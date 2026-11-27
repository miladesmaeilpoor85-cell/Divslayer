# Ember & Iron — the playtest kit

You play the game **as a phone player does**: by touch. Each run starts the game from a scenario file (a JSON list of
steps), plays it, and keeps what the player saw: screenshots, the text on screen, the hero's state and a log.

```
tools/playtest/play.sh <your-name> <scenario.json> [WxH]
```
(Linux with Godot 4.6 on the PATH and xvfb-run. Runs and saves go to `$PLAYTEST_HOME`, default `/tmp/ember_playtest`.
The runner is `tests/playtest.gd`; `--playtest` keeps the game as a player gets it.)
- `<your-name>`: `gamer` or `critic`. Your saves/profile live in `data/<your-name>/`, your runs in `runs/<your-name>/NNN/`.
  Your save carries over between runs (use `{"do":"continue"}` to pick up where the last run saved).
- `WxH`: the phone screen, landscape. `1600x720` (default) is a 20:9 phone — use it for screenshots you will judge.
  `1067x480` is the same phone at lower pixel density — use it for long fights (much faster). `854x400` = the game's
  own layout size.
- Only one game runs at a time on this machine (two cores): `play.sh` waits for its turn. A run of N seconds of play
  takes roughly 2–5×N seconds of real time plus ~12 s to start. Keep scenarios focused (a few minutes of play each).
- Output: `$PLAYTEST_HOME/runs/<you>/NNN/log.txt` (every step and its result, the text on screen at each screenshot),
  `runs/<you>/NNN/shots/*.png` (look at them with the Read tool), `errors.txt` (engine errors, if any).

## Steps
```
{"do":"menu"}                                  the title screen (tap your way in with tap_text)
{"do":"new","class":"warrior"}                 a new hero, skipping the menu (warrior | mage | rogue | paladin)
{"do":"continue"}                              load your save
{"do":"preset","name":"act1","class":"mage"}   a hero at a point of the story (see Presets)
{"do":"lang","v":"fa"}                         fa (default, the game's main market) | en
{"do":"tap","x":800,"y":360}                   a finger tap at window pixels (or "fx","fy" 0..1 of the screen)
{"do":"tap_text","text":"بازی تازه"}           tap the visible button/label whose text contains this
{"do":"drag","from":[x,y],"to":[x,y],"sec":0.4} a swipe (lists do NOT scroll by dragging here: Godot drag-scrolls only on a
                                               real touch screen — use "scroll")
{"do":"scroll","fx":0.6,"fy":0.5,"dir":"down","n":4}  scroll the list under that point
{"do":"stick","dir":[1,0],"sec":2}             hold the joystick (x right, y down) for sec
{"do":"walk_to","x":600,"y":400,"max_sec":15}  steer with the joystick to a map point
{"do":"walk_to_npc","id":"elder"}              steer to a villager
{"do":"walk_to_exit","to":"forest"}            steer into the exit to that map
{"do":"button","id":"attack","hold":0.1}       a touch button: attack dodge block potion skill1 skill2 ult sneak shove talk scroll
                                               (shove = the calling's own move: lasso / feather / arrow / fire-walk)
                                               (hold attack ~0.8 s = heavy blow; block is held for "hold")
{"do":"talk"}                                  Talk (a villager must be near), then read every page
{"do":"dialog_all"}                            tap through an open dialogue
{"do":"fight","sec":40,"shots_every":10}       fight like a decent phone player (approach, attack, roll from boss wind-ups,
                                               potion under 35% HP, a spell every few seconds, the ultimate when ready)
                                               until the area is clear, the hero falls, or sec runs out. Reports foes down,
                                               damage taken, lowest HP, potions, rolls, swings/hits.
{"do":"wait","sec":1.5}
{"do":"shot","name":"village"}                 a screenshot + the text on screen (in the log)
{"do":"burst","name":"combo","n":6,"every":0.2} a contact sheet of n frames (motion, effects, animation)
{"do":"state"}                                 hero, map, foes near, exits, open panels, the objective (JSON)
{"do":"save"}
```
Test shortcuts (say in your report when you used them; a real player cannot):
```
{"do":"goto","map":"dungeon","x":663,"y":764}  move to a map point at once
{"do":"invuln","v":true}                       the hero cannot be hurt
{"do":"set","key":"gold","v":500}              set a saved value (gold, potions, level, weapon 0..6, armor 0..5)
{"do":"setting","key":"ui","v":2}              a setting: ui (0 small, 1 normal, 2 large), cam (0..2), fx (0..2), shake, haptics
```

## Presets (the hero at a point of the story)
| name | level | gear (weapon/armour) | story |
|---|---|---|---|
| start | 1 | 1/0 | nothing done (Rostam offers his training in the yard north-east of the fountain) |
| act1 | 4 | 2/1 | quest 1 given: defeat Arzhang the Div in the Sunken Crypt (dungeon) |
| act2 | 8 | 3/2 | Arzhang down; quest 2: the King of Mazandaran in the Ashen Peaks |
| act3 | 12 | 4/3 | quest 3: the Sorceress in the Shadowfen |
| ch2 | 16 | 5/4 | the first three quests done: chapter 2 begins (talk to Zal) |
| ch3 | 18 | 6/5 | chapter 3 under way: find the banner's three jewels on Damavand (talk to Kavian the Smith, then Qaren) |
| endgame | 22 | 6/5 | everything done: the Boss Rush and New Game+ (Sorush, in the sanctum) |

## The world
Maps and their exits:
- village (Zabol, the hub; NPCs: elder = Zal, smith = Kavian the Smith, merchant = Sindokht of Kabul, alchemist = Rudabeh
  the Healer, brann = Jamshid, rostam = Rostam (the training, by the post near 530,236), siavash = Siavash (the Trial),
  gordafarid = Gordafarid (the bounties); the Bounty Board, the Trial arena, a fountain that heals) → forest, shrine_shadows
- forest → village, dungeon, peaks, camp, shrine_embers
- dungeon (Sunken Crypt; boss Arzhang, near 663,764) → forest
- peaks (Ashen Peaks; boss King of Mazandaran, near 373,234) → forest, shadowfen, sanctum
- shadowfen (bog; Bid the Div and the Sorceress, near 473,234) → peaks
- camp (bandit camp; Ashkbus) → forest
- sanctum (Crystal Sanctum; the White Div near 413,254; NPC keeper = Sorush) → peaks, frostvale, wyrmhollow
- emberforge (Puladvand near 433,264; Pulad of Ghandi) — through a door in the peaks
- frostvale (Akvan the Div near 951,602; NPC hesk = Hom) → sanctum
- wyrmhollow (the Dragon of Kashaf near 428,939) → sanctum
- damavand (the Slopes of Damavand, east of the peaks; NPC qaren = Qaren; Kondrow near 320,260; the fire temple near
  1145,830; the Gate north) → peaks, zahhakcave
- zahhakcave (the Cave of Chains; Zahhak near 600,770) → damavand
- seven puzzle shrines (shrine_*), the trial arena (trial)

The hero is the Ember-bearer (no name of his own); the class is his calling: warrior = Pahlavan (tank, heavy blows), mage =
Sage (spells), rogue = Ayyar (fast, backstabs, stealth), paladin = Oathbearer (shield, holy). Presets after `start` count
Rostam's training as done.

## The fighting bot is a decent player, not a good one
It reads about three in four marked attacks in time and steps or rolls out of them, drinks under 35%, casts now and then.
It does not use the bosses' own weaknesses (break Arzhang's pillars, bait charges into walls, burn the Sorceress's eggs),
does not block or parry. A loss by the bot says "hard for an average player", not "impossible". Play the key fights by hand
(stick/button steps) as well when you judge difficulty.

## What this kit cannot tell you (say so instead of guessing)
- The feel of a real touch screen: latency, thumb reach on a real phone, haptics, holding the phone for an hour.
- Real performance: the cloud renders in software; FPS here says nothing about a phone.
- Sound and music (no audio here) — judge only from what you can read about them.
Everything else — what the screen shows, how readable it is, how the fights go, the numbers, the words, the flow,
the first five minutes — you can test for real.

## Things that catch testers out
- `preset` writes over your save: a later `continue` loads the preset's hero, not the one you started with `new` or `menu`.
- Settings (`setting`, or changed in the game's menu) stay in your profile for later runs — set them back at the end of a run.

### Fresh-game journey to Zal (Persian UI)

After importing the project with Godot 4.7.2, run `tools/playtest/zal_journey.sh` (optional first argument: random seed, default 705). Each run gets its own temporary profile. The runner taps New Game, chooses the default warrior, follows visible objective changes and records the first death, unexpected modal or stalled objective. It sends ordinary touch events. Its observations use UI nodes, projected character artwork and the compass, so this is a semantic UI test. It does not require OCR. It never teleports the player or gifts health, equipment or experience.

On the chapter build the goal is Zal's reward conversation and the resulting objective change. On a build with the Zabol memorial the goal is the visible lantern handoff acknowledgement. The evidence folder printed at startup contains `journey.json` (result, milestones, on-screen text and final diagnostic state), `touches.jsonl` (finger, coordinates and frame for each touch or drag), and `log.txt`. Display runs also capture checkpoint images. Headless runs omit image capture. Exit code 1 denotes a blocked journey; it is evidence to investigate, not a diagnosis of a game defect.
