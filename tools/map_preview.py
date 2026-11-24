"""Draw a map from its data, seen from above, for designing maps (v0.19): the ground, every object sprite at its place,
walls (red), exits (green, with the map they lead to), hazards (orange), NPCs (yellow), enemy spawns (magenta, bosses
bigger), items (cyan), the player start (white) and the lights (faint circles).

    python3 tools/map_preview.py sanctum out.png [--scale 0.5] [--clean]   (--clean: the ground and the objects only)
"""
import json
import os
import sys

from PIL import Image, ImageDraw

from image_assets import open_image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCALE_SPR = 1.0 / 3.0

def ground_image_path(root: str, key: str, map_definition: dict) -> str:
	"""Resolve the same explicit groundFile override used by the runtime World loader."""
	ground_file = str(map_definition.get("groundFile") or (key + "_ground.jpg"))
	return os.path.join(root, "assets", "art", "Maps", ground_file)


def map_object_image_path(root: str, sprite_name: str, metadata: dict) -> str:
	"""Resolve the manifest-selected object filename and extension."""
	filename = str(metadata.get("file") or sprite_name)
	extension = str(metadata.get("extension") or "png").lower().lstrip(".")
	if os.path.basename(filename) != filename or extension not in {"png", "jpg", "jpeg", "webp", "svg"}:
		raise ValueError(f"unsafe or unsupported map-object image reference: {sprite_name}")
	return os.path.join(root, "assets", "art", "MapObjects", filename + "." + extension)


def main():
	key, out = sys.argv[1], sys.argv[2]
	sc = float(sys.argv[sys.argv.index("--scale") + 1]) if "--scale" in sys.argv else 0.5
	with open(os.path.join(ROOT, "data", "Maps", key + ".json"), encoding="utf-8") as map_file:
		md = json.load(map_file)
	d = md["data"]
	W, H = int(d["w"]), int(d["h"])
	gpath = ground_image_path(ROOT, key, md)
	if os.path.exists(gpath):
		g = open_image(gpath).resize((int(W * sc), int(H * sc)), Image.LANCZOS)
	else:
		g = Image.new("RGBA", (int(W * sc), int(H * sc)), (40, 40, 48, 255))
	with open(os.path.join(ROOT, "data", "map_object_sprites.json"), encoding="utf-8") as sprites_file:
		sprites = json.load(sprites_file)
	objs = sorted([o for o in md.get("objects", []) if "sprite" in o], key=lambda o: float(o.get("sort", o["y"])))
	for o in objs:
		m = sprites.get(o.get("sprite", ""))
		if not m:
			continue
		p = map_object_image_path(ROOT, o["sprite"], m)
		im = open_image(p)
		k = SCALE_SPR * sc
		im = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)
		x = o["x"] * sc - float(m["w"]) * 0.5 * k
		y = o["y"] * sc - float(m["h"]) * (1.0 - float(m["pivot"][1])) * k
		g.alpha_composite(im, (int(x), int(y)))
	if "--clean" in sys.argv:
		g.convert("RGB").save(out)
		print(f"{key} {W}x{H} -> {out} (clean)")
		return
	dr = ImageDraw.Draw(g, "RGBA")
	R = lambda r: [r["x"] * sc, r["y"] * sc, (r["x"] + r["w"]) * sc, (r["y"] + r["h"]) * sc]
	for l in md.get("lights", []) or []:
		r = float(l.get("r", 60)) * sc
		dr.ellipse([l["x"] * sc - r, l["y"] * sc - r, l["x"] * sc + r, l["y"] * sc + r], outline=(255, 240, 160, 60))
	for w in d.get("walls", []):
		dr.rectangle(R(w), outline=(255, 60, 60, 220), fill=(255, 60, 60, 40))
	for h in d.get("hazards", []) or []:
		dr.rectangle(R(h), outline=(255, 150, 40, 255), fill=(255, 150, 40, 60))
	for e in d.get("exits", []):
		dr.rectangle(R(e), outline=(60, 255, 90, 255), fill=(60, 255, 90, 80))
		dr.text((e["x"] * sc + 2, e["y"] * sc + 2), e["to"], fill=(200, 255, 200, 255))
	for n in d.get("npcs", []):
		dr.rectangle([n["x"] * sc, n["y"] * sc, (n["x"] + 26) * sc, (n["y"] + 34) * sc], outline=(255, 230, 60, 255), width=2)
		dr.text((n["x"] * sc, n["y"] * sc - 10), n.get("id", "?"), fill=(255, 240, 120, 255))
	for s in d.get("enemySpawns", []):
		big = s["type"] in ("boss", "boss2", "matriarch", "arbiter", "ignarok", "ancientwyrm", "toadking", "anvilward", "captain", "glaciertitan")
		r = 9 if big else 4
		dr.ellipse([s["x"] * sc - r, s["y"] * sc - r, s["x"] * sc + r, s["y"] * sc + r], outline=(255, 60, 255, 255), width=2)
		if big:
			dr.text((s["x"] * sc + 10, s["y"] * sc), s["type"], fill=(255, 150, 255, 255))
	for it in d.get("items", []) or []:
		dr.rectangle([it["x"] * sc, it["y"] * sc, (it["x"] + 12) * sc, (it["y"] + 12) * sc], outline=(60, 230, 255, 255), width=2)
	ps = d.get("playerStart")
	if ps:
		dr.ellipse([ps["x"] * sc - 5, ps["y"] * sc - 5, ps["x"] * sc + 5, ps["y"] * sc + 5], fill=(255, 255, 255, 255))
	for gr in md.get("grass", []) or []:
		dr.rectangle(R(gr), outline=(120, 255, 120, 160))
	for x in range(0, W, 100):
		dr.text((x * sc + 1, 1), str(x), fill=(255, 255, 255, 160))
	for y in range(0, H, 100):
		dr.text((1, y * sc + 1), str(y), fill=(255, 255, 255, 160))
	g.convert("RGB").save(out)
	print(f"{key} {W}x{H} -> {out}")

if __name__ == "__main__":
	main()
