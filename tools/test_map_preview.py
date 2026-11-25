"""Regression tests for map preview ground-image path resolution."""
from __future__ import annotations

import json
import os
import sys
import unittest
from pathlib import Path

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


if __name__ == "__main__":
    unittest.main()
