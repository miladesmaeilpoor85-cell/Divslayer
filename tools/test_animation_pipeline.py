from __future__ import annotations

import json
import shutil
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
                self.assertEqual(walk["fps"], 9.0)
                self.assertEqual(walk["frame_duration_ms"], 110)
                self.assertEqual(attack["frame_count"], 1)
                self.assertFalse(attack["loop"])
                self.assertEqual(attack["fps"], 24.0)
                self.assertEqual(attack["frame_duration_ms"], 40)
                with Image.open(output / walk["file"]) as gif:
                    self.assertEqual(gif.n_frames, 4)
                    self.assertEqual(gif.info.get("duration"), 110)
                with Image.open(output / attack["file"]) as gif:
                    self.assertEqual(gif.n_frames, 1)
                    self.assertEqual(gif.info.get("duration"), 40)

    def _temporary_project(self, temporary: str, *, clip_fps: float | None = None) -> Path:
        root = Path(temporary)
        config_path = root / "creative/animation/config.json"
        config_path.parent.mkdir(parents=True)
        source_path = root / "assets/art/Heroes/warrior_starter.png"
        source_path.parent.mkdir(parents=True)
        shutil.copyfile(ROOT / "assets/art/Heroes/warrior_starter.png", source_path)
        config = json.loads(CONFIG.read_text(encoding="utf-8"))
        for clip in config["clips"]:
            if clip_fps is None:
                clip.pop("fps", None)
            elif clip["name"] == "attack":
                clip["fps"] = clip_fps
        config_path.write_text(json.dumps(config), encoding="utf-8")
        return config_path

    def test_legacy_clips_inherit_global_fps(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            config_path = self._temporary_project(temporary)
            report = build_animation(config_path, Path(temporary) / "out")
            self.assertTrue(all(clip["fps"] == 9.0 for clip in report["preview_clips"]))
            self.assertTrue(all(clip["frame_duration_ms"] == 110 for clip in report["preview_clips"]))

    def test_rejects_non_positive_clip_fps(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            config_path = self._temporary_project(temporary, clip_fps=0)
            with self.assertRaisesRegex(ValueError, "FPS must be positive"):
                build_animation(config_path, Path(temporary) / "out")

    def test_build_is_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            one = build_animation(CONFIG, Path(first))
            two = build_animation(CONFIG, Path(second))
            self.assertEqual(one["asset_sha256"], two["asset_sha256"])
            self.assertEqual(one["preview_clips"], two["preview_clips"])


if __name__ == "__main__":
    unittest.main()
