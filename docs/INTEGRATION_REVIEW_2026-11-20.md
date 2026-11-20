# Integration review — 20 November 2026

## Decision summary

Do not merge PRs #25, #26, and #36 as three uncoordinated changes. They all touch the wind/gameplay integration surface, and PRs #25 and #26 share a stale base and have diverged. Keep the existing draft PRs available while combining and re-testing their work on one integration branch.

This review is based on GitHub PR metadata, current file lists/patches, branch comparisons, and successful workflow runs visible on 20 November 2026. No PR was merged and `main` was not modified by this review.

## Current base and branch state

- Current `main`: `0f20e499bf17966a9edb3639a4373205be048edd`.
- PR #25 and PR #26 both declare base SHA `79ef9ff181b7bf9872f59a3dacda4d5812fbf4e2`; they therefore need to be revalidated against the current `main`.
- PR #36 declares the current main SHA as its base and reports a clean merge state.
- GitHub compares PR #25 and PR #26 as **diverged**: the compare reports 30 commits ahead and 2 behind (from #25 to #26). This does not mean their changes are interchangeable.

## PR inventory

| PR | Scope | Current evidence | Main remaining gate |
|---|---|---|---|
| [#25](https://github.com/miladesmaeilpoor85-cell/Divslayer/pull/25) | Weather-aware ambient particle/fog drift; wind behaviour and related quest/animation/pipeline changes in its branch | Current head CI passed all 4 Godot shards, Android QA export, creative tools, GDScript/Python lint, artwork/map validation, and audio checks | Rebase/reconcile with current main and #26; phone rendering/performance is not proven |
| [#26](https://github.com/miladesmaeilpoor85-cell/Divslayer/pull/26) | Dodge wind trails and Thornwood parley-loop fix; branch also carries overlapping gameplay, quest, animation, and CI changes | Current head CI passed all 4 Godot shards, Android QA export, creative tools, lint, artwork/map, and audio checks | Reconcile overlapping edits with #25 and current main; manual device rendering still required |
| [#36](https://github.com/miladesmaeilpoor85-cell/Divslayer/pull/36) | Chapter IV Alborz playable vertical slice: map, wind zone/shelters, guards, scout rescue, objective/save flow, procedural wind cues | Current head CI checks passed; PR description also records Chapter IV regression coverage and Android emulator launch evidence | Physical-phone gameplay pass and replacement of temporary ground/NPC/prop assets |

## Shared-file collision surface

PRs #25 and #26 both modify a large common set of files. Important shared paths include:

- `scripts/game.gd`, `scripts/main.gd`, `scripts/player.gd`, and `scripts/world.gd`
- `scripts/wind_gust.gd`, `docs/CHAPTER_04_WIND_SYSTEM_IMPLEMENTATION.md`, and `tools/run_all_tests.sh`
- animation pipeline scripts/docs, test files, Android QA workflow, creative-tools workflow, and README/changelog files

PR #36 also modifies the Chapter IV document, `scripts/game.gd`, `scripts/main.gd`, `scripts/world.gd`, and `tools/run_all_tests.sh`. The current PR #36 base is clean against main, but its changes must be replayed after the #25/#26 integration because those paths overlap.

## Recommended integration sequence

1. Freeze scope and retain current PR heads as references; do not force-push or rewrite their existing history.
2. Create one integration branch from the latest `main`.
3. Port the weather/ambient changes from #25 while preserving the current controller and test runner on main.
4. Port the dodge trail and Thornwood state fix from #26. Resolve shared hunks explicitly; do not copy one PR's entire version of `game.gd`, `main.gd`, `player.gd`, or `world.gd` over the other.
5. Port the Alborz route and Chapter IV quest flow from #36 last, preserving the integrated wind controller and player-movement behaviour.
6. Run the complete Godot suite, all four shards, GDScript/Python lint, artwork/map validation, audio checks, creative-tool smoke tests, Android APK export/signature checks, and Android emulator smoke test on the combined head.
7. Require a physical-device playthrough before calling the stage complete. Keep the combined change as a draft until that sign-off is recorded.

## Acceptance gates

- **Wind:** phase timing, shelter attenuation/collision, map edges, overlapping zones, knockback interactions, dodge and casting, all four classes, and map reset behaviour.
- **Alborz:** unlocked only after its prerequisite story state; correct entry/return spawns; scout cannot be rescued before guards are cleared; objective/save state survives app restart.
- **Visual effects:** weather particles and gust telegraphs remain readable over combat; no excessive mobile overdraw or frame-time spikes.
- **Regression:** Thornwood Fight choice cannot reopen parley after leaving/re-entering; existing saves migrate safely.
- **Assets:** every new ground, prop, scout, audio, or animation asset is registered with source, terms, and private evidence location.

## Explicitly not done

- None of PR #25, #26, or #36 has been merged by this review.
- No production artwork has been fabricated or described as final.
- No production signing key, app ID, private export preset, or API credential has been added.
