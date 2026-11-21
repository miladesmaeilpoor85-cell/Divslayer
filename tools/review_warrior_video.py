from __future__ import annotations

import json
import subprocess
from collections import Counter
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "artifacts" / "warrior-source" / "hoosha-hoosha-1795294926704-1.mp4"
OUT = ROOT / "artifacts" / "warrior-video-review"
FRAMES = OUT / "frames"


def probe() -> dict:
    raw = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_streams",
         "-show_format", "-of", "json", str(SOURCE)],
        check=True, capture_output=True, text=True,
    )
    data = json.loads(raw.stdout)
    stream = data["streams"][0]
    rate = stream.get("avg_frame_rate", "0/1")
    num, den = (rate.split("/") + ["1"])[:2]
    fps = float(num) / max(float(den), 1.0)
    return {
        "source": "hoosha-hoosha-1795294926704-1.mp4",
        "width": stream.get("width"),
        "height": stream.get("height"),
        "fps": rate,
        "fps_float": fps,
        "frame_count_reported": int(stream.get("nb_frames") or 0),
        "duration_seconds": float(stream.get("duration", data["format"].get("duration", 0))),
        "codec": stream.get("codec_name"),
        "pixel_format": stream.get("pix_fmt"),
    }


def matte(frame: np.ndarray) -> tuple[np.ndarray, dict]:
    # Draft green-screen key with conservative soft edge and green despill.
    b, g, r = cv2.split(frame.astype(np.float32))
    excess = g - np.maximum(r, b)
    hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
    hue, sat, _ = cv2.split(hsv)
    is_green = (hue >= 32) & (hue <= 90) & (sat >= 65) & (excess >= 10)
    alpha = np.clip((52.0 - excess) / 38.0, 0.0, 1.0)
    alpha[is_green & (excess > 38)] = 0.0
    spill = np.maximum(0.0, excess - 8.0) * 0.82
    clean_g = np.maximum(0.0, g - spill)
    rgba = np.dstack([
        np.clip(r, 0, 255).astype(np.uint8),
        np.clip(clean_g, 0, 255).astype(np.uint8),
        np.clip(b, 0, 255).astype(np.uint8),
        np.clip(alpha * 255, 0, 255).astype(np.uint8),
    ])
    return rgba, {
        "green_pixel_ratio": float(np.mean(is_green)),
        "transparent_pixel_ratio": float(np.mean(alpha < 0.05)),
        "opaque_pixel_ratio": float(np.mean(alpha > 0.95)),
    }


def main() -> None:
    if not SOURCE.is_file():
        raise FileNotFoundError(f"Warrior source video not staged: {SOURCE}")
    OUT.mkdir(parents=True, exist_ok=True)
    FRAMES.mkdir(parents=True, exist_ok=True)
    meta = probe()
    cap = cv2.VideoCapture(str(SOURCE))
    decoded = 0
    previous = None
    hashes = Counter()
    green_stats = []
    frame_diffs = []
    frame_paths = []
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        rgba, stats = matte(frame)
        path = FRAMES / f"warrior_attack_{decoded:04d}.png"
        Image.fromarray(rgba, "RGBA").save(path, optimize=True)
        frame_paths.append(path)
        green_stats.append(stats)
        # Small grayscale signature to detect exact/near-identical consecutive frames.
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        small = cv2.resize(gray, (32, 32), interpolation=cv2.INTER_AREA)
        signature = small.tobytes()
        hashes[signature] += 1
        if previous is not None:
            frame_diffs.append(float(np.mean(cv2.absdiff(small, previous))))
        previous = small
        decoded += 1
    cap.release()
    if decoded < 2:
        raise RuntimeError(f"Only {decoded} frames decoded")

    meta["frames_decoded"] = decoded
    meta["green_pixel_ratio_mean"] = float(np.mean([x["green_pixel_ratio"] for x in green_stats]))
    meta["transparent_pixel_ratio_mean"] = float(np.mean([x["transparent_pixel_ratio"] for x in green_stats]))
    meta["opaque_pixel_ratio_mean"] = float(np.mean([x["opaque_pixel_ratio"] for x in green_stats]))
    meta["consecutive_frame_mean_abs_difference_32x32"] = float(np.mean(frame_diffs)) if frame_diffs else 0.0
    meta["identical_frame_signature_count"] = int(sum(v - 1 for v in hashes.values() if v > 1))
    meta["note"] = (
        "Automated technical review and draft chroma key only. Contact sheets and frame "
        "timing must be visually checked. Not approved for runtime use."
    )
    (OUT / "manifest.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")

    # Contact sheets show the full extracted sequence in chronological order.
    tile_w, tile_h = 144, 190
    per_page = 35
    for page in range((decoded + per_page - 1) // per_page):
        subset = frame_paths[page * per_page:(page + 1) * per_page]
        sheet = Image.new("RGB", (tile_w * 5, tile_h * 7), (35, 35, 35))
        draw = ImageDraw.Draw(sheet)
        for idx, path in enumerate(subset):
            im = Image.open(path).convert("RGBA")
            im.thumbnail((tile_w - 8, tile_h - 25), Image.Resampling.LANCZOS)
            tile = Image.new("RGBA", (tile_w, tile_h), (75, 75, 75, 255))
            checker = Image.new("RGBA", (tile_w, tile_h - 22), (0, 0, 0, 0))
            cd = ImageDraw.Draw(checker)
            for y in range(0, checker.height, 12):
                for x in range(0, checker.width, 12):
                    if (x // 12 + y // 12) % 2:
                        cd.rectangle((x, y, x + 11, y + 11), fill=(110, 110, 110, 255))
                    else:
                        cd.rectangle((x, y, x + 11, y + 11), fill=(65, 65, 65, 255))
            tile.alpha_composite(checker)
            tile.alpha_composite(im, ((tile_w - im.width) // 2, 0))
            ImageDraw.Draw(tile).text((5, tile_h - 18), path.stem, fill="white")
            sheet.paste(tile.convert("RGB"), ((idx % 5) * tile_w, (idx // 5) * tile_h))
        sheet.save(OUT / f"contact-sheet-{page + 1:02d}.jpg", quality=91)

    readme = (
        "# Warrior source video review — draft\n\n"
        f"- Source: {meta['source']}\n- Codec: {meta['codec']}\n"
        f"- Canvas: {meta['width']}x{meta['height']}\n- Frame rate: {meta['fps']} ({meta['fps_float']:.3f} fps)\n"
        f"- Reported frames: {meta['frame_count_reported']}\n- Decoded frames: {decoded}\n"
        f"- Duration: {meta['duration_seconds']:.3f} seconds\n"
        f"- Mean green-screen pixel ratio: {meta['green_pixel_ratio_mean']:.4f}\n"
        f"- Mean transparent pixel ratio after draft key: {meta['transparent_pixel_ratio_mean']:.4f}\n"
        f"- Repeated frame signatures: {meta['identical_frame_signature_count']}\n\n"
        "This is a preliminary technical pass. Inspect contact sheets for character consistency, "
        "cropping, weapon/shield integrity, edge halos, and motion continuity. Do not import into "
        "the game until a human visual review and in-engine timing test pass.\n"
    )
    (OUT / "README.md").write_text(readme, encoding="utf-8")
    print(json.dumps(meta, indent=2))


if __name__ == "__main__":
    main()
