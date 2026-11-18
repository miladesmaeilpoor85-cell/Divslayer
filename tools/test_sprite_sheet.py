"""Tests for generated character sprite-sheet input validation."""

import tempfile
import unittest
from pathlib import Path

import sprite_sheet
from PIL import Image


class SpriteSheetTransparencyTests(unittest.TestCase):
    def test_rejects_rgb_checkerboard_as_fake_transparency(self) -> None:
        image = Image.new("RGB", (32, 32), (245, 245, 245))
        for y in range(0, 32, 8):
            for x in range(0, 32, 8):
                if (x // 8 + y // 8) % 2:
                    for yy in range(y, y + 8):
                        for xx in range(x, x + 8):
                            image.putpixel((xx, yy), (160, 160, 160))
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "checkerboard.png"
            image.save(path)
            with self.assertRaisesRegex(SystemExit, "alpha channel"):
                sprite_sheet.load_rgba(str(path))

    def test_preserves_real_rgba_transparency_and_soft_edges(self) -> None:
        image = Image.new("RGBA", (4, 1), (120, 80, 40, 255))
        image.putalpha(Image.new("L", (4, 1)))
        pixels = image.load()
        pixels[0, 0] = (120, 80, 40, 0)
        pixels[1, 0] = (120, 80, 40, 8)
        pixels[2, 0] = (120, 80, 40, 128)
        pixels[3, 0] = (120, 80, 40, 248)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "real_alpha.png"
            image.save(path)
            result = sprite_sheet.load_rgba(str(path))
        alpha = result.getchannel("A")
        self.assertEqual(alpha.getpixel((0, 0)), 0)
        self.assertEqual(alpha.getpixel((1, 0)), 0)
        self.assertGreater(alpha.getpixel((2, 0)), 120)
        self.assertEqual(alpha.getpixel((3, 0)), 255)

    def test_accepts_palette_png_with_transparency_index(self) -> None:
        image = Image.new("P", (2, 2), 1)
        image.putpalette([0, 0, 0, 255, 0, 0] + [0, 0, 0] * 254)
        image.info["transparency"] = 0
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "palette_alpha.png"
            image.save(path, transparency=0)
            result = sprite_sheet.load_rgba(str(path))
        self.assertEqual(result.getpixel((0, 0))[3], 255)


if __name__ == "__main__":
    unittest.main()
