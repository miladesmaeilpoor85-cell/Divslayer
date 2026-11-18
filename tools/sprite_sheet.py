"""(v0.30) Turn one AI-painted character image into a game sprite sheet, with the motion made here.

The AI cannot draw a consistent frame-by-frame animation, so it draws each character once and this script animates it:
a walk is a hop with a little squash and sway, the attack is a lean, all around the feet.

  villagers / heroes (rows down, up, side; columns walk0-3 + attack), from a turnaround (front, side facing right, back):
    python3 tools/sprite_sheet.py char <turnaround.png> <out_sheet.png> [--height 134] [--cell 120x156] [--foot 150]
  foes (one row of frames per variant, one view facing right):
    python3 tools/sprite_sheet.py foe <view.png> <out_sheet.png> --cell 240x252 --height 230 --frames 4 [--foot 246] [--calm]
  (--calm: a floating foe breathes slowly instead of striding)
  flyers drawn twice side by side (wings up, wings down), the poses become the frames, the body held still:
    python3 tools/sprite_sheet.py poses <two_poses.png> <out_sheet.png> --cell 150x130 --height 120 --frames 2 [--nudge dx,dy] [--align gold]
  (--align gold: line the poses up by their golden parts — beak, talons, cuffs — when the wings hide the body)

The figure keeps the old sprite's height in its cell (measure the old sheet), so nothing in play changes size.
"""
import sys
import math
import numpy as np
from PIL import Image, ImageFilter

SS = 2   # supersampling: frames are built at twice the cell size, then scaled down once


def load_rgba(path: str) -> Image.Image:
    source = Image.open(path)
    # RGB images cannot carry transparency. A checkerboard painted into the pixels is not an alpha channel.
    if "A" not in source.getbands() and "transparency" not in source.info:
        raise SystemExit("the image has no alpha channel; a checkerboard background is not transparency")
    im = source.convert("RGBA")
    a = np.array(im.getchannel("A")).astype(np.float32)
    if a.max() < 10:
        raise SystemExit("the image has no transparency: ask for a transparent background")
    # the chat hands images over with the inside at alpha ~250: make it solid, keep soft edges soft
    a = np.clip((a - 8.0) * 255.0 / 240.0, 0, 255)
    im.putalpha(Image.fromarray(a.astype(np.uint8)))
    return im


def split_views(im: Image.Image, n: int) -> list:
    """the n figures side by side, left to right, by the empty columns between them"""
    a = np.array(im.getchannel("A")) > 40
    cols = a.any(axis=0)
    runs, start = [], None
    for x, on in enumerate(cols):
        if on and start is None:
            start = x
        elif not on and start is not None:
            runs.append([start, x])
            start = None
    if start is not None:
        runs.append([start, len(cols)])
    # merge runs split by gaps narrower than 12 px (a staff, a stray lock of hair)
    merged = [runs[0]]
    for r in runs[1:]:
        if r[0] - merged[-1][1] < 12:
            merged[-1][1] = r[1]
        else:
            merged.append(r)
    merged = [r for r in merged if r[1] - r[0] > 30]
    if len(merged) != n:
        return split_by_blobs(im, n)
    out = []
    for x0, x1 in merged:
        sub = im.crop((x0, 0, x1, im.height))
        bb = sub.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
        out.append(sub.crop(bb))
    return out


def split_by_blobs(im: Image.Image, n: int) -> list:
    """figures that overlap in columns (a hammer over the next figure's shoulder): the n biggest connected shapes,
    left to right; small loose bits go to the nearest one"""
    from scipy import ndimage
    a = np.array(im.getchannel("A"))
    mask = a > 40
    lab, cnt = ndimage.label(mask)
    sizes = ndimage.sum(mask, lab, range(1, cnt + 1))
    order = list(np.argsort(sizes)[::-1])
    seeds = [int(i) + 1 for i in order[:n]]
    if len(seeds) < n or sizes[order[n - 1]] < 0.05 * sizes[order[0]]:
        raise SystemExit("could not find %d separate figures (%d shapes)" % (n, cnt))
    coms = {s: ndimage.center_of_mass(mask, lab, s)[1] for s in seeds}
    owner = np.zeros_like(lab)
    for i in range(1, cnt + 1):
        if sizes[i - 1] < 30:
            continue
        cx = ndimage.center_of_mass(mask, lab, i)[1]
        best = min(seeds, key=lambda s: abs(coms[s] - cx))
        owner[lab == i] = best
    out = []
    for s in sorted(seeds, key=lambda s: coms[s]):
        keep = owner == s
        rgba = np.array(im)
        rgba[..., 3] = np.where(keep, rgba[..., 3], 0)
        sub = Image.fromarray(rgba)
        out.append(sub.crop(sub.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()))
    return out


def body_center_x(view: Image.Image) -> float:
    """where the body stands: the alpha-weighted centre of the figure (a thin staff barely moves it)"""
    a = np.array(view.getchannel("A")).astype(np.float64)
    xs = np.arange(a.shape[1])
    return float((a.sum(axis=0) * xs).sum() / a.sum())


def premul_resize(im: Image.Image, size) -> Image.Image:
    return im.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")


def place(view: Image.Image, scale: float, cw: int, ch: int, foot: int, cx: float,
          dy=0.0, sx=1.0, sy=1.0, rot=0.0, dx=0.0) -> Image.Image:
    """one frame at SS x the cell: the view scaled to fit, its feet on the foot line, then moved, squashed and turned
    around the feet"""
    W, H = cw * SS, ch * SS
    s = scale * SS
    w, h = max(1, round(view.width * s * sx)), max(1, round(view.height * s * sy))
    v = premul_resize(view, (w, h))
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    fx = W / 2 - cx * s * sx + dx * SS          # the body's centre on the cell's centre
    fy = foot * SS - h + dy * SS                # the feet on the foot line
    canvas.alpha_composite(v, (round(fx), round(fy)))
    if rot:
        # turn around the feet (Pillow turns around a centre: shift, turn, shift back)
        pivot = (W / 2 + dx * SS, foot * SS + dy * SS)
        canvas = canvas.convert("RGBa").rotate(rot, resample=Image.BICUBIC, center=pivot).convert("RGBA")
    return canvas


def finish(frame: Image.Image, cw: int, ch: int) -> Image.Image:
    f = premul_resize(frame, (cw, ch))
    # a light sharpen keeps the outline crisp after the big step down
    rgb = f.convert("RGB").filter(ImageFilter.UnsharpMask(radius=1.0, percent=60, threshold=2))
    rgb.putalpha(f.getchannel("A"))
    return rgb


# the hop: [dy, sx, sy, rot] per walk frame (dy in cell px, up is negative; rot in degrees, + turns left)
WALK = [(0, 1.0, 1.0, 0.0), (-4, 0.98, 1.03, 2.5), (0, 1.03, 0.97, 0.0), (-4, 0.98, 1.03, -2.5)]
WALK_SIDE = [(0, 1.0, 1.0, -1.5), (-4, 0.98, 1.03, -3.0), (0, 1.03, 0.97, -1.0), (-4, 0.98, 1.03, -3.0)]


def char_sheet(src, out, height=134, cell=(120, 156), foot=150):
    cw, ch = cell
    im = load_rgba(src)
    # (v0.33) a hero's sheet has a fourth view, his side-on attack; a villager's has three
    try:
        front, side, back, strike = split_views(im, 4)
    except SystemExit:
        front, side, back = split_views(im, 3)
        strike = None
    scale = height / max(front.height, side.height, back.height)
    views = {"down": front, "up": back, "side": side}
    sheet = Image.new("RGBA", (cw * 5, ch * 3), (0, 0, 0, 0))
    for r, d in enumerate(["down", "up", "side"]):
        v = views[d]
        cx = body_center_x(v)
        if v.width * scale > cw - 4:      # too wide for the cell: shrink this view a little
            sc = (cw - 4) / v.width
        else:
            sc = scale
        frames = WALK_SIDE if d == "side" else WALK
        for c, (dy, sx, sy, rot) in enumerate(frames):
            f = place(v, sc, cw, ch, foot, cx, dy=dy, sx=sx, sy=sy, rot=rot)
            sheet.alpha_composite(finish(f, cw, ch), (c * cw, r * ch))
        # the attack: his own strike pose side-on (kept at the same scale: the body moves back a little and the blade
        # is shrunk only if it still leaves the cell), otherwise a lean into the blow
        if d == "side" and strike is not None:
            ssc = scale
            scx = body_center_x(strike)
            right = (strike.width - scx) * ssc
            left = scx * ssc
            dx = -min(14.0, max(0.0, right - (cw / 2 - 2)))
            if right + dx > cw / 2 - 2 or left - dx > cw / 2 - 2:
                ssc = min((cw / 2 - 2 - dx) / (strike.width - scx), (cw / 2 - 2 + dx) / scx)
            f = place(strike, ssc, cw, ch, foot, scx, dx=dx)
            print("strike: scale %.4f of %.4f, moved %.1f px" % (ssc, scale, dx))
        elif d == "side":
            f = place(v, sc, cw, ch, foot, cx, dx=5, rot=-9)
        elif d == "down":
            f = place(v, sc, cw, ch, foot, cx, dy=2, sx=1.05, sy=1.05)
        else:
            f = place(v, sc, cw, ch, foot, cx, dy=-3, sx=0.97, sy=0.97)
        sheet.alpha_composite(finish(f, cw, ch), (4 * cw, r * ch))
    save_small(sheet, out)
    print(out, sheet.size, "scale %.4f" % scale)


def foe_sheet(src, out, cell, height, frames=4, foot=None, variants=1, views=1, erode=0, calm=False):
    """views > 1: the image holds that many forms side by side (the Sorceress's disguise and her true shape); row r of
    the sheet is form r, all at one scale; rows past the last form are the last form enraged"""
    cw, ch = cell
    foot = foot if foot is not None else ch - 6
    im = load_rgba(src)
    if erode:
        # images handed over as WebP carry a coloured fringe: shave the edge at full size, where it costs nothing
        im.putalpha(im.getchannel("A").filter(ImageFilter.MinFilter(2 * erode + 1)))
    if views > 1:
        forms = split_views(im, views)
        scale = min(min(height / f.height, (cw - 6) / f.width) for f in forms)
        sheet = Image.new("RGBA", (cw * frames, ch * variants), (0, 0, 0, 0))
        for r in range(variants):
            f = forms[min(r, views - 1)]
            cx = body_center_x(f)
            for c in range(frames):
                lift = 0.5 - 0.5 * math.cos(2 * math.pi * c / frames)
                fr = finish(place(f, scale, cw, ch, foot, cx, dy=-3 * lift, sx=1.0 - 0.012 * lift, sy=1.0 + 0.025 * lift), cw, ch)
                sheet.alpha_composite(fr if r < views else enraged(fr, r - views + 1), (c * cw, r * ch))
        save_small(sheet, out)
        print(out, sheet.size, "scale %.4f" % scale, "forms", views)
        return
    bb = im.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
    v = im.crop(bb)
    scale = min(height / v.height, (cw - 6) / v.width)
    cx = body_center_x(v)
    sheet = Image.new("RGBA", (cw * frames, ch * variants), (0, 0, 0, 0))
    for c in range(frames):
        ph = 2 * math.pi * c / frames
        # a heavy step for a foe on the move: rise and sway with each stride, swell a little on the way up
        lift = 0.5 - 0.5 * math.cos(2 * ph) if frames >= 4 else 0.5 - 0.5 * math.cos(ph)
        dy = -4 * lift
        sy = 1.0 + 0.025 * lift
        sx = 1.0 - 0.012 * lift
        rot = 2.0 * math.sin(ph) if frames >= 4 else 0.0
        if calm:
            # (v0.34) a foe that floats (a sorcerer on his smoke, a hailstorm): a slow breath, no stride, no sway
            lift = 0.5 - 0.5 * math.cos(ph)
            dy, sy, sx, rot = -2 * lift, 1.0 + 0.015 * lift, 1.0 - 0.008 * lift, 0.0
        f = place(v, scale, cw, ch, foot, cx, dy=dy, sx=sx, sy=sy, rot=rot)
        fin = finish(f, cw, ch)
        for r in range(variants):
            sheet.alpha_composite(fin if r == 0 else enraged(fin, r), (c * cw, r * ch))
    save_small(sheet, out)
    print(out, sheet.size, "scale %.4f" % scale)


def figures_in_place(im: Image.Image, n: int) -> list:
    """(v0.34) the n figures side by side, each cropped to its own box: [(crop, (x0, y0)), …] with x0, y0 where the crop
    sat in the image"""
    a = np.array(im.getchannel("A")) > 40
    cols = a.any(axis=0)
    runs, start = [], None
    for x, on in enumerate(cols):
        if on and start is None:
            start = x
        elif not on and start is not None:
            runs.append([start, x])
            start = None
    if start is not None:
        runs.append([start, len(cols)])
    merged = [runs[0]]
    for r in runs[1:]:
        if r[0] - merged[-1][1] < 12:
            merged[-1][1] = r[1]
        else:
            merged.append(r)
    merged = [r for r in merged if r[1] - r[0] > 30]
    if len(merged) != n:
        return blobs_in_place(im, n)
    out = []
    for x0, x1 in merged:
        sub = im.crop((x0, 0, x1, im.height))
        bb = sub.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
        out.append((sub.crop(bb), (x0 + bb[0], bb[1])))
    return out


def blobs_in_place(im: Image.Image, n: int) -> list:
    """the poses nearly touch (a wing tip a pixel from the next figure): the n biggest connected shapes, left to right,
    small loose bits (sparks, a strand of hair) going to the nearest; [(crop, (x0, y0)), …] as figures_in_place"""
    from scipy import ndimage
    a = np.array(im.getchannel("A"))
    mask = a > 8
    lab, cnt = ndimage.label(mask)
    sizes = ndimage.sum(mask, lab, range(1, cnt + 1))
    order = list(np.argsort(sizes)[::-1])
    if cnt < n or sizes[order[n - 1]] < 0.05 * sizes[order[0]]:
        raise SystemExit("could not find %d separate figures (%d shapes)" % (n, cnt))
    seeds = [int(i) + 1 for i in order[:n]]
    coms = {sd: ndimage.center_of_mass(mask, lab, sd)[1] for sd in seeds}
    owner = np.zeros_like(lab)
    for i in range(1, cnt + 1):
        cx = ndimage.center_of_mass(mask, lab, i)[1]
        owner[lab == i] = min(seeds, key=lambda sd: abs(coms[sd] - cx))
    out = []
    rgba = np.array(im)
    for sd in sorted(seeds, key=lambda sd: coms[sd]):
        one = rgba.copy()
        one[..., 3] = np.where(owner == sd, one[..., 3], 0)
        sub = Image.fromarray(one)
        bb = sub.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
        out.append((sub.crop(bb), (bb[0], bb[1])))
    return out


def _gold(im: Image.Image) -> Image.Image:
    """the golden parts (beak, crest, talons, cuffs) as a mask: the same in every pose, unlike the wings"""
    a = np.array(im).astype(np.int16)
    m = (a[..., 0] > 150) & (a[..., 1] > 110) & (a[..., 2] < 90) & (a[..., 3] > 200)
    out = im.copy()
    out.putalpha(Image.fromarray((m * 255).astype(np.uint8)))
    return out


def body_shift(ref: Image.Image, other: Image.Image, by="shape") -> tuple:
    """(v0.34) how far to move `other` so its body lies on `ref`'s: the two poses of a flyer are one drawing with the wings
    moved, so the shift that makes the most of the shapes overlap puts the head and body in the same place"""
    from scipy.signal import fftconvolve
    k = 4
    if by == "gold":
        ref, other = _gold(ref), _gold(other)
    a = np.array(ref.getchannel("A").resize((ref.width // k, ref.height // k))) > 60
    b = np.array(other.getchannel("A").resize((other.width // k, other.height // k))) > 60
    # the body counts most: the solid middle of each shape (wing tips are thin)
    from scipy import ndimage
    it = 3 if by == "shape" else 0
    a = (ndimage.binary_erosion(a, iterations=it) if it else a).astype(np.float32)
    b = (ndimage.binary_erosion(b, iterations=it) if it else b).astype(np.float32)
    corr = fftconvolve(a, b[::-1, ::-1], mode="full")
    iy, ix = np.unravel_index(np.argmax(corr), corr.shape)
    return ((ix - (b.shape[1] - 1)) * k, (iy - (b.shape[0] - 1)) * k)


def pose_sheet(src, out, cell, height, poses=2, frames=2, foot=None, nudge=(0, 0), align="shape"):
    """(v0.34) a flyer drawn in `poses` wing positions side by side: the frames are the poses in turn (wings up, wings
    down), the body held still between them, all at one scale"""
    cw, ch = cell
    foot = foot if foot is not None else ch - 6
    im = load_rgba(src)
    figs = figures_in_place(im, poses)
    ref = figs[0][0]
    placed = [(ref, (0, 0))]
    for f, _ in figs[1:]:
        dx, dy = body_shift(ref, f, align)
        placed.append((f, (dx + nudge[0], dy + nudge[1])))
    x0 = min(p[1][0] for p in placed)
    y0 = min(p[1][1] for p in placed)
    x1 = max(p[1][0] + p[0].width for p in placed)
    y1 = max(p[1][1] + p[0].height for p in placed)
    layers = []
    for f, (dx, dy) in placed:
        layer = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
        layer.alpha_composite(f, (dx - x0, dy - y0))
        layers.append(layer)
    scale = min(height / (y1 - y0), (cw - 6) / (x1 - x0))
    cx = body_center_x(layers[0])
    sheet = Image.new("RGBA", (cw * frames, ch), (0, 0, 0, 0))
    for c in range(frames):
        lay = layers[(c * poses) // frames]
        sheet.alpha_composite(finish(place(lay, scale, cw, ch, foot, cx), cw, ch), (c * cw, 0))
    save_small(sheet, out)
    print(out, sheet.size, "scale %.4f" % scale, "union", (x1 - x0, y1 - y0), "shifts", [p[1] for p in placed])


RAGE = "fire"      # set by --rage: fire (hotter, an ember rim), frost (colder, an ice rim), shadow (darker, a violet rim)


def enraged(frame: Image.Image, level: int) -> Image.Image:
    """a boss's later phase (variant row 1, 2 …): its colours pushed one way and a glowing rim around the outline"""
    a = frame.getchannel("A")
    rgb = np.array(frame.convert("RGB")).astype(np.float32)
    k = 0.18 * level
    if RAGE == "frost":
        mul, add, rim = (1 - k * 0.6, 1 - k * 0.1, 1 + k * 0.5), (0, 8 * level, 22 * level), (110, 210, 255)
    elif RAGE == "shadow":
        mul, add, rim = (1 - k * 0.25, 1 - k * 0.7, 1 - k * 0.1), (10 * level, 0, 14 * level), (170, 60, 255)
    else:
        mul, add, rim = (1 + k, 1 - k * 0.5, 1 - k * 0.8), (18 * level, 0, 0), (255, 110, 30)
    for i in range(3):
        rgb[..., i] = np.clip(rgb[..., i] * mul[i] + add[i], 0, 255)
    body = Image.fromarray(rgb.astype(np.uint8)).convert("RGBA")
    body.putalpha(a)
    halo = a.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(2.0))
    glow = Image.new("RGBA", frame.size, rim + (0,))
    glow.putalpha(halo.point(lambda v: int(v * 0.75)))
    glow.alpha_composite(body)
    return glow


def save_small(sheet: Image.Image, out: str) -> None:
    """a 256-colour palette with alpha: about a quarter of the size and no visible loss at sprite size (the project zip
    must stay under 30 MB); --full keeps every colour"""
    if "--full" in sys.argv:
        sheet.save(out, optimize=True)
    else:
        sheet.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.FLOYDSTEINBERG).save(out, optimize=True)


def _opt(name, default, cast=str):
    if name in sys.argv:
        return cast(sys.argv[sys.argv.index(name) + 1])
    return default


if __name__ == "__main__":
    mode, src, out = sys.argv[1], sys.argv[2], sys.argv[3]
    RAGE = _opt("--rage", "fire")
    cell = tuple(int(v) for v in _opt("--cell", "120x156").split("x"))
    if mode == "poses":
        pose_sheet(src, out, cell, _opt("--height", cell[1] - 12, int), poses=_opt("--poses", 2, int),
                   frames=_opt("--frames", 2, int), foot=_opt("--foot", None, int),
                   nudge=tuple(int(v) for v in _opt("--nudge", "0,0").split(",")), align=_opt("--align", "shape"))
    elif mode == "char":
        char_sheet(src, out, height=_opt("--height", 134, int), cell=cell, foot=_opt("--foot", cell[1] - 6, int))
    else:
        foe_sheet(src, out, cell, _opt("--height", cell[1] - 12, int), frames=_opt("--frames", 4, int),
                  foot=_opt("--foot", None, int), variants=_opt("--variants", 1, int), views=_opt("--views", 1, int),
                  erode=_opt("--erode", 0, int), calm="--calm" in sys.argv)
