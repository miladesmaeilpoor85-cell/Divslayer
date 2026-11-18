#!/usr/bin/env python3
"""Rebuild data/world_graph.json from the map files (v0.19): every region's size, its exits (the map they lead to and
their rectangle), its villagers (feet positions) and its bosses (feet positions). The compass, the minimap and the
world map read it. Run it after changing a map's exits, NPCs or bosses.

    python3 tools/make_world_graph.py [--check]   (--check: only report the differences with the current file)
"""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BOSSES = {"boss", "boss2", "matriarch", "arbiter", "ignarok", "ancientwyrm", "toadking", "anvilward", "captain", "glaciertitan"}

def main():
	types = json.load(open(os.path.join(ROOT, "data", "Tables", "ENEMY_TYPES.json")))
	out = {}
	mdir = os.path.join(ROOT, "data", "Maps")
	for f in sorted(os.listdir(mdir)):
		if not f.endswith(".json"):
			continue
		key = f[:-5]
		d = json.load(open(os.path.join(mdir, f)))["data"]
		g = {"w": d["w"], "h": d["h"], "exits": [], "npcs": {}, "bosses": {}}
		for e in d.get("exits", []) or []:
			g["exits"].append({"to": e["to"], "r": [e["x"], e["y"], e["w"], e["h"]]})
		for n in d.get("npcs", []) or []:
			g["npcs"][n["id"]] = [float(n["x"]) + float(n.get("w", 26)) * 0.5, n["y"] + n.get("h", 34)]
		for s in d.get("enemySpawns", []) or []:
			t = s["type"]
			if t in BOSSES or types.get(t, {}).get("boss"):
				e = types.get(t, {})
				g["bosses"][t] = [float(s["x"]) + float(e.get("w", 24)) * 0.5, s["y"] + e.get("h", 24)]
		out[key] = g
	path = os.path.join(ROOT, "data", "world_graph.json")
	old = json.load(open(path)) if os.path.exists(path) else {}
	for k in sorted(set(old) | set(out)):
		if old.get(k) != out.get(k):
			print("changed:", k)
	if "--check" not in sys.argv:
		json.dump(out, open(path, "w"), separators=(",", ":"))
		print("wrote", path, len(out), "regions")

if __name__ == "__main__":
	main()
