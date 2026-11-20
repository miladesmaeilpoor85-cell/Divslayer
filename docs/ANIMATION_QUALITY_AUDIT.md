# Frame-level animation audit

The animation quality audit is a read-only CI tool. It reads `data/art_manifest.json` and the registered PNG artwork, then writes a JSON report under `artifacts/animation-review/`. It never modifies game assets or the manifest.

## Measurements

- Frame count and unique-frame count for each directional hero clip and enemy variant.
- Exact duplicate frame pairs and the fraction of adjacent pixels that visibly change.
- Average non-transparent alpha coverage and variation in the visible bottom edge as a footline-drift review cue.
- Attack FPS, contact-frame index, and contact time when the manifest contains those fields.

The audit understands embedded attack columns, separate attack atlases, and per-direction `attackFrameFiles`. The last format is used by Warrior Starter's twelve individual attack poses.

## Interpretation

A one-frame attack is reported as a single-pose clip, not automatically as a bug. Two-frame and low-motion warnings are prompts for visual review. Alpha coverage and pixel differences do not measure pose quality, weight, appeal, weapon readability, or correct acting. Those require human review at native sprite size and actual Android display scale.

## Current manifest baseline

There are 12 registered hero looks and three directional attack clips per look (36 clips total). Warrior Starter contributes three four-frame clips; the remaining 33 clips are one-pose attacks. The CI report is the machine-generated source of truth for future counts after new art is registered.
