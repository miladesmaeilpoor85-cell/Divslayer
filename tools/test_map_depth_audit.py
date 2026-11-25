"""Tests for world depth and explicitly measured playtime reporting."""
from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from map_depth_audit import build_report


class MapDepthAuditTests(unittest.TestCase):
    def make_repo(self, root: Path) -> None:
        (root / "data/Maps").mkdir(parents=True)
        (root / "data/Tables").mkdir(parents=True)
        graph = {
            "village": {"w": 900, "h": 650, "exits": [{"to": "shrine_echoes"}], "bosses": {}},
            "shrine_echoes": {"w": 680, "h": 520, "exits": [{"to": "village"}], "bosses": {}},
            "scriptedConnections": [
                {"from": "village", "to": "shrine_echoes", "via": "test gate", "condition": "test"}
            ],
        }
        (root / "data/world_graph.json").write_text(json.dumps(graph), encoding="utf-8")
        (root / "data/Tables/CLASSES.json").write_text(
            json.dumps({"warrior": {"speed": 2.7}, "rogue": {"speed": 3.4}}), encoding="utf-8"
        )
        (root / "data/quest_points.json").write_text(json.dumps({"village": []}), encoding="utf-8")
        for key, width, height in (("village", 900, 650), ("shrine_echoes", 680, 520)):
            definition = {
                "groundScale": 2,
                "objects": [{"sprite": "tree"}],
                "data": {
                    "name": key,
                    "w": width,
                    "h": height,
                    "exits": [{"to": "shrine_echoes" if key == "village" else "village"}],
                    "npcs": [],
                    "enemySpawns": [],
                    "items": [],
                    "hazards": [],
                },
            }
            (root / "data/Maps" / f"{key}.json").write_text(json.dumps(definition), encoding="utf-8")

    def test_layout_metrics_are_not_presented_as_playtime(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.make_repo(root)
            report = build_report(root)
            self.assertEqual(report["summary"]["map_count"], 2)
            self.assertEqual(report["summary"]["shrine_count"], 1)
            self.assertEqual(report["summary"]["reachable_by_static_exits_count"], 1)
            self.assertEqual(report["summary"]["reachable_with_declared_scripted_gates_count"], 2)
            self.assertEqual(report["summary"]["unreachable_after_declared_scripted_gates"], [])
            self.assertEqual(report["actual_playtime"]["status"], "not_measured")
            self.assertIsNone(report["actual_playtime"]["total_seconds"])
            village = next(item for item in report["maps"] if item["key"] == "village")
            self.assertGreater(village["shortest_straight_boundary_crossing_seconds_fastest_class"], 0)

    def test_explicit_map_visit_records_are_aggregated(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.make_repo(root)
            log = root / "playtest.jsonl"
            log.write_text(
                '{"event":"map_visit","map":"village","duration_seconds":31.25,"method":"manual"}\n'
                '{"event":"map_visit","map":"village","duration_seconds":18.75,"method":"manual"}\n',
                encoding="utf-8",
            )
            report = build_report(root, log)
            self.assertEqual(report["actual_playtime"]["status"], "measured")
            self.assertEqual(report["actual_playtime"]["visit_count"], 2)
            self.assertEqual(report["actual_playtime"]["total_seconds"], 50.0)
            self.assertEqual(report["actual_playtime"]["by_map"]["village"]["visits"], 2)

    def test_unknown_graph_connection_is_a_blocker(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.make_repo(root)
            path = root / "data/world_graph.json"
            graph = json.loads(path.read_text(encoding="utf-8"))
            graph["village"]["exits"].append({"to": "missing_region"})
            path.write_text(json.dumps(graph), encoding="utf-8")
            report = build_report(root)
            self.assertTrue(any("unknown world graph maps" in error for error in report["errors"]))


if __name__ == "__main__":
    unittest.main()
