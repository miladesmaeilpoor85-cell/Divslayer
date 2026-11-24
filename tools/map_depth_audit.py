"""Measure region content density and accept real map-visit durations as evidence.

Map dimensions and base movement speed are layout diagnostics only. They are
not estimates of campaign playtime; actual time is reported only from explicit
map_visit records supplied by a manual or automated playtest.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from collections import deque
from pathlib import Path
from typing import Any

PIXELS_PER_GAME_SPEED_UNIT = 62.5


def _read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _session_durations(path: Path | None) -> dict[str, Any]:
    if path is None:
        return {"status": "not_measured", "total_seconds": None, "visits": [], "by_map": {}}

    visits: list[dict[str, Any]] = []
    errors: list[str] = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError as exc:
            errors.append(f"line {line_number}: invalid JSON ({exc.msg})")
            continue
        if event.get("event") != "map_visit":
            continue
        map_key = str(event.get("map", "")).strip()
        try:
            duration = float(event.get("duration_seconds"))
        except (TypeError, ValueError):
            errors.append(f"line {line_number}: map_visit needs duration_seconds")
            continue
        if not map_key or not math.isfinite(duration) or duration < 0:
            errors.append(f"line {line_number}: map_visit has an invalid map or duration")
            continue
        visits.append({
            "map": map_key,
            "duration_seconds": round(duration, 3),
            "method": str(event.get("method", "unspecified")),
        })

    by_map: dict[str, dict[str, float | int]] = {}
    for visit in visits:
        key = visit["map"]
        current = by_map.setdefault(key, {"visits": 0, "duration_seconds": 0.0})
        current["visits"] += 1
        current["duration_seconds"] += visit["duration_seconds"]
    for stats in by_map.values():
        stats["duration_seconds"] = round(float(stats["duration_seconds"]), 3)

    status = "measured" if visits and not errors else "partial" if visits else "no_valid_visits"
    return {
        "status": status,
        "total_seconds": round(sum(item["duration_seconds"] for item in visits), 3) if visits else None,
        "visit_count": len(visits),
        "visits": visits,
        "by_map": by_map,
        "errors": errors,
    }


def _reachable_from(start: str, graph: dict[str, Any]) -> set[str]:
    reached = {start} if start in graph else set()
    queue = deque(reached)
    while queue:
        current = queue.popleft()
        for edge in graph[current].get("exits", []):
            target = str(edge.get("to", ""))
            if target in graph and target not in reached:
                reached.add(target)
                queue.append(target)
    return reached


def build_report(root: Path, session_log: Path | None = None) -> dict[str, Any]:
    root = root.resolve()
    graph = _read_json(root / "data/world_graph.json")
    classes = _read_json(root / "data/Tables/CLASSES.json")
    quest_points = _read_json(root / "data/quest_points.json")
    class_speeds = {
        name: float(definition.get("speed", 0.0)) * PIXELS_PER_GAME_SPEED_UNIT
        for name, definition in classes.items()
    }
    positive_speeds = [speed for speed in class_speeds.values() if speed > 0]
    fastest_speed = max(positive_speeds, default=0.0)
    slowest_speed = min(positive_speeds, default=0.0)

    maps: list[dict[str, Any]] = []
    errors: list[str] = []
    for key, graph_entry in sorted(graph.items()):
        map_path = root / "data/Maps" / f"{key}.json"
        if not map_path.is_file():
            errors.append(f"world graph map has no data file: {key}")
            continue
        try:
            definition = _read_json(map_path)
            data = definition["data"]
            width, height = int(data["w"]), int(data["h"])
            if width <= 0 or height <= 0:
                raise ValueError("map dimensions must be positive")
        except (KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
            errors.append(f"invalid map data for {key}: {exc}")
            continue

        objects = definition.get("objects", [])
        enemies = data.get("enemySpawns", [])
        npcs = data.get("npcs", [])
        items = data.get("items", [])
        exits = data.get("exits", [])
        hazards = data.get("hazards", [])
        map_quests = quest_points.get(key, [])
        neighbours = [str(edge.get("to", "")) for edge in graph_entry.get("exits", [])]
        unknown = sorted(set(neighbours) - set(graph))
        if unknown:
            errors.append(f"{key} points to unknown world graph maps: {', '.join(unknown)}")

        area = width * height
        maps.append({
            "key": key,
            "name": data.get("name", key),
            "kind": "shrine" if key.startswith("shrine_") else "region",
            "width": width,
            "height": height,
            "area": area,
            "ground_file": definition.get("groundFile", f"{key}_ground.jpg"),
            "objects": len(objects),
            "enemies": len(enemies),
            "npcs": len(npcs),
            "items": len(items),
            "exits": len(exits),
            "hazards": len(hazards),
            "quest_points": len(map_quests),
            "bosses": len(graph_entry.get("bosses", {})),
            "connections": neighbours,
            "objects_per_10000_area": round(len(objects) * 10000 / area, 3),
            "enemies_per_100000_area": round(len(enemies) * 100000 / area, 3),
            "shortest_straight_boundary_crossing_seconds_fastest_class": (
                round(min(width, height) / fastest_speed, 2) if fastest_speed else None
            ),
            "longest_straight_boundary_crossing_seconds_slowest_class": (
                round(max(width, height) / slowest_speed, 2) if slowest_speed else None
            ),
        })

    reached = _reachable_from("village", graph)
    shrines = [item for item in maps if item["kind"] == "shrine"]
    regions = [item for item in maps if item["kind"] == "region"]
    areas = [item["area"] for item in maps]
    return {
        "schema_version": 1,
        "measurement_note": (
            "Map size, density and ideal straight-line crossing figures are structural diagnostics, "
            "not estimates of real playtime or campaign length."
        ),
        "summary": {
            "map_count": len(maps),
            "region_count": len(regions),
            "shrine_count": len(shrines),
            "reachable_from_village_count": len(reached),
            "unreachable_from_village": sorted(set(graph) - reached),
            "smallest_map_area": min(areas) if areas else None,
            "largest_map_area": max(areas) if areas else None,
            "mean_width": round(sum(item["width"] for item in maps) / len(maps), 1) if maps else None,
            "mean_height": round(sum(item["height"] for item in maps) / len(maps), 1) if maps else None,
        },
        "class_base_speeds_px_per_second": {key: round(value, 2) for key, value in class_speeds.items()},
        "actual_playtime": _session_durations(session_log),
        "maps": maps,
        "errors": errors,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--report", type=Path, default=Path("artifacts/map-depth-report.json"))
    parser.add_argument("--session-log", type=Path, help="JSONL file containing explicit map_visit duration records")
    args = parser.parse_args()
    report = build_report(args.root, args.session_log)
    output = args.report if args.report.is_absolute() else args.root / args.report
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Maps analysed: {report['summary']['map_count']}")
    print(f"Reachable from village: {report['summary']['reachable_from_village_count']}/{report['summary']['map_count']}")
    print(f"Measured playtime: {report['actual_playtime']['status']}")
    for error in report["errors"]:
        print(f"ERROR: {error}", file=sys.stderr)
    print("MAP_DEPTH_AUDIT_PASSED" if not report["errors"] else "MAP_DEPTH_AUDIT_FAILED")
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
