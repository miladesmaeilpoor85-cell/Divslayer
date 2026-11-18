extends RefCounted
## (v0.18) The look of the puzzle shrines' pieces, drawn in code in the game's style (flat colours, a lighter top,
## thick dark outlines): stone blocks, pressure plates, a lever, runes and the mosaic, mirrors, the light emitter and
## the target crystal, ice walls, brambles, the altar, the inner door, the cracked wall, tablets, the eternal flame,
## the Watchers, water, ice and oil. Every function draws on `ci` around a local origin; tall things stand on the
## origin (their feet), flat things fill the rect they are given. The braziers, the barrel and the crystals reuse the
## map-object pictures.

const PropsFx = preload("res://scripts/fx/props_fx.gd")
const Tex = preload("res://scripts/fx/tex.gd")

const OL := Color(0.09, 0.07, 0.06)
const GOLD := Color(1.0, 0.82, 0.42)
const EMBER := Color(1.0, 0.56, 0.2)

## stone colours by shrine (they follow the painted floors)
const STONE := {
	"shrine_embers": Color(0.47, 0.52, 0.42), "shrine_weight": Color(0.47, 0.45, 0.52), "shrine_fuse": Color(0.5, 0.42, 0.38),
	"shrine_tides": Color(0.4, 0.5, 0.48), "shrine_light": Color(0.5, 0.56, 0.66), "shrine_echoes": Color(0.52, 0.44, 0.4),
	"shrine_shadows": Color(0.42, 0.4, 0.5),
}

static func stone(key: String) -> Color:
	return STONE.get(key, Color(0.5, 0.48, 0.5))

static func _rect(ci: CanvasItem, r: Rect2, fill: Color, w := 2.0, ol := OL) -> void:
	ci.draw_rect(r, fill)
	ci.draw_rect(r, ol, false, w)

static func _poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, w := 2.0, ol := OL) -> void:
	ci.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, ol, w, true)

static func _oval(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)

static func _glow(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_texture_rect(Tex.glow(), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, col)

static func shadow(ci: CanvasItem, w: float, a := 0.32) -> void:
	_oval(ci, Vector2(0, -2), w * 0.55, w * 0.18, Color(0, 0, 0, a))

# ---------------------------------------------------------------- tall pieces (origin = feet)
## a carved stone block (one cell): a light top and a darker face, a square rune on top
static func block(ci: CanvasItem, base: Color, glow := 0.0) -> void:
	shadow(ci, 44.0, 0.38)
	_rect(ci, Rect2(-19, -14, 38, 13), base.darkened(0.42))
	_rect(ci, Rect2(-19, -38, 38, 25), base.lightened(0.08))
	ci.draw_rect(Rect2(-12, -32, 24, 13), base.darkened(0.25), false, 2.0)
	ci.draw_rect(Rect2(-6, -28, 12, 5), Color(GOLD, 0.25 + 0.6 * glow) if glow > 0.0 else base.darkened(0.3))
	ci.draw_line(Vector2(-15, -9), Vector2(-9, -5), base.darkened(0.6), 1.0)
	ci.draw_line(Vector2(10, -11), Vector2(15, -6), base.darkened(0.6), 1.0)

## the shrine's lever: down (left) or flipped (right)
static func lever(ci: CanvasItem, base: Color, flip_k: float) -> void:
	shadow(ci, 22.0)
	_rect(ci, Rect2(-10, -8, 20, 7), base.darkened(0.3))
	var tip := Vector2(lerp(-10.0, 10.0, flip_k), -26)
	ci.draw_line(Vector2(0, -6), tip, OL, 5.0)
	ci.draw_line(Vector2(0, -6), tip, Color(0.55, 0.42, 0.3), 3.0)
	ci.draw_circle(tip, 4.0, OL)
	ci.draw_circle(tip, 3.0, Color(0.85, 0.3, 0.22))

## the stone that holds the eternal flame; `cold` for a frost basin
static func pedestal(ci: CanvasItem, base: Color, h := 26.0) -> void:
	shadow(ci, 30.0)
	_rect(ci, Rect2(-13, -7, 26, 7), base.darkened(0.35))
	_rect(ci, Rect2(-9, -h + 4, 18, h - 10), base.darkened(0.1))
	_rect(ci, Rect2(-14, -h - 2, 28, 7), base.lightened(0.1))

static func eternal_flame(ci: CanvasItem, base: Color, t: float, seed: float) -> void:
	pedestal(ci, base, 26.0)
	_glow(ci, Vector2(0, -38), 34.0, Color(1, 0.6, 0.25, 0.35))
	PropsFx.fire(ci, Vector2(0, -28), 7.5, t, seed)

## a brazier's flame (the bowl is the map's brazier picture); a timed brazier shows its time running out as a ring
static func brazier_fire(ci: CanvasItem, t: float, seed: float, left_k := -1.0) -> void:
	PropsFx.fire(ci, Vector2(0, -31), 5.5, t, seed)
	if left_k >= 0.0:
		ci.draw_arc(Vector2(0, -22), 20.0, -PI * 0.5, -PI * 0.5 + TAU * left_k, 28, Color(1, 0.75, 0.3, 0.85), 2.5, true)

static func mirror(ci: CanvasItem, base: Color, o: int, hit: float) -> void:
	shadow(ci, 34.0)
	_oval(ci, Vector2(0, -6), 15, 6, base.darkened(0.35))
	ci.draw_arc(Vector2(0, -6), 15.0, 0, TAU, 24, OL, 2.0, true)
	var a := Vector2(-13, -8) if o == 0 else Vector2(-13, -34)
	var b := Vector2(13, -34) if o == 0 else Vector2(13, -8)
	ci.draw_line(Vector2(0, -6), Vector2(0, -21), OL, 5.0)
	ci.draw_line(a, b, OL, 9.0)
	ci.draw_line(a, b, Color(0.78, 0.86, 0.92), 6.0)
	ci.draw_line(a.lerp(b, 0.15) + Vector2(-1, -1), a.lerp(b, 0.6) + Vector2(-1, -1), Color(1, 1, 1, 0.9), 2.0)
	if hit > 0.0:
		_glow(ci, a.lerp(b, 0.5), 16.0, Color(1, 0.95, 0.7, 0.55 * hit))

static func emitter(ci: CanvasItem, base: Color, dir: Vector2, t: float) -> void:
	pedestal(ci, base, 22.0)
	var c := Vector2(0, -28)
	var p := 0.85 + 0.15 * sin(t * 4.0)
	_glow(ci, c, 22.0, Color(1, 0.95, 0.7, 0.5 * p))
	ci.draw_circle(c, 7.5, OL)
	ci.draw_circle(c, 6.0, Color(1, 0.96, 0.78))
	ci.draw_line(c, c + dir * 10.0, OL, 5.0)
	ci.draw_line(c, c + dir * 10.0, Color(0.9, 0.8, 0.5), 3.0)

## the crystal the light must reach: dim and blue, or blazing gold
static func target(ci: CanvasItem, base: Color, lit: float, t: float) -> void:
	pedestal(ci, base, 20.0)
	var c := Vector2(0, -32)
	var col := Color(0.55, 0.62, 0.8).lerp(Color(1, 0.86, 0.45), lit)
	if lit > 0.0:
		_glow(ci, c, 30.0 + 4.0 * sin(t * 5.0), Color(1, 0.86, 0.5, 0.55 * lit))
	_poly(ci, PackedVector2Array([c + Vector2(0, -13), c + Vector2(9, -2), c + Vector2(0, 9), c + Vector2(-9, -2)]), col)
	ci.draw_line(c + Vector2(0, -13), c + Vector2(0, 9), Color(1, 1, 1, 0.45), 1.5)

static func icewall(ci: CanvasItem, k: float) -> void:
	if k <= 0.0:
		return
	var h := 40.0 * k
	shadow(ci, 42.0 * k, 0.3)
	_rect(ci, Rect2(-19, -12 * k, 38, 11 * k), Color(0.48, 0.78, 0.92, 0.9), 2.0, Color(0.12, 0.26, 0.36))
	_rect(ci, Rect2(-19, -h, 38, h - 12 * k), Color(0.72, 0.92, 1.0, 0.88), 2.0, Color(0.12, 0.26, 0.36))
	ci.draw_line(Vector2(-12, -h + 6), Vector2(-4, -h * 0.4), Color(1, 1, 1, 0.8), 2.0)
	ci.draw_line(Vector2(6, -h + 4), Vector2(12, -h * 0.55), Color(1, 1, 1, 0.6), 1.5)

## thorns that only fire clears; burn_k runs 0..1 while it burns away
static func bramble(ci: CanvasItem, t: float, seed: float, burn_k: float) -> void:
	if burn_k >= 1.0:
		return
	var a := 1.0 - burn_k
	shadow(ci, 40.0, 0.3 * a)
	var stems := [[Vector2(-18, -2), Vector2(-6, -30), Vector2(10, -8)], [Vector2(-10, -4), Vector2(4, -34), Vector2(18, -4)],
		[Vector2(-16, -16), Vector2(2, -22), Vector2(17, -18)], [Vector2(-4, -2), Vector2(-14, -24), Vector2(6, -36)]]
	for s in stems:
		var pts := PackedVector2Array()
		for i in 9:
			var u := i / 8.0
			pts.append(s[0].lerp(s[1], u).lerp(s[1].lerp(s[2], u), u))
		ci.draw_polyline(pts, Color(OL, a), 5.0, true)
		ci.draw_polyline(pts, Color(0.36, 0.3, 0.16, a), 3.0, true)
		for i in range(1, 8, 2):
			var p: Vector2 = pts[i]
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-2, 0), p + Vector2(2, 0), p + Vector2(0, -5)]), Color(0.62, 0.55, 0.3, a))
	for i in 4:
		ci.draw_circle(Vector2(-12 + i * 8, -14 - (i % 2) * 10), 3.0, Color(0.3, 0.42, 0.2, a))
	if burn_k > 0.0:
		for i in 3:
			PropsFx.fire(ci, Vector2(-12 + i * 12, -6 - (i % 2) * 8), 5.0 * a + 2.0, t, seed + i)

static func altar(ci: CanvasItem, base: Color, ready: bool, t: float) -> void:
	shadow(ci, 40.0)
	_rect(ci, Rect2(-12, -16, 24, 15), base.darkened(0.3))
	_rect(ci, Rect2(-18, -27, 36, 11), base.lightened(0.12))
	ci.draw_line(Vector2(-14, -22), Vector2(14, -22), base.darkened(0.2), 1.5)
	if ready:
		var y := -46.0 + 3.0 * sin(t * 2.4)
		_glow(ci, Vector2(0, y), 26.0, Color(1, 0.85, 0.45, 0.55))
		sigil(ci, Vector2(0, y), 9.0, GOLD)

## the shrine's sigil: a ring with a seven-pointed star
static func sigil(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_arc(c, r, 0, TAU, 28, OL, 4.0, true)
	ci.draw_arc(c, r, 0, TAU, 28, col, 2.0, true)
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(c + Vector2.from_angle(-PI * 0.5 + i * TAU * 3.0 / 7.0) * r * 0.78)
	ci.draw_polyline(pts, col, 1.5, true)

## the inner door: a stone slab that sinks into the floor as it opens (k 0 shut .. 1 open)
static func door(ci: CanvasItem, base: Color, k: float, lit: float) -> void:
	if k >= 1.0:
		ci.draw_rect(Rect2(-20, -4, 40, 4), base.darkened(0.45))
		return
	var h := 44.0 * (1.0 - k)
	_rect(ci, Rect2(-20, -h, 40, h), base.darkened(0.15))
	ci.draw_rect(Rect2(-20, -h, 40, 5), base.lightened(0.12))
	if h > 18.0:
		var c := Vector2(0, -h * 0.5 - 2)
		var col := Color(0.25, 0.22, 0.24).lerp(GOLD, lit)
		if lit > 0.0:
			_glow(ci, c, 18.0, Color(1, 0.85, 0.45, 0.4 * lit))
		sigil(ci, c, 8.0, col)

static func cracked(ci: CanvasItem, base: Color) -> void:
	_rect(ci, Rect2(-20, -44, 40, 44), base.darkened(0.12))
	var cr := [[Vector2(-14, -40), Vector2(-6, -30), Vector2(-11, -20), Vector2(-3, -9)], [Vector2(8, -42), Vector2(3, -31), Vector2(12, -22)],
		[Vector2(-2, -24), Vector2(7, -14), Vector2(4, -3)]]
	for c in cr:
		ci.draw_polyline(PackedVector2Array(c), OL, 2.0, true)
	for i in 4:
		ci.draw_circle(Vector2(-14 + i * 9, -3), 3.0 + (i % 2), base.darkened(0.3))

static func tablet(ci: CanvasItem, base: Color) -> void:
	shadow(ci, 26.0)
	var pts := PackedVector2Array([Vector2(-11, 0), Vector2(-11, -20), Vector2(-8, -26), Vector2(8, -26), Vector2(11, -20), Vector2(11, 0)])
	_poly(ci, pts, base.lightened(0.05))
	for i in 3:
		ci.draw_line(Vector2(-6, -19 + i * 5), Vector2(6, -19 + i * 5), base.darkened(0.4), 1.5)

## a Watcher: a stone pillar with an amber eye that turns with its light
static func watcher(ci: CanvasItem, base: Color, ang: float, alarm: float) -> void:
	shadow(ci, 28.0, 0.4)
	_rect(ci, Rect2(-11, -40, 22, 40), base.darkened(0.2))
	_rect(ci, Rect2(-14, -46, 28, 8), base.lightened(0.05))
	var eye := Vector2(0, -26) + Vector2.from_angle(ang) * Vector2(5, 3)
	var col := Color(1, 0.78, 0.3).lerp(Color(1, 0.25, 0.2), alarm)
	_glow(ci, eye, 14.0, Color(col, 0.6))
	ci.draw_circle(eye, 4.5, OL)
	ci.draw_circle(eye, 3.2, col)

# ---------------------------------------------------------------- flat pieces (rects in world space)
static func plate(ci: CanvasItem, r: Rect2, base: Color, heavy: bool, pressed: bool) -> void:
	var inner := r.grow(-3.0)
	_rect(ci, inner, base.darkened(0.42 if pressed else 0.3))
	var top := inner.grow(-3.0)
	if pressed:
		top.position.y += 2.0
	ci.draw_rect(top, base.darkened(0.12) if not pressed else base.darkened(0.2))
	var c := top.get_center()
	var col := GOLD if pressed else base.darkened(0.45)
	if pressed:
		_glow(ci, c, 22.0, Color(1, 0.85, 0.45, 0.45))
	if heavy:
		ci.draw_rect(Rect2(c - Vector2(7, 7), Vector2(14, 14)), col, false, 2.0)
		ci.draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), col)
	else:
		ci.draw_arc(c, 8.0, 0, TAU, 20, col, 2.0, true)
		ci.draw_circle(c, 2.5, col)

## a rune disc: its glyph (1 circle, 2 crescent, 3 triangle, 4 diamond), glowing once stepped in order
static func rune(ci: CanvasItem, r: Rect2, base: Color, g: int, lit: float, wrong: float) -> void:
	var c := r.get_center()
	var rad: float = r.size.x * 0.46
	_oval(ci, c, rad, rad, base.darkened(0.35))
	ci.draw_arc(c, rad, 0, TAU, 28, OL, 2.0, true)
	var col := base.darkened(0.55).lerp(Color(1, 0.62, 0.25), lit).lerp(Color(1, 0.25, 0.2), wrong)
	if lit > 0.0 or wrong > 0.0:
		_glow(ci, c, rad * 1.8, Color(col, 0.5 * max(lit, wrong)))
	ci.draw_arc(c, rad - 4.0, 0, TAU, 28, col, 1.5, true)
	glyph(ci, c, g, rad * 0.5, col)

static func glyph(ci: CanvasItem, c: Vector2, g: int, s: float, col: Color) -> void:
	match g:
		1:
			ci.draw_arc(c, s * 0.8, 0, TAU, 20, col, 2.5, true)
		2:
			ci.draw_arc(c, s * 0.8, PI * 0.3, PI * 1.7, 20, col, 2.5, true)
			ci.draw_arc(c + Vector2(s * 0.35, 0), s * 0.55, PI * 0.45, PI * 1.55, 16, col, 2.0, true)
		3:
			ci.draw_polyline(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.9, s * 0.7), c + Vector2(-s * 0.9, s * 0.7), c + Vector2(0, -s)]), col, 2.5, true)
		_:
			ci.draw_polyline(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.8, 0), c + Vector2(0, s), c + Vector2(-s * 0.8, 0), c + Vector2(0, -s)]), col, 2.5, true)

## the mosaic: the room in miniature with its four runes' glyphs, each with the dots that tell when to step on it
static func mosaic(ci: CanvasItem, r: Rect2, base: Color, runes: Array, room: Rect2) -> void:
	_rect(ci, r.grow(-4.0), base.darkened(0.45), 3.0)
	ci.draw_rect(r.grow(-9.0), base.darkened(0.3))
	var inner := r.grow(-14.0)
	for ru in runes:
		var rel: Vector2 = (ru["c"] - room.position) / room.size
		var p: Vector2 = inner.position + rel * inner.size
		ci.draw_circle(p, 11.0, base.darkened(0.55))
		glyph(ci, p + Vector2(0, -1), int(ru["g"]), 5.5, Color(0.95, 0.85, 0.6))
		var n: int = int(ru["n"])
		for i in n:
			ci.draw_circle(p + Vector2(-(n - 1) * 3.0 + i * 6.0, 15.0), 2.2, GOLD)

## deep water (or the ice frost made of it), shallow pools, oil
static func water(ci: CanvasItem, r: Rect2, t: float, seed: float) -> void:
	ci.draw_rect(r, Color(0.09, 0.22, 0.3))
	for i in 2:
		var y := r.position.y + 10.0 + i * 18.0 + sin(t * 1.4 + seed + i) * 2.0
		var x0 := r.position.x + 6.0 + fmod(seed * 7.0 + i * 13.0, 12.0)
		ci.draw_line(Vector2(x0, y), Vector2(x0 + 14.0, y), Color(0.35, 0.6, 0.7, 0.55), 2.0)

static func ice(ci: CanvasItem, r: Rect2, warn: float, t: float) -> void:
	var blink := warn > 0.0 and int(t * 8.0) % 2 == 0
	ci.draw_rect(r, Color(0.78, 0.92, 0.98) if not blink else Color(0.55, 0.75, 0.86))
	ci.draw_rect(r.grow(-1.0), Color(0.5, 0.75, 0.88), false, 2.0)
	ci.draw_line(r.position + Vector2(6, 8), r.position + Vector2(18, 20), Color(1, 1, 1, 0.8), 2.0)
	if warn > 0.0:
		ci.draw_polyline(PackedVector2Array([r.position + Vector2(8, 30), r.position + Vector2(20, 22), r.position + Vector2(26, 32), r.position + Vector2(34, 18)]), Color(0.2, 0.36, 0.48), 1.5, true)

static func shallow(ci: CanvasItem, r: Rect2, t: float, seed: float) -> void:
	ci.draw_rect(r.grow(-1.0), Color(0.2, 0.42, 0.4, 0.8))
	var y := r.position.y + 20.0 + sin(t * 1.8 + seed) * 2.0
	ci.draw_line(Vector2(r.position.x + 8, y), Vector2(r.position.x + 22, y), Color(0.55, 0.78, 0.72, 0.5), 1.5)
	ci.draw_circle(r.position + Vector2(30, 10), 3.0, Color(0.3, 0.55, 0.3))

static func storm_arcs(ci: CanvasItem, r: Rect2, t: float, seed: float) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		var x := r.position.x + 4.0 + i * 6.4
		var y := r.get_center().y + sin(t * 40.0 + seed + i * 2.1) * 9.0
		pts.append(Vector2(x, y))
	ci.draw_polyline(pts, Color(0.85, 0.75, 1.0, 0.9), 2.0, true)
	ci.draw_polyline(pts, Color(1, 1, 1, 0.7), 1.0, true)

static func oil(ci: CanvasItem, pts: Array, burned: float, burnt_all: bool, t: float) -> void:
	if pts.size() < 2:
		return
	var line := PackedVector2Array(pts)
	ci.draw_polyline(line, Color(0.05, 0.04, 0.03, 0.85), 11.0, true)
	ci.draw_polyline(line, Color(0.16, 0.12, 0.08, 0.9) if not burnt_all else Color(0.08, 0.07, 0.06, 0.9), 7.0, true)
	if not burnt_all:
		ci.draw_polyline(line, Color(0.6, 0.5, 0.35, 0.35), 2.0, true)
	if burned > 0.0 and not burnt_all:
		var left := burned
		for i in range(1, pts.size()):
			var a: Vector2 = pts[i - 1]
			var b: Vector2 = pts[i]
			var ln := a.distance_to(b)
			var u: float = clamp(left / ln, 0.0, 1.0)
			var e := a.lerp(b, u)
			for k in 3:
				PropsFx.fire(ci, a.lerp(e, (k + 1) / 3.0), 4.5, t, float(i * 3 + k))
			left -= ln
			if left <= 0.0:
				break

## a Watcher's light on the floor
static func cone(ci: CanvasItem, c: Vector2, ang: float, half: float, rng: float, alarm: float) -> void:
	var pts := PackedVector2Array([c])
	for i in 13:
		var a: float = ang - half + 2.0 * half * i / 12.0
		pts.append(c + Vector2.from_angle(a) * rng)
	var col := Color(1, 0.86, 0.45, 0.17).lerp(Color(1, 0.3, 0.2, 0.3), alarm)
	ci.draw_colored_polygon(pts, col)
	ci.draw_polyline(pts.slice(1), Color(col, 0.35), 1.5, true)

## the way into a shrine on its region's map: a stone stair going down, two rune stones and a pillar of light
## (gold and quieter once the shrine is done)
static func gate(ci: CanvasItem, w: float, done: bool, t: float) -> void:
	var hw := w * 0.5
	_oval(ci, Vector2(0, -4), hw + 18.0, 15.0, Color(0, 0, 0, 0.25))
	_poly(ci, PackedVector2Array([Vector2(-hw - 8, 4), Vector2(-hw - 4, -14), Vector2(hw + 4, -14), Vector2(hw + 8, 4)]), Color(0.45, 0.44, 0.47))
	ci.draw_rect(Rect2(-hw, -11, w, 13), Color(0.06, 0.05, 0.07))
	for i in 3:
		ci.draw_line(Vector2(-hw + 2, -8 + i * 4), Vector2(hw - 2, -8 + i * 4), Color(0.3, 0.29, 0.33), 2.0)
	var rc := Color(0.65, 0.88, 1.0) if not done else GOLD
	var p := 0.6 + 0.4 * sin(t * 2.2)
	for sx in [-1.0, 1.0]:
		var x: float = sx * (hw + 12.0)
		_rect(ci, Rect2(x - 5, -30, 10, 28), Color(0.5, 0.49, 0.53))
		ci.draw_rect(Rect2(x - 5, -34, 10, 5), Color(0.6, 0.59, 0.63))
		_glow(ci, Vector2(x, -18), 9.0, Color(rc, 0.7 * p))
		ci.draw_line(Vector2(x, -24), Vector2(x, -12), rc, 2.0)

static func pillar_of_light(ci: CanvasItem, w: float, done: bool, t: float) -> void:
	var col := Color(0.7, 0.9, 1.0) if not done else Color(1.0, 0.84, 0.45)
	var a := (0.32 if not done else 0.16) * (0.8 + 0.2 * sin(t * 1.7))
	var h := 300.0 if not done else 150.0
	var steps := 14
	for i in steps:
		var k := float(i) / steps
		var y0 := -h * k
		var ww: float = w * (0.9 - 0.45 * k)
		ci.draw_rect(Rect2(-ww * 0.5, y0 - h / steps, ww, h / steps + 1.0), Color(col, a * (1.0 - k)))
		ci.draw_rect(Rect2(-ww * 0.18, y0 - h / steps, ww * 0.36, h / steps + 1.0), Color(1, 1, 1, a * 0.9 * (1.0 - k)))
	for i in 4:
		var ph := fmod(t * 0.35 + i * 0.25, 1.0)
		ci.draw_circle(Vector2(sin(t + i * 1.7) * w * 0.25, -h * ph), 2.0, Color(1, 1, 1, 0.6 * (1.0 - ph)))
