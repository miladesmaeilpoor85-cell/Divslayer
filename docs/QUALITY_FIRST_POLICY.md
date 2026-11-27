# Quality-first production policy | سیاست کیفیت‌محور دیوکش

**Status:** project-wide production rule  
**Priority:** visual, audio, animation, and gameplay quality take precedence over reducing the download, install, or repository size.

## اصل قطعی

حجم فایل به‌تنهایی دلیل قابل‌قبولی برای پایین‌آوردن کیفیت نیست. اگر انتخاب بین حفظ کیفیت و کوچک‌کردن بستهٔ بازی باشد، کیفیت حفظ می‌شود و افزایش حجم پذیرفته است.

The game must not sacrifice artistic or sensory quality merely to meet an arbitrary APK/AAB size target. There is no project-wide maximum package-size target.

## What must not be reduced just to save bytes

### Artwork, textures, and UI

- All 2D image imports in Godot must use `compress/mode=0` (Lossless) and `process/size_limit=0`.
- Do not use Godot Lossy, VRAM Compressed, or Basis Universal import modes for 2D artwork merely to reduce disk/download size. Godot's texture-import documentation specifically recommends against VRAM Compressed and Basis Universal for 2D elements.
- The editor plugin enforces Lossless imports whenever the project opens in Godot. The CI helper `tools/enforce_quality_first_imports.py` applies the same settings before import, and `tools/quality_first_audit.py` rejects any remaining lossy or downscaled image.
- Lossless import preserves the quality of the existing source file; it cannot restore information already lost inside a JPEG or lossy WebP source. Keep or reacquire a higher-quality master when that happens.
- Lossless imports can use more memory than VRAM-compressed textures. Profile the game on target devices, but do not respond to memory pressure by silently lowering source or import quality; optimize resource lifetime, loading, atlases, and scene usage first.

- Do not downscale source artwork, character atlases, environment textures, portraits, UI, or VFX just to reduce package size.
- Do not lower texture quality, colour precision, alpha fidelity, or image dimensions only to make the package smaller.
- Keep lossless source masters. Prefer PNG or another lossless source format for sprites, pixel art, line art, UI, transparency-critical assets, and masks.
- Do not replace a sharp or detailed source with a lower-quality JPEG/WebP export merely because it is smaller.
- GPU/VRAM texture formats are a separate runtime decision, not an automatic package-size optimization. Review each relevant art class at native size and actual Android display scale; reject compression that creates visible banding, block artefacts, edge halos, colour shifts, or alpha damage. A compressed GPU format may be used only when visual fidelity is demonstrably preserved and the reason is runtime memory/performance rather than download-size reduction.

### Audio and music
- Keep original/master recordings where available. Do not lower sample rate, bitrate, encoder quality, channel count, or dynamic detail just to reduce package size.
- Preserve stereo sources unless a deliberate sound-design decision calls for mono (for example, a specifically authored centred positional effect); do not downmix a stereo recording just because mono is smaller.
- New lossy delivery encodes must use a high-quality setting and be auditioned against the source. The current build tool defaults to Vorbis quality 10 at 48 kHz.
- Do not truncate musical phrases, remove ambience layers, shorten loops, or trim meaningful tails to save bytes. Any musical edit must be an intentional arrangement decision reviewed by ear.

### Animation, VFX, and environments
- Do not reduce animation frame count, atlas resolution, frame rate, colour detail, or directional/action coverage to shrink the build.
- A still pose with procedural movement is not a quality-equivalent replacement for authored animation when the art plan calls for distinct poses.
- Do not remove particles, lighting, layered ambience, environment details, or unique assets solely to reduce download size.
- Preserve visual readability and performance separately: first profile the actual device bottleneck, then optimize the implementation without silently deleting authored detail.

## Acceptable engineering optimizations

- Lossless compression, deduplication of truly identical files, correct resource packaging, asynchronous loading, streaming, caching, and memory lifecycle improvements are acceptable when they preserve the authored result.
- Runtime performance and memory may be optimized, but a change must be judged at the intended Android display scale and on representative physical devices.
- A quality/performance setting may alter fidelity only when it is an explicit, reviewed graphics setting with a documented reason and a tested fallback. It must not be introduced as a hidden way to meet a package-size target.
- An asset may be replaced only by a version that passes the same or higher visual/audio quality review and rights/provenance checks.

## CI and review rules

- File-size and pixel-dimension thresholds in `tools/asset_audit.py` are informational warnings. They must never trigger automatic downscaling, recompression, deletion, or rejection solely because an asset is large.
- Build reports may record APK/AAB size and growth for transparency, but size is not a quality score or acceptance gate.
- Every proposed lossy conversion requires a before/after comparison against the original at native resolution / full playback quality. If a reviewer can detect a meaningful loss, keep the higher-quality version.
- Keep original source files and the evidence used to approve an asset change. Do not overwrite source masters with delivery encodes.

## Audio build baseline

`tools/build_audio.py` uses a high-quality Vorbis default (quality 10, 48 kHz), preserves source channel layout unless an explicitly authored mono treatment is selected, and does not downmix the dungeon score merely to halve file size. Any manual override to lower quality requires a documented artistic/technical reason and review; package size alone is not a valid reason.

## Definition of done

A quality-sensitive asset change is complete only when:
1. The source/master is retained.
2. The new asset is equal or better in visible/audible quality.
3. It is checked at native resolution / full playback quality and at the actual Android presentation scale.
4. Godot import/runtime checks pass.
5. Performance is measured separately from fidelity.
6. The asset's provenance and usage rights are documented.

**Decision rule:** when size and quality conflict, preserve quality. Never quietly trade quality for a smaller download.
