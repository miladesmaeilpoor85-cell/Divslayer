#!/usr/bin/env python3
"""Chapter 3 art (v0.23, "Damavand"), made from the game's own sprites so it keeps their style (thick outline, soft
shading), and one new creature drawn in the same style:

  Enemies/zahhak.png        Zahhak, the serpent-shouldered king: the crypt's horned knight, larger, in black-violet plate with
                            gold and a venom-green blade (his two serpents and his crown are drawn by the game, so they move)
  Enemies/kondrow.png       Kondrow, his steward: the bandit chief re-dressed in the king's violet and gold
  Enemies/serpentguard.png  the serpent guard: the bandits in black-green scale with a gold band
  Enemies/serpentarcher.png the serpent archer: the same for the bandit archers
  Enemies/serpent.png       a serpent of Zahhak's brood (new: drawn here, four frames of its body's wave)
  Npcs/qaren.png            Qaren, Kaveh's son: the exile smith in a red cloak and steel

and adds their entries to data/art_manifest.json.

    python3 tools/ch3_art.py
"""
import json, math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ch2_art import load, save, hsv_map, warm, ART, ROOT

def scaled(src, cw, ch, frames, rows, k):
	ncw, nch = int(cw * k), int(ch * k)
	out = Image.new("RGBA", (ncw * frames, nch * rows), (0, 0, 0, 0))
	for r in range(rows):
		for f in range(frames):
			cell = src.crop((f * cw, r * ch, (f + 1) * cw, (r + 1) * ch)).resize((ncw, nch), Image.LANCZOS)
			out.alpha_composite(cell, (f * ncw, r * nch))
	return out, ncw, nch

def zahhak():
	im, cw, ch = scaled(load("Enemies/boss.png"), 240, 252, 4, 1, 1.3)
	def fn(h, s, v):
		red = warm(h, s) > 0.25
		redd = (np.minimum(np.abs(h - 0.98), 1 - np.abs(h - 0.98)) < 0.06) & (s > 0.3)    # the crimson plate
		plate = red | redd
		gold = (np.abs(h - 0.12) < 0.05) & (s > 0.45) & (v > 0.55)
		violet = (np.abs(h - 0.74) < 0.08) & (s > 0.2)                                       # the blade's glow
		nh = np.where(plate & ~gold, 0.76, np.where(violet, 0.33, h))
		ns = np.where(plate & ~gold, np.clip(s * 0.55, 0, 1), np.where(violet, np.clip(s * 1.1, 0, 1), s))
		nv = np.where(plate & ~gold, v * 0.62, np.where(violet, np.minimum(1.0, v * 1.1), v))
		return nh, ns, nv
	im = hsv_map(im, fn)
	# a faint venom-green glow round the outline
	al = im.split()[3].filter(ImageFilter.GaussianBlur(7))
	glow = Image.new("RGBA", im.size, (120, 220, 120, 0))
	glow.putalpha(al.point(lambda x: int(x * 0.28)))
	base = Image.new("RGBA", im.size, (0, 0, 0, 0))
	base.alpha_composite(glow)
	base.alpha_composite(im)
	save(base, "Enemies/zahhak.png")
	return cw, ch

def kondrow():
	im, cw, ch = scaled(load("Enemies/captain.png"), 144, 186, 4, 2, 1.22)
	def fn(h, s, v):
		w = warm(h, s)
		cloth = (w > 0.35) & (s > 0.45) & (v > 0.35)          # the red hood and cape
		nh = np.where(cloth, 0.78, h)
		ns = np.where(cloth, s * 0.75, s)
		nv = np.where(cloth, v * 0.82, v)
		return nh, ns, nv
	save(hsv_map(im, fn), "Enemies/kondrow.png")
	return cw, ch

def serpent_clothes(src_rel, out_rel):
	def fn(h, s, v):
		w = warm(h, s)
		leather = (w > 0.3) & (s > 0.2) & (v < 0.75) & (v > 0.12)
		band = (w > 0.3) & (s > 0.5) & (v >= 0.45) & (np.minimum(np.abs(h - 0.0), 1 - np.abs(h - 0.0)) < 0.04)
		skin = (w > 0.3) & (v >= 0.75)
		nh = np.where(band, 0.12, np.where(leather & ~skin, 0.38, h))
		ns = np.where(band, 0.7, np.where(leather & ~skin, s * 0.7, s))
		nv = np.where(band, np.minimum(1.0, v * 1.2), np.where(leather & ~skin, v * 0.62, v))
		return nh, ns, nv
	save(hsv_map(load(src_rel), fn), out_rel)

def serpent():
	"""a serpent rearing to strike, side view facing right, 4 frames of the body's wave; drawn at 3x"""
	CW, CH = 150, 108
	out = Image.new("RGBA", (CW * 4, CH), (0, 0, 0, 0))
	OUT = (26, 22, 18, 255)
	TOP = np.array([58, 110, 52], np.float32)
	TOP2 = np.array([36, 74, 38], np.float32)
	BELLY = np.array([222, 206, 120], np.float32)
	for f in range(4):
		ph = f / 4.0 * 2 * math.pi
		cell = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
		# the body: from the tail (left, on the ground) along a wave to the raised neck (right)
		pts = []
		for i in range(40):
			t = i / 39.0
			x = 12 + t * 84
			y = 88 - 7 * math.sin(t * 9.0 - ph) * (1.0 - t * 0.7) - (t ** 2.4) * 44
			pts.append((x, y))
		d = ImageDraw.Draw(cell)
		rad = [3.5 + 10.5 * min(1.0, i / 14.0) * (1.0 - 0.3 * (i / 39.0)) for i in range(40)]
		for (x, y), r in zip(pts, rad):
			d.ellipse([x - r - 3, y - r - 3, x + r + 3, y + r + 3], fill=OUT)
		for i, ((x, y), r) in enumerate(zip(pts, rad)):
			k = (i % 6) / 6.0
			col = TOP * (1 - 0.35 * k) + TOP2 * 0.35 * k
			d.ellipse([x - r, y - r, x + r, y + r], fill=tuple(int(c) for c in col) + (255,))
		for (x, y), r in zip(pts[4:], rad[4:]):
			d.ellipse([x - r * 0.55, y + r * 0.05, x + r * 0.55, y + r * 0.75], fill=tuple(int(c) for c in BELLY) + (255,))
		# diamond marks on the back
		for i in range(6, 36, 5):
			x, y = pts[i]
			r = rad[i] * 0.5
			d.polygon([(x, y - r * 1.4), (x + r, y - r * 0.4), (x, y + r * 0.2), (x - r, y - r * 0.4)], fill=(150, 170, 60, 255))
		# the head: a broad wedge with an eye, the jaw a little open, a forked tongue
		hx, hy = pts[-1][0] + 14, pts[-1][1] - 6 + 2 * math.sin(ph)
		hs = 1.25
		P = lambda a, b: (hx + a * hs, hy + b * hs)
		head = [P(-16, -9), P(4, -13), P(22, -6), P(25, 1), P(8, 6), P(-14, 9)]
		d.polygon([(x + (3 if x > hx else -3), y + (3 if y > hy else -3)) for x, y in head], fill=OUT)
		d.polygon(head, fill=tuple(int(c) for c in TOP) + (255,))
		d.polygon([P(-12, 3), P(8, 3), P(22, 0), P(8, 6), P(-12, 8)], fill=tuple(int(c) for c in BELLY) + (255,))
		e0, e1 = P(3, -9), P(11, -2)
		d.ellipse([e0[0], e0[1], e1[0], e1[1]], fill=(250, 220, 60, 255), outline=OUT, width=2)
		p0, p1 = P(6, -8), P(8.5, -3)
		d.ellipse([p0[0], p0[1], p1[0], p1[1]], fill=OUT)
		tl = 8 + 4 * math.sin(ph * 2)
		t0 = P(24, 1)
		d.line([t0, (t0[0] + tl, t0[1] + 1)], fill=(200, 40, 60, 255), width=2)
		d.line([(t0[0] + tl, t0[1] + 1), (t0[0] + tl + 4, t0[1] - 2)], fill=(200, 40, 60, 255), width=2)
		d.line([(t0[0] + tl, t0[1] + 1), (t0[0] + tl + 4, t0[1] + 4)], fill=(200, 40, 60, 255), width=2)
		# a soft highlight along the back
		hl = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
		hd = ImageDraw.Draw(hl)
		for (x, y), r in zip(pts[6:], rad[6:]):
			hd.ellipse([x - r * 0.45, y - r * 0.85, x + r * 0.2, y - r * 0.35], fill=(170, 220, 140, 120))
		cell.alpha_composite(hl.filter(ImageFilter.GaussianBlur(1.2)))
		out.alpha_composite(cell, (f * CW, 0))
	save(out, "Enemies/serpent.png")
	return CW, CH

def qaren():
	def fn(h, s, v):
		dark = (s < 0.35) & (v < 0.45) & (v > 0.12)             # the dark clothes -> a red cloak
		nh = np.where(dark, 0.99, h)
		ns = np.where(dark, 0.62, s)
		nv = np.where(dark, np.minimum(1.0, v * 1.5 + 0.08), v)
		return nh, ns, nv
	save(hsv_map(load("Npcs/brann.png"), fn), "Npcs/qaren.png")

def main():
	zc = zahhak()
	kc = kondrow()
	serpent_clothes("Enemies/bandit.png", "Enemies/serpentguard.png")
	serpent_clothes("Enemies/banditArcher.png", "Enemies/serpentarcher.png")
	sc = serpent()
	qaren()
	man_path = os.path.join(ROOT, "data", "art_manifest.json")
	man = json.load(open(man_path))
	en = man["enemies"]
	b = en["boss"]
	en["zahhak"] = dict(b, cellW=zc[0], cellH=zc[1], logicalW=round(b["logicalW"] * 1.3), logicalH=round(b["logicalH"] * 1.3), gameSize={"w": 60, "h": 72})
	c = en["captain"]
	en["kondrow"] = dict(c, cellW=kc[0], cellH=kc[1], logicalW=round(c["logicalW"] * 1.22), logicalH=round(c["logicalH"] * 1.22), gameSize={"w": 34, "h": 46})
	en["serpentguard"] = dict(en["bandit"])
	en["serpentarcher"] = dict(en["banditArcher"])
	hd = dict(en["cinderhound"])
	en["serpent"] = dict(hd, cellW=sc[0], cellH=sc[1], frames=4, variants=1, logicalW=50, logicalH=36, gameSize={"w": 30, "h": 20}, timedMs=None, hover=None)
	man["npcs"]["qaren"] = dict(man["npcs"]["brann"])
	json.dump(man, open(man_path, "w"), indent=1)
	print("manifest: zahhak, kondrow, serpentguard, serpentarcher, serpent, qaren")

if __name__ == "__main__":
	main()
