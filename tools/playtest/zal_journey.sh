#!/usr/bin/env bash
# Use an isolated fresh profile and preserve the report even when the journey fails.
set -eu
project=$(cd "$(dirname "$0")/../.." && pwd)
run=$(mktemp -d "${TMPDIR:-/tmp}/divslayer-zal-XXXXXXXX")
printf 'Evidence directory: %s\n' "$run"
export XDG_DATA_HOME="$run/profile"
mode=()
if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then mode=(--headless); fi
exec godot "${mode[@]}" --path "$project" --resolution 1600x720 --fixed-fps 60 --audio-driver Dummy \
  -- --playtest --test res://tests/zal_journey.gd --journey-seed "${1:-705}" --out "$run"
