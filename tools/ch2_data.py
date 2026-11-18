#!/usr/bin/env python3
"""Chapter 2 data (v0.19): the new foes, the two new regions' scaling and names, added to the HTML game's tables.
Everything here is mine (the HTML game had no Hoarfrost Vale, Wyrm's Hollow, Glacier Titan, frost wolves, rime wraiths
or wyrmlings); the Ancient Wyrm's entry is the HTML game's, with more XP and gold as the end of the chapter.
Idempotent: run it again after editing the numbers.

    python3 tools/ch2_data.py
"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = os.path.join(ROOT, "data", "Tables")

FOES = {
	"frostwolf": {"w": 30, "h": 22, "hp": 30, "dmg": 8, "speed": 2.15, "xp": 40, "gold": 14, "color": "#cfd8e0",
		"name": "Wolf of the Seven Labours", "applies": {"freeze": 1}},
	"rimewraith": {"w": 28, "h": 38, "hp": 38, "dmg": 9, "speed": 1.0, "xp": 46, "gold": 18, "color": "#a8d0e0",
		"name": "Turanian Sorcerer", "shoots": {"every": 2.6, "speed": 3.0, "applies": "freeze", "col": "#bfe6ff", "range": 270, "keep": 150, "n": 1}},
	"wyrmling": {"w": 38, "h": 44, "hp": 46, "dmg": 10, "speed": 1.2, "xp": 70, "gold": 26, "color": "#7a6ad0", "knockMult": 0.6,
		"name": "Wyrmling", "applies": {"freeze": 1}, "shoots": {"every": 3.8, "speed": 3.2, "applies": "freeze", "col": "#9fd8ff", "range": 240, "keep": 110, "n": 2}},
	"glaciertitan": {"w": 64, "h": 70, "hp": 260, "dmg": 24, "speed": 0.6, "xp": 900, "gold": 450, "color": "#1d3f8a",
		"name": "The Glacier Titan", "knockMult": 0.12, "boss": True, "applies": {"freeze": 2}},
}
NAMES_FA = {"Wolf of the Seven Labours": "گرگِ هفت‌خوان", "Turanian Sorcerer": "جادوگرِ تورانی", "Wyrmling": "اژدهابچه", "The Glacier Titan": "غول یخچال"}
AREA = {"frostvale": {"hp": 6.4, "dmg": 1.9}, "wyrmhollow": {"hp": 7.0, "dmg": 2.0}}
# boss health: tuned with the balance bot (tests/bosstest.gd --bot --natural): the Titan ~40 s, the Wyrm ~90 s for a hero
# at the level and gear a player has by then (the Wyrm's HTML 3.6 left it a 25 s fight against a level 15 hero)
BOSS = {"glaciertitan": {"hp": 8.0, "dmg": 1}, "ancientwyrm": {"hp": 10.0, "dmg": 1}}
MAPNAME = {"frostvale": ["Hoarfrost Vale", "درهٔ یخ‌بندان"], "wyrmhollow": ["The Wyrm's Hollow", "مغاکِ اژدها"]}

def edit(name, fn, compact=False):
	p = os.path.join(T, name)
	d = json.load(open(p))
	fn(d)
	if compact:
		json.dump(d, open(p, "w"), ensure_ascii=False, separators=(",", ":"))
	else:
		json.dump(d, open(p, "w"), ensure_ascii=False, indent=1)
	print("  ", name)

def foes(d):
	d.update(FOES)
	d["ancientwyrm"]["xp"] = 2000
	d["ancientwyrm"]["gold"] = 900

def bal(d):
	d["AREA"].update(AREA)
	d["BOSS"].update(BOSS)

if __name__ == "__main__":
	edit("ENEMY_TYPES.json", foes)
	edit("V12_ENEMY.json", lambda d: d.update(NAMES_FA))
	edit("V12_BAL.json", bal)
	edit("CH_MAPNAME.json", lambda d: d.update(MAPNAME))
