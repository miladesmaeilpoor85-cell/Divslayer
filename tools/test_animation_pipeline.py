
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from PIL import Image

from animation_pipeline import build_animation

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "creative/animation/warrior_starter_attack.json"


class AnimationPipelineTests(unittest.TestCase):
    def test_builds_three_direction_four_frame_attack_sheet(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            report = build_animation(CONFIG, output)
            self.assertEqual(report["status"], "passed")
            self.assertEqual(report["total_frames"], 12)
            self.assertEqual(report["asset_dimensions"], [640, 468])
            self.assertEqual(report["directions"], ["down", "up", "side"])
            self.assertEqual(report["frames_per_direction"], 4)

            with Image.open(output / report["asset"]) as opened:
                atlas = opened.convert("RGBA")
            self.assertEqual(atlas.size, (640, 468))
            for row in range(3):
                for column in range(4):
                    cell = atlas.crop(
                        (column * 160, row * 156, (column + 1) * 160, (row + 1) * 156)
                    )
                    self.assertIsNotNone(cell.getchannel("A").getbbox())

            for preview in report["previews"]:
                with Image.open(output / preview) as gif:
                    self.assertEqual(gif.n_frames, 4)


    def test_validates_and_previews_the_tracked_editable_atlas(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            report = build_animation(CONFIG, output)
            self.assertEqual(report["status"], "passed")
            self.assertEqual(report["total_frames"], 12)
            self.assertEqual(report["asset_dimensions"], [640, 468])
            self.assertEqual(report["fps"], 25)
            self.assertEqual(report["directions"], ["down", "up", "side"])
            for preview in report["previews"]:
                with Image.open(output / preview) as gif:
                    self.assertEqual(gif.n_frames, 4)

    def test_build_is_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            one = build_animation(CONFIG, Path(first))
            two = build_animation(CONFIG, Path(second))
            self.assertEqual(one["asset_sha256"], two["asset_sha256"])


if __name__ == "__main__":
    unittest.main()
