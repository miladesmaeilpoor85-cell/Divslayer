"""Tests for the quality-first Godot image-import audit."""
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from quality_first_audit import audit_2d_image_imports


class QualityFirstImportAuditTests(unittest.TestCase):
    def _write_import(self, root: Path, mode: int, size_limit: int = 0) -> None:
        asset = root / "assets" / "art" / "hero.png.import"
        asset.parent.mkdir(parents=True, exist_ok=True)
        asset.write_text(
            "[params]\n"
            f"compress/mode={mode}\n"
            f"process/size_limit={size_limit}\n"
            "detect_3d/compress_to=0\n",
            encoding="utf-8",
        )

    def test_lossless_import_without_downscaling_passes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self._write_import(root, mode=0, size_limit=0)
            report = audit_2d_image_imports(root)
            self.assertEqual(report["files_checked"], 1)
            self.assertEqual(report["errors"], [])

    def test_lossy_import_fails(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self._write_import(root, mode=1)
            report = audit_2d_image_imports(root)
            self.assertTrue(any("Lossless" in item for item in report["errors"]))

    def test_hidden_downscaling_fails(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self._write_import(root, mode=0, size_limit=512)
            report = audit_2d_image_imports(root)
            self.assertTrue(any("downscaling" in item for item in report["errors"]))

    def test_detected_3d_import_must_remain_lossless(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self._write_import(root, mode=0, size_limit=0)
            asset = root / "assets" / "art" / "hero.png.import"
            contents = asset.read_text(encoding="utf-8").replace(
                "detect_3d/compress_to=0", "detect_3d/compress_to=1"
            )
            asset.write_text(contents, encoding="utf-8")
            report = audit_2d_image_imports(root)
            self.assertTrue(any("detect_3d/compress_to" in item for item in report["errors"]))


if __name__ == "__main__":
    unittest.main()
