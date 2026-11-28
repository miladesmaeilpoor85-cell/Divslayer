"""Generate clean art previews, collision overlays, and an overview sheet for every map."""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

CELL_WIDTH = 280
CELL_HEIGHT = 190
THUMBNAIL_SIZE = (264, 156)
DETAILED_MAPS = {"village", "forest", "peaks"}


def render_map(
    renderer: Path,
    root: Path,
    key: str,
    destination: Path,
    scale: float,
    *,
    clean: bool,
) -> str:
    command = [
        sys.executable,
        str(renderer),
        key,
        str(destination),
        "--scale",
        str(scale),
    ]
    if clean:
        command.append("--clean")
    result = subprocess.run(
        command,
        cwd=root,
        capture_output=True,
        text=True,
        timeout=120,
        check=False,
    )
    if result.returncode != 0 or not destination.is_file():
        return f"{key}: {(result.stderr or result.stdout)[-1000:]}"
    return ""


def make_overview(previews: list[tuple[str, Path]], destination: Path) -> None:
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
            tile.paste(
                thumbnail,
                ((THUMBNAIL_SIZE[0] - thumbnail.width) // 2, (THUMBNAIL_SIZE[1] - thumbnail.height) // 2),
            )
            overview.paste(tile, (x + 8, y + 4))
        draw.text((x + 8, y + 166), name, fill=(235, 235, 235))
    overview.save(destination, quality=90, optimize=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, default=Path("artifacts/map-previews"))
    parser.add_argument("--scale", type=float, default=0.25)
    parser.add_argument("--detail-scale", type=float, default=1.0)
    args = parser.parse_args()
    if args.scale <= 0 or args.detail_scale <= 0:
        parser.error("preview scales must be positive")

    root = args.root.resolve()
    output = args.output if args.output.is_absolute() else root / args.output
    output.mkdir(parents=True, exist_ok=True)
    map_data = sorted((root / "data" / "Maps").glob("*.json"))
    if not map_data:
        print("No map JSON files found", file=sys.stderr)
        return 1

    renderer = root / "tools" / "map_preview.py"
    debug_previews: list[tuple[str, Path]] = []
    clean_previews: list[tuple[str, Path]] = []
    errors: list[str] = []
    for map_file in map_data:
        key = map_file.stem
        debug_path = output / f"{key}.png"
        clean_path = output / f"{key}-clean.png"
        for destination, scale, clean, collection in (
            (debug_path, args.scale, False, debug_previews),
            (clean_path, args.scale, True, clean_previews),
        ):
            error = render_map(renderer, root, key, destination, scale, clean=clean)
            if error:
                errors.append(error)
            else:
                collection.append((key, destination))

        if key in DETAILED_MAPS:
            detail_path = output / f"{key}-native-clean.png"
            error = render_map(
                renderer,
                root,
                key,
                detail_path,
                args.detail_scale,
                clean=True,
            )
            if error:
                errors.append(error)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    make_overview(debug_previews, output / "all-maps-overview.jpg")
    make_overview(clean_previews, output / "all-maps-clean-overview.jpg")
    print(f"Map previews generated: {len(debug_previews)}/{len(map_data)}")
    print(f"Clean previews generated: {len(clean_previews)}/{len(map_data)}")
    print(f"Native-scale art previews generated: {len(DETAILED_MAPS)}")
    print(f"Overviews: {output / 'all-maps-overview.jpg'} and {output / 'all-maps-clean-overview.jpg'}")
    print("MAP_PREVIEWS_PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
