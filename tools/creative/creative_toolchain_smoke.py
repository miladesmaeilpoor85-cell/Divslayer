#!/usr/bin/env python3
"""Non-destructive smoke tests for the creative applications used by Divslayer.

This script creates temporary QA assets only. It never edits files under assets/.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import signal
import subprocess
import sys
import time
import wave
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

from PIL import Image


def run(
    command: list[str],
    *,
    timeout: int = 90,
    env: dict[str, str] | None = None,
    log_path: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        check=False,
        capture_output=True,
        text=True,
        timeout=timeout,
        env=env,
    )
    if log_path is not None:
        log_path.write_text(
            (result.stdout or "") + (result.stderr or ""),
            encoding="utf-8",
        )
    if result.returncode != 0:
        details = (result.stdout or "") + (result.stderr or "")
        raise RuntimeError(
            f"Command failed ({result.returncode}): {' '.join(command)}\n{details[-6000:]}"
        )
    return result


def executable(name: str) -> str:
    path = shutil.which(name)
    if path is None:
        raise RuntimeError(f"Required creative tool is not installed: {name}")
    return path


def get_version(name: str, binary: str, version_args: tuple[str, ...] = ("--version",)) -> str:
    command = [binary, *version_args]
    if name == "Krita":
        command = ["xvfb-run", "-a", *command]
    result = run(command, timeout=45)
    text = (result.stdout or result.stderr).strip()
    return "\n".join(text.splitlines()[:4]) or "version output unavailable"


def inspect_png(path: Path) -> tuple[int, int]:
    with Image.open(path) as image:
        image.verify()
    with Image.open(path) as image:
        if image.format != "PNG":
            raise RuntimeError(f"{path} is not a PNG")
        return image.size


def run_blender(blender: str, out: Path, root: Path) -> Path:
    render_path = out / "blender-procedural-preview.png"
    scene_script = root / "tools/creative/blender_smoke_scene.py"
    run(
        [
            blender,
            "--background",
            "--factory-startup",
            "--python",
            str(scene_script),
            "--",
            str(out),
        ],
        timeout=180,
        log_path=out / "blender.log",
    )
    if not render_path.is_file() or render_path.stat().st_size < 1024:
        raise RuntimeError("Blender did not create the expected render")
    inspect_png(render_path)
    return render_path


def run_krita(krita: str, source: Path, out: Path) -> Path:
    destination = out / "krita-roundtrip.png"
    run(
        [
            "xvfb-run",
            "-a",
            krita,
            str(source),
            "--export",
            "--export-filename",
            str(destination),
        ],
        timeout=180,
        log_path=out / "krita.log",
    )
    if not destination.is_file() or destination.stat().st_size < 1024:
        raise RuntimeError("Krita did not create the expected exported image")
    if inspect_png(destination) != inspect_png(source):
        raise RuntimeError("Krita round-trip changed the image dimensions")
    return destination


def find_lmms_template() -> Path | None:
    roots = [Path("/usr/share/lmms"), Path("/usr/local/share/lmms")]
    preferred = ("empty.mpt", "Empty.mpt", "default.mpt", "Default.mpt")
    for root in roots:
        if not root.exists():
            continue
        for name in preferred:
            matches = list(root.rglob(name))
            if matches:
                return matches[0]
    return None


def make_lmms_smoke_project(out: Path) -> tuple[Path | None, str]:
    template = find_lmms_template()
    if template is None:
        return None, "No installed LMMS starter template was found; renderer smoke test skipped."

    try:
        tree = ET.parse(template)
        root = tree.getroot()
        root.set("type", "song")
        song = root.find(".//song")
        if song is None:
            return None, f"Installed template has no song node: {template}"

        track = song.find(".//track[@type='0']")
        if track is None:
            return None, f"Installed template has no instrument track: {template}"

        pattern = track.find("pattern")
        if pattern is None:
            pattern = ET.SubElement(
                track,
                "pattern",
                {
                    "steps": "16",
                    "muted": "0",
                    "type": "0",
                    "name": "CI smoke melody",
                    "pos": "0",
                    "len": "192",
                    "frozen": "0",
                },
            )
        for note in list(pattern.findall("note")):
            pattern.remove(note)
        ET.SubElement(
            pattern,
            "note",
            {"key": "60", "vol": "100", "pos": "0", "pan": "0", "len": "48"},
        )

        project = out / "lmms-smoke-project.mmp"
        tree.write(project, encoding="utf-8", xml_declaration=True)
        return project, f"Generated one-note QA project from installed template: {template}"
    except (ET.ParseError, OSError, ValueError) as error:
        return None, f"Could not prepare LMMS smoke project: {error}"


def inspect_wav(path: Path) -> dict[str, Any]:
    if not path.is_file() or path.stat().st_size < 128:
        raise RuntimeError(f"LMMS did not create a usable WAV file: {path}")
    with wave.open(str(path), "rb") as audio:
        frames = audio.getnframes()
        rate = audio.getframerate()
        channels = audio.getnchannels()
        if frames <= 0 or rate <= 0 or channels not in (1, 2):
            raise RuntimeError(f"Invalid rendered WAV metadata: {path}")
        return {
            "sample_rate": rate,
            "channels": channels,
            "frames": frames,
            "duration_seconds": round(frames / rate, 3),
            "bytes": path.stat().st_size,
        }


def run_lmms(lmms: str, out: Path) -> dict[str, Any]:
    project, note = make_lmms_smoke_project(out)
    if project is None:
        return {"status": "installed_only", "note": note}

    rendered = out / "lmms-smoke-render.wav"
    run(
        [
            lmms,
            "render",
            str(project),
            "--output",
            str(rendered),
            "--format",
            "wav",
            "--samplerate",
            "44100",
        ],
        timeout=180,
        log_path=out / "lmms.log",
    )
    return {
        "status": "rendered",
        "note": note,
        "project": project.name,
        "render": rendered.name,
        "audio": inspect_wav(rendered),
    }


def run_audacity(audacity: str, source_audio: Path, out: Path) -> dict[str, Any]:
    """Open an existing OGG in Audacity under Xvfb without enabling remote scripting."""
    log_path = out / "audacity-gui.log"
    env = os.environ.copy()
    env["HOME"] = str(out / "audacity-home")
    Path(env["HOME"]).mkdir(parents=True, exist_ok=True)

    log_file = log_path.open("w", encoding="utf-8")
    process = subprocess.Popen(
        ["xvfb-run", "-a", audacity, str(source_audio)],
        stdout=log_file,
        stderr=subprocess.STDOUT,
        text=True,
        env=env,
        start_new_session=True,
    )
    try:
        time.sleep(8)
        return_code = process.poll()
        if return_code is not None:
            raise RuntimeError(
                f"Audacity exited during file-open smoke test ({return_code}); "
                f"see {log_path}"
            )
        return {
            "status": "launched_with_input",
            "source": str(source_audio),
            "observation_seconds": 8,
            "note": "Audacity process remained active during the observation window after receiving the OGG input argument; full audio decoding is verified separately by PyAV/FFmpeg.",
        }
    finally:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=5)
        log_file.close()


def native_source_inventory() -> dict[str, int]:
    tracked = subprocess.run(
        ["git", "ls-files", "-z"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.split("\0")
    suffixes = [Path(item).suffix.lower() for item in tracked if item]
    return {
        "krita": suffixes.count(".kra"),
        "blender": suffixes.count(".blend"),
        "lmms": suffixes.count(".mmp") + suffixes.count(".mmpz"),
        "audacity": suffixes.count(".aup3"),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    root = Path.cwd()
    source_inventory = native_source_inventory()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)

    binaries = {
        "Blender": executable("blender"),
        "Krita": executable("krita"),
        "LMMS": executable("lmms"),
        "Audacity": executable("audacity"),
    }
    versions = {
        name: get_version(name, binary, ("-version",) if name == "Audacity" else ("--version",))
        for name, binary in binaries.items()
    }

    blender_preview = run_blender(binaries["Blender"], out, root)
    krita_export = run_krita(binaries["Krita"], blender_preview, out)
    lmms_result = run_lmms(binaries["LMMS"], out)

    audio_source = root / "assets/audio/music/title.ogg"
    if not audio_source.is_file():
        raise RuntimeError(f"Expected existing game audio for Audacity smoke test: {audio_source}")
    audacity_result = run_audacity(binaries["Audacity"], audio_source, out)

    report = {
        "tool_versions": versions,
        "blender": {
            "status": "rendered",
            "output": blender_preview.name,
            "dimensions": inspect_png(blender_preview),
            "scene": "procedural QA scene only; not game artwork",
        },
        "krita": {
            "status": "exported",
            "input": blender_preview.name,
            "output": krita_export.name,
            "dimensions": inspect_png(krita_export),
            "note": "Non-destructive round-trip smoke test; no game asset was rewritten.",
        },
        "lmms": lmms_result,
        "audacity": audacity_result,
        "source_project_inventory": source_inventory,
    }
    (out / "creative-tools-report.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
