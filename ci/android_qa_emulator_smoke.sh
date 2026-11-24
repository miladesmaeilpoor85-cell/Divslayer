#!/usr/bin/env bash
set -euo pipefail

mkdir -p build/android
trap 'timeout 20s adb logcat -d -v time > build/android/emulator-logcat.txt 2>&1 || true; timeout 20s adb shell dumpsys activity activities > build/android/emulator-activity.txt 2>&1 || true' EXIT

echo "Installing Divslayer QA APK"
adb shell settings put secure immersive_mode_confirmations confirmed || true
adb logcat -c
timeout 240s adb install -r build/android/Divslayer-QA.apk
adb shell pm path com.example.divslayer.qa | grep -F 'package:'

app_is_foreground() {
  local activity_state
  activity_state="$(timeout 20s adb shell dumpsys activity activities 2>/dev/null | tr -d '\r' || true)"
  grep -E 'topResumedActivity|ResumedActivity' <<< "$activity_state" | grep -F 'com.example.divslayer.qa/' >/dev/null
}

godot_setup_completed() {
  timeout 20s adb logcat -d -v brief 2>/dev/null | grep -Fq 'OnGodotSetupCompleted'
}

ready=0
for attempt in 1 2; do
  if [[ "$attempt" -eq 2 ]]; then
    echo "First Android start was interrupted during device package/overlay configuration; restarting Divslayer once from a clean process."
    timeout 30s adb logcat -d -v time > build/android/emulator-first-launch-logcat.txt
    timeout 30s adb shell am force-stop com.example.divslayer.qa
    sleep 2
  fi

  launch_result="$(timeout 60s adb shell am start -n com.example.divslayer.qa/com.godot.game.GodotAppLauncher 2>&1 | tr -d '\r' || true)"
  printf '%s\n' "$launch_result" | tee "build/android/launcher-command-attempt-$attempt.txt"
  if [[ -n "$launch_result" ]] && grep -Eq '(^|[[:space:]])Error:|Exception' <<< "$launch_result"; then
    echo "::error::Android rejected the explicit Godot launcher activity on attempt $attempt."
    exit 1
  fi

  for poll in $(seq 1 25); do
    sleep 1
    if godot_setup_completed && app_is_foreground; then
      sleep 6
      if app_is_foreground; then
        ready=1
        break
      fi
      echo "Godot setup completed but Android did not keep Divslayer in the foreground."
      break
    fi
  done

  if [[ "$ready" -eq 1 ]]; then
    echo "Divslayer reached OnGodotSetupCompleted and remained in the foreground."
    break
  fi
done

timeout 30s adb logcat -d -v time > build/android/emulator-logcat.txt
if [[ "$ready" -ne 1 ]]; then
  echo "::error::Divslayer did not complete Godot setup and remain in the foreground after two clean launch attempts."
  exit 1
fi
if grep -E 'FATAL EXCEPTION|Fatal signal|SIGSEGV|SCRIPT ERROR:|Parse Error:|ERROR: Failed to load script|ANR in com\.example\.divslayer\.qa|Application Not Responding: com\.example\.divslayer\.qa' build/android/emulator-logcat.txt; then
  echo "::error::Android runtime reported a fatal, app ANR, or Godot script error."
  exit 1
fi
grep -F 'OnGodotSetupCompleted' build/android/emulator-logcat.txt

dump_ui() {
  timeout 30s adb shell uiautomator dump --compressed /sdcard/divslayer-window.xml >/dev/null
  timeout 30s adb pull /sdcard/divslayer-window.xml build/android/emulator-window.xml >/dev/null
}

dump_ui
if ! python3 - build/android/emulator-window.xml > build/android/anr-action.txt <<'PY'
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

root = ET.parse(Path(sys.argv[1])).getroot()
nodes = list(root.iter("node"))
labels = [
    " ".join((node.attrib.get("text", ""), node.attrib.get("content-desc", ""))).strip()
    for node in nodes
]
is_anr = any(
    "not responding" in label.lower() or "isn't responding" in label.lower()
    for label in labels
)
if not is_anr:
    print("NONE")
    raise SystemExit(0)

for node in nodes:
    label = " ".join((node.attrib.get("text", ""), node.attrib.get("content-desc", ""))).strip()
    if label.lower() == "wait":
        bounds = node.attrib.get("bounds", "")
        values = [int(part) for part in re.findall(r"-?\d+", bounds)]
        if len(values) == 4:
            print(f"WAIT {(values[0] + values[2]) // 2} {(values[1] + values[3]) // 2}")
            raise SystemExit(0)

print("ERROR: ANR dialog detected but its Wait button was not exposed")
raise SystemExit(2)
PY
then
  cat build/android/anr-action.txt
  echo "::error::Could not safely inspect the emulator's system ANR dialog."
  exit 1
fi

read -r action tap_x tap_y < build/android/anr-action.txt
case "$action" in
  NONE)
    echo "No system ANR dialog detected."
    ;;
  WAIT)
    echo "System launcher ANR dialog detected; selecting its visible Wait button."
    adb shell input tap "$tap_x" "$tap_y"
    sleep 8
    dump_ui
    if grep -Eiq "not responding|isn't responding" build/android/emulator-window.xml; then
      echo "::error::The emulator system ANR dialog remained after selecting Wait."
      exit 1
    fi
    ;;
  *)
    cat build/android/anr-action.txt
    echo "::error::Unexpected ANR detector result."
    exit 1
    ;;
esac

timeout 30s adb shell dumpsys activity activities > build/android/emulator-activity.txt
foreground="$(grep -E 'topResumedActivity|ResumedActivity' build/android/emulator-activity.txt | grep -F 'com.example.divslayer.qa/' || true)"
if [[ -z "$foreground" ]]; then
  echo "::error::Divslayer is not the resumed foreground activity."
  exit 1
fi
printf '%s\n' "$foreground"

timeout 30s adb shell screencap -p /sdcard/divslayer-qa-launch.png
timeout 30s adb pull /sdcard/divslayer-qa-launch.png build/android/emulator-launch.png
test -s build/android/emulator-launch.png

echo "Captured Android QA launch screenshot with no visible system ANR dialog."
echo "Divslayer Godot setup completed and the QA app remained in the foreground."
