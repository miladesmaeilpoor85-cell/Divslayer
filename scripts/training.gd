extends Node2D
## (v0.24) Rostam's training yard in Zabol (the open grass north-east of the fountain, on the way to Kavian's forge — where the
## camera keeps the hero in the middle of the screen, clear of the buttons): a straw-wrapped post to strike, and Rostam's
## marked blows for the roll and the shield (Game.Tut keeps the steps). The marked blows are the bosses' own telegraphs
## (world.bossfx), so the hero learns the very thing the bosses will do to him — but here they never hurt.

const POST := Vector2(530, 236)      # feet of the post
const ROLL_R := 46.0
const MARK_SEC := 1.15
const PAUSE := 1.6
const FIRST_MARK := 3.0      # the first blow of a drill waits for its words to be read (v0.24, playtest)

var world: Node = null
var post: Node2D = null
var rect := Rect2()
var clock := 0.0
var _next := 0.0
var _live := false               # a marked blow is on the ground
var _shake := 0.0
var _far := true                 # the hero is not in the yard (true at first: arriving in Zabol is not "walking off")
var _rolls0 := 0                 # the hero's rolls when the blow was marked

func setup(w: Node) -> void:
	world = w
	name = "Training"
	post = Node2D.new()
	post.name = "TrainingPost"
	post.position = POST
	post.draw.connect(_draw_post)
	world.ysort.add_child(post)
	rect = Rect2(POST - Vector2(16, 52), Vector2(32, 54))
	# (v0.26, playtest: a roll with no direction beside the post ran into it and earned an "Again!") the post has no body:
	# the hero strikes it, and rolls past it
	Game.Tut.away = false

func hero() -> Node:
	var p = get_tree().get_first_node_in_group("player")
	return p if p != null and not p.dead and p.world == world else null

func rostam() -> Node:
	for n in get_tree().get_nodes_in_group("npcs"):
		if str(n.get_meta("id", "")) == "rostam":
			return n
	return null

## a blow from the hero's swing
func strike(box: Rect2, _fv: Vector2, heavy: bool) -> void:
	if not rect.grow(8.0).intersects(box):
		return
	_shake = 0.25
	Sfx.play("hit", -6.0, 0.1)
	if world.fx:
		world.fx.emit("debris", POST + Vector2(0, -30), 6, Color(0.85, 0.75, 0.45), Vector2.UP, 80.0, 90.0)
	var T = Game.Tut
	match T.step():
		"strike":
			T.st()["hits"] = int(T.st().get("hits", 0)) + 1
			var n := int(T.st()["hits"])
			world.float_text(POST + Vector2(0, -64), T.fmt("hit_post", [mini(n, T.STRIKES), T.STRIKES]), Color(1, 0.9, 0.6))
			if n >= T.STRIKES:
				T.set_step("heavy")
				_say(T.line("good") + " " + T.line("t_heavy"))
			else:
				Game.stats_changed.emit()
		"heavy":
			if heavy:
				T.st()["rolls"] = 0
				T.set_step("roll")
				_next = FIRST_MARK
				_say(T.line("good") + " " + T.line("t_roll"))

## (v0.24) the last drill: any spell cast in the yard (the caster's cast_done)
func on_cast(_id: String) -> void:
	if Game.Tut.step() != "spell":
		return
	var p := hero()
	if p == null or p.global_position.distance_to(POST) > 320.0:
		return
	world.float_text(p.global_position + Vector2(0, -60), Game.Tut.line("spelled"), Color(1, 0.85, 0.5), true)
	Game.Tut.set_step("sig")
	_say(Game.Tut.line("t_sig_" + Game.cls))

## (v0.26) the calling's own move, used in the yard
func on_sig() -> void:
	if Game.Tut.step() != "sig":
		return
	var p := hero()
	if p == null or p.global_position.distance_to(POST) > 320.0:
		return
	_complete()

func _say(t: String) -> void:
	# (v0.26, playtest: the fifth drill's words still stood on the bar while the sixth was under way) his new word
	# replaces the old one at once
	for n in get_tree().get_nodes_in_group("notify"):
		n.clear()
	world.notice.emit(t, "sword")
	Sfx.play("quest", -6.0)

func _process(dt: float) -> void:
	clock += dt
	if _shake > 0.0:
		_shake = max(0.0, _shake - dt)
	if post:
		post.queue_redraw()
	var T = Game.Tut
	var p := hero()
	if p == null or get_tree().paused:
		return
	# the drill waits for the hero to be in the yard (v0.26: and says so, once, when he walks off; back in the yard,
	# Rostam repeats what he asked for)
	var d: float = p.global_position.distance_to(POST)
	var far: bool = d > (250.0 if _far else 300.0)
	if far != _far:
		_far = far
		T.away = far
		if T.active():
			if far:
				_say(T.line("come_back"))
			else:
				_next = FIRST_MARK
				_say(T.line("t_sig_" + Game.cls) if T.step() == "sig" else T.line("t_" + T.step()))
			Game.stats_changed.emit()
	if far or not T.step() in ["roll", "block"] or _live:
		return
	_next -= dt
	if _next > 0.0:
		return
	_mark(p, T.step())

## Rostam marks a blow on the ground where the hero stands
func _mark(p: Node, kind: String) -> void:
	_live = true
	_rolls0 = int(p.rolls_n)
	var at: Vector2 = p.global_position + Vector2(0, -6)
	var col := Color8(255, 150, 60) if kind == "roll" else Color8(120, 170, 255)
	world.bossfx.circle(at, ROLL_R, MARK_SEC if kind == "roll" else MARK_SEC + 0.25, col, _land.bind(kind), null)
	var r := rostam()
	if r:
		var spr = r.get_child(0)
		if spr is AnimatedSprite2D:
			spr.play("attack_down")
	Sfx.play("swing", -4.0)

func _land(t: Dictionary, kind: String) -> void:
	_live = false
	_next = PAUSE
	var p := hero()
	if p == null:
		return
	var T = Game.Tut
	var r := rostam()
	if r:
		var spr = r.get_child(0)
		if spr is AnimatedSprite2D:
			spr.play("idle_down")
	world.burst(t["pos"], Color(1, 0.8, 0.5) if kind == "roll" else Color(0.7, 0.85, 1.0), 12, 120.0)
	Sfx.play("heavy", -6.0)
	var inside: bool = world.bossfx.in_circle(t)
	match kind:
		"roll":
			# (v0.26, playtest: walking out of the ring counted, so the drill could pass without the button it teaches)
			var rolled: bool = p.dodge_iframes > 0.0 or int(p.rolls_n) > _rolls0
			if not inside and not rolled:
				world.float_text(p.global_position + Vector2(0, -56), T.line("walked"), Color(1, 0.85, 0.6), true)
				_next = 0.8
			elif not inside or p.dodge_iframes > 0.0:
				T.st()["rolls"] = int(T.st().get("rolls", 0)) + 1
				var n := int(T.st()["rolls"])
				world.float_text(p.global_position + Vector2(0, -56), T.fmt("rolled", [mini(n, T.ROLLS), T.ROLLS]), Color(0.75, 1.0, 0.8))
				Sfx.play("dodge", 0.0)
				if n >= T.ROLLS:
					T.set_step("block")
					_next = FIRST_MARK
					# Rostam tells of the perfect block himself when it is done; the one-time tip would hide behind his talk
					var tips: Dictionary = Game.v18().get("tips", {})
					tips["block"] = true
					Game.v18()["tips"] = tips
					_say(T.line("good") + " " + T.line("t_block"))
				else:
					Game.stats_changed.emit()
			else:
				_miss(p)
		"block":
			if inside and p.blocking:
				world.float_text(p.global_position + Vector2(0, -56), T.line("blocked"), Color(0.75, 0.9, 1.0))
				Sfx.play("shield", 0.0)
				Sfx.play("clank", -2.0)
				T.set_step("spell")
				_say(T.line("good") + " " + T.line("t_spell"))
			elif not inside:
				_next = 0.6           # he moved off: Rostam marks it again where he stands
			else:
				_miss(p)

## a blow that would have landed: no harm in the yard, only a nudge and "Again!"
func _miss(p: Node) -> void:
	world.float_text(p.global_position + Vector2(0, -56), Game.Tut.line("again"), Color(1, 0.7, 0.55), true)
	p.knock(Vector2(0, 14))
	world.shake(3.0)

func _complete() -> void:
	var T = Game.Tut
	var gift: String = T.finish()
	world.lore_sheet.emit(T.line("name"), [T.line("r_done1"), T.line("r_parry"), T.done_line()], "hero:warrior_endgame:npc_rostam")
	world.notice.emit(gift, "coins")
	Sfx.play("quest", -2.0)
	Sfx.play("coin")

## the post: a stake with a crossbar and a straw-wrapped head, a target painted on the chest; it rocks when struck
func _draw_post() -> void:
	var lean := sin(clock * 60.0) * 6.0 * _shake
	post.draw_set_transform(Vector2.ZERO, deg_to_rad(lean), Vector2.ONE)
	var dark := Color(0.2, 0.13, 0.07)
	var wood := Color(0.55, 0.38, 0.2)
	var straw := Color(0.86, 0.74, 0.42)
	post.draw_rect(Rect2(-5, -50, 10, 50), dark)
	post.draw_rect(Rect2(-3.5, -50, 7, 49), wood)
	post.draw_rect(Rect2(-17, -38, 34, 7), dark)
	post.draw_rect(Rect2(-16, -37, 32, 5), wood)
	post.draw_circle(Vector2(0, -26), 11.0, dark)
	post.draw_circle(Vector2(0, -26), 9.5, straw)
	post.draw_circle(Vector2(0, -26), 5.5, Color(0.75, 0.25, 0.18))
	post.draw_circle(Vector2(0, -26), 2.5, straw)
	post.draw_circle(Vector2(0, -52), 8.0, dark)
	post.draw_circle(Vector2(0, -52), 6.5, straw)
	for i in 3:
		post.draw_line(Vector2(-9, -20 + i * 5), Vector2(9, -22 + i * 5), Color(0.6, 0.5, 0.25, 0.8), 1.0)
	post.draw_set_transform(Vector2.ZERO)
	# while a strike drill waits: a soft ring round the post
	if Game.Tut.step() in ["strike", "heavy"]:
		var k := 0.5 + 0.5 * sin(clock * 4.0)
		post.draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.45))
		post.draw_arc(Vector2.ZERO, 26.0 + 3.0 * k, 0, TAU, 36, Color(1, 0.85, 0.4, 0.5 + 0.3 * k), 2.5, true)
		post.draw_set_transform(Vector2.ZERO)
