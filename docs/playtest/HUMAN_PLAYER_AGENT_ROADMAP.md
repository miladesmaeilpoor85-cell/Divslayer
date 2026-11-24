# Divslayer Human Player Agent

## Purpose

Build a repeatable player agent that can start a fresh save, play through the game using ordinary controls, explore reachable content, recover from mistakes, and produce evidence-backed player, critic, and QA reports.

The agent is a test player, not a game cheat. Normal progression must use the same touch/UI actions available to a player. It must not use presets, teleportation, direct quest-state mutation, invulnerability, or boss isolation to make progress.

## Current implementation boundary

The current PR #65 is the first touch-driven prototype. It covers title/class selection, Rostam's tutorial, an initial equipment/shop sequence, selected class progression actions, and a scripted Chapter I route.

It is not yet a full-campaign agent and it is not yet a vision-only AI. The Godot test process currently has access to runtime objects and game-state APIs. Those APIs may remain available for assertions and QA evidence, but ordinary player decisions should progressively move to observations available on screen: visible text, HUD, dialogue choices, shop cards, map cues, and screenshots.

The latest shop-interaction change records visible dialogue/control evidence and selects Kaveh's visible "Buy armour" choice by inspecting the actual active dialogue buttons. This is a diagnostic and resilience improvement; it is not considered verified until a new run against the updated PR head passes.

The journey workflow now generates four evidence artifacts per class run: `run-evidence.json`, `player-report.md`, `critic-report.md`, and `qa-report.md`. Reports are deliberately conservative: a passing Chapter I run is not treated as full-game completion, unvisited maps remain `not tested`, and subjective critic/player judgements are left for human review. The report generator has dedicated Python unit tests in `tools/test_playtest_reports.py` and is included in both Godot CI and the class-journey workflow.

The latest four-class run on 24 November 2026 passed the full Chapter I route for Warrior, Rogue, and Paladin. Mage reached Arzhang but ended with the boss at 49.8% HP and two grave pillars still at full health; the victory assertion correctly failed. The next correction makes the agent approach a pillar from the side opposite the boss so the game's native nearest-enemy aim assist selects the pillar, and records actual pillar HP reductions. This is pending a fresh four-class runtime run.

## Target architecture

### 1. Observation

Capture timestamped observations at meaningful decision points:

- Screenshot and visible text/HUD labels.
- Current visible dialogue and enabled choices.
- Visible shop, equipment, skill, map, and pause panels.
- Current map and a short action/result description.
- Optional internal telemetry tagged as QA-only evidence, never silently mixed with player-facing perception.

### 2. Player decision loop

Use a bounded loop:

`Observe -> Understand -> Choose goal -> Act -> Verify -> Remember`

The agent should maintain short-term memory of visited places, inspected interactables, failed routes, shop outcomes, discovered clues, defeated bosses, deaths, retries, and the last known quest state. Repeated failures must cause a different recovery action rather than blindly repeating the same input.

### 3. Human-like control

Use real touch/button input. Include varied reaction delays, imperfect but bounded combat decisions, resource conservation, repositioning, occasional mistakes, and recovery. The policy must remain fair: no hidden damage bonuses, invulnerability, scripted boss kills, or state mutation.

### 4. Campaign and exploration

Run each class from an independent new save. Follow the live objective, but do not assume the objective marker represents all available content. Maintain a discoverable-content manifest and verify every reachable region, side quest, boss, shrine/puzzle, NPC interaction, shop/crafting path, and ending.

The current repository contains 22 region/map data files:

`alborz`, `alborz_eyrie`, `camp`, `damavand`, `dungeon`, `emberforge`, `forest`, `frostvale`, `peaks`, `sanctum`, `shadowfen`, `shrine_echoes`, `shrine_embers`, `shrine_fuse`, `shrine_light`, `shrine_shadows`, `shrine_tides`, `shrine_weight`, `trial`, `village`, `wyrmhollow`, and `zahhakcave`.

The seven named shrine regions must each have a separate result record. A map being present in source data does not, by itself, prove that the player can reach or complete it.

## Evidence and completion rules

A campaign run is complete only when the game's real ending/completion condition is observed and recorded. Reaching a last known map, defeating one boss, losing the objective marker, or timing out does not count as completion.

Each class run should preserve:

- A fresh-save identifier/profile and class selection.
- Timestamped action/observation log and screenshots.
- Map-visit and discovery manifest, including inaccessible or unverified content.
- Main/side quest transitions and completion evidence.
- Boss start/end evidence, deaths, rematches, and resource use.
- Purchases, equipment changes, skill/talent choices, and currency decisions.
- Softlocks, route failures, UI failures, crashes, and reproducible steps.

A report must distinguish **completed**, **attempted but failed**, **unavailable/inaccessible**, and **not tested**. Never convert missing evidence into a success claim.

## Three separate reports

1. **Player report:** first-person play experience, clarity, exploration, difficulty, pacing, frustration, reward, and engagement.
2. **Critic report:** narrative, world/level design, combat, class identity, progression/balance, art direction, sound, UI/UX, and overall structure. Every major judgment should point to run evidence.
3. **QA report:** reproducible defects, severity, environment, steps, expected/actual result, logs, screenshots, and whether a defect blocks progression.

The critic report must analyse recorded play evidence after the run; it must not fabricate impressions for content the agent did not reach.

## Delivery phases

### V1 — Reliable touch-driven Chapter I player

- Start each class through the title screen.
- Complete the tutorial through ordinary controls.
- Resolve story-first shop/dialogue interactions.
- Purchase or explicitly explain why the first armour tier cannot be purchased.
- Exercise natural navigation, basic combat, pickups, and class progression.
- Produce per-class artifacts and stable diagnostics.

### V2 — Autonomous campaign runner

- Replace the fixed Chapter I action list with a bounded objective-driven loop.
- Recover from death, interrupted dialogue, blocked routes, closed shops, and resource shortages.
- Detect stagnation and try a different action or mark the blocker with evidence.
- Continue through the official campaign and its actual ending for each class.

### V3 — Full-content exploration and evaluation

- Traverse all reachable maps and optional content from the manifest.
- Complete side quests, shrines/puzzles, bosses, trials, and other discoverable systems where available.
- Compare the four class experiences without sharing saves or progression.
- Generate the three evidence-backed reports.

### V4 — Stronger visual autonomy

- Make screen/HUD/dialogue observations the primary decision input.
- Keep Godot runtime access limited to test assertions and QA validation.
- Evaluate how closely the agent's actions and decisions resemble a human player, and document any simulation limits.

## Campaign completion boundary

A source review of the current Chapter IV implementation shows that it is a vertical slice, not a final-game chapter: it covers the Alborz pass, one scout rescue, and a return to Zal. Its own story text describes this as the first part of the Silent Wind and says the deeper silence requires another journey. The project does not currently expose a single, authoritative true-ending or full-campaign-complete flag for the player agent to verify.

Until the game defines that final condition, the agent may report verified chapter/quest milestones and the currently playable content boundary, but it must not claim that the full game has been completed. The report generator's strict true-ending marker is intentionally not emitted by the current Chapter I test.

## Current blockers and validation status

- PR #65 remains a Draft and must stay unmerged until its artifacts and CI are reviewed.
- Earlier Chapter I runs on commit `59678c20865f74196b67a61f07e6d3053d6b3b6c` failed at the first shop interaction for all four classes. Those runs predate the latest shop-diagnostic commit and cannot be used to judge that newer code.
- The updated shop logic is not yet verified by a CI run against the current PR head.
- The evidence-report generator and its CI wiring have been committed, but its new unit tests and generated artifacts are not yet verified on the current PR head.
- The expanded Chapter I scenario now requires evidence of Arzhang's actual defeat from the game's boss kill counter, then follows the live quest target back to Zal and verifies the Chapter I reward state. This is still only a Chapter I milestone, not a full-campaign run.
- The updated fight policy prioritizes Arzhang's live grave pillars from phase II onward and uses ordinary light/heavy attacks to break them; it does not remove other enemies, grant damage, or change boss/player state.
- Runtime verification of this expanded scenario is pending on the updated PR head; a source change alone is not evidence that all four classes can win the encounter.
- Existing long campaign touch tests have independent navigation/survival failures. Those must be fixed from their own logs rather than hidden by relaxing assertions.

## Acceptance gate before merge

Keep the PR Draft until:

1. The updated branch passes Godot import/parse and all required headless tests.
2. All four fresh class journeys defeat Arzhang through normal combat, follow the objective back to Zal, and complete the Chapter I reward checkpoint without shortcuts.
3. Shop, dialogue, navigation, combat, and recovery evidence is present and reviewable.
4. Every class artifact includes the machine-readable evidence manifest and three distinct reports; no report claims unvisited content or full-game completion.
5. The scope and limitations in the PR description match what the tests actually prove.

Do not merge or label the agent "full game complete" until the V2/V3 completion rules are met.
