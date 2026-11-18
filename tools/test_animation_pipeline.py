from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from animation_pipeline import build_animation

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "creative/animation/warrior_starter_attack.json"


class AnimationPipelineTests(unittest.TestCase):
    def test_validates_and_previews_the_tracked_warrior_sheet(self) -> None:
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

            for preview in report["previews"]:
                with Image.open(output / preview) as gif:
                    self.assertEqual(gif.n_frames, 5)

    def test_build_is_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            one = build_animation(CONFIG, Path(first))
            two = build_animation(CONFIG, Path(second))
            self.assertEqual(one["asset_sha256"], two["asset_sha256"])


if __name__ == "__main__":
    unittest.main()
