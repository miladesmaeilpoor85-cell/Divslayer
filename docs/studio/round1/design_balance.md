# Ember & Iron 0.26.1 — balance report (game designer)

FINAL after 9 of 10 runs (runs/design/001-009). Every run: `play.sh design <scenario> 854x400`, `setting diff=normal`, the fighting bot (no block/parry, no boss weak points). Scenarios are in runs/design_scenarios/.
Test shortcuts in every run: `preset` (sets level, gear, potions, gold, quests) and `goto` (to the map's normal entrance, so the bot clears the regular foes on its way to the boss, as a player does). Runs 004 and 008 also used `set` (level/gear/potions).
**Caveat for every result:** presets spend NO talent points and have no forge levels, relics or sigils (tests/playtest.gd:316-360). A real player at the same level is stronger. A bot loss means "hard for an average player who has not built the hero yet", not "impossible".

## 1. Formulas used (from code)
- Hero: HP = class hp + 8/level; ATK = class atk + 2/level + weapon; DEF = class def + 1/level + armour (scripts/game.gd:361, 367, 374). Damage taken is cut by DEF/(DEF+60), at most 60% (game.gd:496).
- XP to next level: 40, then x1.35 each level (game.gd:344, 589). Cumulative XP needed: L4 166 · L6 393 · L8 804 · L9 1122 · L12 2911 · L13 3965 · L16 9896 · L18 18111.
- Foe HP = base x area hp x boss hp; foe hit = round(base x boss dmg) x area dmg (game.gd:507-517, 497; data/Tables/ENEMY_TYPES.json, V12_BAL.json AREA/BOSS).
- Potion: +20 + 20% max HP. Greater Potion: a flat +50, drunk FIRST whenever 50+ HP is missing (scripts/player.gd:710-719). No carry cap on potions (none found in shop.gd or game.gd).
- Gold: regular foes and bosses pay ENEMY_TYPES gold; boss kill bonus 30/60/80 (game.gd:734); Zal pays 100/300/500 (game.gd:683); Jamshid pays 350 after Pulad of Ghandi (game.gd:1127); bounties pay need x gold x 2 + 15 gold and need x xp x 1.5 XP (game.gd:972-973).

## 2. The curve
"Story lvl" is an ESTIMATE: XP of every regular foe on each map killed once (data/Maps/*.json, counted by script) plus the bosses before it. It leaves out bounties, re-clears and shrine/training XP. HP and hit are computed, before the hero's DEF.

| Boss (map) | HP | hit | Story lvl (est.) | Preset | Pahlavan | Sage | Ayyar | Oathbearer |
|---|---|---|---|---|---|---|---|---|
| Arzhang (dungeon) | 3,047 | 8.5 | L3-4 | act1 L4, 2/1, 3 pots | win, low <40%, 2 pots (known) | win ~20 s, low 22%, 3 pots (known) | win, low ≤70%, 1 pot (known) | win, low 53%, 0 pots (known) |
| King of Mazandaran (peaks) | 5,846; takes half damage in magma armour | 15.2 | L6 | act2 L8, 3/2, 4 pots | **LOSS** 36.2 s, King at 16%, 4/4 pots (002) | **LOSS** 34.5 s, King at 10%, 4/4 pots (003) | win 27.4 s, low 22%, 3 pots (008) | win 60.8 s, low 27%, 4/4 pots (008) |
| Sorceress (shadowfen, with Bid the Div 1,863 HP) | 10,698 | 18 | L9 | act3 L12, 4/3, 5 pots | win 39.8 s, low 21%, 4 pots (003). **At story L9, 3/2: LOSS** 39.0 s, Sorceress at 10% (004) | win 44.8 s, low 28%, 5/5 pots (004) | - | - |
| White Div (sanctum) | 16,505 | 27 | L13 | ch2 L16, 5/4, 6 pots | win 31.4 s, **low 84%, 0 pots** (005) | win 51.7 s, low 24%, 3 pots (005) | - | - |
| Zahhak (zahhakcave) | 42,120 | 57.2 | L16 | ch3 L18, 6/5, 7 pots | **LOSS** 60.8 s, Zahhak at 28% (006) | **LOSS** 58.6 s, Zahhak at 52% (007) | **LOSS** 44.4 s, Zahhak at 30% (009) | **LOSS** 61.0 s, Zahhak at 51% (009) |

Not run (HP / hit): Pulad of Ghandi 4,408 / 15.8; Puladvand 12,621 / 25.2; Akvan 13,312 / 45.6; the Dragon of Kashaf 36,400 / 44; Kondrow 7,104 / 42.

Reading the curve:
- Boss HP goes 3.0k → 5.8k → 10.7k → 16.5k → 42.1k.
- The Pahlavan's ATK with preset gear goes 22 → 37 → 53 → 71 → 87.
- Hits the Pahlavan needs to kill the boss (HP / (ATK x 1.2)): 115 → 132 (more in the magma armour) → 168 → 194 → **403**.
- Boss hits the Pahlavan can take (his HP / the hit after DEF): 8.4 → 7.8 → 9.7 → 9.0 → **5.1**.

So the curve has two walls, the King and Zahhak, with an easy stretch between them (the Sorceress at L12, the White Div at L16).

## 3. Problems, ranked
1. **Spike: Zahhak, the last boss, beats all four callings at the ch3 preset (L18, best gear, 7 potions).**
   - Measured: 006 STEP 5, Pahlavan `the hero fell after 60.8 s · ... damage taken 646 · lowest hp 0% · potions 8`, Zahhak at 28%. 007 STEP 5, Sage, Zahhak at 52%. 009 STEP 4, Ayyar, Zahhak at 30%. 009 STEP 12, Oathbearer `damage taken 821 · potions 7`, Zahhak at 51%.
   - Every loss ran out of potions, so damage is a problem, not only HP.
   - From the tables: 2.55x the White Div's HP and 2.1x its hit, while the hero gains only 1.23x ATK and 1.1x HP. A potion (+55 HP at L18) heals about one Zahhak hit.
   - A story player reaches him at about L16 (estimate), so weaker still.
2. **Spike: the King of Mazandaran, the 2nd boss.**
   - Measured at the act2 preset (L8, Mythril/Chainmail, 4 potions): Pahlavan and Sage lose (002 STEP 4, King at 16%; 003 STEP 4, King at 10%; 001 STEP 5, King at 48% when the hero was dropped next to him with the whole peaks mob). Ayyar and Oathbearer win only just, with 1 and 0 potions left (008 STEP 4, 12).
   - He comes right after a boss every calling beats at the first try.
   - From the tables: 1.9x Arzhang's HP plus the magma armour, while hero damage rises 1.68x.
   - A story player arrives at about L6 with Steel/Leather (estimate), not at L8 with Mythril/Chainmail.
3. **The presets, and so the tuning, are 2-3 levels and about one gear tier above a player who follows the story.**
   - Levels (estimated from tables): L6 vs L8 at the King, L9 vs L12 at the Sorceress, L13 vs L16 at chapter 2, L16 vs L18 at Zahhak.
   - Gold in one pass (estimated): about 393 by the King vs 835 of preset gear; about 1,150 (+350 from Jamshid) by the Sorceress vs 2,115.
   - Measured where it matters: at the story level (L9, 3/2) the Sorceress wins (004 STEP 20, Sorceress at 10%). The L12 preset beats her with 21-28% HP left (003, 004).
   - Bounties may close the gap: each pays about 1.5x the XP and 2x the gold of its kills. Not measured.
4. **Potions are close to free and have no cap, so they bypass the tuning.**
   - The same Pahlavan who lost to the King with 4 potions wins with 12 (008 STEP 21 `the area is clear after 54.0 s · ... damage taken 532 · lowest hp 21% · potions 12`). That is 64 more gold, and every losing hero had 279-314 gold left (001, 002, 003).
   - Measured gold per area clear is 400-550 (before/after: 003 500→1032, 005 900→1294 and 900→1357, 008 300→716). A potion costs 8.
   - This is a design decision more than a number (for example a carry cap of 5 + 1 per chapter), so it is not in my 6 changes. Note that every boss HP cut below makes potion-chugging easier still.
5. **Economy: the Greater Potion is a trap from about L15** (estimated from player.gd:710-719 and SHOPS.json "hesk").
   - At Hom a normal potion costs 10 and heals 20+20%: 52 at L16 Pahlavan, 55 at L18. The Greater costs 40, heals a flat 50 and is drunk first.
   - Hom sells it only in chapter 2 (frostvale), where every hero is about L14 or higher.
6. **Dead zone, at preset level only: the White Div for the Pahlavan.**
   - 005 STEP 4 `the area is clear after 31.4 s · ... lowest hp 84% · potions 0`. The Sage needed 3 potions (low 24%).
   - At the story level (L13, est.) the fight would be harder, so I make no change until problem 3 is settled.
7. **Callings: none is clearly too strong or too weak.**
   - Pahlavan: worst at the King (he takes 7.0 HP/s, against Ayyar 4.9, Oathbearer 5.2, Sage 6.5: runs 002, 008, 003), but best at the White Div and Zahhak.
   - Sage: weakest at Zahhak (52% left) and at the White Div.
   - Ayyar: fastest at the King (27.4 s).
   - Oathbearer: slowest (60.8 s at the King, 51% left at Zahhak).
   - One thing to watch: the "tank" Pahlavan takes the most damage per second at the King, because the bot does not block. Check again once the bot blocks.

## 4. Changes (at most 6, in priority order; none tested, because the workspace is frozen)
| # | File:line | Old → new | Effect |
|---|---|---|---|
| 1 | data/Tables/V12_BAL.json:70 (BOSS.boss2.hp) | 5.22 → 4.3 | King 5,846 → 4,816 HP (-18%). The two losers stopped with 10-16% of his HP left; the rest of the cut covers the damage they take in the extra time. Ayyar and the Oathbearer would finish with potions to spare. |
| 2 | data/Tables/V12_BAL.json:102 (BOSS.zahhak.hp) | 9.0 → 7.0 | Zahhak 42,120 → 32,760 HP (-22%, still 2x the White Div). The Pahlavan (28% left) and the Ayyar (30%) would win at the preset level. |
| 3 | data/Tables/V12_BAL.json:57 (AREA.zahhakcave.dmg) | 2.2 → 1.8 | Zahhak's hit 57 → 47, and the cave's serpents hit 18% less. An L18 Pahlavan takes about 6 hits instead of 5 to fall. With #2, the Sage and the Oathbearer (51-52% left) come within reach of a skilled player, though not of the bot. |
| 4 | data/Tables/V12_BAL.json:74 (BOSS.matriarch.hp) | 6.84 → 6.0 | Sorceress 10,698 → 9,384 HP (-12%). The story-level L9 Pahlavan, who stopped with her at 10%, would just win. At L12 it stays a fight (low 21-28% today). |
| 5 | scripts/player.gd:719 | `50.0 if big` → `50.0 + floorf(Game.max_hp() * 0.3) if big` | The Greater Potion stays better than the normal one at every level (L16: 98 vs 52). This fixes the trap without touching the price. |
| 6 | scripts/game.gd:589 | `* 1.35` → `* 1.30` | ESTIMATE. The one-pass story player would be L14 instead of L13 at chapter 2, and L18 instead of L16 at Zahhak (cumulative XP to L18 drops 18,111 → 11,073). Chapter 1 does not change (still L6 at the King), so #1 and #4 are still needed. Lowest priority: verify with a played story run first. tests/playtest.gd:324 also hard-codes 1.35 for the presets. |

## 5. Not measured
- The bosses not run: Pulad of Ghandi, Puladvand, Akvan, Kondrow, Bid the Div alone, Ashkbus, and the Dragon of Kashaf (36,400 HP, the second-highest in the game, in chapter 2 at est. L14-16, a likely third wall).
- Ayyar and Oathbearer at the Sorceress and the White Div. Any fight on Story, Hard or Nightmare.
- Any boss fought alone: every run includes that map's regular foes, the way a player meets them.
- Bounties (the contract pool and how fast they pay), respawning foes, shrine/training/chest XP and gold. So the "story level" and gold figures are estimates from the map tables.
- Talents, forge levels, relics, sigils, accessories: presets have none. Real heroes will do better than the bot, most of all late in the game, where these sources stack.
- Blocking and parrying (the bot never does either), boss weak points (pillars, eggs, charges into walls), and the King's magma armour on its own.
- Odd numbers seen but not chased: after killing the King, the Ayyar shows 94/129 HP at L9 and the Pahlavan 104/139 (008 STEP 5, 22), above the formula (94, 104). Probably a gear drop; worth an engineering look.

## Raw run results
- 001 (act2, goto 373,330, next to the King with the whole peaks mob): Pahlavan L8 `the hero fell after 24.6 s · foes down 5 · damage taken 254 · lowest hp 12% · potions 4`, King at 48%. The Sage fight did not start because the death panel was still open (a kit issue; later runs fix it with wait 4 + tap_text "زنده شدن").
- 002 (act2, from the forest entrance 575,860): Pahlavan L8 `the hero fell after 36.2 s · foes down 7 · damage taken 253 · lowest hp 1% · potions 4`. All 7 regular foes dead, King at 16%.
- 003: Sage L8 act2 `the hero fell after 34.5 s · foes down 5 · damage taken 225 · lowest hp 12% · potions 4`, King at 10%. Pahlavan L12 act3 (shadowfen from 1080,640) `the area is clear after 39.8 s · foes down 34 · damage taken 247 · lowest hp 21% · potions 4`. Sorceress dead (objective "return to Zal"), gold 500→1032.
- 004: Sage L12 act3 `the area is clear after 44.8 s · foes down 29 · damage taken 282 · lowest hp 28% · potions 5`, Sorceress dead. Story-level Pahlavan (act3 preset, then level 9, weapon 3, armour 2, 4 potions, save+continue → 104/104 HP) `the hero fell after 39.0 s · foes down 32 · damage taken 264 · lowest hp 0% · potions 4`, Sorceress at 10%.
- 005 (ch2 L16, 5/4, 6 potions; sanctum from 60,540): Pahlavan `the area is clear after 31.4 s · foes down 11 · damage taken 173 · lowest hp 84% · potions 0`, White Div dead (objective "talk to Zal — the earth trembles", gold 900→1294). Sage `the area is clear after 51.7 s · foes down 20 · damage taken 226 · lowest hp 24% · potions 3`, White Div dead (gold 900→1357).
- 006 (ch3 L18, 6/5, 7 potions; zahhakcave from 600,90): Pahlavan `the hero fell after 60.8 s · foes down 16 · damage taken 646 · lowest hp 0% · potions 8`, Zahhak at 28%.
- 007: Sage, same setup, `the hero fell after 58.6 s · foes down 12 · damage taken 604 · lowest hp 11% · potions 8`, Zahhak at 52%.
- 008 (act2 L8, King from the entrance): Ayyar `the area is clear after 27.4 s · foes down 8 · damage taken 135 · lowest hp 22% · potions 3`, WIN. Oathbearer `the area is clear after 60.8 s · foes down 8 · damage taken 315 · lowest hp 27% · potions 4`, WIN (0 left). Pahlavan with potions set to 12 `the area is clear after 54.0 s · foes down 8 · damage taken 532 · lowest hp 21% · potions 12`, WIN (0 left).
- 009 (ch3 L18, Zahhak): Ayyar `the hero fell after 44.4 s · foes down 14 · damage taken 601 · lowest hp 15% · potions 8`, Zahhak at 30%. Oathbearer `the hero fell after 61.0 s · foes down 14 · damage taken 821 · lowest hp 11% · potions 7`, Zahhak at 51%.
