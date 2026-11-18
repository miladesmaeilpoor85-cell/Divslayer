#!/usr/bin/env python3
"""Chapter 3 maps (v0.23, "Damavand"): the Slopes of Damavand (damavand) and the Cave of Chains (zahhakcave), and the new
road east out of the Ashen Peaks. Same format and painting style as tools/ch2_maps.py (whose helpers it uses).

  damavand    1500x1200: the road in from the peaks (west), Qaren's camp, Kondrow's ruined terrace (north-west), the old fire
              temple with its three altars (south-east), lava vents and ash, snow on the heights, and the Gate of Damavand
              in the mountain's face (north), which only the Kaviani banner opens
  zahhakcave  1200x1000: a basalt cave going down from the gate to the chained king's hollow (the binding circle, the four
              great chains' anchors)

    python3 tools/ch3_maps.py [damavand] [zahhakcave] [peaks]
Then: python3 tools/make_world_graph.py; python3 tools/map_preview.py damavand out.png
"""
import json, math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ch2_maps import Map, GS, noise, lerp, to_img, poly_mask, smooth_path, save_jpg, ROOT

# where chapter 3's pieces stand (the game reads these from the map's "ch3" block)
ALTARS = [(1060, 760), (1230, 760), (1145, 905)]
TEMPLE_CHEST = (1145, 820)
GATE = (760, 0)

def damavand():
	m = Map("damavand", "The Slopes of Damavand", 1500, 1200, 3303)
	W, H = m.w, m.h
	rng = m.rng
	roads = [
		[(0, 620), (160, 640), (300, 700), (360, 790)],              # in from the peaks to Qaren's camp
		[(300, 700), (330, 520), (320, 360)],                         # north-west up to Kondrow's terrace
		[(330, 520), (560, 470), (720, 330), (760, 180), (760, 60)],  # the climb to the Gate
		[(560, 470), (820, 600), (1000, 700), (1100, 800)],           # east down to the fire temple
	]
	paths = [smooth_path(r, rng, wob=10) for r in roads]
	for p in paths:
		for (x, y) in p[::2]:
			m.clear(x, y, 36)
	camp = (360, 820)
	terrace = (320, 260)
	temple = (1145, 830)
	m.clear(camp[0], camp[1], 140)
	m.clear(terrace[0], terrace[1], 175)
	m.clear(temple[0], temple[1], 170)
	m.clear(760, 90, 130)              # before the Gate
	m.clear(40, 620, 80)               # the road from the peaks
	# ---- Qaren's camp: the watch Kaveh's son keeps on the mountain
	m.obj("v17tent", camp[0] - 100, camp[1] - 40, r=60)
	m.obj("v17tent", camp[0] + 105, camp[1] - 50, r=60)
	m.obj("campfire", camp[0], camp[1] + 22, wall=False, r=16)
	m.obj("banner", camp[0] - 40, camp[1] - 60, wall=False)
	m.obj("banner", camp[0] + 40, camp[1] - 64, wall=False)
	m.obj("crates", camp[0] + 150, camp[1] + 40, r=34)
	m.obj("barrel", camp[0] - 140, camp[1] + 50, wall=False)
	m.obj("torch", camp[0] - 70, camp[1] + 60, wall=False)
	m.light(camp[0], camp[1] + 15, 160, 0.85, "#ffb070")
	m.npcs.append({"id": "qaren", "x": camp[0] + 30 - 13, "y": camp[1] + 10 - 34, "w": 26, "h": 34, "color": "#b04040",
		"name": "Qaren, Kaveh's Son", "_en": "Qaren, Kaveh's Son"})
	# ---- Kondrow's terrace: the steward's ruined hall, columns in a broken ring, braziers, the guards
	tx, ty = terrace
	for i in range(10):
		a = math.pi * 2 * i / 10 + 0.3
		if abs(((a - math.pi * 0.5) + math.pi) % (2 * math.pi) - math.pi) < 0.45:
			continue                       # the way in, from the south
		x, y = tx + math.cos(a) * 165, ty + math.sin(a) * 130
		if 40 < x < W - 40 and 70 < y < H - 30:
			m.obj("column", x, y, sprite="column_128" if i % 3 else "column_132", r=30)
	m.obj("stonewall_h", tx, ty - 150, sprite="stonewall_53", r=40)
	for (dx, dy) in [(-80, -60), (80, -60)]:
		m.obj("brazier", tx + dx, ty + dy, wall=False, r=16)
		m.light(tx + dx, ty + dy - 24, 130, 0.8, "#ffb070")
	for i in range(5):
		m.obj("bones", tx + rng.uniform(-110, 110), ty + rng.uniform(-70, 90), wall=False, r=0)
	m.spawn("kondrow", tx - 17, ty - 46)
	for (dx, dy) in [(-120, 70), (110, 60)]:          # (v0.23 playtest) two, not three: Kondrow is the fight
		m.spawn("serpentguard", tx + dx - 12, ty + dy - 34)
	# ---- the fire temple: a ring of columns, three cold altars (the game draws and lights them), its chest
	cx, cy = temple
	for i in range(8):
		a = math.pi * 2 * i / 8 + 0.4
		if abs(((a - math.pi) + math.pi) % (2 * math.pi) - math.pi) < 0.5:
			continue                       # open toward the road (west)
		m.obj("pillar", cx + math.cos(a) * 160, cy + math.sin(a) * 125, sprite="pillar_51", r=30)
	m.light(cx, cy, 200, 0.25, "#ff9040")
	for (dx, dy) in [(-170, -150), (150, -160), (200, 70)]:
		m.spawn("serpentarcher", cx + dx - 12, cy + dy - 34)
	# ---- the Gate of Damavand: the cliff of the mountain across the top, the door in the middle (drawn by the game)
	for x in range(40, W - 20, 120):
		if abs(x - GATE[0]) < 120:
			continue
		m.obj("spire", x + rng.uniform(-14, 14), 70 + rng.uniform(-8, 14), r=40)
	m.walls.append({"x": 0, "y": 0, "w": GATE[0] - 70, "h": 46, "color": "#2a2020"})
	m.walls.append({"x": GATE[0] + 70, "y": 0, "w": W - GATE[0] - 70, "h": 46, "color": "#2a2020"})
	for (dx, dy) in [(-110, 110), (110, 110)]:
		m.obj("brazier", GATE[0] + dx, GATE[1] + dy, wall=False, r=16)
		m.light(GATE[0] + dx, GATE[1] + dy - 24, 140, 0.8, "#c080ff")
	for (dx, dy) in [(-60, 170), (70, 180)]:
		m.spawn("serpentguard", GATE[0] + dx - 12, GATE[1] + dy - 34)
	m.spawn("serpentarcher", GATE[0] - 150, GATE[1] + 230)
	# ---- the slopes: lava spires, vents and pools, rocks, dead trees, boulders, bones
	m.scatter(["spire"], (40, 180, W - 40, H - 40), 18, 42)
	m.scatter(["boulders"], (60, 160, W - 60, H - 40), 8, 44)
	m.scatter(["deadtree"], (40, 160, W - 40, H - 30), 12, 30, wall=False)
	m.scatter(["rock"], (40, 120, W - 40, H - 20), 30, 16, wall=False)
	m.scatter(["vent"], (80, 200, W - 80, H - 60), 9, 20, wall=False)
	m.scatter(["bones"], (40, 160, W - 40, H - 30), 8, 12, wall=False)
	for (x, y, w, h) in [(520, 980, 120, 70), (930, 380, 110, 70), (1300, 520, 120, 80), (620, 760, 90, 60)]:
		m.hazards.append({"x": x, "y": y, "w": w, "h": h})            # lava (untyped, as in the peaks)
	m.lava = [(x + w / 2, y + h / 2, w / 2, h / 2) for (x, y, w, h) in [(520, 980, 120, 70), (930, 380, 110, 70), (1300, 520, 120, 80), (620, 760, 90, 60)]]
	# ---- foes: guard packs on the roads, archers, Zahhak's serpents in the ash, ember imps by the vents
	for (px, py) in [(640, 560), (900, 690), (1120, 600)]:     # (the third pack moved off Kondrow's terrace)
		for k in range(3):
			m.spawn("serpentguard", px + rng.uniform(-50, 50) - 12, py + rng.uniform(-30, 30) - 34)
	for (px, py) in [(980, 470), (230, 470)]:
		m.spawn("serpentarcher", px - 12, py - 34)
	for (px, py) in [(700, 900), (820, 1000), (1280, 300), (1180, 420), (430, 1020), (1350, 1050)]:
		m.spawn("serpent", px - 15, py - 20)
	for (px, py) in [(1000, 1050), (1380, 760), (180, 1000), (600, 1100)]:
		m.spawn("imp", px - 10, py - 24)
	# ---- things lying about
	m.item("potion", 120, 900)
	m.item("potion", 1420, 300)
	m.item("mana_potion", 640, 280)
	m.item("greater_potion", 900, 1080)
	m.item("obsidian", 1400, 980)
	m.item("obsidian", 470, 160)
	m.item("chest", 1370, 160)
	# ---- the way back to the peaks; the hero arrives here; the Gate up north (its exit opens with the banner)
	m.exits.append({"x": 0, "y": 560, "w": 20, "h": 120, "to": "peaks", "spawnX": 1100, "spawnY": 626, "dir": "left"})
	m.exits.append({"x": GATE[0] - 45, "y": 0, "w": 90, "h": 16, "to": "zahhakcave", "spawnX": 600, "spawnY": 60, "dir": "up"})
	m.start = {"x": 40, "y": 626}
	m.write({"ch3": {"altars": [list(a) for a in ALTARS], "chest": list(TEMPLE_CHEST), "gate": list(GATE)}})
	paint_damavand(m, paths)

def paint_damavand(m, paths):
	rng = np.random.default_rng(3303)
	W, H = m.w * GS, m.h * GS
	n1 = noise(W, H, 380, rng, 3)
	n2 = noise(W, H, 70, rng, 2)
	ash_a = np.array([92, 84, 80], np.float32)
	ash_b = np.array([58, 52, 52], np.float32)
	base = lerp(ash_a, ash_b, np.clip(n1 * 1.4 - 0.2, 0, 1)) * (0.92 + 0.12 * n2[..., None])
	# snow on the heights (the top), thinning down the slope
	yy, xx = np.mgrid[0:H, 0:W]
	snow = np.clip(1.0 - (yy / GS - 40.0) / 260.0 + (n1 - 0.5) * 0.9, 0, 1) ** 1.4
	base = base * (1 - snow[..., None] * 0.85) + np.array([214, 218, 228], np.float32) * snow[..., None] * 0.85
	img = to_img(base)
	d = ImageDraw.Draw(img, "RGBA")
	pr = random.Random(33)
	# glowing cracks in the ash (lower slopes), pumice, pebbles, cinder drifts
	for _ in range(160):
		x, y = pr.uniform(0, W), pr.uniform(300 * GS, H)
		pts = [(x, y)]
		a = pr.uniform(0, 6.28)
		for k in range(pr.randint(3, 6)):
			a += pr.uniform(-0.8, 0.8)
			x += math.cos(a) * pr.uniform(12, 34)
			y += math.sin(a) * pr.uniform(12, 34)
			pts.append((x, y))
		d.line(pts, fill=(255, 110, 40, 60), width=9)
		d.line(pts, fill=(255, 170, 70, 170), width=3)
		d.line([(p[0] + 2, p[1] + 2) for p in pts], fill=(30, 20, 18, 150), width=2)
	for _ in range(3000):
		x, y = pr.uniform(0, W), pr.uniform(0, H)
		r = pr.uniform(1.5, 4.5)
		c = pr.choice([(40, 34, 34, 140), (120, 110, 104, 120), (150, 70, 40, 90)])
		d.ellipse([x - r, y - r, x + r, y + r], fill=c)
	for _ in range(140):
		x, y = pr.uniform(0, W), pr.uniform(0, H)
		rx, ry = pr.uniform(40, 130), pr.uniform(12, 36)
		d.ellipse([x - rx, y - ry, x + rx, y + ry], fill=(40, 34, 34, 34))
	# lava pools: a dark crust, molten middle
	for (cx, cy, rx, ry) in m.lava:
		cx, cy, rx, ry = cx * GS, cy * GS, rx * GS * 1.08, ry * GS * 1.1
		d.ellipse([cx - rx - 10, cy - ry - 10, cx + rx + 10, cy + ry + 10], fill=(40, 22, 18, 255))
		d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(230, 90, 30, 255))
		d.ellipse([cx - rx * 0.6, cy - ry * 0.55, cx + rx * 0.6, cy + ry * 0.55], fill=(255, 190, 80, 255))
		for k in range(8):
			a = pr.uniform(0, 6.28)
			d.ellipse([cx + math.cos(a) * rx * 0.5 - 14, cy + math.sin(a) * ry * 0.5 - 8, cx + math.cos(a) * rx * 0.5 + 14, cy + math.sin(a) * ry * 0.5 + 8], fill=(120, 40, 20, 200))
	# trodden paths: pale packed ash with a darker rim, stones along the way
	pm = poly_mask((W, H), paths, 46, 6)
	img.paste(Image.new("RGB", (W, H), (70, 62, 60)), (0, 0), pm.point(lambda v: int(v * 0.8)))
	inner = poly_mask((W, H), paths, 28, 6)
	img.paste(Image.new("RGB", (W, H), (128, 118, 110)), (0, 0), inner.point(lambda v: int(v * 0.75)))
	d = ImageDraw.Draw(img, "RGBA")
	for p in paths:
		for i in range(0, len(p) - 1, 2):
			x, y = p[i][0] * GS, p[i][1] * GS
			for s in (-1, 1):
				if pr.random() < 0.5:
					r = pr.uniform(4, 8)
					d.ellipse([x + s * 30 - r, y - r * 0.7, x + s * 30 + r, y + r * 0.7], fill=(54, 48, 46, 200))
	# the temple's floor: old flagstones in a ring, a fire-sign in the middle
	cx, cy = 1145 * GS, 830 * GS
	for rr in range(60, 300, 46):
		d.ellipse([cx - rr, cy - rr * 0.78, cx + rr, cy + rr * 0.78], outline=(50, 44, 42, 160), width=6)
	d.ellipse([cx - 300, cy - 234, cx + 300, cy + 234], fill=(110, 100, 92, 70))
	for i in range(12):
		a = i / 12 * 6.283
		d.line([(cx + math.cos(a) * 60, cy + math.sin(a) * 47), (cx + math.cos(a) * 300, cy + math.sin(a) * 234)], fill=(50, 44, 42, 120), width=4)
	# Kondrow's terrace: cracked marble
	tx, ty = 320 * GS, 260 * GS
	d.ellipse([tx - 330, ty - 260, tx + 330, ty + 260], fill=(150, 140, 150, 110))
	for _ in range(60):
		x, y = tx + pr.uniform(-300, 300), ty + pr.uniform(-230, 230)
		d.line([(x, y), (x + pr.uniform(-40, 40), y + pr.uniform(-30, 30))], fill=(70, 60, 70, 140), width=3)
	# the gate's apron: worn steps of black stone
	gx = 760 * GS
	for k in range(5):
		d.rectangle([gx - 160 + k * 14, 50 * GS + k * 22, gx + 160 - k * 14, 50 * GS + k * 22 + 18], fill=(44, 38, 44, 230), outline=(20, 16, 20, 255), width=3)
	# a vignette
	edge = np.minimum(np.minimum(xx, W - xx), np.minimum(yy, H - yy)).astype(np.float32)
	k = np.clip(1.0 - edge / 240.0, 0, 1) * 0.22
	arr = np.asarray(img, np.float32) * (1.0 - k[..., None]) + np.array([30, 22, 24], np.float32) * k[..., None]
	save_jpg(to_img(arr), m.key)

# ================================================================ the Cave of Chains
CAVE = [
	"##########....##########",
	"#########......#########",
	"########........########",
	"#######....##....#######",
	"######....####....######",
	"#####....######....#####",
	"####.....######.....####",
	"###......######......###",
	"###.......####.......###",
	"####.......##.......####",
	"#####..............#####",
	"###..................###",
	"##....................##",
	"##....................##",
	"##....................##",
	"##....................##",
	"###..................###",
	"####................####",
	"######............######",
	"########################",
]
C = 50
ANCHORS = [(250, 610), (950, 610), (250, 900), (950, 900)]
LAIR = (600, 770)

def zahhakcave():
	assert all(len(r) == 24 for r in CAVE) and len(CAVE) == 20
	m = Map("zahhakcave", "The Cave of Chains", 1200, 1000, 6606)
	rng = m.rng
	rock = [[ch == "#" for ch in row] for row in CAVE]
	runs = {}
	for y, row in enumerate(rock):
		x = 0
		while x < 24:
			if row[x]:
				x0 = x
				while x < 24 and row[x]:
					x += 1
				runs.setdefault((x0, x), []).append(y)
			else:
				x += 1
	for (x0, x1), ys in runs.items():
		ys.sort()
		start = prev = ys[0]
		for y in ys[1:] + [None]:
			if y is not None and y == prev + 1:
				prev = y
				continue
			m.walls.append({"x": x0 * C + 6, "y": start * C + 6, "w": (x1 - x0) * C - 12, "h": (prev - start + 1) * C - 12, "color": "#1a1420"})
			if y is not None:
				start = prev = y
	def floor(cx, cy):
		return 0 <= cx < 24 and 0 <= cy < 20 and not rock[cy][cx]
	for cy in range(20):
		for cx in range(24):
			if not floor(cx, cy):
				continue
			n = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if not floor(cx + dx, cy + dy))
			if n == 0 or cy <= 1 or (11 <= cy and 4 <= cx <= 19):
				continue
			x, y = cx * C + C / 2 + rng.uniform(-8, 8), cy * C + C / 2 + rng.uniform(4, 16)
			r = rng.random()
			if r < 0.28 and m.free(x, y, 22, margin=10):
				m.obj("spire", x, y, r=26)
			elif r < 0.5 and m.free(x, y, 10, margin=10):
				m.obj(rng.choice(["rock", "rock", "bones"]), x, y, wall=False, r=10)
	# the way down: braziers of violet fire, serpent guards, serpents in the side halls
	for (x, y) in [(520, 80), (680, 80)]:
		m.obj("brazier", x, y, wall=False, r=14)
		m.light(x, y - 22, 130, 0.8, "#b070ff")
	m.spawn("serpentguard", 560, 180)
	m.spawn("serpentguard", 630, 190)
	for (x, y) in [(300, 320), (360, 380), (240, 420)]:
		m.spawn("serpent", x, y)
	for (x, y) in [(880, 320), (830, 390), (930, 430)]:
		m.spawn("serpent", x, y)
	m.spawn("serpentarcher", 300, 470)
	m.spawn("serpentarcher", 880, 470)
	m.item("greater_potion", 220, 360)
	m.item("greater_potion", 980, 360)
	m.item("potion", 600, 520)
	# the hollow: four great anchors of the chains, braziers, bones; the chained king in the middle
	for (x, y) in ANCHORS:
		m.obj("pillar", x, y, sprite="pillar_108", r=30)
		m.light(x, y - 60, 120, 0.5, "#b070ff")
	for i in range(12):
		x, y = rng.uniform(180, 1020), rng.uniform(640, 900)
		if abs(x - LAIR[0]) > 140 or abs(y - LAIR[1]) > 90:
			m.obj("bones", x, y, wall=False, r=0)
	m.spawn("zahhak", LAIR[0] - 30, LAIR[1] - 72)
	m.light(LAIR[0], LAIR[1] - 20, 280, 0.35, "#9060d0")
	m.exits.append({"x": 560, "y": 0, "w": 80, "h": 16, "to": "damavand", "spawnX": GATE[0], "spawnY": 130, "dir": "up"})
	m.start = {"x": 600, "y": 60}
	m.write({"ch3": {"anchors": [list(a) for a in ANCHORS], "lair": list(LAIR)}})
	paint_cave(m, rock)

def paint_cave(m, rock):
	rng = np.random.default_rng(6606)
	W, H = m.w * GS, m.h * GS
	cell = Image.new("L", (24, 20), 0)
	cell.putdata([255 if rock[y][x] else 0 for y in range(20) for x in range(24)])
	mask = cell.resize((W, H), Image.NEAREST).filter(ImageFilter.GaussianBlur(26))
	mk = np.asarray(mask, np.float32) / 255.0
	wob = noise(W, H, 70, rng, 2)
	mk = np.clip((mk + (wob - 0.5) * 0.35 - 0.5) * 6.0 + 0.5, 0, 1)
	n1 = noise(W, H, 300, rng, 3)
	n2 = noise(W, H, 40, rng, 2)
	floor_a = np.array([62, 54, 66], np.float32)
	floor_b = np.array([40, 34, 44], np.float32)
	floor = lerp(floor_a, floor_b, np.clip(n1 * 1.3 - 0.15, 0, 1)) * (0.92 + 0.12 * n2[..., None])
	rock_a = np.array([22, 18, 26], np.float32)
	rock_b = np.array([36, 30, 40], np.float32)
	rockc = lerp(rock_a, rock_b, n2) * (0.9 + 0.2 * n1[..., None])
	img = to_img(floor * (1 - mk[..., None]) + rockc * mk[..., None])
	d = ImageDraw.Draw(img, "RGBA")
	pr = random.Random(66)
	for _ in range(800):
		x, y = pr.uniform(0, W), pr.uniform(0, H)
		if mk[int(y), int(x)] > 0.2:
			continue
		pts = [(x, y)]
		a = pr.uniform(0, 6.28)
		for k in range(pr.randint(2, 4)):
			a += pr.uniform(-0.9, 0.9)
			x += math.cos(a) * pr.uniform(8, 22)
			y += math.sin(a) * pr.uniform(8, 22)
			pts.append((x, y))
		d.line(pts, fill=(20, 16, 24, 150), width=2)
	for _ in range(2200):
		x, y = pr.uniform(0, W), pr.uniform(0, H)
		if mk[int(y), int(x)] > 0.2:
			continue
		r = pr.uniform(1.5, 4)
		d.ellipse([x - r, y - r, x + r, y + r], fill=(100, 90, 110, 110))
	# veins: violet sorcery and old embers
	for _ in range(60):
		x, y = pr.uniform(0, W), pr.uniform(0, H)
		if mk[int(y), int(x)] > 0.05:
			continue
		pts = [(x, y)]
		a = pr.uniform(0, 6.28)
		for k in range(pr.randint(3, 7)):
			a += pr.uniform(-0.7, 0.7)
			x += math.cos(a) * pr.uniform(14, 34)
			y += math.sin(a) * pr.uniform(14, 34)
			pts.append((x, y))
		col = (150, 80, 230) if pr.random() < 0.6 else (255, 120, 50)
		d.line(pts, fill=col + (60,), width=9)
		d.line(pts, fill=tuple(min(255, c + 60) for c in col) + (190,), width=3)
	for _ in range(600):
		x, y = pr.uniform(0, W), pr.uniform(0, H)
		if mk[int(y), int(x)] < 0.8:
			continue
		l = pr.uniform(20, 60)
		d.line([x, y, x + l, y + pr.uniform(-6, 6)], fill=(50, 42, 56, 120), width=3)
	edge = Image.fromarray((mk * 255).astype(np.uint8)).filter(ImageFilter.FIND_EDGES).filter(ImageFilter.GaussianBlur(3))
	img.paste(Image.new("RGB", (W, H), (150, 110, 190)), (0, 0), edge.point(lambda v: min(255, int(v * 2.0))))
	shade = Image.fromarray((mk * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(18))
	sh = np.asarray(shade, np.float32) / 255.0
	arr = np.asarray(img, np.float32)
	arr = arr * (1.0 - 0.35 * np.clip(sh - mk, 0, 1)[..., None])
	img = to_img(arr)
	d = ImageDraw.Draw(img, "RGBA")
	# Fereydun's binding circle round the chained king
	cx, cy = LAIR[0] * GS, LAIR[1] * GS
	for rr, col, wd in [(360, (170, 110, 230, 70), 8), (330, (210, 160, 250, 90), 3), (230, (170, 110, 230, 60), 4)]:
		d.ellipse([cx - rr, cy - rr * 0.6, cx + rr, cy + rr * 0.6], outline=col, width=wd)
	for i in range(8):
		a = i / 8.0 * 6.283
		x, y = cx + math.cos(a) * 345, cy + math.sin(a) * 345 * 0.6
		d.regular_polygon((x, y, 14), 4, rotation=45 + i * 11, outline=(220, 180, 255, 150), width=3)
	save_jpg(img, m.key, q=86)

# ================================================================ the peaks' new road east
def patch_peaks():
	p = os.path.join(ROOT, "data", "Maps", "peaks.json")
	md = json.load(open(p))
	ex = [e for e in md["data"]["exits"] if e["to"] != "damavand"]
	ex.append({"x": 1130, "y": 566, "w": 20, "h": 120, "to": "damavand", "spawnX": 34, "spawnY": 626, "dir": "right"})
	md["data"]["exits"] = ex
	json.dump(md, open(p, "w"), indent=1, ensure_ascii=False)
	print("peaks: exits", [e["to"] for e in ex])

if __name__ == "__main__":
	which = sys.argv[1:] or ["peaks", "damavand", "zahhakcave"]
	if "peaks" in which:
		patch_peaks()
	if "damavand" in which:
		damavand()
	if "zahhakcave" in which:
		zahhakcave()
