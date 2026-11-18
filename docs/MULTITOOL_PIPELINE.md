# Multi-tool production pipeline | خط تولید چندابزاری دیوکش

The game owner does not need to install or operate desktop tools. These pinned tools run on GitHub-hosted runners, and their reports are attached to the workflow run as downloadable artifacts. Godot remains the game engine, not the only development tool.

## Tools now integrated

| Area | Tool | What it does |
|---|---|---|
| GDScript quality | GDScript Toolkit `gdlint` 4.5.0 | Parses and statically lints scripts and tests against the repository's `gdlintrc` |
| Python build-tool quality | Ruff 0.16.8 | Lints the maintained Python pipeline tools; all Python helpers are syntax-compiled |
| Image inspection | Pillow 13.0.0 | Fully decodes every registered image and creates visual contact sheets by asset category |
| Level-design review | Existing `map_preview.py` plus Pillow | Renders all 20 JSON maps with ground, props, walls, exits, hazards, NPCs, spawns and player start; creates an overview sheet |
| Audio engineering QA | FFmpeg / ffprobe | Reads codec metadata and fully decodes all audio files to detect corrupt or truncated streams |
| Engine validation | Godot 4.7.2 headless | Imports resources and runs the project's full automated gameplay test suite |
| Android packaging | Android SDK / Godot export / `apksigner` | Exports the isolated QA APK and verifies its Android package/signature |

Tool versions for gdtoolkit, Ruff, and Pillow are explicitly pinned so CI does not silently upgrade its linters or image-decoding library. FFmpeg is installed from the Ubuntu 24.04 runner's package repository; its version is printed in each run.

## Reports

The multi-tool workflow uploads:
- `Divslayer-Audio-Analysis`: per-file codec, sample rate, channels, duration, and decode status.
- `Divslayer-Artwork-and-Map-Review`: image contact sheets, image-decode report, individual map previews, and a complete map overview.

The map previews are design-review evidence, not proof of good playability. The images still require visual inspection for pathing, readability, spawn fairness, collision, and mobile-screen composition.

## Safety and scope

- Image processing in CI is read-only: it does not rewrite source images or Godot imports.
- FFmpeg checks are read-only: they do not normalize, trim, or replace the game's audio.
- The existing `tools/optimize_png.py` can perform pixel-preserving PNG compression, but it is deliberately not run automatically. A future optimization batch must be measured, pixel-compared, reviewed, and submitted separately.
- No new music is generated or imported by this workflow. Existing soundtrack commercial-use evidence remains an open legal/provenance review; a successful decode is not proof of usage rights.
- Godot gameplay, Android QA export, and physical-device testing remain separate gates. A green toolchain run is not a production release approval.
- These checks run in the cloud. They do not require VS Code, Krita, Blender, Audacity, Android Studio, or another desktop application on the owner's PC.
