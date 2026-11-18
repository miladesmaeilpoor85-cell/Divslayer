"""Decode and inventory every game audio asset using FFmpeg/ffprobe."""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

AUDIO_EXTENSIONS = {".ogg", ".wav", ".mp3", ".flac"}


def parse_probe_payload(payload: dict[str, Any]) -> dict[str, Any]:
    streams = [stream for stream in payload.get("streams", []) if stream.get("codec_type") == "audio"]
    if not streams:
        raise ValueError("ffprobe found no audio stream")
    audio = streams[0]
    raw_duration = payload.get("format", {}).get("duration")
    try:
        duration = float(raw_duration)
    except (TypeError, ValueError) as exc:
        raise ValueError("missing or invalid audio duration") from exc
    if duration <= 0:
        raise ValueError("audio duration must be positive")
    try:
        sample_rate = int(audio.get("sample_rate", 0))
        channels = int(audio.get("channels", 0))
    except (TypeError, ValueError) as exc:
        raise ValueError("invalid audio stream metadata") from exc
    if sample_rate <= 0 or channels <= 0:
        raise ValueError("audio stream has invalid sample rate or channel count")
    return {
        "codec": str(audio.get("codec_name", "unknown")),
        "sample_rate_hz": sample_rate,
        "channels": channels,
        "duration_seconds": round(duration, 3),
        "bit_rate": audio.get("bit_rate") or payload.get("format", {}).get("bit_rate"),
    }


def run_checked(command: list[str], file_path: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [*command, str(file_path)],
        check=True,
        capture_output=True,
        text=True,
        timeout=180,
    )


def audit_audio(root: Path) -> dict[str, Any]:
    root = root.resolve()
    ffmpeg = shutil.which("ffmpeg")
    ffprobe = shutil.which("ffprobe")
    if not ffmpeg or not ffprobe:
        raise RuntimeError("FFmpeg and ffprobe must be installed on the audit runner")

    audio_root = root / "assets" / "audio"
    if not audio_root.is_dir():
        raise FileNotFoundError(f"audio directory does not exist: {audio_root}")
    files = sorted(path for path in audio_root.rglob("*") if path.is_file() and path.suffix.lower() in AUDIO_EXTENSIONS)
    results: list[dict[str, Any]] = []
    errors: list[str] = []

    for path in files:
        rel = path.relative_to(root).as_posix()
        try:
            probe = run_checked(
                [
                    ffprobe,
                    "-v", "error",
                    "-show_entries", "format=duration,bit_rate:stream=codec_type,codec_name,sample_rate,channels,bit_rate",
                    "-of", "json",
                ],
                path,
            )
            metadata = parse_probe_payload(json.loads(probe.stdout))
            decode = subprocess.run(
                [ffmpeg, "-v", "error", "-xerror", "-i", str(path), "-map", "0:a:0", "-f", "null", "-"],
                check=True,
                capture_output=True,
                text=True,
                timeout=180,
            )
            del decode
            metadata["path"] = rel
            metadata["size_bytes"] = path.stat().st_size
            results.append(metadata)
        except (OSError, subprocess.SubprocessError, json.JSONDecodeError, ValueError) as exc:
            detail = getattr(exc, "stderr", "") or str(exc)
            errors.append(f"{rel}: {detail.strip()[-1200:]}")

    return {
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
    try:
        report = audit_audio(args.root)
    except (FileNotFoundError, RuntimeError) as exc:
        print(f"AUDIO_AUDIT_FAILED: {exc}", file=sys.stderr)
        return 1

    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Audio files decoded: {report['files_passed']}/{report['files_checked']}")
    print(f"Total playable duration: {report['total_duration_seconds'] / 3600:.2f} hours")
    print(f"Codecs: {report['codecs']}")
    for error in report["errors"]:
        print(f"ERROR: {error}", file=sys.stderr)
    print("AUDIO_AUDIT_PASSED" if not report["errors"] else "AUDIO_AUDIT_FAILED")
    return 1 if report["errors"] or report["files_checked"] == 0 else 0


if __name__ == "__main__":
    sys.exit(main())
