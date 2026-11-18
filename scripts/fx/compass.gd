extends Node2D
## The quest compass: a small gold chevron circling the hero that points to where the objective is —
## Zal, the boss to hunt, or the exit that leads towards them (the shortest walk over the
## regions' exits). It hides when the target is on screen or close, and during boss fights.

var world: Node = null
var point := {}
var _t := 0.0
var _a := 0.0

func setup(w: Node, parent: Node) -> void:
	world = w
	name = "Compass"
	parent.add_child(self)

func _process(dt: float) -> void:
	_t -= dt
	if _t <= 0.0:
		_t = 0.3
		point = Game.compass_point(world.key)
	var p = world.get_tree().get_first_node_in_group("player")
	var want := 0.0
	if p != null and p.world == world and not p.dead and not point.is_empty() and Game.fight.is_empty() and int(Game.settings.get("compass", 1)) == 1:
		var c: Vector2 = p.global_position + Vector2(0, -17)
		var to: Vector2 = point["pos"] - c
		var d := to.length()
		var vp := get_viewport()
		var ct := vp.get_canvas_transform()
		var sp: Vector2 = ct * point["pos"]
		var on_screen := Rect2(Vector2(40, 40), vp.get_visible_rect().size - Vector2(80, 80)).has_point(sp)
		if point["exit"]:
			want = 1.0 if d > 80.0 else 0.0
		else:
			want = 1.0 if d > 140.0 and not on_screen else 0.0
		position = c
		rotation = to.angle()
	_a = move_toward(_a, want, dt * 3.0)
	visible = _a > 0.01
	if visible:
		queue_redraw()

func _draw() -> void:
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 220.0)
	var col := Color(1, 0.55, 0.35) if point.get("kind", "") == "boss" else Color(1, 0.86, 0.45)
	var r := 44.0 + 3.0 * sin(Time.get_ticks_msec() / 300.0)
	var tip := Vector2(r + 9.0, 0)
	var pts := PackedVector2Array([tip, Vector2(r - 3.0, -8.0), Vector2(r + 1.0, 0), Vector2(r - 3.0, 8.0)])
	var sh := PackedVector2Array()
	for q in pts:
		sh.append(q + Vector2(1.2, 1.6))
	draw_colored_polygon(sh, Color(0, 0, 0, 0.45 * _a))
	draw_colored_polygon(pts, Color(col, _a * pulse))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0.25, 0.15, 0.05, 0.8 * _a), 1.2, true)
