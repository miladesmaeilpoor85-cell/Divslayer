# Level review, chapters 2-3 (Level Designer B)

Maps: sanctum, frostvale, wyrmhollow, emberforge, damavand, zahhakcave. Nothing was run and nothing edited; every number
is measured from data/Maps/*.json with scripts (4 px grid, so distances are +-3 px).

Conventions used (read from scripts/world.gd, enemy.gd, player.gd):
- A spawn's JSON x,y is its top-left; the foe's feet are (x + w/2, y + h). Its collision box is 0.8*w wide, min(h,18)
  high, bottom on the feet. The hero's box is 26x34, bottom on the feet. An arrival's feet are (spawnX+13, spawnY+34).
- Only data.walls collide (objects with isWall are already in that list).
- Common foes have NO unstick step on spawn (only bosses call _unstick). An item is picked up when the hero's feet are
  within 26 px of (x + w/2, y + h).
- "STUCK" below = the foe's collision box overlaps a wall rect at spawn. Not verified at runtime: Godot may squeeze the
  body out or leave it wedged; either way the placement is wrong. QA should look at each one.

## Cross-map defect: 16 foes spawn inside walls, 7 items sit where the hero may not reach
| map | foe # / type | spawn now | wall hit (depth) | nearest clear spawn |
|---|---|---|---|---|
| zahhakcave | 0 serpentguard | (560,180) | (506,206,188,38) 8 px | (524,160), better (368,256) |
| zahhakcave | 1 serpentguard | (630,190) | same, 18 px | (654,162), better (808,256) |
| wyrmhollow | 2 frostknight | (640,210) | (556,206,188,38) 14 px; hero cannot get nearer than 49 px | (612,158) |
| wyrmhollow | 1 skeleton | (720,175) | same wall, 5 px | (716,159) |
| wyrmhollow | 7 wyrmling | (360,580) | (345,614,50,70) 10 px | (348,560) |
| wyrmhollow | 8 rimewraith | (240,620) | (6,656,238,38) 1 px | (240,608) |
| frostvale | 3 frostknight | (1061,157) | (1060,170,50,60) 25 px | (1021,157) |
| frostvale | 9,10,11 frostwolf | (497,205) (451,202) (468,188) | tree (468,193,40,60) 8/10/17 px | (517,185) (431,202) (468,160) |
| frostvale | 17 frostwolf | (660,959) | (650,960,40,60) 21 px | (660,927) |
| frostvale | 6 crystalSpider | (1137,933) | (1155,930,50,70) 5 px | (1121,933) |
| damavand | 1 serpentguard | (188,296) | Kondrow's gate pillar (199,306,50,60) 10 px | (258,316) |
| damavand | 2 serpentguard | (418,286) | gate pillar (393,304,50,60) 16 px | (358,316) |
| damavand | 29 imp | (590,1076) | (580,1055,50,70) 28 px | (550,1076) |
| damavand | 25 serpent | (1335,1030) | (1330,1047,50,70) 3 px | (1335,1014) |

Items (nearest reachable hero position vs the 26 px pickup radius):
| map | item # | now | reach | move to |
|---|---|---|---|---|
| frostvale | 5 greater_potion | (1040,610) inside ring pillar (1022,587,50,70) | 42 px: unreachable | (1000,610) |
| damavand | 1 potion | (1420,300) | 34 px | (1452,300) |
| damavand | 0 potion | (120,900) | 30 px | (120,928) |
| damavand | 5 obsidian | (470,160) | 30 px | (470,132) |
| wyrmhollow | 4 greater_potion | (1060,715) | 27 px (borderline) | (1060,739) |
| frostvale | 6 page1 | (380,135) | 22 px (reachable, tight) | (400,135) |
sanctum and emberforge: no stuck foe, no unreachable item.

## sanctum (Crystal Sanctum, 1200x1000, 96% walkable, 16 foes, 52 lights)
Good: no stuck foes, no chokes (narrowest point on the route 186 px), Sorush at the centre (600,500) is on the line
from the south arrival to the boss, every exit is lit.
1. The way back to the peaks is not where you came in. Peaks -> sanctum lands at feet (573,974) (bottom centre), but
   the exit to the peaks is the west edge (0,480,20,120): 743 px of path away, out of the 427x192 view. A player who
   turns round to leave finds a wall. Fix (smallest): in peaks.json exit "sanctum" set spawnX 560 -> 30, spawnY 940 ->
   506 (arrive at feet (43,540), 30 px from the door, like the frostvale side does).
2. The arbiter stands on ice. Boss feet (627,204); ice rect (600,200,140,80) starts 4 px under him (centre 56 px
   away). Melee from the south or east means standing on a freeze-every-0.8-s tile. Pillar (540,100,50,70) is 93 px
   west. Fix: move hazard #2 from (600,200) to (600,300).
3. Difficulty order is upside down. From the peaks arrival the first foes inside 270 px are frostknights #12 (213 px)
   and #10 (263 px), 46 hp each, with ice (520,880,180,80) 14 px north of the arrival; the 16-hp icelings (#0-#4,
   y 160-280) are the row next to the boss. Fix: swap types #12 <-> #1 and #10 <-> #3 (knights north, icelings south).
4. Two icelings fight alongside the boss: #2 at 99 px and #3 at 142 px from the arbiter. Fix: move #2 from (520,160)
   to (420,100) (if finding 3 is not applied, at least this).
5. Uniform grid: foes every ~200 px (nearest neighbours 99-283 px), so 2-4 are in aggro anywhere and up to 6 at
   (740,500). Leaving shrine_light (feet (330,496)) puts #5 138, #6 145, #9 146, #1 197 px away. Fix: move #9
   frostknight from (280,600) to (60,700), and #6 from (460,500) to (460,620) (still 4 -> 2 at the shrine door).
   The SE golem #14 (940,880) guards nothing (nearest item 700+ px): move item 1 potion (1080,120) -> (1100,900).

## frostvale (Hoarfrost Vale, 1400x1100, 23 foes, 9 lights)
Good: the safest arrival of the six (no foe inside 270 px, Hom's camp 370 px away), the ice lake is a clear landmark
between the door and the boss, and the pages/scroll pull the player to three corners.
1. Six stuck foes and the unreachable greater potion in the ring pillar (table above). #3 is the guard of the chest
   at (1015,188), buried 25 px.
2. Akvan's ring is a cage. Free distance from boss feet (1170,558): E 132, S 68, SW 84, N 132-144 px; the only way in
   or out is the west gap, 127 px (y 460-587 at x ~1021-1072). Interior about 270x210 for a 64x70 boss: one roll from
   a pillar anywhere, and the south pillars are 68 px behind the boss. Fix: delete the two south-west ring walls
   (1022,587,50,70) and (1080,615,50,70) (and their objects) to give a second opening and ~120 px more floor.
3. South-east clump: at (980,800) ten foes are inside 270 px (#4-#8 spiders/icelings, wolf pack #12-14, #15, #21).
   Fix: move the wolf pack #12,#13,#14 from (802..811,737..761) to around (560,820) (300 px west).
4. The straight line door -> boss (y 540 -> 558) crosses 380 px of ice (x 508-890) with 3 icelings on it; the path
   round the north is 1158 px = 10.5 s with nothing lit before x ~940. Add a light at (700,430) r 130 on the north
   bank to show the way round.
5. The west third (x < 450) holds one foe (#19) and the camp; fine as a rest zone, but the SW corner (40,1080) is
   350 px from anything: dead space with no reward. Put the moved potion from finding 1 or a pickup at (120,1000).

## wyrmhollow (The Wyrm's Hollow, 1300x1100, 53% walkable, 19 foes, 19 lights)
Good: the best boss arena of the six: about 1050x370, free 496 px E, 556 px W, 196 px S, no hazard, no common foe
inside 270 px of the boss, one 260-px light on it.
1. Entrance guards are in the rock: #2 frostknight is wedged in the 12-px crack between wall rows and the hero cannot
   come nearer than 49 px; #1 skeleton 5 px in. All three (#0 144, #1 151, #2 164 px) are inside aggro of the arrival
   (650,84). Fix: #2 -> (612,158) at least; better move #0/#1/#2 300 px away, e.g. #0 (560,170) -> (380,230).
2. West route = 8 foes at once in a pinched corridor. At (320,540): #3 #4 #5 spiders, #6 #7 wyrmlings, #8 wraith,
   #14 #15 bats, all inside 270 px, nearest neighbours 42-90 px. The route narrows to 66 px at (356,316) (between
   (299,211,50,70) and (365,350,50,70)), 46 px at (400-440,440-480) and 50 px at (480,480-520). Fix: delete wall
   (365,350,50,70) and (404,469,50,70) (duplicates of crystals 30 px away) and move #6 (300,400) -> (200,330),
   #8 -> (240,608) so the group splits in two.
3. East route = the fight is on ice. Hazard (880,380,270,230) fills the corridor and #9 #10 #11 #12 #13 all stand
   inside it. Both routes to the boss are therefore punishing; neither is the "easy" one. Fix: shrink the hazard to
   (960,420,190,150) so a 80-px dry lane remains on the west edge.
4. Route length 1116 px (10 s) with the widest possible route only 64 px at its narrowest: no way to kite.
   Covered by fixes 2-3.
5. Greater potion #4 (1060,715) is 27 px from the nearest standable spot (borderline pickup); move to (1060,739).

## emberforge (Forge of the First Flame, 1250x1000, 94% walkable, 15 foes, 16 lights)
Good: no stuck foes, no unreachable items, route to the boss 740 px with nothing narrower than 170 px, and the whole
south half (3 obsidian, slagbrutes, the anvilward) is a real optional loop.
1. Three common foes join Ignarok: #4 moltencore 123 px, #5 258 px, #2 cinderhound 259 px from boss feet (656,234).
   Fix: move #4 from (520,200) to (400,160).
2. The boss is pinned between a furnace (600,60,70,70) 141 px north and a forge (520,300,90,60) 132 px south-west:
   an 84-px-tall boss in a 170-px slot, and vent (480,400,180,60) covers the south approach. Fix: move the ignarok
   spawn from (620,150) to (700,200) (clear of the forge) or drop wall (520,300,90,60).
3. The shrine_echoes trigger (978,420,44,16) is in open floor 395 px from the boss, inside his 420 px range; a roll
   during the fight can leave the map. The arrival from that shrine (1000,516) has bellowdrone #8 at 111 px.
   Fix: move #8 from (880,520) to (880,640).
4. The anvilward (190 hp, (620,900)) guards nothing: nearest item is obsidian #2 at 300 px, and vent
   (520,860,200,56) lies under it. Fix: move obsidian #3 from (140,925) to (720,960).
5. The NE corner (1200,40) is 310 px from any foe or item: empty. Low priority.

## damavand (The Slopes of Damavand, 1500x1200, 30 foes, 6 lights)
Good: three goals in three directions, each with its own light (ruin 240/400,176; temple 1145,830 r 200; gate
650/870,86), and Qaren's camp is 350 px from the arrival with only one archer (#19, 263 px) in range.
1. Coming back out of the cave you land between two guards: arrival feet (773,164), #7 at 59 px, #6 at 73 px,
   archer #8 at 181 px. Fix: move #6 from (688,136) to (548,366); #7 from (818,146) to about (848,430) (my first
   pick (888,386) touches lava (930,380,110,70), so check this one); #8 from (610,230) to (610,330).
2. Eleven foes at once on the temple road: at (840,700) packs #9-11, #12-14, #15-17, archers #3 #18 and serpent #20
   are all inside 270 px; the packs are 210-270 px apart and each is three guards stacked within 10-37 px.
   Fix: move pack #15,#16,#17 from (1073,591) (1058,588) (1080,543) to (1138,976) (1168,996) (1108,1001) (south of
   the temple; verified clear).
3. Kondrow's two gate guards are inside the gate pillars (table). The gap they should hold is 144 px (x 249-393).
   Fix: #1 -> (258,316), #2 -> (358,316) (verified clear).
4. Stick point: a 26-29 px slot (the hero is 26) at (440,320-400) between pillar (393,304,50,60) and the block to
   its east, and a 30-px slot at (600-640,960-1000). Fix: move the block east of the pillar 20 px further east.
5. Three unreachable pickups and two more stuck foes (table). The road packs stand 400+ px from any light: add a
   light at (640,540) r 130 and (880,660) r 130.

## zahhakcave (The Cave of Chains, 1200x1000, 58% walkable, 11 foes, 7 lights)
Good: the arena is right for a last boss: about 1000x450, free 508 px E and W, 188 px S, four anchor pillars as
cover, no hazard, no common foe inside 270 px, and the only exit is 820 px of path away so nobody leaves by accident.
1. Both door guards are inside the central rock, 126 and 133 px from the arrival (613,94) (table). Fix: #0 (560,180)
   -> (368,256), #1 (630,190) -> (808,256) (verified clear; 304 px from the arrival, one per wing).
2. The wings are unlit: serpents #2 #3 and #5 #6 are 175-220 px from the nearest light (r 120), and the two greater
   potions at (220,360) and (980,360) sit in the same dark. Add lights at (300,380) r 130 and (900,380) r 130.
3. Each wing is one clump: at (420,360) six foes are inside 270 px (after fix 1: guard + 3 serpents + archer per
   wing, nearest neighbours 71-86 px). Fix: move archers #8 (300,470) -> (200,580) and #9 (880,470) -> (980,580), so
   they open the arena instead of joining the wing fight.
4. Four 30-px slots (hero 26) beside the arena pillars: (200,880-920), (1000,880-920), (1000,560-600). A knocked-back
   hero can lodge there. Fix: move pillars (225,830,50,70) and (925,830,50,70) 20 px toward the centre.
5. Route 820 px (7.5 s), widest route 112 px, narrowest point on the short path 154 px: fine. Potion #2 (600,520) at
   the arena mouth is 237 px from Zahhak, inside his 420 px notice range: picking it up starts the fight. Move it to
   (600,470) only if that is not intended.

## Top 10 across the maps
1. 16 foes spawn overlapping walls (zahhakcave 2, wyrmhollow 4, frostvale 6, damavand 4); wyrmhollow #2 cannot be
   reached at all. Table above gives a clear spawn for each.
2. wyrmhollow: both routes to the Dragon are bad: west = 8 foes inside 270 px through 46-66 px pinches; east = all
   5 foes standing in a 270x230 ice field.
3. damavand: return from the cave lands 59 and 73 px from two guards.
4. damavand: 11 foes inside 270 px at (840,700) on the temple road.
5. sanctum: arrive from the peaks at the bottom (573,974), leave by the west edge 743 px away.
6. frostvale: Akvan's ring is a 270x210 cage with one 127-px door and pillars 68 px behind the boss.
7. sanctum: the arbiter stands on freezing ice, with two icelings 99 and 142 px from him.
8. 4-5 pickups out of reach (frostvale greater potion inside a pillar; three in damavand; one borderline in
   wyrmhollow).
9. sanctum: hardest foes at the entrance, weakest at the boss.
10. zahhakcave: dark wings (foes and potions 175-220 px from any light) and each wing a single clump.

## Not checked
- No runtime check: what Godot does with a foe spawned inside a wall, and whether enemies respawn on re-entry
  (findings on return arrivals assume they do).
- Whether a foe needs line of sight to notice the hero (I assumed distance only, per enemy.gd line 195).
- Lighting: I measured distance to lights; how dark the unlit ground really looks was not seen.
- Proposed positions marked "verified clear" were tested against walls and hazards with a 10 px margin; the others
  were chosen from the overhead picture and need a look.
