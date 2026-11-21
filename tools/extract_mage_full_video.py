from __future__ import annotations

import json
import subprocess
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "hoosha-hoosha-1795274587505-1.mp4"
OUT = ROOT / "artifacts" / "mage-full-video-extraction"
FRAMES = OUT / "frames"


def probe() -> dict:
    raw = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_streams",
         "-show_format", "-of", "json", str(SOURCE)],
        check=True, capture_output=True, text=True,
    )
    data = json.loads(raw.stdout)
    stream = data["streams"][0]
    return {
        "source": SOURCE.name,
        "width": stream.get("width"),
        "height": stream.get("height"),
        "fps": stream.get("avg_frame_rate"),
        "frame_count": int(stream.get("nb_frames") or 0),
        "duration_seconds": float(stream.get("duration", data["format"].get("duration", 0))),
    }


def key_green(frame: np.ndarray) -> np.ndarray:
    # Preserve the full frame and feather anti-aliased green-screen boundaries.
    b, g, r = cv2.split(frame.astype(np.float32))
    excess = g - np.maximum(r, b)
    hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
    hue, sat, _ = cv2.split(hsv)
    green_screen = (hue >= 32) & (hue <= 88) & (sat >= 70) & (excess >= 12)
    # Hard removal for saturated green, soft matte around hair/clothing edges.
    alpha = np.clip((48.0 - excess) / 36.0, 0.0, 1.0)
    alpha[green_screen & (excess > 42)] = 0.0
    # Remove green spill only where a green excess is detected.
    spill = np.maximum(0.0, excess - 7.0) * 0.88
    clean_g = np.maximum(0.0, g - spill)
    rgb = cv2.merge([r, clean_g, b])
    rgba = np.dstack([np.clip(rgb, 0, 255).astype(np.uint8),
                      np.clip(alpha * 255, 0, 255).astype(np.uint8)])
    return rgba


def main() -> None:
    if not SOURCE.is_file():
        raise FileNotFoundError(SOURCE)
    FRAMES.mkdir(parents=True, exist_ok=True)
    meta = probe()
    cap = cv2.VideoCapture(str(SOURCE))
    written = 0
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        rgba = key_green(frame)
        Image.fromarray(rgba, "RGBA").save(FRAMES / f"mage_cast_{written:04d}.png", optimize=True)
        written += 1
    cap.release()
    if written < 2:
        raise RuntimeError(f"Expected full video frames; extracted only {written}")
    meta["frames_extracted"] = written
    meta["fps_float"] = float(meta["fps"].split("/")[0]) / float(meta["fps"].split("/")[1])
    meta["note"] = "Full-frame chroma-key draft. Review edge matte/despill before runtime use; this is not yet approved as a game animation."
    (OUT / "manifest.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")

    # Four review sheets, keeping all 121 frames visible at reduced scale.
    paths = sorted(FRAMES.glob("*.png"))
    for page in range((len(paths) + 30) // 31):
        subset = paths[page * 31:(page + 1) * 31]
        tile_w, tile_h = 120, 230
        sheet = Image.new("RGB", (tile_w * 5, tile_h * 7), (28, 28, 28))
        for idx, path in enumerate(subset):
            im = Image.open(path).convert("RGBA")
            im.thumbnail((tile_w - 8, tile_h - 28), Image.Resampling.LANCZOS)
            tile = Image.new("RGBA", (tile_w, tile_h), (75, 75, 75, 255))
            for y in range(0, tile_h - 24, 12):
                for x in range(0, tile_w, 12):
                    if (x // 12 + y // 12) % 2:
                        ImageDraw.Draw(tile).rectangle((x, y, x + 11, y + 11), fill=(105, 105, 105, 255))
            tile.alpha_composite(im, ((tile_w - im.width) // 2, 2))
            ImageDraw.Draw(tile).text((5, tile_h - 20), path.stem, fill="white")
            sheet.paste(tile.convert("RGB"), ((idx % 5) * tile_w, (idx // 5) * tile_h))
        sheet.save(OUT / f"contact-sheet-{page + 1:02d}.jpg", quality=90)

    readme = (
        "# Mage full-video frame extraction — draft\\n\\n"
        f"- Source: {SOURCE.name}\\n- Extracted frames: {written}\\n"
        f"- Source frame rate: {meta['fps']}\\n- Canvas: {meta['width']}x{meta['height']}\\n\\n"
        "All decoded frames are included as transparent PNGs at original dimensions. "
        "A preliminary chroma key and green despill were applied. Inspect hair, cloth edges, "
        "staff crystal, and glow effects. Do not import into runtime until visual cleanup, "
        "timing review, and in-game testing are complete.\\n"
    )
    (OUT / "README.md").write_text(readme, encoding="utf-8")
    print(json.dumps(meta, indent=2))


if __name__ == "__main__":
    main()
