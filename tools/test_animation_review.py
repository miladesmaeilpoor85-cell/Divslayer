"""Unit tests for sprite-sheet animation review previews."""
from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

import animation_review


class AnimationReviewTests(unittest.TestCase):
    def _project(self, root: Path) -> tuple[Path, Path]:
        (root / "data").mkdir()
        hero_dir = root / "assets" / "art" / "Heroes"
        enemy_dir = root / "assets" / "art" / "Enemies"
        hero_dir.mkdir(parents=True)
        enemy_dir.mkdir(parents=True)
        manifest = {
            "heroes": {
                "warrior_starter": {
                    "cellW": 16,
                    "cellH": 16,
                    "rows": ["down", "up", "side"],
                    "cols": ["walk0", "walk1", "walk2", "walk3", "attack"],
                    "pivot": [0.5, 0.125],
                }
            },
            "enemies": {
                "shade": {
                    "cellW": 12,
                    "cellH": 10,
                    "frames": 3,
                    "variants": 2,
                    "pivot": [0.5, 0.1],
                    "timedMs": 125,
                },
                "single_pose": {
                    "cellW": 8,
                    "cellH": 8,
                    "frames": 1,
                    "variants": 1,
                    "pivot": [0.5, 0.0],
                },
                "unbuilt": {"error": "source art is not ready"},
            },
        }
        manifest_path = root / "data" / "art_manifest.json"
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

        hero = Image.new("RGBA", (16 * 5, 16 * 3), (0, 0, 0, 0))
        draw = ImageDraw.Draw(hero)
        for row in range(3):
            for col in range(5):
                draw.rectangle(
                    (col * 16 + 4, row * 16 + 3, col * 16 + 11, row * 16 + 14),
                    fill=(220, 90 + col * 10, 40, 255),
                )
        hero.save(hero_dir / "warrior_starter.png")

        enemy = Image.new("RGBA", (12 * 3, 10 * 2), (0, 0, 0, 0))
        draw = ImageDraw.Draw(enemy)
        for row in range(2):
            for col in range(3):
                draw.rectangle(
                    (col * 12 + 2, row * 10 + 2, col * 12 + 9, row * 10 + 8),
                    fill=(70, 40 + row * 80, 160 + col * 20, 255),
                )
        enemy.save(enemy_dir / "shade.png")
        Image.new("RGBA", (8, 8), (255, 255, 255, 0)).save(enemy_dir / "single_pose.png")
        return manifest_path, root / "artifacts" / "animation-review"

    def test_exports_hero_walks_enemy_variants_and_single_frame_pose(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _, output = self._project(root)
            report = animation_review.review_sheets(
                root, Path("data/art_manifest.json"), Path("artifacts/animation-review")
            )
            self.assertEqual(report["checked"], 3)
            self.assertEqual(report["valid"], 3)
            self.assertEqual(len(report["skipped"]), 1)
            self.assertFalse(report["errors"])
            self.assertTrue((output / "hero-warrior_starter-side-walk.gif").is_file())
            self.assertTrue((output / "hero-warrior_starter-side-attack.png").is_file())
            self.assertTrue((output / "enemy-shade-variant-1-loop.gif").is_file())
            self.assertTrue(
                (output / "enemy-single_pose-variant-0-still.png").is_file()
            )
            with Image.open(output / "enemy-shade-variant-1-loop.gif") as gif:
                self.assertEqual(gif.n_frames, 3)
                self.assertEqual(
                    gif.info["duration"], 120
                )  # GIF delays use 10 ms units.

    def test_reports_sheet_dimensions_that_do_not_match_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._project(root)
            bad = root / "assets" / "art" / "Heroes" / "warrior_starter.png"
            Image.new("RGBA", (79, 48), (255, 0, 0, 255)).save(bad)
            report = animation_review.review_sheets(
                root, Path("data/art_manifest.json"), Path("artifacts/review")
            )
            self.assertTrue(
                any("expected 80x48" in error for error in report["errors"])
            )
            self.assertEqual(report["valid"], 2)

    def test_rejects_invalid_scale(self) -> None:
        with self.assertRaises(ValueError):
            animation_review.review_sheets(
                Path("."), Path("missing.json"), Path("out"), scale=0
            )


if __name__ == "__main__":
    unittest.main()
