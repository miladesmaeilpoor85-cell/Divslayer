"""Report missing commercial-release evidence without inferring ownership or licences.

This is an evidence-completeness check only. It does not establish legal sufficiency.
"""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Any


def audit_release_evidence(root: Path) -> dict[str, Any]:
    root = root.resolve()
    register_path = root / "docs" / "ASSET_RIGHTS_REGISTER.csv"
    credits_path = root / "data" / "audio_credits.json"
    errors: list[str] = []
    blockers: list[dict[str, str]] = []
    artwork: list[str] = []
    music: list[str] = []

    if not register_path.is_file():
        errors.append("Missing docs/ASSET_RIGHTS_REGISTER.csv")
    else:
        try:
            with register_path.open("r", encoding="utf-8-sig", newline="") as stream:
                reader = csv.DictReader(stream)
                required = {"asset_path", "commercial_use_status", "proof_reference_private_location"}
                if not required.issubset(set(reader.fieldnames or [])):
                    errors.append("Artwork rights register is missing required evidence columns")
                else:
                    seen: set[str] = set()
                    for line, row in enumerate(reader, start=2):
                        path = (row.get("asset_path") or "").strip()
                        status = (row.get("commercial_use_status") or "").strip().upper()
                        proof = (row.get("proof_reference_private_location") or "").strip()
                        if not path:
                            errors.append(f"Artwork register line {line} has no asset_path")
                            continue
                        if path in seen:
                            errors.append(f"Duplicate artwork rights record: {path}")
                        seen.add(path)
                        artwork.append(path)
                        if status != "VERIFIED" or not proof:
                            blockers.append({
                                "kind": "artwork",
                                "asset": path,
                                "reason": "status must be VERIFIED and a private evidence reference must be recorded",
                            })
        except (OSError, csv.Error, UnicodeError) as exc:
            errors.append(f"Could not read artwork register: {exc}")

    if not credits_path.is_file():
        errors.append("Missing data/audio_credits.json")
    else:
        try:
            credits = json.loads(credits_path.read_text(encoding="utf-8"))
            if not isinstance(credits.get("music"), list):
                errors.append("data/audio_credits.json music must be an array")
            else:
                for index, track in enumerate(credits["music"]):
                    if not isinstance(track, dict):
                        errors.append(f"Music credit {index} is not an object")
                        continue
                    title = str(track.get("title", f"music[{index}]"))
                    status = str(track.get("commercial_use_status", "UNVERIFIED")).strip().upper()
                    proof = str(track.get("proof_reference_private_location", "")).strip()
                    music.append(title)
                    if status != "VERIFIED" or not proof:
                        blockers.append({
                            "kind": "music",
                            "asset": title,
                            "reason": "status must be VERIFIED and a private evidence reference must be recorded",
                        })
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f"Could not read audio credits: {exc}")

    art_blockers = sum(item["kind"] == "artwork" for item in blockers)
    music_blockers = sum(item["kind"] == "music" for item in blockers)
    return {
        "release_ready": not errors and not blockers,
        "artwork_records": len(artwork),
        "artwork_evidence_blockers": art_blockers,
        "music_records": len(music),
        "music_evidence_blockers": music_blockers,
        "errors": errors,
        "blockers": blockers,
        "note": "Evidence completeness only; this does not replace licence review, legal advice, signing verification, or device QA.",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--json", action="store_true", help="print a machine-readable report")
    parser.add_argument("--report", type=Path, default=None, help="optional JSON report path")
    args = parser.parse_args()
    report = audit_release_evidence(args.root)
    rendered = json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True)
    if args.report is not None:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(rendered + "\n", encoding="utf-8")
    if args.json:
        print(rendered)
    else:
        print("Commercial evidence audit")
        print(f"Artwork records: {report['artwork_records']} | blockers: {report['artwork_evidence_blockers']}")
        print(f"Music records: {report['music_records']} | blockers: {report['music_evidence_blockers']}")
        for error in report["errors"]:
            print("ERROR: " + error)
        print("RELEASE_READY" if report["release_ready"] else "RELEASE_BLOCKED")
    # Missing owner evidence is a release blocker, not a source-code CI failure.
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
