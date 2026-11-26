"""Unit tests for frame-level sprite animation quality metrics."""
from __future__ import annotations

import base64
import io
import json
import tempfile
import unittest
from pathlib import Path

from animation_quality_audit import audit, frame_metrics
from PIL import Image, ImageDraw


class AnimationQualityAuditTests(unittest.TestCase):
    def test_detects_duplicate_frames_and_measures_motion(self) -> None:
        first = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        ImageDraw.Draw(first).rectangle((4, 2, 9, 14), fill=(220, 120, 50, 255))
        third = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        ImageDraw.Draw(third).rectangle((5, 2, 10, 14), fill=(220, 120, 50, 255))
        metrics = frame_metrics([first, first.copy(), third])
        self.assertEqual(metrics["unique_frames"], 2)
        self.assertEqual(metrics["duplicate_pairs"], [[0, 1]])
        self.assertGreater(metrics["mean_adjacent_changed_pixel_ratio"], 0.0)
        self.assertEqual(metrics["visible_bottom_range_px"], 0)

    def make_project(self, root: Path) -> None:
        manifest = {
            "heroes": {
                "warrior_starter": {
                    "cellW": 16, "cellH": 16,
                    "rows": ["down", "up", "side"],
                    "cols": ["walk0", "walk1", "walk2", "walk3", "attack"],
                }
            },
            "enemies": {
                "shade": {"cellW": 12, "cellH": 10, "frames": 2},
                "static_prop": {"cellW": 8, "cellH": 8, "frames": 1},
                "procedural": {"error": "drawn by code"},
            },
        }
        (root / "data").mkdir()
        hero_dir = root / "assets/art/Heroes"
        enemy_dir = root / "assets/art/Enemies"
        hero_dir.mkdir(parents=True)
        enemy_dir.mkdir(parents=True)
        (root / "data/art_manifest.json").write_text(json.dumps(manifest), encoding="utf-8")

        hero = Image.new("RGBA", (80, 48), (0, 0, 0, 0))
        draw = ImageDraw.Draw(hero)
        for row in range(3):
            for col in range(4):
                x = 3 + col
                draw.rectangle(
                    (col * 16 + x, row * 16 + 2, col * 16 + x + 5, row * 16 + 13),
                    fill=(220, 100, 40, 255),
                )
            draw.rectangle((68, row * 16 + 2, 73, row * 16 + 13), fill=(220, 100, 40, 255))
        hero.save(hero_dir / "warrior_starter.png")

        enemy = Image.new("RGBA", (24, 10), (0, 0, 0, 0))
        draw = ImageDraw.Draw(enemy)
        draw.rectangle((2, 2, 7, 8), fill=(60, 120, 180, 255))
        draw.rectangle((14, 2, 19, 8), fill=(60, 120, 180, 255))
        enemy.save(enemy_dir / "shade.png")
        Image.new("RGBA", (8, 8), (0, 0, 0, 0)).save(enemy_dir / "static_prop.png")

    def test_audits_hero_attacks_and_enemy_cycle_lengths(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.make_project(root)
            report = audit(root)
        self.assertEqual(report["hero_looks"], 1)
        self.assertEqual(report["hero_walk_clips"], 3)
        self.assertEqual(report["hero_attack_clips"], 3)
        self.assertEqual(report["enemy_sprite_sheets"], 2)
        self.assertEqual(report["enemy_variant_frame_counts"], {1: 1, 2: 1})
        self.assertEqual(report["warning_counts"]["hero_attack_is_one_pose"], 3)
        self.assertFalse(report["errors"])
        self.assertEqual(len(report["skipped"]), 1)


    def test_audits_svg_enemy_animation_sheet(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.make_project(root)
            manifest_path = root / "data/art_manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["enemies"]["gale_warden"] = {
                "cellW": 12, "cellH": 10, "frames": 4, "variants": 1,
                "pivot": [0.5, 0.1], "timedMs": 160,
                "file": "gale_warden", "extension": "svg",
            }
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            svg = """<svg xmlns="http://www.w3.org/2000/svg" width="48" height="10" viewBox="0 0 48 10">
            <rect x="1" y="1" width="7" height="8" fill="#d0e0ef"/>
            <rect x="13" y="1" width="6" height="7" fill="#8bc7df"/>
            <rect x="25" y="1" width="5" height="6" fill="#6098b5"/>
            <rect x="37" y="1" width="4" height="5" fill="#426680"/>
            </svg>"""
            (root / "assets/art/Enemies/gale_warden.svg").write_text(svg, encoding="utf-8")
            report = audit(root)

        self.assertFalse(report["errors"], report["errors"])
        self.assertEqual(report["enemy_sprite_sheets"], 3)
        warden_clips = [
            clip for clip in report["clips"]
            if clip["asset_id"] == "gale_warden"
        ]
        self.assertEqual(len(warden_clips), 1)
        self.assertEqual(warden_clips[0]["frame_count"], 4)

    def test_reads_separate_attack_frame_files_by_direction(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.make_project(root)
            manifest_path = root / "data/art_manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            hero = manifest["heroes"]["warrior_starter"]
            frame_rows = []
            for row, direction in enumerate(["down", "up", "side"]):
                row_paths = []
                for index in range(4):
                    relative = f"warrior_starter_attack/{direction}_{index}.png"
                    frame_path = root / "assets/art/Heroes" / relative
                    frame_path.parent.mkdir(parents=True, exist_ok=True)
                    frame = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
                    draw = ImageDraw.Draw(frame)
                    draw.rectangle(
                        (3 + index, 2 + row, 8 + index, 12 + row),
                        fill=(220, 110 + index * 8, 50, 255),
                    )
                    frame.save(frame_path)
                    row_paths.append(relative)
                frame_rows.append(row_paths)
            hero["attackFrameFiles"] = frame_rows
            hero["attackFrames"] = 4
            hero["attackFps"] = 24
            hero["attackImpactFrame"] = 2
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

            report = audit(root)

        self.assertFalse(report["errors"], report["errors"])
        self.assertEqual(report["hero_attack_frame_counts"], {4: 3})
        self.assertEqual(report["hero_attack_multiframe_clips"], 3)
        self.assertEqual(report["hero_attack_single_pose_clips"], 0)
        self.assertNotIn("hero_attack_is_one_pose", report["warning_counts"])
        attack_clips = [clip for clip in report["clips"] if clip["clip"].startswith("attack_")]
        self.assertTrue(all(clip["fps"] == 24.0 and clip["impact_frame"] == 2 for clip in attack_clips))
        self.assertTrue(all(clip["impact_time_ms"] == 83.33 for clip in attack_clips))

    def test_reads_packed_base64_attack_atlas(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.make_project(root)
            manifest_path = root / "data/art_manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            hero = manifest["heroes"]["warrior_starter"]

            atlas = Image.new("RGBA", (64, 48), (0, 0, 0, 0))
            draw = ImageDraw.Draw(atlas)
            for row in range(3):
                for column in range(4):
                    draw.rectangle(
                        (column * 16 + 3 + column, row * 16 + 2, column * 16 + 9 + column, row * 16 + 13),
                        fill=(220, 110 + column * 8, 50, 255),
                    )
            image_buffer = io.BytesIO()
            atlas.save(image_buffer, format="PNG")
            encoded = base64.b64encode(image_buffer.getvalue()).decode("ascii")
            split = (len(encoded) // 2) - (len(encoded) // 2) % 4
            payload_dir = root / "assets/art/Heroes/attack_atlas_data/warrior"
            payload_dir.mkdir(parents=True)
            paths = []
            for index, part in enumerate((encoded[:split], encoded[split:])):
                relative = f"attack_atlas_data/warrior/part_{index:02d}.b64"
                (payload_dir / f"part_{index:02d}.b64").write_text(part, encoding="ascii")
                paths.append(relative)
            hero["attackSheetBase64Parts"] = paths
            hero["attackFrames"] = 4
            hero["attackFps"] = 24
            hero["attackImpactFrame"] = 2
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

            report = audit(root)

        self.assertFalse(report["errors"], report["errors"])
        self.assertEqual(report["hero_attack_frame_counts"], {4: 3})
        self.assertEqual(report["hero_attack_multiframe_clips"], 3)
        attack_clips = [clip for clip in report["clips"] if clip["clip"].startswith("attack_")]
        self.assertTrue(all(clip["fps"] == 24.0 and clip["impact_frame"] == 2 for clip in attack_clips))

    def test_audits_runtime_base64_warden_atlas_and_svg_fallback_separately(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.make_project(root)
            manifest_path = root / "data/art_manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["enemies"]["gale_warden"] = {
                "cellW": 136,
                "cellH": 156,
                "frames": 4,
                "variants": 1,
                "trailingPx": 0,
                "fallbackCellW": 204,
                "fallbackCellH": 234,
                "fallbackPxPerUnitLogical": 3,
                "pxPerUnitLogical": 2,
                "pivot": [0.5, 0.0128],
                "timedMs": 160,
                "file": "alborzwarden",
                "extension": "svg",
                "base64Parts": [
                    "alborzwarden/part_00.b64",
                    "alborzwarden/part_01.b64",
                    "alborzwarden/part_02.b64",
                    "alborzwarden/part_03.b64",
                ],
            }
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

            fallback_svg = """<svg xmlns="http://www.w3.org/2000/svg" width="816" height="234" viewBox="0 0 816 234">
            <rect x="12" y="12" width="160" height="200" fill="#d0e0ef"/>
            <rect x="216" y="12" width="160" height="195" fill="#8bc7df"/>
            <rect x="420" y="12" width="160" height="188" fill="#6098b5"/>
            <rect x="624" y="12" width="160" height="180" fill="#426680"/>
            </svg>"""
            (root / "assets/art/Enemies/alborzwarden.svg").write_text(fallback_svg, encoding="utf-8")

            atlas = Image.new("RGBA", (544, 156), (0, 0, 0, 0))
            draw = ImageDraw.Draw(atlas)
            for frame in range(4):
                x = frame * 136
                draw.ellipse(
                    (x + 22 + frame * 2, 16 + frame * 4, x + 112, 144 - frame * 5),
                    fill=(100 + frame * 25, 150, 210, 255),
                )
            buffer = io.BytesIO()
            atlas.save(buffer, format="WEBP", lossless=True)
            encoded = base64.b64encode(buffer.getvalue()).decode("ascii")
            part_size = ((len(encoded) // 4) // 4) * 4
            folder = root / "assets/art/Enemies/alborzwarden"
            folder.mkdir(parents=True)
            for index in range(4):
                part = encoded[index * part_size : (index + 1) * part_size] if index < 3 else encoded[index * part_size :]
                (folder / f"part_{index:02d}.b64").write_text(part, encoding="ascii")

            report = audit(root)

        self.assertFalse(report["errors"], report["errors"])
        self.assertEqual(report["enemy_sprite_sheets"], 3)
        warden_clips = [
            clip for clip in report["clips"]
            if clip["asset_id"] == "gale_warden"
        ]
        self.assertEqual(len(warden_clips), 1)
        self.assertEqual(warden_clips[0]["frame_count"], 4)
        self.assertGreater(warden_clips[0]["visible_alpha_ratio"], 0.0)

    def test_rejects_attack_frame_with_wrong_cell_dimensions(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.make_project(root)
            manifest_path = root / "data/art_manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["heroes"]["warrior_starter"]["attackFrameFiles"] = [
                ["missing_attack.png"] * 4,
                ["missing_attack.png"] * 4,
                ["missing_attack.png"] * 4,
            ]
            manifest["heroes"]["warrior_starter"]["attackFrames"] = 4
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            attack_path = root / "assets/art/Heroes/missing_attack.png"
            Image.new("RGBA", (15, 16), (255, 0, 0, 255)).save(attack_path)
            report = audit(root)

        self.assertTrue(any("expected 16x16" in error for error in report["errors"]))

    def test_rejects_wrong_sheet_dimensions(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.make_project(root)
            Image.new("RGBA", (79, 48), (0, 0, 0, 0)).save(
                root / "assets/art/Heroes/warrior_starter.png"
            )
            report = audit(root)
        self.assertTrue(any("expected 80x48" in error for error in report["errors"]))


if __name__ == "__main__":
    unittest.main()
