"""Regression tests for map preview ground-image path resolution."""
from __future__ import annotations

import os
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from map_preview import ground_image_path  # noqa: E402


class MapPreviewGroundPathTests(unittest.TestCase):
    def test_honors_explicit_ground_file_override(self) -> None:
        path = ground_image_path("/project", "alborz", {"groundFile": "frostvale_ground.jpg"})
        self.assertEqual(
            path,
            os.path.join("/project", "assets", "art", "Maps", "frostvale_ground.jpg"),
        )

    def test_falls_back_to_map_key_ground_file(self) -> None:
        path = ground_image_path("/project", "forest", {"data": {}})
        self.assertEqual(
            path,
            os.path.join("/project", "assets", "art", "Maps", "forest_ground.jpg"),
        )


if __name__ == "__main__":
    unittest.main()
