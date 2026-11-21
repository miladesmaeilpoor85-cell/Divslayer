import base64
import csv
import struct
import tempfile
import unittest
from pathlib import Path

from asset_audit import audit_repository, image_dimensions


def png_bytes(width=2, height=3):
    signature = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", width, height) + b"\x08\x06\x00\x00\x00" + bytes(4)
    iend = struct.pack(">I", 0) + b"IEND" + b"\xaeB\x60\x82"
    return signature + ihdr + iend


def jpeg_bytes(width=4, height=5):
    frame = bytes([8]) + height.to_bytes(2, "big") + width.to_bytes(2, "big") + bytes([1, 1, 0x11, 0])
    return b"\xff\xd8\xff\xc0" + (11).to_bytes(2, "big") + frame + b"\xff\xd9"


def webp_vp8x_bytes(width=6, height=7):
    payload = bytearray(10)
    payload[4:7] = (width - 1).to_bytes(3, "little")
    payload[7:10] = (height - 1).to_bytes(3, "little")
    body = b"WEBP" + b"VP8X" + (10).to_bytes(4, "little") + bytes(payload)
    return b"RIFF" + len(body).to_bytes(4, "little") + body


class AssetAuditTests(unittest.TestCase):
    def make_repo(self):
        temp = tempfile.TemporaryDirectory()
        root = Path(temp.name)
        (root / "assets/art/Enemies").mkdir(parents=True)
        (root / "assets/audio/sfx").mkdir(parents=True)
        (root / "docs").mkdir()
        self.addCleanup(temp.cleanup)
        return root

    def write_registry(self, root, rows):
        with (root / "docs/ASSET_RIGHTS_REGISTER.csv").open("w", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=["asset_path", "commercial_use_status"])
            writer.writeheader()
            writer.writerows(rows)

    def test_reads_png_jpeg_and_webp_dimensions(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixtures = {
                "x.png": (png_bytes(2, 3), (2, 3)),
                "x.jpg": (jpeg_bytes(4, 5), (4, 5)),
                "x.webp": (webp_vp8x_bytes(6, 7), (6, 7)),
            }
            for name, (payload, expected) in fixtures.items():
                path = root / name
                path.write_bytes(payload)
                self.assertEqual(image_dimensions(path), expected)

    def test_clean_assets_pass_and_unverified_is_only_a_warning(self):
        root = self.make_repo()
        (root / "assets/art/Enemies/a.png").write_bytes(png_bytes())
        (root / "assets/audio/sfx/hit.ogg").write_bytes(b"OggS" + bytes([0]) + bytes(22))
        self.write_registry(root, [{"asset_path": "assets/art/Enemies/a.png", "commercial_use_status": "UNVERIFIED"}])
        report = audit_repository(root)
        self.assertEqual(report["errors"], [])
        self.assertEqual(report["artwork_files"], 1)
        self.assertEqual(report["audio_files_checked"], 1)
        self.assertTrue(any("UNVERIFIED" in warning for warning in report["warnings"]))

    def test_unregistered_image_fails(self):
        root = self.make_repo()
        (root / "assets/art/Enemies/a.png").write_bytes(png_bytes())
        self.write_registry(root, [])
        report = audit_repository(root)
        self.assertTrue(any("not registered" in error for error in report["errors"]))

    def test_missing_registered_file_fails(self):
        root = self.make_repo()
        self.write_registry(root, [{"asset_path": "assets/art/Enemies/missing.png", "commercial_use_status": "UNVERIFIED"}])
        report = audit_repository(root)
        self.assertTrue(any("missing file" in error for error in report["errors"]))

    def test_corrupt_image_and_audio_fail(self):
        root = self.make_repo()
        (root / "assets/art/Enemies/a.png").write_bytes(b"not a png")
        (root / "assets/audio/sfx/hit.ogg").write_bytes(b"not an ogg")
        self.write_registry(root, [{"asset_path": "assets/art/Enemies/a.png", "commercial_use_status": "UNVERIFIED"}])
        report = audit_repository(root)
        self.assertTrue(any("invalid artwork file" in error for error in report["errors"]))
        self.assertTrue(any("invalid audio file" in error for error in report["errors"]))

    def test_project_icon_outside_art_directory_is_included(self):
        root = self.make_repo()
        (root / "icon.png").write_bytes(png_bytes())
        self.write_registry(root, [{"asset_path": "icon.png", "commercial_use_status": "UNVERIFIED"}])
        report = audit_repository(root)
        self.assertEqual(report["errors"], [])
        self.assertEqual(report["artwork_files"], 1)

    def test_base64_attack_atlas_parts_reassemble_and_are_registered(self):
        root = self.make_repo()
        payload_dir = root / "assets/art/Heroes/attack_atlas_data/rogue"
        payload_dir.mkdir(parents=True)
        encoded = base64.b64encode(png_bytes(640, 468)).decode("ascii")
        split = len(encoded) // 2
        split -= split % 4
        parts = [encoded[:split], encoded[split:]]
        paths = []
        for index, part in enumerate(parts):
            rel = f"assets/art/Heroes/attack_atlas_data/rogue/part_{index:02d}.b64"
            (root / rel).write_text(part, encoding="ascii")
            paths.append({"asset_path": rel, "commercial_use_status": "UNVERIFIED"})
        self.write_registry(root, paths)

        report = audit_repository(root)
        self.assertEqual(report["errors"], [])
        self.assertEqual(report["atlas_payload_parts"], 2)
        self.assertEqual(report["atlas_payloads_checked"], 1)
        self.assertEqual(report["registered_atlas_payload_parts"], 2)

    def test_base64_attack_atlas_missing_part_fails(self):
        root = self.make_repo()
        payload_dir = root / "assets/art/Heroes/attack_atlas_data/rogue"
        payload_dir.mkdir(parents=True)
        encoded = base64.b64encode(png_bytes(640, 468)).decode("ascii")
        split = len(encoded) // 2
        split -= split % 4
        parts = [encoded[:split], encoded[split:]]
        paths = []
        for index, part in ((0, parts[0]), (2, parts[1])):
            rel = f"assets/art/Heroes/attack_atlas_data/rogue/part_{index:02d}.b64"
            (root / rel).write_text(part, encoding="ascii")
            paths.append({"asset_path": rel, "commercial_use_status": "UNVERIFIED"})
        self.write_registry(root, paths)

        report = audit_repository(root)
        self.assertTrue(any("missing or out of order" in error for error in report["errors"]))

    def test_path_traversal_is_rejected(self):
        root = self.make_repo()
        self.write_registry(root, [{"asset_path": "assets/art/../../outside.png", "commercial_use_status": "UNVERIFIED"}])
        report = audit_repository(root)
        self.assertTrue(any("unsafe path" in error for error in report["errors"]))


if __name__ == "__main__":
    unittest.main()
