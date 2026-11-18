#!/usr/bin/env python3
"""Lossless PNG optimisation for the art (v0.18): re-compress every PNG under the given folders with oxipng and keep the
result only when its decoded pixels are identical to the original (RGBA, every pixel). Nothing visible changes; the
project gets about 6 MB smaller (12.7 MB of PNG -> 6.7 MB). Godot re-imports the files (its own texture format is the same).

    pip install pyoxipng pillow numpy
    python3 tools/optimize_png.py assets/art
"""
import os, sys, io
import numpy as np
import oxipng
from PIL import Image

def rgba(b):
	im = Image.open(io.BytesIO(b))
	im.load()
	return np.asarray(im.convert("RGBA"))

def main(roots):
	before = after = 0
	kept = changed = 0
	for root in roots:
		for dp, _, fs in os.walk(root):
			for f in sorted(fs):
				if not f.lower().endswith(".png"):
					continue
				p = os.path.join(dp, f)
				b = open(p, "rb").read()
				o = oxipng.optimize_from_memory(b, level=4, strip=oxipng.StripChunks.safe())
				before += len(b)
				if len(o) < len(b) and np.array_equal(rgba(b), rgba(o)):
					open(p, "wb").write(o)
					after += len(o)
					changed += 1
				else:
					after += len(b)
					kept += 1
	print("PNG %.2f MB -> %.2f MB (%d smaller, %d kept as they were)" % (before / 1e6, after / 1e6, changed, kept))

if __name__ == "__main__":
	main(sys.argv[1:] or ["assets/art"])
