#!/usr/bin/env python3
"""(v0.35) Painted map objects: an AI painting of several props (trees, rocks, a house …) cut into pieces and fitted into
the map objects' pictures (assets/art/MapObjects), each at the size and on the base line of the old picture, so every
map keeps its layout and its walls. A piece that is wider or taller than the old canvas grows the canvas, and
data/map_object_sprites.json is updated so the base stays where it was.

  python3 tools/props_art.py split <sheet.png> <name> <n>   # -> art_src/props/pieces/<name>_<i>.png (+ a numbered contact)
  python3 tools/props_art.py apply <spec.json>              # spec: {"<file>": {"piece": "<name>_<i>", "scale": 1.0,
                                                            #        "flip": false}, …}
  python3 tools/props_art.py wall <piece> <file> [--post <piece>]   # a palisade run: the section repeated along a
                                                            # long horizontal picture, or posts stacked down a tall one
  python3 tools/props_art.py region <spec.json>             # a whole region (art_src/props/<region>.json): new
                                                            # pictures for that region only, its maps' objects pointed
                                                            # at them; other regions keep theirs until their turn
The old pictures are kept in art_src/old_props (copied the first time a file is replaced).
"""
import json, os, sys, shutil
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(os.path.dirname(ROOT), "art_src", "props")
OLD = os.path.join(os.path.dirname(ROOT), "art_src", "old_props")
OBJ = os.path.join(ROOT, "assets", "art", "MapObjects")
SPRITES = os.path.join(ROOT, "data", "map_object_sprites.json")
sys.path.insert(0, os.path.join(ROOT, "tools"))
from sprite_sheet import load_rgba, premul_resize  # noqa: E402


def pieces_of(im, n):
    """the n biggest shapes, top row first, left to right; loose bits (a leaf, a spark) join the nearest"""
    from scipy import ndimage
    a = np.array(im.getchannel("A"))
    mask = a > 8
    # shapes that nearly touch stay apart; bits of one prop that are a few pixels apart join up
    lab, cnt = ndimage.label(ndimage.binary_dilation(mask, iterations=3))
    sizes = ndimage.sum(mask, lab, range(1, cnt + 1))
    order = list(np.argsort(sizes)[::-1])
    if cnt < n:
        raise SystemExit("found %d shapes, want %d" % (cnt, n))
    seeds = [int(i) + 1 for i in order[:n]]
    coms = {s: ndimage.center_of_mass(mask, lab, s) for s in seeds}
    owner = np.zeros_like(lab)
    for i in range(1, cnt + 1):
        c = ndimage.center_of_mass(mask, lab, i)
        owner[lab == i] = min(seeds, key=lambda s: (coms[s][0] - c[0]) ** 2 + (coms[s][1] - c[1]) ** 2)
    # rows: sort by the top of each shape, a new row when a top is below the previous shape's middle
    boxes = {}
    for s in seeds:
        ys, xs = np.where((owner == s) & mask)
        boxes[s] = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    by_y = sorted(seeds, key=lambda s: (boxes[s][1] + boxes[s][3]) / 2)
    rows, cur = [], [by_y[0]]
    for s in by_y[1:]:
        prev_mid = np.mean([(boxes[t][1] + boxes[t][3]) / 2 for t in cur])
        prev_h = np.mean([boxes[t][3] - boxes[t][1] for t in cur])
        if (boxes[s][1] + boxes[s][3]) / 2 - prev_mid > prev_h * 0.5:
            rows.append(cur)
            cur = [s]
        else:
            cur.append(s)
    rows.append(cur)
    ordered = [s for r in rows for s in sorted(r, key=lambda s: boxes[s][0])]
    rgba = np.array(im)
    out = []
    for s in ordered:
        one = rgba.copy()
        one[..., 3] = np.where((owner == s), one[..., 3], 0)
        p = Image.fromarray(one)
        out.append(p.crop(p.getchannel("A").point(lambda v: 255 if v > 30 else 0).getbbox()))
    return out


def cmd_split(sheet, name, n):
    im = load_rgba(sheet)
    ps = pieces_of(im, n)
    d = os.path.join(SRC, "pieces")
    os.makedirs(d, exist_ok=True)
    for i, p in enumerate(ps):
        p.save(os.path.join(d, "%s_%d.png" % (name, i)))
    # a contact sheet, numbered, to check the order
    from PIL import ImageDraw
    th = 220
    thumbs = [p.resize((max(1, int(p.width * th / p.height)), th)) for p in ps]
    W = sum(t.width for t in thumbs) + 20 * (len(thumbs) + 1)
    c = Image.new("RGBA", (W, th + 40), (60, 80, 60, 255))
    x = 20
    dr = ImageDraw.Draw(c)
    for i, t in enumerate(thumbs):
        c.alpha_composite(t, (x, 30))
        dr.text((x, 6), "%s_%d  %dx%d" % (name, i, ps[i].width, ps[i].height), fill=(255, 255, 255, 255))
        x += t.width + 20
    c.save(os.path.join(d, name + "_contact.png"))
    print(name, [p.size for p in ps])


def _old(file):
    os.makedirs(OLD, exist_ok=True)
    o = os.path.join(OLD, file + ".png")
    if not os.path.exists(o):
        shutil.copy(os.path.join(OBJ, file + ".png"), o)
    return Image.open(o).convert("RGBA")


def _save(img, path):
    img.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.FLOYDSTEINBERG).save(path, optimize=True)


def _update_sprites(file, w, h, pivot_y):
    sp = json.load(open(SPRITES))
    for k, m in sp.items():
        if m.get("file", k) == file:
            m["w"], m["h"] = w, h
            m["logicalW"], m["logicalH"] = round(w / 3.0, 4), round(h / 3.0, 4)
            m["pivot"] = [0.5, pivot_y]
    json.dump(sp, open(SPRITES, "w"), indent=1, ensure_ascii=False)
    open(SPRITES, "a").write("\n")


def _meta(file):
    sp = json.load(open(SPRITES))
    for k, m in sp.items():
        if m.get("file", k) == file:
            return m
    raise SystemExit("no sprite uses " + file)


def fit(file, piece, scale=1.0, flip=False, height=None, base_up=0):
    """the piece drawn where the old picture's figure stood: same bottom, same centre, the old height x scale"""
    old = _old(file)
    m = _meta(file)
    W, H = old.size
    bb = old.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox() or (0, 0, W, H)
    target_h = (height if height else (bb[3] - bb[1])) * scale
    p = piece.transpose(Image.FLIP_LEFT_RIGHT) if flip else piece
    k = target_h / p.height
    pw, ph = max(1, round(p.width * k)), max(1, round(p.height * k))
    p = premul_resize(p, (pw, ph))
    cx = (bb[0] + bb[2]) / 2.0
    bottom = bb[3] - base_up
    x0, y0 = round(cx - pw / 2.0), round(bottom - ph)
    # grow the canvas when the piece spills out (left/right evenly, so the centre stays; on top, so the base stays)
    pad_x = max(0, -x0, x0 + pw - W)
    pad_top = max(0, -y0)
    pad_bot = max(0, y0 + ph - H)
    NW, NH = W + 2 * pad_x, H + pad_top + pad_bot
    canvas = Image.new("RGBA", (NW, NH), (0, 0, 0, 0))
    canvas.alpha_composite(p, (x0 + pad_x, y0 + pad_top))
    _save(canvas, os.path.join(OBJ, file + ".png"))
    # the base (pivot) sits m.pivot[1] * H above the old bottom edge: keep it at the same place in the world
    base_from_top = H * (1.0 - float(m["pivot"][1])) + pad_top
    _update_sprites(file, NW, NH, 1.0 - base_from_top / NH)
    return (NW, NH)


def cmd_apply(spec_path):
    spec = json.load(open(spec_path))
    for file, s in spec.items():
        if file.startswith("_"):
            continue
        piece = Image.open(os.path.join(SRC, "pieces", s["piece"] + ".png")).convert("RGBA")
        size = fit(file, piece, float(s.get("scale", 1.0)), bool(s.get("flip", False)), s.get("height"), int(s.get("base_up", 0)))
        print(file, "<-", s["piece"], size)


def cmd_wall(piece_name, file, post_name=None):
    """a palisade: long horizontal pictures repeat the section side by side; tall narrow ones (a wall running away from
    the viewer) stack the post from the top down, each a little lower and in front of the last"""
    old = _old(file)
    W, H = old.size
    bb = old.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
    sec = Image.open(os.path.join(SRC, "pieces", piece_name + ".png")).convert("RGBA")
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if W >= H:
        th = bb[3] - bb[1]
        k = th / sec.height
        s = premul_resize(sec, (max(1, round(sec.width * k)), th))
        step = int(s.width * 0.96)
        x = bb[0]
        while x < bb[2]:
            canvas.alpha_composite(s, (x, bb[1]))
            x += step
        canvas = canvas.crop((0, 0, W, H))
        a = np.array(canvas)
        a[:, bb[2]:, 3] = 0
        canvas = Image.fromarray(a)
    else:
        post = Image.open(os.path.join(SRC, "pieces", (post_name or piece_name) + ".png")).convert("RGBA")
        pw = bb[2] - bb[0]
        k = pw / post.width
        s = premul_resize(post, (pw, max(1, round(post.height * k))))
        step = max(8, int(s.width * 0.55))
        y = bb[1]
        while y + s.height <= bb[3] + 2:
            canvas.alpha_composite(s, (bb[0], y))
            y += step
        if y < bb[3]:
            canvas.alpha_composite(s, (bb[0], bb[3] - s.height))
    _save(canvas, os.path.join(OBJ, file + ".png"))
    print(file, "wall", (W, H))


# ---------------------------------------------------------------- a whole region (v0.35)
FIRE = lambda a: (a[..., 0] > 200) & (a[..., 1] > 120) & (a[..., 2] < 140) & (a[..., 3] > 200)


def _frac_point(piece, how):
    """a point on the piece as fractions of its size: [fx, fy], "glow" (the middle of its flame or lantern light) or
    "top" (the middle of its topmost few rows: a chimney, a dome's lantern)"""
    if isinstance(how, list):
        return how[0], how[1]
    a = np.array(piece)
    if how == "glow":
        ys, xs = np.where(FIRE(a.astype(np.int16)))
        if len(ys) == 0:
            raise SystemExit("no flame colour found")
        return float(xs.mean()) / piece.width, float(ys.mean()) / piece.height
    if how == "top":
        al = a[..., 3] > 60
        rows = np.where(al.any(axis=1))[0]
        top = rows[0]
        band = al[top:top + max(4, piece.height // 60)]
        xs = np.where(band.any(axis=0))[0]
        return float(xs.mean()) / piece.width, float(top + piece.height // 80) / piece.height
    raise SystemExit("unknown point " + str(how))


def render(piece, like_meta, like_img, scale=1.0, flip=False):
    """the piece where the old picture's figure stood (same base, same centre, its height x scale); returns the canvas,
    the new pivot, and a function turning a point on the piece (fractions) into map units from the base"""
    W, H = like_img.size
    bb = like_img.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox() or (0, 0, W, H)
    p = piece.transpose(Image.FLIP_LEFT_RIGHT) if flip else piece
    k = (bb[3] - bb[1]) * scale / p.height
    pw, ph = max(1, round(p.width * k)), max(1, round(p.height * k))
    p = premul_resize(p, (pw, ph))
    cx = (bb[0] + bb[2]) / 2.0
    x0, y0 = round(cx - pw / 2.0), round(bb[3] - ph)
    pad_x = max(0, -x0, x0 + pw - W)
    pad_top = max(0, -y0)
    pad_bot = max(0, y0 + ph - H)
    NW, NH = W + 2 * pad_x, H + pad_top + pad_bot
    canvas = Image.new("RGBA", (NW, NH), (0, 0, 0, 0))
    canvas.alpha_composite(p, (x0 + pad_x, y0 + pad_top))
    base_y = H * (1.0 - float(like_meta["pivot"][1])) + pad_top
    base_x = W / 2.0 + pad_x

    def to_units(fx, fy):
        px = x0 + pad_x + (1 - fx if flip else fx) * pw
        py = y0 + pad_top + fy * ph
        return [round((px - base_x) / 3.0, 1), round((py - base_y) / 3.0, 1)]
    return canvas, 1.0 - base_y / NH, to_units


def wall_canvas(like_img, section, post):
    """a palisade in the old picture's frame: a long one repeats the section; a tall one (a wall running toward the
    viewer) shows the tips of its posts in staggered rows, seen from above, and the full face of its last posts"""
    W, H = like_img.size
    bb = like_img.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    face_h = 198                      # the height of the front walls of the camp, in picture pixels
    s = premul_resize(section, (max(1, round(section.width * face_h / section.height)), face_h))
    if W >= H:
        x = bb[0]
        while x < bb[2]:
            canvas.alpha_composite(s, (x, bb[3] - face_h))
            x += int(s.width * 0.96)
        a = np.array(canvas)
        a[:, bb[2]:, 3] = 0
        return Image.fromarray(a)
    bw = bb[2] - bb[0]
    # a double row of stakes, seen from above: each a sharpened tip and a bit of its shaft, a row a stake apart
    cols = 2
    pw = bw // cols
    ps = premul_resize(post, (pw, max(1, round(post.height * pw / post.width))))
    tip = ps.crop((0, 0, pw, int(pw * 2.1)))
    step = int(pw * 0.92)
    y = bb[1]
    stop = bb[3] - face_h
    while y < stop:
        for c in range(cols):
            canvas.alpha_composite(tip, (bb[0] + c * pw, y))
        y += step
    face = s.crop((0, 0, min(s.width, bw), face_h))
    canvas.alpha_composite(face, (bb[0] + (bw - face.width) // 2, bb[3] - face_h))
    return canvas


def cmd_region(spec_path):
    spec = json.load(open(spec_path))
    sp = json.load(open(SPRITES))
    piece = lambda n: Image.open(os.path.join(SRC, "pieces", n + ".png")).convert("RGBA")
    def old_img(name):
        # the old picture, from the project, or from the archive once the region no longer uses it
        f = sp[name].get("file", name) + ".png"
        path = os.path.join(OBJ, f) if os.path.exists(os.path.join(OBJ, f)) else os.path.join(OLD, f)
        return Image.open(path).convert("RGBA")
    for new, d in spec["new"].items():
        like = d["like"]
        if "wall" in d:
            canvas = wall_canvas(old_img(like), piece(d["wall"]), piece(d.get("post", d["wall"])))
            pivot = float(sp[like]["pivot"][1])
            fx = {}
        else:
            pc = piece(d["piece"])
            canvas, pivot, to_units = render(pc, sp[like], old_img(like), float(d.get("scale", 1.0)), bool(d.get("flip", False)))
            fx = {}
            if "fx" in d:
                fx["fx_at"] = to_units(*_frac_point(pc, d["fx"]))
            if "fx_s" in d:
                fx["fx_s"] = d["fx_s"]
            if "smoke" in d:
                fx["smoke_at"] = None if d["smoke"] is None else to_units(*_frac_point(pc, d["smoke"]))
        _save(canvas, os.path.join(OBJ, new + ".png"))
        m = {"w": canvas.width, "h": canvas.height, "logicalW": round(canvas.width / 3.0, 4),
             "logicalH": round(canvas.height / 3.0, 4), "pivot": [0.5, pivot]}
        m.update(fx)
        sp[new] = m
        print(new.ljust(16), "<-", d.get("piece", d.get("wall")), canvas.size, fx if fx else "")
    json.dump(sp, open(SPRITES, "w"), indent=1, ensure_ascii=False)
    open(SPRITES, "a").write("\n")
    # point the region's objects at the new pictures (a list: chosen by the object's place, so it never changes)
    for mp in spec["maps"]:
        path = os.path.join(ROOT, "data", "Maps", mp + ".json")
        md = json.load(open(path))
        n = 0
        for o in md.get("objects", []):
            old = o.get("sprite")
            rule = spec["swap"].get(mp + ":" + str(old), spec["swap"].get(str(old)))
            if rule is None:
                continue
            choices = rule if isinstance(rule, list) else [rule]
            o["sprite"] = choices[(int(o["x"]) * 31 + int(o["y"]) * 17) % len(choices)]
            n += 1
        json.dump(md, open(path, "w"), indent=1, ensure_ascii=False)
        open(path, "a").write("\n")
        left = sorted({o.get("sprite") for o in md.get("objects", []) if o.get("sprite") and not str(o["sprite"]).startswith(spec.get("prefix", "g_"))})
        print(mp, n, "objects repainted; still old:", left)


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[0] == "split":
        cmd_split(a[1], a[2], int(a[3]))
    elif a[0] == "apply":
        cmd_apply(a[1])
    elif a[0] == "region":
        cmd_region(a[1])
    elif a[0] == "wall":
        cmd_wall(a[1], a[2], a[a.index("--post") + 1] if "--post" in a else None)
