"""Generate map layout previews and an overview sheet using the existing Pillow renderer."""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

CELL_WIDTH = 280
CELL_HEIGHT = 190
THUMBNAIL_SIZE = (264, 156)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, default=Path("artifacts/map-previews"))
    parser.add_argument("--scale", type=float, default=0.25)
    args = parser.parse_args()

    root = args.root.resolve()
    output = args.output if args.output.is_absolute() else root / args.output
    output.mkdir(parents=True, exist_ok=True)
    map_data = sorted((root / "data" / "Maps").glob("*.json"))
    if not map_data:
        print("No map JSON files found", file=sys.stderr)
        return 1

    renderer = root / "tools" / "map_preview.py"
    previews: list[tuple[str, Path]] = []
    errors: list[str] = []
    for map_file in map_data:
        key = map_file.stem
        destination = output / f"{key}.png"
        result = subprocess.run(
            [sys.executable, str(renderer), key, str(destination), "--scale", str(args.scale)],
            cwd=root,
            capture_output=True,
            text=True,
            timeout=120,
            check=False,
        )
        if result.returncode != 0 or not destination.is_file():
            errors.append(f"{key}: {(result.stderr or result.stdout)[-1000:]}")
            continue
        previews.append((key, destination))

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    columns = 4
    rows = (len(previews) + columns - 1) // columns
    overview = Image.new("RGB", (columns * CELL_WIDTH, rows * CELL_HEIGHT), (30, 33, 39))
    draw = ImageDraw.Draw(overview)
    for index, (name, path) in enumerate(previews):
        x = (index % columns) * CELL_WIDTH
        y = (index // columns) * CELL_HEIGHT
        with Image.open(path) as image:
            image.load()
            thumbnail = image.convert("RGB")
            thumbnail.thumbnail(THUMBNAIL_SIZE, Image.Resampling.LANCZOS)
            tile = Image.new("RGB", THUMBNAIL_SIZE, (50, 54, 63))
            tile.paste(thumbnail, ((THUMBNAIL_SIZE[0] - thumbnail.width) // 2, (THUMBNAIL_SIZE[1] - thumbnail.height) // 2))
            overview.paste(tile, (x + 8, y + 4))
        draw.text((x + 8, y + 166), name, fill=(235, 235, 235))
    overview.save(output / "all-maps-overview.jpg", quality=88, optimize=True)

    print(f"Map previews generated: {len(previews)}/{len(map_data)}")
    print(f"Overview: {output / 'all-maps-overview.jpg'}")
    print("MAP_PREVIEWS_PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
