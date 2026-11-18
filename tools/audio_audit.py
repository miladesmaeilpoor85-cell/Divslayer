"""Decode and inventory every game audio asset with FFmpeg through PyAV."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import av

AUDIO_EXTENSIONS = {".ogg", ".wav", ".mp3", ".flac"}


def stream_metadata(stream: Any, duration: float) -> dict[str, Any]:
    context = stream.codec_context
    sample_rate = int(context.sample_rate or 0)
    channels = int(context.layout.nb_channels)
    if duration <= 0:
        raise ValueError("audio duration must be positive")
    if sample_rate <= 0 or channels <= 0:
        raise ValueError("audio stream has invalid sample rate or channel count")
    return {
        "codec": str(context.name),
        "sample_rate_hz": sample_rate,
        "channels": channels,
        "duration_seconds": round(duration, 3),
    }


def _stream_duration(container: Any, stream: Any) -> float:
    if stream.duration is not None and stream.time_base is not None:
        return float(stream.duration * stream.time_base)
    if container.duration is not None:
        return float(container.duration) / float(av.time_base)
    raise ValueError("FFmpeg could not determine audio duration")


def decode_file(path: Path) -> dict[str, Any]:
    with av.open(str(path), mode="r") as container:
        streams = list(container.streams.audio)
        if not streams:
            raise ValueError("FFmpeg found no audio stream")
        stream = streams[0]
        metadata = stream_metadata(stream, _stream_duration(container, stream))
        frames = 0
        decoded_samples = 0
        for frame in container.decode(stream):
            frames += 1
            decoded_samples += int(frame.samples)
        if frames == 0 or decoded_samples == 0:
            raise ValueError("audio stream decoded no samples")
        metadata["decoded_frames"] = frames
        metadata["decoded_samples"] = decoded_samples
        metadata["container"] = str(container.format.name)
        return metadata


def audit_audio(root: Path) -> dict[str, Any]:
    root = root.resolve()
    audio_root = root / "assets" / "audio"
    if not audio_root.is_dir():
        raise FileNotFoundError(f"audio directory does not exist: {audio_root}")
    files = sorted(path for path in audio_root.rglob("*") if path.is_file() and path.suffix.lower() in AUDIO_EXTENSIONS)
    results: list[dict[str, Any]] = []
    errors: list[str] = []

    for path in files:
        rel = path.relative_to(root).as_posix()
        try:
            metadata = decode_file(path)
            metadata["path"] = rel
            metadata["size_bytes"] = path.stat().st_size
            results.append(metadata)
        except Exception as exc:  # noqa: BLE001 - PyAV codec errors vary by bundled FFmpeg library.
            errors.append(f"{rel}: {type(exc).__name__}: {str(exc)[-1200:]}")

    return {
        "pyav_version": av.__version__,
        "ffmpeg_libraries": {name: list(version) for name, version in av.library_versions.items()},
        "files_checked": len(files),
        "files_passed": len(results),
        "total_duration_seconds": round(sum(item["duration_seconds"] for item in results), 3),
        "codecs": dict(sorted(_count_by(results, "codec").items())),
        "sample_rates_hz": dict(sorted(_count_by(results, "sample_rate_hz").items())),
        "channel_layouts": dict(sorted(_count_by(results, "channels").items())),
        "files": results,
        "errors": errors,
    }


def _count_by(rows: list[dict[str, Any]], key: str) -> dict[str, int]:
    counts: dict[str, int] = {}
    for row in rows:
        value = str(row[key])
        counts[value] = counts.get(value, 0) + 1
    return counts


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--report", type=Path, default=Path("artifacts/audio-report.json"))
    args = parser.parse_args()
    report = audit_audio(args.root)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PyAV / FFmpeg libraries: {report['pyav_version']} / {report['ffmpeg_libraries']}")
    print(f"Audio files decoded: {report['files_passed']}/{report['files_checked']}")
    print(f"Total playable duration: {report['total_duration_seconds'] / 3600:.2f} hours")
    print(f"Codecs: {report['codecs']}")
    for error in report["errors"]:
        print(f"ERROR: {error}", file=sys.stderr)
    print("AUDIO_AUDIT_PASSED" if not report["errors"] else "AUDIO_AUDIT_FAILED")
    return 1 if report["errors"] or report["files_checked"] == 0 else 0


if __name__ == "__main__":
    sys.exit(main())
