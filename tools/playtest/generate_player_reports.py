#!/usr/bin/env python3
"""Build evidence-only player, critic, and QA reports from a Divslayer playtest.

The Chapter I journey is not a full-game completion test. This tool never
infers campaign completion from reaching a boss or passing the final scripted
checkpoint. Completion requires an explicit true-ending marker.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

KNOWN_MAPS = [
    "alborz", "alborz_eyrie", "camp", "damavand", "dungeon", "emberforge",
    "forest", "frostvale", "peaks", "sanctum", "shadowfen", "shrine_echoes",
    "shrine_embers", "shrine_fuse", "shrine_light", "shrine_shadows",
    "shrine_tides", "shrine_weight", "trial", "village", "wyrmhollow",
    "zahhakcave",
]
ENGINE_ERROR = re.compile(
    r"(?:SCRIPT ERROR:|Parse Error:|ERROR: Failed to load script|"
    r"ERROR: Failed to create an autoload|ERROR: Invalid get index|"
    r"ERROR: .*\.import:|QUALITY_FIRST_IMPORT_AUDIT_FAILED|"
    r"QUALITY_FIRST_IMPORTS_FAILED)",
    re.IGNORECASE,
)
STEP_RE = re.compile(r"^STEP (\d+) ([0-9.]+) s (\{.*\}) -> (.*)$")
SCREEN_RE = re.compile(r"^SCREEN ([^:]+): (.*)$")


def _parse_step(line: str) -> dict[str, Any] | None:
    """Parse one playtest STEP line without confusing nested JSON in its result.

    The result may itself be JSON (for the "state" action), so a greedy regex
    over the whole line consumes both objects. Let JSONDecoder identify the
    exact end of the scenario object instead.
    """
    prefix = re.match(r"^STEP (\d+) ([0-9.]+) s ", line.strip())
    if not prefix:
        return None
    raw = line.strip()
    try:
        scenario, end = json.JSONDecoder().raw_decode(raw, prefix.end())
    except (json.JSONDecodeError, TypeError):
        return None
    if not isinstance(scenario, dict):
        return None
    if raw[end:end + 4] != " -> ":
        return None
    return {
        "index": int(prefix.group(1)),
        "elapsed_seconds": float(prefix.group(2)),
        "action": str(scenario.get("do", "")),
        "scenario": scenario,
        "result": raw[end + 4:],
    }


def _state_from_step(step: dict[str, Any]) -> dict[str, Any] | None:
    if step.get("action") != "state":
        return None
    try:
        state = json.loads(str(step.get("result", "")))
    except json.JSONDecodeError:
        return None
    return state if isinstance(state, dict) else None


def build_report(
    hero: str,
    log_text: str,
    engine_text: str = "",
    scenario_steps: list[dict[str, Any]] | None = None,
    available_shots: set[str] | None = None,
) -> dict[str, Any]:
    """Return a structured, conservative evidence summary for one class run."""
    lines = log_text.splitlines()
    steps = [step for line in lines if (step := _parse_step(line)) is not None]
    states = [state for step in steps if (state := _state_from_step(step)) is not None]
    screens = []
    for line in lines:
        match = SCREEN_RE.match(line)
        if match:
            name = match.group(1).strip()
            screens.append({
                "file": name,
                "visible_text": match.group(2).strip(),
                "file_present": available_shots is None or name in available_shots,
            })

    map_visits: list[str] = []
    for state in states:
        name = str(state.get("map", "")).strip()
        if name and name not in map_visits:
            map_visits.append(name)
    for pattern in (
        r"PLAYER_AGENT_OBJECTIVE map=([^ ]+)",
        r"PLAYER_AGENT_PICKUP_SCAN map=([^ ]+)",
    ):
        for match in re.finditer(pattern, log_text):
            name = match.group(1).strip()
            if name and name not in map_visits:
                map_visits.append(name)

    passed = re.findall(r"^ASSERTION_PASSED (.+)$", log_text, re.MULTILINE)
    failed = re.findall(r"^ASSERTION_FAILED (.+)$", log_text, re.MULTILINE)
    if not failed:
        failed = re.findall(r"^PLAYTEST_ASSERTION: (.+)$", log_text, re.MULTILINE)
    engine_errors = [line.strip() for line in engine_text.splitlines() if ENGINE_ERROR.search(line)]
    if not engine_errors:
        engine_errors = [line.strip() for line in lines if ENGINE_ERROR.search(line)]
    fight_steps = [step for step in steps if step["action"] == "fight"]
    action_events = [
        line for line in lines
        if re.search(r"PLAYER_AGENT_(?:ACTIONS|POLICY|RECOVERED|RECOVERY|SHOP_PURCHASE_RESULT|PILLAR_PRIORITY|PILLAR_APPROACH|PILLAR_DAMAGED|PILLAR_DESTROYED|MAGE_EVASION)", line)
        or line.startswith("FIGHT_EVIDENCE ")
    ]
    boss_encounters = [
        {
            "type": match.group(1),
            "present_before": match.group(2) == "true",
            "hp_before_percent": float(match.group(3)),
            "present_after": match.group(4) == "true",
            "hp_after_percent": float(match.group(5)),
            "defeated": match.group(6) == "true",
        }
        for match in re.finditer(
            r"^FIGHT_EVIDENCE type=(\S+) present_before=(true|false) "
            r"hp_before=([0-9.]+) present_after=(true|false) "
            r"hp_after=([0-9.]+) defeated=(true|false)$",
            log_text,
            re.MULTILINE,
        )
    ]
    screenshots = [s["file"] for s in screens if s["file_present"]]
    done = "PLAYTEST_DONE" in log_text
    failure_summary_present = "PLAYTEST_ASSERTIONS_FAILED" in log_text
    assertion_failure = bool(failed) or failure_summary_present
    assertions_passed = (
        "PLAYTEST_ASSERTIONS_PASSED" in log_text
        and not assertion_failure
    )
    true_ending = "PLAYER_AGENT_TRUE_ENDING_CONFIRMED" in log_text
    run_passed = done and assertions_passed and not engine_errors

    # A startup/parse failure is a failed QA run even when the playtest driver
    # never got far enough to create log.txt. Reserve "not_run" for the absence
    # of both player evidence and an engine failure.
    if not log_text.strip() and not engine_errors:
        journey_status = "not_run"
    elif assertion_failure or engine_errors:
        journey_status = "failed"
    elif run_passed:
        journey_status = "passed"
    else:
        journey_status = "incomplete"

    issues: list[dict[str, str]] = []
    for item in failed:
        issues.append({"severity": "BLOCKER", "source": "playtest assertion", "detail": item})
    if failure_summary_present and not failed:
        issues.append({
            "severity": "BLOCKER",
            "source": "playtest summary",
            "detail": (
                "PLAYTEST_ASSERTIONS_FAILED was emitted without a corresponding "
                "ASSERTION_FAILED or PLAYTEST_ASSERTION detail line."
            ),
        })
    for item in engine_errors:
        issues.append({"severity": "BLOCKER", "source": "Godot engine", "detail": item})
    if journey_status == "not_run":
        issues.append({
            "severity": "BLOCKER",
            "source": "playtest summary",
            "detail": (
                "No player journey output or recognized engine diagnostic was captured; "
                "the journey did not run."
            ),
        })
    elif journey_status == "incomplete":
        issues.append({
            "severity": "HIGH",
            "source": "playtest summary",
            "detail": (
                "The journey did not record both PLAYTEST_DONE and "
                "PLAYTEST_ASSERTIONS_PASSED completion markers."
            ),
        })
    for marker, severity, label in [
        ("PLAYER_AGENT_ROUTE_MISROUTED", "HIGH", "Unexpected map transition during objective navigation"),
        ("PLAYER_AGENT_SHOP_FAILED", "HIGH", "Shop UI interaction did not open"),
        ("combat unexpectedly changed map", "HIGH", "Combat crossed an unintended map exit"),
        ("PLAYER_AGENT_LOADOUT_MODAL_BLOCK", "MEDIUM", "A modal panel blocked the next loadout interaction"),
    ]:
        for line in lines:
            if marker in line and not any(issue["detail"] == line for issue in issues):
                issues.append({"severity": severity, "source": "player-agent telemetry", "detail": line.strip()})

    step_source = scenario_steps if scenario_steps is not None else [
        step["scenario"] for step in steps if step.get("scenario")
    ]
    planned_checkpoint_names = [
        str(item.get("name", ""))
        for item in step_source
        if item.get("do") == "checkpoint" and item.get("name")
    ]
    reached_checkpoint_names = [
        name for name in re.findall(r"^STAGE_START (.+?) potions=", log_text, re.MULTILINE)
        if name != "startup"
    ]
    known_not_visited = [name for name in KNOWN_MAPS if name not in map_visits]
    final_state = states[-1] if states else {}
    seconds_match = re.search(r"PLAYTEST_DONE\s+([0-9.]+) s wall", log_text)
    wall_seconds = float(seconds_match.group(1)) if seconds_match else None

    return {
        "schema_version": 1,
        "hero_class": hero,
        "journey_status": journey_status,
        "test_run_finished": done,
        "assertions_passed": assertions_passed,
        "assertions": {"passed": passed, "failed": failed},
        "wall_seconds": wall_seconds,
        "steps_completed": len(steps),
        "combat_samples": len(fight_steps),
        "combat_step_summaries": [
            {"step": item["index"], "seconds": item["elapsed_seconds"],
             "target": item["scenario"].get("target_foe", ""),
             "duration_limit": item["scenario"].get("sec")}
            for item in fight_steps
        ],
        "boss_encounters": boss_encounters,
        "map_visits_observed": map_visits,
        "known_maps_not_observed": known_not_visited,
        "scenario_checkpoints_planned": planned_checkpoint_names,
        "scenario_checkpoints_reached": reached_checkpoint_names,
        "screenshots": screens,
        "player_action_evidence": action_events,
        "final_observed_state": final_state,
        "qa_issues": issues,
        "full_game_completion": {
            "confirmed": true_ending,
            "evidence_marker": "PLAYER_AGENT_TRUE_ENDING_CONFIRMED" if true_ending else None,
            "note": (
                "An explicit true-ending marker was recorded."
                if true_ending else
                "Not confirmed. A passed Chapter I route, boss encounter, boss damage, "
                "or missing objective marker is not proof that the complete game was finished."
            ),
        },
        "review_limits": [
            "This report summarizes only evidence present in this run's logs and screenshots.",
            "No subjective enjoyment, fairness, narrative quality, audio quality, or visual quality score is inferred automatically.",
            "Maps not observed in this run are classified as not tested, not as inaccessible or absent.",
            "The current scripted journey verifies an Arzhang victory and return to Zal in Chapter I; it is not a full-campaign run.",
        ],
    }


def _bullets(items: list[str], empty: str) -> str:
    return "\n".join(f"- {item}" for item in items) if items else f"- {empty}"


def write_reports(report: dict[str, Any], destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    (destination / "run-evidence.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    hero = report["hero_class"]
    status = report["journey_status"]
    duration = report["wall_seconds"]
    duration_text = f"{duration:.1f} s" if duration is not None else "not recorded"
    maps = report["map_visits_observed"]
    screenshots = [s["file"] for s in report["screenshots"] if s["file_present"]]
    passed = report["assertions"]["passed"]
    failed = report["assertions"]["failed"]
    issues = report["qa_issues"]
    map_lines = [f"{name}: observed" for name in maps]
    map_lines.extend(f"{name}: not tested in this run" for name in report["known_maps_not_observed"])

    player = f"""# Player report — {hero}

- Journey status: **{status}**
- Run duration: {duration_text}
- Recorded steps: {report['steps_completed']}
- Combat samples: {report['combat_samples']}
- Full game completion: **{'confirmed' if report['full_game_completion']['confirmed'] else 'not confirmed'}**

## What this run actually covered

{_bullets(report['scenario_checkpoints_reached'], 'No named scenario checkpoint was confirmed as reached.')}

## Observed areas

{_bullets(map_lines, 'No map visit could be established from the log.')}

## Player-action evidence

{_bullets(report['player_action_evidence'], 'No player-action telemetry was recorded.')}

## Boss encounter evidence

{_bullets([f"{item['type']}: defeated={item['defeated']}, HP {item['hp_before_percent']:.1f}% → {item['hp_after_percent']:.1f}%" for item in report['boss_encounters']], 'No boss encounter outcome was recorded.')}

## Evidence captured

{_bullets(screenshots, 'No screenshot file was confirmed as present.')}

## Experience assessment

A subjective experience verdict is **pending human review**. The automated run can establish which interactions and checkpoints were observed, but it cannot reliably infer enjoyment, frustration, perceived fairness, or whether the game feels satisfying to play.

## Completion boundary

{report['full_game_completion']['note']}
"""

    readable_text_shots = sum(bool(s["visible_text"].strip()) for s in report["screenshots"] if s["file_present"])
    purchase_events = sum("SHOP_PURCHASE_RESULT" in e for e in report["player_action_evidence"])
    critic = f"""# Critic report — {hero}

## Evidence coverage

| Area | Evidence in this run | Assessment |
|---|---|---|
| Narrative and dialogue | {readable_text_shots} screenshot(s) with visible UI text; extracted text is in run-evidence.json | Dialogue quality still requires human review |
| World and exploration | {len(maps)} observed map(s) | Partial; unvisited areas remain untested |
| Combat | {report['combat_samples']} combat sample(s) | Tactical and animation quality not scored automatically |
| Boss progression | {len(report['boss_encounters'])} recorded boss outcome(s) | Kill-counter evidence only; encounter quality still needs human review |
| Progression and economy | {purchase_events} recorded purchase result(s) | State-change evidence only |
| UI and readability | {len(screenshots)} screenshot(s) with visible-text extraction | Manual visual inspection required |
| Audio | No reliable audio judgement is produced by this run | Not evaluated |
| Ending and campaign structure | {'True-ending marker present' if report['full_game_completion']['confirmed'] else 'No true-ending evidence'} | Not evaluated |

## Assertions reached

{_bullets(passed, 'No passed checkpoints recorded.')}

## Critic's conclusion

No numerical score or broad quality verdict is assigned. A critic must inspect the referenced screenshots and actual gameplay evidence before judging narrative delivery, level design, encounter readability, class identity, balance, animation, art direction, or sound. Content not reached by this run must not receive an invented assessment.

## Scope limit

The current test journey is a Chapter I sample. It does not establish full-game quality or completion.
"""

    issue_lines = [f"[{item['severity']}] {item['source']}: {item['detail']}" for item in issues]
    qa = f"""# QA report — {hero}

- Journey status: **{status}**
- Assertions passed: {len(passed)}
- Assertions failed: {len(failed)}
- QA findings: {len(issues)}
- Engine error lines: {sum(item['source'] == 'Godot engine' for item in issues)}

## Findings

{_bullets(issue_lines, 'No automated QA finding was detected in the available logs.')}

## Boss encounter evidence

{_bullets([f"{item['type']}: defeated={item['defeated']}, HP {item['hp_before_percent']:.1f}% → {item['hp_after_percent']:.1f}%" for item in report['boss_encounters']], 'No boss encounter outcome was recorded.')}

## Passed checkpoints

{_bullets(passed, 'No passed checkpoint recorded.')}

## Failed checkpoints

{_bullets(failed, 'No failed checkpoint recorded.')}

## Reproduction evidence

{_bullets(screenshots, 'No screenshot evidence was confirmed.')}

## Final observed state

{json.dumps(report['final_observed_state'], ensure_ascii=False, sort_keys=True)}

## QA caveat

Absence of a detected issue is not proof that a feature is defect-free. Areas not reached or not logged remain **not tested**. A boss taking damage is not a victory condition.
"""

    (destination / "player-report.md").write_text(player, encoding="utf-8")
    (destination / "critic-report.md").write_text(critic, encoding="utf-8")
    (destination / "qa-report.md").write_text(qa, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--class", dest="hero", required=True, choices=("warrior", "mage", "rogue", "paladin"))
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--engine-log", type=Path, required=True)
    parser.add_argument("--scenario", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    log_text = args.log.read_text(encoding="utf-8", errors="replace") if args.log.exists() else ""
    engine_text = args.engine_log.read_text(encoding="utf-8", errors="replace") if args.engine_log.exists() else ""
    scenario_steps: list[dict[str, Any]] = []
    if args.scenario.exists():
        try:
            parsed = json.loads(args.scenario.read_text(encoding="utf-8"))
            if isinstance(parsed, list):
                scenario_steps = [item for item in parsed if isinstance(item, dict)]
        except json.JSONDecodeError:
            pass
    shot_dir = args.log.parent / "shots"
    available_shots = {path.name for path in shot_dir.glob("*.png")} if shot_dir.exists() else set()
    report = build_report(args.hero, log_text, engine_text, scenario_steps, available_shots)
    write_reports(report, args.out)
    print(
        f"PLAYER_REPORTS_WRITTEN class={args.hero} status={report['journey_status']} "
        f"maps={len(report['map_visits_observed'])} issues={len(report['qa_issues'])} "
        f"full_game_complete={report['full_game_completion']['confirmed']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
