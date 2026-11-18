extends Control
## Item pictures drawn in code (no image files): every sword tier from the Iron Sword to the Frostreaver,
## every armour from the Leather Vest to the Glacial Aegis, and the health potion — on a tile framed in the
## item's rarity colour (the HTML RARITY_COLORS). Used by the shop, the hero sheet and messages.

const Tex = preload("res://scripts/fx/tex.gd")
const RARITY := {"common": Color("#c9a349"), "rare": Color("#5a9ad0"), "epic": Color("#c98ad0"), "legendary": Color("#ff8a3c")}

@export var kind := "weapon"      # weapon | armor | potion | mpotion (mana, v0.6)
@export var tier := 1
var tile := true                   # draw the framed tile behind the item
var dim := false                   # locked items: greyed

func setup(k: String, t: int, with_tile := true) -> Control:
	kind = k
	tier = t
	tile = with_tile
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()
	return self

static func rarity_of(k: String, t: int) -> String:
	if k == "potion" or k == "mpotion":
		return "common"
	if t >= 5:
		return "legendary"
	if t == 4:
		return "epic"
	if t == 3:
		return "rare"
	return "common"

static func rarity_color(k: String, t: int) -> Color:
	return RARITY[rarity_of(k, t)]

func _draw() -> void:
	var s: float = min(size.x, size.y)
	var c := size * 0.5
	var rc := rarity_color(kind, tier)
	if tile:
		draw_style_box(UI.box(Color(0.07, 0.05, 0.04, 0.95), Color(rc, 0.9 if not dim else 0.35), 2, s * 0.16, 0), Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)))
		draw_texture_rect(Tex.glow(), Rect2(c - Vector2(s, s) * 0.42, Vector2(s, s) * 0.84), false, Color(rc, 0.22 if not dim else 0.06))
	var k := s / 100.0 * (0.86 if tile else 1.0)
	match kind:
		"weapon":
			draw_set_transform(c + Vector2(-1, 1) * k * 2.0, PI * 0.25, Vector2(k, k))
			_sword(clamp(tier, 0, 6))
		"armor":
			draw_set_transform(c, 0.0, Vector2(k, k))
			_armor(clamp(tier, 0, 5))
		"potion":
			draw_set_transform(c, 0.0, Vector2(k, k))
			_potion()
		"mpotion":
			draw_set_transform(c, 0.0, Vector2(k, k))
			_potion(Color(0.22, 0.42, 0.95), Color(0.5, 0.7, 1.0))
	draw_set_transform(Vector2.ZERO)
	if dim:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.03, 0.45))

func _col(c: Color) -> Color:
	return Color(c.v, c.v, c.v, c.a).lerp(c, 0.25) if dim else c

func _poly(pts: Array, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array(pts), _col(col))

# ---------------------------------------------------------------- swords (drawn upright, tip up; rotated 45°)
func _sword(t: int) -> void:
	var blade: Color = [Color(0.6, 0.62, 0.66), Color(0.62, 0.64, 0.68), Color(0.78, 0.8, 0.86), Color(0.66, 0.86, 0.95), Color(0.58, 0.58, 0.64), Color(0.24, 0.21, 0.21), Color(0.7, 0.9, 1.0)][t]
	var edge: Color = [Color(0.8, 0.82, 0.86), Color(0.86, 0.88, 0.92), Color(0.97, 0.98, 1), Color(0.92, 0.99, 1), Color(0.9, 0.9, 0.94), Color(1, 0.55, 0.15), Color(0.95, 1, 1)][t]
	var guard: Color = [Color(0.4, 0.36, 0.3), Color(0.45, 0.4, 0.35), Color(0.58, 0.6, 0.66), Color(0.86, 0.88, 0.93), Color(0.95, 0.74, 0.3), Color(0.16, 0.13, 0.12), Color(0.75, 0.86, 0.98)][t]
	var gem: Color = [Color(0.5, 0.45, 0.4), Color(0.5, 0.45, 0.4), Color(0.7, 0.72, 0.78), Color(0.3, 0.6, 1), Color(0.9, 0.15, 0.15), Color(1, 0.5, 0.1), Color(0.4, 0.95, 1)][t]
	var wb: float = [4.5, 5.0, 5.5, 5.5, 7.0, 9.0, 6.5][t]
	var top: float = [-34.0, -36.0, -38.0, -40.0, -44.0, -40.0, -44.0][t]
	if t >= 5:
		draw_texture_rect(Tex.glow(), Rect2(Vector2(-22, top - 6), Vector2(44, 70)), false, Color(edge, 0.35))
	if t == 5:
		# the Emberfang: a broad cleaver with a glowing edge
		_poly([Vector2(-wb, 16), Vector2(-wb, top + 6), Vector2(wb + 4, top - 2), Vector2(wb + 2, 16)], blade)
		_poly([Vector2(wb - 1, top + 1), Vector2(wb + 4, top - 2), Vector2(wb + 2, 16), Vector2(wb - 1, 16)], edge)
		for i in 3:
			draw_circle(Vector2(-2, top + 14 + i * 12), 1.6, _col(Color(1, 0.5, 0.15)))
	elif t == 6:
		# the Frostreaver: a crystal blade with jagged edges
		var pts := [Vector2(-wb, 16)]
		for i in 6:
			var y: float = 16 + (top + 8 - 16) * (i + 1) / 6.0
			pts.append(Vector2(-wb - (2.5 if i % 2 == 0 else 0.0), y))
		pts.append(Vector2(0, top))
		for i in range(5, -1, -1):
			var y2: float = 16 + (top + 8 - 16) * (i + 1) / 6.0
			pts.append(Vector2(wb + (2.5 if i % 2 == 1 else 0.0), y2))
		pts.append(Vector2(wb, 16))
		_poly(pts, Color(blade, 0.9))
		_poly([Vector2(-1, 14), Vector2(-1, top + 10), Vector2(0, top + 2), Vector2(2, top + 10), Vector2(2, 14)], edge)
	else:
		_poly([Vector2(-wb, 16), Vector2(-wb, top + 10), Vector2(0, top), Vector2(wb, top + 10), Vector2(wb, 16)], blade)
		_poly([Vector2(-wb, 16), Vector2(-wb, top + 10), Vector2(0, top), Vector2(0, 16)], edge)
		draw_line(Vector2(0.5, 12), Vector2(0.5, top + 12), _col(blade.darkened(0.25)), 1.4)
		if t == 4:
			for i in 3:
				draw_line(Vector2(-2, top + 16 + i * 10), Vector2(2, top + 20 + i * 10), _col(Color(1, 0.3, 0.2)), 1.6)
	# guard
	if t == 4:
		_poly([Vector2(-18, 14), Vector2(-8, 18), Vector2(8, 18), Vector2(18, 14), Vector2(14, 22), Vector2(-14, 22)], guard)
	elif t == 6:
		_poly([Vector2(-16, 16), Vector2(0, 21), Vector2(16, 16), Vector2(12, 22), Vector2(-12, 22)], guard)
	else:
		_poly([Vector2(-15, 16), Vector2(15, 16), Vector2(15, 22), Vector2(-15, 22)], guard)
		_poly([Vector2(-15, 16), Vector2(15, 16), Vector2(15, 18), Vector2(-15, 18)], guard.lightened(0.3))
	# grip with wraps, pommel
	_poly([Vector2(-3.2, 22), Vector2(3.2, 22), Vector2(3.2, 38), Vector2(-3.2, 38)], Color(0.36, 0.22, 0.12))
	for i in 4:
		draw_line(Vector2(-3.2, 24 + i * 4), Vector2(3.2, 26 + i * 4), _col(Color(0.22, 0.13, 0.07)), 1.2)
	draw_circle(Vector2(0, 41.5), 5.0, _col(guard))
	draw_circle(Vector2(0, 41.5), 3.0, _col(gem))
	draw_circle(Vector2(-1, 40.5), 1.0, _col(Color(1, 1, 1, 0.8)))

# ---------------------------------------------------------------- armour (a cuirass with shoulder plates)
func _armor(t: int) -> void:
	var body: Color = [Color(0.4, 0.36, 0.3), Color(0.55, 0.36, 0.2), Color(0.6, 0.62, 0.66), Color(0.3, 0.28, 0.3), Color(0.22, 0.52, 0.44), Color(0.66, 0.86, 0.98)][t]
	var trim: Color = [Color(0.5, 0.45, 0.4), Color(0.75, 0.55, 0.32), Color(0.82, 0.84, 0.88), Color(1, 0.55, 0.18), Color(0.85, 0.72, 0.3), Color(0.95, 1, 1)][t]
	if t >= 3:
		draw_texture_rect(Tex.glow(), Rect2(Vector2(-40, -42), Vector2(80, 84)), false, Color(trim, 0.22))
	var torso := [Vector2(-22, -28), Vector2(-9, -32), Vector2(0, -22), Vector2(9, -32), Vector2(22, -28), Vector2(25, 6), Vector2(19, 30), Vector2(-19, 30), Vector2(-25, 6)]
	var dark := []
	for p in torso:
		dark.append(p + Vector2(1.5, 2.5))
	_poly(dark, Color(0, 0, 0, 0.45))
	_poly(torso, body)
	# light falls from the left
	_poly([Vector2(-22, -28), Vector2(-9, -32), Vector2(0, -22), Vector2(0, 30), Vector2(-19, 30), Vector2(-25, 6)], body.lightened(0.12))
	match t:
		1:
			for i in 4:
				draw_line(Vector2(-4, -14 + i * 9), Vector2(4, -10 + i * 9), _col(trim), 1.4)
				draw_line(Vector2(4, -14 + i * 9), Vector2(-4, -10 + i * 9), _col(trim), 1.4)
		2:
			for y in range(-20, 26, 5):
				for x in range(-20, 22, 5):
					if abs(x) < 23 - abs(y) * 0.1:
						draw_arc(Vector2(x + (2.5 if (y / 5) % 2 == 0 else 0.0), y), 2.0, 0, TAU, 8, _col(Color(0.38, 0.4, 0.44)), 1.0)
		3:
			draw_line(Vector2(0, -20), Vector2(0, 28), _col(trim), 2.0)
			draw_line(Vector2(-18, 0), Vector2(18, 0), _col(Color(trim, 0.7)), 1.5)
			draw_arc(Vector2(0, 2), 9.0, 0, TAU, 20, _col(trim), 1.6)
		4:
			for y in range(-18, 28, 7):
				for x in range(-18, 20, 8):
					draw_arc(Vector2(x + (4 if (y / 7) % 2 == 0 else 0), y), 4.0, 0.2, PI - 0.2, 8, _col(trim.darkened(0.1)), 1.2)
		5:
			_poly([Vector2(-6, -16), Vector2(0, -24), Vector2(6, -16), Vector2(0, 0)], Color(1, 1, 1, 0.75))
			draw_line(Vector2(-20, 10), Vector2(-6, 24), _col(Color(1, 1, 1, 0.6)), 1.5)
	# shoulder plates and belt
	for sx in [-1, 1]:
		var pts := []
		for i in 13:
			var a := PI + i / 12.0 * PI
			pts.append(Vector2(sx * 24, -24) + Vector2(cos(a) * 12.0, sin(a) * 9.0))
		_poly(pts, body.darkened(0.08) if sx > 0 else body.lightened(0.08))
		draw_arc(Vector2(sx * 24, -24), 11.0, PI, TAU, 14, _col(trim), 1.6)
	_poly([Vector2(-20, 19), Vector2(20, 19), Vector2(19.5, 25), Vector2(-19.5, 25)], trim.darkened(0.35))
	_poly([Vector2(-4, 18), Vector2(4, 18), Vector2(4, 26), Vector2(-4, 26)], trim)

# ---------------------------------------------------------------- potion
func _potion(liquid := Color(0.86, 0.16, 0.26), shine := Color(1, 0.45, 0.5)) -> void:
	draw_texture_rect(Tex.glow(), Rect2(Vector2(-34, -24), Vector2(68, 68)), false, Color(liquid.lightened(0.2), 0.3))
	draw_circle(Vector2(1.5, 13), 24.0, Color(0, 0, 0, 0.4))
	draw_circle(Vector2(0, 10), 24.0, Color(0.85, 0.92, 0.95, 0.35))
	# the liquid: the lower part of the bulb
	var liq := []
	for i in 17:
		var a := -0.25 + i / 16.0 * (PI + 0.5)
		liq.append(Vector2(cos(a) * 21.0, 10.0 + sin(a) * 21.0))
	_poly(liq, liquid)
	_poly([liq[0], liq[0] + Vector2(-2, -2), liq[16] + Vector2(2, -2), liq[16]], shine)
	draw_arc(Vector2(0, 10), 24.0, 0, TAU, 40, Color(0.92, 0.96, 1, 0.9), 2.2, true)
	_poly([Vector2(-6, -26), Vector2(6, -26), Vector2(6, -12), Vector2(-6, -12)], Color(0.85, 0.92, 0.95, 0.5))
	_poly([Vector2(-8, -34), Vector2(8, -34), Vector2(7, -25), Vector2(-7, -25)], Color(0.62, 0.42, 0.24))
	draw_arc(Vector2(-6, 4), 13.0, PI * 1.1, PI * 1.45, 10, Color(1, 1, 1, 0.75), 2.5, true)
