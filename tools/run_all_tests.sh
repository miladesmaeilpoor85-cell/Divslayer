#!/usr/bin/env bash
# Run the complete Godot suite. CI may distribute suites across independent shards.
# Usage: tools/run_all_tests.sh <label> [preload.so]
set -uo pipefail
cd "$(dirname "$0")/.."

label=${1:-normal}
pre=${2:-}
test_timeout=${GODOT_TEST_TIMEOUT_SECONDS:-400}
shard_index=${GODOT_TEST_SHARD_INDEX:-0}
shard_count=${GODOT_TEST_SHARD_COUNT:-1}

if ! [[ "$test_timeout" =~ ^[1-9][0-9]*$ ]]; then
  echo "GODOT_TEST_TIMEOUT_SECONDS must be a positive integer." >&2
  exit 2
fi
if ! [[ "$shard_index" =~ ^[0-9]+$ && "$shard_count" =~ ^[1-9][0-9]*$ ]] || (( shard_index >= shard_count )); then
  echo "Invalid Godot test shard: index=$shard_index count=$shard_count" >&2
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

# Keep every suite from main, including the Chapter IV wind and animation tests.
tests=(windgusttest quittest achtest rushtest audiotest shrinetest chapter2test chapter3test chapter4test tutorialtest questpointtest texttest v24fixtest sigtest v26fixtest v27fixtest v28portraittest trialtest contracttest elitetest anvilwardtest ashkbustest difftest storytest forgetest alchemytest geartest tolltest stealthtest blocktest uitest fxtest bossfxcleartest bosstest skilltest animationtest warriorreviewtest)
selected_tests=()
for i in "${!tests[@]}"; do
  if (( i % shard_count == shard_index )); then selected_tests+=("${tests[$i]}"); fi
done
if (( ${#selected_tests[@]} == 0 )); then
  echo "No tests assigned to shard $shard_index/$shard_count" >&2
  exit 2
fi

printf 'SHARD %s/%s suites=%s autotest=%s\n' "$shard_index" "$shard_count" "${#selected_tests[@]}" "$([[ $shard_index -eq 0 ]] && echo yes || echo no)" | tee -a "$out"
for test_name in "${selected_tests[@]}"; do
  test_log="/tmp/ei_tests/${label}.${test_name}.raw.log"
  started=$SECONDS
  printf 'START %s\n' "$test_name" | tee -a "$out"
  run_godot -- --test "res://tests/${test_name}.gd" 2>&1 | tee "$test_log"
  status=${PIPESTATUS[0]}
  elapsed=$((SECONDS - started))
  passes=$(grep -cE '^PASS' "$test_log" || true)
  fails=$(grep -cE '^FAIL' "$test_log" || true)
  crashes=$(grep -c 'signal 11' "$test_log" || true)
  errors=$(grep -Ec 'SCRIPT ERROR|Parse Error' "$test_log" || true)
  timed_out=0
  [[ $status -eq 124 || $status -eq 137 ]] && timed_out=1
  printf '== %s exit=%s elapsed=%ss pass=%s fail=%s crash=%s errors=%s timeout=%s\n' "$test_name" "$status" "$elapsed" "$passes" "$fails" "$crashes" "$errors" "$timed_out" | tee -a "$out"
  if [[ $status -ne 0 || $fails -gt 0 || $crashes -gt 0 || $errors -gt 0 ]]; then
    failed=1
    grep -E '^FAIL|SCRIPT ERROR|Parse Error|signal 11|ERROR:' "$test_log" | head -30 | tee -a "$out" || true
    if [[ ! -s "$test_log" ]]; then echo "No test output was produced before exit." | tee -a "$out"; fi
  fi
done

if (( shard_index == 0 )); then
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
else
  echo "AUTOTEST_ASSIGNED_TO_SHARD_0" | tee -a "$out"
fi

if [[ $failed -ne 0 ]]; then
  echo "TESTS_FAILED shard=$shard_index/$shard_count" | tee -a "$out"
  exit 1
fi
if (( shard_index == 0 )); then
  echo "ALL_TESTS_PASSED" | tee -a "$out"
else
  echo "SHARD_TESTS_PASSED shard=$shard_index/$shard_count" | tee -a "$out"
fi
