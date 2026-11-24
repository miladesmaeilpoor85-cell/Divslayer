import tempfile
import unittest
from pathlib import Path

from playtest.generate_player_reports import build_report, write_reports


class PlayerReportTests(unittest.TestCase):
    def test_chapter_one_checkpoint_does_not_claim_full_game_completion(self) -> None:
        log = "\n".join([
            "SCREEN 01_real_player_title.png: [شروع بازی]",
            "ASSERTION_PASSED rostam_training_completed",
            "PLAYER_AGENT_LOADOUT weapon=1->1 armour=0->1 gold=30",
            'STEP 14 0.40 s {"do":"state"} -> {"map":"forest","objective":"clue 1/2","hp":"90/100"}',
            'STEP 15 3.10 s {"do":"fight","sec":12} -> won locally',
            "PLAYTEST_ASSERTIONS_PASSED",
            "PLAYTEST_DONE  18.4 s wall",
        ])
        report = build_report("mage", log)
        self.assertEqual(report["journey_status"], "passed")
        self.assertEqual(report["map_visits_observed"], ["forest"])
        self.assertFalse(report["full_game_completion"]["confirmed"])
        self.assertIn("dungeon", report["known_maps_not_observed"])
        self.assertEqual(report["combat_samples"], 1)

    def test_assertion_and_engine_errors_become_blocking_findings(self) -> None:
        log = "ASSERTION_FAILED armour_not_purchased\nPLAYTEST_ASSERTIONS_FAILED 1"
        engine = "SCRIPT ERROR: Parse failed\n"
        report = build_report("warrior", log, engine)
        self.assertEqual(report["journey_status"], "failed")
        self.assertTrue(any(item["severity"] == "BLOCKER" for item in report["qa_issues"]))
        self.assertEqual(len(report["qa_issues"]), 2)

    def test_writes_three_distinct_reports_and_json_evidence(self) -> None:
        report = build_report(
            "rogue",
            "ASSERTION_PASSED test_checkpoint\nPLAYTEST_ASSERTIONS_PASSED\nPLAYTEST_DONE 1.0 s wall",
        )
        with tempfile.TemporaryDirectory() as folder:
            destination = Path(folder)
            write_reports(report, destination)
            self.assertTrue((destination / "player-report.md").is_file())
            self.assertTrue((destination / "critic-report.md").is_file())
            self.assertTrue((destination / "qa-report.md").is_file())
            self.assertTrue((destination / "run-evidence.json").is_file())


if __name__ == "__main__":
    unittest.main()
