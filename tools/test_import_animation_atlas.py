"""Regression coverage for hero attack-atlas extraction."""
from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from import_animation_atlas import _key_connected_background, _key_global_background, import_atlas
from PIL import Image, ImageDraw


class AnimationAtlasImportTests(unittest.TestCase):
    def make_atlas(self, path: Path, duplicate_last: bool = False) -> None:
        image = Image.new("RGBA", (1024, 768), (255, 0, 255, 255))
        draw = ImageDraw.Draw(image)
        for row in range(3):
            for col in range(4):
                x, y = col * 256 + 92, row * 256 + 25 + col * 2
                color = (35 + row * 25, 90, 155, 255)
                draw.ellipse((x, y, x + 62, y + 62), fill=color)
                draw.rectangle((x + 13, y + 55, x + 48, y + 190 - col * 5), fill=color)
                draw.line((x + 18, y + 95, x + 5 + col * 23, y + 145), fill=(245, 210, 120, 255), width=12)
                draw.line((x + 40, y + 95, x + 78 - col * 18, y + 150), fill=(245, 210, 120, 255), width=12)
                draw.rectangle((x + 5, y + 180 - col * 5, x + 28, y + 198 - col * 5), fill=color)
                if duplicate_last and col == 3:
                    source = image.crop((2 * 256, row * 256, 3 * 256, (row + 1) * 256))
                    image.paste(source, (3 * 256, row * 256))
        image.save(path)

    def test_splits_transparent_frames_and_aligns_foot_baselines(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source, output = root / "mage.png", root / "out"
            self.make_atlas(source)
            report = import_atlas(source, output, prefix="mage_starter_attack")
            self.assertEqual(report["status"], "passed")
            self.assertEqual(report["output_dimensions"], [640, 468])
            self.assertTrue(all(len(row) == 4 for row in report["frame_files"]))
            self.assertTrue(all(frame["output_bbox"][3] == 150 for frame in report["frames"]))
            with Image.open(output / report["output_atlas"]) as atlas:
                self.assertEqual(atlas.getpixel((0, 0))[3], 0)
                self.assertEqual(atlas.size, (640, 468))
            saved = json.loads((output / "mage_starter_attack_import_report.json").read_text())
            self.assertEqual(saved["output_sha256"], report["output_sha256"])

    def test_global_key_removes_enclosed_chroma_islands_but_default_preserves_them(self) -> None:
        background = Image.new("RGBA", (20, 20), (255, 0, 255, 255))
        draw = ImageDraw.Draw(background)
        draw.rectangle((5, 5, 14, 14), outline=(255, 255, 255, 255), width=2)

        edge_connected = background.copy()
        _key_connected_background(edge_connected, (255, 0, 255), 72)
        self.assertEqual(edge_connected.getpixel((9, 9))[3], 255)

        global_key = background.copy()
        removed = _key_global_background(global_key, (255, 0, 255), 72)
        self.assertGreater(removed, 0)
        self.assertEqual(global_key.getpixel((9, 9))[3], 0)
        self.assertEqual(global_key.getpixel((5, 5))[3], 255)

    def test_global_key_mode_is_recorded_in_import_report(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source, output = root / "rogue.png", root / "out"
            self.make_atlas(source)
            report = import_atlas(source, output, prefix="rogue_starter_attack", global_key=True)
        self.assertEqual(report["key_mode"], "global")

    def test_detects_duplicates_without_silently_promoting_them(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "rogue.png"
            self.make_atlas(source, duplicate_last=True)
            report = import_atlas(source, root / "out", prefix="rogue_starter_attack")
        self.assertEqual(report["status"], "passed_with_warnings")
        self.assertTrue(any(report["duplicate_pairs"][direction] for direction in ("down", "up", "side")))

    def test_rejects_unsafe_output_prefix(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "mage.png"
            self.make_atlas(source)
            with self.assertRaisesRegex(ValueError, "prefix may contain only"):
                import_atlas(source, root / "out", prefix="../escape")

    def test_rejects_wrong_grid_dimensions(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "bad.png"
            Image.new("RGBA", (1023, 768), (255, 0, 255, 255)).save(source)
            with self.assertRaisesRegex(ValueError, "not divisible"):
                import_atlas(source, root / "out", prefix="bad_attack")

    def test_rejects_unrecognized_background(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "bad.png"
            Image.new("RGBA", (1024, 768), (20, 30, 40, 255)).save(source)
            with self.assertRaisesRegex(ValueError, "background removed"):
                import_atlas(source, root / "out", prefix="bad_attack")


if __name__ == "__main__":
    unittest.main()
