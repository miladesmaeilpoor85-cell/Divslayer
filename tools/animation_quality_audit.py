"""Measure sprite-frame variation and alignment without modifying production art."""
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
DIFF_THRESHOLD = 12
LOW_MOTION_RATIO = 0.02
FOOT_DRIFT_LIMIT = 2


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

    normalized = []
    visible_ratios = []
    baselines = []
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
    changes = []
    for before, after in zip(normalized, normalized[1:]):
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
        "foot_baseline_range_px": max(baselines) - min(baselines) if len(baselines) > 1 else 0,
    }


def clip_warnings(metrics: dict[str, Any], kind: str, name: str) -> list[str]:
    result = []
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
    if kind == "heroes" and metrics["foot_baseline_range_px"] > FOOT_DRIFT_LIMIT:
        result.append("hero_foot_baseline_drift")
    return result


def crop(sheet: Image.Image, column: int, row: int, width: int, height: int) -> Image.Image:
    return sheet.crop((column * width, row * height, (column + 1) * width, (row + 1) * height))


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
            source = root / "assets" / "art" / folder / f"{asset_id}.png"
            try:
                width = positive_int(meta.get("cellW"), f"{asset_id}.cellW")
                height = positive_int(meta.get("cellH"), f"{asset_id}.cellH")
                if not source.is_file():
                    raise ValueError(f"missing sprite sheet: {source.relative_to(root).as_posix()}")
                with Image.open(source) as opened:
                    opened.load()
                    sheet = opened.convert("RGBA")

                if kind == "heroes":
                    rows, columns = meta.get("rows"), meta.get("cols")
                    if not isinstance(rows, list) or not rows or not isinstance(columns, list) or not columns:
                        raise ValueError(f"{asset_id} must define non-empty rows and cols")
                    expected = (width * len(columns), height * len(rows))
                    if sheet.size != expected:
                        raise ValueError(f"{asset_id} is {sheet.width}x{sheet.height}; expected {expected[0]}x{expected[1]}")
                    walk_cols = [i for i, label in enumerate(columns) if str(label).startswith("walk")]
                    attack_cols = [i for i, label in enumerate(columns) if str(label) == "attack" or str(label).startswith("attack_")]
                    if not walk_cols:
                        raise ValueError(f"{asset_id} has no walk columns")
                    attack_sheet = None
                    attack_path = None
                    if meta.get("attackSheet"):
                        attack_path = root / "assets" / "art" / folder / str(meta["attackSheet"])
                        if not attack_path.is_file():
                            raise ValueError(f"missing separate attack sheet: {meta['attackSheet']}")
                        with Image.open(attack_path) as opened:
                            opened.load()
                            attack_sheet = opened.convert("RGBA")
                        attack_count = positive_int(meta.get("attackFrames"), f"{asset_id}.attackFrames")
                        attack_expected = (width * attack_count, height * len(rows))
                        if attack_sheet.size != attack_expected:
                            raise ValueError(f"{meta['attackSheet']} is {attack_sheet.size}; expected {attack_expected}")
                    for row, direction in enumerate(rows):
                        frames = [crop(sheet, col, row, width, height) for col in walk_cols]
                        metrics = frame_metrics(frames)
                        name = f"walk_{direction}"
                        clips.append({"kind": kind, "asset_id": asset_id, "clip": name, **metrics, "warnings": clip_warnings(metrics, kind, name)})
                        if attack_sheet is not None:
                            attack_frames = [crop(attack_sheet, col, row, width, height) for col in range(attack_count)]
                        else:
                            attack_frames = [crop(sheet, col, row, width, height) for col in attack_cols]
                        if attack_frames:
                            metrics = frame_metrics(attack_frames)
                            name = f"attack_{direction}"
                            clips.append({"kind": kind, "asset_id": asset_id, "clip": name, **metrics, "warnings": clip_warnings(metrics, kind, name)})
                else:
                    count = positive_int(meta.get("frames"), f"{asset_id}.frames")
                    variants = positive_int(meta.get("variants", 1), f"{asset_id}.variants")
                    expected = (width * count, height * variants)
                    if sheet.size != expected:
                        raise ValueError(f"{asset_id} is {sheet.size}; expected {expected}")
                    for variant in range(variants):
                        frames = [crop(sheet, col, variant, width, height) for col in range(count)]
                        metrics = frame_metrics(frames)
                        name = f"variant_{variant}"
                        clips.append({"kind": kind, "asset_id": asset_id, "clip": name, **metrics, "warnings": clip_warnings(metrics, kind, name)})
            except (OSError, ValueError, TypeError, json.JSONDecodeError) as exc:
                errors.append(f"{source.relative_to(root).as_posix()}: {exc}")

    warning_counts: Counter[str] = Counter()
    for clip_data in clips:
        warning_counts.update(clip_data["warnings"])
    hero_attacks = [item for item in clips if item["kind"] == "heroes" and item["clip"].startswith("attack_")]
    hero_walks = [item for item in clips if item["kind"] == "heroes" and item["clip"].startswith("walk_")]
    enemy_clips = [item for item in clips if item["kind"] == "enemies"]
    return {
        "manifest": manifest_file.relative_to(root).as_posix(),
        "hero_looks": len({item["asset_id"] for item in clips if item["kind"] == "heroes"}),
        "hero_walk_clips": len(hero_walks),
        "hero_attack_clips": len(hero_attacks),
        "hero_attack_frame_counts": dict(sorted(Counter(item["frame_count"] for item in hero_attacks).items())),
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
            "A valid four-frame walk cycle does not imply dedicated attack, block, dodge, hurt, or death clips.",
            "Separate hero attack atlases are measured when attackSheet and attackFrames are registered in the manifest.",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--manifest", type=Path, default=Path("data/art_manifest.json"))
    parser.add_argument("--report", type=Path, default=Path("artifacts/animation-review/animation-quality-report.json"))
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
    print(f"Enemy sprite sheets: {report['enemy_sprite_sheets']}")
    print(f"Enemy variant clips: {report['enemy_variant_clips']}")
    print(f"Warnings by type: {report['warning_counts']}")
    for error in report["errors"]:
        print(f"ERROR: {error}", file=sys.stderr)
    print("ANIMATION_QUALITY_AUDIT_PASSED" if not report["errors"] else "ANIMATION_QUALITY_AUDIT_FAILED")
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
