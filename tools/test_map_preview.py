"""Regression tests for map preview ground-image path resolution."""
from __future__ import annotations

import os
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from map_preview import ground_image_path, map_object_image_path


class MapPreviewGroundPathTests(unittest.TestCase):
    def test_honors_explicit_ground_file_override(self) -> None:
        path = ground_image_path("/project", "alborz", {"groundFile": "frostvale_ground.jpg"})
        self.assertEqual(
            path,
            os.path.join("/project", "assets", "art", "Maps", "frostvale_ground.jpg"),
        )

    def test_resolves_svg_map_ground_file(self) -> None:
        path = ground_image_path("/project", "alborz", {"groundFile": "alborz_ground.svg"})
        self.assertEqual(
            path,
            os.path.join("/project", "assets", "art", "Maps", "alborz_ground.svg"),
        )

    def test_resolves_svg_map_object_metadata(self) -> None:
        path = map_object_image_path(
            "/project", "alborz_cairn",
            {"file": "alborz_cairn", "extension": "svg"},
        )
        self.assertEqual(
            path,
            os.path.join("/project", "assets", "art", "MapObjects", "alborz_cairn.svg"),
        )

    def test_rejects_unsafe_map_object_filename(self) -> None:
        with self.assertRaises(ValueError):
            map_object_image_path(
                "/project", "rock", {"file": "../secret", "extension": "svg"}
            )

    def test_falls_back_to_map_key_ground_file(self) -> None:
        path = ground_image_path("/project", "forest", {"data": {}})
        self.assertEqual(
            path,
            os.path.join("/project", "assets", "art", "Maps", "forest_ground.jpg"),
        )


if __name__ == "__main__":
    unittest.main()
