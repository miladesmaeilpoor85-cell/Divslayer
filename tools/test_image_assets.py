"""Regression tests for raster and SVG image decoding used by art QA."""
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from PIL import Image

from image_assets import open_image


class ImageAssetsTests(unittest.TestCase):
    def test_loads_raster_as_detached_rgba(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "sample.png"
            Image.new("RGB", (7, 5), (25, 50, 75)).save(path)
            image = open_image(path)
            self.assertEqual(image.size, (7, 5))
            self.assertEqual(image.mode, "RGBA")
            self.assertEqual(image.getpixel((0, 0)), (25, 50, 75, 255))

    def test_rasterizes_svg_at_authored_canvas_size(self) -> None:
        svg = """<svg xmlns="http://www.w3.org/2000/svg" width="24" height="16" viewBox="0 0 24 16">
        <rect x="2" y="2" width="10" height="8" fill="#d0e0ef"/>
        </svg>"""
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "sample.svg"
            path.write_text(svg, encoding="utf-8")
            image = open_image(path)
            self.assertEqual(image.size, (24, 16))
            self.assertEqual(image.mode, "RGBA")
            self.assertEqual(image.getpixel((4, 4)), (208, 224, 239, 255))
            self.assertEqual(image.getpixel((20, 12))[3], 0)


if __name__ == "__main__":
    unittest.main()
