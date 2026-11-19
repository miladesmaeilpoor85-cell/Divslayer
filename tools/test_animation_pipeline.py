from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from animation_pipeline import build_animation
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "creative/animation/warrior_starter_attack.json"


class AnimationPipelineTests(unittest.TestCase):
    def test_validates_atlas_and_exports_separate_action_previews(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            report = build_animation(CONFIG, output)
            self.assertEqual(report["status"], "passed")
            self.assertEqual(report["total_frames"], 15)
            self.assertEqual(report["asset_dimensions"], [800, 468])
            self.assertEqual(report["cell_dimensions"], [160, 156])
            self.assertEqual(report["directions"], ["down", "up", "side"])
            self.assertEqual(report["frames_per_direction"], 5)
            self.assertEqual(report["fps"], 9.0)

            with Image.open(output / report["asset"]) as opened:
                self.assertEqual(opened.size, (800, 468))
                atlas = opened.convert("RGBA")
            for row in range(3):
                for column in range(5):
                    cell = atlas.crop(
                        (column * 160, row * 156, (column + 1) * 160, (row + 1) * 156)
                    )
                    self.assertIsNotNone(cell.getchannel("A").getbbox())

            clips = report["preview_clips"]
            self.assertEqual(len(clips), 6)
            by_action = {(item["direction"], item["clip"]): item for item in clips}
            for direction in ["down", "up", "side"]:
                walk = by_action[(direction, "walk")]
                attack = by_action[(direction, "attack")]
                self.assertEqual(walk["frame_count"], 4)
                self.assertTrue(walk["loop"])
                self.assertEqual(attack["frame_count"], 1)
                self.assertFalse(attack["loop"])
                with Image.open(output / walk["file"]) as gif:
                    self.assertEqual(gif.n_frames, 4)
                with Image.open(output / attack["file"]) as gif:
                    self.assertEqual(gif.n_frames, 1)

    def test_build_is_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            one = build_animation(CONFIG, Path(first))
            two = build_animation(CONFIG, Path(second))
            self.assertEqual(one["asset_sha256"], two["asset_sha256"])
            self.assertEqual(one["preview_clips"], two["preview_clips"])


if __name__ == "__main__":
    unittest.main()
