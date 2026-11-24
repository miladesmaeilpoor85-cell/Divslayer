"""Validate sprite-sheet layouts and export reviewable animation previews.

The tool reads data/art_manifest.json and never modifies production artwork.
It creates GIF previews for multi-frame animations and PNG previews for
single-frame poses, composited over a checkerboard with a pivot guide.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from image_assets import open_image
from PIL import Image, ImageDraw

DEFAULT_ROOT = Path(__file__).resolve().parents[1]
CHECKER_A = (54, 58, 66, 255)
CHECKER_B = (76, 80, 88, 255)
GUIDE = (245, 200, 95, 255)


def _positive_int(value: Any, field: str) -> int:
    try:
        number = int(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{field} must be an integer") from exc
    if number < 1:
        raise ValueError(f"{field} must be positive")
    return number


def _checkerboard(width: int, height: int, square: int) -> Image.Image:
    canvas = Image.new("RGBA", (width, height), CHECKER_A)
    draw = ImageDraw.Draw(canvas)
    for y in range(0, height, square):
        for x in range(0, width, square):
            if ((x // square) + (y // square)) % 2:
                draw.rectangle(
                    (x, y, min(width - 1, x + square - 1), min(height - 1, y + square - 1)),
                    fill=CHECKER_B,
                )
    return canvas


def _compose_frame(
    cell: Image.Image,
    cell_size: tuple[int, int],
    pivot: list[float],
    scale: int,
) -> Image.Image:
    width, height = cell_size
    frame = _checkerboard(width * scale, height * scale, max(4, 8 * scale))
    sprite = cell.convert("RGBA").resize(
        (width * scale, height * scale), Image.Resampling.NEAREST
    )
    frame.alpha_composite(sprite)
    pivot_y = float(pivot[1]) if len(pivot) > 1 else 0.0
    guide_y = max(
        0, min(frame.height - 1, round(height * (1.0 - pivot_y) * scale))
    )
    ImageDraw.Draw(frame).line(
        (0, guide_y, frame.width - 1, guide_y),
        fill=GUIDE,
        width=max(1, scale),
    )
    return frame.convert("RGB")


def _save_animation(
    frames: list[Image.Image], destination: Path, fps: float
) -> None:
    if not frames:
        raise ValueError("animation has no frames")
    # GIF stores frame delays in 10 ms units; Pillow quantizes the value.
    duration_ms = max(20, round((1000.0 / fps) / 10.0) * 10)
    frames[0].save(
        destination,
        save_all=True,
        append_images=frames[1:],
        duration=duration_ms,
        loop=0,
        optimize=True,
        disposal=2,
    )


def _save_still(frame: Image.Image, destination: Path) -> None:
    frame.save(destination, format="PNG", optimize=True)


def _validate_metadata(
    key: str, meta: dict[str, Any], kind: str
) -> tuple[int, int, list[float]]:
    width = _positive_int(meta.get("cellW"), f"{key}.cellW")
    height = _positive_int(meta.get("cellH"), f"{key}.cellH")
    pivot = meta.get("pivot", [0.5, 0.0])
    if not isinstance(pivot, list) or len(pivot) < 2:
        raise ValueError(f"{key}.pivot must contain x and y values")
    try:
        px, py = float(pivot[0]), float(pivot[1])
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{key}.pivot must contain numeric values") from exc
    if not (0.0 <= px <= 1.0 and 0.0 <= py <= 1.0):
        raise ValueError(f"{key}.pivot values must be between 0 and 1")
    if kind == "heroes":
        rows, cols = meta.get("rows"), meta.get("cols")
        if (
            not isinstance(rows, list)
            or not rows
            or not isinstance(cols, list)
            or not cols
        ):
            raise ValueError(f"{key} must define non-empty rows and cols")
    else:
        _positive_int(meta.get("frames"), f"{key}.frames")
        _positive_int(meta.get("variants", 1), f"{key}.variants")
    return width, height, [px, py]


def _cell(
    image: Image.Image, x: int, y: int, width: int, height: int
) -> Image.Image:
    return image.crop(
        (x * width, y * height, (x + 1) * width, (y + 1) * height)
    )


def review_sheets(
    root: Path,
    manifest_path: Path,
    output_dir: Path,
    scale: int = 2,
) -> dict[str, Any]:
    if scale < 1:
        raise ValueError("scale must be at least 1")
    root = root.resolve()
    manifest_path = manifest_path if manifest_path.is_absolute() else root / manifest_path
    output_dir = output_dir if output_dir.is_absolute() else root / output_dir
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    output_dir.mkdir(parents=True, exist_ok=True)

    report: dict[str, Any] = {
        "manifest": (
            manifest_path.relative_to(root).as_posix()
            if manifest_path.is_relative_to(root)
            else str(manifest_path)
        ),
        "scale": scale,
        "checked": 0,
        "valid": 0,
        "skipped": [],
        "errors": [],
        "previews": [],
        "hero_attack_audit": [],
    }

    for kind, folder in (("heroes", "Heroes"), ("enemies", "Enemies")):
        entries = manifest.get(kind, {})
        if not isinstance(entries, dict):
            report["errors"].append(f"manifest.{kind} must be an object")
            continue
        for key, meta in sorted(entries.items()):
            if not isinstance(meta, dict):
                report["skipped"].append(
                    {"kind": kind, "id": key, "reason": "metadata is not an object"}
                )
                continue
            if meta.get("error"):
                report["skipped"].append(
                    {"kind": kind, "id": key, "reason": str(meta["error"])}
                )
                continue

            report["checked"] += 1
            source_name = str(meta.get("file", key))
            extension = str(meta.get("extension", "png")).lower().lstrip(".")
            if Path(source_name).name != source_name or extension not in {"png", "jpg", "jpeg", "webp", "svg"}:
                report["errors"].append(f"{key} has an unsafe or unsupported sprite file reference")
                continue
            relative = Path("assets") / "art" / folder / f"{source_name}.{extension}"
            source = root / relative
            try:
                cell_w, cell_h, pivot = _validate_metadata(key, meta, kind)
                if not source.is_file():
                    raise ValueError(f"missing sprite sheet: {relative.as_posix()}")
                sheet = open_image(source)

                if kind == "heroes":
                    rows, cols = meta["rows"], meta["cols"]
                    expected = (cell_w * len(cols), cell_h * len(rows))
                    walk_indices = [
                        i for i, name in enumerate(cols)
                        if str(name).startswith("walk")
                    ]
                    attack_indices = [
                        i for i, name in enumerate(cols) if str(name).startswith("attack")
                    ]
                    attack_fps = float(meta.get("attackFps", 24.0))
                    if attack_fps <= 0.0:
                        raise ValueError(f"{key}.attackFps must be positive")
                    separate_attack = None
                    separate_attack_relative = ""
                    if meta.get("attackSheet"):
                        attack_name = str(meta["attackSheet"])
                        if Path(attack_name).name != attack_name or "/" in attack_name or "\\" in attack_name:
                            raise ValueError(f"{key}.attackSheet must be a filename inside Heroes")
                        separate_attack_relative = (Path("assets") / "art" / folder / attack_name).as_posix()
                        attack_path = root / separate_attack_relative
                        if not attack_path.is_file():
                            raise ValueError(f"missing separate attack atlas: {separate_attack_relative}")
                        separate_attack = open_image(attack_path)
                        attack_count = _positive_int(meta.get("attackFrames"), f"{key}.attackFrames")
                        attack_expected = (cell_w * attack_count, cell_h * len(rows))
                        if separate_attack.size != attack_expected:
                            raise ValueError(
                                f"{separate_attack_relative} is {separate_attack.width}x{separate_attack.height}; "
                                f"expected {attack_expected[0]}x{attack_expected[1]}"
                            )
                        if attack_count < 2:
                            raise ValueError(f"{key}.attackFrames must contain at least two frames")
                    else:
                        attack_count = len(attack_indices)
                        if attack_count < 1:
                            raise ValueError(f"{key} has no attack columns or separate attack atlas")
                    if len(walk_indices) < 2:
                        raise ValueError(
                            f"{key} needs at least two walk columns for a loop preview"
                        )
                    fps = 9.0
                else:
                    frames_count = _positive_int(meta["frames"], f"{key}.frames")
                    variants = _positive_int(
                        meta.get("variants", 1), f"{key}.variants"
                    )
                    expected = (cell_w * frames_count, cell_h * variants)
                    walk_indices = list(range(frames_count))
                    attack_indices = []
                    timed_ms = meta.get("timedMs")
                    if timed_ms is None:
                        fps = 7.0
                    else:
                        timed_ms_value = float(timed_ms)
                        if timed_ms_value <= 0:
                            raise ValueError(f"{key}.timedMs must be positive")
                        fps = 1000.0 / timed_ms_value

                if sheet.size != expected:
                    raise ValueError(
                        f"{relative.as_posix()} is {sheet.width}x{sheet.height}; "
                        f"expected {expected[0]}x{expected[1]}"
                    )

                previews_for_sheet: list[str] = []
                if kind == "heroes":
                    for row_index, direction in enumerate(rows):
                        frames = [
                            _compose_frame(
                                _cell(sheet, col_index, row_index, cell_w, cell_h),
                                (cell_w, cell_h),
                                pivot,
                                scale,
                            )
                            for col_index in walk_indices
                        ]
                        name = f"hero-{key}-{direction}-walk.gif"
                        _save_animation(frames, output_dir / name, fps)
                        previews_for_sheet.append(name)
                        attack_frames = [
                            _compose_frame(
                                _cell(
                                    separate_attack if separate_attack is not None else sheet,
                                    frame_index if separate_attack is not None else attack_indices[frame_index],
                                    row_index, cell_w, cell_h,
                                ),
                                (cell_w, cell_h), pivot, scale,
                            )
                            for frame_index in range(attack_count)
                        ]
                        if len(attack_frames) > 1:
                            attack_preview = f"hero-{key}-{direction}-attack.gif"
                            _save_animation(attack_frames, output_dir / attack_preview, attack_fps)
                        else:
                            attack_preview = f"hero-{key}-{direction}-attack.png"
                            _save_still(attack_frames[0], output_dir / attack_preview)
                        previews_for_sheet.append(attack_preview)
                else:
                    variants = _positive_int(
                        meta.get("variants", 1), f"{key}.variants"
                    )
                    for variant in range(variants):
                        frames = [
                            _compose_frame(
                                _cell(sheet, frame_index, variant, cell_w, cell_h),
                                (cell_w, cell_h),
                                pivot,
                                scale,
                            )
                            for frame_index in walk_indices
                        ]
                        if len(frames) > 1:
                            name = f"enemy-{key}-variant-{variant}-loop.gif"
                            _save_animation(frames, output_dir / name, fps)
                        else:
                            name = f"enemy-{key}-variant-{variant}-still.png"
                            _save_still(frames[0], output_dir / name)
                        previews_for_sheet.append(name)

                if kind == "heroes":
                    report["hero_attack_audit"].append({
                        "id": key,
                        "source": separate_attack_relative if separate_attack is not None else relative.as_posix(),
                        "frame_count": attack_count,
                        "frame_rate": round(attack_fps, 3),
                        "status": "multi_frame_attack_preview" if attack_count > 1 else "single_frame_attack_placeholder",
                    })
                report["valid"] += 1
                report["previews"].append(
                    {
                        "kind": kind,
                        "id": key,
                        "source": relative.as_posix(),
                        "cell_size": [cell_w, cell_h],
                        "sheet_size": list(sheet.size),
                        "expected_size": list(expected),
                        "frame_rate": round(fps, 3),
                        "preview_files": previews_for_sheet,
                        "status": "valid",
                    }
                )
            except (OSError, ValueError, TypeError, ZeroDivisionError) as exc:
                report["errors"].append(f"{relative.as_posix()}: {exc}")

    report_path = output_dir / "animation-review.json"
    report_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--manifest", type=Path, default=Path("data/art_manifest.json"))
    parser.add_argument("--output", type=Path, default=Path("artifacts/animation-review"))
    parser.add_argument(
        "--scale", type=int, default=2,
        help="nearest-neighbour preview scale (default: 2)",
    )
    args = parser.parse_args()
    if args.scale < 1:
        parser.error("--scale must be at least 1")
    try:
        report = review_sheets(args.root, args.manifest, args.output, args.scale)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"ANIMATION_REVIEW_FAILED: {exc}", file=sys.stderr)
        return 1

    print(f"Sprite sheets checked: {report['checked']}")
    print(f"Valid sheets: {report['valid']}")
    print(f"Multi-frame hero attacks: {sum(item['frame_count'] > 1 for item in report['hero_attack_audit'])}")
    print(f"Single-frame hero attack placeholders: {sum(item['frame_count'] == 1 for item in report['hero_attack_audit'])}")
    print(f"Skipped metadata entries: {len(report['skipped'])}")
    print(
        "Animation previews written: "
        f"{sum(len(item['preview_files']) for item in report['previews'])}"
    )
    for error in report["errors"]:
        print(f"ERROR: {error}", file=sys.stderr)
    print("ANIMATION_REVIEW_PASSED" if not report["errors"] else "ANIMATION_REVIEW_FAILED")
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
