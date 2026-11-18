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
    if name == "Audacity":
        result = run(
            ["dpkg-query", "-W", "-f=${Version}", "audacity"],
            timeout=15,
        )
        return f"Audacity Debian package {result.stdout.strip()}"
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
    render_path = out / "flame-seal-relic-blender.png"
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
    scene_file = out / "flame-seal-relic.blend"
    if not scene_file.is_file() or scene_file.stat().st_size < 1024:
        raise RuntimeError("Blender did not save the editable source scene")
    inspect_png(render_path)
    return render_path



def create_krita_ora(source: Path, out: Path) -> Path:
    """Build an editable two-layer OpenRaster document from the Blender render."""
    import xml.etree.ElementTree as ET
    import zipfile

    base = Image.open(source).convert("RGBA")
    width, height = base.size
    finish = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    from PIL import ImageDraw

    draw = ImageDraw.Draw(finish)
    gold = (221, 165, 70, 105)
    warm_white = (255, 218, 151, 175)
    cx, cy = width // 2, height // 2
    # Fine engraved inner-rim highlights, kept on the editable Krita finish layer.
    ring_box = (
        int(width * 0.17),
        int(height * 0.17),
        int(width * 0.83),
        int(height * 0.83),
    )
    draw.ellipse(ring_box, outline=gold, width=max(1, width // 320))
    draw.arc(ring_box, start=205, end=252, fill=warm_white, width=max(2, width // 170))
    draw.arc(ring_box, start=28, end=75, fill=warm_white, width=max(2, width // 170))

    # Small diamond glints sit inside the medallion rather than outside its silhouette.
    radius = int(min(width, height) * 0.34)
    for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        x, y = cx + dx * radius * 0.72, cy + dy * radius * 0.72
        size = max(3, width // 95)
        draw.polygon(
            ((x, y - size), (x + size * 0.55, y), (x, y + size), (x - size * 0.55, y)),
            fill=warm_white,
        )

    merged = Image.alpha_composite(base, finish)
    ora = out / "flame-seal-relic-layered.ora"
    stack = ET.Element("image", {"version": "0.0.1", "w": str(width), "h": str(height), "name": "Flame Seal Relic"})
    stack_el = ET.SubElement(stack, "stack")
    ET.SubElement(
        stack_el,
        "layer",
        {
            "name": "Krita finishing — rim glints",
            "src": "data/01-krita-finishing.png",
            "opacity": "1.0",
            "visibility": "visible",
            "composite-op": "svg:src-over",
            "x": "0",
            "y": "0",
        },
    )
    ET.SubElement(
        stack_el,
        "layer",
        {
            "name": "Blender render — bronze relic",
            "src": "data/00-blender-render.png",
            "opacity": "1.0",
            "visibility": "visible",
            "composite-op": "svg:src-over",
            "x": "0",
            "y": "0",
        },
    )
    thumbnail = merged.copy()
    thumbnail.thumbnail((128, 128))
    with zipfile.ZipFile(ora, "w") as archive:
        archive.writestr("mimetype", "image/openraster", compress_type=zipfile.ZIP_STORED)
        archive.writestr("stack.xml", ET.tostring(stack, encoding="utf-8", xml_declaration=True))
        for name, image in (
            ("data/00-blender-render.png", base),
            ("data/01-krita-finishing.png", finish),
            ("mergedimage.png", merged),
            ("Thumbnails/thumbnail.png", thumbnail),
        ):
            buffer = __import__("io").BytesIO()
            image.save(buffer, format="PNG")
            archive.writestr(name, buffer.getvalue(), compress_type=zipfile.ZIP_DEFLATED)
    return ora

def inspect_ora_dimensions(path: Path) -> tuple[int, int]:
    """Read the merged preview dimensions inside an OpenRaster archive."""
    import io
    import zipfile

    with zipfile.ZipFile(path) as archive:
        merged = archive.read("mergedimage.png")
    with Image.open(io.BytesIO(merged)) as image:
        return image.size


def run_krita(krita: str, source: Path, out: Path) -> Path:
    destination = out / "flame-seal-relic-final.png"
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
    if inspect_png(destination) != inspect_ora_dimensions(source):
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


def run_lmms(lmms: str, out: Path, root: Path) -> dict[str, Any]:
    """Render the tracked, editable Divslayer title-theme sketch."""
    project = root / "creative/lmms/divslayer_title_theme_sketch_01.mmp"
    if not project.is_file():
        raise RuntimeError(f"Tracked LMMS source project is missing: {project}")
    rendered = out / "divslayer-title-theme-sketch-01.wav"
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
        timeout=240,
        log_path=out / "lmms.log",
    )
    return {
        "status": "rendered",
        "source_project": str(project.relative_to(root)),
        "render": rendered.name,
        "audio": inspect_wav(rendered),
        "note": "Original eight-bar draft for review; not yet approved as the shipped game soundtrack.",
    }

def render_audio_preview(ffmpeg: str, source_audio: Path, out: Path) -> dict[str, Any]:
    """Create a trimmed, loudness-matched review copy; never replace the raw LMMS render."""
    preview = out / "divslayer-title-theme-sketch-01-preview.wav"
    run(
        [
            ffmpeg,
            "-hide_banner",
            "-y",
            "-i",
            str(source_audio),
            "-af",
            "silenceremove=stop_periods=1:stop_duration=0.15:stop_threshold=-60dB,"
            "afade=t=out:st=16.2:d=1.45,"
            "loudnorm=I=-18.5:TP=-2.0:LRA=7:linear=true",
            "-ar",
            "44100",
            "-ac",
            "2",
            "-c:a",
            "pcm_s16le",
            str(preview),
        ],
        timeout=120,
        log_path=out / "ffmpeg-audio-preview.log",
    )
    return {
        "status": "rendered",
        "render": preview.name,
        "audio": inspect_wav(preview),
        "target_integrated_loudness_lufs": -18.5,
        "target_true_peak_dbfs": -2.0,
        "note": "Trimmed trailing digital silence and made a separate review copy at the project's usual soundtrack loudness target. This is not a production soundtrack approval.",
    }


def run_audacity(audacity: str, source_audio: Path, out: Path) -> dict[str, Any]:
    """Launch Audacity with the rendered WAV path under Xvfb; remote scripting stays disabled."""
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
                f"Audacity exited during WAV-argument launch smoke test ({return_code}); "
                f"see {log_path}"
            )
        return {
            "status": "process_remained_active_with_wav_argument",
            "source": str(source_audio),
            "observation_seconds": 8,
            "note": "Audacity was launched with the generated WAV path and remained active for 8 seconds. This confirms process startup only; it does not verify waveform inspection, playback, or mastering. Full audio decoding is verified separately by PyAV/FFmpeg.",
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
        "FFmpeg": executable("ffmpeg"),
    }
    versions = {
        name: get_version(name, binary, ("-version",) if name == "Audacity" else ("-version",) if name == "FFmpeg" else ("--version",))
        for name, binary in binaries.items()
    }

    blender_preview = run_blender(binaries["Blender"], out, root)
    layered_ora = create_krita_ora(blender_preview, out)
    krita_export = run_krita(binaries["Krita"], layered_ora, out)
    lmms_result = run_lmms(binaries["LMMS"], out, root)
    audio_preview_result = render_audio_preview(
        binaries["FFmpeg"], out / lmms_result["render"], out
    )

    audacity_source = out / audio_preview_result["render"]
    audacity_result = run_audacity(binaries["Audacity"], audacity_source, out)

    report = {
        "tool_versions": versions,
        "blender": {
            "status": "rendered",
            "source_script": "tools/creative/blender_smoke_scene.py",
            "native_scene": "flame-seal-relic.blend",
            "output": blender_preview.name,
            "dimensions": inspect_png(blender_preview),
            "note": "First-pass item concept for review; not yet imported into the game.",
        },
        "krita": {
            "status": "exported",
            "editable_layered_source": layered_ora.name,
            "layers": ["Blender render — bronze relic", "Krita finishing — rim glints"],
            "output": krita_export.name,
            "dimensions": inspect_png(krita_export),
            "note": "OpenRaster is an editable layered format supported by Krita.",
        },
        "lmms": lmms_result,
        "audio_preview": audio_preview_result,
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
