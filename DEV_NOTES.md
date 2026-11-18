# Divslayer / دیوکش (Godot; Ember & Iron until 0.29) — notes for whoever continues the work

The name changed in 0.29 for sales («دیوکش» says action and Shahnameh at a glance; the old name said neither). Old names
stay in history (CHANGELOG, studio reports, code comments). The hero is an anti-hero since 0.29: a sell-sword the ember fell
to, not a chosen one — keep new lines in that voice (people respect what he does, not what he is; rewards are wages; the
songs are Rostam's).

Godot port of the HTML game (`ember_and_iron_v18.html`). Current version: see `Game.VERSION` in `scripts/game.gd` and CHANGELOG.md.
The owner, Milad, writes in Persian, tests on his phone and PC, and wants the work done end to end
(build, test, export, sign) with honest reports and at most one question at a time.

## Engine and project
- Godot **4.6.2 stable** or **4.7.2** (standard, not .NET — the .NET/mono editor without the .NET SDK warns that it may
  crash), renderer **GL Compatibility**, viewport 854×400,
  stretch `canvas_items` + `expand`, landscape. Everything is built in code (one scene: `scenes/main.tscn`).
- Autoloads: `Game` (state, data tables, settings, save, day/night, quest routing), `Sfx` (recorded CC0 sounds with
  variations + the synthesised ones), `UI` (theme, fonts, Lucide icons from `data/icons.json`), `Music` (recorded region
  tracks with crossfades, ambience loops; the generative tune as fallback). See "Audio" below.
- Persian first: Vazirmatn fonts, RTL layouts, Persian digits via `Game.num()`, texts via `Game.t(en, fa)`.

## Where things are
- `scripts/main.gd` flow (title → world, map changes, death/rematch, level-up) · `world.gd` one map
- `player.gd`, `enemy.gd`, `boss.gd`, `bossfx.gd` (v18 telegraphs), `arena_obj.gd`, `hazards.gd`
- Block and parry (v0.7): in `player.gd` (`block_start`, `block_end`, `_guard`, `_parry_stagger`, `_block_visual`), button "block" in `touch_pad.gd`, keys C / N. Hold to block (30% through, stamina cost, slower walk); raising it within `PARRY_WIN` (0.2 s) before a blow is a perfect parry (no damage, foes stunned, bosses staggered, ult +8). Stamina too low = guard break (1.4 s lockout).
- Sneak and shove (v0.8): `player.gd` (`toggle_sneak`, `stealth_mul`, `shove`, backstab in `attack`), `enemy.gd` (`alert`, sight range uses `stealth_mul`), `world.gd` (`grass` patches, `in_grass`), buttons in `touch_pad.gd`, keys Z / F.
- Thornwood Toll (v0.9): state `Game.toll()` {st: none|active|box|done, how, ledger, truce}; Thalia and pickups in `main.gd` (`_talk_thalia`, `_take_strongbox`, `_parley_*`), camp logic in `world.gd` (`on_notice`, `parley_done`, `truce_broken`, `scatter`), `Enemy.parley`/`rally`, choices in `dialogue.gd`, lines in `scripts/toll.gd`.
- Gear (v0.10): `scripts/gear.gd` (static: roll, add, equip, sell, sum, uniq, relic, drop_from), state `gear` {eq, bag}; stats hooked in `game.gd` (max_hp, atk, defense, speed, crit_chance, max_mp, mp_regen, max_stamina, add_ult, incoming); effects in `player.gd` (`_procs`, `_thorns`, `_emberfall`, `_revive_item`); map items `world.gd` (`_items_setup`, `_items_tick`) + `Game.collect`; Gear tab `pause_menu.gd` (`_gear`).
- Alchemy (v0.11): `scripts/craft.gd` (Miri's panel), `Game` (herbs, essence, scrolls, recipes, craft, spend_scroll, herb_drop, scroll_sel), `player.gd` (`use_scroll`, `haste_t`, `regen_t`), `caster.cast_free`, touch button "scroll", Gear tab sections, `main.gd` (`_talk_miri`).
- Forge (v0.12): `scripts/forge.gd` (panel), `Game.forge()/forge_cost/forge_block/forge_upgrade` (state `forge` {w, a}, max 5), hooked into `atk()` and `defense()`; Garen's choice in `main.gd` (`_talk_garen`). NOT in the port yet: the story after Elder Rowan's three quests (Brann, Warden Core, Kindling Key, Ignarok, the Peaks door), difficulty levels.
- Brann the Exile (v0.13): state `Game.brann()` none|core|anvil|anvil_done|ignarok|ignarok_done|done; `brann_sync/key/objective/target/lines/step` in `game.gd`, lines in `scripts/story.gd`, Brann's talk in `main.gd`, the Kindling door (a synthetic exit + `_door_visual`) in `world.gd` (peaks), mini bosses `captain` and `anvilward` call `boss_defeated` from `Enemy.die`. Still missing: the Boss Rush (RUSH_BOSSES), the achievements (ACHIEVEMENTS.json, 21), the village fountain (FOUNTAIN.json), hero crowns (cosmetics, "Earned at 25 contracts"), Frostreaver / Glacial Aegis, the Sanctum's Memory Keeper and the Wyrm Key chamber.
- Difficulty (v0.14): `Game.DIFFS`, `diff()`, `diff_mul()`, `diff_name()`; applied in `enemy_stats` (hp), `incoming` (damage), `xp_mul`, `gold_mul`; Settings row in `pause_menu.gd`.
- Bounty Board (v0.15): `Game.contracts()/contract_fill/contract_progress/contract_claim` (state `contracts` {list, claimed}), kill hook in `Enemy.die`, the board node `world._board()` (village), claim dialogue `main._open_board`, Hero page lines in `pause_menu.gd`.
- Trial and elites (v0.16): `scripts/trial.gd` (the wave runner, `plan(n)` is pure), the arena gate `world._arena_gate`, `main._open_arena`, `Enemy.make_elite` (aura, stats, status), `Game.trial()/elites_slain()/elite_rate/testing` (the test runner sets `Game.testing` so the maps spawn no random elites). Bosses are NOT used in the Trial: their fights need their own arenas; a Boss Rush must handle that.
- Shrines (v0.18): `scripts/shrine.gd` (one node on a shrine map: builds the pieces from the map's `v16objs` and the 17x13 layout in
  `V16_SHRINE_LIST`, runs the mechanics, `strike()` / `element()` / `shot_at()` are called by the player's swing, the caster's area
  spells and the spell projectiles), `scripts/fx/shrine_art.gd` (every piece drawn in code), the gate and pillar of light
  `world._shrine_gate`, the altar `main._shrine_altar` / `_on_sigil`, state `Game.shrine(key)` {door, claimed, gift} and
  `Game.sigil()/sigil_bonus()/take_sigil()` (hooked into max_hp, atk, defense, max_mp), `Game.SHRINE_ORDER` for the compass.
- Chapter 2 (v0.19): `scripts/chapter2.gd` (`Game.Ch2`, static: the steps "" -> keeper -> shards -> forge -> descend -> slain ->
  done, every line in both languages, objective/target/news/gates/log, the Elder's, Keeper's, Hesk's and Brann's lines and what
  happens after them; state `Game.state.c2`), `scripts/vault.gd` (the rimeglass vault in the Sanctum), `scripts/ui/ending.gd` (the
  end card), the Sanctum's door and east rimeglass `world._ch2_sanctum`, the talks in `main.gd` (`_talk_keeper`, `_talk_hesk`,
  `_brann_frost`, `_wyrm_stirs`, `_chapter_end`), boss kits `boss._ai_titan` / `_ai_wyrm` (+ motion "fly"), shooters
  `enemy._shooter` (ENEMY_TYPES "shoots": {every, speed, applies, col, range, keep, n}), boss music `Music.set_boss(true, type)`
  plays `boss_<type>.ogg` when there is one. Hooks in `game.gd`: elder_lines, elder_has_news, boss_defeated, objective,
  quest_target, collect (pages). The maps: `data/Maps/frostvale.json`, `wyrmhollow.json` (made by `tools/ch2_maps.py`, which also
  paints their grounds and adds the Sanctum's two exits); foes and scaling by `tools/ch2_data.py`; art by `tools/ch2_art.py`.
  After changing a map: `python3 tools/make_world_graph.py` (data/world_graph.json), `python3 tools/map_preview.py <map> out.png`.
- Achievements and looks (v0.20): `scripts/achievements.gd` (`Game.Ach`, static: the list of 34 `[id, icon, name en/fa, desc en/fa,
  counter, need, secret]`, the profile `user://profile.json` — `user://profile_test.json` under the test runner — with `ach`, `stats`,
  `look`, `new`; `add(counter)` from the hooks, `check()` on `Game.stats_changed` for the ones read from the save, `on_boss()` from
  `Game.boss_defeated` (the fight's `hurt` flag, set in `player.take_hit`, decides "Untouched"), `sync()` at `main.start_world`).
  Hooks: kills `Enemy.die`, crits / backstabs `player.attack`, parries `player._guard`, dodges `player.dodge`, ults `caster.ultimate`,
  crafts `Game.craft`. The card `scripts/ui/ach_card.gd` (listens to `Game.achieved`), the pages `pause_menu._achievements` /
  `_looks` (Hero tab, `hsub`). `scripts/looks.gd` (`Game.Looks`: `ORDER`, `EARN` look -> achievement, `material(sheet, look)`, aura /
  trail / crown) + `scripts/fx/hero_look.gdshader` + the masks `assets/art/Heroes/<sheet>_mask.png` and `data/hero_masks.json` made
  by `tools/make_hero_masks.py` (R = class cloth, full recolour; G = the paladin's plate, half; rules per class: hue window,
  saturation, brightness, rows left alone). The hero: `player.refresh_look` (sheet + look), `_look_extras` (aura sprite, crown node),
  `_look_tick` (pulse, motes); the after-images carry the material (`fx.ghost`).
- The fountain (v0.20): `scripts/fx/fountain.gd` (drawn in code, in the y-sort at the basin's front edge; light, water sound,
  `_restore` heals within `heal_r`; off under the test runner unless `in_tests`, because the village start is next to it). The map
  already had its square wall (416, 396, 72×72) and a `{"special": "fountain"}` object the port ignores.
- Boss Rush (v0.21): `scripts/rush.gd` (`Game.Rush`; a Node under main while a run is on, `main.rush_run`): `ORDER` [boss, map,
  hero's feet, run health, run damage scale], the pouch (`POUCH`, `MANA_POUCH`), `HEAL_BETWEEN`, `FAST_SEC`; `begin` → `_go(i)` (fade,
  `main.goto_map`, banner) → `on_victory` (from `main._on_victory`) → next or `_complete`; `on_died` (from `main._on_died`); `abort`
  (from `main._quit_to_title`). `Game.rush` (not saved) is what the scaling reads (`Game.area_scale`: the run's damage;
  `Game.enemy_stats`: the run's health for its boss) and what makes a map a memory (`world.rush`: only that boss, no NPCs / items /
  camp / shrine gates / sanctum pieces, exits never armed, a `CanvasModulate` named "Memory"). `Game.boss_defeated` returns at once in
  a run (no bounty, relic, quest). `state.rush_keep` holds the hero's own potions and the Keeper's spot; `Rush.restore_kept()` runs in
  `Game.load_game`. The Keeper's menu `main._keeper_menu` (when `Rush.available()`), best time in the profile stat `rush_best_ms`.
  Balance: `godot --headless --fixed-fps 60 --path . -- --test res://tests/bosstest.gd --bot --rush [--boss X] [--runs N] [--level N]`.
- New Game+ (v0.21): `Game.ng()` (state `ng`), `Game.area_scale(area)` (V12_BAL.AREA, raised to at least `NG_FLOOR` (the Vale) and by
  `NG_HP` / `NG_DMG` per cycle, not the village or the Trial) used by `enemy_stats` (health; XP by the health ratio, gold +50% a cycle)
  and `incoming` (damage); `Game.elite_chance()`; `Game.start_ng()` erases `NG_RESET` (q1-3, defeated, brann, toll, c2, picked) and
  keeps the rest; `main.start_ng()` (fade, village, banner) after `main._ng_confirm`.
- Skills (v0.6): `skills.gd` (spell/ultimate/talent data and numbers), `caster.gd` (child of the player: mana,
  casting, cooldowns, Battle Roar, mana potions, the four ultimates), `fx/spells.gd` (per-map node on the effects
  overlay: shots, lightning, tethers, meteors, pillars, ground blasts, the whirlwind vortex; feeds the light map).
  Talent effects and mana live in `game.gd` (`max_mp`, `talent`, `learn_talent`, `*_mul`); `Game.add_ult()` fills
  the meter. Save format v2 adds `mp`; `state.talents`, `state.slots`, `state.ult`, `state.mana_potions`,
  `state.gift_firewall` (old saves are migrated on load).
- `scripts/fx/`: `fx.gd` particles/rings/swings/shadows, `lighting.gd` light map, `atmos.gd` weather,
  `props_fx.gd` flames/lamps/sway, `loot.gd`, `compass.gd`, `game_camera.gd`, `tex.gd`
- `scripts/ui/`: `minimap.gd`, `world_map.gd`, `item_icon.gd`, `bar.gd`, `portrait.gd`, `notify.gd`, `credits.gd`
- HUD and menus: `hud.gd`, `touch_pad.gd`, `pause_menu.gd`, `menu.gd`, `shop.gd`, `dialogue.gd`, `boss_ui.gd`
- Data exported from the HTML game: `data/Maps/*.json`, `data/Tables/*.json`, `data/world_graph.json`

## Names (v0.22: the Shahnameh; v0.24: the Ember-bearer)
The texts use the Shahnameh's names; the ids in code, data and saves keep the old ones. id → name: village → Zabol; elder → Zal
(son of Sam, lord of Zabol); smith → Kavian the Smith (of Kaveh's house — Kaveh himself is the legend of chapter 3, Qaren is his
son); merchant → Sindokht of Kabul; alchemist → Rudabeh the Healer (Zal's wife, Rostam's mother); rostam → Rostam (the training);
siavash → Siavash (keeps the Trial of Embers); gordafarid → Gordafarid (keeps the bounty board); brann → the Shade of Jamshid (v0.25; he was "the Exile");
keeper → Sorush; hesk → Hom; boss → Arzhang the Div; boss2 → the King of Mazandaran; matriarch → the Sorceress (زنِ جادو);
arbiter → the White Div; ignarok → Puladvand; glaciertitan → Akvan the Div; ancientwyrm → the Dragon of Kashaf; toadking → Bid the
Div (titled the toad-shaped Div); anvilward → Pulad of Ghandi; captain → Ashkbus of Kushan; pahlavan (look) → Jahan-Pahlavan.
**The hero has no name of his own** (v0.24): he is *the Ember-bearer* (اخگردار), and the class is his calling
(`Game.HEROES`, `hero_name()` = "Ember-bearer", `hero_role()`, `hero_path()`): warrior Pahlavan (the way of Rostam), mage Sage
(the way of Zal), rogue Ayyar (the way of Gordafarid), paladin Oathbearer (the way of Siavash). The heroes of the Shahnameh are
people of Zabol, drawn from the heroes' sheets in their own colours (`world.gd HERO_NPCS`, skins `npc_*` in `MON_SKINS.json`).
`tools/shahnameh_names.py` and `tools/ember_bearer.py` hold the English and Persian replacements (run them on any text that
brings an old name back; the second skips chapter 3, whose Kaveh is the legend).

## Rostam's training (v0.24)
- `scripts/tutorial.gd` (`Game.Tut`, static): steps `"" → strike → heavy → roll → block → spell → done | skipped` in
  `Game.state.tut` = {step, hits, rolls, told}. `told` = the key of Rostam's last word (`hint_key()`): a new one puts a "!" over him. A hero from before v0.24 (tale begun, no `tut`) is "skipped". The objective and the compass
  point at Rostam only before the tale has begun; he offers the training while it has never been met, and asks to go on while a
  drill is in progress; afterwards (or after skipping) he gives a word for the fight ahead (`hint()`, by where the tale stands).
- `scripts/training.gd` (a node of the village world): the post (`strike()` from the player's swing, a small solid body) and the
  marked blows for the roll and the shield — real boss telegraphs (`world.bossfx.circle`), judged as they land (`dodge_iframes` or
  out of the ring; `blocking` inside it); they never hurt. The gift: 30 gold, two potions.
- The yard is at `training.gd POST` (530, 236), Rostam just north of it (village.json): open grass where the camera keeps the hero
  mid-screen. The pad makes the drilled button glow (`Tut.teaches()`); a skipped hero can still come back ("late").
- Main: `_talk_rostam` / `_rostam_offer` / `_rostam_pick`; Siavash opens the Trial (`_open_arena(who)`), Gordafarid the board
  (`_open_board(who)`). Test: `tests/tutorialtest.gd`.

## Chapter 3 (v0.23): the Chains of Damavand
- `scripts/chapter3.gd` (`Game.Ch3`, static) holds the story: steps `"" → jewels → forge → descend → bound → done` in
  `Game.state.c3` = {step, jewels {kondrow, temple, qaren}, banner, altars_lit, altars_done, qaren {met, kills, st}}, all the lines
  (EN/FA, table `L`), objective/compass/news/gates, Kaveh's and Qaren's talks, the Elder's epilogue, the quest log. It opens when
  `Ch2.step() == "done"`. Game hooks: objective, quest_target, elder_lines/has_news, boss_defeated (`on_boss`), enemy deaths
  (`on_kill`: serpentguard/serpentarcher for Qaren), exits (`exit_block`: peaks→damavand needs "jewels", damavand→zahhakcave
  "descend"), `caster.dmg_mul()` × `banner_mul()`. NG+ resets `c3`.
- Maps: `tools/ch3_maps.py` builds `damavand` and `zahhakcave` (and the exit from the peaks); their JSON has a `"ch3"` block
  (altars, chest, gate / anchors, lair). Data: `tools/ch3_data.py`. Art: `tools/ch3_art.py` (recoloured from the game's sprites; the
  serpent is drawn new). Zahhak's serpents and crown are drawn in code (`boss.gd _draw_zahhak`), the chains by the world
  (`world.gd _ch3_cave`).
- `scripts/altars.gd`: the fire temple (like `vault.gd`): `strike`/`element`/`shot_at` hooks from the player's swing, Ember
  Nova and the spells' shots.
- Zahhak's AI is `boss.gd _ai_zahhak` (bite lanes, venom pools, sword cone, chain lash wave, rockfall, serpents; a leash to the
  lair of 230/320/∞ px by phase). Balance: `bosstest.gd --bot --natural --boss zahhak --runs 4`.
- Main: `_talk_garen` gives Kaveh's chapter lines first when he has news, `_talk_qaren`, `_zahhak_bound` (the banner and Sorush's
  lines, only if the hero is still in the cave), `_chapter_end(3)` → `ending.open(3)`.

## Echoes, the small pad, the callings' moves (v0.25, v0.26)
- v0.25: the foes of chapter 1 are *echoes* of the ones Rostam slew (Zal's first task, Rostam's `r2` and hints in `tutorial.gd`);
  brann is *the Shade of Jamshid* (pale sprite in `world._npc`); `Tut.pad_open()` keeps the pad small in Zabol for a new hero
  (`state.pad_all` once he has left the village or passed level 1); the export builds armeabi-v7a too.
- v0.26: `Skills.SIG` (one move per calling) and `player.signature()` on the pad's "shove" button (cooldown in `shove_cd`);
  `ward_t` (the feather, checked first in `take_hit`), `fire_t` (the fire-walk, `_sig_step`), `_lasso`. `player.shove()` is kept
  for the tests and the keyboard-free paths that call it. Training step `sig` after `spell` (`training.on_sig`). `tests/sigtest.gd`.

## The playtest's fixes (v0.24)
- Camera: `game_camera.gd APRON` lets the view slide past the map's edges (fractions of the view: left 0.12, top 0.20, right 0.24,
  bottom 0.20 — the buttons are on the right and at the bottom); `world.gd _draw_apron` folds the ground out there and darkens it.
  `cam.frame(at)` / `unframe()` shift the view for the boss name card (works while paused).
- Arrivals (`main._safe_arrival`): foes within 450 px get `enemy.calm = 3.5` (not noticing; any hurt wakes them).
- `Game.sep()` is the mark between items: " · " in English, "، " in Persian ("·" reads as the Persian zero in this font).
- `tools/v24_text.py`: the text pass (pairs, then the ezafe/«·»/«باس» sweeps over every Persian string); `tests/texttest.gd` guards it.
- Victory: `Game.victory_at`; the achievement card waits 3.2 s after it; `main._on_victory` clears the message queue.
- Death panel: `story_btn` after a second fall to the same boss. Notify: messages keep to `notify.gd BAND` (the top strip between
  the hero's panel and the minimap).

## Playtesting (v0.23)
`tests/playtest.gd` plays the game from a JSON scenario through real touches (InputEventScreenTouch/Drag via
`Input.parse_input_event`, so the joystick, the buttons and menu taps go through the real paths). `tools/playtest/play.sh <tester>
<scenario.json> [WxH]` runs it under xvfb with an isolated `XDG_DATA_HOME` per tester (saves never mix) and one game at a time
(a lock). Steps, presets and the maps are in `tools/playtest/README.md`. `--playtest` leaves `Game.testing` off (elites roll, the real
profile is used). The fighting bot in it (`fight`) approaches, attacks, rolls from boss wind-ups, drinks under 35%, casts.
`tools/l10n_check.py` lists English text shown without Persian.

## Painted portraits (v0.28)
- Made with ChatGPT Images (Hooshaa): style Sunburst, 1:1, background Transparent, "improve prompt" off; Rostam's portrait
  (and one or two others) uploaded as style references; each prompt names a distinct headwear and ends with "visible
  painterly brushwork, not photographic ... transparent background, no text, no frame". Steam needs an AI disclosure.
- The chat hands the images over as WebP with alpha ~251 inside and coloured fringes. `art_src/clean.py <in> <out> x0 y0 x1 y1`
  (kept outside the project) makes the inside opaque, keeps the largest piece, erodes the fringe, crops the head and
  shoulders and scales to 512; `--soft` keeps soft alpha (Jamshid's smoke). Then save as WebP quality 90.
- Files: `assets/art/Portraits/<name>.webp`, imported lossy 0.9 with mipmaps (set in the .import files; without mipmaps a
  512 px face drawn at ~100 px shimmers).
- `Portrait.ART` maps the dialogue's sheet (or a hero of the tale's look, `npc_rostam`) to [file, facing]; facing 1 = the
  face turns to the viewer's right. `dialogue._render` mirrors the painting so the face turns toward the text.
- All eleven speakers are painted (Qaren since 0.28.1). Later candidates: the app icon, the store banner and title screen, boss cards.

## Painted sprites (v0.30)
- The AI cannot draw a consistent frame-by-frame animation, so it draws each character once: villagers as a turnaround
  (front, side facing right, back; 16:9, transparent) from a reference image = the old sprite's three views (for size and
  pose) + the portrait (for the design). Foes will be one view facing right.
- `python3 tools/sprite_sheet.py char <turnaround.png> assets/art/Npcs/<id>.png --height 138` cuts the views (by empty
  columns, or by shapes when a hammer or spear overlaps the next view), fits the tallest view to the height, puts the feet
  on the foot line, and makes walk0-3 (a hop with squash and sway; walk0 is also the idle frame) and the attack lean.
  `foe` mode makes a breathing loop for a foe sheet. Use a taller --height when a crown, halo or spear takes the top.
- Sheets are saved as 256-colour PNGs (`--full` keeps every colour). Old sheets and the AI originals are kept outside the
  project (art_src). Bosses done in 0.32 (`foe` mode; `--views 2` for the Sorceress's two forms, `--rage` for the
  phase-two row; all twelve bosses). The hero's twelve sheets came in 0.33: a fourth view (the strike) used for the
  side attack, a 160 px cell (`--cell 160x156`), and `make_hero_masks.py` PAINTED_RULES (per class, or per sheet when
  the cloth colour drifts with the gear). The 26 common foes came in 0.34 (see below).
- Foes (v0.34): one painted view facing right, 1:1, from a reference made of foes already painted (art_src/foes holds the
  originals and `build.sh`, the exact command for each sheet). `foe --calm` for a floating foe (no stride, a slow
  breath). Flyers are painted twice side by side (wings up, wings down) and built with `poses`: the two poses are lined up
  by their bodies (`--align gold` uses the golden parts when the wings cover the body) and become the frames (manifest
  `frames` 2, `timedMs` ~120-160). A cell may grow to fit a shape; keep the foot line `cellH - 6` and update `cellW`,
  `cellH`, `logicalW/H` and `pivot` in the manifest together. `tests/v34foeshots.gd --only <map>` shows them in play.

## Music (v0.31)
- The project records identify every soundtrack take as generated with Suno V6 through the Hoosha API. The masters (mp3)
  are kept outside the project (work/music). The repository metadata records a commercial-use claim, but this note alone
  does not prove that the API route/downloads were authorized under the terms in force on each generation date. Verify the
  Hoosha provider terms and the applicable Suno terms, retain account receipts, task IDs and source records, and do not
  rely on the commercial-use claim until that review is complete. `data/audio_credits.json` labels this status accordingly;
  `tools/build_audio.py` predates this and must not be re-run over it.
- Prompts: instrumental, Persian mode and instruments named, a BPM, and for anything that loops: "keep the same energy all
  the way through, no long silence, no fade-out ending". Battles: "no quiet intro". Suno makes two takes per prompt; both
  are used where they are good (`<key>_2.ogg` plays in turn).
- Level each take to its group (-18.5 LUFS places, -18 forge/cave/Trial, -17.5 battles) with a plain gain, cut the
  first 0.2 s of silence, encode Vorbis q2, 44.1 kHz.

## Delivering the project (v0.30)
- An upload to Claude takes at most about 30 MB a file, so the project goes out (and comes back in a new chat) as several
  zips: `python3 tools/pack_parts.py <project> <out_dir> Divslayer_vX_Y_Z --top Divslayer` (since 0.32: code, art and audio
  packed apart, under 24 MB a part, all into one folder `Divslayer`; PARTS.txt gives each part's content hash, so an
  update need only send the parts whose hash changed). Every part has the same top folder: extract all of them "here" into one place. PARTS.txt lists the
  parts. There is no limit on the whole project any more; the size players download (the APK) still matters.

## Tests (all must pass before a release)
```
godot --headless --fixed-fps 60 --path . -- --autotest
godot --headless --fixed-fps 60 --path . -- --test res://tests/uitest.gd      # 31 checks
godot --headless --fixed-fps 60 --path . -- --test res://tests/fxtest.gd      # 26 checks
godot --headless --fixed-fps 60 --path . -- --test res://tests/bosstest.gd    # 45 checks
godot --headless --fixed-fps 60 --path . -- --test res://tests/bosstest.gd --bot --runs 3   # balance bot
godot --headless --fixed-fps 60 --path . -- --test res://tests/perftest.gd
godot --headless --fixed-fps 60 --path . -- --test res://tests/skilltest.gd   # 70 checks (v0.6)
godot --headless --fixed-fps 60 --path . -- --test res://tests/blocktest.gd   # 29 checks (v0.7)
godot --headless --fixed-fps 60 --path . -- --test res://tests/stealthtest.gd   # 36 checks (v0.8)
godot --headless --fixed-fps 60 --path . -- --test res://tests/tolltest.gd   # 56 checks (v0.9)
godot --headless --fixed-fps 60 --path . -- --test res://tests/geartest.gd   # 50 checks (v0.10)
godot --headless --fixed-fps 60 --path . -- --test res://tests/alchemytest.gd   # 63 checks (v0.11)
godot --headless --fixed-fps 60 --path . -- --test res://tests/forgetest.gd   # 40 checks (v0.12)
godot --headless --fixed-fps 60 --path . -- --test res://tests/storytest.gd   # 44 checks (v0.13)
godot --headless --fixed-fps 60 --path . -- --test res://tests/difftest.gd   # 24 checks (v0.14)
godot --headless --fixed-fps 60 --path . -- --test res://tests/contracttest.gd   # 33 checks (v0.15)
godot --headless --fixed-fps 60 --path . -- --test res://tests/trialtest.gd   # 50 checks (v0.16)
godot --headless --fixed-fps 60 --path . -- --test res://tests/audiotest.gd   # 41 checks (v0.16.1 + v0.17)
godot --headless --fixed-fps 60 --path . -- --test res://tests/shrinetest.gd   # 70 checks (v0.18)
godot --headless --fixed-fps 60 --path . -- --test res://tests/chapter2test.gd   # 66 checks (v0.19)
godot --headless --fixed-fps 60 --path . -- --test res://tests/achtest.gd   # 43 checks (v0.20)
godot --headless --fixed-fps 60 --path . -- --test res://tests/rushtest.gd   # 36 checks (v0.21)
godot --headless --fixed-fps 60 --path . -- --test res://tests/chapter3test.gd   # 67 checks (v0.23)
godot --headless --fixed-fps 60 --path . -- --test res://tests/tutorialtest.gd   # 44 checks (v0.24: the Ember-bearer, Rostam's training)
godot --headless --fixed-fps 60 --path . -- --test res://tests/texttest.gd   # 10 checks (v0.24: names left behind, one Persian style)
godot --headless --fixed-fps 60 --path . -- --test res://tests/v24fixtest.gd   # 19 checks (v0.24: the playtest's fixes)
godot --headless --fixed-fps 60 --path . -- --test res://tests/v28portraittest.gd   # 16 checks (painted portraits, villager and hero sheets, music)
godot --headless --fixed-fps 60 --path . -- --test res://tests/bosstest.gd --bot --natural --boss zahhak --runs 4   # Zahhak
godot --headless --fixed-fps 60 --path . -- --test res://tests/bosstest.gd --bot --rush --runs 2   # the Boss Rush balance
godot --headless --path . -- --test res://tests/quittest.gd       # quitting at once must not crash (look for "signal 11")
godot --headless --fixed-fps 60 --path . -- --test res://tests/bosstest.gd --bot --boss ancientwyrm --runs 3   # also glaciertitan
tools/run_all_tests.sh normal          # every suite + the autotest -> /tmp/ei_tests/normal.log
tools/run_all_tests.sh guard tools/guardmalloc.so   # the same under the Android-like allocator
```
Screenshots: `tests/uishots.gd`, `tests/fxshots.gd`, `tests/bossshots.gd`, `tests/skillshots.gd`, `tests/shrineshots.gd`, `tests/ch2shots.gd`, `tests/v20shots.gd`, `tests/v21shots.gd`, `tests/v22shots.gd`, `tests/ch3shots.gd`, `tests/v24shots.gd`
(`--states` for moments in play, `--only a,b`) (need a real renderer:
`xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 854x400 -- --test res://tests/skillshots.gd --out DIR`).

## Android release
- Preset "Android": arm64-v8a and armeabi-v7a (one APK, about 65 MB with both; arm64 alone about 45 MB), `version/code` must go up every release, `permissions/vibrate=true`. Its `exclude_filter` must never name a file the game loads (v0.27: the Wyrm's sheet was left out and the boss was invisible on phones only; `tests/v27fixtest.gd` checks it). Test hooks (`--test`, `--autotest`, `--shots`, `--menushot`) work only in debug builds (`OS.is_debug_build()`).
- Saves, the profile and settings go through `Game.write_safe` / `read_safe`: a side `.tmp` file, then a rename; the last good file stays as `.bak`. Android Back opens the pause menu (`config/quit_on_go_back=false`, `main._notification`).
- **Retired test signing material:** The legacy `emberiron.p12`, `key.pem`, and `cert.pem` found in an older private project archive are exposed and must never be used again. The project owner confirmed on 18 November 2026 that no APK signed with this material was distributed to external testers or users. Do not copy these files into the repository or use them for QA or release builds.
- Export unsigned (`godot --headless --path . --export-release Android build/Divslayer_unsigned.apk`). Before the first external distribution, generate a **new production release key locally** on the owner's computer. Keep its password out of source files, shell history, workflow logs, and public documentation; store two encrypted/offline backups separately. Use the official Android `zipalign` and `apksigner` tools with password sources supplied only through a private local shell or a trusted secret manager. Never add the private key, certificate, password, or private export preset to GitHub.
- Once a build signed with the new production key is distributed, keep that same key for future updates. Do not use the retired test key or the custom `tools/apk_sign_v2.py` signer for production releases; use the official Godot/Android signing toolchain.

- Keep the APK under 30 MB (most of it is the Godot engine library); identical pictures are stored once
  (`map_object_sprites.json` → `"file"`). New PNGs: run `python3 tools/optimize_png.py assets/art` (lossless, checked pixel by pixel).
- The project zip for Milad must stay under 30 MB (his upload limit): v0.18 was about 23 MB, v0.19 about 26 MB, v0.20 and v0.21 about 26.5 MB.

### After the v0.26 panel
- `Game.is_echo(type)` reads `"echo": true` in `BOSS_CFG`: it changes the victory message and banner, and `boss._echo_look`
  draws the after-image (skipped at fx quality 0). A new echo boss needs only the flag and an "Echo of…" title.
- `Tut.drilling()` (not `active()`) is what the objective, `teaches()`, `target()` and the small pad ask: a drill is "on" only
  in Zabol and near the yard. `training.gd` sets `Tut.away` with hysteresis (300 out, 250 back).
- `training._say` clears the message bar first (`notify` is in the group "notify").
- `game_camera._corner_apron()` sets `limit_bottom` every physics frame; `_apply_zoom` only sets the base value.
- `boss_ui._banner_clear()` keeps a banner below the message bar's panel.
- Chapter 2's premise is **seals**, not wardens; do not bring "warden/پاسدار" back for the three foes of chapter 1.

## Audio (v0.17)
- `assets/audio/music/<key>.ogg` — one track per region (`title village forest dungeon peaks shadowfen sanctum emberforge
  camp trial boss shrine`; every `shrine_*` map plays `shrine`). `Music.track_key()` picks it; the boss theme while
  `Music.boss`. Three decks (`Music.decks`) crossfade with equal-power fades (2.4 s, 0.9 s into a boss fight); a track starts
  over `TAIL` (4.5 s) before its end on another deck, so its end crossfades into its start (the trimmed tracks also have a
  4 s fade-out). A track you leave is resumed where it was if you come back within 150 s (after a boss fight, a quick visit).
  A region without a file falls back to the old generative tune (`PATTERNS`), which now plays on its own reverb bus.
- `assets/audio/amb/<name>.ogg` — crickets, wind, birds, fire, cave, water (looping; every loop was re-cut by the build script so
  its end runs into its start without a click). Rain stays synthesised. `atmos.gd` `sound()` decides what plays (map, hour,
  weather) and runs whatever the graphics setting.
- `assets/audio/sfx/<sound>_<n>.ogg` — the variations of each recorded sound (`Sfx.FILE_SOUNDS`), found by name at start-up.
  `Sfx.play()` picks one at random (never the same twice in a row), with a per-sound gain (`GAIN`), pitch (`PITCH`), optional
  synthesised layer (`LAYER`) and cooldown (`COOLDOWN`, so a pack of wolves growls once). Footsteps: `Sfx.step(map_key, quiet)`
  from `player._footsteps` on the map's ground (`GROUND`). The synthesised sounds stay for the magic, the heartbeat, the kill
  pop and as a fallback.
- Buses: `SFX` (effects, and `Ambience` sends to it, so "Sound volume" covers the ambience), `Music` (tracks), `MusicSynth`
  (the generative tune, with reverb, into Music), a hard limiter on Master. Settings `mvol` / `svol` (0 quiet, 1 normal, 2 loud).
- **Levels.** Tracks are loudness-matched (EBU R128: -19 LUFS, the crypt drone -23, the boss -17, the shrine -22), the ambience
  -26 to -30 LUFS. The sound effects are peak-normalised and then set by `Sfx.GAIN`, measured so a recording sits about 3 dB above
  the synthesised sound it replaces (loudest 150 ms RMS of each; the measuring script ports the synth to numpy).
- **Rebuild** (needs ffmpeg with libvorbis; ~1.5 min): get the sources, then run the script, then import.
  ```
  git clone --depth 1 --filter=blob:none --no-checkout https://github.com/ETdoFresh/kenney.nl.git kenney
  cd kenney && for d in kenney_rpgaudio kenney_impactsounds kenney_interfacesounds kenney_uiaudio kenney_musicjingles; do git checkout HEAD -- $d; done
  git clone --depth 1 https://github.com/Daddy-Ousen/innworld-rpg.git innworld     # its game/assets/audio keeps the OpenGameArt files
  python3 tools/build_audio.py --kenney kenney --innworld innworld/game/assets/audio
  godot --headless --path . --import
  ```
  (check out the Kenney packs one at a time: several at once ran out of memory.) The script writes `assets/audio/CREDITS.md`,
  `assets/audio/licenses/` and `data/audio_credits.json` (shown in Settings → Credits).
- **Licences and rights status.** The CC0 notices in this section apply only to the identified Kenney/OpenGameArt
  ambience and sound-effect sources; do not infer that the soundtrack is CC0. The current 30-track Suno V6 / Hoosha API
  soundtrack has a separate, unverified commercial-use claim documented in the Music (v0.31) section above and in
  `data/audio_credits.json`. Keep those sources separate and verify each provider term, account entitlement, API route,
  download authorization and production record before commercial distribution. Do not rerun the legacy
  `tools/build_audio.py` over the current soundtrack metadata.
- Encoding pitfalls: ffmpeg ignores a negative `-q:a` for libvorbis (it silently falls back to 128 kb/s); `-ac 1` mixes stereo to
  mono at -3 dB per side, so in-phase material comes out +3 dB hot — downmix with `pan` inside the filter chain instead; `alimiter`
  delays the signal by its attack unless `latency=true` (that broke the loops). Music is 32 kHz q0 (Vorbis cuts above ~15 kHz at q0
  anyway): about 7 MB for 20 minutes.
- Tests under `--fixed-fps` run frames faster than real time: the fades follow game time (wait frames), the playback position
  follows the mixer's real time (wait real seconds). See `tests/audiotest.gd`.

## Android-only crashes (how the v0.16.1 audio crash was found)
1. Read the Build ID in the tombstone/backtrace and compare it with the template: `llvm-readelf -n lib/arm64-v8a/libgodot_android.so`
   inside `android_release.apk` from the export templates. Official 4.6.2 release template = `a1dc416352711900`.
2. Download the official symbols for that exact version from the GitHub release:
   `Godot_native_debug_symbols.4.6.2.stable.template_release.android.zip` (about 770 MB; arm64 = `arm64-v8a/libgodot_android.so`).
3. Symbolise the `pc` offsets of the frames in `libgodot_android.so`:
   `llvm-symbolizer --obj=arm64-v8a/libgodot_android.so --inlining --demangle -p 0x2afe1e0 0x306ca2c ...`
   (or `ndk-stack -sym arm64-v8a/ -dump crash.txt`, with a line of asterisks first in crash.txt).
4. Reproduce on Linux: Android's allocator (Scudo) puts blocks above 64 KiB right before a guard page, glibc does not, so a read
   one byte past a big buffer crashes only on the phone. `tools/guardmalloc.c` copies that behaviour:
   `gcc -O2 -shared -fPIC -o tools/guardmalloc.so tools/guardmalloc.c -ldl -lpthread`, then
   `LD_PRELOAD=tools/guardmalloc.so godot --headless --path . -- --test res://tests/<suite>.gd`.
   Run the suites under it before a release. (tools/ is excluded from the export.)
5. Rules learned: `AudioStreamWAV.loop_end` is the LAST frame played (frames - 1), not one past it. In 4.6 `AudioStreamWAV.data` is a
   `TightLocalVector` (exact size, no slack), so any off-by-one in sample positions reads outside the allocation.

## Making a map (v0.19)
The HTML game's grounds were drawn in code (tiles, strokes, paths), so new ones can be painted the same way: `tools/ch2_maps.py`
builds a map from a layout (paths, clearings, a rock grid for caves), places the game's own map-object sprites (walls from the
footprints in `FOOT`, measured on the HTML maps), and paints the ground at twice the map size. A boss needs `ENEMY_TYPES`,
`V12_BAL.BOSS`, `Game.BOSS_CFG`, art in `art_manifest.json`, and an AI in `boss.gd` (or it gets the generic kit). Look at the result
with `map_preview.py` (walls red, exits green, spawns magenta) and in the game with a screenshot script (`tests/ch2shots.gd`).

## Godot pitfalls met so far
- A freed object compares `== null`: use `is_instance_valid()`.
- `:=` cannot infer from Variant expressions; type them (`var x: float = ...`).
- Lambdas capture by value; use bound methods.
- A Theme on a window does not reach Controls under a CanvasLayer: the kit is merged into the default theme.
- Engine.time_scale (hit-stop) also slows physics.
- Headless input in tests: `get_viewport().push_input(ev, true)`.
- Headless runs without `--fixed-fps` give many process frames per physics frame: wait on `physics_frame` in tests
  and screenshot scripts when timing gameplay.
- GDScript: calling a method on a freed object from a test can crash the engine outright (signal 11), not just error — in
  chapter2test an allowed exit started the trip to another map and freed the world the test still held. Hold the trip back.
- `--check-only --script` cannot see autoloads ("Identifier not found: Game"); filter those lines out and read the rest, which
  catches real parse errors (a name declared twice, `:=` from an untyped call).
- (v0.21) Never run two test processes at once: they share `user://save.json` and the test profile, and one breaks the other.
  Every test run starts from an empty test profile (`main._ready` resets it), so no look worn by an earlier suite changes the next.
- (v0.21) Checks must not assume what a random roll gives (a shrine's treasure can be an amulet of health that is put on at once,
  an elite can drop a second item): count from after the roll, or test "at least".
- A Button does not grow with child controls: for cards that must fit their text use a PanelContainer with a
  flat, empty-styled Button as its last child (see the talent cards).

## Not done yet
- The hero looks have no capes (MON_SKINS "cape"): a cape on these sprites would need drawing per frame.
- New Game+ has no story of its own yet (the same tale, tougher).
- Zahhak is not in the Boss Rush (it stays the seven of chapters 1–2).
- Chapter 3 borrows music (no CC0 Persian tracks could be fetched here).
- (seen in 0.29) The calling cards overflow at 854x400 in English: the second calling move sits below the card and touches
  the buttons (Persian fits). A smaller description font or a taller card at small sizes would fix it.
- Testing on real phones (GPU cost of lighting on weak phones; "Graphics: Light" exists for them).
- Store release (Myket / Cafe Bazaar), a smaller custom export template.

## Painted maps (v0.35)
- Ground: `data/terrain.json` names the textures (file, units a tile covers, gain) and each map's base / r (path) / g
  (paving) / b (second ground) plus sat, edges, rough. `python3 tools/terrain.py texture <painting> <name> --units N`
  makes a painting seamless and installs it (set mipmaps on in its .import); `splat <map>` reads the old picture kept in
  art_src/old_ground (add a RECIPES entry per map); `bake <map>` redraws the minimap picture.
- Objects: paint sheets of separate props (transparent), `props_art.py split <sheet> <name> <n>`, then list in
  art_src/props/<region>.json which piece replaces which old object (`like` gives height and base) and run
  `props_art.py region <spec>`. `tests/v35mapshots.gd --only <map>` to look.
