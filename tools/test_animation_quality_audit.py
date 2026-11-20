"""Unit tests for frame-level sprite animation quality metrics."""
from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from animation_quality_audit import audit, frame_metrics
from PIL import Image, ImageDraw


class AnimationQualityAuditTests(unittest.TestCase):
    def test_detects_duplicate_frames_and_measures_motion(self) -> None:
        first = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        ImageDraw.Draw(first).rectangle((4, 2, 9, 14), fill=(220, 120, 50, 255))
        third = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        ImageDraw.Draw(third).rectangle((5, 2, 10, 14), fill=(220, 120, 50, 255))
        metrics = frame_metrics([first, first.copy(), third])
        self.assertEqual(metrics["unique_frames"], 2)
        self.assertEqual(metrics["duplicate_pairs"], [[0, 1]])
        self.assertGreater(metrics["mean_adjacent_changed_pixel_ratio"], 0.0)
        self.assertEqual(metrics["visible_bottom_range_px"], 0)

    def make_project(self, root: Path) -> None:
        manifest = {
            "heroes": {
                "warrior_starter": {
                    "cellW": 16, "cellH": 16,
                    "rows": ["down", "up", "side"],
                    "cols": ["walk0", "walk1", "walk2", "walk3", "attack"],
                }
            },
            "enemies": {
                "shade": {"cellW": 12, "cellH": 10, "frames": 2},
                "static_prop": {"cellW": 8, "cellH": 8, "frames": 1},
                "procedural": {"error": "drawn by code"},
            },
        }
        (root / "data").mkdir()
        hero_dir = root / "assets/art/Heroes"
        enemy_dir = root / "assets/art/Enemies"
        hero_dir.mkdir(parents=True)
        enemy_dir.mkdir(parents=True)
        (root / "data/art_manifest.json").write_text(json.dumps(manifest), encoding="utf-8")

        hero = Image.new("RGBA", (80, 48), (0, 0, 0, 0))
        draw = ImageDraw.Draw(hero)
        for row in range(3):
            for col in range(4):
                x = 3 + col
                draw.rectangle((col * 16 + x, row * 16 + 2, col * 16 + x + 5, row * 16 + 13), fill=(220, 100, 40, 255))
            draw.rectangle((68, row * 16 + 2, 73, row * 16 + 13), fill=(220, 100, 40, 255))
        hero.save(hero_dir / "warrior_starter.png")

        enemy = Image.new("RGBA", (24, 10), (0, 0, 0, 0))
        draw = ImageDraw.Draw(enemy)
        draw.rectangle((2, 2, 7, 8), fill=(60, 120, 180, 255))
        draw.rectangle((14, 2, 19, 8), fill=(60, 120, 180, 255))
        enemy.save(enemy_dir / "shade.png")
        Image.new("RGBA", (8, 8), (0, 0, 0, 0)).save(enemy_dir / "static_prop.png")

    def test_audits_hero_attacks_and_enemy_cycle_lengths(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.make_project(root)
            report = audit(root)
        self.assertEqual(report["hero_looks"], 1)
        self.assertEqual(report["hero_walk_clips"], 3)
        self.assertEqual(report["hero_attack_clips"], 3)
        self.assertEqual(report["enemy_sprite_sheets"], 2)
        self.assertEqual(report["enemy_variant_frame_counts"], {1: 1, 2: 1})
        self.assertEqual(report["warning_counts"]["hero_attack_is_one_pose"], 3)
        self.assertEqual(report["warning_counts"]["limited_two_frame_cycle"], 1)
        self.assertFalse(report["errors"])
        self.assertEqual(len(report["skipped"]), 1)

    def test_rejects_wrong_sheet_dimensions(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.make_project(root)
            Image.new("RGBA", (79, 48), (0, 0, 0, 0)).save(
                root / "assets/art/Heroes/warrior_starter.png"
            )
            report = audit(root)
        self.assertTrue(any("expected 80x48" in error for error in report["errors"]))


if __name__ == "__main__":
    unittest.main()
