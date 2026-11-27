"""Tests for the quality-first import normalizer."""
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from enforce_quality_first_imports import normalize_import_text, process_import


class QualityFirstImportNormalizerTests(unittest.TestCase):
    def test_lossy_and_downscaled_import_is_normalized(self) -> None:
        source = (
            "[remap]\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n"
            "[params]\ncompress/mode=1\ndetect_3d/compress_to=1\nprocess/size_limit=512\n"
        )
        result, changed = normalize_import_text(source)
        self.assertTrue(changed)
        self.assertIn("compress/mode=0", result)
        self.assertIn("detect_3d/compress_to=0", result)
        self.assertIn("process/size_limit=0", result)

    def test_normalized_import_is_idempotent(self) -> None:
        source = (
            "[params]\ncompress/mode=0\ndetect_3d/compress_to=0\nprocess/size_limit=0\n"
        )
        result, changed = normalize_import_text(source)
        self.assertFalse(changed)
        self.assertEqual(result, source)

    def test_missing_settings_are_added(self) -> None:
        source = "[remap]\nimporter=\"texture\"\n[params]\n"
        result, changed = normalize_import_text(source)
        self.assertTrue(changed)
        self.assertIn("compress/mode=0", result)
        self.assertIn("detect_3d/compress_to=0", result)
        self.assertIn("process/size_limit=0", result)

    def test_check_only_does_not_modify_file(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "hero.png.import"
            path.write_text(
                "[params]\ncompress/mode=1\ndetect_3d/compress_to=1\nprocess/size_limit=0\n",
                encoding="utf-8",
            )
            changed, error = process_import(path, check_only=True)
            self.assertTrue(changed)
            self.assertIsNone(error)
            self.assertIn("compress/mode=1", path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
