#!/usr/bin/env python3
"""(v0.35) Painted terrain: the tools behind data/terrain.json and scripts/fx/terrain.gd.

  python3 tools/terrain.py noise                         # assets/art/Terrain/noise.png (tileable, three octaves)
  python3 tools/terrain.py texture <src.png> <name> [--size 1024] [--units 340]
        # an AI-painted texture -> tileable (seams blended away) -> assets/art/Terrain/<name>.webp, listed in terrain.json
  python3 tools/terrain.py splat <map>                   # the map's splat map from its old ground picture + its objects
  python3 tools/terrain.py bake <map>                    # a small picture of the new ground for the minimap / world map
  python3 tools/terrain.py placeholder                   # rough stand-in textures, to test before the paintings arrive

The splat (a pixel for SPLAT_STEP map units): red = path, green = paving, blue = a second ground (moss and leaves under
trees, a patch here and there). It is read from the old ground picture by colour (the old pictures are kept in
art_src/old_ground), so the paths stay exactly where the map's walls, exits and spawns expect them.
"""
import json, os, sys, math
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TDIR = os.path.join(ROOT, "assets", "art", "Terrain")
CFG = os.path.join(ROOT, "data", "terrain.json")
OLD = os.path.join(os.path.dirname(ROOT), "art_src", "old_ground")
SPLAT_STEP = 4.0


def load_cfg():
    if os.path.exists(CFG):
        return json.load(open(CFG))
    return {"textures": {}, "maps": {}}


def save_cfg(c):
    json.dump(c, open(CFG, "w"), indent=1, ensure_ascii=False)
    open(CFG, "a").write("\n")


def tile_noise(n, freq, rng):
    """periodic noise: random phases at low frequencies only, so it wraps at the edges by construction"""
    f = np.fft.fftfreq(n)
    fx, fy = np.meshgrid(f, f)
    r = np.sqrt(fx ** 2 + fy ** 2) * n
    spec = (rng.standard_normal((n, n)) + 1j * rng.standard_normal((n, n))) * np.exp(-(r / freq) ** 2)
    spec[0, 0] = 0
    a = np.real(np.fft.ifft2(spec))
    a = (a - a.min()) / (a.max() - a.min())
    return a


def cmd_noise():
    rng = np.random.default_rng(7)
    n = 256
    ch = [tile_noise(n, 4, rng), tile_noise(n, 9, rng), tile_noise(n, 22, rng)]
    img = np.stack(ch, -1)
    os.makedirs(TDIR, exist_ok=True)
    Image.fromarray((img * 255).astype(np.uint8)).save(os.path.join(TDIR, "noise.png"))
    print("noise.png", n)


def make_seamless(im, k=0.30):
    """one axis at a time: the picture rolled half a tile along x has its edges in the middle and the original's middle
    at its edges (which wrap onto each other); it is laid over the original near the left and right edges only, so the
    result wraps along x. Then the same along y on that result (rolling along y keeps the x wrap)."""
    a = np.asarray(im).astype(np.float32)
    for axis in (1, 0):
        n = a.shape[axis]
        rolled = np.roll(a, n // 2, axis)
        t = np.abs(np.arange(n) - (n - 1) / 2.0) / ((n - 1) / 2.0)       # 0 in the middle, 1 at the edges
        m = np.clip((t - (1 - k)) / k, 0, 1)
        m = m * m * (3 - 2 * m)
        m = m.reshape((1, n, 1) if axis == 1 else (n, 1, 1))
        a = a * (1 - m) + rolled * m
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def seam_error(im):
    a = np.asarray(im).astype(np.float32)
    inside = np.abs(np.diff(a, axis=1)).mean()
    edge = np.abs(a[:, 0] - a[:, -1]).mean()
    return edge / max(inside, 1e-3)


def cmd_texture(src, name, size=1024, units=340.0):
    im = Image.open(src).convert("RGB")
    s = min(im.size)
    im = im.crop(((im.width - s) // 2, (im.height - s) // 2, (im.width - s) // 2 + s, (im.height - s) // 2 + s))
    before = seam_error(im)
    if before > 1.6:
        im = make_seamless(im)
    im = im.resize((size, size), Image.LANCZOS)
    os.makedirs(TDIR, exist_ok=True)
    out = os.path.join(TDIR, name + ".webp")
    im.save(out, quality=88, method=6)
    c = load_cfg()
    c["textures"][name] = {"file": name + ".webp", "units": units}
    save_cfg(c)
    print(out, "seam %.2f -> %.2f" % (before, seam_error(im)), os.path.getsize(out) // 1024, "KB")


def _map(key):
    return json.load(open(os.path.join(ROOT, "data", "Maps", key + ".json")))


def _blur(a, r):
    return np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r))).astype(np.float32) / 255


def _hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    d = mx - mn + 1e-6
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6.0
    s = np.where(mx > 0, d / (mx + 1e-6), 0)
    return h, s, mx


def _solid(mask, least=40):
    """the mask without its specks (a brown leaf in the grass is not a path): shapes under `least` pixels go, small holes
    fill"""
    from scipy import ndimage
    m = ndimage.binary_opening(mask, iterations=1)
    lab, n = ndimage.label(m)
    if n:
        sizes = ndimage.sum(m, lab, range(1, n + 1))
        keep = np.zeros(n + 1, bool)
        keep[1:] = sizes >= least
        m = keep[lab]
    m = ndimage.binary_closing(m, iterations=2)
    return m.astype(np.float32)


# how each map's old picture is read: which colours were the path (r) and the paving (g)
RECIPES = {
    "village": {"r": "brown", "g": "grey", "b_trees": 0.55, "b_patch": 0.15},
    "forest": {"r": "brown", "b_trees": 0.9, "b_patch": 0.45},
    "camp": {"r": "brown", "b_trees": 0.8, "b_patch": 0.25, "smooth": 5.0, "soft": 2.2},
}


def cmd_splat(key):
    md = _map(key)
    d = md["data"]
    W, H = float(d["w"]), float(d["h"])
    rec = RECIPES[key]
    old = Image.open(os.path.join(OLD, key + "_ground.jpg")).convert("RGB")
    sw, sh = int(math.ceil(W / SPLAT_STEP)), int(math.ceil(H / SPLAT_STEP))
    # read the colours at a finer step, then smooth down
    fine = np.asarray(old.resize((sw * 2, sh * 2), Image.BOX)).astype(np.float32) / 255
    hh, ss, vv = _hsv(fine)
    brownish = (hh < 0.18) | (hh > 0.95)
    grey = brownish & (ss < 0.30)
    brown = brownish & (ss >= 0.30)
    out = np.zeros((sh * 2, sw * 2, 3), np.float32)
    if rec.get("r") == "brown":
        out[..., 0] = _solid(brown | (grey & (rec.get("g") != "grey")))
    if rec.get("g") == "grey":
        out[..., 1] = _solid(grey)
    # a second ground: moss and fallen leaves gathered under the trees, and a few large soft patches
    b = np.zeros((sh * 2, sw * 2), np.float32)
    k = 2.0 / SPLAT_STEP
    yy, xx = np.mgrid[0:sh * 2, 0:sw * 2]
    for o in md.get("objects", []):
        if o.get("kind") in ("tree", "pine", "willow") or str(o.get("sprite", "")).split("_")[0] in ("tree", "pine", "willow", "stump"):
            cx, cy = float(o["x"]) * k, float(o["y"]) * k
            r = 46.0 * k
            b = np.maximum(b, np.exp(-(((xx - cx) ** 2 + ((yy - cy) * 1.4) ** 2) / (2 * r * r))))
    rng = np.random.default_rng(abs(hash(key)) % 2 ** 31)
    patch = tile_noise(max(sw, sh) * 2, 5, rng)[:sh * 2, :sw * 2]
    b = np.maximum(b * rec.get("b_trees", 0.6), np.clip((patch - (1 - rec.get("b_patch", 0.2))) * 4, 0, 1))
    if rec.get("smooth"):
        # the trampled yard of a camp: its outline rounded (blur, then cut at the middle), no jagged grass islands
        out[..., 0] = (_blur(out[..., 0], rec["smooth"]) > 0.5).astype(np.float32)
    if rec.get("soft"):
        out[..., 0] = _blur(out[..., 0], rec["soft"])
    out[..., 2] = np.clip(b, 0, 1) * (1 - out[..., 0]) * (1 - out[..., 1])
    for c in range(3):
        out[..., c] = _blur(_blur(out[..., c], 1.2), 0.8)
    img = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).resize((sw, sh), Image.LANCZOS)
    os.makedirs(os.path.join(TDIR, "splat"), exist_ok=True)
    p = os.path.join(TDIR, "splat", key + ".png")
    img.save(p, optimize=True)
    print(p, img.size)


def _tex(c, name):
    t = c["textures"][name]
    return Image.open(os.path.join(TDIR, t["file"])).convert("RGB"), float(t.get("units", 340))


def cmd_bake(key, ppu=1.0):
    """the ground as the game draws it, at `ppu` pixels a map unit (no edge noise): for the minimap and the world map"""
    c = load_cfg()
    m = c["maps"][key]
    d = _map(key)["data"]
    W, H = int(d["w"]), int(d["h"])
    ow, oh = int(W * ppu), int(H * ppu)
    splat = np.asarray(Image.open(os.path.join(TDIR, "splat", key + ".png")).convert("RGB").resize((ow, oh), Image.BILINEAR)).astype(np.float32) / 255

    def layer(name):
        t, u = _tex(c, name)
        n = max(1, int(u * ppu))
        t = t.resize((n, n), Image.LANCZOS)
        reps = (int(math.ceil(oh / n)), int(math.ceil(ow / n)), 1)
        return np.tile(np.asarray(t).astype(np.float32), reps)[:oh, :ow]

    gain = lambda n: float(c["textures"][n].get("gain", 1.0))
    col = layer(m["base"]) * gain(m["base"])
    for ch, idx in (("b", 2), ("r", 0), ("g", 1)):
        if ch in m:
            w = np.clip((splat[..., idx] - 0.5) / 0.36 + 0.5, 0, 1)[..., None]
            col = col * (1 - w) + layer(m[ch]) * gain(m[ch]) * w
    # a map with terrain draws its ground itself: this picture only feeds the minimap and the world map, so 1 px a unit
    sat = float(m.get("sat", 1.0))
    lum = (col * np.array([0.299, 0.587, 0.114])).sum(-1, keepdims=True)
    col = lum + (col - lum) * sat
    img = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8))
    p = os.path.join(ROOT, "assets", "art", "Maps", key + "_ground.jpg")
    img.save(p, quality=80, optimize=True)
    print(p, img.size, os.path.getsize(p) // 1024, "KB")


def cmd_placeholder():
    """flat stand-ins until the paintings arrive (only to test the shader)"""
    rng = np.random.default_rng(3)
    n = 512
    specs = {"meadow": ((76, 122, 58), (104, 152, 72)), "dirtpath": ((128, 98, 64), (156, 124, 86)),
             "cobble": ((118, 112, 102), (160, 152, 138)), "forestfloor": ((52, 74, 40), (96, 78, 46))}
    c = load_cfg()
    for name, (a, b) in specs.items():
        t = tile_noise(n, 40, rng) * 0.6 + tile_noise(n, 120, rng) * 0.4
        img = np.array(a, np.float32) * (1 - t[..., None]) + np.array(b, np.float32) * t[..., None]
        if name == "cobble":
            pts = rng.random((60, 2)) * n
            yy, xx = np.mgrid[0:n, 0:n]
            dmin = np.full((n, n), 1e9)
            d2 = np.full((n, n), 1e9)
            for p in pts:
                for ox in (-n, 0, n):
                    for oy in (-n, 0, n):
                        dd = (xx - p[0] - ox) ** 2 + (yy - p[1] - oy) ** 2
                        d2 = np.where(dd < dmin, dmin, np.minimum(d2, dd))
                        dmin = np.minimum(dmin, dd)
            edge = np.clip((np.sqrt(d2) - np.sqrt(dmin)) / 6, 0, 1)
            img *= (0.55 + 0.45 * edge)[..., None]
        os.makedirs(TDIR, exist_ok=True)
        Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(os.path.join(TDIR, name + ".webp"), quality=85)
        c["textures"].setdefault(name, {"file": name + ".webp", "units": 340})
    save_cfg(c)
    print("placeholders written")


if __name__ == "__main__":
    a = sys.argv[1:]
    opt = lambda k, d, f=str: f(a[a.index(k) + 1]) if k in a else d
    if a[0] == "noise":
        cmd_noise()
    elif a[0] == "texture":
        cmd_texture(a[1], a[2], opt("--size", 1024, int), opt("--units", 340.0, float))
    elif a[0] == "splat":
        cmd_splat(a[1])
    elif a[0] == "bake":
        cmd_bake(a[1])
    elif a[0] == "placeholder":
        cmd_placeholder()
