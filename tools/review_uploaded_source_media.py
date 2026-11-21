from __future__ import annotations

import json
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts" / "source-media-review"
PNG_FILES = [
    ROOT / "hoosha-hoosha-1795269314286-1.png",
    ROOT / "hoosha-hoosha-1795269633719-2.png",
]
VIDEO_FILES = [
    ROOT / "hoosha-hoosha-1795273509214-1.mp4",
    ROOT / "hoosha-hoosha-1795274587505-1.mp4",
]

def ffprobe(path: Path) -> dict:
    result = subprocess.run([
        "ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(path)
    ], check=True, capture_output=True, text=True)
    data = json.loads(result.stdout)
    video = next((s for s in data.get("streams", []) if s.get("codec_type") == "video"), {})
    return {
        "file": path.name, "bytes": path.stat().st_size,
        "codec": video.get("codec_name"), "width": video.get("width"), "height": video.get("height"),
        "avg_frame_rate": video.get("avg_frame_rate"), "nb_frames": video.get("nb_frames"),
        "duration_seconds": float(video.get("duration", data.get("format", {}).get("duration", 0)) or 0),
        "pixel_format": video.get("pix_fmt"), "has_audio": any(s.get("codec_type") == "audio" for s in data.get("streams", [])),
    }

def labeled_thumb(path: Path, size=(240, 300)) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    bg = Image.new("RGBA", image.size, (55, 55, 55, 255))
    bg.alpha_composite(image)
    bg.thumbnail(size, Image.Resampling.LANCZOS)
    tile = Image.new("RGB", (size[0], size[1] + 34), (32, 32, 32))
    x = (size[0] - bg.width) // 2
    y = (size[1] - bg.height) // 2
    tile.paste(bg.convert("RGB"), (x, y))
    draw = ImageDraw.Draw(tile)
    draw.text((6, size[1] + 8), path.name[:34], fill="white")
    return tile

def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    report = {"images": [], "videos": []}
    image_tiles = []
    for path in PNG_FILES:
        if not path.is_file():
            raise FileNotFoundError(path)
        with Image.open(path) as im:
            im.load()
            alpha = im.getchannel("A") if "A" in im.getbands() else None
            bbox = alpha.getbbox() if alpha else None
            report["images"].append({
                "file": path.name, "bytes": path.stat().st_size, "format": im.format,
                "width": im.width, "height": im.height, "mode": im.mode,
                "has_alpha": alpha is not None, "alpha_bbox": bbox,
                "alpha_extrema": alpha.getextrema() if alpha else None,
            })
        copy = OUT / path.name
        copy.write_bytes(path.read_bytes())
        image_tiles.append(labeled_thumb(path))
    if image_tiles:
        sheet = Image.new("RGB", (480, 668), (18, 18, 18))
        for i, tile in enumerate(image_tiles):
            sheet.paste(tile, ((i % 2) * 240, (i // 2) * 334))
        sheet.save(OUT / "uploaded-png-contact-sheet.jpg", quality=92)

    for path in VIDEO_FILES:
        if not path.is_file():
            raise FileNotFoundError(path)
        meta = ffprobe(path)
        duration = meta["duration_seconds"]
        meta["sample_timestamps"] = [round(duration * p, 3) for p in (0.08, 0.18, 0.28, 0.38, 0.48, 0.58, 0.68, 0.78, 0.88, 0.96)]
        frame_paths = []
        for index, stamp in enumerate(meta["sample_timestamps"]):
            frame = OUT / f"{path.stem}-frame-{index:02d}.png"
            subprocess.run([
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", str(stamp),
                "-i", str(path), "-frames:v", "1", "-vf", "scale=240:-1", str(frame)
            ], check=True, capture_output=True)
            frame_paths.append(frame)
        tiles = []
        for i, frame in enumerate(frame_paths):
            with Image.open(frame) as im:
                im.load()
                tile = Image.new("RGB", (240, 280), (28, 28, 28))
                im.thumbnail((240, 250), Image.Resampling.LANCZOS)
                tile.paste(im.convert("RGB"), ((240 - im.width) // 2, (250 - im.height) // 2))
                ImageDraw.Draw(tile).text((8, 258), f"{stamp if False else meta['sample_timestamps'][i]}s", fill="white")
                tiles.append(tile)
        sheet = Image.new("RGB", (960, 840), (18, 18, 18))
        for i, tile in enumerate(tiles):
            sheet.paste(tile, ((i % 4) * 240, (i // 4) * 280))
        sheet.save(OUT / f"{path.stem}-contact-sheet.jpg", quality=92)
        meta["contact_sheet"] = f"{path.stem}-contact-sheet.jpg"
        report["videos"].append(meta)
    (OUT / "source-media-review.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))

if __name__ == "__main__":
    main()
