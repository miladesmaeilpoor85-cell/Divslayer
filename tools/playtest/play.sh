#!/bin/bash
# Play the game from a scenario, as a phone player (touches), and keep what was seen.
#   play.sh <tester> <scenario.json> [WxH]
#     tester    a name: each tester has its own saves/profile (data/<tester>) and its runs (runs/<tester>/NNN)
#     WxH       the screen, landscape (default 1600x720, a 20:9 phone; 854x400 is the game's own layout size)
# Prints the run folder; read its log.txt and look at shots/*.png.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
GAME="${GAME:-$(cd "$HERE/../.." && pwd)}"
WORK="${PLAYTEST_HOME:-/tmp/ember_playtest}"
T="${1:?tester name}"; S="${2:?scenario.json}"; RES="${3:-1600x720}"
mkdir -p "$WORK/data/$T" "$WORK/runs/$T"
N=$(ls "$WORK/runs/$T" | wc -l); N=$(printf "%03d" $((N + 1)))
OUT="$WORK/runs/$T/$N"; mkdir -p "$OUT"
cp "$S" "$OUT/scenario.json"
# one game at a time on this machine (two cores): wait for the lock
exec 9>"$WORK/.lock"; flock 9
XDG_DATA_HOME="$WORK/data/$T" timeout 900 xvfb-run -a -s "-screen 0 ${RES}x24" \
  godot --path "$GAME" --rendering-driver opengl3 --resolution "$RES" --fixed-fps 60 --audio-driver Dummy \
  -- --test res://tests/playtest.gd --playtest --script "$OUT/scenario.json" --out "$OUT" > "$OUT/godot.txt" 2>&1
code=$?
flock -u 9
grep -E "SCRIPT ERROR|ERROR:|Parse Error" "$OUT/godot.txt" | grep -v "ALSA\|audio" | head -20 > "$OUT/errors.txt"
echo "RUN $OUT (exit $code)"
[ -s "$OUT/errors.txt" ] && { echo "--- engine errors:"; cat "$OUT/errors.txt"; }
echo "--- log:"; cat "$OUT/log.txt" 2>/dev/null | cut -c1-1500
