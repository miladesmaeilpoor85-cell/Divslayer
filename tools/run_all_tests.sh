#!/usr/bin/env bash
# Run every headless suite and the autotest. Any failed suite, crash, timeout,
# parser error, or non-zero process exit makes this script return non-zero.
# Usage: tools/run_all_tests.sh <label> [preload.so]
set -u

cd "$(dirname "$0")/.."
label=${1:-normal}
pre=${2:-}
mkdir -p /tmp/ei_tests
out="/tmp/ei_tests/${label}.log"
: > "$out"
failed=0

run_godot() {
  if [[ -n "$pre" ]]; then
    LD_PRELOAD="$pre" timeout 400 godot --headless --fixed-fps 60 --path . "$@" 2>&1
  else
    timeout 400 godot --headless --fixed-fps 60 --path . "$@" 2>&1
  fi
}

for t in quittest achtest rushtest audiotest shrinetest chapter2test chapter3test tutorialtest texttest v24fixtest sigtest v26fixtest v27fixtest v28portraittest trialtest contracttest elitetest anvilwardtest ashkbustest difftest storytest forgetest alchemytest geartest tolltest stealthtest blocktest uitest fxtest bossfxcleartest bosstest skilltest animationtest; do
  r=$(run_godot -- --test "res://tests/$t.gd")
  status=$?
  passes=$(printf '%s\n' "$r" | grep -cE '^PASS' || true)
  fails=$(printf '%s\n' "$r" | grep -cE '^FAIL' || true)
  crashes=$(printf '%s\n' "$r" | grep -c 'signal 11' || true)
  errors=$(printf '%s\n' "$r" | grep -Ec 'SCRIPT ERROR|Parse Error' || true)
  printf '== %s exit=%s pass=%s fail=%s crash=%s errors=%s\n' "$t" "$status" "$passes" "$fails" "$crashes" "$errors" >> "$out"
  printf '%s\n' "$r" | grep -E '^FAIL|SCRIPT ERROR|Parse Error|signal 11' | head -10 >> "$out" || true
  if [[ $status -ne 0 || $fails -gt 0 || $crashes -gt 0 || $errors -gt 0 ]]; then
    failed=1
  fi
done

r=$(run_godot -- --autotest)
status=$?
json_count=$(printf '%s\n' "$r" | grep -c 'AUTOTEST_JSON' || true)
fails=$(printf '%s\n' "$r" | grep -cE '^FAIL' || true)
crashes=$(printf '%s\n' "$r" | grep -c 'signal 11' || true)
errors=$(printf '%s\n' "$r" | grep -Ec 'SCRIPT ERROR|Parse Error' || true)
printf '== autotest exit=%s json=%s fail=%s crash=%s errors=%s\n' "$status" "$json_count" "$fails" "$crashes" "$errors" >> "$out"
printf '%s\n' "$r" | grep -E '^FAIL|SCRIPT ERROR|Parse Error|signal 11' | head -10 >> "$out" || true

if [[ $status -ne 0 || $json_count -eq 0 || $fails -gt 0 || $crashes -gt 0 || $errors -gt 0 ]]; then
  failed=1
fi

if [[ $failed -ne 0 ]]; then
  echo "TESTS_FAILED" >> "$out"
  cat "$out"
  exit 1
fi

echo "ALL_TESTS_PASSED" >> "$out"
cat "$out"
