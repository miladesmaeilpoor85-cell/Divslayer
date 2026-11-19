#!/usr/bin/env bash
# Run every headless suite and the autotest. Each suite is bounded independently,
# progress is streamed to CI, and failures retain the exact suite output.
# Usage: tools/run_all_tests.sh <label> [preload.so]
set -uo pipefail

cd "$(dirname "$0")/.."
label=${1:-normal}
pre=${2:-}
test_timeout=${GODOT_TEST_TIMEOUT_SECONDS:-120}
if ! [[ "$test_timeout" =~ ^[1-9][0-9]*$ ]]; then
  echo "GODOT_TEST_TIMEOUT_SECONDS must be a positive integer (seconds)." >&2
  exit 2
fi

mkdir -p /tmp/ei_tests
out="/tmp/ei_tests/${label}.log"
: > "$out"
failed=0

run_godot() {
  if [[ -n "$pre" ]]; then
    LD_PRELOAD="$pre" timeout --signal=TERM --kill-after=10 "${test_timeout}s" godot --headless --fixed-fps 60 --path . "$@"
  else
    timeout --signal=TERM --kill-after=10 "${test_timeout}s" godot --headless --fixed-fps 60 --path . "$@"
  fi
}

tests=(quittest achtest rushtest audiotest shrinetest chapter2test chapter3test tutorialtest texttest v24fixtest sigtest v26fixtest v27fixtest v28portraittest trialtest contracttest elitetest anvilwardtest ashkbustest difftest storytest forgetest alchemytest geartest tolltest stealthtest blocktest uitest fxtest bossfxcleartest bosstest skilltest)

for t in "${tests[@]}"; do
  test_log="/tmp/ei_tests/${label}.${t}.raw.log"
  started=$SECONDS
  printf 'START %s\n' "$t" | tee -a "$out"

  run_godot -- --test "res://tests/${t}.gd" 2>&1 | tee "$test_log"
  status=${PIPESTATUS[0]}

  elapsed=$((SECONDS - started))
  passes=$(grep -cE '^PASS' "$test_log" || true)
  fails=$(grep -cE '^FAIL' "$test_log" || true)
  crashes=$(grep -c 'signal 11' "$test_log" || true)
  errors=$(grep -Ec 'SCRIPT ERROR|Parse Error' "$test_log" || true)
  timed_out=0
  [[ $status -eq 124 || $status -eq 137 ]] && timed_out=1

  summary="== $t exit=$status elapsed=${elapsed}s pass=$passes fail=$fails crash=$crashes errors=$errors timeout=$timed_out"
  printf '%s\n' "$summary" | tee -a "$out"

  if [[ $status -ne 0 || $fails -gt 0 || $crashes -gt 0 || $errors -gt 0 ]]; then
    failed=1
    grep -E '^FAIL|SCRIPT ERROR|Parse Error|signal 11|ERROR:' "$test_log" | head -30 | tee -a "$out" || true
    if [[ ! -s "$test_log" ]]; then
      echo "No test output was produced before exit." | tee -a "$out"
    fi
  fi
done

test_log="/tmp/ei_tests/${label}.autotest.raw.log"
started=$SECONDS
printf 'START autotest\n' | tee -a "$out"
run_godot -- --autotest 2>&1 | tee "$test_log"
status=${PIPESTATUS[0]}
elapsed=$((SECONDS - started))
json_count=$(grep -c 'AUTOTEST_JSON' "$test_log" || true)
fails=$(grep -cE '^FAIL' "$test_log" || true)
crashes=$(grep -c 'signal 11' "$test_log" || true)
errors=$(grep -Ec 'SCRIPT ERROR|Parse Error' "$test_log" || true)
timed_out=0
[[ $status -eq 124 || $status -eq 137 ]] && timed_out=1
printf '== autotest exit=%s elapsed=%ss json=%s fail=%s crash=%s errors=%s timeout=%s\n' "$status" "$elapsed" "$json_count" "$fails" "$crashes" "$errors" "$timed_out" | tee -a "$out"
if [[ $status -ne 0 || $json_count -eq 0 || $fails -gt 0 || $crashes -gt 0 || $errors -gt 0 ]]; then
  failed=1
  grep -E '^FAIL|SCRIPT ERROR|Parse Error|signal 11|ERROR:' "$test_log" | head -30 | tee -a "$out" || true
fi

if [[ $failed -ne 0 ]]; then
  echo "TESTS_FAILED" | tee -a "$out"
  exit 1
fi

echo "ALL_TESTS_PASSED" | tee -a "$out"
