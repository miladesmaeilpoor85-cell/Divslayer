# Level design review — chapter 1 (Level Designer A)

Maps: village, forest, dungeon, peaks, shadowfen, camp. Nothing was run and nothing was edited; every number is
computed from `game/data/Maps/<map>.json` plus the code lines named below.

## How I measured (read this first)
- Indexes are 0-based positions in the JSON arrays (`enemySpawns[3]` = "enemy #3", `walls[5]` = "wall #5", ...).
- Arrival point = the other map's exit `spawnX+13, spawnY+34` (world.gd:284, the hero's feet).
- Enemy position = spawn `x+12, y+24` (default 24x24 body; bosses are bigger, so boss distances are +-15 px).
- Hero collision box is 26x34 (player.gd:82), not 20 px: I treat any gap under 40 px as a snag, under 60 as too narrow to fight.
- Exits cannot be left through during a boss fight within 400 px (world.gd:319-327). So "rolling out of the arena by
  accident" is already solved; I do not report it.
- NOT verified, the director should check: `_safe_arrival()` (3.5 s of calm for foes within 450 px, main.gd:250) is
  called only on load, respawn and rematch (main.gd:113, 246, 280). I found no call on an ordinary walk through an
  exit, and it skips bosses in every case. All "attacked on arrival" findings below assume that.
- NOT known: enemy stats (I could not locate the table in my budget), roll distance, whether spike traps are visible
  in the dark, where exactly the painted roads run (I read them off the 2 px/px previews).
- Systemic, all maps: the view is 427x192, so the hero sees 96 px up and down but common foes notice at 270 px and
  bosses at 420 px. Vertically, everything aggroes from 2.8 screens-heights away, unseen. Enemy placement north/south
  of an entrance matters far more than east/west.
- README "The world" boss coordinates (dungeon 663,764; peaks 373,234; shadowfen 473,234) do not match the JSON
  spawns (850,650; 560,120; 660,120) — a constant offset of (-187,+114). Do not use them as map coordinates.

---

## village (Zabol, 900x650)
Good: compact hub — every NPC is within 370 px (3.4 s) of the start, no foes, the Trial gate and Siavash sit on the
way to the forest exit, four plaza lamps make the centre the obvious anchor.

1. **The forest exit is the only way forward and it is dark.** Exit rect (880,260,20x120); the nearest lights are
   (545,297) and (545,482), r150, ending at x=695 — 185 px of unlit ground before the exit, and no light on the
   shrine arch either. On a 427 px wide view the exit is off-screen from the plaza (start to exit = 470 px).
   Fix: add light `{x:850, y:320, r:130, i:0.8, c:"#ffcf80"}`.
2. **The first walk bumps a wall.** playerStart feet (433,524); fountain wall #3 (416..488, 396..468) is 56 px
   straight north, exactly on the line to Zal (430,300). A new player's first stick push goes into a block.
   Fix: playerStart `{x:350, y:500}` (line to Zal then clears the fountain by 16 px). Note main.gd:113/245 also
   hard-code (433,524) for load/respawn.
3. **40 px alley to nowhere.** Between cottage wall #0 (bottom y=190) and #1 (top y=230), x 80..240: a 40 px slot
   (hero 26) leading only to the 80 px strip behind the cottages; no reward. Fix: wall #1 `y:190, h:150` (closes it).
4. Three corners (50,50), (850,50), (850,600) are 266-282 px from any content. Acceptable for a hub; low priority.

## forest (Whispering Forest, 1100x850)
Good: four painted roads meet at one crossroads (~560,430) and each leads to an exit; the bramble-ring chest at
(985,110) with wraith #5 guarding it is a proper off-path reward; the potion at (700,600) is 100+ px off the camp road.

1. **Arriving from the camp, a slime is 170 px away.** Arrival (600,820); slime #3 feet (512,674) = 170 px, due
   north-west, i.e. off the top of the screen. Fix: move enemy #3 (500,650) -> (860,700): 288 px from the camp
   arrival, 308 from the peaks arrival, and it fills finding 3.
2. **Leaving the Ember shrine, two slimes are at 245 and 253 px** (enemy #4 and #0; #3 at 255 goes away with fix 1).
   Arrival (330,496). Borderline and they are tier-1; leave unless playtests complain.
3. **South-east is empty.** (1000..1050, 800) is 360 px from any foe, item or exit; a 300x250 px corner with a tall
   grass patch at (883,679) and nothing to find. Fix 1 covers it.
4. **Arrival points sit on top of the exit they came through:** from camp 10 px, from peaks 27, from village 33
   (same pattern: dungeon 16, peaks-from-forest 10, village 17). The exit re-fires after 0.6 s once the hero has
   moved 20 px (world.gd:213-223), so a step back in a fight leaves the map. Fix where it costs nothing:
   camp.json exit #0 `spawnY 786 -> 750`; dungeon.json exit #0 `spawnY 60 -> 90`; village.json exit #0
   `spawnX 40 -> 70`.
5. No lights at all (`lights: []`). Five exits; the roads carry it by day. If nights are dark, add one light at the
   crossroads (560,430) r150.

## dungeon (Sunken Crypt, 1000x800)
Good: the boss brazier (860,676, r170) and the shrine brazier (140,676) are clear goals left and right; the cracked
closet with its chest in the top-left corner is a real secret; walls #1-#3 split the room into readable quarters.

1. **Three things notice the hero on the doorstep.** Arrival from the forest (453,764): wraith #2 at 194 px,
   skeleton #3 at 252 px, and Arzhang at 419 px feet-to-feet (~426 centre-to-centre) — 6 px outside his 420 px
   range. One step right starts the boss fight with two adds already chasing.
   Fix: enemy #2 (400,550) -> (180,480) [368 px away, now guards the shrine/chest corner];
   enemy #3 (650,600) -> (640,440) [360 px away, 296 from the boss, beside trap #1];
   forest.json exit #1 `spawnX 440 -> 400` (boss margin becomes ~45 px).
2. **A spike trap in the dark, 104 px straight ahead.** Trap #3 (450..510, 600..660); arrival x=453 is inside its
   x-range and the arrival is outside every light (nearest (320,638) r140 is 183 px away). First step north = 8 dmg.
   Fix: trap #3 `y 600 -> 480`, and add light `{x:480, y:700, r:140, i:0.85, c:"#ffb060"}`.
3. **The boss is 3.8 s from the door; three quarters of the crypt is optional and the far room is empty.**
   Door to boss = 419 px in a straight line with no wall on it. The NE room (x 440..1000, y 0..380, 560x380 px)
   holds archer #1, trap #2 and no reward: (950,50) is 448 px from any content. Both rewards (item chest (150,600),
   closet chest (30,36)) and the shrine are on the west side.
   Fix: move item #0 chest (150,600) -> (920,80). It currently sits 12 px from the shrine arch pillar (138 -> 150).
4. **Skeleton #3 is 206 px from the boss** and joins the fight every time (fixed by the move in 1; if you keep it,
   keep it over 300 px from (862,674)).
5. Boss arena (x 600..1000, y 420..800 = 400x380): no static wall within 250 px of the boss except pushable barrel
   b3 (615,560) at 233 px. Room to roll is fine; the "bait his charge into a wall" lesson has only wall #2
   (254 px north) and the map edges (126-138 px) to work with. No change proposed; say it in the boss tip.

## peaks (Ashen Peaks, 1150x920)
Good: relic at (1000,800) is 427 px off the entry-to-boss line with imp #4 and golem #6 guarding that side — the
best reward pull of the six maps; arrival from the forest is clean (nearest foe 340 px).

1. **The Emberforge door and a spire wall off the road 84 px north of the entrance.** Arrival from the forest
   (573,890). Door rect (520..630, 790..806) is added in code (world.gd:161), exactly across the road; spire wall #8
   (640..690, 760..830) starts 10 px to its right, so together they block x 520..690. Sealed: the first thing the
   player meets is a "sealed" message and a 40 px push back. With the key: walking north up the road warps to the
   Emberforge every time. Coming back out of the forge the hero lands at (573,854): 48 px under the door, 46 px
   above the forest exit.
   Fix (data): wall #8 `x 640 -> 720` and object spire_70 `x 665 -> 745` (opens an 90 px lane right of the door).
   Fix (code, better): move the door rect off the road, e.g. `x:700` beside the spire, or require an interact.
2. **A golem stands 113 px from the Fuse shrine's way out.** Arrival (110,376); golem #5 feet (212,424). Also
   241 px from the shadowfen arrival (93,634).
   Fix: enemy #5 (200,400) -> (400,470): 324 px and 348 px. (It then sits 124 px from imp #3; acceptable, or
   nudge imp #3 (350,600) -> (330,660).)
3. **The King's arena is about 230x230 px.** Boss feet (572,144): lava hazard #0 (560..670, 250..320) 106 px south
   and on the road line (road x~573, hazard starts x=560); spire wall #1 102 px west; top edge 144 px; bats #2 and
   #1 at 143 and 255 px both join the fight.
   Fix: hazard #0 (560,250) -> (610,340) [arena depth 230 -> 320 px, road clear by 24 px];
   enemy #2 (700,150) -> (950,300) [430 px from the boss, fills the empty NE corner, 400 px from any content].
4. **Spire wall #5 stands on the road.** (520..570, 420..490); the road and the straight line entrance-to-boss run
   at x~560-573. Fix: wall #5 `x 520 -> 470`, object spire_67 `x 545 -> 495`.
5. **No lights (`lights: []`) on a map with six ways out** (forest, shadowfen, sanctum, damavand, shrine, forge door).
   Fix: add `{x:572, y:150, r:170, i:0.9, c:"#ff9a40"}` at the boss and `{x:573, y:860, r:130, i:0.8, c:"#ffb060"}`
   at the forest entry.

## shadowfen (Shadowfen Bog, 1200x1000)
Good: the glow-shrooms and tall grass give the bog its own navigation texture; herbs are placed as risk/reward
(one inside poison pool #4, one 37 px from a wisp, one tucked under the log 214 px off the entry line); the relic
essence at (520,60) sits behind the boss.

1. **The Toad King fights in a 120 px pocket.** Spawn feet (392,904): poison #6 ends at x=360 (32 px left),
   poison #7 starts at x=480 (88 px right), map edge 96 px below, willow wall #9 74 px above. Any roll lands in poison.
   Fix: hazard #7 `x 480 -> 640` (free ground becomes 280 px wide; it ends flush with hazard #8 at 800).
2. **Nothing leads to the Sorceress.** The boardwalk runs from the peaks exit to the Tides shrine (1010 px west);
   the boss is 588 px north-west at (672,144) with no path and no light (nearest shroom light 172 px away, r80).
   Only the compass points there. Fix: add light `{x:700, y:170, r:170, i:0.85, c:"#c070ff"}`; ideally a second
   one halfway at (880,360).
3. **A lurker is 176 px from the entrance, inside a pool that lies on the boardwalk.** Arrival (1093,554);
   enemy #7 (920,600) is inside hazard #5 (820..960, 600..680), which the planks cross on the preview (verify).
   Wisp #10 is at 270 px. Fix: hazard #5 (820,600) -> (760,640); enemy #7 (920,600) -> (800,660) [310 px].
4. **The Sorceress's own floor is a 140 px funnel.** She spawns flush against boulder wall #2 (0-12 px, verify she
   cannot snag), with poison #1 ending at x=640 and poison #2 starting at x=780 just south of her; toad #3 at 190 px
   joins. Fix: hazard #1 (520,220) -> (430,250) [funnel 140 -> 230 px]; enemy #3 (600,300) -> (600,420) [278 px].
5. **Thirteen foes on an even grid, weakest last.** Nearest-neighbour distances are all 156-242 px: no clumps, but
   also no quiet stretch anywhere on a 1200x1000 map. The three mosquitos (first, so presumably weakest, in the
   list) sit in the far NW corner, ~900 px from the entrance and beyond the boss; the first contacts are a lurker
   and a wisp. Fix: swap types of enemy #10 (wisp at 940,300 -> mosquito) and enemy #0 (mosquito at 180,160 -> wisp).
   Check the stat table before doing it.

## camp (Thornwood Camp, 1200x900)
Good: best-authored map of the set — one readable road from the exit to a torch-lit gate, three gates (120, 80,
72 px), grass lanes outside the west and east gates for the sneak route, the ledger and strongbox as two different
side goals, arrival clean (nearest bandit 301 px).

1. **30 px slots behind the tents.** Store tent wall #7 (210..330, 180..250) is 30 px from the north palisade and
   30 px from the west palisade; the captain's tent wall #8 is 30 px from the north and 40 px from the east one.
   The hero is 26 px wide: 2 px clearance a side on a touch stick, and the strongbox (238,262) sits at the mouth of
   one. Sleep tents #9/#10 leave 40 px above the south palisade.
   Fix: grow the collision only — wall #7 `{x:180, y:150, w:150, h:100}`, wall #8 `{x:820, y:150, w:200, h:120}`,
   walls #9/#10 `h 70 -> 110`.
2. **If the alarm goes up, everything is on one screen.** Six foes within 300 px of the captain (598,416),
   nearest-neighbour 90-139 px, two of them archers. By design there are the parley and the sneak; just make sure
   the fight version is tested as a 7-on-1. No data change proposed.
3. **The outside ring south and east is dead.** The strip y 780..900 (1200x120 px) and the SE corner — (1150,850)
   is 625 px from any content — hold nothing; a full lap of the palisade is ~28 s of walking. The grass at
   (1062,600) and (1066,250) suggests a route, but only the east gate (y 300..372) pays off.
   Fix: put one pickup at the far end, e.g. item `{x:1100, y:830, type:"herb"}` — but check `_camp_setup`
   (world.gd:680-686) first, it routes every camp item through `_pickup`.
4. Barrel b4 (250,600) is 22 px from sleep tent #9 and barrel b2 (640,410) is 42 px from the captain's feet; both
   are pushable so they are not traps, but b2 will be shoved by the captain's first step. Low priority.

---

## Top 10 across chapter 1
1. peaks — Emberforge door (520..630, 790..806) + spire wall #8 block the road 84 px north of the forest entrance;
   with the key it warps on every pass. Move wall #8 to x=720, or move the door in world.gd:161.
2. dungeon — on arrival: wraith 194 px, skeleton 252 px, boss 6 px outside his range. Move enemy #2 -> (180,480),
   enemy #3 -> (640,440), forest.json exit #1 spawnX -> 400.
3. peaks — golem #5 is 113 px from the Fuse shrine's arrival point. Move to (400,470).
4. shadowfen — Toad King's pocket is 120 px wide between two poison pools. Hazard #7 x -> 640.
5. peaks — boss arena ~230x230 with lava on the road and two bats in range. Hazard #0 -> (610,340), enemy #2 -> (950,300).
6. shadowfen — no path or light to the Sorceress; the boardwalk leads to the shrine instead. Add a light at (700,170) r170.
7. shadowfen — lurker 176 px from the entrance inside a pool on the boardwalk. Hazard #5 -> (760,640), enemy #7 -> (800,660).
8. dungeon — boss 3.8 s from the door, NE room (560x380) empty, both rewards in the SW. Move chest item #0 -> (920,80).
9. camp — 30 px slots behind the store and captain's tents (hero is 26). Grow walls #7/#8 to close them.
10. dungeon — unlit spike trap #3 104 px straight north of the door. Trap y -> 480, add a light at (480,700) r140.

Runners-up: forest slime #3 at 170 px from the camp arrival (move to (860,700)); arrival points 10-33 px from their
own exit on five maps; shadowfen Sorceress funnel (hazard #1 -> (430,250)); village forest exit unlit.

## To verify before acting
- Whether foes really get no calm period on a normal exit transition (main.gd `_safe_arrival` call sites).
- Whether hazard #5 in shadowfen really overlaps the boardwalk art, and where the peaks road runs relative to wall #5.
- Enemy tiers (mosquito/toad/lurker/wisp) before the type swap in shadowfen.
- Boss body sizes: the matriarch's box against boulder wall #2 at spawn.
