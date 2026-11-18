extends RefCounted
## Small textures the effects share, made once at run time (no image files): a soft dot, a spark streak,
## the soft contact shadow, the light-map "cut" falloff (the HTML VIS 'cut' sprite) and a glow falloff.

static var _c := {}

static func _radial(key: String, size: int, stops: Array) -> Texture2D:
	if _c.has(key):
		return _c[key]
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for s in stops:
		offs.append(float(s[0]))
		cols.append(s[1])
	var g := Gradient.new()
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	_c[key] = t
	return t

## white, soft edge: particles, fireflies, coins' shine
static func dot() -> Texture2D:
	return _radial("dot", 32, [[0.0, Color(1, 1, 1, 1)], [0.45, Color(1, 1, 1, 0.85)], [1.0, Color(1, 1, 1, 0)]])

## a hard-ish dot for debris and rain splashes
static func pip() -> Texture2D:
	return _radial("pip", 16, [[0.0, Color(1, 1, 1, 1)], [0.7, Color(1, 1, 1, 1)], [1.0, Color(1, 1, 1, 0)]])

## the contact shadow under characters (stretched into an ellipse by the sprite's scale)
static func shadow() -> Texture2D:
	return _radial("shadow", 64, [[0.0, Color(0, 0, 0, 1)], [0.6, Color(0, 0, 0, 0.9)], [1.0, Color(0, 0, 0, 0)]])

## the light map: how much darkness a light takes away from its centre outwards (V15.lightSprite('cut'))
static func cut() -> Texture2D:
	return _radial("cut", 64, [[0.0, Color(1, 1, 1, 1)], [0.5, Color(1, 1, 1, 0.52)], [1.0, Color(1, 1, 1, 0)]])

## coloured glow around bright lights (additive)
static func glow() -> Texture2D:
	return _radial("glow", 64, [[0.0, Color(1, 1, 1, 1)], [0.35, Color(1, 1, 1, 0.45)], [1.0, Color(1, 1, 1, 0)]])

## a spark streak, long along y with its bright head at +y (particles align y with their velocity)
static func streak() -> Texture2D:
	if _c.has("streak"):
		return _c["streak"]
	var w := 8
	var h := 32
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for x in w:
		var vx: float = 1.0 - abs((x + 0.5) / w * 2.0 - 1.0)
		for y in h:
			var u := (y + 0.5) / h
			# fading tail at the top, bright head at the bottom
			var a: float = pow(u, 1.6) * vx * vx
			if u > 0.85:
				a *= (1.0 - u) / 0.15
			img.set_pixel(x, y, Color(1, 1, 1, clamp(a * 1.6, 0.0, 1.0)))
	var t := ImageTexture.create_from_image(img)
	_c["streak"] = t
	return t

## a thin rain streak, long along y
static func rain() -> Texture2D:
	if _c.has("rain"):
		return _c["rain"]
	var w := 3
	var h := 26
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for x in w:
		var vx: float = 1.0 - abs((x + 0.5) / w * 2.0 - 1.0)
		for y in h:
			var u := (y + 0.5) / h
			img.set_pixel(x, y, Color(1, 1, 1, clamp(vx * (0.25 + 0.75 * u) * 1.2, 0.0, 1.0)))
	var t := ImageTexture.create_from_image(img)
	_c["rain"] = t
	return t

## a small leaf (pointed ellipse with a darker vein), white: particles tint it
static func leaf() -> Texture2D:
	if _c.has("leaf"):
		return _c["leaf"]
	var w := 16
	var h := 8
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var u := (x + 0.5) / w * 2.0 - 1.0
			var v := (y + 0.5) / h * 2.0 - 1.0
			var half: float = (1.0 - u * u) * 0.95
			var inside: float = clamp((half - abs(v)) * 4.0, 0.0, 1.0)
			var shade: float = 0.75 if abs(v) < 0.18 else 1.0
			img.set_pixel(x, y, Color(shade, shade, shade, inside))
	var t := ImageTexture.create_from_image(img)
	_c["leaf"] = t
	return t

## a soft, lumpy cloud for fog and smoke banks
static func cloud() -> Texture2D:
	if _c.has("cloud"):
		return _c["cloud"]
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.035
	noise.fractal_octaves = 3
	for y in n:
		for x in n:
			var d := Vector2((x + 0.5) / n - 0.5, (y + 0.5) / n - 0.5).length() * 2.0
			var fall: float = clamp(1.0 - d, 0.0, 1.0)
			var v: float = (noise.get_noise_2d(x, y) * 0.5 + 0.5)
			img.set_pixel(x, y, Color(1, 1, 1, clamp(fall * fall * (0.35 + v * 0.9), 0.0, 1.0)))
	var t := ImageTexture.create_from_image(img)
	_c["cloud"] = t
	return t

## shared blend materials: additive glow, multiplied darkness
static func add_material() -> CanvasItemMaterial:
	if _c.has("add"):
		return _c["add"]
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_c["add"] = m
	return m

static func mul_material() -> CanvasItemMaterial:
	if _c.has("mul"):
		return _c["mul"]
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_c["mul"] = m
	return m

## a fade-out alpha ramp shared by particles: full, then gone
static func fade_ramp(hold := 0.0) -> Gradient:
	var key := "ramp%.2f" % hold
	if _c.has(key):
		return _c[key]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	if hold > 0.0:
		g.add_point(hold, Color(1, 1, 1, 1))
	_c[key] = g
	return g

## fades in, then out (fireflies, motes)
static func pulse_ramp() -> Gradient:
	if _c.has("pulse"):
		return _c["pulse"]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.2, Color(1, 1, 1, 1))
	g.add_point(0.4, Color(1, 1, 1, 0.35))
	g.add_point(0.6, Color(1, 1, 1, 1))
	g.add_point(0.85, Color(1, 1, 1, 0.5))
	_c["pulse"] = g
	return g

static func curve(points: Array) -> Curve:
	var c := Curve.new()
	for p in points:
		c.add_point(Vector2(p[0], p[1]))
	return c
