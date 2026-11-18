#!/usr/bin/env python3
"""Chapter 2 art (v0.19), made from the game's own sprites so it keeps their style (thick outline, soft shading):

  MapObjects/icespire_*.png   the Ashen Peaks' lava spires turned to frozen stone (brown -> slate blue, lava -> ice light)
  Enemies/frostwolf.png       the cinderhound in a white winter coat with ice-blue eyes and marks
  Enemies/rimewraith.png      the wraith, pale and frost-blue
  Enemies/wyrmling.png        a young wyrm: the Ancient Wyrm, smaller, paler and violet-blue
  Enemies/glaciertitan.png    the glacial golem, bigger and deep blue with white glowing cracks
  Npcs/hesk.png               Hesk the trapper: the hooded alchemist re-dressed in furs and leather
  Items/shard_*.png           the three shards of the Wyrm Key (the frost relic in three lights)
  Items/page.png              a page of the lost expedition's journal

and adds their entries to data/art_manifest.json and data/map_object_sprites.json.

    python3 tools/ch2_art.py
"""
import colorsys, json, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "assets", "art")

def load(rel):
	return Image.open(os.path.join(ART, rel)).convert("RGBA")

def save(im, rel):
	p = os.path.join(ART, rel)
	im.save(p, optimize=True)
	print("  %s %dx%d %d KB" % (rel, im.width, im.height, os.path.getsize(p) // 1024))

def hsv_map(im, fn):
	"""apply fn(h, s, v) -> (h, s, v) to every opaque pixel (h in 0..1)"""
	a = np.asarray(im, np.float32) / 255.0
	rgb, al = a[..., :3], a[..., 3:]
	mx = rgb.max(-1)
	mn = rgb.min(-1)
	d = mx - mn + 1e-6
	r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
	h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6.0
	s = np.where(mx > 0, d / (mx + 1e-6), 0)
	v = mx
	h, s, v = fn(h, s, v)
	h = h % 1.0
	i = np.floor(h * 6).astype(int) % 6
	f = h * 6 - np.floor(h * 6)
	p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
	out = np.zeros_like(rgb)
	for k, (x, y, z) in enumerate([(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)]):
		mk = i == k
		out[..., 0][mk], out[..., 1][mk], out[..., 2][mk] = x[mk], y[mk], z[mk]
	res = np.concatenate([np.clip(out, 0, 1), al], -1)
	return Image.fromarray((res * 255).astype(np.uint8), "RGBA")

def warm(h, s):
	"""how much a pixel belongs to the warm (red-orange-brown) family"""
	dh = np.minimum(np.abs(h - 0.06), 1 - np.abs(h - 0.06))
	return np.clip(1.0 - dh / 0.11, 0, 1) * np.clip(s * 3.0, 0, 1)

# ---------------------------------------------------------------- map objects
def icespires(manifest):
	src = [k for k in manifest if k.rsplit("_", 1)[0] == "spire"]
	made = {}
	for k in sorted(src):
		f = manifest[k].get("file", k)
		if f in made:
			continue
		def fn(h, s, v):
			w = warm(h, s)
			glow = (s > 0.55) & (v > 0.65)          # the lava in the cracks
			nh = np.where(w > 0.3, 0.57, h)
			ns = np.where(glow & (w > 0.3), 0.45, np.where(w > 0.3, s * 0.32, s))
			nv = np.where(glow & (w > 0.3), np.minimum(1.0, v * 1.12 + 0.1), np.where(w > 0.3, v * 1.05 + 0.04, v))
			return nh, ns, nv
		im = hsv_map(load("MapObjects/%s.png" % f), fn)
		new = "icespire_" + f.rsplit("_", 1)[1]
		save(im, "MapObjects/%s.png" % new)
		made[f] = new
	out = {}
	for k in sorted(src):
		e = dict(manifest[k])
		f = e.pop("file", k)
		nk = "icespire_" + k.rsplit("_", 1)[1]
		if made[f] != nk:
			e["file"] = made[f]
		out[nk] = e
	return out

# ---------------------------------------------------------------- foes
def frostwolf():
	def fn(h, s, v):
		w = warm(h, s)
		glow = (s > 0.6) & (v > 0.6) & (w > 0.4)    # the embers in its coat and eyes -> ice blue
		nh = np.where(glow, 0.55, np.where(w > 0.2, 0.6, h))
		ns = np.where(glow, 0.6, np.where(w > 0.2, s * 0.18, s))
		nv = np.where(glow, np.minimum(1.0, v * 1.15), np.where(w > 0.2, np.minimum(1.0, 0.25 + v * 1.6), v))
		return nh, ns, nv
	save(hsv_map(load("Enemies/cinderhound.png"), fn), "Enemies/frostwolf.png")

def rimewraith():
	def fn(h, s, v):
		purple = (np.abs(h - 0.75) < 0.12) & (s > 0.12)
		nh = np.where(purple, 0.54, h)
		ns = np.where(purple, s * 0.55, s)
		nv = np.where(purple, np.minimum(1.0, v * 1.35 + 0.12), v)
		return nh, ns, nv
	save(hsv_map(load("Enemies/wraith.png"), fn), "Enemies/rimewraith.png")

def wyrmling():
	src = load("Enemies/ancientwyrm.png")
	cw, ch = 372, 324
	# the wingless row only, every frame shrunk to 0.55 in a new, smaller cell
	k = 0.55
	ncw, nch = int(cw * k), int(ch * k)
	out = Image.new("RGBA", (ncw * 4, nch), (0, 0, 0, 0))
	for f in range(4):
		cell = src.crop((f * cw, 0, (f + 1) * cw, ch)).resize((ncw, nch), Image.LANCZOS)
		out.alpha_composite(cell, (f * ncw, 0))
	def fn(h, s, v):
		teal = (np.abs(h - 0.53) < 0.09) & (s > 0.15)
		nh = np.where(teal, 0.70, h)
		ns = np.where(teal, s * 0.8, s)
		nv = np.where(teal, np.minimum(1.0, v * 1.18), v)
		return nh, ns, nv
	save(hsv_map(out, fn), "Enemies/wyrmling.png")
	return {"cellW": ncw, "cellH": nch}

def glaciertitan():
	src = load("Enemies/icegolem.png")
	cw, ch = 168, 168
	k = 1.75
	ncw, nch = int(cw * k), int(ch * k)
	out = Image.new("RGBA", (ncw * 4, nch), (0, 0, 0, 0))
	for f in range(4):
		cell = src.crop((f * cw, 0, (f + 1) * cw, ch)).resize((ncw, nch), Image.LANCZOS)
		out.alpha_composite(cell, (f * ncw, 0))
	def fn(h, s, v):
		blue = (np.abs(h - 0.6) < 0.1) & (s > 0.1)
		light = v > 0.85
		nh = np.where(blue, 0.62, h)
		ns = np.where(blue & ~light, np.minimum(1.0, s * 1.35 + 0.1), s * 0.6)
		nv = np.where(blue & ~light, v * 0.72, np.minimum(1.0, v * 1.05))
		return nh, ns, nv
	im = hsv_map(out, fn)
	# a little rime glow around the outline
	al = im.split()[3].filter(ImageFilter.GaussianBlur(6))
	glow = Image.new("RGBA", im.size, (190, 235, 255, 0))
	glow.putalpha(al.point(lambda x: int(x * 0.35)))
	base = Image.new("RGBA", im.size, (0, 0, 0, 0))
	base.alpha_composite(glow)
	base.alpha_composite(im)
	save(base, "Enemies/glaciertitan.png")
	return {"cellW": ncw, "cellH": nch}

# ---------------------------------------------------------------- the trapper
def hesk():
	def fn(h, s, v):
		green = (np.abs(h - 0.36) < 0.12) & (s > 0.18)       # the hood and robe -> pale fur and brown leather
		hood = green & (v > 0.45)
		nh = np.where(green, np.where(hood, 0.1, 0.07), h)
		ns = np.where(green, np.where(hood, 0.12, 0.45), s)
		nv = np.where(green, np.where(hood, np.minimum(1.0, v * 1.35 + 0.15), v * 0.8), v)
		# the potions on the belt -> buckles and a horn
		bright = (s > 0.5) & (v > 0.6) & ~green
		nh = np.where(bright, 0.09, nh)
		ns = np.where(bright, 0.35, ns)
		return nh, ns, nv
	save(hsv_map(load("Npcs/alchemist.png"), fn), "Npcs/hesk.png")

# ---------------------------------------------------------------- items
def shards():
	src = load("Items/relic_frost.png")
	for name, hue, sat in [("shard_judgement", 0.58, 0.35), ("shard_frost", 0.5, 0.7), ("shard_memory", 0.76, 0.55)]:
		def fn(h, s, v, hue=hue, sat=sat):
			cool = s > 0.08
			return np.where(cool, hue, h), np.where(cool, np.clip(s * 0.6 + sat * 0.5, 0, 1), s), v
		save(hsv_map(src, fn), "Items/%s.png" % name)

def page():
	W, H = 60, 72
	im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	d = ImageDraw.Draw(im)
	pts = [(8, 6), (50, 4), (54, 16), (52, 66), (12, 68), (6, 52), (9, 30)]
	d.polygon(pts, fill=(236, 222, 186, 255))
	d.line(pts + [pts[0]], fill=(54, 38, 26, 255), width=4, joint="curve")
	d.polygon([(50, 4), (54, 16), (44, 14)], fill=(200, 184, 146, 255))
	for i, y in enumerate(range(18, 60, 7)):
		x1 = 44 if i % 3 != 2 else 34
		d.line([(15, y), (x1, y)], fill=(120, 96, 70, 255), width=2)
	d.ellipse([34, 46, 48, 58], fill=(150, 200, 235, 255), outline=(54, 38, 26, 255), width=2)   # a frost stain
	save(im, "Items/page.png")

def main():
	mo_path = os.path.join(ROOT, "data", "map_object_sprites.json")
	mo = json.load(open(mo_path))
	for k, v in icespires(mo).items():
		mo[k] = v
	json.dump(mo, open(mo_path, "w"), separators=(",", ":"))
	frostwolf()
	rimewraith()
	wl = wyrmling()
	gt = glaciertitan()
	hesk()
	shards()
	page()
	man_path = os.path.join(ROOT, "data", "art_manifest.json")
	man = json.load(open(man_path))
	en = man["enemies"]
	en["frostwolf"] = dict(en["cinderhound"], gameSize={"w": 30, "h": 22})
	en["rimewraith"] = dict(en["wraith"])
	w0 = en["ancientwyrm"]
	en["wyrmling"] = dict(w0, cellW=wl["cellW"], cellH=wl["cellH"], variants=1, logicalW=round(w0["logicalW"] * 0.55),
		logicalH=round(w0["logicalH"] * 0.55), gameSize={"w": 38, "h": 44})
	g0 = en["icegolem"]
	en["glaciertitan"] = dict(g0, cellW=gt["cellW"], cellH=gt["cellH"], logicalW=round(g0["logicalW"] * 1.75),
		logicalH=round(g0["logicalH"] * 1.75), gameSize={"w": 64, "h": 70})
	man["npcs"]["hesk"] = dict(man["npcs"]["alchemist"])
	json.dump(man, open(man_path, "w"), indent=1)
	print("manifest: frostwolf, rimewraith, wyrmling, glaciertitan, hesk; map objects: icespire_*")

if __name__ == "__main__":
	main()
