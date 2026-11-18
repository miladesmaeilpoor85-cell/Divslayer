# Creative applications | Krita, Audacity, LMMS, Blender

This layer adds the four requested creative applications to the existing cloud toolchain. The applications run on a GitHub-hosted Ubuntu runner; the game owner does not need to install them locally.

## What the workflow actually does

The workflow is intentionally non-destructive. It creates temporary QA files under **artifacts/creative-tools/** and never overwrites anything under **assets/**.

| Application | Current automated use | What it does not claim |
|---|---|---|
| Blender | Runs in background mode, builds a small procedural bronze-orb scene, saves an editable .blend QA scene, and renders a PNG | The generated orb is a pipeline fixture, not a Divslayer enemy or production sprite |
| Krita | Opens the Blender preview and exports a second PNG through Krita's command-line export support; dimensions and PNG decoding are checked | A flattened PNG cannot restore lost source layers; this is not a redesign of existing game art |
| LMMS | Checks the installed application version; when an LMMS starter template is available, generates a temporary one-note project and renders it to WAV | The test tone is not game music and is never added to assets/audio/ |
| Audacity | Starts the GUI in a virtual display with the existing title soundtrack as its input and verifies that the application remains running during the smoke window | This does not master, normalize, trim, or replace game audio |

The LMMS and Krita command-line steps use their documented export/render workflows. Blender is run headlessly for deterministic background rendering. Audacity's remote named-pipe scripting is deliberately not enabled: the Audacity manual warns that this control channel is not suitable for a web-server environment because commands are not sanitized. The existing PyAV/FFmpeg job remains responsible for automated, full-file audio decoding and metadata analysis. Audacity is retained for actual listening, editing, and mastering work when an audio-editing task is undertaken.

## Current source-project gap

At the time this workflow was added, the tracked repository contained no native source projects with these extensions:

- Krita: .kra
- Blender: .blend
- LMMS: .mmp or .mmpz
- Audacity: .aup3

The game currently stores its art mainly as exported PNG/JPEG/WebP files and its audio mainly as OGG files. This is enough for import, inspection, and some conversions, but not enough to recover Krita layers or an original Blender model, LMMS arrangement, or Audacity edit history. The smoke report includes the tracked native-project inventory so this gap is visible and can be closed as source projects are added.

For future editable work, keep source files alongside the exported game assets, for example:

- creative/krita/ for layered .kra documents
- creative/blender/ for .blend scenes and reusable materials
- creative/lmms/ for .mmp / .mmpz arrangements and exported stems
- creative/audacity/ for .aup3 sessions and mastering notes

Do not treat a rendered test file as an approved game asset. Before promoting any new artwork or audio into the game, review its quality and update the relevant rights/credits records with the actual source and terms. A successful render or decode is not evidence of commercial-use permission.

## Workflow and outputs

Workflow: .github/workflows/creative-tools-pipeline.yml

Triggers: changes to creative-tool scripts, game art/audio, this document, or a manual workflow_dispatch.

Artifact: Divslayer-Creative-Tools-Review, retained for 14 days. It contains the application version report, procedural Blender render and .blend QA scene, Krita round-trip PNG, LMMS smoke WAV/project when available, and Audacity launch log.

This workflow does not build an Android APK because it does not change gameplay. A QA APK is needed only after a gameplay or in-game asset change is prepared for device testing.
