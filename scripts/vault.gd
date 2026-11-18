extends Node2D
## (v0.19) Sorush's vault in the Crystal Sanctum's north-east corner: five cells of rimeglass (the HTML game's
## sanctum v16objs "icewall" vault0..vault4, never built in the port) around a chest (v16obj "vault").
## Before chapter 2 opens it (Sorush's word, Ch2 step "shards") the rimeglass does not even scratch. Then a heavy blow
## cracks a cell (two break it), a plain blow only chips it (six), fire — a fire spell, a burning blade — melts it at once.
## Reach the chest: the Shard of Memory, gold, a greater potion and an epic accessory (Ch2.open_vault). The broken cells and
## the opened chest are saved (Game.state.c2.vault, vault_open).

const Art = preload("res://scripts/fx/shrine_art.gd")
const HP := 2.0
const HEAVY := 1.0
const PLAIN := 0.34

var world: Node = null
var cells: Array = []        # {id, rect, hp, melt, node, body}
var chest := {}              # {rect, node, open}
var _tip_t := 0.0
var _plain_tip := false

func setup(w: Node) -> void:
	world = w
	name = "Vault"
	var broken: Array = Game.Ch2.st()["vault"]
	for o in Game.map_data(str(w.key)).get("v16objs", []):
		var id := str(o.get("id", ""))
		if o["t"] == "icewall" and id.begins_with("vault"):
			var r := Rect2(float(o["x"]), float(o["y"]), float(o.get("w", 40)), float(o.get("h", 40)))
			var c := {"id": id, "rect": r, "hp": HP, "melt": 0.0, "node": null, "body": null}
			if broken.has(id):
				c["hp"] = 0.0
				c["melt"] = 1.0
			else:
				c["body"] = _solid(r)
			var n := Node2D.new()
			n.name = "Rimeglass_" + id
			n.position = Vector2(r.position.x + r.size.x * 0.5, r.end.y)
			n.draw.connect(_draw_cell.bind(n, c))
			world.ysort.add_child(n)
			c["node"] = n
			cells.append(c)
		elif o["t"] == "chest" and id == "vault":
			var cr := Rect2(float(o["x"]), float(o["y"]), float(o.get("w", 30)), float(o.get("h", 24)))
			var cn := Node2D.new()
			cn.name = "VaultChest"
			cn.position = Vector2(cr.position.x + cr.size.x * 0.5, cr.end.y)
			var tex = load(Game.ART + "Items/chest.png")
			if tex:
				var spr := Sprite2D.new()
				spr.texture = tex
				var sc: float = 34.0 / float(tex.get_width())
				spr.scale = Vector2(sc, sc)
				spr.centered = false
				spr.position = Vector2(-tex.get_width() * sc * 0.5, -tex.get_height() * sc + 2)
				cn.add_child(spr)
			world.ysort.add_child(cn)
			chest = {"rect": cr, "node": cn, "open": bool(Game.Ch2.st()["vault_open"])}
			_chest_look()
	if world.lighting and not chest.is_empty():
		world.lighting.map_lights.append({"pos": chest["rect"].get_center(), "r": 90.0, "i": 0.6, "c": Color(0.7, 0.85, 1.0), "fire": false, "seed": 0.0})

func _solid(r: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.position + r.size * 0.5
	body.add_child(cs)
	world.add_child(body)
	world.wall_rects.append(r)
	return body

func intact() -> Array:
	return cells.filter(func(c): return float(c["hp"]) > 0.0)

func is_open() -> bool:
	return bool(chest.get("open", false))

## a blow from the hero's swing
func strike(box: Rect2, _fv: Vector2, heavy: bool) -> void:
	for c in intact():
		if not c["rect"].grow(6.0).intersects(box):
			continue
		if not Game.Ch2.vault_breakable():
			if _tip_t <= 0.0:
				_tip_t = 2.0
				world.float_text(c["rect"].get_center() + Vector2(0, -30), Game.Ch2.line("t_vault_shut"), Color(0.75, 0.9, 1.0))
				Sfx.play("clank", -6.0)
			return
		hit(c, HEAVY if heavy else PLAIN)
		if not heavy and not _plain_tip:
			_plain_tip = true
			world.tip("rimeglass", Game.Ch2.L["t_vault_heavy"][0], Game.Ch2.L["t_vault_heavy"][1])

func hit(c: Dictionary, amount: float) -> void:
	c["hp"] = float(c["hp"]) - amount
	Sfx.play("clank", -3.0, 0.12)
	Sfx.play("ice", -8.0)
	if world.fx:
		world.fx.sparks(c["rect"].get_center(), 6, Color(0.85, 0.95, 1.0))
	if float(c["hp"]) <= 0.0:
		_break(c)
	else:
		if amount >= HEAVY:
			world.float_text(c["rect"].get_center() + Vector2(0, -30), Game.Ch2.line("t_vault_crack"), Color(0.8, 0.95, 1.0))
		c["node"].queue_redraw()

func _break(c: Dictionary) -> void:
	if float(c["melt"]) > 0.0:
		return
	c["hp"] = 0.0
	c["melt"] = 0.01
	if c["body"] and is_instance_valid(c["body"]):
		c["body"].queue_free()
		c["body"] = null
	world.wall_rects.erase(c["rect"])
	var broken: Array = Game.Ch2.st()["vault"]
	if not broken.has(c["id"]):
		broken.append(c["id"])
	Game.save_game()
	Sfx.play("ice")
	Sfx.play("trap", -6.0)
	world.shake(3.0)
	if world.fx:
		world.fx.burst(c["rect"].get_center(), Color(0.8, 0.94, 1.0), 16, 140.0)

## a spell's fire at p within r
func element(p: Vector2, r: float, status: String) -> void:
	if status != "burn" or not Game.Ch2.vault_breakable():
		return
	for c in intact():
		if c["rect"].get_center().distance_to(p) <= r + 20.0:
			_break(c)

## a spell shot at p: stops at the rimeglass (fire melts it)
func shot_at(p: Vector2, status: String) -> bool:
	for c in intact():
		if c["rect"].has_point(p):
			if status == "burn" and Game.Ch2.vault_breakable():
				_break(c)
			return true
	return false

func _process(dt: float) -> void:
	_tip_t = max(0.0, _tip_t - dt)
	for c in cells:
		if float(c["melt"]) > 0.0 and float(c["melt"]) < 1.0:
			c["melt"] = min(1.0, float(c["melt"]) + dt * 1.6)
			c["node"].queue_redraw()
	if chest.is_empty() or is_open():
		return
	var p = get_tree().get_first_node_in_group("player")
	if p == null or p.dead or p.world != world:
		return
	if p.global_position.distance_to(chest["rect"].get_center() + Vector2(0, 8)) < 34.0:
		open_chest()

func open_chest() -> void:
	if is_open():
		return
	chest["open"] = true
	for line in Game.Ch2.open_vault():
		world.notice.emit(line, "gem")
	Sfx.play("chest")
	Sfx.play("found")
	if world.fx:
		var c: Vector2 = chest["rect"].get_center()
		world.fx.emit("shine", c, 24, Color(0.75, 0.9, 1.0), Vector2.UP, 60.0, 150.0)
		world.fx.flash_light(c, 200.0, 1.0, Color(0.7, 0.85, 1.0), 0.8)
	_chest_look()
	Game.stats_changed.emit()

func _chest_look() -> void:
	if chest.is_empty():
		return
	chest["node"].modulate = Color(0.62, 0.66, 0.74) if is_open() else Color(1, 1, 1)

func _draw_cell(n: Node2D, c: Dictionary) -> void:
	var k := 1.0 - float(c["melt"])
	Art.icewall(n, k)
	if k >= 1.0 and float(c["hp"]) < HP:
		# cracks, more of them as the cell weakens
		var dmg := 1.0 - float(c["hp"]) / HP
		var col := Color(0.12, 0.26, 0.36, 0.85)
		n.draw_line(Vector2(-14, -30), Vector2(-2, -18), col, 2.0)
		n.draw_line(Vector2(-2, -18), Vector2(8, -26), col, 2.0)
		if dmg > 0.4:
			n.draw_line(Vector2(-2, -18), Vector2(2, -6), col, 2.0)
			n.draw_line(Vector2(6, -34), Vector2(14, -16), col, 1.5)
		if dmg > 0.75:
			n.draw_line(Vector2(-16, -12), Vector2(-6, -8), col, 1.5)
			n.draw_line(Vector2(10, -10), Vector2(16, -4), col, 1.5)
