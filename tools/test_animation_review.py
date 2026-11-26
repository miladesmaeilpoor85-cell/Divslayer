"""Unit tests for sprite-sheet animation review previews."""
from __future__ import annotations

import base64
import io
import json
import tempfile
import unittest
from pathlib import Path

import animation_review
from PIL import Image, ImageDraw


class AnimationReviewTests(unittest.TestCase):
    def _project(self, root: Path) -> tuple[Path, Path]:
        (root / "data").mkdir()
        hero_dir = root / "assets" / "art" / "Heroes"
        enemy_dir = root / "assets" / "art" / "Enemies"
        hero_dir.mkdir(parents=True)
        enemy_dir.mkdir(parents=True)
        manifest = {
            "heroes": {
                "warrior_starter": {
                    "cellW": 16,
                    "cellH": 16,
                    "rows": ["down", "up", "side"],
                    "cols": ["walk0", "walk1", "walk2", "walk3", "attack"],
                    "pivot": [0.5, 0.125],
                }
            },
            "enemies": {
                "shade": {
                    "cellW": 12,
                    "cellH": 10,
                    "frames": 3,
                    "variants": 2,
                    "pivot": [0.5, 0.1],
                    "timedMs": 125,
                },
                "single_pose": {
                    "cellW": 8,
                    "cellH": 8,
                    "frames": 1,
                    "variants": 1,
                    "pivot": [0.5, 0.0],
                },
                "unbuilt": {"error": "source art is not ready"},
            },
        }
        manifest_path = root / "data" / "art_manifest.json"
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

        hero = Image.new("RGBA", (16 * 5, 16 * 3), (0, 0, 0, 0))
        draw = ImageDraw.Draw(hero)
        for row in range(3):
            for col in range(5):
                draw.rectangle(
                    (col * 16 + 4, row * 16 + 3, col * 16 + 11, row * 16 + 14),
                    fill=(220, 90 + col * 10, 40, 255),
                )
        hero.save(hero_dir / "warrior_starter.png")

        enemy = Image.new("RGBA", (12 * 3, 10 * 2), (0, 0, 0, 0))
        draw = ImageDraw.Draw(enemy)
        for row in range(2):
            for col in range(3):
                draw.rectangle(
                    (col * 12 + 2, row * 10 + 2, col * 12 + 9, row * 10 + 8),
                    fill=(70, 40 + row * 80, 160 + col * 20, 255),
                )
        enemy.save(enemy_dir / "shade.png")
        Image.new("RGBA", (8, 8), (255, 255, 255, 0)).save(enemy_dir / "single_pose.png")
        return manifest_path, root / "artifacts" / "animation-review"

    def test_exports_hero_walks_enemy_variants_and_single_frame_pose(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _, output = self._project(root)
            report = animation_review.review_sheets(
                root, Path("data/art_manifest.json"), Path("artifacts/animation-review")
            )
            self.assertEqual(report["checked"], 3)
            self.assertEqual(report["valid"], 3)
            self.assertEqual(len(report["skipped"]), 1)
            self.assertFalse(report["errors"])
            self.assertTrue((output / "hero-warrior_starter-side-walk.gif").is_file())
            self.assertTrue((output / "hero-warrior_starter-side-attack.png").is_file())
            self.assertTrue((output / "enemy-shade-variant-1-loop.gif").is_file())
            self.assertTrue(
                (output / "enemy-single_pose-variant-0-still.png").is_file()
            )
            with Image.open(output / "enemy-shade-variant-1-loop.gif") as gif:
                self.assertEqual(gif.n_frames, 3)
                self.assertEqual(
                    gif.info["duration"], 120
                )  # GIF delays use 10 ms units.


    def test_exports_multi_frame_svg_enemy_sheet(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            manifest_path, output = self._project(root)
            payload = json.loads(manifest_path.read_text(encoding="utf-8"))
            payload["enemies"]["gale_warden"] = {
                "cellW": 12,
                "cellH": 10,
                "frames": 4,
                "variants": 1,
                "pivot": [0.5, 0.1],
                "timedMs": 160,
                "file": "gale_warden",
                "extension": "svg",
            }
            manifest_path.write_text(json.dumps(payload), encoding="utf-8")
            svg = """<svg xmlns="http://www.w3.org/2000/svg" width="48" height="10" viewBox="0 0 48 10">
            <rect x="1" y="1" width="7" height="8" fill="#d0e0ef"/>
            <rect x="13" y="1" width="7" height="7" fill="#8bc7df"/>
            <rect x="25" y="1" width="7" height="6" fill="#6098b5"/>
            <rect x="37" y="1" width="7" height="5" fill="#426680"/>
            </svg>"""
            (root / "assets" / "art" / "Enemies" / "gale_warden.svg").write_text(
                svg, encoding="utf-8"
            )

            report = animation_review.review_sheets(
                root, Path("data/art_manifest.json"), Path("artifacts/animation-review")
            )
            self.assertFalse(report["errors"])
            self.assertEqual(report["valid"], 4)
            preview = output / "enemy-gale_warden-variant-0-loop.gif"
            self.assertTrue(preview.is_file())
            with Image.open(preview) as gif:
                self.assertEqual(gif.n_frames, 4)
                self.assertEqual(gif.size, (24, 20))

    def test_exports_base64_webp_warden_atlas_with_trailing_padding(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            manifest_path, output = self._project(root)
            payload = json.loads(manifest_path.read_text(encoding="utf-8"))
            payload["enemies"]["gale_warden"] = {
                "cellW": 140,
                "cellH": 156,
                "frames": 4,
                "variants": 1,
                "trailingPx": 2,
                "pivot": [0.5, 0.0128],
                "timedMs": 160,
                "file": "gale_warden",
                "extension": "svg",
                "base64Parts": ["gale_warden/part_00.b64", "gale_warden/part_01.b64"],
            }
            manifest_path.write_text(json.dumps(payload), encoding="utf-8")
            atlas = Image.new("RGBA", (562, 156), (0, 0, 0, 0))
            draw = ImageDraw.Draw(atlas)
            for frame in range(4):
                x = frame * 140
                draw.ellipse(
                    (x + 24 + frame * 2, 18 + frame * 4, x + 115, 143 - frame * 5),
                    fill=(100 + frame * 25, 150, 210, 255),
                )
            buffer = io.BytesIO()
            atlas.save(buffer, format="WEBP", lossless=True)
            encoded = base64.b64encode(buffer.getvalue()).decode("ascii")
            split = (len(encoded) // 2) // 4 * 4
            folder = root / "assets" / "art" / "Enemies" / "gale_warden"
            folder.mkdir(parents=True)
            (folder / "part_00.b64").write_text(encoded[:split], encoding="ascii")
            (folder / "part_01.b64").write_text(encoded[split:], encoding="ascii")

            report = animation_review.review_sheets(
                root, Path("data/art_manifest.json"), Path("artifacts/animation-review")
            )
            self.assertFalse(report["errors"])
            entry = next(item for item in report["previews"] if item["id"] == "gale_warden")
            self.assertEqual(entry["sheet_size"], [562, 156])
            self.assertEqual(entry["expected_size"], [562, 156])
            preview = output / "enemy-gale_warden-variant-0-loop.gif"
            self.assertTrue(preview.is_file())
            with Image.open(preview) as gif:
                self.assertEqual(gif.n_frames, 4)
                self.assertEqual(gif.size, (280, 312))

    def test_reports_sheet_dimensions_that_do_not_match_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._project(root)
            bad = root / "assets" / "art" / "Heroes" / "warrior_starter.png"
            Image.new("RGBA", (79, 48), (255, 0, 0, 255)).save(bad)
            report = animation_review.review_sheets(
                root, Path("data/art_manifest.json"), Path("artifacts/review")
            )
            self.assertTrue(
                any("expected 80x48" in error for error in report["errors"])
            )
            self.assertEqual(report["valid"], 2)

    def test_rejects_invalid_scale(self) -> None:
        with self.assertRaises(ValueError):
            animation_review.review_sheets(
                Path("."), Path("missing.json"), Path("out"), scale=0
            )


    def test_exports_separate_multi_frame_attack_atlas(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            manifest_path, output = self._project(root)
            payload = json.loads(manifest_path.read_text(encoding="utf-8"))
            payload["heroes"]["warrior_starter"].update({
                "attackSheet": "warrior_starter_attack.png",
                "attackFrames": 4,
                "attackFps": 24,
            })
            manifest_path.write_text(json.dumps(payload), encoding="utf-8")

            attack = Image.new("RGBA", (16 * 4, 16 * 3), (0, 0, 0, 0))
            draw = ImageDraw.Draw(attack)
            for row in range(3):
                for frame in range(4):
                    draw.rectangle(
                        (frame * 16 + 3, row * 16 + 3, frame * 16 + 12, row * 16 + 14),
                        fill=(50 + frame * 45, 150, 220 - frame * 35, 255),
                    )
            attack.save(root / "assets" / "art" / "Heroes" / "warrior_starter_attack.png")

            report = animation_review.review_sheets(
                root, Path("data/art_manifest.json"), Path("artifacts/animation-review")
            )
            self.assertFalse(report["errors"])
            self.assertEqual(report["hero_attack_audit"][0]["frame_count"], 4)
            self.assertEqual(
                report["hero_attack_audit"][0]["status"], "multi_frame_attack_preview"
            )
            attack_preview = output / "hero-warrior_starter-side-attack.gif"
            self.assertTrue(attack_preview.is_file())
            with Image.open(attack_preview) as gif:
                self.assertEqual(gif.n_frames, 4)
                self.assertEqual(gif.info["duration"], 40)

    def test_single_frame_attacks_are_explicitly_reported_as_placeholders(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _, output = self._project(root)
            report = animation_review.review_sheets(
                root, Path("data/art_manifest.json"), Path("artifacts/animation-review")
            )
            self.assertEqual(
                report["hero_attack_audit"][0]["status"], "single_frame_attack_placeholder"
            )
            self.assertTrue((output / "hero-warrior_starter-side-attack.png").is_file())


if __name__ == "__main__":
    unittest.main()
