# Shrine playtest — Ember & Iron 0.27.0 (IN PROGRESS)

Tester: shrine tester. Kit: `play.sh shrines <scenario> 1600x720`, scenarios in `runs/shrine_scenarios/` (built by `gen.py`).
Hero: preset `ch2` warrior (level 16). Test shortcuts used in every run: `preset`, `goto` to the shrine's stair.
The puzzle itself is played with stick / walk_to / attack / talk / tap only. SEEN = screen or log, READ = code/data.

## What the code says (READ, before playing)

All seven rooms are 17x13 cells of 40 px; the hero arrives at (340,477) bottom-centre, the way out is the gap right
below him, the inner door is at cell (8,3), the altar behind it. Reward at the altar (main.gd:467, shrine.gd:1043):
gold + one accessory of the listed rarity + a permanent Sigil chosen from four (+12 HP / +6 MP / +2 ATK / +1 DEF).
The tablet's text is also sent as a one-time hint on first entry (shrine.gd:133).

| shrine | entered from (stair) | rule | door opens when | gold / accessory |
|---|---|---|---|---|
| shadows | village (452,70) | 4 Watchers sweep light cones (reach 178 px); seen in the light, or heard within 84 px when not sneaking = sent back to the start. Sneaking inside tall grass is invisible | hero stands on the far plate (top-left) | 140 / rare |
| embers | forest (330,408) | strike the eternal flame: blade burns 10 s; light 3 braziers; one is behind brambles (burn them), one across water (light the oil trail) | 3 braziers lit | 120 / rare |
| weight | dungeon (92,608) | 2 stone blocks onto 2 heavy plates; walk into a block to push one cell; lever resets; 2 skeletons | both plates under blocks | 160 / rare |
| fuse | peaks (110,288) | push the barrel next to the cracked wall, light it with the flame-blade (3 s fuse, blast 92 px), run; 2 imps, lava | wall blown | 220 / epic |
| tides | shadowfen (130,518) | strike frost crystal (blade cold 9 s), strike water to freeze it 14 s, cross; storm crystal kills what stands in water; 3 toads | hero on the plate AND no foe alive | 260 / epic |
| light | sanctum (330,408) | strike 3 mirrors to turn them, melt the ice wall with the flame-blade, beam must reach the crystal; 2 icelings | crystal lit | 320 / epic |
| echoes | emberforge (1000,428) | step on 4 runes in the mosaic's order (dots 1-4), then light two braziers that burn 9 s each so both burn at once; 2 cinderhounds | sequence + both braziers | 380 / epic |

Tablet texts (READ, V16_SHRINE_LIST.json) are quoted per shrine below.

## 1. Shrine of Shadows — SOLVED on the 4th crossing attempt (run `runs/shrines/001`)

- Entered from: village stair at (452,70). SEEN log STEP 6 "changed map -> shrine_shadows".
- Told to the player (SEEN shot 04, log STEP 19): «نگهبان‌ها هر چه در نورشان راه برود را می‌بینند و صدای هر که بلند قدم بردارد را
  می‌شنوند. مخفیانه برو، در علف بلند بمان و روی صفحهٔ آن سر قدم بگذار.» English (SEEN shot 03): "The Watchers see whatever
  walks in their light, and hear whoever walks loudly. Sneak, keep to the tall grass, and step on the far plate."
- Result: three attempts were sent back to the start (log STEP 28-47: hero back near (332,468)), the fourth reached the
  plate (STEP 55 pos (79,194)); the door was open, altar worked (STEP 62-67).
- Time: about 75 s of play for my four scripted attempts; a clean pass is about 12 s.
- Reward SEEN: +140 gold (900 -> 1040), accessory «آویز حیات (+۲۰ جان بیشینه) — پوشیده شد», sigil choice
  «سرزندگی / تمرکز / نیرو / پایداری», banner «زیارتگاه پاک شد · ۱ از ۷ زیارتگاه».
- Leaving: SEEN, walked out to the village (STEP 70-72).
- Problems: see the list at the end (filled in after the screenshots are judged).

## 2-7: not played yet

## Not tested
- everything except shadows (so far); sound; real touch feel.
