#!/usr/bin/env python3
"""Generate one Divslayer cinematic clip with the Gemini Omni Interactions API.

The API key is read only from GEMINI_API_KEY. This tool never prints credentials.
"""
from __future__ import annotations

import argparse
import base64
import io
import json
import os
import re
import sys
import time
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlparse
from urllib.request import Request, urlopen

API_BASE = "https://generativelanguage.googleapis.com/v1beta"
DEFAULT_MODEL = "gemini-omni-1.2-flash"
MAX_PROMPT_CHARS = 12_000
MAX_REFERENCE_BYTES = 20 * 1024 * 1024
MAX_VIDEO_BYTES = 250 * 1024 * 1024
REQUEST_TIMEOUT_SECONDS = 900


class GeminiApiError(RuntimeError):
    """Safe, user-facing API error that never includes request headers."""


def _api_error_message(raw: bytes) -> str:
    try:
        payload = json.loads(raw.decode("utf-8", errors="replace"))
        error = payload.get("error", {})
        message = error.get("message") or error.get("status") or "Unknown API error"
        return str(message)[:1200]
    except (ValueError, AttributeError, TypeError):
        return raw.decode("utf-8", errors="replace")[:1200] or "Empty API response"


def _request_bytes(
    method: str,
    url: str,
    api_key: str,
    body: bytes | None = None,
    timeout: int = REQUEST_TIMEOUT_SECONDS,
) -> tuple[bytes, str]:
    headers = {
        "x-goog-api-key": api_key,
        "Accept": "application/json, video/mp4, application/octet-stream",
    }
    if body is not None:
        headers["Content-Type"] = "application/json"
    request = Request(url, data=body, headers=headers, method=method)
    try:
        with urlopen(request, timeout=timeout) as response:
            data = response.read(MAX_VIDEO_BYTES + 1)
            if len(data) > MAX_VIDEO_BYTES:
                raise GeminiApiError("The API response exceeded the 250 MiB safety limit.")
            return data, response.headers.get("Content-Type", "")
    except HTTPError as exc:
        detail = _api_error_message(exc.read(16_384))
        raise GeminiApiError(f"Google Gemini API returned HTTP {exc.code}: {detail}") from None
    except URLError as exc:
        raise GeminiApiError(f"Could not reach the Google Gemini API: {exc.reason}") from None
    except TimeoutError:
        raise GeminiApiError(
            "The Google request timed out. Check Google AI Studio usage before retrying; "
            "the server may have accepted the request."
        ) from None


def _request_json(method: str, url: str, api_key: str, payload: dict[str, Any] | None = None) -> dict[str, Any]:
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8") if payload is not None else None
    raw, content_type = _request_bytes(method, url, api_key, body)
    if "json" not in content_type.lower() and not raw.lstrip().startswith(b"{"):
        raise GeminiApiError("Google returned a non-JSON response where JSON metadata was expected.")
    try:
        data = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, ValueError):
        raise GeminiApiError("Google returned malformed JSON metadata.") from None
    if not isinstance(data, dict):
        raise GeminiApiError("Google returned an unexpected response format.")
    return data


def _workspace_file(workspace: Path, relative_path: str) -> Path:
    candidate = Path(relative_path)
    if candidate.is_absolute():
        raise ValueError("Reference image must be a repository-relative path.")
    resolved_workspace = workspace.resolve()
    resolved = (resolved_workspace / candidate).resolve()
    if not resolved.is_relative_to(resolved_workspace):
        raise ValueError("Reference image path must stay inside the repository.")
    if not resolved.is_file():
        raise ValueError(f"Reference image was not found in the repository: {relative_path}")
    return resolved


def load_reference_image(
    workspace: Path,
    relative_path: str,
    sprite_grid: str | None = None,
    sprite_cell: int = 0,
) -> tuple[str, str]:
    """Return (base64 data, MIME type), optionally cropping one sprite-sheet cell."""
    path = _workspace_file(workspace, relative_path)
    suffix = path.suffix.lower()
    mime_type = {
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
    }.get(suffix)
    if mime_type is None:
        raise ValueError("Reference image must be a PNG or JPEG file.")
    raw = path.read_bytes()
    if not raw:
        raise ValueError("Reference image is empty.")
    if len(raw) > MAX_REFERENCE_BYTES:
        raise ValueError("Reference image exceeds the 20 MiB upload limit.")

    if sprite_grid:
        match = re.fullmatch(r"(\d+)x(\d+)", sprite_grid.strip().lower())
        if not match:
            raise ValueError("Sprite grid must use the COLUMNSxROWS format, for example 5x3.")
        columns, rows = int(match.group(1)), int(match.group(2))
        if columns < 1 or rows < 1 or columns * rows > 256:
            raise ValueError("Sprite grid must contain between 1 and 256 cells.")
        if not 0 <= sprite_cell < columns * rows:
            raise ValueError(f"Sprite cell must be between 0 and {columns * rows - 1}.")

        try:
            from PIL import Image
        except ImportError:
            raise ValueError("Pillow is required to crop a sprite sheet. Install Pillow==13.0.0.") from None

        try:
            with Image.open(io.BytesIO(raw)) as image:
                image.load()
                width, height = image.size
                if width < columns or height < rows:
                    raise ValueError("Sprite grid is larger than the reference image.")
                col = sprite_cell % columns
                row = sprite_cell // columns
                left = col * width // columns
                top = row * height // rows
                right = (col + 1) * width // columns
                bottom = (row + 1) * height // rows
                cell = image.crop((left, top, right, bottom)).convert("RGBA")
                buffer = io.BytesIO()
                cell.save(buffer, format="PNG")
                raw = buffer.getvalue()
                mime_type = "image/png"
        except (OSError, ValueError) as exc:
            if isinstance(exc, ValueError):
                raise
            raise ValueError(f"Could not decode sprite sheet: {exc}") from None

    return base64.b64encode(raw).decode("ascii"), mime_type


def build_payload(
    prompt: str,
    duration: int,
    aspect_ratio: str,
    resolution: str,
    reference: tuple[str, str] | None = None,
) -> dict[str, Any]:
    cleaned_prompt = prompt.strip()
    if not cleaned_prompt:
        raise ValueError("Prompt cannot be empty.")
    if len(cleaned_prompt) > MAX_PROMPT_CHARS:
        raise ValueError(f"Prompt exceeds the {MAX_PROMPT_CHARS:,}-character limit.")
    if not 3 <= duration <= 15:
        raise ValueError("Duration must be between 3 and 15 seconds.")
    if aspect_ratio not in {"16:9", "9:16"}:
        raise ValueError("Aspect ratio must be 16:9 or 9:16.")
    if resolution not in {"360p", "720p"}:
        raise ValueError("Resolution must be 360p or 720p in this cost-controlled workflow.")

    if reference is None:
        model_input: str | list[dict[str, str]] = cleaned_prompt
    else:
        image_data, mime_type = reference
        model_input = [
            {"type": "image", "data": image_data, "mime_type": mime_type},
            {"type": "text", "text": cleaned_prompt},
        ]

    return {
        "model": DEFAULT_MODEL,
        "input": model_input,
        "response_format": {
            "type": "video",
            "duration": f"{duration}s",
            "aspect_ratio": aspect_ratio,
            "resolution": resolution,
            "delivery": "uri",
        },
        "background": False,
        "store": False,
        "stream": False,
    }


def extract_video_output(response: dict[str, Any]) -> tuple[str | None, str | None]:
    """Find the generated video's URI or inline base64 data in REST response shapes."""
    output_video = response.get("output_video")
    if isinstance(output_video, dict):
        uri = output_video.get("uri")
        data = output_video.get("data")
        if uri or data:
            return uri, data

    for step in response.get("steps", []):
        if not isinstance(step, dict) or step.get("type") != "model_output":
            continue
        for item in step.get("content", []):
            if isinstance(item, dict) and item.get("type") == "video":
                return item.get("uri"), item.get("data")
    return None, None


def parse_file_id(file_uri: str) -> str:
    parsed = urlparse(file_uri)
    match = re.search(r"/files/([A-Za-z0-9_-]+)(?::download)?$", parsed.path)
    if not match:
        match = re.fullmatch(r"files/([A-Za-z0-9_-]+)", file_uri)
    if not match:
        raise GeminiApiError("Google returned an unsupported video file URI.")
    return match.group(1)


def _poll_file(api_key: str, file_id: str, timeout_seconds: int = 900) -> None:
    deadline = time.monotonic() + timeout_seconds
    metadata_url = f"{API_BASE}/files/{quote(file_id, safe='')}"
    while time.monotonic() < deadline:
        metadata = _request_json("GET", metadata_url, api_key)
        state = str(metadata.get("state", "")).upper()
        if state == "ACTIVE":
            return
        if state == "FAILED":
            raise GeminiApiError("Google reported that video file processing failed.")
        print(f"Video file state: {state or 'PROCESSING'}")
        time.sleep(5)
    raise GeminiApiError("Timed out while waiting for Google's video file to become ACTIVE.")


def download_video(api_key: str, file_uri: str, output_path: Path) -> None:
    file_id = parse_file_id(file_uri)
    _poll_file(api_key, file_id)
    url = f"{API_BASE}/files/{quote(file_id, safe='')}:download?alt=media"
    raw, content_type = _request_bytes("GET", url, api_key)
    if len(raw) < 12 or raw[4:8] != b"ftyp":
        message = _api_error_message(raw[:16_384]) if raw.lstrip().startswith(b"{") else ""
        suffix = f" Google response: {message}" if message else ""
        raise GeminiApiError(f"Downloaded output did not have a valid MP4 signature.{suffix}")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(raw)
    print(f"Saved MP4 ({len(raw):,} bytes; {content_type or 'video/mp4'}) to {output_path}")


def write_inline_video(data: str, output_path: Path) -> None:
    try:
        raw = base64.b64decode(data, validate=True)
    except (ValueError, TypeError):
        raise GeminiApiError("Google returned invalid base64 video data.") from None
    if len(raw) < 12 or raw[4:8] != b"ftyp":
        raise GeminiApiError("The inline video data did not have a valid MP4 signature.")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(raw)
    print(f"Saved MP4 ({len(raw):,} bytes) to {output_path}")


def _workspace_file_for_output(workspace: Path, relative_path: str) -> Path:
    candidate = Path(relative_path)
    if candidate.is_absolute():
        raise ValueError("Output path must be repository-relative.")
    resolved_workspace = workspace.resolve()
    resolved = (resolved_workspace / candidate).resolve()
    if not resolved.is_relative_to(resolved_workspace):
        raise ValueError("Output path must stay inside the repository.")
    return resolved


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prompt", required=True, help="Video prompt text.")
    parser.add_argument("--output", default="artifacts/google-omni-video/divslayer-omni.mp4")
    parser.add_argument("--reference-image", help="Optional repository-relative PNG/JPEG reference.")
    parser.add_argument("--sprite-grid", help="Optional sprite grid, e.g. 5x3.")
    parser.add_argument("--sprite-cell", type=int, default=0, help="Zero-based row-major sprite cell.")
    parser.add_argument("--duration", type=int, default=6, choices=range(3, 16))
    parser.add_argument("--aspect-ratio", choices=("16:9", "9:16"), default="16:9")
    parser.add_argument("--resolution", choices=("360p", "720p"), default="720p")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not api_key:
        print("ERROR: GEMINI_API_KEY is not set. Add it as a GitHub Actions secret.", file=sys.stderr)
        return 2

    workspace = Path.cwd()
    try:
        reference = None
        if args.reference_image:
            reference = load_reference_image(
                workspace,
                args.reference_image,
                sprite_grid=args.sprite_grid,
                sprite_cell=args.sprite_cell,
            )
        payload = build_payload(
            args.prompt,
            duration=args.duration,
            aspect_ratio=args.aspect_ratio,
            resolution=args.resolution,
            reference=reference,
        )
        output_path = _workspace_file_for_output(workspace, args.output)
        print(f"Requesting {args.duration}s {args.aspect_ratio} {args.resolution} video from {DEFAULT_MODEL}.")
        response = _request_json("POST", f"{API_BASE}/interactions", api_key, payload)
        video_uri, video_data = extract_video_output(response)
        if video_data:
            write_inline_video(video_data, output_path)
        elif video_uri:
            download_video(api_key, video_uri, output_path)
        else:
            status = str(response.get("status", "unknown"))
            interaction_id = response.get("id")
            raise GeminiApiError(
                f"Google did not return a video URI or video data (status={status}, "
                f"interaction_id={interaction_id or 'not provided'})."
            )

        metadata_path = output_path.with_suffix(".json")
        metadata_path.write_text(
            json.dumps(
                {
                    "model": response.get("model", DEFAULT_MODEL),
                    "interaction_id": response.get("id"),
                    "duration_seconds": args.duration,
                    "aspect_ratio": args.aspect_ratio,
                    "resolution": args.resolution,
                    "reference_image": args.reference_image,
                    "sprite_grid": args.sprite_grid,
                    "sprite_cell": args.sprite_cell if args.sprite_grid else None,
                    "prompt": args.prompt,
                },
                ensure_ascii=False,
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        print(f"Saved generation metadata to {metadata_path}")
        return 0
    except (GeminiApiError, ValueError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
