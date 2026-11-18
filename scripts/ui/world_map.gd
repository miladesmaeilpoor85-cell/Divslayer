extends Control
## The world map (pause menu → Map): the regions of the HTML game as illustrated tiles (each one's own
## ground in miniature) joined by the roads between them. Regions you have not set foot in stay veiled
## with a "?", the one you stand in has a gold ring and your face, and the quest's goal pulses (a skull for
## a boss, "!" for Zal). The legend names the region under your finger.

const Portrait = preload("res://scripts/ui/portrait.gd")

## where each region sits on the parchment (0..1, a schematic, not to scale); roads come from the exits
const LAYOUT := {
	"trial": Vector2(0.0, 0.0), "dungeon": Vector2(0.333, 0.0), "sanctum": Vector2(0.667, 0.0), "frostvale": Vector2(1.0, 0.0),
	"village": Vector2(0.0, 0.5), "forest": Vector2(0.333, 0.5), "peaks": Vector2(0.667, 0.5), "emberforge": Vector2(1.0, 0.5),
	"camp": Vector2(0.333, 1.0), "shadowfen": Vector2(0.667, 1.0), "damavand": Vector2(1.0, 1.0),
}

var here := ""
var player: Node = null
var _tex := {}
var picked := ""
signal region_picked(key: String)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(250, 200)       # (v0.27, UX: wider than the screen with the Large interface)

func _process(_dt: float) -> void:
	if is_visible_in_tree():
		queue_redraw()

## tile size: as large as the parchment allows (4 columns, 3 rows, room for the names)
func tile() -> Vector2:
	var w: float = min(size.x / 5.0, (size.y - 30.0) / 3.0 * 1.35)
	return Vector2(w, w / 1.45)

func _pos(k: String) -> Vector2:
	var t := tile()
	var m := Vector2(t.x * 0.5 + 10, t.y * 0.5 + 10)
	var area := size - m * 2.0 - Vector2(0, 16)
	return m + LAYOUT[k] * area

func _ground(k: String) -> Texture2D:
	if not _tex.has(k):
		_tex[k] = load(Game.ART + "Maps/" + k + "_ground.jpg")
	return _tex[k]

## the region a map belongs to on the parchment: a shrine shows as its region, the Wyrm's Hollow as the Sanctum (v0.19)
static func region_of(k: String) -> String:
	if LAYOUT.has(k):
		return k
	if k == "wyrmhollow":
		return "sanctum"
	if k == "zahhakcave":
		return "damavand"
	var sd: Dictionary = Game.shrine_def(k)
	return str(sd.get("parent", k)) if not sd.is_empty() else k

static func visited(k: String) -> bool:
	return Game.state.get("visited", {}).has(k) or k == str(Game.state.get("map", ""))

func _gui_input(ev: InputEvent) -> void:
	var p := Vector2(-1, -1)
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		p = ev.position
	elif ev is InputEventScreenTouch and ev.pressed:
		p = ev.position
	if p.x < 0:
		return
	for k in LAYOUT:
		if Rect2(_pos(k) - tile() * 0.5, tile()).grow(6).has_point(p):
			picked = k
			region_picked.emit(k)
			Sfx.play("ui", -6.0)
			accept_event()
			return

func _draw() -> void:
	draw_style_box(UI.box(Color(0.16, 0.12, 0.085, 0.95), Color(UI.GOLD, 0.4), 1, 10, 0), Rect2(Vector2.ZERO, size))
	# faint parchment grain
	for i in 40:
		var r := Vector2(fmod(i * 97.3, size.x), fmod(i * 53.7, size.y))
		draw_circle(r, 6.0 + fmod(i * 7.0, 10.0), Color(0, 0, 0, 0.04))
	var g := Game.world_graph()
	# roads first
	var drawn := {}
	for k in LAYOUT:
		for e in g.get(k, {}).get("exits", []):
			var to := str(e["to"])
			if not LAYOUT.has(to):
				continue
			var key: String = k + to if k < to else to + k
			if drawn.has(key):
				continue
			drawn[key] = true
			var known: bool = visited(k) or visited(to)
			_road(_pos(k), _pos(to), known)
	var t := Game.quest_target()
	for k in LAYOUT:
		_tile(k, t)

func _road(a: Vector2, b: Vector2, known: bool) -> void:
	var n := int(a.distance_to(b) / 9.0)
	for i in n:
		if i % 2 == 0:
			var p0: Vector2 = a.lerp(b, float(i) / n)
			var p1: Vector2 = a.lerp(b, float(i + 1) / n)
			draw_line(p0, p1, Color(0.85, 0.7, 0.42, 0.75 if known else 0.25), 2.5, true)

func _tile(k: String, t: Dictionary) -> void:
	var c := _pos(k)
	var tl := tile()
	var r := Rect2(c - tl * 0.5, tl)
	var seen := visited(k)
	draw_rect(r.grow(2), Color(0, 0, 0, 0.45))
	var tex := _ground(k)
	if tex:
		draw_texture_rect(tex, r, false, Color(1, 1, 1) if seen else Color(0.28, 0.26, 0.24))
	var border := UI.GOLD_HI if k == here else (Color(UI.GOLD, 0.8) if seen else Color(UI.GOLD_DIM, 0.6))
	if k == picked:
		border = Color(1, 1, 1)
	draw_rect(r, border, false, 2.5 if k == here else 1.5)
	if not seen:
		var f: Font = UI.font_bold
		draw_string(f, c + Vector2(-5, 7), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(UI.CREAM, 0.55))
	# region name under the tile (only for places you have been)
	if seen:
		var nm := Game.map_title(k)
		var fs := 10
		var w := UI.font_bold.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x0: float = clamp(c.x - w * 0.5, 2.0, size.x - w - 2.0)
		draw_string_outline(UI.font_bold, Vector2(x0, r.end.y + 12), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.85))
		draw_string(UI.font_bold, Vector2(x0, r.end.y + 12), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.GOLD_HI if k == here else UI.CREAM)
	# you are here
	if k == here:
		var pul := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
		draw_arc(c, 13.0 + pul * 3.0, 0, TAU, 28, Color(UI.GOLD_HI, 0.9), 2.5, true)
		draw_circle(c, 9.0, Color(0.1, 0.07, 0.05))
		draw_circle(c, 7.0, UI.GOLD_HI)
	# the quest goal
	if not t.is_empty() and str(t["map"]) == k:
		var pc := r.position + Vector2(tl.x - 10, 10)
		var pul2 := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
		draw_circle(pc, 10.0 + pul2 * 2.0, Color(0, 0, 0, 0.6))
		var boss: bool = t["kind"] == "boss"
		draw_circle(pc, 9.0, Color(0.85, 0.25, 0.2) if boss else UI.GOLD)
		var ic: Texture2D = UI.icon("skull" if boss else "info", 48)
		if ic:
			draw_texture_rect(ic, Rect2(pc - Vector2(6, 6), Vector2(12, 12)), false, Color(1, 1, 1))
