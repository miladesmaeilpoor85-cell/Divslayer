# Side quests — test report (v0.27.0) — IN PROGRESS

Tester: side-quest tester. Runs in /home/claude/studio/runs/side/NNN, scenarios in runs/side_scenarios/.
SEEN = seen in a run (run/step or shot). READ = read in code only (file:line), not yet played.
Test shortcuts used: `preset`, `goto`, `set`, `invuln` (named per run below).

## Table (state after run 001; runs 002-006 pending)

| # | Item | Found? (told it exists / where) | Startable? | Completable? | Reward? |
|---|---|---|---|---|---|
| 1 | Gordafarid / Bounty Board | SEEN 001 step 5, shot 02: Gordafarid opens the board, three contracts with reward and n/need. No line says WHERE a foe lives. | SEEN 001 step 5 (contracts exist at once, no "accept") | READ game.gd:991-1010, main.gd:972 (claim at board) — pending run 005 | READ gold = need*gold*2+15, xp (game.gd:975) — pending |
| 2 | Siavash's Trial | SEEN 001 step 64, shot 16: Siavash explains, "leave by the southern gate" | SEEN 001 step 66 (enter) | pending (rest of run 001) | READ trial.gd:28-31,112-128: gold 20+8n, xp, rare/epic item every 5th wave |
| 3 | Sindokht's toll | SEEN 001 step 15: she gives it before the shop opens; says "south of the Whispering Forest" | SEEN 001 shot 04 toast "مأموریت تازه: باج خارزار" | READ main.gd:768-785, 730-766 — pending run 002 | READ main.gd:726: 100-300 gold + 20% off for good |
| 4 | Jamshid's forge quest | SEEN 001 step 0: objective "هستهٔ نگهبان را به جمشید برگردان" after Arzhang; step 22 he names the door in the Ashen Peaks | SEEN 001 step 22-24: Kindling Key toast | READ game.gd:1052-1146 — pending run 003 | READ game.gd:1126-1143: 350 gold, forge +1/+1, then +2/+2 and 3 talent points |
| 5 | Hom (pages, wolves) | READ chapter2.gd:105-109 (he tells both on first meeting); only in the quest log, never on the objective/compass (game.gd:746-790 has no Hom line) | READ chapter2.gd:420-428 | READ chapter2.gd:378-398 | READ chapter2.gd:429-434: 250 gold+rare, 300 gold+epic |
| 6 | Bandit camp / Ashkbus | READ toll.gd, world.gd:682-830 | READ world.gd:762-781 (parley on being seen) | pending run 002 | pending |
| 7 | Bid the Div (Toad King) | READ game.gd:654: Zal names him once when giving quest 3; no objective, no map mark | READ shadowfen boss at (402,918) | pending run 005 | READ game.gd:716-722: 1-2 essence, a relic if CH_RELICS has one |
| 8 | Boss Rush / New Game+ | READ main.gd:556-634 (Sorush's menu after chapter 2) | READ rush.gd:74-86 | READ rush.gd:171-209 | READ rush.gd:36-37: 1500 gold first time, 300 after |
| 9 | Cauldron / forge loop | SEEN 001 shots 08-13: Rudabeh says "bring Bogbloom from the Shadowfen"; costs shown per recipe | SEEN 001 step 38 (opens) | pending run 005 (brew with real loot) | — |

## Problems so far (to be ranked at the end)

- WRONG STATE (SEEN 001 step 5): at level 8 with only quest 2 open, the board offers "۶ پشهٔ مرداب را بکش" (Shadowfen mosquitoes). The Shadowfen opens with quest 3. The pool is gated by level only (game.gd:940, 954-962), not by what the story has opened. Smallest fix: in `contract_pool()` also require the map to be open (q2 not "not_started" for peaks, q3 for shadowfen, chapter 2 for sanctum).
- UNCLEAR (SEEN 001 shot 02): a contract names the foe but not the region. Smallest fix: add the region name to `contract_label` from CH_HUNT_POOL.maps.
- UNCLEAR (SEEN 001 steps 17, 25): after taking the toll the HUD objective stays on the main quest; after Jamshid gives the key it falls back to the main quest. Both sit only in the pause quest log (shot 15). By design (game.gd:776-784), but nothing on the HUD says a side quest is open.
- COSMETIC (SEEN 001 step 41): the cauldron list keeps its scroll position when reopened; the first recipe's button was off-screen (y = -58).

## Not tested yet
Everything marked pending.
