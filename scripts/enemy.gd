extends CharacterBody2D

const Gear = preload("res://scripts/gear.gd")
## A basic enemy: stats from ENEMY_TYPES with region/boss scaling, chases the hero when close,
## contact damage (+ its poison/freeze/burn), knockback, hit flash, health bar, XP and gold on death.
## Bosses and minibosses extend this in boss.gd; arena objects (pillars, eggs, echoes) in arena_obj.gd.

const Sheets = preload("res://scripts/sheets.gd")
const Fx = preload("res://scripts/fx/fx.gd")
const Loot = preload("res://scripts/fx/loot.gd")

var type := ""
var world: Node = null
var hp := 10.0
var max_hp := 10.0
var dmg := 5.0
var spd := 60.0
var xp := 5
var gold := 1
var boss := false
var box := Vector2(24, 24)
var home := Vector2.ZERO
var dead := false
var hit_cd := 0.0
var flash := 0.0
var knock := Vector2.ZERO
var wander := Vector2.ZERO
var wander_t := 0.0
var knock_mult := 1.0
var applies := {}
var hover := []
var hover_t := 0.0
var anim: AnimatedSprite2D
var bar_bg: ColorRect
var bar: ColorRect
var own_bar := true
var parley := false            # (v0.9) holds its blade during a parley or a deal: no chase, no contact damage
var calm := 0.0                # (v0.24) seconds it has not yet noticed a hero who just arrived (a load, a retry) — a hit wakes it
var elite := ""                 # (v0.16) "", "fire", "ice" or "storm": a stronger foe that sets its element on you
var _aura: Node2D
var rally := false              # (v0.9) "To me, lads!": chases from anywhere in the map
var alert := false             # (v0.7) has noticed the hero: a sneaking hero is seen from much closer, and unseen foes take backstabs
var est := {}                 # status effects on this enemy: burn | freeze | stun | poison -> {t, p, tick}
var drop_shadow: Sprite2D
var feel := true              # breathing / squash / lean (arena objects that animate themselves turn it off)
var tint := Color(1, 1, 1)    # the enemy's colour (sparks, debris)
var _wob := 0.0
var _bar_shown := 0.0
var _bar_trail := 1.0
var shoots := {}               # (v0.19) foes that keep their distance and shoot: {every, speed, applies, col, range, keep, n}
var shoot_t := 0.0
var can_leap := false
var can_teleport := false
var leap_cooldown := 0.0
var leap_windup := 0.0
var leap_time := 0.0
var leap_dir := Vector2.ZERO
var special_velocity := Vector2.ZERO
var teleport_cooldown := 0.0
var teleport_windup := 0.0
var teleport_target := Vector2.ZERO
var teleport_target_valid := false
var squad_alert_t := 0.0
var squad_pressure_t := 0.0
var squad_side := 1.0
var region_key := ""
var regional_skill := ""
var regional_cooldown := 0.0
var regional_windup := 0.0
var regional_attack_pending := false
var elite_attack_cooldown := 0.0
var elite_attack_pending := false
var elite_attack_trap_next := true
const LEAP_WINDUP := 0.42
const LEAP_DURATION := 0.34


## Regional signature moves are restricted to the maps and creatures that teach them.
static func regional_skill_for(area: String, enemy_type: String) -> String:
	match area:
		"shadowfen":
			return "bog_spit" if enemy_type == "mosquito" else ""
		"emberforge":
			return "flame_charge" if enemy_type == "cinderhound" else ""
		"frostvale":
			return "rime_pounce" if enemy_type == "frostwolf" else ""
		"damavand", "zahhakcave":
			return "venom_lash" if enemy_type == "serpentguard" else ""
	return ""


func setup(t: String, area: String, feet: Vector2, w: Node) -> void:
	type = t
	region_key = area
	regional_skill = regional_skill_for(area, t)
	world = w
	name = "Enemy_" + t
	add_to_group("enemies")
	var s: Dictionary = Game.enemy_stats(t, area)
	max_hp = float(s["hp"])
	hp = max_hp
	dmg = float(s["dmg"])
	spd = float(s["speed"])
	xp = int(s["xp"])
	gold = int(s["gold"])
	boss = bool(s["boss"])
	box = Vector2(float(s["w"]), float(s["h"]))
	knock_mult = float(s.get("knock", 1.0))
	var cs_hex = Game.enemy_def(t).get("color", "#c8c0b0")
	tint = Color(str(cs_hex)) if typeof(cs_hex) == TYPE_STRING else Color(0.8, 0.75, 0.7)
	_wob = randf() * TAU
	var ap = Game.enemy_def(t).get("applies", {})
	applies = ap if typeof(ap) == TYPE_DICTIONARY else {}
	var shd = Game.enemy_def(t).get("shoots", {})
	shoots = shd if typeof(shd) == TYPE_DICTIONARY else {}
	var enemy_data: Dictionary = Game.enemy_def(t)
	can_leap = bool(enemy_data.get("canLeap", false))
	can_teleport = bool(enemy_data.get("canTeleport", false))
	leap_cooldown = randf_range(1.0, 1.8)
	teleport_cooldown = randf_range(2.2, 3.2)
	regional_cooldown = randf_range(2.0, 3.2) if regional_skill != "" else 0.0
	shoot_t = randf_range(1.0, 2.2)
	position = feet
	home = feet
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(box.x * 0.8, min(box.y, 18.0))
	cs.shape = shape
	cs.position = Vector2(0, -shape.size.y * 0.5)
	add_child(cs)
	var sh: Dictionary = Sheets.enemy(t)
	if sh.is_empty():
		_placeholder()
	else:
		anim = AnimatedSprite2D.new()
		anim.sprite_frames = sh["frames"]
		anim.centered = false
		anim.offset = sh["offset"]
		anim.scale = Vector2.ONE * Sheets.SCALE
		var meta: Dictionary = sh["meta"]
		anim.modulate.a = float(meta.get("alpha", 1.0))
		add_child(anim)
		anim.play("v0")
		anim.frame = randi() % max(1, int(meta.get("frames", 1)))
		var hv = meta.get("hover", null)
		if typeof(hv) == TYPE_ARRAY and hv.size() >= 3:
			hover = hv
			hover_t = randf() * 10.0
	drop_shadow = Fx.shadow_for(self, box.x, box.y, 0.42 if boss else 0.34)
	if not hover.is_empty():
		Fx.lift_shadow(drop_shadow, float(hover[0]))
	_health_bar()
	_after_setup()

## hooks for boss.gd / arena_obj.gd
func _after_setup() -> void:
	pass

func targetable() -> bool:
	return not dead


## Called when a nearby ally spots the hero. The short shared alert lets a pack react
## to a stealthy approach without granting the whole map permanent aggro.
func hear_alarm(_where: Vector2) -> void:
	if dead or parley:
		return
	alert = true
	squad_alert_t = maxf(squad_alert_t, 2.4)


func center() -> Vector2:
	return global_position - Vector2(0, box.y * 0.5)

func set_variant(v: int) -> void:
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("v%d" % v) and anim.animation != "v%d" % v:
		var f := anim.frame
		anim.play("v%d" % v)
		anim.frame = f

func _hover(dt: float) -> void:
	if hover.is_empty() or anim == null:
		return
	hover_t += dt
	anim.position.y = -(float(hover[0]) + sin(hover_t * 1000.0 / float(hover[1])) * float(hover[2]))

func _placeholder() -> void:
	## the wisp (and anything without a painted sheet) is a glowing orb
	var orb := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 16:
		pts.append(Vector2(cos(i * TAU / 16.0), sin(i * TAU / 16.0)) * 8.0)
	orb.polygon = pts
	orb.color = Color(0.6, 1.0, 0.75, 0.85)
	orb.position = Vector2(0, -16)
	add_child(orb)

## a small framed health bar over the head with a fading damage trail; shown once the enemy is hurt
func _health_bar() -> void:
	var wdt: float = clamp(box.x, 24.0, 64.0)
	bar_bg = ColorRect.new()          # kept as the bar's holder (older code toggles its visibility)
	bar_bg.color = Color(0, 0, 0, 0)
	bar_bg.size = Vector2(wdt, 5)
	bar_bg.position = Vector2(-wdt * 0.5, -box.y - 13.0 - (float(hover[0]) if not hover.is_empty() else 0.0))
	bar_bg.visible = false
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.draw.connect(_draw_bar)
	add_child(bar_bg)
	bar = bar_bg

func _draw_bar() -> void:
	var w: float = bar_bg.size.x
	var k: float = clamp(hp / max_hp, 0.0, 1.0)
	bar_bg.draw_rect(Rect2(-1, -1, w + 2, 6), Color(0, 0, 0, 0.7))
	bar_bg.draw_rect(Rect2(0, 0, w, 4), Color(0.18, 0.06, 0.05, 0.9))
	if _bar_trail > k:
		bar_bg.draw_rect(Rect2(0, 0, w * _bar_trail, 4), Color(1, 0.86, 0.6, 0.85))
	var c := Color(0.9, 0.3, 0.25) if not boss else Color(0.95, 0.6, 0.2)
	bar_bg.draw_rect(Rect2(0, 0, w * k, 4), c)
	bar_bg.draw_rect(Rect2(0, 0, w * k, 1.5), c.lightened(0.35))

func hit_rect() -> Rect2:
	return Rect2(global_position - Vector2(box.x * 0.5, box.y), box)

func _physics_process(dt: float) -> void:
	if dead:
		return
	hit_cd = max(0.0, hit_cd - dt)
	calm = max(0.0, calm - dt)
	leap_cooldown = maxf(0.0, leap_cooldown - dt)
	teleport_cooldown = maxf(0.0, teleport_cooldown - dt)
	squad_alert_t = maxf(0.0, squad_alert_t - dt)
	squad_pressure_t = maxf(0.0, squad_pressure_t - dt)
	regional_cooldown = maxf(0.0, regional_cooldown - dt)
	regional_windup = maxf(0.0, regional_windup - dt)
	elite_attack_cooldown = maxf(0.0, elite_attack_cooldown - dt)
	_flash(dt)
	_hover(dt)
	if _estatus(dt):
		# A hard interrupt cancels a committed movement attack cleanly.
		leap_windup = 0.0
		leap_time = 0.0
		teleport_windup = 0.0
		teleport_target_valid = false
		regional_windup = 0.0
		regional_attack_pending = false
		elite_attack_pending = false
		if anim:
			anim.position.y = 0.0
		# frozen or stunned: no AI, knockback still slides it
		velocity = knock * 0.3
		knock = knock.move_toward(Vector2.ZERO, 900.0 * dt)
		move_and_slide()
		return
	if dead:
		return
	if parley:
		velocity = knock * 0.3
		knock = knock.move_toward(Vector2.ZERO, 900.0 * dt)
		move_and_slide()
		return
	var p = get_tree().get_first_node_in_group("player")
	var v := Vector2.ZERO
	if p and not p.dead:
		var to: Vector2 = (p.global_position + Vector2(0, -17)) - (global_position + Vector2(0, -box.y * 0.5))
		var d := to.length()
		var aggro := 420.0 if boss else 270.0
		var sm: float = p.stealth_mul() if p.has_method("stealth_mul") else 1.0
		var see: float = aggro * sm
		var chase_r: float = aggro if sm >= 1.0 else see * 1.8
		var heard_call := squad_alert_t > 0.0 and d < aggro * 1.65
		var chasing: bool = rally or heard_call or (calm <= 0.0 and d < (chase_r if alert else see))
		if chasing and not alert:
			alert = true
			_voice(false)
			if world and world.has_method("on_notice"):
				world.on_notice(self)
			if sm < 1.0 and world and world.has_method("float_text"):
				world.float_text(global_position + Vector2(0, -box.y - 14), "!", Color(1, 0.4, 0.3))
		elif not chasing:
			alert = false

		# The Mazandaran sorcerer winds up, then blinks to an open flank instead of
		# walking straight into the player's blade.
		var special_move := false
		var teleported := false
		if chasing and can_teleport:
			if teleport_windup > 0.0:
				teleport_windup = maxf(0.0, teleport_windup - dt)
				if teleport_windup <= 0.0:
					if teleport_target_valid and _teleport_position_valid(teleport_target):
						var old_pos: Vector2 = global_position
						global_position = world.to_global(teleport_target)
						teleported = true
						_blink_effect(old_pos, global_position)
					teleport_target_valid = false
					teleport_cooldown = randf_range(3.2, 4.4)
				special_move = true
			elif teleport_cooldown <= 0.0 and d >= 115.0 and d <= 270.0:
				teleport_target = _choose_teleport_target(p)
				if teleport_target != Vector2(-9999.0, -9999.0):
					teleport_target_valid = true
					teleport_windup = 0.28
					special_move = true
					if world.fx:
						world.fx.ring(world.to_global(teleport_target) + Vector2(0, -box.y * 0.45), Color(0.72, 0.52, 1.0), 24.0, 0.34)
				else:
					teleport_cooldown = 0.75
		if teleported:
			to = (p.global_position + Vector2(0, -17)) - (global_position + Vector2(0, -box.y * 0.5))
			d = to.length()

		# Boars of the marsh (toads) pause to telegraph a short, avoidable leap.
		if chasing and not special_move and can_leap:
			special_move = _leap_step(dt, to, d)
		if chasing and not special_move and elite == "venom":
			special_move = _venom_attack_step(p, d)
		if chasing and not special_move and regional_skill != "":
			special_move = _regional_attack_step(p, d)
		if special_move:
			v = special_velocity if leap_time > 0.0 else Vector2.ZERO
		elif chasing and not shoots.is_empty():
			v = _shooter(dt, to, d, p)
		elif chasing and d > 4.0:
			var toward_hero: Vector2 = to / d
			if squad_pressure_t > 0.0 and d > 58.0 and d < 205.0:
				# During an ally's volley, close in on a diagonal rather than stacking
				# directly behind the front line.
				var flank: Vector2 = toward_hero.orthogonal() * squad_side
				v = (toward_hero * 0.9 + flank * 0.55).normalized() * spd * 1.12
			else:
				v = toward_hero * spd
		elif not chasing:
			v = _wander(dt)
		# contact damage (+ the enemy's status: poison, freeze, burn …)
		if hit_cd <= 0.0 and hit_rect().intersects(p.body_rect()):
			_contact(p)
			hit_cd = 0.9
		if anim and abs(to.x) > 2.0 and chasing:
			anim.flip_h = to.x < 0
	if knock.length() > 1.0:
		v += knock
		knock = knock.move_toward(Vector2.ZERO, 900.0 * dt)
	velocity = v
	move_and_slide()
	global_position = global_position.clamp(Vector2(box.x * 0.5, box.y), world.size - Vector2(box.x * 0.5, 0))

# ---------------------------------------------------------------- creature movement archetypes
func _leap_step(dt: float, to: Vector2, d: float) -> bool:
	special_velocity = Vector2.ZERO
	if leap_windup > 0.0:
		leap_windup = maxf(0.0, leap_windup - dt)
		if leap_windup <= 0.0:
			if to.length() > 1.0:
				leap_dir = to.normalized()
				leap_time = LEAP_DURATION
			else:
				leap_cooldown = 0.55
		return true
	if leap_time > 0.0:
		var progress: float = 1.0 - leap_time / LEAP_DURATION
		special_velocity = leap_dir * maxf(spd * 2.8, 190.0)
		if anim:
			anim.position.y = -sin(progress * PI) * 22.0
		leap_time = maxf(0.0, leap_time - dt)
		if leap_time <= 0.0:
			if anim:
				anim.position.y = 0.0
			leap_cooldown = randf_range(2.6, 3.6)
		return true
	if leap_cooldown <= 0.0 and d >= 82.0 and d <= 190.0:
		leap_windup = LEAP_WINDUP
		var mark: Vector2 = global_position + to.normalized() * minf(98.0, d - 36.0)
		if world and world.fx:
			world.fx.ring(mark + Vector2(0, -8), Color(1.0, 0.52, 0.24), 22.0, LEAP_WINDUP)
		if world:
			world.float_text(global_position + Vector2(0, -box.y - 14), "!", Color(1.0, 0.52, 0.24), true)
		return true
	return false



# ---------------------------------------------------------------- elite signature attacks
## Venom elites alternate a slow poison spit with a marked ground trap. The trap's
## circle is deliberately left visible for 0.9 s so a moving or rolling hero can leave it.
func _venom_attack_step(p: Node, d: float) -> bool:
	if elite_attack_pending:
		return true
	if elite_attack_cooldown > 0.0 or d < 90.0 or d > 285.0:
		return false
	if world == null or world.bossfx == null or p == null:
		return false
	var target: Vector2 = p.pc() if p.has_method("pc") else p.global_position
	var col := Color(0.48, 0.88, 0.30)
	if elite_attack_trap_next:
		elite_attack_pending = true
		elite_attack_cooldown = randf_range(4.8, 5.6)
		world.bossfx.circle(target, 52.0, 0.9, col, _fire_venom_trap, self)
		world.float_text(global_position + Vector2(0, -box.y - 14), "!", col, true)
		Sfx.play("poison", -7.0, 0.12)
		return true
	var direction: Vector2 = target - center()
	if direction.length() < 1.0:
		direction = Vector2.RIGHT
	world.bossfx.shots.append({
		"pos": center(),
		"v": direction.normalized() * 2.6 * Game.PXS,
		"life": 2.0,
		"dmg": maxf(1.0, round(dmg * 0.72)),
		"col": col,
		"applies": "poison",
		"sec": 2.2,
		"src": "venom_elite:spit"
	})
	if world.fx:
		world.fx.ring(center(), col, 20.0, 0.28)
	world.burst(center(), col, 4, 70.0)
	Sfx.play("poison", -6.0, 0.12)
	flash = 0.08
	elite_attack_trap_next = true
	elite_attack_cooldown = randf_range(4.2, 5.0)
	return true


func _fire_venom_trap(t: Dictionary) -> void:
	if not elite_attack_pending or elite != "venom" or dead or world == null or world.bossfx == null:
		return
	elite_attack_pending = false
	elite_attack_trap_next = false
	var bfx: Node = world.bossfx
	var pos: Vector2 = t["pos"]
	bfx.pool(pos, 92.0, 2.8, "poison", self, 0.65, ["poison", 1.6, 1.0])
	world.burst(pos, Color(0.42, 0.88, 0.30), 12, 105.0)
	Sfx.play("trap", -5.0, 0.12)
	if bfx.in_circle(t):
		bfx.hit(self, 0.74, ["poison", 1.8, 1.0])


# ---------------------------------------------------------------- regional signature attacks
func _regional_attack_step(p: Node, d: float) -> bool:
	if regional_attack_pending:
		return true
	if regional_cooldown > 0.0 or d < 105.0 or d > 235.0:
		return false
	if world == null or world.bossfx == null or p == null:
		return false
	var target: Vector2 = p.pc() if p.has_method("pc") else p.global_position
	var origin: Vector2 = center()
	var delay := 0.62
	regional_attack_pending = true
	match regional_skill:
		"bog_spit":
			delay = 0.7
			world.bossfx.circle(target, 54.0, delay, Color(0.45, 0.9, 0.38), _fire_regional_circle, self)
		"flame_charge":
			delay = 0.58
			world.bossfx.lane(origin, target, 52.0, delay, Color(1.0, 0.42, 0.16), _fire_regional_lane, self)
		"rime_pounce":
			delay = 0.76
			world.bossfx.circle(target, 58.0, delay, Color(0.62, 0.86, 1.0), _fire_regional_circle, self)
		"venom_lash":
			delay = 0.64
			world.bossfx.lane(origin, target, 36.0, delay, Color(0.58, 0.9, 0.36), _fire_regional_lane, self)
		_:
			regional_attack_pending = false
			return false
	regional_windup = delay
	regional_cooldown = randf_range(5.6, 7.0)
	return true


func _fire_regional_circle(t: Dictionary) -> void:
	if not regional_attack_pending or dead or world == null or world.bossfx == null:
		return
	regional_attack_pending = false
	var bfx: Node = world.bossfx
	var pos: Vector2 = t["pos"]
	if regional_skill == "bog_spit":
		bfx.pool(pos, 82.0, 3.4, "poison", self, 0.34, ["poison", 1.2, 0.6])
		world.burst(pos, Color(0.42, 0.88, 0.34), 12, 110.0)
		if bfx.in_circle(t):
			bfx.hit(self, 0.78, ["poison", 2.2, 1.0])
	elif regional_skill == "rime_pounce":
		world.burst(pos, Color(0.65, 0.88, 1.0), 16, 130.0)
		if bfx.in_circle(t):
			bfx.hit(self, 0.82, ["freeze", 0.9, 1.0])


func _fire_regional_lane(t: Dictionary) -> void:
	if not regional_attack_pending or dead or world == null or world.bossfx == null:
		return
	regional_attack_pending = false
	var bfx: Node = world.bossfx
	var end: Vector2 = t["b"]
	var status: Array = []
	var mult := 0.9
	var col := Color(1.0, 0.42, 0.16)
	match regional_skill:
		"flame_charge":
			status = ["burn", 2.2, 1.0]
			mult = 0.92
			col = Color(1.0, 0.42, 0.16)
		"venom_lash":
			status = ["poison", 2.4, 1.0]
			mult = 0.84
			col = Color(0.58, 0.9, 0.36)
	world.burst(end, col, 10, 105.0)
	if bfx.in_lane(t):
		bfx.hit(self, mult, status)


func _choose_teleport_target(p: Node) -> Vector2:
	if world == null or p == null:
		return Vector2(-9999.0, -9999.0)
	var hero_local: Vector2 = world.to_local(p.global_position)
	var current_local: Vector2 = world.to_local(global_position)
	var toward: Vector2 = hero_local - current_local
	if toward.length() < 1.0:
		toward = Vector2.RIGHT
	var side: Vector2 = toward.normalized().orthogonal()
	var candidates: Array[Vector2] = [
		hero_local + side * 104.0,
		hero_local - side * 104.0,
		hero_local - toward.normalized() * 112.0,
	]
	for candidate in candidates:
		if candidate.distance_to(current_local) > 82.0 and candidate.distance_to(hero_local) >= 76.0 and _teleport_position_valid(candidate):
			return candidate
	return Vector2(-9999.0, -9999.0)


func _teleport_position_valid(pos: Vector2) -> bool:
	if world == null or pos.x < box.x * 0.5 + 8.0 or pos.x > world.size.x - box.x * 0.5 - 8.0:
		return false
	if pos.y < box.y + 8.0 or pos.y > world.size.y - 8.0:
		return false
	var body_h: float = minf(box.y, 18.0)
	var body_rect := Rect2(pos + Vector2(-box.x * 0.4, -body_h), Vector2(box.x * 0.8, body_h))
	return not world.wall_hit(body_rect)


func _blink_effect(old_pos: Vector2, new_pos: Vector2) -> void:
	var col := Color(0.72, 0.52, 1.0)
	if world and world.fx:
		world.fx.ring(old_pos + Vector2(0, -box.y * 0.45), col, 28.0, 0.34)
		world.fx.ring(new_pos + Vector2(0, -box.y * 0.45), col.lightened(0.18), 34.0, 0.4)
		world.fx.flash_light(new_pos + Vector2(0, -box.y * 0.45), 74.0, 0.55, col, 0.25)
	flash = 0.08
	Sfx.play("dash", -5.0, 0.12)


# ---------------------------------------------------------------- status effects (weapon procs: burn, stun; mage: freeze)
func apply_status(kind: String, sec: float, potency := 1.0) -> void:
	if dead:
		return
	if est.has(kind):
		est[kind]["t"] = max(float(est[kind]["t"]), sec)
		est[kind]["p"] = max(float(est[kind]["p"]), potency)
	else:
		est[kind] = {"t": sec, "p": potency, "tick": 0.0}

func has_status(kind: String) -> bool:
	return est.has(kind)

## ticks burn/poison damage; returns true while frozen or stunned
func _estatus(dt: float) -> bool:
	if est.is_empty():
		return false
	var stop := false
	for k in est.keys():
		var s: Dictionary = est[k]
		s["t"] = float(s["t"]) - dt
		s["tick"] = float(s["tick"]) - dt
		if (k == "burn" or k == "poison") and float(s["tick"]) <= 0.0:
			s["tick"] = 0.4 if k == "burn" else 0.6
			var dd: float = (2.0 if k == "burn" else 1.0) * float(s["p"])
			hp -= dd
			flash = 0.08
			world.float_text(global_position + Vector2(0, -box.y), "-%d" % int(dd), Color(1, 0.5, 0.25) if k == "burn" else Color(0.45, 0.85, 0.4))
			if hp <= 0.0:
				est.clear()
				die()
				return true
		if k == "freeze" or k == "stun":
			stop = true
		if float(s["t"]) <= 0.0:
			est.erase(k)
	if anim and flash <= 0.0:
		var a := anim.modulate.a
		anim.modulate = Color(0.65, 0.9, 1.0, a) if est.has("freeze") else (Color(1.0, 0.75, 0.6, a) if est.has("burn") else Color(1, 1, 1, a))
	return stop

func _flash(dt: float) -> void:
	if flash > 0.0:
		flash -= dt
		if anim:
			anim.modulate = Color(3, 3, 3, anim.modulate.a) if flash > 0.0 else Color(1, 1, 1, anim.modulate.a)

func _contact(p: Node) -> void:
	var h0: float = Game.hp
	p.take_hit(dmg)
	if Game.hp < h0:
		for k in applies:
			p.apply_status(str(k), 2.6, float(applies[k]))

func _wander(dt: float) -> Vector2:
	wander_t -= dt
	if wander_t <= 0.0:
		wander_t = randf_range(1.2, 2.8)
		var back := home - global_position
		if back.length() > 90.0:
			wander = back.normalized() * spd * 0.4
		elif randf() < 0.5:
			wander = Vector2.ZERO
		else:
			wander = Vector2.from_angle(randf() * TAU) * spd * 0.35
	if anim and abs(wander.x) > 1.0:
		anim.flip_h = wander.x < 0
	return wander

## an elite: tougher, harder-hitting, worth more, wreathed in its element (fire burns, frost freezes, storm stuns, venom poisons)
func make_elite(el: String, power := 1.0) -> void:
	var d: Dictionary = Game.elite_def(el)
	if d.is_empty() or boss:
		return
	elite = el
	max_hp *= 2.4 * power
	hp = max_hp
	dmg *= 1.3
	xp = int(xp * 3 * power)
	gold = int(gold * 3 * power)
	applies[str(d["status"])] = 1.0
	if el == "venom":
		elite_attack_cooldown = randf_range(2.4, 3.2)
		elite_attack_trap_next = true
	if anim:
		anim.modulate = Color(str(d["col"])).lerp(Color.WHITE, 0.35)
	_aura = Node2D.new()
	_aura.z_index = -1
	_aura.draw.connect(func():
		var col := Color(str(d["glow"]))
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
		var r := maxf(box.x, 18.0) * 0.8 + pulse * 3.0
		_aura.draw_circle(Vector2(0, -box.y * 0.45), r, Color(col, 0.16 + 0.1 * pulse))
		_aura.draw_arc(Vector2(0, -box.y * 0.45), r, 0.0, TAU, 28, Color(col, 0.75), 2.0))
	add_child(_aura)

## breathing, a squash when hit, a lean when knocked back (VIS enemy animation); the bar's trail fades
func _process(dt: float) -> void:
	if _aura and not dead:
		_aura.queue_redraw()
	if bar_bg and bar_bg.visible:
		var k: float = clamp(hp / max_hp, 0.0, 1.0)
		if _bar_trail > k:
			_bar_trail = max(k, _bar_trail - dt * 0.8)
			bar_bg.queue_redraw()
	if dead or anim == null or not feel:
		return
	var b := sin(Time.get_ticks_msec() / (520.0 if boss else 340.0) + _wob)
	var sy := 1.0 + b * 0.028
	var sx := 1.0 - b * 0.028
	if flash > 0.0:
		sx *= 1.07
		sy *= 0.93
	anim.scale = Vector2(sx, sy) * Sheets.SCALE
	anim.rotation = clamp(-knock.x / Game.PXS * 0.035, -0.16, 0.16) if knock.length() > 1.0 else 0.0

func hurt(amount: float, crit: bool, from_dir: Vector2, heavy := false) -> void:
	calm = 0.0
	if dead:
		return
	# Taking a hit interrupts a committed leap before the knockback is applied.
	leap_windup = 0.0
	leap_time = 0.0
	regional_windup = 0.0
	regional_attack_pending = false
	elite_attack_pending = false
	if anim:
		anim.position.y = 0.0
	if parley and world and world.has_method("truce_broken"):
		world.truce_broken()
	hp -= amount
	flash = 0.11
	knock = from_dir * 260.0 * knock_mult
	bar_bg.visible = own_bar
	bar_bg.queue_redraw()
	world.float_text(global_position + Vector2(0, -box.y - 6), str(int(round(amount))) + ("!" if crit else ""), Color(1, 0.72, 0.3) if crit else Color(1, 1, 1), crit)
	# impact: sparks fly away from the blow, a ring and a flash of light on crits (VIS damageEnemy)
	var c := center()
	var fx = world.fx
	if fx:
		fx.sparks(c, 14 if crit else 8, Color(1, 0.94, 0.69) if crit else Color(1, 0.85, 0.54), from_dir)
		fx.burst(c, tint, 3 if not crit else 5, 90.0)
		if crit or heavy:
			fx.ring(c, Color(1, 0.94, 0.69), 16.0, 0.3)
			fx.flash_light(c, 90.0, 0.8, Color(1, 0.85, 0.55), 0.25)
	if ARMORED.has(type):
		Sfx.play("clank", -7.0, 0.1)
	if hp <= 0.0:
		die()

## (v0.19) a shooter (rime wraiths, wyrmlings): closes in to its range, backs off when the hero is too near, and every few
## seconds looses frost bolts at him (one, or a spread of three) — slow enough to dodge, they freeze for a moment
func _shooter(dt: float, to: Vector2, d: float, p: Node) -> Vector2:
	var rng := float(shoots.get("range", 250.0))
	var keep := float(shoots.get("keep", 130.0))
	var v := Vector2.ZERO
	if d > rng * 0.85:
		v = to / max(1.0, d) * spd
	elif d < keep:
		v = -to / max(1.0, d) * spd * 0.7
	else:
		v = Vector2(-to.y, to.x).normalized() * spd * 0.35 * sin(Time.get_ticks_msec() / 900.0 + _wob)
	shoot_t -= dt
	if shoot_t <= 0.0 and d < rng and world.bossfx:
		if world.has_method("request_enemy_volley") and not world.request_enemy_volley(self):
			# Keep checking shortly; a nearby archer has the next clear firing window.
			shoot_t = 0.14
			return v
		shoot_t = float(shoots.get("every", 2.6)) * randf_range(0.85, 1.2)
		var n := int(shoots.get("n", 1))
		var c := center()
		var a: float = (p.global_position + Vector2(0, -17) - c).angle()
		var col := Color(str(shoots.get("col", "#bfe6ff")))
		for i in n:
			var off := 0.0 if n == 1 else (float(i) - (n - 1) * 0.5) * 0.26
			world.bossfx.shots.append({"pos": c, "v": Vector2.from_angle(a + off) * float(shoots.get("speed", 3.0)) * Game.PXS,
				"life": 1.6, "dmg": dmg, "col": col, "applies": str(shoots.get("applies", "")), "sec": 1.2, "src": type + ":bolt"})
		Sfx.play("ice", -10.0, 0.15)
		flash = 0.08
	return v

## (v0.17) creatures with a voice: a growl, a chitter or a gurgle when they notice the hero and when they fall
## (bandits, knights, golems and spirits stay silent: their blades and stone speak for them)
## (v0.34) the foes come from the Shahnameh now: the boar, the nahang and the lion growl like the leopard and the wolf;
## the eagle of Kavus is not a bat and the serpent of Zahhak is not a beetle, so neither chitters any more
const VOICE := {"cinderhound": "growl", "imp": "growl", "lurker": "growl", "toad": "growl", "slime": "growl",
	"bogegg": "slime", "mosquito": "bug", "crystalSpider": "growl", "iceling": "bug", "frostwolf": "growl", "wyrmling": "growl",
	"golem": "growl"}

func _voice(dying: bool) -> void:
	if boss or not VOICE.has(type):
		return
	var v: String = VOICE[type]
	if v == "growl":
		Sfx.play("die" if dying else "growl", -2.0 if dying else -4.0, 0.1)
	elif v == "bug":
		Sfx.play("bug", 0.0 if dying else -3.0, 0.15)
	else:
		Sfx.play("slime", 0.0 if dying else -4.0, 0.12)

## foes in plate or stone ring like metal when struck (V17.ARMORED); (v0.34) the elephant and the divs of flesh no longer do
const ARMORED := {"frostknight": 1, "moltencore": 1, "captain": 1, "anvilward": 1, "boss2": 1, "kondrow": 1, "zahhak": 1}

func die() -> void:
	dead = true
	remove_from_group("enemies")
	collision_layer = 0
	Game.Ach.add("kills")
	var g := int(round(gold * Game.gold_mul()))
	var x := int(round(xp * Game.xp_mul()))
	Game.state["gold"] = int(Game.state.get("gold", 0)) + g
	var hero = get_tree().get_first_node_in_group("player")
	if hero and hero.caster and not hero.caster.ult_active():
		Game.add_ult(10.0 if boss else 5.0)
	var up: bool = Game.add_xp(x)
	world.float_text(global_position + Vector2(0, -box.y - 16), Game.t("+%d XP" % x, "+%s تجربه" % Game.num(x)), Color(0.6, 0.9, 1))
	if up:
		Sfx.play("levelup")
		world.level_up.emit(Game.lvl())
	Sfx.play("kill", -3.0)
	Sfx.play("poof", -8.0)
	_voice(true)
	var c := center()
	var fx = world.fx
	if fx:
		fx.smoke(c, 8 if not boss else 16, Color(0.82, 0.78, 0.74, 0.7), 1.2 if not boss else 2.2)
		fx.burst(c, tint, 10 if not boss else 26, 150.0)
		fx.emit("shine", c, 6, Color(0.85, 0.95, 1.0), Vector2.UP, 40.0, 70.0)
		fx.flash_light(c, 110.0 if not boss else 260.0, 0.8, Color(1, 0.9, 0.7), 0.35 if not boss else 0.8)
	Loot.spawn(world, c, g, x, boss)
	if elite != "":
		Game.state["elites"] = Game.elites_slain() + 1
		Gear.grant(Gear.roll("rare"))
		world.float_text(global_position + Vector2(0, -66), Game.t("Elite slain!", "نخبه کشته شد!"), Color(1, 0.85, 0.45), true)
	Gear.drop_from(type, boss)
	var c2k: String = Game.Ch2.on_kill(type)
	if c2k != "":
		world.float_text(global_position + Vector2(0, -40), c2k, Color(0.75, 0.9, 1.0), true)
	var c3k: String = Game.Ch3.on_kill(type)        # (v0.23) Qaren's count of serpent guards
	if c3k != "":
		world.float_text(global_position + Vector2(0, -40), c3k, Color(0.7, 1.0, 0.6), true)
		if c3k == Game.Ch3.line("t_guards_done"):
			world.notice.emit(c3k, "check")
			Sfx.play("quest", -2.0)
	var ct := Game.contract_progress(type)
	if ct != "":
		world.float_text(global_position + Vector2(0, -52), ct, Color(1, 0.9, 0.5), true)
		Sfx.play("quest", -4.0)
	if not boss and Game.herb_drop(world.key):
		world.float_text(global_position + Vector2(0, -34), Game.t("+1 Bogbloom", "+۱ گلِ مرداب"), Color(0.6, 0.95, 0.55))
	if type == "captain" or type == "anvilward":     # the mini bosses: Ashkbus (his men scatter) and Pulad of Ghandi
		world.boss_down.emit(Game.boss_defeated(type))
		if type == "captain":
			world.scatter()
	if bar_bg:
		bar_bg.visible = false
	if drop_shadow:
		drop_shadow.visible = false
	if boss:
		Sfx.play("roar")
		world.shake(10.0)
		Game.vibrate(120, 1.0)
		world.boss_down.emit(Game.boss_defeated(type))
	# a white pop, then gone
	if anim:
		anim.modulate = Color(3, 3, 3, anim.modulate.a)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.18, 0.86), 0.08)
	tw.tween_property(self, "modulate:a", 0.0, 0.3).set_delay(0.06)
	tw.chain().tween_callback(queue_free)
