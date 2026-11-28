"""Regression tests for map preview ground-image path resolution."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from map_preview import ground_image_path


class MapPreviewGroundPathTests(unittest.TestCase):
    def test_honors_explicit_ground_file_override(self) -> None:
        path = ground_image_path("/project", "alborz", {"groundFile": "frostvale_ground.jpg"})
        self.assertEqual(
            path,
            os.path.join("/project", "assets", "art", "Maps", "frostvale_ground.jpg"),
        )

    def test_dedicated_region_ground_art_is_used_instead_of_tiled_terrain(self) -> None:
        root = Path(__file__).resolve().parents[1]
        terrain = json.loads((root / "data/terrain.json").read_text(encoding="utf-8"))
        tiled_maps = terrain.get("maps", {})

        for key in ("village", "forest", "peaks"):
            definition = json.loads(
                (root / "data/Maps" / f"{key}.json").read_text(encoding="utf-8")
            )
            ground_path = Path(ground_image_path(str(root), key, definition))
            self.assertTrue(ground_path.is_file(), f"{key} ground image is missing")
            self.assertEqual(ground_path.suffix.lower(), ".svg")
            self.assertNotIn(
                key,
                tiled_maps,
                f"{key} has a dedicated painted ground image and must not hide it behind tiled terrain",
            )

    def test_falls_back_to_map_key_ground_file(self) -> None:
        path = ground_image_path("/project", "forest", {"data": {}})
        self.assertEqual(
            path,
            os.path.join("/project", "assets", "art", "Maps", "forest_ground.jpg"),
        )


    def test_dedicated_ground_svgs_match_logical_maps_at_two_x_resolution(self) -> None:
        root = Path(__file__).resolve().parents[1]
        for key in ("village", "forest", "peaks"):
            definition = json.loads(
                (root / "data/Maps" / f"{key}.json").read_text(encoding="utf-8")
            )
            data = definition["data"]
            svg_path = root / "assets/art/Maps" / definition["groundFile"]
            svg_root = ET.parse(svg_path).getroot()
            width = int(float(svg_root.attrib["width"].removesuffix("px")))
            height = int(float(svg_root.attrib["height"].removesuffix("px")))
            view_box = [float(value) for value in svg_root.attrib["viewBox"].replace(",", " ").split()]
            self.assertEqual(view_box, [0.0, 0.0, float(data["w"]), float(data["h"])])
            self.assertEqual((width, height), (int(data["w"]) * 2, int(data["h"]) * 2))
            self.assertGreaterEqual(len(list(svg_root.iter("{http://www.w3.org/2000/svg}path"))), 20)

    def test_clean_preview_renders_a_native_logical_size_region(self) -> None:
        root = Path(__file__).resolve().parents[1]
        renderer = root / "tools/map_preview.py"
        with tempfile.TemporaryDirectory() as temp_dir:
            destination = Path(temp_dir) / "village-clean.png"
            result = subprocess.run(
                [sys.executable, str(renderer), "village", str(destination), "--scale", "1.0", "--clean"],
                cwd=root,
                capture_output=True,
                text=True,
                timeout=120,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
            with Image.open(destination) as preview:
                self.assertEqual(preview.size, (900, 650))
                self.assertGreater(len(preview.getcolors(maxcolors=1_000_000) or []), 64)


if __name__ == "__main__":
    unittest.main()
