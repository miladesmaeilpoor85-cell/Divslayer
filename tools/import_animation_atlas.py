"""Import a 4x3 generated attack atlas as aligned, transparent Godot frames."""
from __future__ import annotations

import argparse
import hashlib
import json
from collections import deque
from pathlib import Path
from typing import Any

from PIL import Image

DIRECTIONS = ("down", "up", "side")
LABELS = ("anticipation", "windup", "contact", "recovery")


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _key_color(value: str) -> tuple[int, int, int]:
    raw = value.removeprefix("#")
    if len(raw) != 6:
        raise ValueError("key color must be a six-digit RGB hex value")
    try:
        return tuple(int(raw[i : i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]
    except ValueError as exc:
        raise ValueError("key color must be a six-digit RGB hex value") from exc


def _key_connected_background(image: Image.Image, key: tuple[int, int, int], tolerance: int) -> int:
    """Clear only key-colored pixels connected to the crop's outer edge."""
    width, height = image.size
    pixels = image.load()
    candidate = bytearray(width * height)
    for y in range(height):
        for x in range(width):
            pixel = pixels[x, y]
            candidate[y * width + x] = int(max(abs(pixel[c] - key[c]) for c in range(3)) <= tolerance)
    visited = bytearray(width * height)
    queue: deque[int] = deque()
    for x in range(width):
        for y in (0, height - 1):
            index = y * width + x
            if candidate[index] and not visited[index]:
                visited[index] = 1
                queue.append(index)
    for y in range(height):
        for x in (0, width - 1):
            index = y * width + x
            if candidate[index] and not visited[index]:
                visited[index] = 1
                queue.append(index)
    removed = 0
    while queue:
        index = queue.popleft()
        x, y = index % width, index // width
        r, g, b, _ = pixels[x, y]
        pixels[x, y] = (r, g, b, 0)
        removed += 1
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < width and 0 <= ny < height:
                neighbour = ny * width + nx
                if candidate[neighbour] and not visited[neighbour]:
                    visited[neighbour] = 1
                    queue.append(neighbour)
    return removed


def _key_global_background(image: Image.Image, key: tuple[int, int, int], tolerance: int) -> int:
    """Clear every key-colored pixel, including isolated islands inside foreground shapes.

    Use only when the same chroma color is intentionally used as an enclosed matte,
    such as a magenta fill inside a pale Rogue slash effect.
    """
    width, height = image.size
    pixels = image.load()
    removed = 0
    for y in range(height):
        for x in range(width):
            r, g, b, _ = pixels[x, y]
            if max(abs((r, g, b)[c] - key[c]) for c in range(3)) <= tolerance:
                pixels[x, y] = (r, g, b, 0)
                removed += 1
    return removed




def _is_magenta_spill(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, alpha = pixel
    return alpha > 0 and r > 110 and b > 90 and g < 135 and r > g + 60 and b > g + 40


def _key_magenta_spill(image: Image.Image, global_mode: bool) -> int:
    """Remove magenta-biased antialiasing connected to the outer edge (or all islands)."""
    width, height = image.size
    pixels = image.load()
    visited = bytearray(width * height)
    queue: deque[int] = deque()
    if global_mode:
        removed = 0
        for y in range(height):
            for x in range(width):
                if _is_magenta_spill(pixels[x, y]):
                    r, g, b, _ = pixels[x, y]
                    pixels[x, y] = (r, g, b, 0)
                    removed += 1
        return removed
    for x in range(width):
        for y in (0, height - 1):
            index = y * width + x
            if _is_magenta_spill(pixels[x, y]) and not visited[index]:
                visited[index] = 1
                queue.append(index)
    for y in range(height):
        for x in (0, width - 1):
            index = y * width + x
            if _is_magenta_spill(pixels[x, y]) and not visited[index]:
                visited[index] = 1
                queue.append(index)
    removed = 0
    while queue:
        index = queue.popleft()
        x, y = index % width, index // width
        r, g, b, _ = pixels[x, y]
        pixels[x, y] = (r, g, b, 0)
        removed += 1
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < width and 0 <= ny < height:
                neighbour = ny * width + nx
                if not visited[neighbour] and _is_magenta_spill(pixels[nx, ny]):
                    visited[neighbour] = 1
                    queue.append(neighbour)
    return removed


def _despill_magenta_edges(image: Image.Image) -> None:
    """Suppress residual magenta color after alpha-safe resampling."""
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, alpha = pixels[x, y]
            if alpha < 8:
                pixels[x, y] = (0, 0, 0, 0)
            elif g < 120 and r > g + 20 and b > g + 20:
                strength = min(1.0, min(r - g, b - g) / 120.0)
                red = int(g + (r - g) * (1.0 - 0.30 * strength))
                green = int(g + (r - g) * (0.20 * strength))
                blue = int(g + (b - g) * (1.0 - 1.15 * strength))
                pixels[x, y] = (
                    max(0, min(255, red)),
                    max(0, min(255, green)),
                    max(0, min(255, blue)),
                    alpha,
                )

def _visible_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").point(lambda a: 255 if a >= 16 else 0).getbbox()
    if bbox is None:
        raise ValueError("frame contains no visible character after background removal")
    return bbox


def _motion_ratio(first: Image.Image, second: Image.Image) -> float:
    a, b = first.convert("RGBA").load(), second.convert("RGBA").load()
    width, height = first.size
    changed = sum(
        1 for y in range(height) for x in range(width)
        if max(abs(a[x, y][c] - b[x, y][c]) for c in range(4)) > 12
    )
    return changed / float(width * height)


def import_atlas(
    source: Path,
    output: Path,
    *,
    prefix: str,
    key_color: str = "#ff00ff",
    tolerance: int = 72,
    global_key: bool = False,
    magenta_spill: bool = False,
    top_padding: int = 8,
    allow_edge_contact: bool = False,
    cell_width: int = 160,
    cell_height: int = 156,
    max_content_width: int = 144,
    bottom_padding: int = 6,
) -> dict[str, Any]:
    """Split a generated atlas, remove edge-connected chroma key, and align all feet."""
    if not source.is_file():
        raise FileNotFoundError(source)
    if not prefix or any(not (char.isalnum() or char in "_-") for char in prefix):
        raise ValueError("prefix may contain only letters, numbers, underscores and hyphens")
    if not 0 <= tolerance <= 255 or cell_width < 16 or cell_height < 16:
        raise ValueError("invalid key tolerance or output cell dimensions")
    if (
        not 0 <= bottom_padding < cell_height
        or not 0 <= top_padding < cell_height - bottom_padding
        or max_content_width < 1
    ):
        raise ValueError("invalid content width or top/foot padding")
    with Image.open(source) as opened:
        atlas = opened.convert("RGBA")
    if atlas.width % 4 or atlas.height % 3:
        raise ValueError(f"source atlas {atlas.size} is not divisible into a 4x3 grid")
    src_w, src_h = atlas.width // 4, atlas.height // 3
    if min(src_w, src_h) < 32:
        raise ValueError("source atlas cells are too small")
    key = _key_color(key_color)
    extracted: list[dict[str, Any]] = []
    for row, direction in enumerate(DIRECTIONS):
        for column, label in enumerate(LABELS):
            cell = atlas.crop((column * src_w, row * src_h, (column + 1) * src_w, (row + 1) * src_h))
            removed = _key_global_background(cell, key, tolerance) if global_key else _key_connected_background(cell, key, tolerance)
            if magenta_spill:
                _key_magenta_spill(cell, global_mode=global_key)
            ratio = removed / float(src_w * src_h)
            if ratio < 0.05:
                raise ValueError(f"{direction}/{label}: only {ratio:.1%} background removed; check key color")
            bbox = _visible_bbox(cell)
            edge_margin = min(bbox[0], bbox[1], src_w - bbox[2], src_h - bbox[3])
            oversized = bbox[2] - bbox[0] > src_w * 0.96 or bbox[3] - bbox[1] > src_h * 0.98
            if oversized and not allow_edge_contact:
                raise ValueError(f"{direction}/{label}: character touches the cell bounds")
            extracted.append({
                "direction": direction, "label": label, "index": column,
                "image": cell.crop(bbox), "source_bbox": list(bbox),
                "background_removed_ratio": round(ratio, 5),
                "edge_margin": edge_margin,
            })
    max_w = max(item["image"].width for item in extracted)
    max_h = max(item["image"].height for item in extracted)
    scale = min(
        max_content_width / max_w,
        (cell_height - top_padding - bottom_padding) / max_h,
        1.0,
    )
    output.mkdir(parents=True, exist_ok=True)
    packed = Image.new("RGBA", (cell_width * 4, cell_height * 3), (0, 0, 0, 0))
    frame_files: list[list[str]] = [[] for _ in DIRECTIONS]
    by_direction: dict[str, list[Image.Image]] = {direction: [] for direction in DIRECTIONS}
    records: list[dict[str, Any]] = []
    for item in extracted:
        pose: Image.Image = item["image"].convert("RGBa")
        size = (max(1, round(pose.width * scale)), max(1, round(pose.height * scale)))
        pose = pose.resize(size, Image.Resampling.LANCZOS).convert("RGBA")
        if magenta_spill:
            _despill_magenta_edges(pose)
        frame = Image.new("RGBA", (cell_width, cell_height), (0, 0, 0, 0))
        x = (cell_width - pose.width) // 2
        y = cell_height - bottom_padding - pose.height
        frame.alpha_composite(pose, (x, y))
        row, index = DIRECTIONS.index(item["direction"]), int(item["index"])
        packed.alpha_composite(frame, (index * cell_width, row * cell_height))
        filename = f"{item['direction']}_{index}.png"
        frame.save(output / filename, optimize=True)
        frame_files[row].append(f"{prefix}/{filename}")
        by_direction[item["direction"]].append(frame)
        records.append({
            "direction": item["direction"], "frame": index, "label": item["label"],
            "source_bbox": item["source_bbox"], "output_bbox": list(_visible_bbox(frame)),
            "background_removed_ratio": item["background_removed_ratio"],
            "minimum_source_margin_px": item["edge_margin"],
        })
    packed_path = output / f"{prefix}_atlas.png"
    packed.save(packed_path, optimize=True)
    duplicates: dict[str, list[list[int]]] = {}
    motion: dict[str, list[float]] = {}
    warnings: list[str] = []
    for item in extracted:
        if item["edge_margin"] < 8:
            warnings.append(
                f'{item["direction"]}/{item["label"]}: art comes within '
                f'{item["edge_margin"]} px of source cell edge; inspect for clipping'
            )
    for direction, frames in by_direction.items():
        pairs = [[i, j] for i in range(4) for j in range(i + 1, 4) if frames[i].tobytes() == frames[j].tobytes()]
        ratios = [round(_motion_ratio(frames[i], frames[i + 1]), 5) for i in range(3)]
        duplicates[direction], motion[direction] = pairs, ratios
        if pairs:
            warnings.append(f"{direction}: duplicate frame pairs {pairs}")
        warnings.extend(
            f"{direction}: low motion between {i} and {i + 1} ({ratio:.1%})"
            for i, ratio in enumerate(ratios) if ratio < 0.025
        )
    report = {
        "status": "passed_with_warnings" if warnings else "passed",
        "source": source.name, "source_sha256": _sha256(source),
        "source_dimensions": list(atlas.size), "source_cell_dimensions": [src_w, src_h],
        "output_atlas": packed_path.name, "output_sha256": _sha256(packed_path),
        "output_dimensions": list(packed.size), "cell_dimensions": [cell_width, cell_height],
        "directions": list(DIRECTIONS), "frames_per_direction": 4,
        "frame_labels": list(LABELS), "common_scale": round(scale, 5),
        "key_color": key_color, "key_tolerance": tolerance,
        "magenta_spill_cleanup": magenta_spill, "top_padding": top_padding,
        "frame_files": frame_files, "duplicate_pairs": duplicates,
        "adjacent_changed_pixel_ratio": motion, "frames": records, "warnings": warnings,
    }
    (output / f"{prefix}_import_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--prefix", required=True)
    parser.add_argument("--key-color", default="#ff00ff")
    parser.add_argument("--tolerance", type=int, default=72)
    parser.add_argument("--global-key", action="store_true", help="remove enclosed key-colored islands too; use only when key color is also inside a foreground effect")
    parser.add_argument("--allow-edge-contact", action="store_true", help="keep sprites with near-edge content but record warnings; manually inspect all flagged cells")
    parser.add_argument("--magenta-spill", action="store_true", help="remove connected magenta-biased matte fringes and despill after resampling; do not use if purple is part of the sprite")
    parser.add_argument("--top-padding", type=int, default=8, help="minimum vertical air above the resized pose in output cells")
    args = parser.parse_args()
    try:
        report = import_atlas(
            args.source, args.output, prefix=args.prefix, key_color=args.key_color,
            tolerance=args.tolerance, global_key=args.global_key,
            allow_edge_contact=args.allow_edge_contact, magenta_spill=args.magenta_spill,
            top_padding=args.top_padding,
        )
    except (OSError, ValueError) as exc:
        parser.exit(2, f"animation atlas import failed: {exc}\n")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
