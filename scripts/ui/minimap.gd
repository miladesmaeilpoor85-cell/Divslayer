extends Control
## The minimap (the HTML #minimap): the region's ground in miniature with its exits (gold), hazards,
## villagers (gold dots), enemies (red; bosses larger), the quest target pulsing, and the hero as an arrow
## facing where he walks. Redrawn ten times a second. Tap it for the full map.

signal opened

var player: Node = null
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

func _gui_input(ev: InputEvent) -> void:
	var tap: bool = (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) \
		or (ev is InputEventScreenTouch and ev.pressed)
	if tap:
		accept_event()
		opened.emit()

func _process(dt: float) -> void:
	_t -= dt
	if _t <= 0.0:
		_t = 0.1
		queue_redraw()

## map -> minimap transform for a region of size `sz` drawn inside `box`
static func fit(sz: Vector2, box: Rect2) -> Array:
	var k: float = min(box.size.x / sz.x, box.size.y / sz.y)
	var o: Vector2 = box.position + (box.size - sz * k) * 0.5
	return [o, k]

func _draw() -> void:
	draw_style_box(UI.box(Color(0.05, 0.035, 0.025, 0.82), Color(0, 0, 0, 0), 0, 8, 0), Rect2(Vector2.ZERO, size))
	if player == null or not is_instance_valid(player) or player.world == null:
		return
	var w: Node = player.world
	draw_region(self, w, Rect2(Vector2(3, 3), size - Vector2(6, 6)), player)
	draw_style_box(UI.box(Color(0, 0, 0, 0), Color(UI.GOLD, 0.75), 2, 8, 0), Rect2(Vector2.ZERO, size))

## shared with the full map: the region `w` drawn into `box` on canvas item `ci`
static func draw_region(ci: CanvasItem, w: Node, box: Rect2, hero: Node) -> void:
	var f := fit(w.size, box)
	var o: Vector2 = f[0]
	var k: float = f[1]
	var g = w.get_node_or_null("Ground")
	if g and g.texture:
		ci.draw_texture_rect(g.texture, Rect2(o, w.size * k), false, Color(0.82, 0.82, 0.82))
	for r in w.wall_rects:
		var rr := Rect2(o + r.position * k, r.size * k)
		if rr.size.x * rr.size.y < box.size.x * box.size.y * 0.5:
			ci.draw_rect(rr, Color(0.12, 0.08, 0.05, 0.28))
	for h in w.hazards:
		var hr: Rect2 = h["rect"]
		var hc := Color(1, 0.45, 0.15, 0.85)
		if h["type"] == "ice":
			hc = Color(0.7, 0.9, 1.0, 0.8)
		elif h["type"] == "poison":
			hc = Color(0.4, 0.85, 0.35, 0.8)
		ci.draw_rect(Rect2(o + hr.position * k, hr.size * k), hc)
	var cp: Dictionary = Game.compass_point(w.key)
	for a in w.get_tree().get_nodes_in_group("exits"):
		if not a.is_inside_tree() or not w.is_ancestor_of(a):
			continue
		var er: Rect2 = a.get_meta("rect")
		var r2 := Rect2(o + er.position * k, er.size * k)
		r2 = r2.grow_individual(max(0.0, (3.0 - r2.size.x) * 0.5), max(0.0, (3.0 - r2.size.y) * 0.5), max(0.0, (3.0 - r2.size.x) * 0.5), max(0.0, (3.0 - r2.size.y) * 0.5))
		var hot: bool = cp.get("exit", false) and str(cp.get("to", "")) == str(a.get_meta("to"))
		ci.draw_rect(r2, Color(1, 0.85, 0.4) if hot else Color(0.96, 0.83, 0.49, 0.85))
	for n in w.get_tree().get_nodes_in_group("npcs"):
		if w.is_ancestor_of(n):
			ci.draw_circle(o + n.global_position * k, 2.6, Color(1, 0.86, 0.45))
	for e in w.get_tree().get_nodes_in_group("enemies"):
		if e.dead or not w.is_ancestor_of(e):
			continue
		var big: bool = e.boss
		var ep: Vector2 = o + e.center() * k
		if big:
			ci.draw_circle(ep, 4.2, Color(0, 0, 0, 0.6))
			ci.draw_circle(ep, 3.4, Color(1, 0.35, 0.25))
		else:
			ci.draw_circle(ep, 1.9, Color(0.95, 0.3, 0.25))
	# the objective in this region: a pulsing ring
	if not cp.is_empty() and not cp.get("exit", false):
		var tp: Vector2 = o + cp["pos"] * k
		var pul := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
		ci.draw_arc(tp, 4.0 + 3.0 * pul, 0, TAU, 20, Color(1, 0.86, 0.45, 0.9 - 0.5 * pul), 1.5, true)
	if hero and is_instance_valid(hero) and hero.world == w:
		var hp: Vector2 = o + (hero.global_position + Vector2(0, -17)) * k
		var a: float = hero.facing_vec().angle()
		var tri := PackedVector2Array([hp + Vector2.from_angle(a) * 5.5, hp + Vector2.from_angle(a + 2.4) * 4.0, hp + Vector2.from_angle(a - 2.4) * 4.0])
		ci.draw_circle(hp, 5.0, Color(0, 0, 0, 0.5))
		ci.draw_colored_polygon(tri, Color(1, 1, 1))
		var ol := tri.duplicate()
		ol.append(tri[0])
		ci.draw_polyline(ol, UI.GOLD, 1.0, true)
