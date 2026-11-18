#!/usr/bin/env python3
"""Chapter 3 data (v0.23, "Damavand"): the new foes, the two new regions' scaling and names, added to the HTML game's tables.
All of it is mine (the HTML game had no Damavand, Zahhak, Kondrow or serpent guards). Idempotent: run it again after editing.

    python3 tools/ch3_data.py
"""
import json, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ch2_data import edit

# (v0.23 playtest) the slopes' foes hit a little softer than first set: a level-17 hero was swarmed at the entrance
FOES = {
	"serpentguard": {"w": 24, "h": 34, "hp": 42, "dmg": 9, "speed": 1.35, "xp": 70, "gold": 26, "color": "#3a6a4a",
		"name": "Serpent Guard", "applies": {"poison": 1}},
	"serpentarcher": {"w": 24, "h": 34, "hp": 32, "dmg": 8, "speed": 1.0, "xp": 72, "gold": 26, "color": "#2f5a3e",
		"name": "Serpent Archer", "shoots": {"every": 2.4, "speed": 3.4, "applies": "poison", "col": "#9fe07a", "range": 290, "keep": 170, "n": 1}},
	"serpent": {"w": 30, "h": 20, "hp": 36, "dmg": 8, "speed": 2.0, "xp": 48, "gold": 12, "color": "#5a9a4a",
		"name": "Serpent", "applies": {"poison": 1}},
	"kondrow": {"w": 34, "h": 46, "hp": 240, "dmg": 20, "speed": 1.05, "xp": 700, "gold": 380, "color": "#7a4aa0",
		"name": "Kondrow", "knockMult": 0.3, "boss": True, "applies": {"poison": 1}},
	"zahhak": {"w": 60, "h": 72, "hp": 600, "dmg": 26, "speed": 0.7, "xp": 2600, "gold": 1200, "color": "#5a3a7a",
		"name": "Zahhak", "knockMult": 0.1, "boss": True, "applies": {"poison": 2}},
}
NAMES_FA = {"Serpent Guard": "پاسدارِ ماردوش", "Serpent Archer": "کماندارِ ماردوش", "Serpent": "مارِ ضحاک", "Kondrow": "کُندرو",
	"Zahhak": "ضحاک"}
AREA = {"damavand": {"hp": 7.4, "dmg": 2.1}, "zahhakcave": {"hp": 7.8, "dmg": 2.2}}
# boss health: tuned with the balance bot (tests/bosstest.gd --bot --natural --boss zahhak)
BOSS = {"kondrow": {"hp": 4.0, "dmg": 1}, "zahhak": {"hp": 9.0, "dmg": 1}}
MAPNAME = {"damavand": ["The Slopes of Damavand", "دامنهٔ دماوند"], "zahhakcave": ["The Cave of Chains", "غارِ زنجیرها"]}

def foes(d):
	d.update(FOES)

def bal(d):
	d["AREA"].update(AREA)
	d["BOSS"].update(BOSS)

if __name__ == "__main__":
	edit("ENEMY_TYPES.json", foes)
	edit("V12_ENEMY.json", lambda d: d.update(NAMES_FA))
	edit("V12_BAL.json", bal)
	edit("CH_MAPNAME.json", lambda d: d.update(MAPNAME))
