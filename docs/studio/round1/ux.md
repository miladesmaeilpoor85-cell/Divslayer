# Ember & Iron v0.26.1 — UX/UI review (phone, landscape)

Seat: UX/UI designer. The workspace was not edited. My runs are in `/home/claude/studio/runs/ux/NNN/` and the scenarios
in `/home/claude/studio/runs/ux_scenarios/` (u1_fa, u2_fa, u3_en, u4_fa854). "base px" means the game's 854x400 layout
pixels. At 1600x720 the layout is 888x400 (x1.8 on screen), and at 1280x720 it is 854x480. The UI-size setting scales
the HUD root, and every in-game panel (pause, shop, dialogue, death) sits under that root: Small x0.88, Large x1.15. So
with Large the room left is 888/1.15 = 772 px wide at 20:9, 743 px at 16:9 or 854x400. On a 6-6.5" phone one base px
is about 0.17 mm, so 44 base px is about 7.5 mm, the usual thumb target. Where the QA seat's shots in
`/home/claude/studio/runs/qa/` back a finding, I name them.

Status: final, after 4 runs (budget: 8 runs and about 35 tool calls; the tool calls ran out first).

## Findings, ranked by how much a player suffers

| # | Screen | Size / lang / UI | What is wrong | Evidence | Smallest fix |
|---|---|---|---|---|---|
| 1 | Every dialogue (Zal, Kavian, every NPC) | all sizes, **fa**, all UI | The spoken line is **left-aligned** in Persian. It starts at the far left of the box, away from the portrait and name tab on the right, with a wide empty gap between them. Cause: the code sets the panel to RTL layout and then gives the label `HORIZONTAL_ALIGNMENT_RIGHT`. In Godot 4 a Label in RTL layout reads LEFT/RIGHT as start/end, so the two flips cancel out. The hint label is flipped the same way. English is correct. | ux/001 `09_dialogue.png` (Zal, 1600x720); ux/002 `13_smith_menu.png` (Kavian); qa/005 `05_smith_fa_ui0.png` (1280x720, UI0). Compare ux/003 `11_dialogue.png` (en, correct) | `dialogue.gd:115-116`: while the panel is RTL, give `text_l` `HORIZONTAL_ALIGNMENT_LEFT` (which means "start") and `hint_l` `RIGHT`. Or delete both lines and let the RTL layout place the text. |
| 2 | Pause → **Map** | **UI Large** at 854x400 and 1280x720, both langs (very likely 1600x720 too) | The Map page makes the pause panel **wider than the screen**: nav 176 + local map 200 + world map 330 + padding ≈ 777 px, but only 743 px fit. In **Persian the cut is on the left**, so the world-map column that holds **Zabol, the player's own location**, is off-screen apart from a sliver. In English the right column and the panel's right frame are cut. At UI Normal it fits (854 fa: ux/004 `02_map_ui1.png`). | ux/004 `05_map_ui2.png` (fa 854x400 L); ux/003 `09_pause_map.png` (en 1280x720 L); qa/004 `07_pause_map_en.png` (en 854x400 L) | `ui/world_map.gd:24` and `pause_menu.gd:835`: let the two maps shrink (set `custom_minimum_size` to about 0.8x when the space is narrow, or `clip_contents` + scale to fit), or stack the local map above the world map once the panel is under 780 px. |
| 3 | HUD quest tracker (top-left) | all sizes, **fa** | The objective wraps to two lines, and the short last line hugs the **left** edge of the box ("(شمالِ جنگل) بده"). Persian lines should end on the right. The tracker is on screen almost all the time, so this is the RTL fault players will see most. | ux/001 `06_intro.png`, `08_hud.png`; ux/002 `10_hud_ui2.png`; ux/004 `01_hud_fa854.png` | `hud.gd:304`: `quest_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if Game.lang == "fa" else LEFT`, set again on `lang_changed`. The row is LTR, so RIGHT really means right here. |
| 4 | Pause → Skills (Spells) | 1600x720 fa, 854x400 fa, 1280x720 en L | The page's main job, binding spells to the two spell buttons, is **below the fold**. The Ultimate card, the signature card and a hint fill the screen, and the spell cards start at the bottom edge with their "2" bind button cut off. The bind buttons are only **40x30** base px, one stacked above the other. Hints elsewhere tell the player to "bind in Menu → Skills", and on opening that page he sees no spells. | ux/002 `02_pause_skills.png`; ux/004 `03_skills_ui1.png`; ux/003 `06_pause_skills.png` | Put the spell list first and shrink the Ultimate and signature cards to one line each, or move them below the list. `pause_menu.gd:714`: make the bind buttons 48x44 and set "1" and "2" side by side. |
| 5 | Fight pad, top-right cluster | **UI Large**, fa, 1600x720 and 854x400 | With the Large interface the **Ultimate ring overlaps the minimap's bottom-right corner**, and the day label "روز" is drawn inside the Ultimate. Spell 2 touches the minimap's bottom edge. An Ultimate that is not charged is dim and reads as part of the map frame. At 16:9 the extra height avoids this. | ux/002 `10_hud_ui2.png`; ux/004 `04_hud_ui2_fa854.png` | Keep the minimap and day label at least 8 px above the topmost pad ring. Either shrink the minimap at UI2, or in `touch_pad.gd:46-47` clamp the y of `ult` and `skill2` so the ring top is ≥ minimap bottom + 6. |
| 6 | Fight pad labels | all sizes, both langs, worst at UI Small | The text under each pad icon is **9 base px** (`touch_pad.gd:322`; 11 px only on Attack), for example "انفجارِ اخگر", "ضربهٔ گردباد", "پنهان". That is about 1.5 mm on a phone, and **7.9 px at UI Small**, where Persian joins and dots blur. Long English names ("Simorgh's Feather", "Arcane Tempest") spill past the ring, and the Ultimate's label sits on top of its own icon. | ux/001 `08_hud.png`; ux/002 `12_hud_ui0.png`; ux/003 `04_hud.png` (en) | Use 11 px minimum (12 for fa) with outline 3. Or drop the labels on the four core buttons the drill teaches (attack/roll/block/potion) and keep them on spells and Ultimate only. |
| 7 | Fight pad spacing | all; UI Normal / Small | **Ultimate and Spell 2 are 10 base px apart** ring to ring (8.8 at UI Small). Potion–Block is 13 px, Block–Spell 1 is 17, Shove–Sneak is 18. Hitting Spell 2 instead of the Ultimate is a costly mis-tap. | worked out from `touch_pad.gd:20-55` (radii + centres), visible in ux/001 `08_hud.png`, ux/004 `01_hud_fa854.png` | Keep ≥ 16 px between ring edges. Move `ult` to `(s.x-40, s.y-196)` or `skill2` to `(s.x-124, s.y-170)`, and move the potion 6 px further left. |
| 8 | Calling cards (new game) | 1600x720 fa, 1280x720 en | The card description is **10 px muted** text (`menu.gd:268`), and the five stat bars have no numbers or words, only 10 px icons. This is the one screen where a new player makes a permanent choice, and it is the hardest to read. Across the row the names and bars sit at different heights, because a 2-line or 3-line description pushes them down. In **Persian each card still carries the small "اخگردار" tag** that was removed from the English cards (`menu.gd:265`). The tag repeats the heading "تو اخگرداری". | ux/001 `04_callings.png`, `05_callings_pick.png`; ux/003 `03_callings.png` | Description 12 px in CREAM at 80 %, with a fixed height of 3 lines so every card lines up. Remove the fa tag (`Game.t("", "")`). Add a value or a one-word label to each bar. |
| 9 | Dialogue with choices (smith, merchant…) | 1600x720 fa; 1280x720 en; 1280x720 fa UI0 | The bottom choice bar **covers the top of the speaker's name tab**, so "کاویانِ آهنگر" / "Kavian the Smith" is cut. Choices are 34 px tall with 13 px centred text, the smallest text in the dialogue. Tutorial toasts ("Sneaking: …") also pop up over the choice list and the quest tracker. | ux/002 `13_smith_menu.png`; ux/003 `12_smith_menu.png`; qa/005 `05_smith_fa_ui0.png` | `dialogue.gd:170-177`: add the name tab's height (≈20 px) to the gap between `_choice_box` and the panel. Choice text 14-15 px, height 40. Hold back hint toasts while a dialogue is open. |
| 10 | "Large" interface makes the pause buttons **smaller** | any size, UI Large | Choosing Large shrinks the pause nav buttons from 36 to **30 px** (`_compact`) and hides the title, so that "Save & quit" fits. After the x1.15 scale they come out at 34.5 px, still under 44. The player asked for bigger and got thinner. | ux/002 `11_pause_ui2.png`; code `pause_menu.gd:115-130` | Let the nav column scroll (it already sits in `nav_scroll`) and keep the buttons ≥ 40 px at every UI size. |
| 11 | Persian signed numbers | fa: shop / talents / forge / craft vs Skills | Most Persian strings put the plus sign **before** the number ("+۲۰ جان", "+۱ حمله در هر رتبه", "+۲ حمله در هر سطح"). The mana line puts it **after** ("۰٫۹+ در ثانیه"). So on screen the sign lands on different sides of the digits on different pages. | text dumps in ux/002 log: `SCREEN 02_pause_skills` vs `SCREEN 14_forge` / `16_craft`; code `pause_menu.gd:604` | Add one helper, `Game.signed(n)`, that wraps sign and digits in LRI…PDI (U+2066…U+2069), and use it for every "+%s". |
| 12 | Panels close only by the corner X | shop, forge, cauldron | The dim backdrop ignores taps (`MOUSE_FILTER_IGNORE`), so the only way out is the 44 px X in the far top corner: top-left in fa, top-right in en. Phone players expect a tap outside (and Android Back) to close a sheet. The way out is also named three ways: "Leave/برگشتن" in NPC menus, "Back/بازگشت" in menus, and an X icon on panels. | `shop.gd:26-30` (forge.gd/craft.gd copy it); ux/001 `10_shop.png`; ux/003 `12_smith_menu.png` | Make `dim` `MOUSE_FILTER_STOP` and close on tap. Handle `ui_cancel`. Pick one word for "leave". |
| 13 | HUD shows around full-screen panels | 1600x720, both langs | The hero portrait, name and quest-tracker pieces show to the left of the pause panel and behind the shop. World name tags also show through the HUD block (en: "…afarid" next to the HP bar). Cosmetic clutter. | ux/002 `01_pause_hero.png`; ux/001 `10_shop.png`; ux/003 `04_hud.png` | Hide the HUD status and quest blocks while pause, shop, forge or craft is open. |
| 14 | Small copy/layout nits | fa | Death panel: the compound verb "زنده شو" breaks across two lines. Boss hint toast: it stays in the old language after a language switch (the boss name does switch). | ux/004 `06_death_fa.png`, `07_death_en.png` | Join the verb with a non-breaking space (U+00A0 or ZWNJ before "شو"). Rebuild the toast on `lang_changed`. |

## Tap-target audit (smallest controls, base px; target 44)

| Control | Size (base px) | Where | Verdict |
|---|---|---|---|
| Spell bind "1" / "2" (Pause → Skills) | **40 x 30**, stacked 4 px apart | `pause_menu.gd:714` | under target in both directions; and below the fold |
| Pause nav buttons, UI Large | **30** tall (x1.15 = 34.5) | `pause_menu.gd:123` | under target |
| Dialogue choice bars | **34** tall x ~780 wide | `dialogue.gd:177` | height under target; the width makes up for it |
| Pause nav buttons, UI Normal | 36 tall (Resume 40) | `pause_menu.gd:102,107` | slightly under |
| Pause settings segmented buttons | 74 x 38 | `pause_menu.gd:939-940` | slightly under in height |
| Talent cards (Skills → Talents) | ≈ 150 x 40-45 (measured on ux/003 `07`) | `pause_menu.gd` talents grid | borderline |
| Pad: Sneak / Shove | 54 Ø (47.5 at UI Small) | `touch_pad.gd:21-22` | size OK; only 18 px apart |
| Pad: Potion / Scroll | 56 Ø | `touch_pad.gd:25-26` | OK; 13 px from Block |
| Pad: Spell 1 / Spell 2 | 58 Ø | `touch_pad.gd:28-29` | OK; **10 px** from Ultimate |
| Menu button; Close X (shop/forge/craft) | 44 x 44 | `hud.gd:112-115`, `shop.gd:71` | exactly at target |
| Title / callings / settings Back | 46 tall | `menu.gd:214,375` | OK |
| Shop item cards; cauldron "Brew"; forge "Upgrade" | 88 tall / ~64 x 64 / ~50 x 80 | `shop.gd:131`, `craft.gd:147` | OK |

## Checked and fine
- Title screen in fa and en: title, "Continue" with the hero summary, New game, Settings, and a language button showing the other language's name. Mirrored between languages. (ux/001 `01`, ux/003 `01`)
- Title settings, fa and en: labels on the leading side and choices on the trailing side. Choice order reads correctly right to left (روشن→خاموش, آرام→معمولی→بلند, کوچک→معمولی→بزرگ). (ux/001 `02-03`, ux/003 `02`)
- Calling screen in fa is mirrored (Pahlavan first on the right; Back on the right with a right-pointing chevron; primary on the left). In en, "Replace saved hero & begin" warns before a save is overwritten. (ux/001 `04`, ux/003 `03`)
- Shop in fa: header mirrored, two-column grid reads right to left, owned/locked/unaffordable states are distinct, 88 px cards. (ux/001 `10-11`)
- Forge and cauldron in fa: mirrored, costs turn red when unaffordable, close X present, big action buttons. (ux/002 `14`, `16`)
- Pause menu at 1600x720 fa UI Normal: all pages (Hero, Achievements, Looks, Spells, Talents, Gear, Map, Settings) show without clipping, and "Save & quit" is visible without scrolling. Same in en at 1280x720 Large, apart from Map (#2). (ux/002 `01-09`, ux/003 `05-10`)
- Map page at UI Normal fits at 854x400 fa and 888x400 fa. (ux/004 `02`, ux/002 `05`)
- English dialogue: text sits next to the portrait, 16 px, easy to read. (ux/003 `11`)
- Death panel at 854x400 fa and 1280x720 fa: centred, both choices ≥ 44 px, the cost of each choice is spelt out. (ux/004 `06`, qa/005 `03`)
- Persian digits are used throughout (۱۲۰, ۶۴ / ۶۴, ۰/۴۲, ۲٫۷), and "a / b" pairs keep the right order.

## Could not check
- Real thumb reach, touch latency, haptics, the Android Back button, and notch/safe-area insets (the code applies these only on a real mobile device).
- Drag-scrolling of lists (the kit scrolls with the wheel only).
- The English death panel as a player sees it: a live language switch does not rebuild an open death panel, and a player cannot switch there anyway.
- The Map page at 1600x720 with UI Large (I inferred it from widths, ≈777 needed vs 772 available; not shot).
- Sound cues for UI.

## For other seats (not UX)
- QA: on the death panel the gold went from ۱۴ to 12 before any choice was made (ux/004 log, `SCREEN 06_death_fa` vs `07_death_en`), while the panel says fighting again here costs nothing. Worth a check.
- Test kit: `preset` does not close an open shop or dialogue. The rest of ux/001 stayed stuck on the shop, and ux/003 stayed on Kavian's menu ("Back" is not a choice there; it is "Leave").

## Run log
- ux/001: 1600x720 fa UI1. Title, title settings, callings, first minute of play, HUD, Zal's dialogue, shop. Shots 12-24 only show the shop (kit quirk above).
- ux/002: 1600x720 fa UI1/UI2/UI0. Every pause page, HUD at three UI sizes, Kavian's menu, forge, cauldron.
- ux/003: 1280x720 en UI2. Title, settings, callings, HUD, every pause page, Zal's dialogue, Kavian's menu. Death and shop not reached (dialogue stayed open).
- ux/004: 854x400 fa UI1/UI2. HUD, Map at both sizes, Skills, death panel (fa, then a language switch).
