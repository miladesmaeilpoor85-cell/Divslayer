#!/usr/bin/env python3
"""Build, validate, and preview Divslayer frame-by-frame sprite atlases.

The source art stays in creative/animation. The script creates a Godot-ready
atlas and per-direction GIFs for visual review. It does not edit game files.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
import shutil
from pathlib import Path
from typing import Any

from PIL import Image, ImageChops, ImageFilter


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_config(config_path: Path) -> tuple[dict[str, Any], Path]:
    config = json.loads(config_path.read_text(encoding="utf-8"))
    required = {
        "source", "cell_width", "cell_height", "directions",
        "frames_per_direction", "fps",
    }
    missing = sorted(required - config.keys())
    if missing:
        raise ValueError(f"Animation config missing keys: {', '.join(missing)}")
    project_root = config_path.parent.parent.parent
    source = (project_root / config["source"]).resolve()
    if not source.is_file():
        raise FileNotFoundError(f"Animation source image not found: {source}")
    expected = len(config["directions"]) * int(config["frames_per_direction"])
    if config.get("source_is_atlas", False):
        if expected < 1:
            raise ValueError("An atlas needs at least one frame")
    else:
        extra_required = {"regions", "max_sprite_width", "max_sprite_height", "bottom_padding"}
        missing = sorted(extra_required - config.keys())
        if missing:
            raise ValueError(f"Animation config missing keys: {', '.join(missing)}")
        if len(config["regions"]) != expected:
            raise ValueError(f"Expected {expected} frame regions, found {len(config['regions'])}")
    return config, source


def build_animation(config_path: Path, output_dir: Path) -> dict[str, Any]:
    config, source_path = load_config(config_path)
    output_dir.mkdir(parents=True, exist_ok=True)
    cell_w = int(config["cell_width"])
    cell_h = int(config["cell_height"])
    directions = [str(item) for item in config["directions"]]
    frames_per_direction = int(config["frames_per_direction"])
    fps = float(config["fps"])
    if cell_w <= 0 or cell_h <= 0 or fps <= 0:
        raise ValueError("Cell dimensions and FPS must be positive")

    asset_name = str(config.get("name", config_path.stem)) + ".png"
    atlas_path = output_dir / asset_name
    preview_frames: dict[str, list[Image.Image]] = {direction: [] for direction in directions}
    frame_records: list[dict[str, Any]] = []

    if config.get("source_is_atlas", False):
        with Image.open(source_path) as opened:
            expected_size = (cell_w * frames_per_direction, cell_h * len(directions))
            if opened.size != expected_size:
                raise ValueError(
                    f"Prepacked atlas must be {expected_size[0]}x{expected_size[1]}, got {opened.width}x{opened.height}"
                )
            atlas = opened.convert("RGBA")
        shutil.copyfile(source_path, atlas_path)
        for row, direction in enumerate(directions):
            for column in range(frames_per_direction):
                cell = atlas.crop((
                    column * cell_w,
                    row * cell_h,
                    (column + 1) * cell_w,
                    (row + 1) * cell_h,
                ))
                if cell.getchannel("A").getbbox() is None:
                    raise ValueError(f"Empty frame cell: {direction}/{column}")
                preview_frames[direction].append(cell)
                frame_records.append({
                    "direction": direction,
                    "frame": column,
                    "label": config.get("frame_labels", [])[column]
                    if column < len(config.get("frame_labels", []))
                    else f"frame_{column}",
                    "source_region": None,
                    "packed_size": [cell_w, cell_h],
                })
    else:
        with Image.open(source_path) as opened:
            source = opened.convert("RGBA")
        atlas = Image.new(
            "RGBA",
            (cell_w * frames_per_direction, cell_h * len(directions)),
            (0, 0, 0, 0),
        )

        for index, region in enumerate(config["regions"]):
            if not isinstance(region, list) or len(region) != 4:
                raise ValueError(f"Region {index} must be [left, top, right, bottom]")
            left, top, right, bottom = (int(value) for value in region)
            if left < 0 or top < 0 or right > source.width or bottom > source.height:
                raise ValueError(f"Region {index} is outside the source image: {region}")
            if right <= left or bottom <= top:
                raise ValueError(f"Region {index} has no area: {region}")

            pose = source.crop((left, top, right, bottom))
            alpha = pose.getchannel("A")
            visible = alpha.point(lambda value: 255 if value > 8 else 0)
            bbox = visible.getbbox()
            if bbox is None:
                raise ValueError(f"Region {index} contains no visible pixels")
            pose = pose.crop(bbox)

            edge_radius = int(config.get("edge_cleanup_radius", 2))
            threshold = int(config.get("edge_cleanup_alpha_threshold", 200))
            if edge_radius < 0 or not 1 <= threshold <= 255:
                raise ValueError("Invalid edge cleanup radius/alpha threshold")
            core = pose.getchannel("A").point(lambda value: 255 if value >= threshold else 0)
            allowed = core.filter(ImageFilter.MaxFilter(edge_radius * 2 + 1))
            pose.putalpha(ImageChops.multiply(pose.getchannel("A"), allowed))

            max_w = min(cell_w - 8, int(config["max_sprite_width"]))
            max_h = min(cell_h - 8, int(config["max_sprite_height"]))
            scale = min(max_w / pose.width, max_h / pose.height)
            new_size = (max(1, round(pose.width * scale)), max(1, round(pose.height * scale)))
            pose = pose.resize(new_size, Image.Resampling.LANCZOS)

            direction_index, frame_index = divmod(index, frames_per_direction)
            direction = directions[direction_index]
            cell = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
            x = (cell_w - pose.width) // 2
            y = cell_h - int(config["bottom_padding"]) - pose.height
            if y < 0:
                raise ValueError(f"Frame {index} does not fit the configured cell")
            cell.alpha_composite(pose, (x, y))
            atlas.alpha_composite(cell, (frame_index * cell_w, direction_index * cell_h))
            preview_frames[direction].append(cell.copy())
            frame_labels = config.get("frame_labels", [])
            frame_records.append({
                "direction": direction,
                "frame": frame_index,
                "label": frame_labels[frame_index]
                if frame_index < len(frame_labels)
                else f"frame_{frame_index}",
                "source_region": [left, top, right, bottom],
                "trimmed_size": [bbox[2] - bbox[0], bbox[3] - bbox[1]],
                "packed_size": list(new_size),
            })

        palette_colors = int(config.get("palette_colors", 0))
        if palette_colors:
            if not 2 <= palette_colors <= 256:
                raise ValueError("palette_colors must be between 2 and 256")
            exported = atlas.quantize(
                colors=palette_colors,
                method=Image.Quantize.FASTOCTREE,
                dither=Image.Dither.FLOYDSTEINBERG,
            )
            exported.save(atlas_path, format="PNG", optimize=True)
        else:
            atlas.save(atlas_path, format="PNG", optimize=True)

    gif_paths: list[str] = []
    duration_ms = max(1, round(1000.0 / fps))
    for direction, frames in preview_frames.items():
        if not frames:
            raise ValueError(f"No frames configured for direction: {direction}")
        gif_path = output_dir / f"{config.get('name', config_path.stem)}_{direction}.gif"
        frames[0].save(
            gif_path,
            save_all=True,
            append_images=frames[1:],
            duration=duration_ms,
            loop=0 if bool(config.get("loop", False)) else 1,
            disposal=2,
            transparency=0,
            optimize=False,
        )
        gif_paths.append(gif_path.name)

    review_scale = int(config.get("review_scale", 2))
    review = atlas.resize(
        (atlas.width * review_scale, atlas.height * review_scale),
        Image.Resampling.NEAREST,
    )
    review_path = output_dir / f"{config.get('name', config_path.stem)}_review.png"
    review.save(review_path, optimize=True)

    report = {
        "status": "passed",
        "name": config.get("name", config_path.stem),
        "source": str(source_path.relative_to(config_path.parent.parent.parent)),
        "source_sha256": sha256(source_path),
        "asset": asset_name,
        "asset_sha256": sha256(atlas_path),
        "asset_dimensions": list(atlas.size),
        "palette_colors": int(config.get("palette_colors", 0)) or None,
        "cell_dimensions": [cell_w, cell_h],
        "directions": directions,
        "frames_per_direction": frames_per_direction,
        "fps": fps,
        "total_frames": len(frame_records),
        "previews": gif_paths,
        "review_image": review_path.name,
        "frames": frame_records,
        "commercial_rights_status": config.get("commercial_rights_status", "UNVERIFIED"),
        "source_mode": "prepacked_atlas" if config.get("source_is_atlas", False) else "mapped_source_regions",
    }
    report_path = output_dir / f"{config.get('name', config_path.stem)}_report.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--config",
        type=Path,
        default=Path("creative/animation/warrior_starter_attack.json"),
    )
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    report = build_animation(args.config.resolve(), args.output.resolve())
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"ANIMATION_PIPELINE_FAILED: {error}", file=sys.stderr)
        raise SystemExit(1)
