import csv
import json
import tempfile
import unittest
from pathlib import Path

from release_evidence_audit import audit_release_evidence


class ReleaseEvidenceAuditTests(unittest.TestCase):
    def make_root(self) -> Path:
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        (root / "docs").mkdir()
        (root / "data").mkdir()
        return root

    def write_register(self, root: Path, status: str, proof: str) -> None:
        with (root / "docs" / "ASSET_RIGHTS_REGISTER.csv").open(
            "w", encoding="utf-8", newline=""
        ) as stream:
            writer = csv.DictWriter(
                stream,
                fieldnames=[
                    "asset_path",
                    "commercial_use_status",
                    "proof_reference_private_location",
                ],
            )
            writer.writeheader()
            writer.writerow({
                "asset_path": "assets/art/Heroes/warrior.png",
                "commercial_use_status": status,
                "proof_reference_private_location": proof,
            })

    def write_credits(self, root: Path, status: str, proof: str) -> None:
        payload = {
            "music": [{
                "title": "Test track",
                "commercial_use_status": status,
                "proof_reference_private_location": proof,
            }]
        }
        (root / "data" / "audio_credits.json").write_text(
            json.dumps(payload), encoding="utf-8"
        )

    def test_unverified_artwork_and_music_are_release_blockers(self) -> None:
        root = self.make_root()
        self.write_register(root, "UNVERIFIED", "")
        self.write_credits(root, "UNVERIFIED", "")
        report = audit_release_evidence(root)
        self.assertFalse(report["release_ready"])
        self.assertEqual(report["artwork_evidence_blockers"], 1)
        self.assertEqual(report["music_evidence_blockers"], 1)

    def test_verified_entries_need_a_private_proof_reference(self) -> None:
        root = self.make_root()
        self.write_register(root, "VERIFIED", "private://art/warrior-proof")
        self.write_credits(root, "VERIFIED", "private://audio/track-proof")
        report = audit_release_evidence(root)
        self.assertTrue(report["release_ready"])
        self.assertEqual(report["blockers"], [])
        self.assertEqual(report["errors"], [])

    def test_verified_without_proof_still_blocks_release(self) -> None:
        root = self.make_root()
        self.write_register(root, "VERIFIED", "")
        self.write_credits(root, "VERIFIED", "")
        report = audit_release_evidence(root)
        self.assertFalse(report["release_ready"])
        self.assertEqual(len(report["blockers"]), 2)


if __name__ == "__main__":
    unittest.main()
