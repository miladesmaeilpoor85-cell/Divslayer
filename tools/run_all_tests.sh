#!/bin/bash
# tools/run_all_tests.sh <label> [preload.so]  -> runs every suite (and the autotest), writes /tmp/ei_tests/<label>.log
# e.g.  tools/run_all_tests.sh normal ;  tools/run_all_tests.sh guard tools/guardmalloc.so  (build it first, see DEV_NOTES)
cd "$(dirname "$0")/.."
label=$1; pre=$2
mkdir -p /tmp/ei_tests; out=/tmp/ei_tests/$label.log; : > $out
for t in quittest achtest rushtest audiotest shrinetest chapter2test chapter3test tutorialtest texttest v24fixtest sigtest v26fixtest v27fixtest v28portraittest trialtest contracttest difftest storytest forgetest alchemytest geartest tolltest stealthtest blocktest uitest fxtest bosstest skilltest; do
  r=$(LD_PRELOAD=$pre timeout 400 godot --headless --fixed-fps 60 --path . -- --test res://tests/$t.gd 2>&1)
  echo "== $t pass=$(echo "$r" | grep -cE '^PASS') fail=$(echo "$r" | grep -cE '^FAIL') crash=$(echo "$r" | grep -c 'signal 11')" >> $out
  echo "$r" | grep -E "^FAIL|SCRIPT ERROR|Parse Error|signal 11" | head -5 >> $out
done
r=$(LD_PRELOAD=$pre timeout 400 godot --headless --fixed-fps 60 --path . -- --autotest 2>&1)
echo "== autotest json=$(echo "$r" | grep -c AUTOTEST_JSON) fail=$(echo "$r" | grep -cE 'FAIL') crash=$(echo "$r" | grep -c 'signal 11')" >> $out
echo ALLDONE >> $out
