extends Node
## The hero's magic (v0.6), a child of the player: mana and its regeneration, the two spell buttons,
## cooldowns, Battle Roar, mana potions (drunk by hand or automatically when a spell needs one), and the
## four class ultimates: Whirlwind Strike, Arcane Tempest, Shadow Dance, Farr Smite.

signal cast_done(id: String)

const Skills = preload("res://scripts/skills.gd")

var player: Node = null
var cds := {}                 # spell -> seconds left
var roar_t := 0.0             # Battle Roar: attack x1.4 while > 0
var spin_t := 0.0             # Whirlwind Strike: seconds of spinning left
var spin_tick := 0.0
var spin_ang := 0.0
var dance: Dictionary = {}    # Shadow Dance in progress: {target, left, t}
var casts := 0                # counters for tests and the bot
var spell_hits := 0
var _nomana_t := 0.0

func setup(p: Node) -> void:
	player = p
	name = "Caster"

func world() -> Node:
	return player.world if player else null

func spells() -> Node:
	var w = world()
	return w.spells if w and w.get("spells") else null

## an ultimate is running (the meter does not fill meanwhile; attacks wait for the dance)
func ult_active() -> bool:
	return spin_t > 0.0 or not dance.is_empty()

func busy() -> bool:
	return not dance.is_empty()

# ---------------------------------------------------------------- every frame
func _physics_process(dt: float) -> void:
	if player == null or player.world == null:
		return
	_nomana_t = max(0.0, _nomana_t - dt)
	if not player.dead:
		Game.mp = min(Game.max_mp(), Game.mp + Game.mp_regen() * dt)
	for k in cds.keys():
		cds[k] = float(cds[k]) - dt
		if float(cds[k]) <= 0.0:
			cds.erase(k)
	if roar_t > 0.0:
		roar_t = max(0.0, roar_t - dt)
		if roar_t == 0.0:
			Game.stats_changed.emit()
	if spin_t > 0.0:
		_spin(dt)
	if not dance.is_empty():
		_dance(dt)

func cd_left(id: String) -> float:
	return float(cds.get(id, 0.0))

## damage multiplier from buffs and talents (Battle Roar, Second Wind)
var scroll_mul := 1.0           # (v0.11) a Frost Lance scroll hits harder than the spell

## cast a spell without mana, cooldown or knowing it: what a scroll does
func cast_free(id: String, mul := 1.0) -> bool:
	scroll_mul = mul
	var ok = _do(id, Skills.spell(id))
	scroll_mul = 1.0
	return ok

func dmg_mul() -> float:
	var m := scroll_mul
	if roar_t > 0.0:
		m *= float(Skills.SPELL["roar"]["mul"])
	if Game.talent("second_wind") > 0 and Game.hp < Game.max_hp() * 0.25:
		m *= 1.5
	return m * Game.Ch3.banner_mul()      # (v0.23) the Derafsh-e Kaviani, raised on Damavand

# ---------------------------------------------------------------- casting
## why a spell can't be cast now ("" = it can)
func block(id: String) -> String:
	if player == null or player.dead or player.world == null:
		return "dead"
	if not Skills.known(id):
		return "locked"
	if cd_left(id) > 0.0:
		return "cooldown"
	if busy():
		return "busy"
	if Game.mp < Skills.cost(id) and int(Game.state.get("mana_potions", 0)) <= 0:
		return "mana"
	return ""

func cast_slot(i: int) -> bool:
	var s: Array = Game.slots()
	if i < 0 or i >= s.size():
		return false
	return cast(str(s[i]))

func cast(id: String) -> bool:
	var why := block(id)
	if why != "":
		if why == "mana" and _nomana_t <= 0.0:
			_nomana_t = 0.8
			player.world.float_text(player.global_position + Vector2(0, -46), Game.t("Not enough mana!", "مانا کافی نیست!"), Color(0.55, 0.7, 1.0))
			Sfx.play("error", -6.0)
		elif why == "locked" and _nomana_t <= 0.0:
			_nomana_t = 0.8
			Sfx.play("error", -8.0)
		return false
	var c := Skills.cost(id)
	if Game.mp < c:
		drink_mana(true)
	if Game.mp < c:
		return false
	var d := Skills.spell(id)
	if not _do(id, d):
		return false
	Game.mp -= c
	cds[id] = Skills.cooldown(id) * (0.9 if Game.cls == "mage" else 1.0)
	casts += 1
	Game.stats_changed.emit()
	cast_done.emit(id)
	return true

func _do(id: String, d: Dictionary) -> bool:
	var w = world()
	var sp = spells()
	var c: Vector2 = player.global_position + Vector2(0, -17)
	var col: Color = d.get("col", Color(1, 1, 1))
	var dmg: float = Game.atk() * dmg_mul() * Skills.power(id)
	match str(d.get("kind", "")):
		"shot":
			if sp == null:
				return false
			var dir := aim_dir(float(d.get("range", 400.0)) * 0.8)
			player.facing = player._dir_name(dir)
			sp.shoot(id, c + dir * 14.0, dir, d, dmg)
			Sfx.play("ice" if id == "icelance" else "bolt", -4.0)
			if w.fx:
				w.fx.emit("shine", c + dir * 14.0, 6, col, dir, 40.0, 90.0)
		"fan":
			if sp == null:
				return false
			var dir2 := aim_dir(float(d.get("range", 380.0)) * 0.8)
			player.facing = player._dir_name(dir2)
			var n := int(d.get("n", 7))
			var spread := float(d.get("spread", 0.6))
			for i in n:
				var a := -spread + 2.0 * spread * float(i) / float(maxi(1, n - 1))
				sp.shoot(id, c + dir2 * 12.0, dir2.rotated(a), d, dmg)
			Sfx.play("nova", -6.0)
			Sfx.play("bolt", -6.0)
			w.shake(3.0)
		"nova":
			var r := float(d.get("r", 80.0))
			aoe(c, r, dmg, str(d.get("status", "")), float(d.get("sec", 0.0)), col)
			if w.get("shrine"):
				w.shrine.element(c, r, str(d.get("status", "")))
			if w.get("vault"):
				w.vault.element(c, r, str(d.get("status", "")))
			if w.get("altars"):
				w.altars.element(c, r, str(d.get("status", "")))
			if sp:
				sp.blast(player.global_position + Vector2(0, -6), r, col, 0.45 if id == "quake" else 0.4)
			if w.fx:
				w.fx.ring(c, col, r, 0.42)
				w.fx.ring(c, Color(1, 1, 1, 0.8), r * 0.55, 0.3)
				if id == "quake":
					w.fx.dust(player.global_position, 14, Vector2.ZERO, Color(0.6, 0.52, 0.4, 0.6))
					w.fx.emit("debris", player.global_position, 12, Color(0.55, 0.45, 0.35), Vector2.UP, 70.0, 180.0)
				else:
					w.fx.emit("ember", c, 18, col, Vector2.ZERO, 180.0, 160.0)
					w.fx.emit("shine", c, 12, col, Vector2.ZERO, 180.0, 200.0)
				w.fx.flash_light(c, r * 2.2, 1.0, col, 0.4)
			w.shake(6.0 if id == "quake" else 4.0)
			Sfx.play("nova", -3.0 if id == "quake" else -5.0)
			if id == "quake":
				Sfx.play("trap", -4.0)
			Game.vibrate(30, 0.7)
		"chain":
			var first := nearest(c, float(d.get("reach", 260.0)))
			if first == null:
				_no_target()
				return false
			var pts := [c]
			var seen := {}
			var cur: Node = first
			var k := dmg
			for i in int(d.get("jumps", 4)):
				if cur == null:
					break
				seen[cur.get_instance_id()] = true
				var at: Vector2 = cur.center()
				pts.append(at)
				hit(cur, k, (at - pts[pts.size() - 2]).normalized())
				k *= float(d.get("falloff", 0.7))
				cur = nearest(at, float(d.get("jump", 150.0)), seen)
			if sp:
				sp.lightning(pts, col)
			Sfx.play("bolt", -2.0, 0.2)
			Sfx.play("crit", -8.0)
		"heal":
			var heal: float = Game.max_hp() * float(d.get("heal", 0.3))
			Game.hp = min(Game.max_hp(), Game.hp + heal)
			w.float_text(player.global_position + Vector2(0, -40), "+%d" % int(heal), Color(0.6, 1, 0.62))
			Sfx.play("potion", -2.0)
			if w.fx:
				w.fx.emit("shine", player.global_position, 18, col, Vector2.UP, 30.0, 110.0)
				w.fx.ring(player.global_position + Vector2(0, -6), col, 22.0, 0.5)
				w.fx.flash_light(c, 160.0, 0.9, col, 0.6)
		"blink":
			var dir3: Vector2 = player.joy if player.joy.length() > 0.12 else Input.get_vector("move_left", "move_right", "move_up", "move_down")
			if dir3.length() < 0.1:
				dir3 = player.facing_vec()
			dir3 = dir3.normalized()
			var start: Vector2 = player.global_position
			if w.fx:
				w.fx.ghost(player.anim, Color(0.7, 0.85, 1.0, 0.6), 0.4)
			var left := float(d.get("dist", 170.0))
			while left > 0.0:
				var step: float = min(8.0, left)
				if player.test_move(player.global_transform, dir3 * step):
					break
				player.global_position += dir3 * step
				left -= step
			player.global_position = player.global_position.clamp(Vector2(13, 34), w.size - Vector2(13, 0))
			player.invuln = max(player.invuln, 0.3)
			player.facing = player._dir_name(dir3)
			Sfx.play("tp", -4.0)
			if w.fx:
				w.fx.emit("shine", start + Vector2(0, -17), 10, col, Vector2.ZERO, 180.0, 90.0)
				w.fx.emit("shine", player.global_position + Vector2(0, -17), 14, col, Vector2.ZERO, 180.0, 120.0)
				w.fx.ring(player.global_position + Vector2(0, -10), col, 16.0, 0.3)
		"drain":
			var e := nearest(c, float(d.get("reach", 170.0)))
			if e == null:
				_no_target()
				return false
			var before: float = e.hp
			hit(e, dmg, (e.center() - c).normalized(), "", 0.0)
			var dealt: float = max(0.0, before - e.hp) if is_instance_valid(e) else dmg
			var heal2: float = max(1.0, dealt * 0.5)
			Game.hp = min(Game.max_hp(), Game.hp + heal2)
			w.float_text(player.global_position + Vector2(0, -40), "+%d" % int(heal2), Color(0.75, 0.55, 1.0))
			if sp:
				sp.tether(c, e.center() if is_instance_valid(e) else c, col)
			Sfx.play("poison", -3.0)
			Sfx.play("whisper", -6.0)
		"buff":
			roar_t = float(d.get("sec", 8.0))
			w.float_text(player.global_position + Vector2(0, -46), Game.t("+40% attack", "۴۰٪ حملهٔ بیشتر"), col, true)
			Sfx.play("roar", -4.0)
			w.shake(5.0)
			if w.fx:
				w.fx.ring(c, col, 30.0, 0.5)
				w.fx.ring(c, Color(1, 0.85, 0.5), 50.0, 0.6)
				w.fx.emit("ember", c, 16, col, Vector2.UP, 60.0, 120.0)
			Game.stats_changed.emit()
		_:
			return false
	return true

func _no_target() -> void:
	if _nomana_t <= 0.0:
		_nomana_t = 0.8
		player.world.float_text(player.global_position + Vector2(0, -46), Game.t("No target", "هدفی نیست"), Color(0.8, 0.8, 0.85))
		Sfx.play("error", -8.0)

## mana potion: +10 MP and a fifth of the pool
func drink_mana(auto := false) -> bool:
	if player.dead or int(Game.state.get("mana_potions", 0)) <= 0 or Game.mp >= Game.max_mp():
		return false
	Game.state["mana_potions"] = int(Game.state["mana_potions"]) - 1
	var add: float = 10.0 + floorf(Game.max_mp() * 0.2)
	Game.mp = min(Game.max_mp(), Game.mp + add)
	var w = world()
	w.float_text(player.global_position + Vector2(0, -40 if not auto else -54), "+%d %s" % [int(add), Game.t("MP", "مانا")], Color(0.5, 0.7, 1.0))
	Sfx.play("potion", -4.0)
	if w.fx:
		w.fx.emit("shine", player.global_position + Vector2(0, -14), 12, Color(0.5, 0.7, 1.0), Vector2.UP, 50.0, 90.0)
	Game.stats_changed.emit()
	return true

# ---------------------------------------------------------------- damage
## one foe hit by magic: a crit roll, the status, a little meter
func hit(e: Node, dmg: float, dir: Vector2, status := "", sec := 0.0) -> void:
	if not is_instance_valid(e) or e.dead or not e.targetable():
		return
	var crit := randf() < Game.crit_chance()
	e.hurt(dmg * (2.0 if crit else 1.0), crit, dir * 0.8, false)
	if status != "" and is_instance_valid(e) and not e.dead:
		e.apply_status(status, sec, 1.0)
	spell_hits += 1
	if not ult_active():
		Game.add_ult(1.5)

## everything within r of p
func aoe(p: Vector2, r: float, dmg: float, status := "", sec := 0.0, _col := Color.WHITE) -> int:
	var n := 0
	for e in player.get_tree().get_nodes_in_group("enemies"):
		if e.dead or not e.targetable():
			continue
		var d: float = p.distance_to(e.center()) - max(e.box.x, e.box.y) * 0.4
		if d <= r:
			var dir: Vector2 = (e.center() - p).normalized() if e.center() != p else Vector2.DOWN
			hit(e, dmg, dir * 1.5, status, sec)
			n += 1
	return n

## nearest targetable foe whose edge is within reach of p
func nearest(p: Vector2, reach: float, skip := {}) -> Node:
	var best: Node = null
	var bd := reach
	for e in player.get_tree().get_nodes_in_group("enemies"):
		if e.dead or not e.targetable() or skip.has(e.get_instance_id()):
			continue
		var d: float = p.distance_to(e.center()) - max(e.box.x, e.box.y) * 0.5
		if d < bd:
			bd = d
			best = e
	return best

## where a shot goes: at the nearest foe in range (phone-friendly aim), else where the hero is moving or facing
func aim_dir(reach: float) -> Vector2:
	var c: Vector2 = player.global_position + Vector2(0, -17)
	var e := nearest(c, reach)
	if e:
		return (e.center() - c).normalized()
	if player.joy.length() > 0.12:
		return player.joy.normalized()
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v.length() > 0.1:
		return v.normalized()
	return player.facing_vec()

# ---------------------------------------------------------------- ultimates
func ult_ready() -> bool:
	return Game.ult() >= 100.0 and not ult_active() and player != null and not player.dead

func ultimate() -> bool:
	if not ult_ready() or player.world == null:
		return false
	var w = world()
	var u := Skills.ult()
	var c: Vector2 = player.global_position + Vector2(0, -17)
	var dmg: float = Game.atk() * dmg_mul() * Game.ult_mul()
	match Game.cls:
		"warrior":
			if w.fx:
				w.fx.ring(c, Color(0.78, 0.53, 0.28), 64.0, 0.42)
				w.fx.dust(player.global_position, 12, Vector2.ZERO, Color(0.58, 0.46, 0.34, 0.62))
				w.fx.sparks(c, 8, Color(1.0, 0.72, 0.38))
			spin_t = 3.0
			spin_tick = 0.0
		"mage":
			_tempest(dmg * Skills.MAGE_SPELL * 2.0)
		"rogue":
			var tgt := nearest(c, 320.0)
			if tgt == null:
				_no_target()
				return false
			dance = {"target": tgt, "left": 5, "t": 0.0}
			player.invuln = max(player.invuln, 1.4)
		"paladin":
			var r := 170.0
			if spells():
				spells().pillar(player.global_position, u["col"], r)
				spells().blast(player.global_position, r, u["col"], 0.6)
			aoe(c, r, dmg * Game.melee_mul() * 2.5, "stun", 1.5)
			var heal: float = Game.max_hp() * 0.3
			Game.hp = min(Game.max_hp(), Game.hp + heal)
			player.clear_statuses()
			w.float_text(player.global_position + Vector2(0, -40), "+%d" % int(heal), Color(1, 0.92, 0.6))
			if w.fx:
				w.fx.ring(c, u["col"], r, 0.6)
				w.fx.ring(c, Color(1, 1, 1), r * 0.5, 0.45)
				w.fx.ring(c, Color(1.0, 0.94, 0.68), r * 0.78, 0.52)
				w.fx.emit("shine", player.global_position, 30, u["col"], Vector2.UP, 25.0, 260.0, 1.2)
				w.fx.sparks(c, 12, Color(1.0, 0.94, 0.68), Vector2.UP)
				w.fx.flash_light(c, 340.0, 1.0, u["col"], 0.9)
			Sfx.play("levelup", -4.0)
			Sfx.play("nova", -4.0)
	Game.state["ult"] = 0.0
	Game.Ach.add("ults")
	w.float_text(player.global_position + Vector2(0, -60), Game.t(u["shout"][0], u["shout"][1]), u["col"], true)
	w.shake(8.0)
	Game.vibrate(80, 1.0)
	Sfx.play("phase", -6.0)
	Game.stats_changed.emit()
	return true

## Whirlwind Strike: a hit on everything within reach every quarter second for 3 s
func _spin(dt: float) -> void:
	spin_t = max(0.0, spin_t - dt)
	spin_ang += dt * 22.0
	spin_tick -= dt
	var w = world()
	if spin_tick <= 0.0:
		spin_tick = 0.25
		var c: Vector2 = player.global_position + Vector2(0, -17)
		var dmg: float = Game.atk() * dmg_mul() * Game.ult_mul() * Game.melee_mul() * 0.9
		for e in player.get_tree().get_nodes_in_group("enemies"):
			if e.dead or not e.targetable():
				continue
			if c.distance_to(e.center()) - max(e.box.x, e.box.y) * 0.5 <= 64.0:
				var crit := randf() < Game.crit_chance()
				# a light shove: foes stay in the storm instead of being flung out of it
				e.hurt(dmg * (2.0 if crit else 1.0), crit, (e.center() - c).normalized() * 0.35, false)
				player._procs(e)
		Sfx.play("swing" if int(spin_t * 4.0) % 2 == 0 else "swing2", -3.0)
		if w.fx:
			w.fx.swing(player, Vector2.from_angle(spin_ang), 52.0, true, int(Game.state.get("weapon", 1)))
			w.fx.dust(player.global_position, 4, Vector2.ZERO)
	if spin_t == 0.0:
		player.body.rotation = 0.0

## Arcane Tempest: meteors on every foe in view (three on a boss), or around you when no one is there
func _tempest(dmg: float) -> void:
	var sp = spells()
	if sp == null:
		return
	var ritual_origin: Vector2 = player.global_position + Vector2(0, -17)
	var w = world()
	if w.fx:
		var lapis := Color(0.30, 0.84, 0.96)
		w.fx.ring(ritual_origin, lapis, 58.0, 0.52)
		w.fx.ring(ritual_origin, Color(0.92, 0.78, 0.42), 36.0, 0.38)
		w.fx.emit("shine", ritual_origin, 14, lapis, Vector2.UP, 42.0, 132.0, 0.9)
		w.fx.flash_light(ritual_origin, 190.0, 0.58, lapis, 0.52)
	# what the camera shows: the view around the hero, held inside the map like the camera itself
	var sz: Vector2 = player.get_viewport_rect().size / (player.cam.zoom if player.cam else Vector2.ONE)
	var half: Vector2 = sz * 0.5
	var cen: Vector2 = player.global_position + Vector2(0, -17)
	cen.x = clamp(cen.x, min(half.x, w.size.x * 0.5), max(w.size.x - half.x, w.size.x * 0.5))
	cen.y = clamp(cen.y, min(half.y, w.size.y * 0.5), max(w.size.y - half.y, w.size.y * 0.5))
	var view := Rect2(cen - half, sz).grow(16.0)
	var n := 0
	for e in player.get_tree().get_nodes_in_group("enemies"):
		if e.dead or not e.targetable() or not view.has_point(e.center()) or n >= 14:
			continue
		var reps := 3 if e.boss else 1
		for i in reps:
			sp.meteor(e.global_position + Vector2(randf_range(-8, 8), randf_range(-6, 6)), dmg, 0.08 * n + 0.3 * i)
		n += 1
	if n == 0:
		for i in 6:
			sp.meteor(player.global_position + Vector2.from_angle(i * TAU / 6.0) * 90.0, dmg, 0.1 * i)

## Shadow Dance: five strikes, each from a new side of the target; finds a new target if this one falls
func _dance(dt: float) -> void:
	dance["t"] = float(dance["t"]) - dt
	if float(dance["t"]) > 0.0:
		return
	var tgt = dance["target"]
	if not is_instance_valid(tgt) or tgt.dead or not tgt.targetable():
		tgt = nearest(player.global_position + Vector2(0, -17), 220.0)
		if tgt == null:
			dance = {}
			return
		dance["target"] = tgt
	var w = world()
	var from: Vector2 = player.global_position
	var rad: float = max(tgt.box.x, tgt.box.y) * 0.5 + 22.0
	var base := randf() * TAU
	for k in 8:
		var feet: Vector2 = tgt.global_position + Vector2.from_angle(base + k * TAU / 8.0) * rad + Vector2(0, 10)
		feet = feet.clamp(Vector2(13, 34), w.size - Vector2(13, 0))
		if w.free_spot(feet, Vector2(26, 34)):
			player.global_position = feet
			break
	var to: Vector2 = tgt.center() - (player.global_position + Vector2(0, -17))
	if w.fx:
		var dash_dir := player.global_position - from
		if dash_dir.length_squared() < 0.0001:
			dash_dir = -to.normalized()
		w.fx.ghost(player.anim, Color(0.55, 0.8, 1.0, 0.6), 0.35)
		w.fx.dash_trail(from + Vector2(0, -17), dash_dir, Color(0.48, 0.84, 0.57, 0.88), 0.18, 48.0)
		w.fx.emit("shine", from + Vector2(0, -17), 6, Color(0.48, 0.84, 0.57), Vector2.ZERO, 180.0, 80.0)
	player.facing = player._dir_name(to)
	player.attacking = 0.16
	var dmg: float = Game.atk() * dmg_mul() * Game.ult_mul() * Game.melee_mul() * 1.5 * 2.3
	tgt.hurt(dmg, true, to.normalized() * 0.6, true)
	player._procs(tgt)
	if w.fx:
		w.fx.swing(player, to.normalized(), 40.0, true, int(Game.state.get("weapon", 1)))
		w.fx.class_impact(tgt.center(), to.normalized(), "rogue", true)
	Sfx.play("tp", -8.0, 0.2)
	Sfx.play("crit", -4.0)
	w.hitstop(0.04)
	player.invuln = max(player.invuln, 0.5)
	dance["left"] = int(dance["left"]) - 1
	dance["t"] = 0.17
	if int(dance["left"]) <= 0:
		dance = {}
