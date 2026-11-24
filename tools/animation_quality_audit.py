"""Measure sprite-frame variation and alignment without modifying production art."""
from __future__ import annotations

import argparse
import base64
import io
import json
import sys
from collections import Counter
from itertools import pairwise
from pathlib import Path
from typing import Any

from image_assets import open_image
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
DIFF_THRESHOLD = 12
LOW_MOTION_RATIO = 0.02


def positive_int(value: Any, field: str) -> int:
    try:
        result = int(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{field} must be an integer") from exc
    if result < 1:
        raise ValueError(f"{field} must be positive")
    return result


def frame_metrics(frames: list[Image.Image]) -> dict[str, Any]:
    if not frames:
        raise ValueError("animation clip contains no frames")
    size = frames[0].size
    if any(frame.size != size for frame in frames):
        raise ValueError("animation frames do not share a common cell size")

    normalized: list[Image.Image] = []
    visible_ratios: list[float] = []
    baselines: list[int] = []
    for frame in frames:
        rgba = frame.convert("RGBA")
        alpha = rgba.getchannel("A")
        visible_ratios.append(sum(alpha.histogram()[1:]) / (size[0] * size[1]))
        bbox = alpha.getbbox()
        if bbox is not None:
            baselines.append(bbox[3])
        canvas = Image.new("RGBA", size, (28, 30, 38, 255))
        canvas.alpha_composite(rgba)
        normalized.append(canvas.convert("RGB"))

    keys = [frame.tobytes() for frame in normalized]
    duplicates = [
        [left, right]
        for left in range(len(keys))
        for right in range(left + 1, len(keys))
        if keys[left] == keys[right]
    ]
    changes: list[float] = []
    for before, after in pairwise(normalized):
        histogram = ImageChops.difference(before, after).convert("L").histogram()
        changed = sum(histogram[DIFF_THRESHOLD + 1 :])
        changes.append(changed / (size[0] * size[1]))

    return {
        "frame_count": len(frames),
        "unique_frames": len(set(keys)),
        "duplicate_pairs": duplicates,
        "adjacent_changed_pixel_ratio": [round(value, 6) for value in changes],
        "min_adjacent_changed_pixel_ratio": round(min(changes), 6) if changes else 0.0,
        "mean_adjacent_changed_pixel_ratio": round(sum(changes) / len(changes), 6) if changes else 0.0,
        "max_adjacent_changed_pixel_ratio": round(max(changes), 6) if changes else 0.0,
        "visible_alpha_ratio": round(sum(visible_ratios) / len(visible_ratios), 6),
        "visible_bottom_range_px": max(baselines) - min(baselines) if len(baselines) > 1 else 0,
    }


def clip_warnings(metrics: dict[str, Any], kind: str, name: str) -> list[str]:
    result: list[str] = []
    count = int(metrics["frame_count"])
    if metrics["duplicate_pairs"]:
        result.append("duplicate_frames")
    if count == 1:
        result.append("single_pose")
        if kind == "heroes" and name.startswith("attack_"):
            result.append("hero_attack_is_one_pose")
    elif count == 2:
        result.append("limited_two_frame_cycle")
    if count > 1 and metrics["max_adjacent_changed_pixel_ratio"] < LOW_MOTION_RATIO:
        result.append("very_low_pixel_motion")
    if int(metrics["visible_bottom_range_px"]) > 3:
        result.append("footline_drift_review")
    return result


def crop(sheet: Image.Image, column: int, row: int, width: int, height: int) -> Image.Image:
    return sheet.crop((column * width, row * height, (column + 1) * width, (row + 1) * height))


def _load_separate_attack_frames(
    root: Path,
    hero_directory: Path,
    frame_rows: Any,
    row_names: list[Any],
    cell_size: tuple[int, int],
    asset_id: str,
    expected_count: int,
) -> list[list[Image.Image]]:
    if not isinstance(frame_rows, list) or len(frame_rows) != len(row_names):
        raise ValueError(f"{asset_id}.attackFrameFiles must provide one row per direction")
    width, height = cell_size
    loaded_rows: list[list[Image.Image]] = []
    safe_directory = hero_directory.resolve()

    for row_index, raw_row in enumerate(frame_rows):
        if not isinstance(raw_row, list) or len(raw_row) != expected_count:
            raise ValueError(
                f"{asset_id}.attackFrameFiles row {row_index} must contain {expected_count} frames"
            )
        loaded_frames: list[Image.Image] = []
        for frame_index, raw_path in enumerate(raw_row):
            if not isinstance(raw_path, str) or not raw_path.strip():
                raise ValueError(f"{asset_id}.attackFrameFiles contains an empty frame path")
            relative_path = Path(raw_path)
            if relative_path.is_absolute():
                raise ValueError(f"{asset_id}.attackFrameFiles paths must be relative")
            frame_path = (safe_directory / relative_path).resolve()
            if not frame_path.is_relative_to(safe_directory):
                raise ValueError(f"{asset_id}.attackFrameFiles path escapes the hero asset directory")
            if not frame_path.is_file():
                raise ValueError(f"missing attack frame: {frame_path.relative_to(root).as_posix()}")
            frame_image = open_image(frame_path)
            if frame_image.size != (width, height):
                raise ValueError(
                    f"{frame_path.relative_to(root).as_posix()} is {frame_image.width}x{frame_image.height}; "
                    f"expected {width}x{height}"
                )
            loaded_frames.append(frame_image)
        loaded_rows.append(loaded_frames)
    return loaded_rows



def _load_base64_attack_sheet(
    root: Path,
    hero_directory: Path,
    parts: Any,
    asset_id: str,
) -> Image.Image:
    if not isinstance(parts, list) or not parts:
        raise ValueError(f"{asset_id}.attackSheetBase64Parts must be a non-empty list")
    safe_directory = hero_directory.resolve()
    encoded_parts: list[str] = []
    for raw_path in parts:
        if not isinstance(raw_path, str) or not raw_path.strip():
            raise ValueError(f"{asset_id}.attackSheetBase64Parts contains an empty path")
        relative_path = Path(raw_path)
        if relative_path.is_absolute():
            raise ValueError(f"{asset_id}.attackSheetBase64Parts paths must be relative")
        part_path = (safe_directory / relative_path).resolve()
        if not part_path.is_relative_to(safe_directory):
            raise ValueError(f"{asset_id}.attackSheetBase64Parts path escapes the hero asset directory")
        if not part_path.is_file():
            raise ValueError(f"missing attack atlas payload: {part_path.relative_to(root).as_posix()}")
        encoded_parts.append(part_path.read_text(encoding="ascii").strip())
    try:
        payload = base64.b64decode("".join(encoded_parts), validate=True)
    except (ValueError, UnicodeError) as exc:
        raise ValueError(f"{asset_id}.attackSheetBase64Parts is not valid Base64: {exc}") from exc
    with Image.open(io.BytesIO(payload)) as opened:
        opened.load()
        return opened.convert("RGBA")


def audit(root: Path, manifest_file: Path = Path("data/art_manifest.json")) -> dict[str, Any]:
    root = root.resolve()
    manifest_file = manifest_file if manifest_file.is_absolute() else root / manifest_file
    manifest = json.loads(manifest_file.read_text(encoding="utf-8"))
    errors: list[str] = []
    skipped: list[dict[str, str]] = []
    clips: list[dict[str, Any]] = []

    for kind, folder in (("heroes", "Heroes"), ("enemies", "Enemies")):
        entries = manifest.get(kind, {})
        if not isinstance(entries, dict):
            errors.append(f"manifest.{kind} must be an object")
            continue
        for asset_id, meta in sorted(entries.items()):
            if not isinstance(meta, dict):
                skipped.append({"kind": kind, "id": asset_id, "reason": "metadata is not an object"})
                continue
            if meta.get("error"):
                skipped.append({"kind": kind, "id": asset_id, "reason": str(meta["error"])})
                continue
            source_name = str(meta.get("file", asset_id))
            extension = str(meta.get("extension", "png")).lower().lstrip(".")
            if Path(source_name).name != source_name or extension not in {"png", "jpg", "jpeg", "webp", "svg"}:
                errors.append(f"{asset_id} has an unsafe or unsupported sprite file reference")
                continue
            source = root / "assets" / "art" / folder / f"{source_name}.{extension}"
            try:
                width = positive_int(meta.get("cellW"), f"{asset_id}.cellW")
                height = positive_int(meta.get("cellH"), f"{asset_id}.cellH")
                if not source.is_file():
                    raise ValueError(f"missing sprite sheet: {source.relative_to(root).as_posix()}")
                sheet = open_image(source)

                if kind == "heroes":
                    rows, columns = meta.get("rows"), meta.get("cols")
                    if not isinstance(rows, list) or not rows or not isinstance(columns, list) or not columns:
                        raise ValueError(f"{asset_id} must define non-empty rows and cols")
                    expected = (width * len(columns), height * len(rows))
                    if sheet.size != expected:
                        raise ValueError(
                            f"{asset_id} is {sheet.width}x{sheet.height}; "
                            f"expected {expected[0]}x{expected[1]}"
                        )
                    walk_cols = [i for i, label in enumerate(columns) if str(label).startswith("walk")]
                    attack_cols = [
                        i for i, label in enumerate(columns)
                        if str(label) == "attack" or str(label).startswith("attack_")
                    ]
                    if not walk_cols:
                        raise ValueError(f"{asset_id} has no walk columns")

                    has_frame_files = "attackFrameFiles" in meta
                    has_base64_sheet = "attackSheetBase64Parts" in meta
                    if has_frame_files and (meta.get("attackSheet") or has_base64_sheet):
                        raise ValueError(f"{asset_id} cannot declare attackFrameFiles with an attack atlas")
                    if has_base64_sheet and meta.get("attackSheet"):
                        raise ValueError(f"{asset_id} cannot declare both attackSheet and attackSheetBase64Parts")
                    separate_rows: list[list[Image.Image]] | None = None
                    if has_frame_files:
                        declared = meta.get("attackFrames")
                        first_row = meta["attackFrameFiles"][0] if (
                            isinstance(meta.get("attackFrameFiles"), list)
                            and meta["attackFrameFiles"]
                            and isinstance(meta["attackFrameFiles"][0], list)
                        ) else None
                        attack_count = positive_int(
                            declared if declared is not None else (len(first_row) if first_row is not None else 0),
                            f"{asset_id}.attackFrames",
                        )
                        separate_rows = _load_separate_attack_frames(
                            root, root / "assets" / "art" / folder, meta["attackFrameFiles"],
                            rows, (width, height), asset_id, attack_count,
                        )

                    attack_sheet = None
                    attack_count = 0
                    if meta.get("attackSheet"):
                        attack_path = root / "assets" / "art" / folder / str(meta["attackSheet"])
                        if not attack_path.is_file():
                            raise ValueError(f"missing separate attack sheet: {meta['attackSheet']}")
                        attack_sheet = open_image(attack_path)
                    elif has_base64_sheet:
                        attack_sheet = _load_base64_attack_sheet(
                            root, root / "assets" / "art" / folder,
                            meta["attackSheetBase64Parts"], asset_id,
                        )
                    if attack_sheet is not None:
                        attack_count = positive_int(meta.get("attackFrames"), f"{asset_id}.attackFrames")
                        attack_expected = (width * attack_count, height * len(rows))
                        if attack_sheet.size != attack_expected:
                            raise ValueError(
                                f"separate attack atlas is {attack_sheet.size}; expected {attack_expected}"
                            )

                    for row, direction in enumerate(rows):
                        frames = [crop(sheet, col, row, width, height) for col in walk_cols]
                        metrics = frame_metrics(frames)
                        name = f"walk_{direction}"
                        clips.append({
                            "kind": kind, "asset_id": asset_id, "clip": name, **metrics,
                            "warnings": clip_warnings(metrics, kind, name),
                        })

                        if separate_rows is not None:
                            attack_frames = separate_rows[row]
                        elif attack_sheet is not None:
                            attack_frames = [
                                crop(attack_sheet, col, row, width, height)
                                for col in range(attack_count)
                            ]
                        else:
                            attack_frames = [crop(sheet, col, row, width, height) for col in attack_cols]
                        if attack_frames:
                            metrics = frame_metrics(attack_frames)
                            name = f"attack_{direction}"
                            clip_data: dict[str, Any] = {
                                "kind": kind, "asset_id": asset_id, "clip": name, **metrics,
                                "warnings": clip_warnings(metrics, kind, name),
                            }
                            if "attackFps" in meta:
                                fps = float(meta["attackFps"])
                                if fps <= 0.0:
                                    raise ValueError(f"{asset_id}.attackFps must be positive")
                                clip_data["fps"] = fps
                                impact_frame = int(meta.get("attackImpactFrame", 0))
                                if not 0 <= impact_frame < len(attack_frames):
                                    raise ValueError(
                                        f"{asset_id}.attackImpactFrame {impact_frame} is outside its attack clip"
                                    )
                                clip_data["impact_frame"] = impact_frame
                                clip_data["impact_time_ms"] = round(impact_frame * 1000.0 / fps, 2)
                            clips.append(clip_data)
                else:
                    count = positive_int(meta.get("frames"), f"{asset_id}.frames")
                    variants = positive_int(meta.get("variants", 1), f"{asset_id}.variants")
                    expected = (width * count, height * variants)
                    if sheet.size != expected:
                        raise ValueError(
                            f"{asset_id} is {sheet.size}; expected {expected[0]}x{expected[1]}"
                        )
                    for variant in range(variants):
                        frames = [crop(sheet, col, variant, width, height) for col in range(count)]
                        metrics = frame_metrics(frames)
                        name = f"variant_{variant}"
                        clips.append({
                            "kind": kind, "asset_id": asset_id, "clip": name, **metrics,
                            "warnings": clip_warnings(metrics, kind, name),
                        })
            except (OSError, ValueError, TypeError, IndexError, json.JSONDecodeError) as exc:
                errors.append(f"{source.relative_to(root).as_posix()}: {exc}")

    warning_counts: Counter[str] = Counter()
    for clip_data in clips:
        warning_counts.update(clip_data["warnings"])
    hero_attacks = [item for item in clips if item["kind"] == "heroes" and item["clip"].startswith("attack_")]
    hero_walks = [item for item in clips if item["kind"] == "heroes" and item["clip"].startswith("walk_")]
    enemy_clips = [item for item in clips if item["kind"] == "enemies"]
    attack_frame_counts = Counter(item["frame_count"] for item in hero_attacks)
    return {
        "manifest": manifest_file.relative_to(root).as_posix(),
        "hero_looks": len({item["asset_id"] for item in clips if item["kind"] == "heroes"}),
        "hero_walk_clips": len(hero_walks),
        "hero_attack_clips": len(hero_attacks),
        "hero_attack_frame_counts": dict(sorted(attack_frame_counts.items())),
        "hero_attack_single_pose_clips": sum(1 for item in hero_attacks if item["frame_count"] == 1),
        "hero_attack_multiframe_clips": sum(1 for item in hero_attacks if item["frame_count"] > 1),
        "enemy_sprite_sheets": len({item["asset_id"] for item in enemy_clips}),
        "enemy_variant_clips": len(enemy_clips),
        "enemy_variant_frame_counts": dict(sorted(Counter(item["frame_count"] for item in enemy_clips).items())),
        "clips_audited": len(clips),
        "warning_counts": dict(sorted(warning_counts.items())),
        "skipped": skipped,
        "errors": errors,
        "clips": clips,
        "notes": [
            "Pixel-difference metrics flag duplicate or nearly static frames; they do not grade drawing quality or acting.",
            "One- and two-frame enemy cycles are review prompts, not automatic defects; hovering or static designs may be intentional.",
            "A valid four-frame walk cycle does not imply dedicated block, dodge, hurt, death or ultimate clips.",
            "Separate hero attack frame files and atlases are measured when registered in art_manifest.json.",
            "Contact-frame timing is reported only when attackFps is registered in the manifest.",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--manifest", type=Path, default=Path("data/art_manifest.json"))
    parser.add_argument(
        "--report", type=Path, default=Path("artifacts/animation-review/animation-quality-report.json")
    )
    args = parser.parse_args()
    try:
        report = audit(args.root, args.manifest)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"ANIMATION_QUALITY_AUDIT_FAILED: {exc}", file=sys.stderr)
        return 1
    output = args.report if args.report.is_absolute() else args.root / args.report
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Hero looks: {report['hero_looks']}")
    print(f"Hero walk clips: {report['hero_walk_clips']}")
    print(f"Hero attack clips: {report['hero_attack_clips']}")
    print(f"Hero attacks with one pose: {report['hero_attack_single_pose_clips']}")
    print(f"Hero attacks with multiple frames: {report['hero_attack_multiframe_clips']}")
    print(f"Hero attack frame counts: {report['hero_attack_frame_counts']}")
    print(f"Enemy sprite sheets: {report['enemy_sprite_sheets']}")
    print(f"Enemy variant clips: {report['enemy_variant_clips']}")
    print(f"Warnings by type: {report['warning_counts']}")
    for error in report["errors"]:
        print(f"ERROR: {error}", file=sys.stderr)
    print("ANIMATION_QUALITY_AUDIT_PASSED" if not report["errors"] else "ANIMATION_QUALITY_AUDIT_FAILED")
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
