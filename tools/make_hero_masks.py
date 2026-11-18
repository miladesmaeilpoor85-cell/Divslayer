#!/usr/bin/env python3
"""Hero looks (v0.20): for every hero sheet, a mask of the cloth that a look recolours, and the cloth's mean brightness.

A look (data/Tables/MON_SKINS.json: three colours, mid / dark / light) is painted by scripts/fx/hero_look.gdshader over the
pixels this mask marks, keeping the drawing's own shading: a pixel as bright as the cloth's mean gets the mid colour, darker
ones run toward the dark colour, brighter ones toward the light one.

    R = the class colour (the warrior's red, the mage's blue, the rogue's green, the paladin's gold): recoloured fully
    G = the paladin's silver plate: tinted at half strength (from behind he shows little gold)

Rules are per class (hue window in degrees, min saturation, brightness range, and the share of each cell's height above
which nothing is touched, so a paladin's blond hair keeps its colour). Writes assets/art/Heroes/<sheet>_mask.png
(8-bit RGB, black where nothing changes) and data/hero_masks.json {sheet: {"key": mean brightness of the R pixels}}.

    python3 tools/make_hero_masks.py [--preview out.png]
"""
import json, os, sys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HEROES = os.path.join(ROOT, "assets", "art", "Heroes")
CELL_H = 156
# channel, hue centre, half width (full weight), extra falloff, min sat, max sat, min value, max value, top share left alone
RULES = {
	"warrior": [("R", 3, 11, 4, 0.42, 1.0, 0.28, 1.0, 0.36)],     # (v0.33) 0.36: the painted face (a red scar) and hair stay
	"mage":    [("R", 222, 13, 5, 0.33, 1.0, 0.22, 1.0, 0.0)],
	"rogue":   [("R", 132, 26, 6, 0.12, 1.0, 0.10, 1.0, 0.0)],
	"paladin": [("R", 44, 9, 4, 0.40, 1.0, 0.45, 1.0, 0.50),
	            ("G", 220, 13, 5, 0.03, 0.22, 0.55, 0.90, 0.47)],
}
# (v0.33) the painted sheets (cell 160 wide): their own cloth colours, measured on the paintings. The sage's robe is a
# dull navy, the ayyar's cloak an olive green (hue ~55, between the leather's ~25 and true green), the oathbearer's
# tunic a mustard gold and his steel a neutral grey (hue means nothing at that saturation: any hue, low saturation).
# The top share keeps the big painted heads (hair, a red scar, a red headband) as they are.
PAINTED_RULES = {
	"warrior": [("R", 3, 11, 4, 0.42, 1.0, 0.28, 1.0, 0.36)],
	"mage":    [("R", 230, 16, 6, 0.16, 1.0, 0.15, 1.0, 0.36)],
	"rogue":   [("R", 56, 9, 4, 0.30, 1.0, 0.18, 0.75, 0.0)],
	# the ayyar's green deepens with his gear (olive ~55, moss ~72, forest ~95) while his leather darkens toward black,
	# whose hue at that darkness drifts up to ~70: each sheet gets its own window
	"rogue_mid":     [("R", 74, 10, 4, 0.33, 1.0, 0.10, 0.80, 0.0)],
	"rogue_endgame": [("R", 92, 14, 4, 0.18, 1.0, 0.06, 0.80, 0.0)],
	"paladin": [("R", 38, 6, 3, 0.60, 1.0, 0.40, 1.0, 0.42),
	            ("G", 0, 180, 1, 0.0, 0.14, 0.50, 0.92, 0.42)],
}

def painted(sheet):
	m = json.load(open(os.path.join(ROOT, "data", "art_manifest.json")))["heroes"].get(sheet, {})
	return int(m.get("cellW", 120)) == 160

def hsv(a):
	rgb = a[..., :3].astype(np.float32) / 255.0
	mx = rgb.max(-1)
	mn = rgb.min(-1)
	d = mx - mn
	s = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
	r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
	h = np.zeros_like(mx)
	dd = np.maximum(d, 1e-6)
	h = np.where(mx == r, (g - b) / dd % 6, h)
	h = np.where(mx == g, (b - r) / dd + 2, h)
	h = np.where(mx == b, (r - g) / dd + 4, h)
	h = np.where(d == 0, 0, h) * 60.0
	return h, s, mx

def mask_for(path, cls, rules=None):
	rules = rules or RULES
	im = np.array(Image.open(path).convert("RGBA"))
	h, s, v = hsv(im)
	a = im[..., 3] / 255.0
	ys = (np.arange(im.shape[0]) % CELL_H) / CELL_H
	out = np.zeros(im.shape[:2] + (3,), np.float32)
	for ch, hc, hw, fall, smin, smax, vmin, vmax, top in rules[cls]:
		dist = np.abs((h - hc + 180.0) % 360.0 - 180.0)
		w = np.clip(1.0 - (dist - hw) / fall, 0.0, 1.0)
		w *= np.clip((s - smin) / 0.06 + 1.0, 0, 1) * (s <= smax + 0.04)
		w *= np.clip((v - vmin) / 0.06 + 1.0, 0, 1) * (v <= vmax + 0.03)
		w *= (ys[:, None] >= top)
		w *= a > 0.05
		out[..., "RGB".index(ch)] = np.maximum(out[..., "RGB".index(ch)], w)
	lum = (0.299 * im[..., 0] + 0.587 * im[..., 1] + 0.114 * im[..., 2]) / 255.0
	r = out[..., 0]
	key = float((lum * r).sum() / max(1.0, r.sum()))
	return (out * 255).round().astype(np.uint8), key

def main():
	info = {}
	previews = []
	for fn in sorted(os.listdir(HEROES)):
		if not fn.endswith(".png") or fn.endswith("_mask.png"):
			continue
		sheet = fn[:-4]
		cls = sheet.split("_")[0]
		rules = PAINTED_RULES if painted(sheet) else RULES
		if sheet in rules:
			rules = dict(rules, **{cls: rules[sheet]})      # (v0.33) a sheet's own window over its class's
		m, key = mask_for(os.path.join(HEROES, fn), cls, rules)
		Image.fromarray(m, "RGB").save(os.path.join(HEROES, sheet + "_mask.png"), optimize=True)
		info[sheet] = {"key": round(key, 4)}
		previews.append((sheet, m))
		print("%-18s key %.3f  R %6d px  G %6d px" % (sheet, key, (m[..., 0] > 127).sum(), (m[..., 1] > 127).sum()))
	json.dump(info, open(os.path.join(ROOT, "data", "hero_masks.json"), "w"), indent=1, sort_keys=True)
	if "--preview" in sys.argv:
		out = sys.argv[sys.argv.index("--preview") + 1]
		rows = []
		for sheet, m in previews:
			src = np.array(Image.open(os.path.join(HEROES, sheet + ".png")).convert("RGBA"))[:CELL_H, :240]
			bg = np.full(src.shape[:2] + (3,), 70, np.float32)
			al = src[..., 3:4] / 255.0
			base = bg * (1 - al) + src[..., :3] * al
			mm = m[:CELL_H, :240].astype(np.float32) / 255.0
			tint = base.copy()
			tint = tint * (1 - mm[..., 0:1]) + np.array([255, 0, 255]) * mm[..., 0:1]
			tint = tint * (1 - mm[..., 1:2] * 0.7) + np.array([0, 255, 0]) * mm[..., 1:2] * 0.7
			rows.append(np.concatenate([base, tint], 1))
		Image.fromarray(np.concatenate(rows, 0).astype(np.uint8)).save(out)

if __name__ == "__main__":
	main()
