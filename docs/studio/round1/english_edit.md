# Ember & Iron — English editorial pass

Editor: English / localisation lead. Read-only pass; nothing in the game was changed and the game was not run.

**Method.** `data/en/extract_en.py` pulls every English string candidate out of `scripts/*.gd`, `scripts/ui/*.gd` and `data/Tables/*.json` into `data/en/en_strings.txt` (1,619 lines, `file:line <tab> tag <tab> text`). All 1,619 lines were read. Display paths were checked in code for the doubtful cases (which table is really shown, which name function a message uses). Nothing was verified on a device: every "overflow" and the `\\n` item below need one look on a phone.

**Importance:** `error` = wrong English or a visible defect · `inconsistent` = one thing written two ways, or against the story frame · `better` = a real improvement in voice or clarity.

**Not shown to the player (no row needed, but stale):** `I18N.json`, `ACHIEVEMENTS.json`, `V12_TIPS.json`, `V18_CFG.json`, `ACCESSORY_POOL.json`, `STATUS_DEFS.json`, `FF_ENCHANT_POOL.json`, `SCROLL_DEFS.json` are not loaded by any script (leftovers of the HTML game). `CLASSES.json` `name` / `ultName` / `ultDesc` ("Warrior", "Mage", "Rogue", "Paladin", "Divine beam") are not displayed either — the menu uses its own cards. If any of these is ever wired back in, it carries old text: "Paladin", "Usurper of the Crystal Sanctum", "Bully of the Bog", "the ⋯ button", "Z" key, "Sneak Attack", "Drink the fountain".

---

## 1. Errors

| file:line | current | suggested | reason | imp. |
|---|---|---|---|---|
| scripts/game.gd:702 (+ names in data/Tables/ENEMY_TYPES.json:103,190,263) | `The echo of %s is dust again!` → "The echo of **The** White Div is dust again!", "The echo of **The** Sorceress…", "The echo of King of Mazandaran…" | store the names without the article ("White Div", "Sorceress", "King of Mazandaran", "Dragon of Kashaf") and write the article in the sentence: `The echo of the %s is dust again!`; for Arzhang / Akvan no article | capital "The" mid-sentence; missing article for the King | error |
| scripts/main.gd:340 (+ scripts/game.gd:156,165,174) | banner subtitle `The echo of %s` → "The echo of The Sorceress" | same fix: name without article, article in the template | same defect on the victory banner | error |
| scripts/game.gd:699 | `%s defeated!` → "The Dragon of Kashaf defeated!" | `%s is defeated!` (reads correctly with or without article) | headline grammar breaks with an article | better |
| scripts/story.gd:28 | `A Kindling lock seals the door.\\n(the Shade of Jamshid may know how to open it)` | `…seals the door.\n(The Shade of Jamshid may know how to open it)` | source has a double backslash: the player will see a literal "\n" (the other two door messages use `\n`); also capital after the bracket like "(Zal may know more)". Same in the Persian half | error |
| scripts/boss.gd:836 | `Ice echoes copy her spells. One hit breaks an echo — fire melts them all.` | `Twins of ice copy his spells. One hit breaks a twin — fire melts them all.` | the White Div is "he" everywhere else; "echo" is the story word and must not also name his ice copies (Persian says همزاد, Rostam says "twins of ice") | error |
| data/Tables/ENEMY_TYPES.json:435 | `Ice Echo` | `Ice Twin` | same clash with the story term | inconsistent |
| scripts/game.gd:714 | `+%d Mana Essences` | `+%d Essence` | the material is "Essence" everywhere else (forge, bag, Rudabeh); uncountable | error |
| data/Tables/RECIPES.json:32 | `Greater HP` | `Greater Potion` | shown in Rudabeh's brew list; the same item is "Greater Potion" in Hom's shop and in every toast | error |
| data/Tables/RECIPES.json:14,28,43 | `+20 HP (craftable)` · `+10 MP (craftable)` · `+50 HP, +30% max HP (consumable)` | `+20 HP` · `+10 MP` · `+50 HP, +30% max HP` | developer notes shown as item text; shops already show the clean form | error |
| data/Tables/RECIPES.json:57,71,86,100,115 | `hurl a fireball` · `freeze enemy 3s` · `8s regeneration` · `ice lance, big dmg + freeze` · `+45% speed 8s` | `Hurls a fireball.` · `Freezes a foe for 3 s.` · `Regenerates health for 8 s.` · `An ice lance: heavy damage, and it freezes.` · `+45% speed for 8 s.` | note-form, "dmg", no capital; the Persian side is full sentences | error |
| scripts/forge.gd:159 | `Bogbloom: foes drop it now and then (most in the Shadowfen), or gather them for Rudabeh.` | `Bogbloom: foes drop it now and then, most often in the Shadowfen.` | "it"/"them" mismatch, and the last clause makes no sense in the smith's hint | error |
| scripts/main.gd:115 | `%d achievements earned on your journey so far — see Menu → Hero` | `Achievements earned so far: %d — see Menu → Hero` | "1 achievements" | error |
| scripts/gear.gd:12 | `Sorcerer Stone` · `Scholar Signet` | `Sorcerer's Stone` · `Scholar's Signet` | missing possessive | error |
| data/Tables/ENEMY_TYPES.json:158 | `Will-o-Wisp` | `Wandering Light` | misspelt (will-o'-the-wisp) and English folklore; Persian is روشنک سرگردان | error |
| data/Tables/TALENT_TREE.json:37 | `Ultimates +30% dmg` | `Ultimates +30% damage` | "dmg" abbreviation (the other talents were already rewritten) | error |
| scripts/boss.gd:640, scripts/toll.gd:56 | `The mountain stirs…` · `You have nothing on him… yet.` | `...` | the rest of the game uses three full stops (about 30 places); two lines use the single ellipsis character | inconsistent |
| scripts/player.gd:622 | `Combo x%d` | `Combo ×%d` | everything else uses "×" | inconsistent |
| scripts/gear.gd:12 | `-20% Dash CD` | `−20% Roll cooldown` | hyphen for minus (talents use "−"), and see Roll/Dash below | inconsistent |
| scripts/shrine.gd:897, :929 | `Game.t("SPLASH!")`, `Game.t("LAVA!")` | add the Persian half | one-argument `Game.t`: Persian players get the English word (for the Persian editor) | error |

## 2. Story frame (echoes; three seals of the First Smiths)

| file:line | current | suggested | reason | imp. |
|---|---|---|---|---|
| scripts/boss.gd:532 | `Rise, wardens!` | `Rise, stones of the dead!` | "wardens" is the old frame's word; here it is only Arzhang's echo raising grave pillars | inconsistent |
| scripts/story.gd:5,11,15,16,19 | `Warden Core` · `the Warden that bars my Forge` · `the Warden still stands` | `Keeper's Core` · `the Keeper that bars my Forge` · `the Keeper still stands` | the same foe is "Pulad of Ghandi, Keeper of the Forge Gate"; removes "warden" from the game | inconsistent |
| data/Tables/MON_SKINS.json:56 | `Verdant Warden` (a look) | `Verdant Keeper` | last "warden" the player sees | inconsistent |
| scripts/chapter2.gd:122 | `The Dragon of Kashaf sleeps for good, and Zabol breathes again.` | `The Dragon of Kashaf is dead at last, and Zabol breathes again.` | the whole chapter says "slay", "is slain", "end what the Smiths only put to sleep" | inconsistent |
| scripts/chapter2.gd:84 | `The White Div took this hall from me, and holds one shard in his fist.` | `The White Div's echo took this hall from me, and holds one shard in its fist.` | chapter 2 foe is an echo (its card says "Echo of the Seventh Labour") | inconsistent |
| scripts/chapter2.gd:87 | `You have already broken the White Div. His shard came back to me with his echo — one of the three is ours.` | `You have already returned the White Div's echo to dust. Its shard came back to me — one of the three is ours.` | "came back with his echo" contradicts the echo having been destroyed | inconsistent |
| scripts/chapter2.gd:90 | `The White Div still keeps his shard. He sits above us, at the head of the hall.` | `The White Div's echo still keeps its shard. It sits above us, at the head of the hall.` | echo | inconsistent |
| scripts/chapter2.gd:91 | `Akvan sleeps in the heart of the Hoarfrost Vale, beyond the east passage.` | `Akvan's echo sleeps in the heart of the Hoarfrost Vale, beyond the east passage.` | echo (line 84 and the journal already say "the echo of Akvan") | inconsistent |
| scripts/chapter2.gd:42,43 | `: the White Div, in the Sanctum` · `: Akvan the Div, in the Hoarfrost Vale (east of the Sanctum)` | `: the White Div's echo, in the Sanctum` · `: Akvan's echo, in the Hoarfrost Vale (east of the Sanctum)` | chapter 1 objectives already say "Defeat the echo of…" | inconsistent |
| scripts/achievements.gd:33,34,35,40 | `Defeat the King of Mazandaran` · `Defeat the Sorceress` · `Defeat the White Div` · `Defeat Akvan the Div` | `Return the echo of the King of Mazandaran to dust` · `…of the Sorceress…` · `…of the White Div…` · `…of Akvan…` | "the game says echo wherever it names them" (v0.26 note) — achievements do not | inconsistent |
| scripts/main.gd:809 | `You have not slain Arzhang.` | `Arzhang's echo still stands.` | Rostam slew Arzhang; the player only meets the echo | inconsistent |
| scripts/chapter2.gd:75 | `The echoes, the Wyrm, the First Flame... all of it ended by one ember-bearer from Zabol.` | `The echoes and the Dragon... all of it ended by one ember-bearer.` | the First Flame (Puladvand) is an optional side tale and may not be done; the hero arrived in Zabol as a stranger ("Welcome to Zabol") | better |
| scripts/chapter2.gd:119 | `If they break... gods keep Zabol.` | `If they break... God keep Zabol.` | plural gods in a Shahnameh world; Rostam says "the name of God" | inconsistent |
| scripts/chapter2.gd:121 / scripts/chapter3.gd:95 | `Chapter Two complete` / `Chapter 3 is over` | `Chapter Two complete` / `Chapter Three complete` | two forms of the same card | inconsistent |

## 3. Leftovers of the generic-fantasy version (displayed text only)

| file:line | where the player sees it | current | suggested | imp. |
|---|---|---|---|---|
| scripts/chapter2.gd:32,37,41,46,47,53,66,71,82,86,94–97,112,118,119,505; data/Tables/CH_MAPNAME.json:39 | chapter 2 quest log, banners, Zal, Sorush, Hom, journal, map title | `the Wyrm`, `the Wyrm Key`, `THE WYRM STIRS!`, `The Wyrm's Hollow`, `a wyrm of Kashaf`, `a wyrm's eye` | `the Dragon`, `the Dragon Key`, `THE DRAGON STIRS!`, `The Dragon's Hollow`, `a dragon of Kashaf`, `a dragon's eye` | inconsistent (one beast, two names; Persian has only اژدها) |
| scripts/achievements.gd:36 | achievement | `Wyrmslayer` | `Heir of Sam` (Sam struck it first; "Dragonslayer" is already Sindokht's sword) | inconsistent |
| scripts/gear.gd:12 | accessory names | `Wyrmfang` · `Wyrmstride` · `Wyrmsoul` | `Dragonfang` · `Dragonstride` · `Dragonsoul` | inconsistent |
| data/Tables/CH_RELICS.json:74 | relic of the Dragon | `Wyrmking Crown` | `Crown of Kashaf` | inconsistent |
| data/Tables/ENEMY_TYPES.json:482 | foe name, bounty board | `Wyrmling` | `Dragon Whelp` | inconsistent |
| scripts/chapter2.gd:29,93,94; scripts/boss.gd:833 | shard name, Sorush, the White Div's shout | `Shard of Judgement` · `Judgement, frost and memory` · `the Judge's seat` · `Judgement multiplies.` | `Shard of Sight` · `Sight, frost and memory` · `the White Div's seat` · `See me twice.` | inconsistent — the "Arbiter" boss survives in these four lines; the White Div is no judge. "Sight" ties to Kavus's eyes, which Rostam already mentions. Persian (تکهٔ داوری, داوری چندبرابر می‌شود) needs the same change |
| data/Tables/ENEMY_TYPES.json:78,247 | foe names, bounty board | `Magma Golem` · `Glacial Golem` | `Magma Giant` · `Ice Giant` | better (golem); note for the Persian editor: V12_ENEMY gives "اکوان دیوی" for the second, which looks unfinished |
| data/Tables/ENEMY_TYPES.json:220 | foe name | `Frostbound Knight` | `Frostbound Rider` | better (knight; Persian is سوار) |
| data/Tables/ENEMY_TYPES.json:67 | foe name | `Ember Imp` | `Ember Divling` | better (imp; Persian is دیوچه) |
| data/Tables/ENEMY_TYPES.json:11 | foe name | `Slime` | `Mire Spawn` | better (JRPG staple; low priority) |
| data/Tables/SHOPS.json:39, data/Tables/WEAPON_TIERS.json:15 | Sindokht's shop, Hero screen | `Mythril Blade` | `Hindi Blade` | better (Tolkien's metal; the epic's fine sword is the تیغ هندی) |
| data/Tables/ARMOR_TIERS.json:23; scripts/chapter2.gd:54,101 | Jamshid's frost-steel armour | `Glacial Aegis` | `Frost-steel Mail` | better (Greek aegis; also ties it to the quest "Frost-steel") |
| scripts/gear.gd:12 | accessory names | `Aegis Girdle` · `Titanforge` · `Phase Walkers` | `Warding Girdle` · `Smith's Girdle` · `Windstep Boots` | better (aegis, titan, sci-fi "phase") |
| scripts/achievements.gd:56; data/Tables/MON_SKINS.json:150 | achievement and look | `Ashen Saint` | `Ashen Devout` | better (saint; Persian is پارسا) |
| scripts/chapter2.gd:76; scripts/game.gd:667 | Zal | `The bards will need new songs.` · `The bards will sing of you for generations` | `The minstrels will need new songs.` · `The minstrels will sing of you for generations` | better (bard is Celtic; the epic has minstrels) |
| scripts/toll.gd:20,64 | bandit captain, outcome line | `Guild law: no one robs a brother's mark.` · `Guild law, honoured.` | `The ayyars' law: no one robs a brother's mark.` · `The ayyars' law, honoured.` | better (thieves' guild is Western; the Ayyar calling already exists) |
| scripts/main.gd:1043 | Siavash's Trial menu | `Enter the Arena` | `Enter the Trial` | inconsistent (it is "the Trial of Embers" everywhere else) |

Checked and clean in displayed text: "paladin", "matriarch", "arbiter", "holy" appear only as internal ids.

## 4. Terminology

| file:line | current | suggested | reason | imp. |
|---|---|---|---|---|
| scripts/gear.gd:12 | `Simurgh's Feather` (amulet) | `Simorgh's Plume` | only "Simurgh" in the game (Simorgh ×6); and "Simorgh's Feather" is already the Sage's own move (scripts/skills.gd:64) | inconsistent |
| scripts/game.gd:237, scripts/toll.gd (10 lines), data/Tables/ENEMY_TYPES.json:399 | `Ashkbus of Kushan` | `Ashkabus of Kushan` | usual English form of اشکبوس (Davis, Warner); "Ashkbus" is unpronounceable | better |
| scripts/forge.gd:115; scripts/main.gd:927 | `The Forge` · `The Forge — refine your gear` (Kavian's screen) | `Kavian's Forge` · `Kavian's Forge — refine your gear` | "the Forge" is also Jamshid's dungeon (story.gd:16–20, chapter2.gd:76, game.gd:785) | inconsistent |
| data/Tables/CH_MAPNAME.json:27 | `Forge of the First Flame` (map title) | `The Emberforge` | the same place is "the Emberforge" in the achievement, Jamshid's lines, the boss card and the forge hint; also 24 characters | inconsistent |
| scripts/forge.gd:167; scripts/achievements.gd:43; scripts/story.gd:9 | `Upgrade` · `Forge your weapon and your armour to +5` · `Jamshid's masterwork: +2/+2 forge, 3 talent points` | `Refine` · `Refine your weapon and your armour to +5` · `Jamshid's masterwork: weapon +2, armour +2, 3 talent points` | the screen says "refine / refinement" | inconsistent |
| scripts/tutorial.gd:61 | `a perfect block staggers the foe` | `a perfect parry staggers the foe` | "perfect parry" in the Block hint, the float text and the achievement | inconsistent |
| scripts/gear.gd:12,13; data/Tables/TALENT_TREE.json:95; scripts/achievements.gd:31; scripts/menu.gd:16 | `+0.1s Dodge` · `Dash CD` · `Dodge Master` · `Dodge 30 times` · `the longest dodge` | `+0.1 s Roll` · `Roll cooldown` · `Roll Master` · `Roll 30 times` · `the longest roll` | the button and the tutorial say Roll; keep "dodge" only in "perfect dodge" | inconsistent |
| scripts/boss.gd:940 | `The icelings come for you — or stay on Akvan and burn it down.` | `Ice wisps are coming for you: break them, or stay on Akvan and melt him with fire.` | the foe is called "Iceshard Wisp"; "burn it down" is raid slang (Persian: melt him with fire); the "— or" does not parse | better |
| scripts/boss.gd:1186 | `His serpents come for you — or stay on Zahhak and finish him.` | `His serpents are coming for you: kill them, or stay on Zahhak and finish him.` | same broken construction | better |
| scripts/trial.gd:87 | `A champion of the foe comes!` | `An elite foe comes!` | the game's word is "elite" ("Elite slain!", "Elite Hunter"); word-for-word from گُردی از سپاهِ دشمن | inconsistent |
| scripts/achievements.gd:28 vs data/Tables/TALENT_TREE.json:35 | `Ultimate Power` (achievement) and `Ultimate Power` (talent) | achievement → `First Fury` | two things, one name | inconsistent |
| scripts/gear.gd:12 vs data/Tables/TALENT_TREE.json:13 | `Critical Eye` (ring) and `Critical Eye` (talent) | ring → `Hawk's Eye` | two things, one name | inconsistent |
| scripts/achievements.gd:32 | `Craft 10 items` | `Brew 10 potions or scrolls` | the button and Rudabeh say "brew" | inconsistent |
| scripts/achievements.gd:44 | `Complete all seven ancient shrines` | `Cleanse all seven ancient shrines` | "SHRINE CLEANSED", "Shrines cleansed" | inconsistent |
| scripts/toll.gd:63,73; scripts/main.gd:812 | `sworn on the Ember` (×3) | `sworn on the ember` | "the ember" is lower-case in every other line | inconsistent |
| scripts/game.gd:688; scripts/main.gd:754; scripts/story.gd:8 | `+%d Gold Reward!` · `Gold Reward!` · `+350 Gold` | `+%d gold` · `Reward` · `+350 gold` | "gold" is lower-case in all other toasts | inconsistent |
| scripts/caster.gd:106 vs scripts/toll.gd:54 | `Not enough mana!` / `Not enough mana.` | one form: `Not enough mana.` | same message twice | inconsistent |
| scripts/skills.gd:53 vs :69 | `cleanses poison, fire and ice` / `washes poison, burning and frost from you` | both: `poison, burning and frost` | same three states, two wordings | inconsistent |
| scripts/game.gd:208 | `The toad-shaped Div` | `The toad-shaped div` | "div" is capital only inside a name | inconsistent |
| scripts/gear.gd:12 | `+5 HP/Pot` · `Revive 1× (death)` · `+30% Ult charge` | `+5 HP per potion` · `Revive once on death` · `+30% Ultimate charge` | cryptic shorthand | better |
| scripts/gear.gd:169 | ` — equipped` | ` — now worn` | the Gear screen says Worn / Wear / Remove | inconsistent |
| scripts/craft.gd:152 | `have ` | `you have ` | shops say "you have" | inconsistent |
| scripts/game.gd:1002 | `Slay Slime ×8` | `Hunt: Slime ×8` | singular noun after "Slay … ×8" | better |
| scripts/hud.gd:544; scripts/main.gd:441 | `Spend talent points from the Menu` · `Bind it in your Skills.` | `Spend talent points in Menu → Skills → Talents` · `Bind it in Menu → Skills.` | the path is written "Menu → Skills" elsewhere | inconsistent |
| data/Tables/V16_SHRINE_LIST.json:131 | `Shove foes into lava (⋯ wheel, or a charged attack).` | `Shove foes into the lava, or knock them in with a heavy blow.` | no "⋯ wheel" in this build; "charged attack" is "heavy blow" everywhere else | inconsistent |
| data/Tables/V16_SHRINE_LIST.json:257 | `step on the runes as it tells — one dot, two, three, four` | `step on the runes in the order it shows — one dot, two, three, four` | not English | error |
| data/Tables/FF_SKILLS.json:9,29,59 | `Burst of fire around you, applies burn.` · `Arcs through up to 4 enemies, weaker each jump.` · `Step a few paces forward, passing through nothing solid.` | `A burst of fire around you; sets foes burning.` · `Arcs through up to 4 foes, weaker with each jump.` · `Step a few paces ahead in a blink; walls still stop you.` | jargon ("applies burn"); the third reads as its opposite | better |

## 5. Voice

| file:line | current | suggested | reason | imp. |
|---|---|---|---|---|
| scripts/toll.gd:35,38; scripts/main.gd:747 | `Psst — a word before you browse.` | `A word, before you look at my wares.` | Sindokht is the queen of Kabul; "psst" and "browse" are a modern shop | better |
| scripts/toll.gd:74 | `The Ashen Hand? I won't ask. I really won't.` | `The Ashen Hand? I will not ask.` | sitcom rhythm | better |
| scripts/toll.gd:13 | `Pleasure doing business. Tell Sindokht the road tax just went up.` | `A fair bargain. Tell Sindokht the toll on this road has risen.` | modern idiom | better |
| scripts/toll.gd:16 | `Call it a gift between professionals.` | `Call it a gift, from one hard man to another.` | "professionals" | better |
| scripts/toll.gd:15 | `Nobody here is paid enough to die today.` | `No one here is paid enough to die for a box.` | modern quip; keeps the bandit's cynicism | better |
| scripts/chapter2.gd:105 | `Name's Hom. I trap, I trade, and I mind my fire.` | `I am Hom. I trap, I trade, and I mind my fire.` | Hom is the hermit of the epic; "Name's" is a Western | better |
| scripts/tutorial.gd:32,34 | `Come back to me any time — I'll tell you what I know of the foes ahead.` | `Come back to me when you will — I will tell you what I know of the foes ahead.` | Rostam uses no contractions anywhere else (also `You'll do` at :60 → `You will do`) | inconsistent |
| scripts/game.gd:645,656 | `Take this reward!` · `Take this last reward!` | `Take this, with Zabol's thanks.` · `Take this — the last I have to give.` | Zal announcing a "reward" is quest-log language | better |
| scripts/game.gd:650 | `Speak with her! Then hunt the Sorceress.` | `Speak with her, then hunt the Sorceress's echo.` | exclamation; echo | better |
| scripts/main.gd:575 | `…one after another: seven bosses, stronger than you met them…` | `…one after another: seven foes, stronger than you met them…` | "bosses" in Sorush's mouth | better |
| scripts/main.gd:568 | `Relive the battles — the Boss Rush` | `Relive the seven battles` | the mode name can stay on the HUD; in his dialogue it breaks voice (also 33 characters) | better |
| scripts/shrine.gd:918 | `ZAP!` | `Struck!` | comic-book word (Persian: صاعقه) | better |
| scripts/death_panel.gd:63,70 | `Respawn in Zabol` · `Or respawn in Zabol and lose %d gold.` | `Wake in Zabol` · `Or wake in Zabol and lose %d gold.` | "respawn" is developer jargon | better |
| scripts/pause_menu.gd:797 | `Story: gentler foes, for the tale. Harder foes have more health and hit harder, and give more XP and gold. It changes at once for damage taken and for foes you meet from now on.` | `Story: gentler foes, for those who came for the tale. On higher settings foes have more health and hit harder, but give more XP and gold. A change applies at once to the damage you take, and to foes you meet from then on.` | word-for-word Persian; "harder foes" is ambiguous | better |
| scripts/pause_menu.gd:815 | `Roll through attacks — right as they land is a perfect dodge.` | `Roll through an attack just as it lands for a perfect dodge.` | broken syntax | better |
| scripts/pause_menu.gd:816 | `Bosses telegraph every attack on the ground. Fill their stagger bar.` | `Bosses mark every attack on the ground before it lands. Fill their stagger bar to stun them.` | "telegraph" is designer jargon; the second sentence gives no reason | better |
| scripts/pause_menu.gd:817 | `Out of mana, a mana potion is drunk for you.` | `If you run out of mana, a mana potion is drunk for you.` | dangling phrase | better |
| scripts/story.gd:7 | `Kindling Key received — the Peaks door is open.` | `Kindling Key received — the sealed door in the Ashen Peaks is open.` | "the Peaks door" is shorthand | better |
| scripts/achievements.gd:60; scripts/chapter3.gd:87 | `Bound in Damavand` · `BOUND IN DAMAVAND` | `Bound beneath Damavand` · `BOUND BENEATH DAMAVAND` | Damavand is a mountain; the text itself says "beneath it lies Zahhak" | better |
| scripts/toll.gd:33 | `Got: Sindokht's strongbox. Now get out!` | `Taken: Sindokht's strongbox. Now get out!` | "Got:" | better |
| scripts/main.gd:957 | `[Claim] ` | `Claim: ` | square brackets read as a placeholder | better |

## 6. Length (to check on a phone)

Pad buttons draw their label at 10–12 px under a round button (`touch_pad.gd:358`), so anything over about 14 characters will run past the button.

| file:line | text | length | suggested | imp. |
|---|---|---|---|---|
| scripts/skills.gd:64 | `Simorgh's Feather` (pad label, Sage's move) | 17 | `Simorgh Feather` or pad-only short form `Feather` | better |
| scripts/skills.gd:40 | `Whirlwind Strike` (pad label, ultimate) | 16 | `Whirlwind` | better |
| data/Tables/FF_SKILLS.json:23 | `Chain Lightning` (pad label, spell) | 15 | `Chain Bolt` | better |
| scripts/touch_pad.gd:79 + data/Tables/RECIPES.json:47–104 | scroll button: `Scroll: Frost Lance ×3` | 22 | drop the `Scroll: ` prefix on the pad (`Frost Lance ×3`) | better |
| scripts/death_panel.gd:68 | `Story difficulty — then fight again` | 35 | `Story mode & fight again` | better |
| scripts/menu.gd:224 | `Replace saved hero & begin` (240 px button) | 26 | `Overwrite & begin` | better |
| scripts/main.gd:569 | `Begin the tale anew — New Game+ %d` | 34 | `Begin New Game+ %d` | better |
| scripts/main.gd:816, :812, :814 | `Conjure a dragon of flame (6 mana)` · `Offer mercy, sworn on the Ember` · `Show the Ashen Hand's mark` | 34 · 31 · 26 | dialogue choices are full-width rows (min width 0), probably fine; check at Large interface size | better |
| data/Tables/MON_SKINS.json:136 | `Rostam's Robe of Honour` (look card) | 23 | `Rostam's Robe` (Persian is just خلعتِ رستم) | better |
| data/Tables/CH_RELICS.json:23 | `Emberheart of Mazandaran` | 24 | `Mazandaran Emberheart` or `Stone King's Heart` | better |
| scripts/game.gd:182 | `Puladvand, the First Flame` (boss bar name) | 26 | name `Puladvand`, title `The First Flame, Lord of the Emberforge` | better |

## 7. British / American

No American spellings found in displayed text (armour, labour, defence, judgement, honoured, recolours, travellers are all British). `ARMOR_TIERS` is an internal id only. Nothing to change.

---

## Glossary — forms to keep

| thing | seen as | keep |
|---|---|---|
| the hero | Ember-bearer / ember-bearer | `ember-bearer` in address; `Ember-bearer` only as a title (menu, HUD) or at the start of a sentence |
| the mark | the ember / the Ember | `the ember` |
| chapter 2 beast | Dragon of Kashaf / the Wyrm | `the Dragon of Kashaf`, short `the Dragon` |
| risen foes | echo of X / X | `the echo of X`, `X's echo`; verb `return to dust`, never slay/kill; pronoun `it` for an echo (boss hints now mix he / it / she) |
| the old makers | First Smiths / the Smiths / wardens | `the First Smiths`, their `three seals`; no "warden" |
| Pulad of Ghandi | Warden / Keeper of the Forge Gate | `the Keeper` |
| Jamshid's dungeon | the Emberforge / the Forge / Forge of the First Flame | `the Emberforge` |
| Kavian's service | The Forge / refine / Upgrade / forge | `Kavian's Forge`, verb `refine` |
| the bird | Simorgh / Simurgh | `Simorgh` |
| bandit chief | Ashkbus | `Ashkabus of Kushan` |
| evade | Roll / Dodge / Dash | `Roll` (action, button, cooldown); `perfect dodge` for the timed feat only |
| timed block | perfect parry / perfect block | `perfect parry`; button `Block` |
| held attack | heavy blow / heavy attack / charge attack / Power Attacks | `heavy blow` |
| sneak hit | backstab / Sneak Attack | `backstab` |
| opponents | foes / enemies | `foes` in all prose (achievements, spell text, map legend still say "enemies") |
| strong foe | elite / champion of the foe | `elite` |
| Siavash's mode | Trial of Embers / the Trial / the Arena | `the Trial of Embers`, short `the Trial` |
| potion-making | brew / craft | `brew` |
| shrine done | cleansed / completed | `cleansed` |
| materials | Essence / Mana Essences; Bogbloom | `Essence` (uncountable), `Bogbloom` (capital, uncountable) |
| big potion | Greater Potion / Greater HP | `Greater Potion` |
| currency | gold / Gold | `gold` |
| stats | HP·MP·ATK·DEF and Health·Mana·Attack·Defence | abbreviations in stat lines (`+5 ATK`), full words in sentences and on the Hero screen |
| seconds | `3 s`, `3s`, `8 seconds`, `a second` | `3 s` in stat lines |
| ellipsis | `...` / `…` | `...` |
| the White Div's copies | Ice Echo / ice echoes / twins of ice | `Ice Twin` |
| the banner | Derafsh-e Kaviani / Kaveh's banner / the Smith's Banner | all fine; `Derafsh-e Kaviani` as the item name |

Duplicate names left as they are but worth knowing: the sigil gifts `Might` and `Vitality` share names with the talent tree `Might` and the talents `Vitality I / II`; `Wayfarer` and `Gilded Sovereign` are each both an achievement and the look it earns (intended).

## Not reached

- `scenes/*.tscn`, map files (a map's own `name` is used by `Game.map_title` when it is not in `CH_MAPNAME`, e.g. "Trial Grounds"), `project.godot` (app name), `export_presets.cfg`, `docs/`, `reports/store_listing_fa.md` — not read.
- The extractor skips one-word lower-case strings ("gold", "essence") and anything built only from variables; those were seen only where they sat on a line with other text.
- Every `.gd` file and every `data/Tables/*.json` file was extracted and read. Persian text was consulted only to judge a suggestion; it was not edited or reviewed.
- Nothing was checked on a device: the `\\n` item, the capital-"The" messages and all of section 6 should be confirmed in a running build.
