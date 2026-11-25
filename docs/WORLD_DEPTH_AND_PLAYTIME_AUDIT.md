# World depth and playtime evidence audit

## Verified structural baseline (25 November 2026)

The world graph currently contains 22 map nodes: 15 non-shrine regions and 7 shrines. All seven shrines use 680 × 520 logical units. The 15 non-shrine regions range from 900 × 650 (Zabol) to 1500 × 1200 (Damavand); the average is approximately 1193 × 947.

The map files expose several useful depth signals: placed objects, enemy spawn points, NPCs, items, hazards, exits, quest markers, and boss registrations. These signals are now reported separately. Object count is not treated as equivalent to meaningful content: a decorative prop does not count as a quest, puzzle, encounter, or discovery. The report distinguishes ordinary map exits from scripted quest gates. The current code confirms a village-to-Trial transition through Siavash's arena dialogue and a Peaks-to-Emberforge transition through the Kindling door after the Brann key is awarded; both are declared in `world_graph.json` under `scriptedConnections`.

## Why dimensions do not prove campaign length

The player movement implementation uses class base speeds from `data/Tables/CLASSES.json` multiplied by 62.5 in `scripts/game.gd`. A shortest-side boundary crossing can therefore be only a few seconds on paper. That is an ideal straight-line lower bound, not a real traversal time: walls, collision, enemies, objectives, combat, backtracking, menus, and player behaviour are not represented by the formula.

The audit deliberately reports these calculations as layout diagnostics. It also reports reachability through ordinary exits separately from reachability after the declared scripted gates are included. It keeps `actual_playtime.status = not_measured` until explicit playtest durations are supplied. It must never turn map area, enemy density, or authored quest count into a claimed completion time.

## Evidence format for a real playthrough

A tester or automated player journey can append one JSON object per completed map visit to a JSONL file:

```json
{"event":"map_visit","map":"forest","duration_seconds":94.2,"method":"manual"}
{"event":"map_visit","map":"forest","duration_seconds":77.5,"method":"automated"}
```

Run:

```bash
python tools/map_depth_audit.py --report artifacts/map-depth-report.json --session-log path/to/map-visits.jsonl
```

The report aggregates actual durations by map and across the supplied log. It does not infer time for maps that were not visited. A useful campaign test must cover all intended main-story transitions, side areas, shrines, deaths/retries, and optional content; partial journeys must be labelled partial.

## Production acceptance gates

1. Every major region needs a recognisable biome signature, distinct ground material, readable route network, local landmarks, and a deliberate set of environmental props.
2. A main region should have more than a single straight corridor: include at least one optional route or discovery, meaningful encounter placement, and a reason to revisit only when the story or reward justifies it.
3. Each shrine needs a distinct puzzle mechanic and a visible state change or reward, not merely a small combat room.
4. Quest and encounter density must be reviewed against the playable footprint. Empty space is acceptable only when it supports pacing, atmosphere, navigation, or combat.
5. Before deciding to enlarge a map, compare its actual recorded exploration and encounter time. Expand only where the current footprint blocks meaningful gameplay.
6. Physical Android review remains necessary for route readability, enemy visibility, and performance. Headless CI cannot replace a human playthrough.

## First terrain pass in this branch

Dedicated, region-specific ground files are wired for Zabol, Whispering Forest, and Ashen Peaks. Their map dimensions, collision rectangles, exits, enemy placements, and quest progression are unchanged. SVG import, preview rendering, rights-register coverage, and map-depth reporting are included in CI; Godot import and on-device visual acceptance still need their run results and human review.
