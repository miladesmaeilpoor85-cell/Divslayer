# QA report: Ember & Iron 0.26.1 (QA seat)

Status: final, after runs 001–007 (7 runs; scenarios in runs/qa_scenarios/, run folders in runs/qa/NNN/).
Test shortcuts (preset / goto / set / invuln) are named wherever a row depends on them. A player cannot use them.

## Bugs

| # | Sev | What happened | Steps | Evidence | Seen / Read |
|---|-----|---------------|-------|----------|-------------|
| 1 | wrong state | Pause menu **Save & quit** does not save where the hero stands. The hero walked to (656,649), pressed Save & quit, then Continue, and came back at (420,502), the point where he had entered Zabol. Cause: `pause_menu.gd:163 _quit()` and `main.gd:169 _quit_to_title()` call `Game.save_game()` without writing `state.x/y`. Only `goto_map`, `_on_engage` and the OS pause notification (`main.gd:338`) write them. A player who quits this way is sent back to the map's entrance, or to the spot where he last engaged a boss. | s3_presets_savequit.json steps 15–24 (endgame preset, then only stick and taps) | runs/qa/003 log: STEP 17 pos [656,649] → STEP 24 pos [420,502] | SEEN + READ |
| 2 | wrong state | **A map change can land on the wrong map.** The hero stood inside the forest's Crypt exit without it firing (see #3). The next map change then sent him into the Sunken Crypt instead of the map that was asked for. Run 007: `goto forest` → "on dungeon". Run 006: `goto shadowfen` → "on dungeon", then he died there next to Arzhang. Seen twice, with the `goto` test shortcut. Likely cause (READ only, not proven): exits are `Area2D.body_entered` (`world.gd:260`). In `goto_map` the old world is only `queue_free`d, its exit signal stays connected to `main._on_exit`, and the hero is moved after he has been re-added, so the old world's armed exit sees him enter. Whether a player can reach this (for example Respawn or Rematch while standing in an exit) was NOT verified. | s7_repro_wrong_map.json steps 5–9; s6_firewalk_boss_bogdeath.json steps 8–9 then 32 | runs/qa/007 log STEP 9 `goto forest` → "on dungeon"; runs/qa/006 log STEP 32 `goto shadowfen` → "on dungeon" | SEEN (with shortcut) + READ |
| 3 | minor | An exit that the hero enters during its first 0.6 s after arriving on a map (`world.gd:198`, exits are disarmed for that time) never fires while he stays in it. He stood in the Crypt exit for 8 s and nothing happened. He has to step out and walk in again. In both runs he arrived 16 px from the exit via `goto`. A player would only hit this by walking back into an exit right after arriving. | s7_repro_wrong_map.json steps 5–8 (also s6 step 9) | runs/qa/007 STEP 6 "gave up after 8 s, 24 px short"; STEP 8 still on forest | SEEN (with shortcut) + READ |
| 4 | minor | Switching fa→en mid-drill: the drill toast already on screen stays in Persian ("سه بار به چوبهٔ تمرین بزن…") while the HUD and names switch to English. It lasts up to 2.4 s (`hud.gd:499`). | s1_training_save.json steps 35–38 | runs/qa/001 shots/06_drill_en.png + its SCREEN line | SEEN |

## Checked and fine
- Mid-drill save/continue at Rostam's strike step (2/3): the count, objective, gold and potions were all kept, nothing doubled (001 steps 13–21).
- "Enough training" → save → continue → "Train with me after all": the objective is right at each step (001 steps 24–36).
- Leaving Zabol mid-drill: no error, no gift paid early (001 steps 40–43).
- Calling moves: the mage's feather cast at the village exit and carried into the forest. The paladin's fire-walk cast at the village exit and carried into the forest. The move spammed 4×, and used after 3 rolls (low stamina). No script error, no stuck state (002 steps 12–31; 006 steps 2–6).
- Calling move and potion pressed while dead: ignored, the death panel stays (005 steps 20–22).
- Death and respawn: the 20% gold loss adds up (118→95, 158→127). The panel's sum matches. Respawn in Zabol gives full HP, keeps the objective, leaves potions as they were, no error (005 steps 16–25; 006 steps 33–39).
- Presets act2 / act3 / ch2 / ch3 / endgame each load into Zabol with a readable objective and a hero who can move. No error (003 steps 0–14).
- Language switch with the game's own buttons (Settings → English / فارسی) while the pause menu is open: the whole menu relabels both ways (005 shots 01–02).
- 854x400, UI size Large, English: pause pages Hero / Skills / Gear / Map / Settings (scrolled) / Achievements, and Sindokht's shop. All text is in English, and the shop screenshot shows no clipping (004 shots 03–12).
- 1600x720 fa pause menu (Hero page): no clipping (003 shot 06). 1280x720, UI size Small, fa: Kavian's menu (005 shot 05). 1067x480, en: Rudabeh's cauldron, all in English (006 shot 05).
- Continue twice in a row: no repeated "achievements earned" toast (004 steps 0–3).
- godot.txt for all 7 runs: no SCRIPT ERROR and no Parse Error. The only lines are "N resources still in use at exit" and "ObjectDB instances leaked at exit", printed at quit.
- Run 002's stuck walk to the peaks exit is by design: the eastern path is sealed in act 1 (`world.gd:271`).

## Could not test / not concluded
- Calling move during a dialogue or a boss intro: the touch pad ignores presses while the tree is paused (`touch_pad.gd:98`, READ). In run 002 the raw talk-button press did not open Zal's dialogue, so this was not seen on screen.
- Calling move while stunned, and saving with a status effect on: no reliable way to get either with the kit inside the budget.
- Death to a common foe with no boss engaged: both deaths (005 peaks, 006 crypt) happened with a boss engaged, so a Rematch was offered, which is correct. Deaths in chapter 2 and 3 were not tried.
- Map change during a boss intro card: only possible with `goto`, because the tree is paused. In run 007 (STEP 14–16) Arzhang's card stayed up over the Shadowfen after `goto`. Kit-only, not reported.
- The forge and cauldron panels themselves in fa at UI size Large. 854x400 in fa.
- Kit notes. The kit's `save` step does not write x/y either. The kit's `lang` step does not rebuild open panels (004 shot 09, use the game's own buttons instead). The `endgame` preset does not set chapter 3, so its objective is the chapter-3 opener.
