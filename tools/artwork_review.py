"""Fully decode game images and create visual review contact sheets with Pillow."""
from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw

from image_assets import open_image

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".svg"}
EXCLUDED_PARTS = {".git", ".godot", ".venv", "build", "dist", "artifacts", "__pycache__"}
CELL_WIDTH = 184
CELL_HEIGHT = 164
THUMBNAIL_SIZE = (164, 124)


def collect_images(root: Path) -> list[Path]:
    return sorted(
        path for path in root.rglob("*")
        if path.is_file()
        and path.suffix.lower() in IMAGE_EXTENSIONS
        and not EXCLUDED_PARTS.intersection(path.relative_to(root).parts)
        and ("assets/art" in path.relative_to(root).as_posix() or "assets/icon" in path.relative_to(root).as_posix() or path.name == "icon.png")
    )


def _category(root: Path, path: Path) -> str:
    rel = path.relative_to(root)
    parts = rel.parts
    if len(parts) >= 3 and parts[0:2] == ("assets", "art"):
        return parts[2]
    return "app-icons"


def make_contact_sheet(category: str, items: list[tuple[str, Image.Image]], output_dir: Path) -> Path:
    columns = 6
    rows = (len(items) + columns - 1) // columns
    sheet = Image.new("RGB", (columns * CELL_WIDTH, rows * CELL_HEIGHT), (31, 34, 40))
    draw = ImageDraw.Draw(sheet)
    for index, (name, source) in enumerate(items):
        x = (index % columns) * CELL_WIDTH
        y = (index // columns) * CELL_HEIGHT
        tile = Image.new("RGBA", THUMBNAIL_SIZE, (48, 52, 60, 255))
        image = source.copy()
        image.thumbnail(THUMBNAIL_SIZE, Image.Resampling.LANCZOS)
        tile.alpha_composite(image.convert("RGBA"), ((THUMBNAIL_SIZE[0] - image.width) // 2, (THUMBNAIL_SIZE[1] - image.height) // 2))
        sheet.paste(tile.convert("RGB"), (x + 10, y + 4))
        label = name if len(name) <= 25 else name[:22] + "..."
        draw.text((x + 8, y + 132), label, fill=(232, 232, 232))
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / f"{category.lower().replace(' ', '-')}.jpg"
    sheet.save(output_path, quality=88, optimize=True)
    return output_path


def audit_images(root: Path, output_dir: Path) -> dict[str, Any]:
    root = root.resolve()
    images = collect_images(root)
    errors: list[str] = []
    details: list[dict[str, Any]] = []
    grouped: dict[str, list[tuple[str, Image.Image]]] = defaultdict(list)
    modes: dict[str, int] = {}

    for path in images:
        rel = path.relative_to(root).as_posix()
        try:
            image = open_image(path)
            width, height = image.size
            mode = image.mode
            if width <= 0 or height <= 0:
                raise ValueError("image has zero dimensions")
            category = _category(root, path)
            grouped[category].append((path.name, image.copy()))
            modes[mode] = modes.get(mode, 0) + 1
            details.append({
                "path": rel,
                "width": width,
                "height": height,
                "mode": mode,
                "size_bytes": path.stat().st_size,
            })
        except (OSError, ValueError, Image.DecompressionBombError) as exc:
            errors.append(f"{rel}: {exc}")

    sheets = []
    if not errors:
        for category, items in sorted(grouped.items()):
            sheet = make_contact_sheet(category, items, output_dir)
            sheets.append(sheet.relative_to(root).as_posix())

    return {
        "image_files_checked": len(images),
        "image_files_decoded": len(details),
        "modes": dict(sorted(modes.items())),
        "contact_sheets": sheets,
        "images": details,
        "errors": errors,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, default=Path("artifacts/artwork-review"))
    args = parser.parse_args()
    output = args.output if args.output.is_absolute() else args.root / args.output
    report = audit_images(args.root, output)
    report_path = output / "image-audit.json"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Images decoded: {report['image_files_decoded']}/{report['image_files_checked']}")
    print(f"Contact sheets created: {len(report['contact_sheets'])}")
    for error in report["errors"]:
        print(f"ERROR: {error}", file=sys.stderr)
    print("IMAGE_DECODE_PASSED" if not report["errors"] and report["image_files_checked"] else "IMAGE_DECODE_FAILED")
    return 1 if report["errors"] or not report["image_files_checked"] else 0


if __name__ == "__main__":
    sys.exit(main())
