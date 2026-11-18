# Divslayer / دیوکش (Godot; formerly Ember & Iron) — changes

## 0.36.0 — Controls for every hand (کنترل برای هر دست)
- Added an optional left-handed touch layout. The action buttons mirror to the left side and the movement joystick responds on the right half of the screen; the original right-handed layout remains the default.
- The setting is available both before starting a game and from the in-game pause menu, is saved separately from the character save, and updates the control hints.
- Automated touch tests cover both movement zones and a mirrored action button.

## 0.35.0 — Painted ground (زمینِ نقاشی‌شده): Zabol, the forest, the camp
The maps were one baked, blurry picture each (2 px a map unit; a phone shows about 3) and cartoon vector props, with
European timber houses in Zabol. The green region is repainted; the other regions follow the same way.
- **Painted terrain** (`scripts/fx/terrain.gd`, `terrain.gdshader`, `data/terrain.json`): four AI-painted tileable textures
  (meadow, earth path, village cobbles, forest floor) tiled across the map and mixed by a small splat map read from the old
  ground picture, so paths, plazas, walls, exits and spawns are exactly where they were. Noise-broken edges, two offset
  samples a texture and a large mottling hide the tiling; sharp at any zoom. Light graphics reads half as many samples.
  `tools/terrain.py` (texture: makes a painting seamless; splat; bake). The old ground pictures now only feed the minimap
  and the world map, rebaked at 1 px a unit (about 4 MB smaller).
- **Painted objects** (`tools/props_art.py region`, `art_src/props/green.json`): plane trees, oaks, pomegranates, cypresses,
  pines, bushes, mossy rocks, a stump; Persian mud-brick houses (one with a windcatcher, one domed), Kaveh's brick forge,
  lantern posts, clay jars, a fruit stall, hay, fences, anvil, weapon rack, cauldron, tents, campfires, signposts; in the
  camp Turanian yurts, the chieftain's tent, wolf banners, iron torches, bones, loot and a palisade of stakes. Each keeps
  the old object's height and base, so layouts and collisions are unchanged. Region-only pictures (`g_…`): the snow, fire
  and cave maps keep theirs until their turn. Trees, bushes and rocks placed many times face either way.
- Flames, lantern glow and chimney smoke follow the paintings (`fx_at`, `fx_s`, `smoke_at` in map_object_sprites.json).
- Over painted ground the map edge fades with no drawn seam.
- 48 unused old pictures left the project (kept in art_src/old_props).
- Tests: `green_region_painted`; `tests/v35mapshots.gd` photographs the maps.

## 0.34.0 — Foes of the Shahnameh (دشمن‌های شاهنامه)
Half the common foes were western fantasy (a slime, skeletons, a mosquito, a crystal spider, stone and magma golems) and
all of them were placeholder drawings. Every one of the 26 now comes from the Shahnameh and is painted like the bosses.
- **A new roster, each with its source**: the Boar of Arman (the boars Bijan slew), the Sorcerer and the Div of Mazandaran
  and the Archer of Mazandaran, the Eagle of Kavus (the eagles of the flying throne), the Raging White Elephant (felled by
  the young Rostam), the Sorcerous Pari, the Swamp Nahang, the Swamp Div, the Ember Leopard, the Brick-Hurling Div and
  the Bellows Div (the divs of Jamshid's forge), the Stone of Hushang, Bazur's Hail, the Frozen Soldier, the Lion and the
  Wolf of the Seven Labours, the Ice Div, the Turanian Sorcerer, the Turanian Raider and Archer, and Zahhak's guards,
  archers and serpents. The Ember Imp and the Wyrmling keep their names in new paintings; the Will-o-Wisp is now the
  Spark of Ahriman. Names change in both languages (`ENEMY_TYPES`, `V12_ENEMY`, the strings); Ashkbus is "Chief of the
  Turanian Raiders". Hom's wolf quest is untouched: the wolves are still wolves.
- **Same fights**: each painting keeps the old foe's height in its cell, and the hit boxes are unchanged. A few cells grew
  to fit the new shape (the elephant, the frozen soldier, the leopard, the lion, the wolf, the boar, the eagle, the pari, the
  nahang, the Turanian archer, Zahhak's guard and archer; manifest `cellW`/`cellH` and pivots updated).
- **Motion**: the walkers stride (the boar and the nahang had a single still frame and now walk); the floating sorcerers
  and the hail breathe slowly instead of striding (`sprite_sheet.py foe --calm`); the eagle, the pari and the Bellows Div
  were painted twice (wings up, wings down) and flap: `sprite_sheet.py poses` lines the two poses up by the body (or by
  the golden parts, `--align gold`, when the wings hide it) and makes them the frames.
- **Sound and sparks**: the boar, the nahang, the lion and the elephant growl; the eagle and the serpent no longer chitter
  like beetles; the elephant and the divs of flesh no longer clang like metal when struck (`ARMORED`); the sparks and
  debris of each foe take its new colours.
- The bandits and Zahhak's men had six near-identical rows the game never showed; they have one now.
- The four forge foes showed their English names in Persian; fixed, and a test makes sure every foe has a Persian name.
- Credits and the store page say the foes are AI-made too; the store page lists the foes' Shahnameh sources.
- Tests: `foe_sheets_painted` (every foe's sheet matches its manifest and ships); `tests/v34foeshots.gd` screenshots the
  foes in their own lands.

## 0.33.0 — The sell-sword (مزدور)
The hero was the last placeholder: a round cartoon boy with a red headband. He is now the nameless sell-sword of the
story, painted in all twelve of his sheets (four callings, three tiers of gear each), with one face across all of them.
- **Twelve hero sheets**: the Pahlavan (red tunic, then lamellar and a lasso, then dark steel and a red cloak), the Sage
  (blue robe, staff with an amber stone, then a staff crowned with a Simorgh feather), the Ayyar (olive, moss, then forest
  green cloak over leather that darkens to black) and the Oathbearer (gold surcoat over steel, sword and round shield).
- **A real attack pose**: each painting has a fourth view, the hero striking side-on (a slash, a cast with fire at the
  staff, a low dagger lunge, a shield-forward cut). `tools/sprite_sheet.py char` uses it for the side attack column at the
  same scale as his other views; the down and up attacks stay a lean.
- **A wider cell**: the strike reaches out, so the hero cell is 160 px wide instead of 120 (manifest `cellW`), and the
  face crop for portraits keeps the old measure (`portrait.gd`), so the HUD and dialogue faces are framed as before.
- **The looks still work**: `tools/make_hero_masks.py` has measured cloth colours for the painted sheets (the sage's navy,
  the ayyar's three greens one window per sheet so his black leather stays black, the oathbearer's mustard gold and
  neutral steel), and leaves the big painted heads alone (hair, the scar, the starter oathbearer's headband).
- Credits and the store text name the hero as AI-made too.

## 0.32.1 — Puladvand (پولادوند)
- The twelfth boss painted: Puladvand, the First Flame. A boss with several phases now takes the row of each phase
  (see 0.32.0, which this completes).

## 0.32.0 — The divs of the tale (دیوهای داستان)
The bosses looked like placeholders (Arzhang a black knight, the White Div a lump of crystal, Zahhak without his
serpents). All twelve are now painted as the Shahnameh draws them.
- **New boss sheets**: Arzhang the Div, the King of Mazandaran (half turned to stone), the Sorceress, Bid the Div (the
  toad), Ashkbus of Kushan, the White Div, Akvan the Div, the Dragon of Kashaf, Puladvand (an iron div with the First Flame
  burning through his seams), Pulad of Ghandi, Kondrow and Zahhak (with the serpents on his shoulders), plus the White Div's ice twins (the game tints them). Each is one painted view;
  `tools/sprite_sheet.py foe` makes a striding loop around the feet and keeps the old height in the cell, so nothing
  changes in play (the hit boxes are the same).
- **The Sorceress shows her true face**: her painting has two forms; the sheet's first row is the veiled beauty, the second
  the hag, and the game already switches rows when her fight turns (`--views 2`).
- **Every boss has a second-phase look**: the row the game switches to in the later phase is the same boss with hotter
  colours and a glowing rim (`--rage fire`; frost for the White Div and Akvan, shadow for Zahhak and Kondrow). Bosses that had
  one row now have two; the White Div stands on the ground instead of floating. A boss with more phases than one switch
  takes the row of his phase when the sheet has it (`boss.set_variant(ph - 1)`; before, every phase showed row 1).
- Credits and the store text say the bosses are AI-made too. `tests/v32bossshots.gd` screenshots every boss, calm and in
  his later phase.

## 0.31.0 — A Persian score (موسیقیِ ایرانی)
Every track in the game is now its own: 30 instrumental takes made with Suno V6 through the Hoosha API, in Persian
modes and instruments (ney, kamancheh, tar, setar, santur, daf, tombak, zarb, sorna, karnay). Project production records
claim commercial-use rights, but the repository does not independently verify the applicable account status, API
authorization, or permitted-download route. Verify those records and the provider terms before commercial distribution;
commercial-use permission does not itself guarantee copyright protection. The borrowed CC0 tracks are gone; ambience
and sound effects remain identified as CC0 in the project metadata.
- **A track for every place**: the title, Zabol, the Whispering Forest, the Sunken Crypt, the Ashen Peaks, the Shadowfen,
  the Thornwood camp, the Ember Forge, the Crystal Sanctum, the Hoarfrost Vale, the Wyrm's Hollow, Damavand, the Cave of
  Chains, the Trial of Embers and the shrines. Damavand, Zahhak's cave and Zahhak's fight had borrowed other tracks; not
  any more.
- **Battles**: one battle theme for the bosses of chapter 1 and a second take for those of chapters 2 and 3
  (`Music.TRACK_ALIAS`), and their own themes for the Dragon of Kashaf and for Zahhak.
- **Two takes in turn**: a place with a second take (`<key>_2.ogg`) plays the two one after the other, a loop each
  (`Music._take`), so a long stay does not repeat one track.
- **The end card has music** (`Music.set_moment("ending")`): the second take of the main theme, until Continue.
- Levels: every take measured and set to -18.5 LUFS (places), -18 (forge, cave, Trial) or -17.5 (battles), so a change of
  place never jumps in loudness. Encoded at Vorbis q2 (about 96 kb/s): 30 tracks in 56 MB.
- Credits list the game's own music first; the audio test accepts a Suno track (no URL, "Suno" licence). New checks: the
  end card's music, and two takes in turn.

## 0.30.0 — The people of the tale (اهالیِ داستان)
The villagers looked like placeholders: a bald Zal (his hair was white from birth), Rostam and Siavash in the hero's own
sheet. All eleven now walk the world as themselves, in the design of their painted portraits.
- **Eleven new sheets**: Zal, Sindokht, Rudabeh, Kavian, the Shade of Jamshid, Sorush, Hom, Qaren, Rostam, Siavash and
  Gordafarid. Each was painted once by ChatGPT Images as a turnaround (front, side, back); `tools/sprite_sheet.py` cuts the
  views and makes the motion (a walk that hops with a little squash and sway, a lean for the attack column), keeps the old
  height in the cell, and saves a 256-colour sheet (about a quarter of the size, no visible loss at sprite size).
- **Rostam, Siavash and Gordafarid have sheets of their own** (`Npcs/rostam.png` …) instead of a calling's sheet in their
  colours; `world._npc` falls back to the old way for a hero of the tale without one. Rostam still stands a head taller.
- Credits and the store text say the people of the tale are AI-made too.
- `tests/v28portraittest.gd`: every villager sheet exists, is 600×468 and ships on Android; every hero of the tale has his
  own sheet. `tests/tutorialtest.gd` accepts Rostam's own sheet.

## 0.29.0 — No hero (قهرمان نیستی)
Sales first: a name that says what the game is, an icon that sells it, and a hero who is not the chosen one.
- **The name** is now «دیوکُش» / Divslayer (title screen, the phone's app name, the end card, the privacy policy). The
  Android package id stays `ir.emberiron.game`: the game is not published yet, players never see it, and changing it would
  wipe the saves of everyone testing on a phone. On a PC the editor keeps saves per project name, so old PC saves stay under
  "Ember & Iron".
- **The icon**: a painted iron gauntlet clenching a burning ember on lapis blue (made with ChatGPT Images); Android gets the
  legacy 192 px icon and an adaptive icon (painting as the background layer), `icon.png` is the same painting.
- **An anti-hero, not a chosen one** (text only, about a dozen lines; no change to play):
  - Zal: the tale said the ember would seek a hero of royal blood; it found a sell-sword, and every echo can smell it on him.
  - Rostam meets "the sell-sword the ember stuck to". The calling screen: "You are no hero — choose your calling" (in Persian: "the ember just fell to you").
  - Rewards are wages ("Zabol pays its debts"); the bards sing of Rostam, not of you; Kavian's banner was "meant for hands
    like yours" because Kaveh was a smith, not a king; Zabol knows whom to call "and what it costs".
  - The last end card: "The poets will sing of Rostam; of you, no one. You were paid."


## 0.28.1 — Qaren's face (چهرهٔ قارن)
- Qaren, son of Kaveh, has his painted portrait (`assets/art/Portraits/qaren.webp`): all eleven people you talk to are
  painted now. `tests/v28portraittest.gd` checks the fallback with a sheet that has no painting instead.

## 0.28.0 — Faces of the tale (چهره‌های داستان)
The first art pass: the people you talk to have painted faces now. Ten portraits in one painted style (Qajar and
Persian-miniature inspired, lapis, ivory and gold), made with ChatGPT Images from the studio's prompts, cleaned and fitted here.
- **Dialogue portraits**: Zal, Sindokht, Rudabeh, the Shade of Jamshid, Sorush, Hom, Kavian the smith, Rostam, Siavash and Gordafarid
  show their painting in the dialogue box (`Portrait.ART` in `scripts/ui/portrait.gd`). Qaren keeps his sprite face until
  his painting is made; any speaker without a painting falls back the same way.
- **The face turns toward the text**: the portrait sits on the right in Persian and on the left in English; a painting is
  mirrored when it would look away from the words.
- **The frame grew** from 88 to 98 px (the panel's inner height is about 100), drawn with mipmaps so it stays clean on small
  screens. Jamshid's old blue tint is not laid over his painting, which is a shade already.
- **Size**: the portraits ship as 512 px WebP (about 850 KB for all ten).
- **Credits** name the portraits as AI-made (Steam asks for this on the store page too).
- `tests/v28portraittest.gd`: every file exists, ships on Android and has mipmaps; every speaker shows his painting; Qaren
  keeps his sprite; the faces turn toward the text in both languages; the frame fits the panel; the HUD's hero portrait is
  untouched.

## 0.27.1 — Side roads (راه‌های فرعی)
The studio's second pass: every shrine and side quest played, and the bosses nobody had measured.
- **Bosses measured with the fighting bot** (Pahlavan and Sage, talent points spent): Akvan, Puladvand and Kondrow are
  fair as they are (both callings win with 21-71% health left). Zahhak at x6.5 is now a close final fight (the Pahlavan
  wins with 19% left, the Sage loses with Zahhak at 10%). The Dragon of Kashaf x10 -> x6.3: at x8.2 both callings still lost
  with a quarter of its health left.
- **Shrines**: six of seven solved by hand on the phone layout (Shadows, Embers, Weight, Tides, Light, Echoes), each with its
  reward, sigil and way out, no script errors. The Fuse shrine is solved by the automated test; the scripted hand run did
  not push the barrel into place, so it is listed as unverified by hand.
- **Side quests**: Sindokht's toll and the bandit camp, Jamshid's forge (the Kindling Key, Pulad of Ghandi, Puladvand, both
  rewards), Hom's pages and hunt, Bid, the bounty board, Sorush's Boss Rush and New Game+ were played through.
  - *Stuck behind a tent*: the 30 px gaps between the camp's two back tents and the palisade swallowed the hero; closed.
  - *Bounties* only name foes of regions the story has opened, and each contract says where its foes live.
  - *The cauldron* opens at the top of its list (it kept its old scroll and the first recipe was off-screen).
- **Common foes never spawn inside a wall** (`world._clear_feet`); `tests/v27fixtest.gd` checks five maps.

## 0.27.0 — The studio (استودیو)
The first round of the studio (`docs/studio/STUDIO.md`): six seats (engineering, QA, publishing, game design, UX, director)
looked at 0.26.1; every finding below was reproduced by the director before it was fixed. Their reports are in
`docs/studio/round1/`.
- **Engineering**
  - *The chapter 2 boss was invisible on phones*: the Android preset still excluded `Enemies/ancientwyrm.png` (an old filter
    line). Removed; `tests/v27fixtest.gd` now checks that no sheet the game loads is excluded from the Android export.
  - *Saves cannot be cut in half any more*: the save, the profile and the settings are written to a side file and renamed
    (`Game.write_safe` / `read_safe`); the last good file stays as `.bak` and is read when the main one is damaged. A
    Continue that still cannot load keeps the damaged file as `save.broken.json` instead of saving over it.
  - *Android Back* opens the pause menu (or closes the shop, forge, cauldron or the pause menu), instead of quitting mid-fight.
  - *The touch pad* redraws when something on it can change (about 9 times a second at rest instead of 60; it was about 40% of
    the frame's CPU).
  - Test hooks (`--test`, `--autotest`, `--shots`, `--menushot`) run only in debug builds. The death panel can no longer open
    under the pause menu or after a quit. Foe sheets are dropped from memory on a map change.
- **QA**
  - *Save & quit* keeps the spot the hero stands on (Continue put him back at the map's entrance).
  - *A map change could land on the wrong map*: the old map's exits are cut from the map change before it is freed.
  - *An exit entered in the first 0.6 s on a map* takes the hero once it is armed and he has moved (it stayed dead before).
- **UX**
  - Persian dialogue lines start next to the portrait (they started at the far left); the quest tracker ends its Persian
    lines on the right; dialogue choices sit above the speaker's name and are taller.
  - The Map page fits the Large interface (it ran off the screen, hiding Zabol in Persian).
  - Skills: the spells come first, with 44 px bind buttons side by side.
  - With the Large interface the minimap gives the Ultimate room; pad rings are at least 14 px apart; pad labels one size up.
  - Calling cards: larger, lighter descriptions of equal height; no "Ember-bearer" tag in Persian either.
  - A tap outside the shop, forge or cauldron closes it. Mana regeneration shows its plus sign like every other number.
- **Game design** (measured with the fighting bot, `docs/studio/round1/design_balance.md`)
  - The King of Mazandaran had 18% more health than the curve allows (hp x5.22 -> x4.3); the Sorceress x6.84 -> x6.3; Zahhak
    x9.0 -> x6.5 and his cave's damage x2.2 -> x1.9. The Dragon of Kashaf x10 -> x6.3 (0.27.1: at x8.2 the bot still lost to it with a quarter of its health left).
  - The Sunken Crypt: the two guards by the door stand further in and the hero arrives 40 px to the west, so Arzhang no
    longer sees him the moment he enters (level design; the gamer's complaint in 0.26).
  - The Greater Potion heals 50 + 30% of max health (it healed less than a plain potion from level 15 and was drunk first);
    it is drunk when that much is missing, or when no plain potion is left.
- **Code review** (an independent pass over this version's own changes): Save & quit out of a Boss Rush memory or a boss
  fight keeps the map's entrance, not the spot; a damaged backup alone no longer offers Continue; a new game drops the
  old hero's backup; the potion button counts Greater Potions.
- **Text** (the Persian and English editors, chapters 2 and 3): the White Div and Akvan are echoes in Sorush's lines and
  objectives too; Zahhak's guards are «روزبانانِ ضحاک»; a negation that had fallen out of the banner's line; "the echo of
  the White Div" (not "of The White Div"); recipe and item text cleaned of developer notes.
- **Publishing**: credits now name the fonts (Vazirmatn, Cinzel — SIL OFL, with their licence files) and the icons (Lucide —
  ISC), and say the characters and maps were drawn for this game. The store listing draft is `docs/studio/round1/store_listing_fa.md`.

## 0.26.1 — the open decisions of the 0.26 playtest, taken
- **The word follows the picture:** Rostam's sprite holds a sword, so Zal and Rostam now both say *blade* ("تیغِ رستم از پژواک
  می‌گذرد، چنان‌که از مه"), not mace. If a mace sprite ever comes, change the two lines back together.
- **The tale stands after Sohrab's death** (Siavash is already in Rostam's care). Nobody explains it; Gordafarid ends "never
  speak that name before Rostam", and Rostam, teaching the Ayyar her arrow, will not name "the young man" she stood before.
- **Arzhang still leaves his lair**: kept on purpose (a level-4 Pahlavan wins on Normal first try; a leash would touch every boss).
- The English calling cards no longer repeat "Ember-bearer" (it overflowed at 16:9; the heading says it).

## 0.26.0 — Four ways (چهار راه)
Both testers, twice: "four callings, one moveset — the Pahlavan casts the same bolt as the Sage." Now:
- **Each calling has its own move**, on the button that was Shove (stamina and a cooldown, never mana; `Skills.SIG`,
  `player.signature()`):
  - **Pahlavan — the Lasso (کمند)**, Rostam's: the foe before you (within 230) is dragged to your feet and stunned 1.2 s; a
    boss loses footing instead (+20 stagger). 6 s.
  - **Sage — the Simorgh's Feather (پرِ سیمرغ)**, Zal's: for 6 s the first blow does not touch you: it gives 10 mana and its light stuns the foes within 110 for 1.6 s (a boss: +15 stagger). 10 s.
  - **Ayyar — the Khadang Arrow (تیرِ خدنگ)**, Gordafarid's: a fast arrow (1.3 x attack); loosed from hiding, three times as
    hard. 2.5 s.
  - **Oathbearer — the Fire-walk (گذر از آتش)**, Siavash's: 4 s of fire around you (0.6 x attack a second, burning), it clears
    poison, fire and ice, and nothing clings to you meanwhile. 12 s.
  The plain shove is gone from the pad (the heavy blow still knocks foes back). The Skills page shows the move under the ultimate.
- **Rostam's training ends with it**: a sixth drill, in his own words for each calling ("Last, my father's way: the Simorgh's
  feather…"); the button appears and glows for it.
- **After the panel's third round** (`docs/playtest/v0.26/playtest_summary_fa.md`):
  - *The echoes are named and seen.* Chapter 2 no longer calls the three foes "wardens": the First Smiths set three **seals**,
    the echoes coiled round them and gnawed them hollow. Cards ("Echo of the Sixth Labour"…), objectives, Zal's tasks, the
    victory banner ("DUST AGAIN — the echo of Arzhang") and message say echo (`Game.is_echo`, `"echo": true` in `BOSS_CFG`);
    the five echoes drag a pale after-image (`boss._echo_look`). One image for Zal and Rostam (the mace, the mist).
  - *Jamshid speaks as a shade*, and his portrait is as pale as he is. The achievement is "Jamshid's Debt".
  - *A drill left half-way* gives the objective, compass and glowing button back to the tale (`Tut.drilling()`, `Tut.away`);
    Rostam says the yard will wait, and repeats the drill on return. The roll drill needs a real roll; the post has no body;
    his new word replaces the old one on the bar.
  - *The pad:* Sneak sits low, under the band the hero is drawn in; a waiting button shows its seconds; in a bottom corner the
    view slides further down so the hero is not on the Shield button (`game_camera.CORNER_B`); the map's edge has a seam.
  - The level banner sits below a tall message; a boss's card centres on a far boss; calling cards show the calling's move;
    a new lasso icon (it looked like the talk bubble).
  - Persian: the critic's table (kasra on spell names, "گلِ مرداب" for the herb everywhere, "شَبَه" for obsidian, "چند گام"
    for "170 px", one word for spells, the menu's subtitle).
- Tests: `tests/sigtest.gd` (14 checks); `tests/tutorialtest.gd`; `tests/v26fixtest.gd` (25); screenshots `tests/v26shots.gd`.

## 0.25.0 — Echoes (پژواک‌ها)
The decisions the 0.24 playtest left open, taken (see `docs/playtest/v0.24/playtest_summary_fa.md`, part 2):
- **Rostam is no longer a bystander.** The critic: "the nameless hero does Rostam's own labours while Rostam gives button tips."
  Now the foes of chapter 1 are **echoes** of the ones Rostam slew, walking again since the chains of Damavand cracked (which
  also foreshadows chapter 3). Zal says so when he gives the first task; Rostam's blade "passes through an echo like smoke —
  only the ember returns it to dust". Rostam's word on each boss now carries his own memory of it (Arzhang on the sixth labour,
  the Sorceress at his table on the fourth, the King of Mazandaran turned to stone, the White Div on the seventh, Akvan and the
  sea); of Zahhak he says: "no echo — the thing itself".
- **Jamshid is a shade.** In the Shahnameh Zahhak sawed him in two. "Jamshid the Exile" is now *the Shade of Jamshid* (روانِ
  جمشید), drawn pale and half seen; he knows the ember ("it was mine once"), and he was "the first to soften iron in fire".
- **A small pad in Zabol.** Until a new hero has left the village once (or passed level 1), the pad shows only attack, roll,
  shield and potion — and the spell button when Rostam's last drill asks for it. Afterwards the whole pad, for good.
- **32-bit phones:** the Android export now builds `armeabi-v7a` beside `arm64-v8a` (older, cheaper phones on Myket/Bazaar).
- Not in this version, on purpose: a skill and a drill of its own for each calling (the next version: it needs design and
  balance, not text); new art for Zal, the Sage and Bid (no CC0 art in a Persian style exists; see the summary); a new signing
  key (make it on your own computer at release time, so the password is only yours).

## 0.24.0 — The Ember-bearer (اخگردار)
The playtest's biggest complaint about the story was the hero's identity: he *was* Rostam (or Zal, Gordafarid, Siavash, by class),
yet everyone in Zabol spoke to him as a stranger — Rudabeh, Rostam's own mother, sold him potions. Now:
- **The hero has no name of his own.** He is *the Ember-bearer*, marked by an ember of the farr that left Jamshid. The class is his
  **calling**: Pahlavan (the way of Rostam), Sage (the way of Zal), Ayyar (the way of Gordafarid), Oathbearer (the way of Siavash).
  The title screen's cards, the HUD, the Hero page, the toll's options and the ending card all use it.
- **The heroes of the Shahnameh are people of Zabol**, drawn from the heroes' sprites in their own colours (portraits too):
  - **Zal**, son of Sam, lord of Zabol, gives the quests (he was "Elder Godarz").
  - **Rostam**, his son, a head taller than anyone, keeps a training yard on the way to Kavian's forge (below).
  - **Siavash** keeps the Trial of Embers (Rostam raised him in Zabol; he rode through fire once); **Gordafarid** keeps the bounty
    board (she fought Sohrab at the White Fortress and slipped his grasp).
  - **Kavian the Smith**, of Kaveh's house (Kaveh is the legend of chapter 3; Qaren is his son, who stood beside Fereydun).
  - **Sindokht of Kabul** keeps the stores (a Kabul caravan; she once turned Sam's wrath from Kabul with gifts and gentle words);
    **Rudabeh the Healer** is Zal's wife and Rostam's mother — a feather of the Simorgh saved her the day Rostam was born.
  - Sorush tells the Dragon of Kashaf in one page: Sam struck it down, it only slept, the First Smiths chained it. The White Div
    took Sorush's hall (he was its "Judge"). Bid the Div keeps his name (a div of Mazandaran) and is titled *the toad-shaped Div*.
    The look *Jahan-Pahlavan* (Rostam's own title) is now *Rostam's Robe of Honour*; *Holy Smite* is *Farr Smite*; *Arcane Bolt*
    is *Ember Bolt* (تیرِ اخگر).
- **Rostam's training** (both testers: "nine buttons and no teacher"). A new hero is sent to Rostam (or to Zal — either starts the
  game). He offers a short training, or lets you skip it: strike the post three times; one heavy blow; roll out of his marked blow
  — or through it, as it lands — twice; take one on the shield; cast a spell (the ember answers). His marked blows are the bosses' own ground warnings, so the hero
  learns exactly what the bosses will do; in the yard they never hurt ("Again!"). The button each drill asks for glows and is never
  faded; each drill's first blow waits for its words to be read. Reward: 30 gold and two potions, and Rostam tells of the perfect
  block. You can stop midway, or come back after saying no. Afterwards he gives a word for the fight ahead (Arzhang's pillars, the
  King of Mazandaran's vents, the Sorceress's eggs, the White Div's echoes, Zahhak's serpents) — a "!" over him when the tale has
  moved on since his last word. Old saves skip the training (Rostam still offers it).

### The playtest of 0.24 (the same two testers) and what came of it
Reports and a Persian summary: `docs/playtest/v0.24/`. Fixed in this version:
- **Fights by a wall were fought under the buttons** (the gamer's main finding: the camera stopped at the map's edge, so a hero
  by the right or bottom edge stood under the thumb buttons — the first training yard and Arzhang's lair both). The view may now
  slide past the edges, most on the right and at the bottom; past the edge the ground is folded out and falls into darkness. The
  yard moved to open grass in the middle of Zabol.
- **Arrivals:** after a load or a rematch, foes near the hero have not noticed him for 3.5 s (a blow wakes them); pushed foes no
  longer simply walk back while the screen fades in.
- **A second fall to the same boss** offers "Story difficulty — then fight again" on the death screen.
- **One message at a time:** a won fight takes its tips away and the achievement card waits for the "Vanquished" banner; Arzhang's
  pillars give one banner (with the bait hint) instead of a banner, a tip and the bar at once, and no "Shielded" over his body;
  long messages keep to the strip between the hero's panel and the minimap; a talk that opens from play (Rostam's end of training)
  cannot be skipped unread by the shield still being pressed.
- **The shop** says "Not enough gold" at once for what you cannot afford (no "tap again"). After a boss, the compass leads to Zal's
  reward before Jamshid's errand. Sindokht's first talk is three pages, not five. "Save & quit" is no longer cut off at the foot of
  the pause menu. The boss's name card frames the boss (Zahhak's serpents were under the letterbox). The region's name has a dark
  band behind it.
- **The text** (the critic's table; `tools/v24_text.py`): no "Elder Godarz" left (chapter 3's last objective still had him), no
  "your name alone" for a nameless hero, Zal never says "Champion"; Ember = اخگر (the Trial was "آزمونِ خاکستر", ash); one name each
  — ضربهٔ کاری (not بحرانی), سرداب (not سردابه or سیاه‌خانه), عصاره (not جوهر), زیارتگاه for the shrines, سرکرده (not باس), مرحله
  (not فاز); راهت را برگزین (not کالبد); the ezafe after a silent he is «هٔ» everywhere (153 strings); زرهِ مذاب; the "·"
  between items, which reads as the Persian zero, is «،» in Persian (`Game.sep()`); Kavian's motto is the same in the talk and the
  shop; Hom's companion is Mehran in both languages; Zahhak "reigned a thousand years". `tests/texttest.gd` keeps it so.
- Tests: `tests/tutorialtest.gd` (44 checks), `tests/texttest.gd` (10), `tests/v24fixtest.gd` (19); fxtest checks the apron,
  uitest that the pause menu fits; screenshots `tests/v24shots.gd`. A draft privacy policy for the stores: `docs/privacy_policy.md`.

## 0.23.0 — Chapter 3: The Chains of Damavand (زنجیرهای دماوند)
A new chapter from the Shahnameh: Zahhak, the serpent-shouldered king whom Fereydun bound beneath Mount Damavand, and the
Derafsh-e Kaviani, the leather apron Kaveh the smith raised on a spear against him. It opens once chapter 2 is over.
- **The story.** Kaveh's forge-fire burns black: Damavand is smoking, Zahhak's chains are cracking, his serpent guards walk the
  slopes and his steward Kondrow has woken. Kaveh still keeps the banner's leather, but its three jewels were lost on the mountain.
  Find them, Kaveh raises the banner again, the Gate of Damavand opens for it, and you go down to Zahhak. When he falls, Sorush
  stays your hand: *his time is not yet* — bind him to the mountain, as Fereydun did. Elder Godarz tells the epilogue; the end card
  of chapter 3 follows (the world stays open).
- **Two new regions.** The **Slopes of Damavand** (east of the Ashen Peaks, behind a rockfall until Kaveh has spoken): ash and lava,
  Qaren's camp, Kondrow's ruined terrace, the old fire temple and the sealed Gate. The **Cave of Chains** below: four chains from
  four pillars to the lair.
- **The three jewels**:
  - **Kondrow**, Zahhak's steward (a miniboss: slam, charge, a ring of poison bolts) on the north-west terrace.
  - **The fire temple**: three altars cold for a thousand years. Blows strike sparks (a plain blow 1, a heavy blow 2, a burning blade
    one more; three light it, for 6 s); fire — a fire bolt, Ember Nova — lights one at once for 14 s. All three burning together
    open the temple's heart: the jewel, gold and an epic accessory.
  - **Qaren, Kaveh's son**, at the camp: bring down ten serpent guards (swordsmen and poison archers).
- **The Derafsh-e Kaviani**: +12% damage on Damavand and in the Cave of Chains (shown in the quest log).
- **Zahhak** (rebuilt boss, three phases). His two serpents rise from his shoulders and bite along marked lanes (both at once in
  phase II, three in a row in the last); venom that leaves poison on the ground; a sword sweep; the chains lash out as a ring you roll
  through; rocks shaken from the roof; he calls his serpents. **The chains hold him near his lair** — one breaks at each phase and his
  reach grows. Weak to fire. Balance bot (level 18, best smith gear, no talents, the banner): 66 s, 125–175% of his health taken,
  2–5 potions, no deaths. Afterwards he stands chained in his lair.
- **New foes**: serpent guards, serpent archers, Zahhak's serpents (a new creature, drawn in the game's style), Kondrow.
- **Achievements** (now 42): *The Smith's Banner*, *Three Fires*, *Bound in Damavand* (secret) — the last earns the **Kaviani** look
  (red, black and gold).
- Music: the slopes borrow the Ashen Peaks' track, the cave the crypt's, Zahhak the Dragon's battle theme (no new CC0 Persian music
  could be fetched here).

### The playtest (two testers on 0.22: a pro mobile gamer and a mobile-games critic) and what came of it
Their full reports are in `docs/playtest/v0.22/`. Fixed in this version:
- **A reload took the hero's weapon and armour away.** JSON gives numbers back as floats, so after loading a save the weapon
  tier was read as "1.0", found no row, and the hero lost his weapon's attack and his armour's defence (a level-5 warrior with
  the fifth blade: attack 41 → 7, defence 16 → 2) — every fight after a reload was far harder than it should be. The forge also
  called the blade "Fists". Whole-number fields are ints again on load; the lookups are guarded; a test checks it.
- **Arzhang's shield is explained where you look**: the boss bar says "shielded: break the pillars (n)", a banner "BREAK THE
  PILLARS" each time they rise; a pillar now takes 15% off his damage taken (was 20%), at most 45% (was 60%).
- **"Story" difficulty** (gentler foes: 70% health, 65% damage, 85% rewards) under Normal, for players who came for the tale.
- **No way out mid-fight**: an exit within reach of an engaged boss does not open (the bot rolled out of Arzhang's arena through
  the shrine door). **Two bosses on a map** (the bog): when one falls, the other takes the health bar and the rematch.
- **Safe arrival** after a load, a rematch or a respawn: two seconds of grace, and foes on the doorstep are pushed back.
- **The Sorceress's brood is capped** (an egg hatches only while fewer than five small foes are near).
- **The buttons no longer hide the fight**: a button over the hero or a boss fades to a ghost.
- **Buttons wear their names** under them until each has been used three times (or level 5) — the first minutes teach the
  controls without a tutorial screen. The help page's line on the ultimate was wrong ("the star button"): fixed.
- **A blade or armour asks for a second tap** before it is bought (potions do not).
- **Zabol's purse**: every hero starts with 40 gold more, so the first visit to the shops is not window-shopping.
- The forge says where herbs, essence and obsidian come from when you lack them.
- Achievement cards wait for a boss fight to end; floating numbers born together are stacked, not drawn over each other.
- The pause menu's column scrolls, its buttons are a little smaller, and with the large interface the title gives its room, so
  "Save & quit" shows. A finger that lands on a card or a button and slides now scrolls the page (the controls pass the drag on).
- A change of language now renames the villagers' plates and the level badge.
- Pale bosses (the White Div, Akvan): the name on their card has a dark outline and a shadow.
- Persian: the English line in Elder Godarz's first talk is translated, and he greets the hero by name; "XP" is «تجربه»
  everywhere; Persian digits and «٪» in item labels and the hero page; the contracts read in Persian order («۱۰ پشهٔ مرداب را
  بکش — پاداش: …»); the credits keep the English titles' quotes in place (bidi isolates); the title shows «نسخهٔ ۰.۲۳.۰», no
  "Godot"; the app's name on a Persian phone is «اخگر و آهن». A glossary pass (`tools/fa_glossary.py`): «سردابِ فرورفته» (one name,
  was three), «مردابِ سایه» (not «سایه‌فن»), «گلِ مرداب», «تیغِ هندی» (not mithril), «جوشنِ یخین», «تیغِ اخگرنیش», «دفاعِ بی‌نقص»
  (not «پرِی»), «پارسای خاکستر» (not «قدیس»), «اخگردار», «یزدان», «کوبهٔ فرّه», «پرِ سیمرغ» (was the Phoenix Heart), Zal the
  «فرزانه» (not «جادوگر») and Siavash the «سوگندوَر» (not «پالادین»), and a few loan-translated lines rewritten.
- The slopes of Damavand were swarming a level-17 hero at the entrance: its foes hit softer (serpent guard 11 → 9, archer and
  serpent 10 → 8) and a pack moved off Kondrow's terrace.
- Chapter 3's first nudge ("speak with Kaveh") waits behind a side quest in progress.
- Qaren's name plate is translated (قارن، پسرِ کاوه). `tools/l10n_check.py` finds English shown without Persian (code and maps).

### The playtest kit (new)
`tests/playtest.gd` and `tools/playtest/`: plays the game from a scenario file through real touches (the joystick, the buttons,
taps on menus by their text), with phone-sized screenshots, contact sheets of motion, the text on screen (and any Latin left in
the Persian game) and the hero's state at every step; a fighting bot that reads three in four marked attacks; presets for every
point of the story (now with chapter 3). `--playtest` keeps the game as a player gets it.

## 0.22.0 — the names of the Shahnameh
Milad asked for the world's names to come from Ferdowsi's Shahnameh. Every text (English and Persian) now uses them; the game's
ids and the saves do not change, so an old save loads as it was.
- **The village**: Fernbrook → **Zabol** (زابل), the land of Zal and Rostam.
- **The four heroes** (the classes keep their stats, spells and ultimates; the calling is shown beside the name):
  **Rostam** (warrior), **Zal** (mage — white-haired, raised by the Simorgh), **Gordafarid** (rogue — she outwitted Sohrab),
  **Siavash** (paladin — he rode through fire unharmed). The Toll's class choices are labelled with the hero's name.
- **The people**: Elder Rowan → **Elder Godarz** (گودرز), Blacksmith Garen → **Kaveh the Smith** (کاوهٔ آهنگر), Merchant Thalia →
  **Sindokht** (سیندخت), Alchemist Miri → **Rudabeh** (رودابه), Brann the Exile → **Jamshid the Exile** (جمشیدِ تبعیدی — the fallen
  king who taught men to work iron), the Memory Keeper → **Sorush** (سروش), Hesk the Trapper → **Hom** (هوم, the mountain hermit).
- **The bosses**: the Dungeon Guardian → **Arzhang the Div** (ارژنگ دیو), the Ember Colossus → **the King of Mazandaran** (شاه
  مازندران, the sorcerer-king who made himself stone), the Marsh Matriarch → **the Sorceress** (زنِ جادو, of Rostam's fourth labour),
  the Frostbound Arbiter → **the White Div** (دیو سپید), Ignarok → **Puladvand** (پولادوند), the Glacier Titan → **Akvan the Div**
  (اکوان دیو), the Ancient Wyrm → **the Dragon of Kashaf** (اژدهای کشف‌رود, slain by Sam), the Toad King → **Bid the Div** (دیو بید),
  the Warden of the Anvil → **Pulad of Ghandi** (پولادِ غندی), Varga the Red → **Ashkbus of Kushan** (اشکبوسِ کشانی). Their relics
  follow (Arzhang's Bulwark, Emberheart of Mazandaran, the Sorceress's Fang, the White Div's Rime).
- The HTML game's own Persian translations had used other names in places (the elder's lines said «نگهبانِ سیاه‌خانه» while the
  quest line said «نگهبان سرداب»): now one name each, everywhere.
- `tools/shahnameh_names.py` does the renaming (idempotent; prints every changed line).

## 0.21.0 — the Boss Rush, New Game+
- **The Boss Rush — "Battles Remembered"** (the HTML game's RUSH_BOSSES, with the port's Ignarok and Glacier Titan). Once chapter 2 is
  over, the **Memory Keeper** in the Crystal Sanctum offers to open the battles you won again, one after another: the Dungeon
  Guardian, the Ember Colossus, the Marsh Matriarch, the Frostbound Arbiter, Ignarok, the Glacier Titan and the Ancient Wyrm.
  - Each fight is a **memory** in the boss's own arena: a cold tint over the world, no other foes, no villagers, no way out.
  - Every boss comes as an endgame fight (its own health and damage for the run, rising toward the Wyrm); bosses keep their full
    move sets and phases, the Wyrm its own music.
  - **The memory's potions**: four health and two mana potions (yours wait outside); between fights 40% of your health and all your
    mana come back. The boss bar shows which memory you are in and the clock (it stops between fights).
  - **Dying ends the run** — no gold is lost; you wake by the Keeper. Quitting mid-run (or the phone closing the game) gives
    everything back on the next load.
  - **All seven**: +1500 gold the first time (+300 after), your time and best time, and three achievements: **Keeper of Battles**
    (clear it — earns the **Pahlavan** look, with a crown), **Memory Unbroken** (under seven minutes) and **Without a Draught** (no potion).
  - Tuned with the balance bot (`tests/bosstest.gd --bot --rush`, a level-16 warrior without talents or accessories): 25–65 s a fight,
    30–110% of his health taken a fight; he just makes it through all seven with the potions and the health between fights.
- **New Game+.** After chapter 2 the Keeper also offers to **begin the tale anew** (with a warning: it cannot be undone).
  - **You keep** your level, gear, gold, spells, talents, sigils, forge, contracts, elites and Trial best; achievements and looks are
    the profile's anyway.
  - **Back again**: Elder Rowan's quests, the bosses, Brann's tale, the Thornwood Toll, chapter 2 and Hesk, and the things lying
    about the maps.
  - **Every region is at least as tough as the Hoarfrost Vale**, and more each cycle (+35% health, +20% damage a cycle; not the
    village and the Trial); foes give more XP (by how much tougher they got) and +50% gold a cycle; more elites. The Boss Rush grows
    with it.
  - "NG+1" by your name on the HUD and on the Hero page; the Keeper's offer stays open in New Game+ whenever he has no part of the
    story to tell. Achievements: **A Twice-Told Tale** (begin New Game+), **Ashen Saint** (the Wyrm in New Game+ — earns the new
    **Ashen Saint** look).
- Achievements: 39 (five new). Looks: 12 (two new).
- The end-of-chapter card now says what waits (the Boss Rush and New Game+) and fits the screen with the large interface.

## 0.20.0 — achievements, hero looks, the village fountain
- **Achievements: 34.** The HTML game's 21 (First Blood, Slayer, Exterminator, Boss Slayer, Boss Master, Untouched, Rich, Apprentice,
  Veteran, Master, Critical Master, Ultimate Power, Frost Heart, Parry Master, Shadow Step, Alchemist, Champion, Legend, Winter Born,
  Wyrmslayer (secret), Ashen Veteran) and 13 for what the port added: The First Flame (Ignarok), Glacier Breaker (the Titan),
  Phantom of Thornwood (the strongbox back unseen), Silver Tongue (the Toll settled with words), Master Smith (+5 weapon and armour),
  Seeker of Sigils (all seven shrines), Wayfarer (25 contracts), Elite Hunter (25 elites), Silent Blade (25 backstabs), The Exile's
  Debt (Brann's tale), Friend of the Trapper (Hesk's two tasks), Legendary Find (a legendary accessory) and Gilded Sovereign (all the rest).
  - A **card** slides in under the quest tracker when one is earned (a medal, its name, what it was for, the look it brings) with its
    own jingle; several wait their turn.
  - **Menu → Hero** now has three pages: the hero sheet, **Achievements** (every one with its progress, e.g. 37/200, "new" marks, secret
    ones hidden until earned) and **Looks**. The menu button's dot also lights for new achievements.
  - Kept in a **profile apart from the save**, as the HTML game did: they stay through a new game. An older save is counted when you
    load it (the bosses you beat, your level, gold, forge, shrines, contracts, quests…), quietly, with one line saying how many came in.
- **Hero looks: 10**, the HTML game's hero skins (there they were bought; here **achievements earn them**): Ember (default), Crimson Oath
  (Boss Master), Verdant Warden (Legend), Frostborn (Winter Born), Azure Adept (Seeker of Sigils), Obsidian Vow (Master Smith), Sunfire
  (The First Flame), Wayfarer (25 contracts), Voidtouched (Wyrmslayer) and Gilded Sovereign (all achievements, with a **crown**).
  - A look recolours the class's own clothes on the hero's sprites (the warrior's red, the mage's blue, the rogue's green, the paladin's
    gold and plate), keeping the drawing's shading, face, hair and weapon; most add a soft **aura** on the ground and a **trail** of
    light motes while walking, and the dodge's after-images take the look's colour. Tap a look in Menu → Hero → Looks to wear it.
- **The village fountain** (FOUNTAIN.json): the cobbled ring in the middle of Fernbrook had an empty dark disc where the HTML game drew
  its fountain in code. Now there is one: a stone basin with water that ripples and glints, a pillar, four jets and splashes, a cool
  light at night and the sound of water close by. **Resting by it restores health and mana** and washes off poison, burns and frost.
- New: the "achievement" jingle (Kenney's Music Jingles, CC0), 15 more Lucide icons (ISC).

## 0.19.0 — chapter 2: The Sleeper Beneath
- **The story goes on.** When Elder Rowan's three quests are done, the ground starts to shake: the Guardian, the Colossus and the
  Matriarch were *wardens*, set by the First Smiths to keep the **Ancient Wyrm** asleep beneath the Crystal Sanctum. "THE WYRM
  STIRS!" The Elder sends you to the **Memory Keeper** in the Sanctum, who tells the rest: the **Wyrm Key** was broken in three.
  - **Shard of Judgement**: the Frostbound Arbiter (the Sanctum's boss, until now without a reason to fight it; if you already
    beat her, the Keeper has her shard).
  - **Shard of Frost**: the **Glacier Titan**, in a new region east of the Sanctum, the **Hoarfrost Vale**.
  - **Shard of Memory**: the Keeper's **vault** in the Sanctum's north-east corner (in the HTML game's data, never built): sealed in
    rimeglass that only cracks after the Keeper's word — **heavy blows** break it (a plain blow only chips it), fire melts it.
  - Bring the three back: the Keeper mends the key, and the **sealed door behind the Judge's seat** opens onto the
    **Wyrm's Hollow**, a cavern down to the Wyrm's lair. Slay the Wyrm, return to the Elder for the epilogue, and the
    **chapter ends** with a card: what you did, thanks for playing, and the world stays open.
- **Two new regions**, drawn in the style of the HTML game's grounds:
  - **Hoarfrost Vale** (snow; wind; its own music): pine woods, a **frozen lake** (slippery), **Hesk the trapper's camp**, a ruined
    watch-post of the First Smiths, a crystal grotto, and the Titan's clearing ringed by ice spires.
  - **The Wyrm's Hollow** (a cave; its own music): an entry hall, a crystal grotto, an ice hall (slippery), the narrows, and the
    lair with an old rune circle.
- **Two new bosses** (mine; the HTML game had only the Wyrm's picture and numbers):
  - **The Glacier Titan** (mini boss): a ground slam, a **frost wave** to roll through, icicles from above, a charge to bait into the
    spires; at half health it **calls icelings** from the snow and hurls ice boulders. Weak to fire.
  - **The Ancient Wyrm** (final boss, three phases): frost **breath** (a cone), tail sweep, a ring of ice shards, a lunge; in phase II
    it **spreads its wings**, takes to the air and **dives on its shadow**, beats a gust of icicles and calls **wyrmlings**; in the final
    phase its breath sweeps the lair and a hailstorm falls. Its own music (an epic orchestral boss theme).
  - Tuned with the balance bot (`tests/bosstest.gd --bot`, the hero's own stats): the Titan ~35 s at level 13, 60-80% of your health
    taken; the Wyrm ~80 s at level 15, 150-200% taken (potions needed), no deaths in the runs.
- **New foes**: **frost wolves** (packs; their bite chills), **rime wraiths** and **wyrmlings** that keep their distance and shoot
  **frost bolts** (new: aimed shots you can dodge), and the sanctum's foes in new places.
- **Hesk the trapper** (new villager, in the Vale): **Wolves of the Vale** (eight frost wolves) and **The Lost Expedition** (three
  frozen journal pages in the snow — each one a piece of the story of the wardens, read when you pick it up), with gold and
  accessories as rewards, and a **small shop** (potions, mana potions, greater potions) so you need not walk back to Fernbrook.
- **Brann's frost-steel**: bring him the Titan's frost-heart and he forges the **Frostreaver** (+46 ATK) and the **Glacial Aegis**
  (+20 DEF) — the HTML game's top tiers, until now not obtainable.
- The objective line, the quest arrow and the quest log follow every step; villagers with news (the Elder, the Keeper, Brann, Hesk)
  show a "!"; the world map shows the Vale, and a shrine or the Hollow now count as their region ("you are here").
- **Fix**: quitting the game in its first fraction of a second (while the music samples were being made) crashed it at exit.
- New art made from the game's own sprites (same outline and shading): frozen ice spires, the frost wolf, the rime wraith, the
  wyrmling, the Glacier Titan, Hesk, the three shards and the journal page. New music: "Medieval: Exploration" (RandomMind, the
  Vale), "Snowfall" (Kistol, the Hollow), "Boss Battle Music" (SubspaceAudio / Juhani Junkala, the Wyrm) — all CC0, in the credits.
- Tools for making maps (`tools/ch2_maps.py`, `map_preview.py`, `make_world_graph.py`), art (`ch2_art.py`), data (`ch2_data.py`),
  and `tools/run_all_tests.sh`.
- `tests/chapter2test.gd` (66 checks: the whole chapter through the real talk paths), `tests/quittest.gd`, the bot's two new bosses,
  `tests/ch2shots.gd` (screenshots). All suites pass, normally and under the guard allocator.

## 0.18.0 — the seven puzzle shrines
- **Seven shrines, seven puzzles.** Every wild region hides an ancient shrine (they were empty rooms in the port; the HTML game's
  data had a whole puzzle for each, with its layout, pieces, tablets and rewards). A stone stair with rune stones and a
  **pillar of light**, seen from far away, marks the way down (gold once the shrine is done); a tablet at the door explains it.
  - **Shrine of Shadows** (village): the Watchers see what walks in their light and hear loud steps — sneak, keep to the tall
    grass, reach the far plate. Seen or heard, you are sent back to the entrance.
  - **Shrine of Embers** (forest): strike the eternal flame and your blade burns for a while — light every brazier; brambles burn
    away; the oil trail carries the fire across the water to the last brazier.
  - **Shrine of Weight** (crypt): only stone weighs the plates down — walk into a block to push it a cell; the lever puts the
    blocks back if one gets stuck. Skeletons guard it.
  - **Shrine of the Fuse** (Ashen Peaks): push the powder barrel beside the cracked wall, light it and run; a shove or a charged
    blow throws imps into the lava.
  - **Shrine of Tides** (Shadowfen): the frost crystal chills your blade — strike the water ahead to freeze a path (it cracks and
    thaws); the storm crystal makes the water deadly to whatever stands in it; the door wants the plate held and no toad left.
  - **Shrine of Light** (Crystal Sanctum): strike a mirror to turn it, lead the light to the crystal; fire melts the ice in its way.
  - **Shrine of Echoes** (Emberforge): the mosaic tells the order of the runes; then both braziers must burn at once (9 s each).
  - Spells work on the pieces too: fire spells light and melt, the ice lance freezes water.
- **The altar**: gold, an accessory (rare or epic) and the **Shrine Sigil** — you choose its gift, for good: **Vitality** (+12 max HP),
  **Focus** (+6 max MP), **Might** (+2 ATK) or **Guard** (+1 DEF). Vitality and Focus are the HTML game's; Might and Guard are mine.
- The objective line and the quest arrow lead to the next shrine once the main quests are done ("Seek the ancient shrines — 3/7");
  the Hero page counts the shrines and the sigils you hold.
- The shrine's name now shows in Persian when you enter it (it was English).
- **Smaller project**: every PNG of the art was re-compressed losslessly (pixel for pixel identical, checked image by image):
  12.7 MB -> 6.7 MB. `tools/optimize_png.py` does it again.
- `tests/shrinetest.gd` (70 checks: every shrine solved through its own mechanics, the altar, the sigils, saving, the gates, the
  compass, spells on the pieces, the title in both languages), `tests/shrineshots.gd` (screenshots). All suites pass, normally and under the guard allocator.

## 0.17.0 — real music and sound
- **Music**: every region has its own recorded track instead of the generative tune — title, Fernbrook, the Whispering Forest,
  the crypt, the Ashen Peaks, the Shadowfen, the Crystal Sanctum, the Emberforge, the bandit camp, the Trial, the shrines, and a
  **boss theme**. A change of region or a boss fight **crossfades**; each track starts over a few seconds before its end,
  crossfading into itself, so no loop point is heard; after a boss fight (or a quick visit elsewhere) the region's track
  **resumes where it was**. 12 tracks, about 20 minutes, loudness-matched.
- **Ambience**: birds by day and crickets by night outdoors, crackling fire in the bandit camp and the Emberforge, the drip and
  hum of the crypt, the sanctum and the shrines, water in the Shadowfen, wind on the Ashen Peaks and in snow and ash storms; rain
  stays. It now plays with light graphics too (only the weather needs full graphics).
- **Sound effects**: recorded swings, impacts, critical slashes, armour clanks, cloth on the dodge, a purse of coins, doors,
  page turns in dialogue, clicks, glass on potions, creature roars — **92 recordings**, several variations of each, never the
  same one twice in a row, with a little pitch variation. New sounds: **footsteps** (grass, stone or snow by region, soft when
  sneaking), creature **growls** when wolves and imps notice you and cries when they fall (slimes gurgle, bugs chitter), a
  **chest** creak, a **latch** rattle at sealed paths, the clink of buckles when you buy or wear gear, a book opening with the
  menu, and short **jingles** for quests, level-ups, rare finds, a boss vanquished and a fall in battle. Doors only on doors: an
  open road gives a rustle instead.
- The synthesised sounds of the HTML game stay for the magic (nova, bolts, ice, poison, phase…), the heartbeat and the kill pop,
  and as a fallback for anything missing.
- **Settings**: **Music volume** and **Sound volume** (quiet / normal / loud), in the game menu and on the title screen; the
  sound volume covers the ambience. A limiter on the master output keeps a pile of sounds from clipping.
- **Credits** (Settings): every track by region and every author. All of it is **CC0** (public domain, free for a sold game):
  RandomMind, pauliuw, kindland, VishwaJai, SkyleTheFrench, nene, cynicmusic, isaiah658, Wolfgang_, SketchMan3, PagDev,
  JaggedStone, rubberduck, artisticdude and Kenney. Licence trail: `assets/audio/CREDITS.md`, `assets/audio/licenses/`.
- `tools/build_audio.py` rebuilds all of it from the sources (see DEV_NOTES, "Audio").
- `tests/audiotest.gd` grows to 41 checks (every file loads, variations, footsteps, every map has a track, the crossfades,
  the loop, the resume, the fallback tune, the ambience by map/hour/weather, the volumes, the bus routing, the credits). All
  suites pass, normally and under the guard-page allocator.
- Test fix: `trialtest` failed now and then (`death_ends_the_run`) when the champion's random drop was a revive charm, worn at
  once, that saved the hero from the planned death; the test now takes it off first.
- Size: the project grows by about 8.8 MB (audio), the APK by about the same.

## 0.16.1 — fix: the crash on Android at night
- **The crash** (POCO, Android 16): the game closed in the audio thread. Symbolised with Godot's official 4.6.2 Android debug
  symbols (the crash's Build ID `a1dc416352711900` is the official 4.6.2 release template), the crashing frame is
  `AudioStreamPlaybackWAV::decode_samples<int16_t>` <- `_mix_internal` <- `AudioStreamPlaybackResampled::mix` <- `AudioServer::_mix_step`
  <- `AudioDriverOpenSL::_buffer_callback`: the mixer read **one frame past the end** of a looping ambience sound.
- **Cause (ours)**: `Music._wav()` set `loop_end = frames`; Godot's mixer plays frame `loop_end` itself, so the last read was
  one frame (2 bytes) outside the buffer. On a PC that reads harmless heap memory; on Android, Scudo places big blocks right
  before a guard page, so the **cricket loop** (exactly 105,840 bytes, a multiple of 16, no padding) faulted the first time it
  wrapped: ~2.4 s after night fell in the village, the forest or the camp. Rain and wind had the same bug but happened to have
  2 and 12 bytes of padding.
- **Fix**: `loop_end = frames - 1` (Godot's own WAV importer uses the same convention).
- **Proof**: reproduced on the server with `tools/guardmalloc.so`, a small allocator shim that gives big blocks a guard page
  the way Scudo does: before the fix the game crashed with signal 11 at the first cricket wrap; after it, it plays every loop
  through several wraps. All test suites were also run under the shim to look for other reads past a buffer.
- `tests/audiotest.gd` (9 checks): every loop ends inside its data, notes and sounds are one-shots, the three loops wrap safely.

## 0.16.0 — the Trial of Embers, and elite foes
- **Trial of Embers**: a stone gate in the east of the village leads to the Trial Grounds (the map was in the data but unreachable).
  Endless **waves**: every wave bigger and tougher (+10% health, +5% damage per wave, up to 14 foes), the foe tier growing from
  the HTML game's list (EI_TRIAL), a few seconds of rest between waves, gold and XP for every wave cleared, and a **champion**
  (a huge elite) every fifth wave that drops a rare or epic accessory. Leave by the southern gate any time. Your **best wave** is kept.
- A death in the arena **costs no gold**.
- **Elites** (the HTML game's fire / frost / storm): **2.4x health, 1.3x damage, 3x XP and gold**, a glowing aura in the element's colour,
  and their hits burn, freeze or stun you. From level 3 about 7% of the ordinary foes on the maps are elites; from wave 4 the
  Trial has them too. Each elite drops a rare accessory and is counted ("Elites slain"). Bosses are never elites.
- The Hero page shows your best wave and the elites slain.
- From the HTML game: the tiers, the element names and colours, the texts. **Mine**: all the numbers (waves, scaling, elite strength).
- Not yet: the **Boss Rush** (RUSH_BOSSES) and the **achievements** (21 in the HTML game).
- `tests/trialtest.gd` (50 checks); all older suites still pass. One older check (`ult_ready_toast`, skilltest) is timing-sensitive
  and fails now and then by itself.

## 0.15.0 — the Bounty Board
- A **Bounty Board** stands in the village square: **three contracts** at a time ("Slay Slime x8"); finish one and another takes its
  place. Kills count anywhere on the map. When one is complete the game says so ("Contract complete — claim it at the board") and the
  board lets you **claim** it for gold and XP (with your difficulty and talent bonuses; a level-up is announced).
- The foes come from the HTML game's hunt pool (14 kinds); the pool **grows with your level** (forest and crypt from level 1, the peaks
  from 3, the fen from 5, the sanctum from 7). The three are always different kinds.
- The Hero page lists your contracts with their progress and the number completed.
- The names, the "three contracts" rule and the claim wording come from the HTML game; **the amounts and the level gates are mine**.
- Not yet: the cosmetic **crowns** ("Earned at 25 contracts", "Earned by defeating Ignarok") — the HTML game has hero crowns; the Godot port has none.
- `tests/contracttest.gd` (33 checks); all older suites still pass.

## 0.14.0 — difficulty: Normal, Hard, Nightmare
- **Settings -> Difficulty -> Foes**: Normal (as before), **Hard** (foes +50% health, hit 30% harder, +25% XP and gold) and
  **Nightmare** (+120% health, +75% damage, +60% XP and gold). It is a global setting, saved with the other settings.
- Damage taken changes at once; foes you meet from now on have the new health (those already standing keep theirs). Poison,
  fire and ice ticks are not scaled. Bosses scale too.
- The names (Normal, Hard, Nightmare) come from the HTML game; **the numbers are mine** (the HTML export kept only the names).
- `tests/difftest.gd` (24 checks); all older suites still pass.
- Delivery: from this version the package is the **project zip only** (no APK).

## 0.13.0 — Brann the Exile: the story reaches the Forge
- **The Emberforge was unreachable**: the Ashen Peaks had no way into it. There is now a stone **Kindling door** in the south of the
  Peaks: dark and sealed ("A Kindling lock seals the door") until Brann gives you the key, glowing once it is yours.
- **Brann's questline** (titles and toasts from the HTML game): the Dungeon Guardian drops the **Warden Core**; bring it to Brann in the village
  and he gives you the **Kindling Key**; slay the **Warden of the Anvil** in the Forge (a mini boss, now counted as a kill); return to
  Brann: +350 gold and your weapon and armour refined to at least +1/+1; **extinguish Ignarok, the First Flame**; return to Brann for
  his **masterwork: +2/+2 forge (up to +5) and 3 talent points**.
- The objective line and the compass follow every step (the Elder's three quests keep priority until they are finished).
  Old saves and early kills catch up (a Guardian killed long ago counts as the Warden Core in hand).
- The quest log (Hero page) lists Brann the Exile and Thornwood Toll with their state.
- **All of Brann's dialogue is mine**: the HTML export kept only the titles and the toasts. Where the Warden Core comes from (the Guardian)
  and where the door stands (south of the Peaks) are my choices. Not yet: the Frostreaver and Glacial Aegis ("found through Brann's
  questline" in the HTML game) are still not obtainable.
- `tests/storytest.gd` (42 checks); all older suites still pass.

## 0.12.0 — the forge: Garen refines what you carry
- **Blacksmith Garen** now asks what you need: *Buy armour*, *The Forge*, or *Leave* (the first use of the choice list outside the
  parley). The Forge refines the weapon and the armour you carry, **+1 to +5 each**: +2 ATK per weapon level, +1 DEF per armour level.
- Each level costs herbs and essence (level 1: 1 + 1, up to level 5: 5 herbs + 3 essence), a few coins (40 x level), and from level 4 on
  **obsidian** (1, then 2): the three shards on the Emberforge map finally have a use.
- A refinement stays when you buy a better blade or plate. The strings (title, "Garen can refine what you already carry",
  "Maximum refinement") come from the HTML game; **the numbers are mine**: the HTML data has no forge tables.
- Fixed: the HTML game has no obsidian quest (it was wrongly suggested): obsidian is a material only.
- `tests/forgetest.gd` (40 checks); all older suites still pass.

## 0.11.0 — alchemy: Miri's cauldron, and five scrolls
- **Alchemist Miri** (village): a few words the first time, then her cauldron. Eight recipes from the HTML game: Health Potion
  (1 herb), Mana Potion (2 herbs), Greater Potion (3 herbs + 1 essence), and the scrolls Fire (2 essence), Ice (2 essence),
  Regeneration (2 herbs + 1 essence), Frost Lance (3 essence) and Haste (3 herbs + 2 essence); each also costs a few coins.
- **Herbs and essence now come from somewhere**: swamp foes drop herbs 12% of the time (forest 5%, elsewhere 2%) besides the
  Bogbloom lying about the fen; every boss gives 2 Mana Essences, a camp chief 1.
- **Scrolls are cast**: a Scroll button (key V / B) appears once you own one. Fire: a hard fireball. Frost Lance: a freezing lance,
  harder than the spell. Ice: freezes the nearest foe 3 s (kept if no foe is near). Regeneration: ~36% of your health over 8 s.
  Haste: +45% speed for 8 s. The Gear tab shows materials and your scrolls and lets you choose which one the button casts.
- `tests/alchemytest.gd` (63 checks); all older suites still pass.
- Known gaps: the numbers (herb drop rates, scroll strengths, essence amounts) are mine where the HTML tables did not say.

## 0.10.0 — gear, relics and things lying about the maps
- **Gear tab** in the pause menu: four slots (ring, belt, boots, amulet), the bag, Wear / Remove / Sell (8 / 25 / 70 / 200 gold
  by rarity). Items come in four rarities (common, rare, epic, legendary), with Persian names.
- All 16 accessory stats work: ATK, DEF, Crit, Speed, Max HP, Max MP, MP regen, HP regen, Lifesteal, HP per potion, Max Stamina,
  Block, Dodge time, Dash cooldown, Ultimate charge, and the **Phoenix Heart** (saves you once, then burns up).
- **Boss relics** (first kill only, worn at once if the slot is free): Guardian's Bulwark (-10% damage), Colossus Emberheart
  (reflect 30%), Matriarch's Fang (25% poison), Arbiter's boots (18% freeze), Ancient Wyrm's amulet (+40% ATK below 40% HP),
  Ignarok's ring (every 5th blow erupts in flame).
- **Drops**: common foes drop an accessory about 3.5% of the time, Varga the Red always drops a rare or better.
- **The map items** (21 in the HTML game, none were in the port): walk over them. Potions, mana potions, **Greater Potions**
  (+50 HP, drunk first when you are missing 50 or more), Bogbloom herbs, obsidian shards (counted for later), a frost scroll
  (counted for later), relics (rare/epic accessory), and the Crypt's chest (120 gold + a rare accessory). Each is found once.
- Known gaps: herbs, obsidian and scrolls are only counted so far (Miri's crafting and scroll casting come next);
  the relics' item names were not in the HTML strings, the accessory Persian names are mine; drop rates and sell prices are mine.
- `tests/geartest.gd` (50 checks). All older suites still pass.

## 0.9.0 — side quest: Thornwood Toll
- **Thalia** now has a word before you browse: bandits under **Varga the Red** robbed her caravan; her strongbox is in the
  Thornwood Camp. The quest shows in the objective line and the compass (once the Elder's story is done) and ends with
  Thalia's reaction, a gold reward and her **friends' price: 20% off** for good.
- **The camp**: Thalia's strongbox and Varga's ledger (taken from the HTML game's map data) lie in the camp. The ledger can be
  picked up at any time. Bandits keep their own rhythm; Varga's men hold their blades once a watcher notices you and
  **Varga calls a parley**.
- **Ways through** (no dice, only what you have earned): pay 200 gold; tell him about the Crypt (Guardian slain); [Paladin]
  mercy on the Ember (+50 gold, 2 potions); [Rogue] the Ashen Hand's mark (+100 gold); [Mage] conjure a dragon, 6 mana, the
  camp flees; the ledger (+150 gold); or fight (his men rally, Varga's fall scatters the camp). A struck deal holds until you
  attack; **sneaking** in (nobody notices) and lifting the box makes you a ghost; lifting it in plain sight turns the camp on you.
  Thalia reacts differently to each, and pays 100–300 gold.
- New choice list in the dialogue box (`Dialogue.choose`). Strings: `scripts/toll.gd`, from the HTML game.
- Known gaps: Varga's mother's charm is stored (`toll.charm`) but accessories are not ported yet, so the paladin gets two
  potions and 50 gold in its place; the main story's objective comes first in the HUD until it is finished.
- `tests/tolltest.gd` (56 checks); all older suites still pass.

## 0.8.0 — sneak and shove
- **Sneak**: a toggle (key Z / Ctrl, touch footprints button). The hero walks at 55% speed and foes notice him only from
  about 45% of their normal range — less in tall grass (the maps' grass patches) and at night. A foe that notices
  you shows "!" and then chases from further away. An unaware foe struck while sneaking takes a triple-damage "Backstab!"
  (not bosses). Any swing, a hit taken or a shove ends the sneak.
- **Shove**: a short hard push (key F / H, touch button): foes in front fly back and are stunned 0.8 s; a boss only loses a
  little stagger and you step back. Costs 15 stamina; cooldown 2.2 s on a hit, 0.8 s on a miss. Works with the shield up.
- Touch layout: two small buttons left of the shield. `tests/stealthtest.gd` (36 checks). All older suites still pass.

## 0.7.0 — block and parry
- **Block**: a shield button (key C / N, touch button left of the roll). Hold it and a third of every blow gets through;
  the hero walks slower, cannot attack, and stamina regenerates slower. Each blocked blow costs stamina.
- **Perfect parry**: raise the shield in the 0.2 s before a blow lands and it does no damage at all, stuns nearby foes,
  jumps a boss's stagger meter, fills the ultimate (+8), gives back a little mana and stamina, with a "Parry!" flash.
- **Guard break**: if stamina cannot pay for a blow, the blow lands in full and the shield cannot be raised for 1.4 s.
  Poison/fire/ice ticks ignore the shield. Rolling or casting drops the shield.
- The shield shows as an arc in front of the hero (gold during the parry window, blue after). A first-time tip explains it.
- Touch layout: the Talk button moved up to make room. `tests/blocktest.gd` (29 checks); all older suites still pass.

## 0.6.0 — spells, ultimates, talents
The HTML game's skill systems, ported and built for phones.

**Mana and spells** (`scripts/skills.gd`, `scripts/caster.gd`, `scripts/fx/spells.gd`)
- A mana bar under health. Pool = class mana + 2 a level; it refills slowly (the mage faster), a little with every
  melee blow that lands, fully on level-up. Mana potions are back at Thalia's (6 gold, +10 and a fifth of the pool);
  when a spell needs mana you don't have, a potion is drunk for you. Key T drinks one by hand.
- The ten spells of the HTML game, learned as you level (cost and cooldown from FF_SKILLS):
  Arcane Bolt and Ember Nova (level 1), Chain Lightning (4), Ice Lance (6), Mending Light (8), Blink (10),
  Stoneshatter (12), Soul Drain (14), Battle Roar (16) — and Emberwall, Brann's gift once the Ember Colossus falls.
  Shots aim themselves at the nearest foe (thumb-friendly), stop at walls, light up the dark.
- Any class can cast; the mage pays half (CLASSES.manaMul), hits hardest (V12_BAL.MAGE_BOLT for the bolt, ×1.8 for the
  rest) and recovers 10% faster.
- Two spell buttons around the attack button show the bound spell, its cooldown, its price (red when you are short)
  and a lock if it is not learned yet. Bind any two in Menu → Skills. Keys: Shift/1/L and X/2/I.
- Freeze and stun from spells feed a boss's stagger meter, as before (they never lock a boss).

**Ultimates** — a star button that fills as you fight (hits, spell hits, hits taken, kills) and glows when ready (key R/3/U):
- Warrior, Whirlwind Strike: 3 s of spinning steel, everything around is struck every quarter second; half damage taken.
- Mage, Arcane Tempest: a meteor on every foe in view, three on a boss, each with a ground warning; sets them burning.
- Rogue, Shadow Dance: five teleporting critical strikes on the nearest foe; untouchable meanwhile.
- Paladin, Holy Smite: a pillar of light — damage and stun around you, 30% health back, poison/fire/ice cleansed.

**Talent tree** (TALENT_TREE): Might, Fortitude, Cunning — 15 talents, one point per level, ranks and requirements,
free reset. Every talent works: attack, crit, health (the new part comes filled), defence, heavy blows, ultimate damage,
speed, roll invulnerability, attack speed, XP, gold, Second Wind. Talents the port had no counterpart for were remade:
Block Mastery → hits taken −15%; Treasure Hunter → +25% gold. Heroes saved in 0.5 get all their points to spend.

**Interface**
- Menu → Skills: Spells (the ultimate with its meter, ten spell cards, tap 1 or 2 to bind) and Talents (three columns).
- A gold dot on the menu button while talent points wait; level-up banner tells what grew; "Skill learned" messages.
- Battle Roar shows as a status chip; the hero sheet lists mana and talent points, potions in one card.
- Class cards show mana and each class's ultimate. Touch buttons: a tap goes to the nearest button under the thumb;
  the potion moved left of the roll, the talk button above it.

**Tests**: `tests/skilltest.gd` (70 checks), `tests/skillshots.gd` (screenshots of every spell and the new screens).
All earlier suites still pass (autotest, uitest 30, fxtest 24, bosstest 45, balance bot 0 deaths) on Godot 4.6.2 and 4.7.2.

## 0.5.0 — a living world
The world, the fighting, the HUD and the menus, reworked after the 0.4 review.

**The world** (ports of the HTML VIS lighting, V15 props and weather, plus what the exported pictures lacked)
- Light and darkness: each region has its own darkness; outdoors it deepens at dusk and night (12-minute day,
  dawn / day / dusk / night) with a warm dawn, red dusk and blue moonlight. Lights carve it away: the hero's glow,
  lamps, torches, braziers, campfires, lava, vents, bolts, bosses, a faint glow on every enemy, flashes from hits.
  Drawn into a small offscreen light map and multiplied over the world (cheap on phones).
- Torches, braziers, campfires and the Trial's fire columns burn again (the exported pictures had no flames),
  blue flames on ice braziers, glowing lanterns, bubbling cauldron, smoking vents and chimneys, glow-shrooms;
  trees, bushes and reeds sway in the wind.
- Weather: rain over Fernbrook, fog in the forest and the bog, ash storms on the peaks, snow in the sanctum
  (30–60 s spells). Ambient life: falling leaves, fireflies at night, crypt dust, rising embers, spores, ice glints.
- Soft contact shadows under every hero, villager and enemy; a closer camera with look-ahead (Far / Normal / Near).

**Fighting**
- Pooled particle engine (no node per hit): directional hit sparks, debris in the enemy's colour, dust, smoke.
- Sweeping weapon arcs coloured by the sword's tier; a tiny hit-stop on every blow, longer on crits and heavy blows,
  a camera punch and a phone buzz on big hits.
- The hero breathes, bobs as he walks, kicks up dust, squashes when hit; the roll is a fast dash with a spin and
  afterimages. Enemies breathe, squash and lean when struck; armoured foes clank.
- Kills pop with smoke and a flash; coins and blue XP sparks fly to the hero. Level-up: a pillar of light and a banner
  with what grew (it waits until a boss banner is gone).
- Music: each region's generative tune from the HTML game, through a reverb; a darker, faster tune with a drum
  in boss fights. Rain, wind and night crickets. A heartbeat below 30% health.

**HUD and controls**
- Minimap (tap it for the full map), a gold quest arrow by the hero that points to the goal or the exit towards it
  (shortest walk over the regions' exits), time of day and weather under the minimap.
- Name plates, a speech bubble over the villager you can talk to, framed enemy health bars with a damage trail,
  larger HUD text, the map title moved to the top so it never covers the hero, a clearer joystick.

**Menus**
- Weapons, armour and potions drawn as items (every tier, framed in its rarity colour) in the shop and hero sheet.
- Hero sheet: the hero in his gear turning on a pedestal. Map tab: this region up close and the world map.
- Settings: music, vibration, camera, graphics (Full / Light for older phones), brightness, quest arrow.
- Title screen by night with embers rising.

**Size**: identical map-object pictures are stored once (78 files), so the APK stays under 30 MB.
**Tests**: `tests/fxtest.gd` (24 checks), `tests/uitest.gd` (30), `tests/perftest.gd`, `tests/fxshots.gd`.

## 0.4.0 — the interface, rebuilt
A full UI pass in the HTML edition's look (dark wood, gold trim), made for phones and Persian first.

- **Design kit** (`scripts/ui.gd`): one theme for every panel and button (merged into the engine's default
  theme — a theme set on a window never reached the HUD under its CanvasLayer), Vazirmatn + Cinzel fonts,
  38 Lucide line icons rendered at runtime from SVG paths (8 KB in total), bars, chips, portraits.
- **Title screen** over the living village: logo, Continue (class, level, place), New game -> four illustrated
  class cards with stat bars, Settings, language. Starting over warns that it replaces the saved hero.
- **HUD**: portrait cropped from the hero's current gear with a level badge, health (damage trail, glows when
  low) / stamina / XP bars, gold and potion chips, status icons with seconds left, quest tracker, menu button,
  ornamented map titles, one queued message band (no more overlapping texts), low-health vignette.
- **Touch controls**: icon buttons; attack shows its charge ring, roll its cooldown and low stamina, potion its
  count; the talk button pops in with the villager's name; styled joystick; UI size Small/Normal/Large; the
  phone's safe area (notches) is respected.
- **Pause menu** (new): Resume, Hero sheet (stats, gear, quests), Settings (language, sound, screen shake,
  UI size, how to play), Save & quit to the title.
- **Dialogue**: framed portrait, name tab, typewriter text (tap to finish the line, tap again for the next),
  page counter. **Shop**: the whole ladder of tiers as cards (owned / next / locked), gain over current gear,
  red price when short. Restyled boss bar, banners, death panel, intro card, damage numbers.
- A gold "!" over Elder Rowan when he has news; fades between maps; level-up message.
- Tests: `tests/uitest.gd` (27 UI checks driven by real input events), `tests/uishots.gd` (every screen).

## 0.3.0 — the v18 bosses
Port of the HTML v18 boss rework (v18_core.js, v18_bosses.js).

**Boss framework** (every boss and miniboss)
- Stagger meter under the boss bar: heavy blows (+10), plain hits (+1.25), perfect dodges (+12),
  wall/pillar crashes, ice and stun (they no longer lock a boss). Full meter = 3.2 s helpless, +50% damage,
  each stagger makes the next one harder (resistance up to 1.6).
- Phases at 66% and 33%: invulnerable roar, shockwave push, banner, new look (variant sprite).
- Telegraph engine: circles, lanes, cones, expanding shockwaves, lobbed rocks, enemy bolts, poison pools;
  one hit per volley; touching a rebuilt boss only grazes (25%).
- Perfect dodge: roll through an attack as it lands.
- Name card the first time you meet a story boss (pauses, tap to skip); banner afterwards.
- Boss bar at the top: name, health with damage trail, stagger meter, phase pips, the Colossus' armour state.
- Death in a boss fight -> "Rematch" at the arena (gold back, potions back) or respawn in Fernbrook.
- VANQUISHED banner, one-time hints, knockback never pushes the hero through a map exit.

**The four story bosses**: Guardian (sweep, charge into walls/pillars, bolt rings, grave pillars, eclipse),
Ember Colossus (magma armour, eruption + exposed core, fist + fissures, stomp, boulders, vents),
Marsh Matriarch (dive and surface, eggs, tongue pull, poison pool, spit),
Frostbound Arbiter (ice lances, leap, storm, ice echoes, hail).
Toad King, Anvil Warden, Varga, Ignarok: framework + an interim telegraphed kit (slam, charge, volley).

**Fixes found while porting**
- Boss health was multiplied by the v18 bonus twice (Guardian 7008 HP instead of 3047).
- Hazards were invisible and partly inactive: Ashen Peaks lava did nothing, ice only slowed 20%,
  poison ticked twice as often as in the HTML game. Lava pools, ice sheets, poison pools and the
  Emberforge's erupting vents are now drawn and behave as in the HTML game.
- Aim assist (v12): swings turn to the nearest enemy, lunge a little, hit diagonals and enemies on top of you.
- Touch: lifting a finger while the game is paused no longer leaves the hero walking on his own.
- Hero status effects: poison, burn, freeze (with HUD chips); weapon tier 3+ sets foes alight, tier 5 stuns,
  the mage's blows can freeze (as in the HTML game).
- Speeds use the HTML game's exact unit (62.5 px/s per "px per frame").

**Tests** (all pass): `tests/autotest.gd` (regressions), `tests/bosstest.gd` (45 boss mechanics checks,
`--bot` balance bot), `tests/bossshots.gd` and `tests/hzshots.gd` (screenshots).
```
godot --headless --fixed-fps 60 --path . -- --test res://tests/bosstest.gd
godot --headless --fixed-fps 60 --path . -- --test res://tests/bosstest.gd --bot --runs 6 [--natural]
```
