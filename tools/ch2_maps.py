#!/usr/bin/env python3
"""Chapter 2 maps (v0.19): the Hoarfrost Vale (frostvale) and the Wyrm's Hollow (wyrmhollow).

Writes data/Maps/<key>.json in the HTML game's map format (objects, walls, exits, hazards, NPCs, spawns, items, lights)
and paints assets/art/Maps/<key>_ground.jpg in the style of the HTML game's code-drawn grounds (a soft base, mottling,
small strokes, paths with a rim). Deterministic: the same seed gives the same maps.

    python3 tools/ch2_maps.py            # both maps
    python3 tools/ch2_maps.py frostvale  # one
Then: python3 tools/map_preview.py frostvale out.png   (and re-import in Godot)
"""
import json, math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = json.load(open(os.path.join(ROOT, "data", "map_object_sprites.json")))
GS = 2  # ground scale: the image is twice the map size

# wall footprints (relative to the object's feet), from the HTML maps
FOOT = {
	"pine": (-20, -60, 40, 60), "tree": (-20, -60, 40, 60), "crystals": (-25, -70, 50, 70), "spire": (-25, -70, 50, 70), "icespire": (-25, -70, 50, 70),
	"pillar": (-25, -70, 50, 70), "column": (-25, -60, 50, 60), "boulders": (-30, -60, 60, 60), "v17tent": (-60, -70, 120, 70),
	"crates": (-35, -80, 70, 80), "stonewall_v": (-20, -220, 40, 220), "stonewall_h": (-110, -45, 220, 45), "log": (-20, -140, 40, 140),
}

def sprite_of(kind, rng):
	names = sorted(k for k in SPRITES if k.rsplit("_", 1)[0] == kind)
	return rng.choice(names)

class Map:
	def __init__(self, key, name, w, h, seed):
		self.key, self.name, self.w, self.h = key, name, w, h
		self.rng = random.Random(seed)
		self.objects, self.walls, self.exits, self.hazards = [], [], [], []
		self.npcs, self.spawns, self.items, self.lights = [], [], [], []
		self.keep = []          # areas kept clear: (x, y, r)
		self.taken = []         # placed solid things: (x, y, r)
		self.start = None

	def clear(self, x, y, r):
		self.keep.append((x, y, r))

	def free(self, x, y, r, margin=40):
		if x < margin or y < margin + 20 or x > self.w - margin or y > self.h - 10:
			return False
		for (cx, cy, cr) in self.keep:
			if (x - cx) ** 2 + (y - cy) ** 2 < (cr + r) ** 2:
				return False
		for (cx, cy, cr) in self.taken:
			if (x - cx) ** 2 + (y - cy) ** 2 < (cr + r) ** 2:
				return False
		return True

	def obj(self, kind, x, y, sprite=None, wall=True, r=None, sort=None, foot=None):
		sp = sprite or sprite_of(kind.replace("_v", "").replace("_h", ""), self.rng)
		k = kind.split("_")[0] if kind.startswith("stonewall") else kind
		o = {"sprite": sp, "x": int(x), "y": int(y), "sort": int(sort if sort is not None else y), "kind": k,
			"isWall": bool(wall and (foot or kind in FOOT)), "animated": False, "smoke": None}
		self.objects.append(o)
		f = foot or FOOT.get(kind)
		if wall and f:
			self.walls.append({"x": int(x + f[0]), "y": int(y + f[1]), "w": int(f[2]), "h": int(f[3]), "color": "#2a3a4a"})
		self.taken.append((x, y, r if r is not None else (28 if f else 14)))
		return o

	def scatter(self, kinds, rect, n, r, wall=True, tries=400):
		x0, y0, x1, y1 = rect
		placed = 0
		for _ in range(tries):
			if placed >= n:
				break
			x = self.rng.uniform(x0, x1)
			y = self.rng.uniform(y0, y1)
			if self.free(x, y, r):
				self.obj(self.rng.choice(kinds), x, y, wall=wall, r=r)
				placed += 1
		return placed

	def light(self, x, y, r, i, c):
		self.lights.append({"x": round(x, 1), "y": round(y, 1), "r": r, "i": i, "c": c})

	def spawn(self, t, x, y):
		self.spawns.append({"type": t, "x": int(x), "y": int(y)})

	def item(self, t, x, y):
		self.items.append({"x": int(x), "y": int(y), "w": 20, "h": 26, "type": t})

	def write(self, extra=None):
		d = {"name": self.name, "w": self.w, "h": self.h, "bg": "#000000", "walls": self.walls, "exits": self.exits,
			"hazards": self.hazards, "npcs": self.npcs, "enemySpawns": self.spawns, "items": self.items,
			"playerStart": self.start}
		md = {"groundScale": GS, "data": d, "objects": sorted(self.objects, key=lambda o: o["sort"]), "lights": self.lights,
			"grass": None, "v16objs": []}
		if extra:
			md.update(extra)
		p = os.path.join(ROOT, "data", "Maps", self.key + ".json")
		json.dump(md, open(p, "w"), indent=1)
		print("%s: %d objects, %d walls, %d spawns, %d items, %d lights -> %s" % (self.key, len(self.objects), len(self.walls),
			len(self.spawns), len(self.items), len(self.lights), p))

# ---------------------------------------------------------------- painting helpers
def noise(w, h, cell, rng, octaves=3):
	"""smooth value noise in 0..1"""
	out = np.zeros((h, w), np.float32)
	amp, tot = 1.0, 0.0
	for o in range(octaves):
		c = max(2, int(cell / (2 ** o)))
		gw, gh = w // c + 2, h // c + 2
		g = rng.random((gh, gw)).astype(np.float32)
		im = Image.fromarray((g * 255).astype(np.uint8)).resize((gw * c, gh * c), Image.BICUBIC)
		out += np.asarray(im, np.float32)[:h, :w] / 255.0 * amp
		tot += amp
		amp *= 0.5
	return out / tot

def lerp(a, b, t):
	return a + (b - a) * t[..., None]

def to_img(arr):
	return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")

def poly_mask(size, lines, width, blur):
	m = Image.new("L", size, 0)
	d = ImageDraw.Draw(m)
	for pts in lines:
		pp = [(x * GS, y * GS) for x, y in pts]
		d.line(pp, fill=255, width=int(width * GS), joint="curve")
		for x, y in pp:
			d.ellipse([x - width * GS / 2, y - width * GS / 2, x + width * GS / 2, y + width * GS / 2], fill=255)
	return m.filter(ImageFilter.GaussianBlur(blur * GS))

def smooth_path(pts, rng, wob=10, step=24):
	"""a hand-drawn path through the points: resampled, with a slow wobble"""
	out = []
	for i in range(len(pts) - 1):
		(x0, y0), (x1, y1) = pts[i], pts[i + 1]
		n = max(2, int(math.hypot(x1 - x0, y1 - y0) / step))
		nx, ny = -(y1 - y0), (x1 - x0)
		ln = math.hypot(nx, ny) or 1.0
		nx, ny = nx / ln, ny / ln
		ph = rng.uniform(0, 6.28)
		for k in range(n):
			t = k / n
			off = math.sin(t * math.pi * 2 + ph) * wob * math.sin(t * math.pi)
			out.append((x0 + (x1 - x0) * t + nx * off, y0 + (y1 - y0) * t + ny * off))
	out.append(pts[-1])
	return out

def save_jpg(img, key, q=84):
	p = os.path.join(ROOT, "assets", "art", "Maps", key + "_ground.jpg")
	img.save(p, quality=q, optimize=True, progressive=False)
	print("  ground %s %dx%d %d KB" % (p, img.width, img.height, os.path.getsize(p) // 1024))

# ================================================================ the Hoarfrost Vale
def frostvale():
	m = Map("frostvale", "Hoarfrost Vale", 1400, 1100, 1907)
	W, H = m.w, m.h
	rng = m.rng
	# roads (in map pixels): west gate -> fork -> camp; fork -> north shore -> the Titan's clearing; camp -> grotto; -> watch-post
	roads = [
		[(0, 540), (180, 548), (290, 610), (320, 760), (350, 830)],
		[(180, 548), (420, 440), (620, 395), (850, 392), (1000, 440), (1090, 520), (1160, 540)],
		[(360, 850), (600, 905), (850, 880), (1060, 880), (1150, 905)],
		[(850, 392), (910, 290), (965, 230)],
	]
	paths = [smooth_path(r, rng, wob=9) for r in roads]
	for p in paths:
		for (x, y) in p[::2]:
			m.clear(x, y, 34)
	lake = (700, 640, 215, 120)             # the frozen lake: centre, radii
	camp = (330, 850)
	titan = (1170, 560)
	m.clear(camp[0], camp[1], 135)
	m.clear(titan[0], titan[1], 215)
	m.clear(lake[0], lake[1], 220)
	m.clear(40, 540, 70)                    # the gate from the sanctum
	m.clear(975, 215, 95)                   # the watch-post
	m.clear(1150, 905, 110)                 # the grotto
	# ---- the frozen lake: slippery ice (hazard "ice"), as the sanctum's patches
	cx, cy, rx, ry = lake
	for k, (fx, fy) in enumerate([(0.0, 0.0), (-0.55, 0.0), (0.55, 0.0), (0.0, -0.55), (0.0, 0.55)]):
		ww = rx * (1.05 if k == 0 else 0.55)
		hh = ry * (1.05 if k == 0 else 0.6)
		m.hazards.append({"x": int(cx + fx * rx - ww * 0.62), "y": int(cy + fy * ry - hh * 0.62), "w": int(ww * 1.24), "h": int(hh * 1.24), "type": "ice"})
	# ---- the trapper's camp: two tents, the fire, his rack and crates; Hesk by the fire
	m.obj("v17tent", camp[0] - 95, camp[1] - 40, r=60)
	m.obj("v17tent", camp[0] + 100, camp[1] - 55, r=60)
	m.obj("campfire", camp[0], camp[1] + 22, wall=False, r=16)
	m.obj("rack", camp[0] - 125, camp[1] + 45, wall=False)
	m.obj("crate", camp[0] + 120, camp[1] + 40, wall=False)
	m.obj("crate", camp[0] + 145, camp[1] + 55, wall=False)
	m.obj("barrel", camp[0] + 88, camp[1] + 62, wall=False)
	m.obj("stump", camp[0] - 48, camp[1] + 48, wall=False)
	m.obj("stump", camp[0] + 46, camp[1] + 52, wall=False)
	m.obj("sign", 300, 720, wall=False)
	m.light(camp[0], camp[1] + 15, 150, 0.85, "#ffb070")
	m.npcs.append({"id": "hesk", "x": camp[0] - 13 - 34, "y": camp[1] + 12 - 34, "w": 26, "h": 34, "color": "#c8b090", "name": "Hesk the Trapper", "_en": "Hesk the Trapper"})
	# ---- the Titan's clearing: a ring of ice spires and crystals, open to the west; ice braziers
	tx, ty = titan
	for i in range(16):
		a = math.pi * 2 * i / 16
		if abs(((a - math.pi) + math.pi) % (2 * math.pi) - math.pi) < 0.5:
			continue                          # the opening, facing the road
		rr = 170 + rng.uniform(-6, 8)
		x, y = tx + math.cos(a) * rr, ty + math.sin(a) * rr * 0.8
		if 40 < x < W - 30 and 70 < y < H - 20:
			m.obj("icespire" if i % 2 == 0 else "crystals", x, y, r=30)
	for (dx, dy) in [(-110, -85), (110, -85), (-110, 95), (110, 95)]:
		m.obj("icebrazier", tx + dx, ty + dy, wall=False, r=18)
		m.light(tx + dx, ty + dy - 20, 120, 0.7, "#9fdcff")
	for i in range(5):
		m.obj("bones", tx + rng.uniform(-110, 110), ty + rng.uniform(-80, 90), wall=False, r=0)
	m.spawn("glaciertitan", tx - 32, ty - 72)
	# ---- the ruined watch-post (north-east): broken walls and columns, a banner, the frost knights' chest
	wx, wy = 975, 215
	m.obj("stonewall_h", wx - 10, wy - 70, sprite="stonewall_53", r=40)
	m.obj("column", wx - 115, wy + 10, r=30)
	m.obj("column", wx + 110, wy + 15, r=30)
	m.obj("pillar", wx + 60, wy - 95, sprite="pillar_51", r=30)
	m.obj("banner", wx - 60, wy - 60, wall=False)
	m.obj("crates", wx + 160, wy - 40, r=35)
	m.obj("torch", wx - 30, wy - 58, wall=False)
	m.light(wx - 30, wy - 80, 120, 0.7, "#ffb070")
	for (dx, dy) in [(-60, 40), (40, 55), (100, -20)]:
		m.spawn("frostknight", wx + dx - 14, wy + dy - 38)
	m.item("chest", wx + 30, wy - 40)
	# ---- the crystal grotto (south-east)
	gx, gy = 1150, 905
	for (dx, dy) in [(-90, -60), (70, -85), (130, 20), (-130, 50), (30, 95)]:
		m.obj("crystals", gx + dx, gy + dy, r=30)
	for i in range(9):
		a = rng.uniform(0, 6.28)
		rr = rng.uniform(60, 150)
		x, y = gx + math.cos(a) * rr, gy + math.sin(a) * rr * 0.7
		if m.free(x, y, 10, margin=30):
			m.obj("smallcrystal", x, y, wall=False, r=10)
	for (dx, dy) in [(-90, -60), (70, -85), (130, 20)]:
		m.light(gx + dx, gy + dy - 40, 90, 0.55, "#9fdcff")
	for (dx, dy) in [(-40, -20), (40, 10), (0, 50)]:
		m.spawn("crystalSpider", gx + dx - 13, gy + dy - 22)
	for (dx, dy) in [(-70, 40), (60, -40)]:
		m.spawn("iceling", gx + dx - 11, gy + dy - 20)
	# ---- the woods: pines everywhere outside the clearings, dead trees, rocks, boulders, stumps
	m.scatter(["pine"], (40, 60, W - 40, 330), 34, 40)
	m.scatter(["pine"], (40, 330, 260, H - 30), 12, 40)
	m.scatter(["pine"], (430, 980, 1000, H - 10), 9, 40)
	m.scatter(["pine"], (1250, 60, W - 30, 330), 4, 40)
	m.scatter(["pine"], (1250, 790, W - 30, H - 30), 4, 40)
	m.scatter(["pine", "pine", "deadtree"], (260, 300, W - 260, H - 60), 18, 38)
	m.scatter(["boulders"], (60, 80, W - 60, H - 40), 7, 42)
	m.scatter(["rock"], (40, 60, W - 40, H - 20), 26, 16, wall=False)
	m.scatter(["stump"], (40, 60, W - 40, H - 20), 9, 14, wall=False)
	m.scatter(["deadtree"], (40, 60, W - 40, H - 20), 7, 30, wall=False)
	# ---- foes: three wolf packs, rime wraiths in the north woods, icelings on the lake
	for (px, py) in [(470, 205), (860, 775), (720, 960)]:
		for k in range(3):
			m.spawn("frostwolf", px + rng.uniform(-45, 45) - 15, py + rng.uniform(-30, 30) - 22)
	for (px, py) in [(640, 170), (250, 330)]:
		m.spawn("rimewraith", px - 14, py - 38)
	for (px, py) in [(640, 610), (770, 660), (705, 560)]:
		m.spawn("iceling", px - 11, py - 20)
	# ---- things lying about: potions, a frost scroll, a greater potion by the clearing; the expedition's pages
	m.item("potion", 140, 300)
	m.item("potion", 1310, 1010)
	m.item("mana_potion", 590, 250)
	m.item("frost_scroll", 1320, 200)
	m.item("greater_potion", 1040, 610)
	m.item("page1", 380, 135)
	m.item("page2", 925, 160)
	m.item("page3", 1230, 965)
	# ---- the gate back to the sanctum; the hero arrives here
	m.exits.append({"x": 0, "y": 480, "w": 20, "h": 120, "to": "sanctum", "spawnX": 1135, "spawnY": 486, "dir": "left"})
	m.start = {"x": 40, "y": 506}
	m.write()
	paint_frostvale(m, paths, lake)

def paint_frostvale(m, paths, lake):
	rng = np.random.default_rng(1907)
	W, H = m.w * GS, m.h * GS
	n1 = noise(W, H, 420, rng, 3)
	n2 = noise(W, H, 90, rng, 2)
	snow_a = np.array([228, 236, 245], np.float32)
	snow_b = np.array([196, 212, 230], np.float32)
	base = lerp(snow_a, snow_b, np.clip(n1 * 1.4 - 0.25, 0, 1))
	base = base * (0.96 + 0.06 * n2[..., None])
	img = to_img(base)
	d = ImageDraw.Draw(img, "RGBA")
	pr = random.Random(77)
	# soft blue shadows of drifts
	for _ in range(160):
		x, y = pr.uniform(0, W), pr.uniform(0, H)
		rx, ry = pr.uniform(40, 140), pr.uniform(14, 40)
		d.ellipse([x - rx, y - ry, x + rx, y + ry], fill=(150, 175, 210, 26))
	# grass tufts poking through, little twigs, sparkles
	for _ in range(1500):
		x, y = pr.uniform(0, W), pr.uniform(0, H)
		col = (90, 120, 110, 150) if pr.random() < 0.6 else (120, 110, 95, 140)
		for k in range(pr.randint(2, 4)):
			a = pr.uniform(-2.4, -0.7)
			l = pr.uniform(6, 14)
			d.line([x + k * 3, y, x + k * 3 + math.cos(a) * l, y + math.sin(a) * l], fill=col, width=2)
	for _ in range(4000):
		x, y = pr.uniform(0, W), pr.uniform(0, H)
		d.ellipse([x - 1.6, y - 1.6, x + 1.6, y + 1.6], fill=(255, 255, 255, 210))
	for _ in range(500):
		x, y = pr.uniform(0, W), pr.uniform(0, H)
		a = pr.uniform(0, 3.14)
		l = pr.uniform(10, 24)
		d.line([x, y, x + math.cos(a) * l, y + math.sin(a) * l], fill=(110, 95, 85, 120), width=2)
	# the frozen lake: pale blue ice with a darker rim, cracks and glints
	cx, cy, rx, ry = [v * GS for v in lake]
	lm = Image.new("L", (W, H), 0)
	ImageDraw.Draw(lm).ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255)
	lm = lm.filter(ImageFilter.GaussianBlur(10))
	ice = Image.new("RGB", (W, H), (172, 214, 236))
	idr = ImageDraw.Draw(ice, "RGBA")
	for _ in range(60):
		x, y = pr.uniform(cx - rx, cx + rx), pr.uniform(cy - ry, cy + ry)
		rr = pr.uniform(30, 120)
		idr.ellipse([x - rr, y - rr * 0.5, x + rr, y + rr * 0.5], fill=(205, 235, 250, 60))
	for _ in range(46):
		x, y = pr.uniform(cx - rx * 0.8, cx + rx * 0.8), pr.uniform(cy - ry * 0.8, cy + ry * 0.8)
		pts = [(x, y)]
		a = pr.uniform(0, 6.28)
		for k in range(pr.randint(3, 6)):
			a += pr.uniform(-0.8, 0.8)
			x += math.cos(a) * pr.uniform(18, 40)
			y += math.sin(a) * pr.uniform(18, 40)
			pts.append((x, y))
		idr.line(pts, fill=(250, 255, 255, 170), width=3)
		idr.line([(p[0] + 2, p[1] + 2) for p in pts], fill=(110, 160, 200, 120), width=2)
	img.paste(ice, (0, 0), lm)
	rim = lm.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.GaussianBlur(4)).point(lambda v: min(255, v * 6))
	img.paste(Image.new("RGB", (W, H), (120, 160, 195)), (0, 0), rim.point(lambda v: v * 0.55))
	# trodden paths: blue-grey snow with a soft rim and footprints
	pm = poly_mask((W, H), paths, 44, 6)
	img.paste(Image.new("RGB", (W, H), (176, 192, 212)), (0, 0), pm.point(lambda v: int(v * 0.85)))
	inner = poly_mask((W, H), paths, 26, 6)
	img.paste(Image.new("RGB", (W, H), (190, 204, 222)), (0, 0), inner.point(lambda v: int(v * 0.7)))
	d = ImageDraw.Draw(img, "RGBA")
	for p in paths:
		for i in range(0, len(p) - 1):
			x, y = p[i][0] * GS, p[i][1] * GS
			for s in (-1, 1):
				d.ellipse([x + s * 10 - 5, y - 7, x + s * 10 + 5, y + 7], fill=(150, 168, 195, 90))
	# a faint vignette at the edges
	v = noise(W, H, 600, rng, 1)
	yy, xx = np.mgrid[0:H, 0:W]
	edge = np.minimum(np.minimum(xx, W - xx), np.minimum(yy, H - yy)).astype(np.float32)
	k = np.clip(1.0 - edge / 220.0, 0, 1) * 0.18
	arr = np.asarray(img, np.float32) * (1.0 - k[..., None]) + np.array([90, 110, 140], np.float32) * k[..., None]
	save_jpg(to_img(arr), m.key)

# ================================================================ the Wyrm's Hollow
HOLLOW = [
	"############..############",
	"#########........#########",
	"########..........########",
	"########..........########",
	"#######....####....#######",
	"######....######....######",
	"####......######......####",
	"###.......######.......###",
	"##........######........##",
	"##........######........##",
	"##.......########.......##",
	"###......########......###",
	"####.....########.....####",
	"#####...##########...#####",
	"####.....########.....####",
	"###....................###",
	"##......................##",
	"##......................##",
	"##......................##",
	"##......................##",
	"###....................###",
	"######..............######",
]
C = 50

def wyrmhollow():
	assert all(len(r) == 26 for r in HOLLOW) and len(HOLLOW) == 22
	m = Map("wyrmhollow", "The Wyrm's Hollow", 1300, 1100, 4211)
	rng = m.rng
	rock = [[ch == "#" for ch in row] for row in HOLLOW]
	# walls: merge rock cells row by row into horizontal runs, then stack equal runs downwards
	runs = {}
	for y, row in enumerate(rock):
		x = 0
		while x < 26:
			if row[x]:
				x0 = x
				while x < 26 and row[x]:
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
			m.walls.append({"x": x0 * C + 6, "y": start * C + 6, "w": (x1 - x0) * C - 12, "h": (prev - start + 1) * C - 12, "color": "#1a2430"})
			if y is not None:
				start = prev = y
	# the floor cells next to rock get spires, rocks and crystals for depth (not in the lair's middle, not at the door)
	def floor(cx, cy):
		return 0 <= cx < 26 and 0 <= cy < 22 and not rock[cy][cx]
	for cy in range(22):
		for cx in range(26):
			if not floor(cx, cy):
				continue
			n = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if not floor(cx + dx, cy + dy))
			if n == 0 or cy <= 1:
				continue
			x, y = cx * C + C / 2 + rng.uniform(-8, 8), cy * C + C / 2 + rng.uniform(4, 16)
			if 15 <= cy and 6 <= cx <= 19:
				continue
			r = rng.random()
			if r < 0.30 and m.free(x, y, 22, margin=10):
				m.obj(rng.choice(["icespire", "crystals"]), x, y, r=26)
			elif r < 0.55 and m.free(x, y, 10, margin=10):
				m.obj(rng.choice(["rock", "rock", "smallcrystal", "bones"]), x, y, wall=False, r=10)
	# the entry hall: pillars, braziers, bones, two skeletons and a frost knight
	for (x, y) in [(505, 140), (795, 140)]:
		m.obj("pillar", x, y, sprite="pillar_108", r=30)
	for (x, y) in [(560, 70), (740, 70)]:
		m.obj("icebrazier", x, y, wall=False, r=14)
		m.light(x, y - 22, 120, 0.75, "#9fdcff")
	m.spawn("skeleton", 560, 170)
	m.spawn("skeleton", 720, 175)
	m.spawn("frostknight", 640, 210)
	# the west chamber: a crystal grotto with spiders, wyrmlings, a wraith and a chest
	for (x, y) in [(170, 380), (390, 420), (150, 590), (420, 610)]:
		m.obj("crystals", x, y, r=30)
		m.light(x, y - 40, 110, 0.6, "#8fd8ff")
	for (x, y) in [(250, 470), (330, 520), (210, 540)]:
		m.spawn("crystalSpider", x, y)
	m.spawn("wyrmling", 300, 400)
	m.spawn("wyrmling", 360, 580)
	m.spawn("rimewraith", 240, 620)
	m.item("chest", 290, 345)
	# the east chamber: an ice hall (slippery), frost knights, icelings, a wyrmling
	m.hazards.append({"x": 880, "y": 380, "w": 270, "h": 230, "type": "ice"})
	for (x, y) in [(860, 360), (1170, 360), (880, 630), (1150, 630)]:
		m.obj("icebrazier", x, y, wall=False, r=14)
		m.light(x, y - 22, 110, 0.7, "#9fdcff")
	m.spawn("frostknight", 960, 440)
	m.spawn("frostknight", 1080, 520)
	m.spawn("iceling", 1000, 560)
	m.spawn("iceling", 920, 520)
	m.spawn("wyrmling", 1040, 400)
	m.item("potion", 1180, 450)
	m.item("mana_potion", 860, 500)
	# the way down: bats in the narrows, greater potions before the lair
	m.spawn("bat", 300, 670)
	m.spawn("bat", 330, 700)
	m.spawn("bat", 970, 670)
	m.spawn("bat", 1000, 700)
	m.item("greater_potion", 240, 715)
	m.item("greater_potion", 1060, 715)
	# the lair: bones and a ring of ice braziers; the Ancient Wyrm sleeps in the middle
	for (x, y) in [(260, 820), (1040, 820), (260, 1010), (1040, 1010)]:
		m.obj("icebrazier", x, y, wall=False, r=14)
		m.light(x, y - 22, 140, 0.8, "#9fdcff")
	for i in range(14):
		x, y = rng.uniform(170, 1130), rng.uniform(790, 1060)
		if abs(x - 650) > 120 or abs(y - 900) > 80:
			m.obj("bones", x, y, wall=False, r=0)
	for (x, y) in [(150, 860), (1150, 860), (180, 1040), (1120, 1040)]:
		m.obj("crystals", x, y, r=30)
		m.light(x, y - 40, 120, 0.6, "#8fd8ff")
	m.spawn("ancientwyrm", 650 - 35, 905 - 80)
	m.light(650, 880, 260, 0.35, "#6fb8e0")
	# the stair back up into the sanctum
	m.exits.append({"x": 610, "y": 0, "w": 80, "h": 16, "to": "sanctum", "spawnX": 647, "spawnY": 40, "dir": "up"})
	m.start = {"x": 637, "y": 40}
	m.write()
	paint_hollow(m, rock)

def paint_hollow(m, rock):
	rng = np.random.default_rng(4211)
	W, H = m.w * GS, m.h * GS
	# the rock mask, rounded: cells blurred and thresholded into organic shapes
	cell = Image.new("L", (26, 22), 0)
	cell.putdata([255 if rock[y][x] else 0 for y in range(22) for x in range(26)])
	mask = cell.resize((W, H), Image.NEAREST).filter(ImageFilter.GaussianBlur(26))
	mk = np.asarray(mask, np.float32) / 255.0
	wob = noise(W, H, 70, rng, 2)
	mk = np.clip((mk + (wob - 0.5) * 0.35 - 0.5) * 6.0 + 0.5, 0, 1)
	n1 = noise(W, H, 300, rng, 3)
	n2 = noise(W, H, 40, rng, 2)
	floor_a = np.array([54, 66, 82], np.float32)
	floor_b = np.array([38, 46, 60], np.float32)
	floor = lerp(floor_a, floor_b, np.clip(n1 * 1.3 - 0.15, 0, 1)) * (0.92 + 0.12 * n2[..., None])
	rock_a = np.array([22, 27, 36], np.float32)
	rock_b = np.array([32, 40, 52], np.float32)
	rockc = lerp(rock_a, rock_b, n2) * (0.9 + 0.2 * n1[..., None])
	img = to_img(floor * (1 - mk[..., None]) + rockc * mk[..., None])
	d = ImageDraw.Draw(img, "RGBA")
	pr = random.Random(99)
	# floor: flagstone cracks, pebbles, frost
	for _ in range(900):
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
		d.line(pts, fill=(18, 22, 30, 150), width=2)
	for _ in range(2500):
		x, y = pr.uniform(0, W), pr.uniform(0, H)
		if mk[int(y), int(x)] > 0.2:
			continue
		r = pr.uniform(1.5, 4)
		d.ellipse([x - r, y - r, x + r, y + r], fill=(90, 105, 125, 110))
	for _ in range(220):
		x, y = pr.uniform(0, W), pr.uniform(0, H)
		if mk[int(y), int(x)] > 0.2:
			continue
		rx, ry = pr.uniform(20, 70), pr.uniform(8, 24)
		d.ellipse([x - rx, y - ry, x + rx, y + ry], fill=(150, 200, 235, 22))
	# glowing veins of crystal in the floor
	for _ in range(70):
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
		d.line(pts, fill=(80, 190, 240, 70), width=9)
		d.line(pts, fill=(150, 230, 255, 200), width=3)
	# the rock: strata lines and a cold rim where it meets the floor
	for _ in range(700):
		x, y = pr.uniform(0, W), pr.uniform(0, H)
		if mk[int(y), int(x)] < 0.8:
			continue
		l = pr.uniform(20, 60)
		d.line([x, y, x + l, y + pr.uniform(-6, 6)], fill=(46, 56, 72, 120), width=3)
	edge = Image.fromarray((mk * 255).astype(np.uint8)).filter(ImageFilter.FIND_EDGES).filter(ImageFilter.GaussianBlur(3))
	img.paste(Image.new("RGB", (W, H), (120, 170, 210)), (0, 0), edge.point(lambda v: min(255, int(v * 2.2))))
	shade = Image.fromarray((mk * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(18))
	sh = np.asarray(shade, np.float32) / 255.0
	arr = np.asarray(img, np.float32)
	arr = arr * (1.0 - 0.35 * np.clip(sh - mk, 0, 1)[..., None])   # the floor darkens near the walls
	# the lair: an old rune circle around the sleeper
	img = to_img(arr)
	d = ImageDraw.Draw(img, "RGBA")
	cx, cy = 650 * GS, 900 * GS
	for rr, col, wd in [(330, (110, 190, 230, 70), 8), (300, (150, 220, 250, 90), 3), (210, (110, 190, 230, 60), 4)]:
		d.ellipse([cx - rr, cy - rr * 0.55, cx + rr, cy + rr * 0.55], outline=col, width=wd)
	for i in range(12):
		a = i / 12.0 * 6.283
		x, y = cx + math.cos(a) * 315, cy + math.sin(a) * 315 * 0.55
		d.regular_polygon((x, y, 12), 3 + i % 3, rotation=i * 17, outline=(170, 230, 255, 140), width=3)
	save_jpg(img, m.key, q=86)

# ================================================================ the sanctum's two new ways (east to the vale, north down to the hollow)
def patch_sanctum():
	p = os.path.join(ROOT, "data", "Maps", "sanctum.json")
	md = json.load(open(p))
	ex = [e for e in md["data"]["exits"] if e["to"] not in ("frostvale", "wyrmhollow")]
	ex.append({"x": 1180, "y": 460, "w": 20, "h": 120, "to": "frostvale", "spawnX": 30, "spawnY": 506, "dir": "right"})
	ex.append({"x": 620, "y": 0, "w": 80, "h": 16, "to": "wyrmhollow", "spawnX": 637, "spawnY": 50, "dir": "up"})
	md["data"]["exits"] = ex
	json.dump(md, open(p, "w"), indent=1, ensure_ascii=False)
	print("sanctum: exits", [e["to"] for e in ex])

if __name__ == "__main__":
	which = sys.argv[1:] or ["frostvale", "wyrmhollow", "sanctum"]
	if "sanctum" in which:
		patch_sanctum()
	if "frostvale" in which:
		frostvale()
	if "wyrmhollow" in which:
		wyrmhollow()
