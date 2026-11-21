extends CharacterBody2D
## The hero: 8-way movement, combo melee with crits, dodge roll with i-frames, potions.
## Origin = feet; the collision box is the HTML game's 26x34 body.

signal died
signal interact(npc: Node)

const Sheets = preload("res://scripts/sheets.gd")
const Fx = preload("res://scripts/fx/fx.gd")
const GameCamera = preload("res://scripts/fx/game_camera.gd")
const Caster = preload("res://scripts/caster.gd")

var world: Node = null
var anim: AnimatedSprite2D
var cast_anim: AnimatedSprite2D
var _mage_cast_front_active := false
const MAGE_CAST_FRONT_DISPLAY_SCALE := 0.88
var body: Node2D              # pivot at the body's middle: the roll spins around it
var shadow: Sprite2D
var cam: Camera2D
var caster: Node              # mana, spells and the ultimate (v0.6)
var moving := false
var _step_t := 0.0             # (v0.17) time to the next footstep
var walk_ph := 0.0
var roll_t := 0.0             # the dodge roll's spin (s left)
var dash_v := Vector2.ZERO
var dash_t := 0.0
var _dust_t := 0.0
var _ghost_t := 0.0
var facing := "down"
var joy := Vector2.ZERO
var move_dir := Vector2.ZERO   # (v0.18) the stick/keys this frame (the shrines' blocks are pushed by leaning on them)
var haste_t := 0.0             # (v0.11) Scroll: Haste, +45% speed
var regen_t := 0.0             # Scroll: Heal, a steady trickle of health
var hold_block := false       # (touch) the block button is held
var hold_attack := false      # (touch) attack button is held -> charging
var charge := 0.0
var charging := false
var near_npc: Node = null
var charge_fx: Node2D
const HEAVY_AT := 0.45
var atk_cd := 0.0
var attacking := 0.0
var _attack_visual_facing := ""
var _pending_attack: Dictionary = {}
var _attack_impact_remaining := 0.0
var invuln := 0.0
var dodge_cd := 0.0
var stamina := 100.0
const Gear = preload("res://scripts/gear.gd")
var combo := 0
var combo_t := 0.0
var hazard_t := 0.0
var sheet := ""
var dead := false
var blocking := false         # (v0.7) shield raised: hold the block button
var block_t := 0.0            # seconds since the shield went up (a perfect parry lands in the first PARRY_WIN)
var guard_broken := 0.0       # seconds left in which the shield cannot be raised (stamina ran dry)
var sneaking := false         # (v0.7) toggled by the sneak button / Z: slower, harder to see, backstabs
var shove_cd := 0.0
var shoves := 0
var rolls_n := 0              # rolls made (the yard counts them)
var sig_uses := 0             # (v0.26) the calling's own move (Skills.SIG), on the Shove button
var ward_t := 0.0             # the Simorgh's feather: seconds the next blow is turned
var fire_t := 0.0             # the walk through fire
var _fire_tick := 0.0
var backstabs := 0
var parries := 0              # running totals, read by tests
var blocks := 0
var block_fx: Node2D
const PARRY_WIN := 0.2
const BLOCK_TAKEN := 0.3      # share of damage that gets through a held shield (an Aegis Girdle lowers it)
var dodge_iframes := 0.0      # the roll itself (a "perfect dodge" window for boss attacks)
var statuses := {}            # "poison" | "burn" | "freeze" -> {"t": seconds left, "p": potency, "tick": s}
const STATUS := {
	"poison": {"tick": 0.6, "dmg": 1.0, "col": Color(0.37, 0.75, 0.35)},
	"burn": {"tick": 0.4, "dmg": 2.0, "col": Color(0.88, 0.35, 0.23)},
	"freeze": {"tick": 0.0, "dmg": 0.0, "col": Color(0.45, 0.82, 0.84)},
}

func setup() -> void:
	name = "Player"
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(26, 34)
	cs.shape = shape
	cs.position = Vector2(0, -17)
	add_child(cs)
	shadow = Fx.shadow_for(self, 26, 34, 0.38)
	body = Node2D.new()
	body.name = "Body"
	body.position = Vector2(0, -17)
	add_child(body)
	anim = AnimatedSprite2D.new()
	anim.centered = false
	anim.scale = Vector2.ONE * Sheets.SCALE
	anim.position = Vector2(0, 19)        # feet 2 px under the node origin, as before
	body.add_child(anim)
	refresh_look()
	charge_fx = Node2D.new()
	charge_fx.position = Vector2(0, -17)
	charge_fx.z_index = 30
	charge_fx.visible = false
	var ring := Line2D.new()
	ring.width = 2.0
	ring.default_color = Color(1, 0.75, 0.35, 0.85)
	for i in 25:
		ring.add_point(Vector2.from_angle(i * TAU / 24.0) * 22.0)
	charge_fx.add_child(ring)
	add_child(charge_fx)
	block_fx = Node2D.new()
	block_fx.position = Vector2(0, -17)
	block_fx.z_index = 29
	block_fx.visible = false
	add_child(block_fx)
	cam = GameCamera.new()
	cam.hero = self
	add_child(cam)
	caster = Caster.new()
	caster.setup(self)
	add_child(caster)
	if not caster.cast_done.is_connected(_on_spell_cast):
		caster.cast_done.connect(_on_spell_cast)

## pick the gear look that matches weapon/armour tiers, painted in the hero look worn (v0.20)
func refresh_look() -> void:
	var w := int(Game.state.get("weapon", 1))
	var a := int(Game.state.get("armor", 0))
	var tag := "starter"
	if w >= 5 or a >= 4:
		tag = "endgame"
	elif w >= 3 or a >= 2:
		tag = "mid"
	var s := Game.cls + "_" + tag
	var lk: String = Game.Looks.current()
	if s == sheet and lk == look:
		return
	if s != sheet:
		_stop_mage_cast_front()
		_cancel_pending_attack()
		sheet = s
		var ch: Dictionary = Sheets.character("heroes", s)
		anim.sprite_frames = ch["frames"]
		anim.offset = ch["offset"]
		anim.play("idle_down")
	look = lk
	Game.Looks.apply(anim, sheet, look)
	_look_extras()

# ---------------------------------------------------------------- hero looks (v0.20): aura, crown, trail
var look := ""
var aura: Sprite2D
var crown_n: Node2D
var _mote_t := 0.0

func _look_extras() -> void:
	var ac: Color = Game.Looks.aura(look)
	if ac.a > 0.0:
		if aura == null:
			aura = Sprite2D.new()
			aura.name = "Aura"
			aura.texture = Fx.Tex.glow()
			aura.material = Fx.Tex.add_material()
			aura.z_as_relative = false
			aura.z_index = -5
			aura.position = Vector2(0, -1)
			aura.scale = Vector2(1.15, 0.42)
			add_child(aura)
		aura.modulate = Color(ac, 0.42)
		aura.visible = true
	elif aura:
		aura.visible = false
	if Game.Looks.crown(look):
		if crown_n == null:
			crown_n = Node2D.new()
			crown_n.name = "Crown"
			crown_n.z_index = 2
			crown_n.scale = Vector2(0.8, 0.8)
			crown_n.draw.connect(_draw_crown)
			body.add_child(crown_n)
		crown_n.position = Vector2(0, 19.0 - float(Game.Looks.HEAD.get(Game.cls, 46.0)) - 3.0)
		crown_n.visible = true
	elif crown_n:
		crown_n.visible = false

## a small gold crown over the head, a gem in front (seen from behind: no gem)
func _draw_crown() -> void:
	var gold := Color(1.0, 0.84, 0.36)
	var dark := Color(0.55, 0.38, 0.1)
	var pts := PackedVector2Array([Vector2(-9, 0), Vector2(-10, -8), Vector2(-5, -4), Vector2(0, -10), Vector2(5, -4), Vector2(10, -8), Vector2(9, 0)])
	var line := pts.duplicate()
	line.append(pts[0])
	crown_n.draw_colored_polygon(pts, gold)
	crown_n.draw_polyline(line, dark, 1.4, true)
	crown_n.draw_rect(Rect2(-9, -1.5, 18, 3), Color(0.9, 0.7, 0.25))
	for x in [-10.0, 0.0, 10.0]:
		crown_n.draw_circle(Vector2(x, -8.5 if x != 0.0 else -10.5), 1.6, Color(1, 0.96, 0.8))
	if facing != "up":
		crown_n.draw_circle(Vector2(0, -3), 1.8, Color(0.85, 0.2, 0.25) if look != "pahlavan" else Color(0.2, 0.85, 0.78))

## the look's trail: motes behind the hero as he walks (not when sneaking, not on the lightest graphics)
func _look_tick(dt: float) -> void:
	if aura and aura.visible:
		var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 420.0)
		aura.scale = Vector2(1.1 + 0.08 * k, 0.40 + 0.03 * k)
		aura.modulate.a = 0.34 + 0.14 * k
	if crown_n and crown_n.visible:
		crown_n.queue_redraw()
	var tc: Color = Game.Looks.trail(look)
	if tc.a <= 0.0 or not moving or sneaking or world == null or world.fx == null or int(Game.settings.get("fx", 1)) <= 0:
		return
	_mote_t -= dt
	if _mote_t <= 0.0:
		_mote_t = 0.14
		world.fx.emit("shine", global_position + Vector2(randf_range(-6, 6), -6), 1, Color(tc, 0.85), -facing_vec(), 40.0, 26.0, 0.8)

func enter_world(w: Node, feet: Vector2) -> void:
	_stop_mage_cast_front()
	_cancel_pending_attack()
	world = w
	global_position = feet
	velocity = Vector2.ZERO
	cam.set_map(w.size)
	cam.make_current()
	roll_t = 0.0
	dash_t = 0.0
	if w.get("spells"):
		w.spells.caster = caster
	# (v0.24) Rostam's last drill listens for a spell
	if w.get("training") and not caster.cast_done.is_connected(w.training.on_cast):
		caster.cast_done.connect(w.training.on_cast)
	caster.dance = {}

func _dir_name(v: Vector2) -> String:
	if abs(v.x) > abs(v.y):
		return "left" if v.x < 0 else "right"
	return "up" if v.y < 0 else "down"

func facing_vec() -> Vector2:
	match facing:
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
		"up": return Vector2.UP
	return Vector2.DOWN

func _physics_process(dt: float) -> void:
	if dead or world == null:
		_stop_mage_cast_front()
		return
	atk_cd = max(0.0, atk_cd - dt)
	attacking = max(0.0, attacking - dt)
	invuln = max(0.0, invuln - dt)
	dodge_iframes = max(0.0, dodge_iframes - dt)
	dodge_cd = max(0.0, dodge_cd - dt)
	guard_broken = max(0.0, guard_broken - dt)
	shove_cd = max(0.0, shove_cd - dt)
	_sig_step(dt)
	_statuses(dt)
	if dead:
		_stop_mage_cast_front()
		return
	_tick_attack_impact(dt)
	if dead:
		_stop_mage_cast_front()
		return
	combo_t = max(0.0, combo_t - dt)
	stamina = min(Game.max_stamina(), stamina + (9.0 if blocking else 28.0) * dt)
	var regen := Gear.sum("hpRegen")
	if regen > 0.0 and not dead and Game.hp < Game.max_hp():
		Game.hp = min(Game.max_hp(), Game.hp + regen * dt)
	if blocking:
		block_t += dt
		if caster.busy() or caster.ult_active():
			block_end()

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if joy.length() > 0.12:
		dir = joy
	if dir.length() > 1.0:
		dir = dir.normalized()
	var spd: float = Game.speed()
	var hz: String = world.hazard_at(global_position)
	if statuses.has("freeze"):
		spd *= 0.5
	if caster.spin_t > 0.0:
		spd *= 0.85
	if blocking:
		spd *= 0.45
	if haste_t > 0.0:
		spd *= 1.45
	if sneaking:
		spd *= 0.55
	if caster.busy():
		dir = Vector2.ZERO
	move_dir = dir
	if dash_t > 0.0:
		# the dodge: 95 px in a fast, short dash (the HTML game teleports; the distance and i-frames are the same)
		var step: float = min(dt, dash_t)
		dash_t -= dt
		move_and_collide(dash_v * step)
		velocity = Vector2.ZERO
	else:
		var wind_drift := Vector2.ZERO
		if world.has_method("wind_drift"):
			wind_drift = world.wind_drift(global_position, caster.busy())
		velocity = dir * spd + wind_drift
		move_and_slide()
	global_position = global_position.clamp(Vector2(13, 34), world.size - Vector2(13, 0))
	moving = dir.length() > 0.1
	if moving:
		facing = _dir_name(dir)
	_footsteps(dt, spd)
	_hazards(hz, dt)

	if Input.is_action_just_pressed("attack"):
		attack_press()
	if Input.is_action_just_released("attack"):
		attack_release()
	var holding := hold_attack or Input.is_action_pressed("attack")
	if charging and holding:
		charge += dt
		if charge >= HEAVY_AT and not charge_fx.visible:
			charge_fx.visible = true
			Sfx.play("charge", -6.0, 0.0)
		if charge_fx.visible:
			charge_fx.scale = Vector2.ONE * (0.8 + 0.2 * sin(charge * 18.0))
	if Input.is_action_just_pressed("interact") and near_npc:
		interact.emit(near_npc)
	_find_npc()
	haste_t = max(0.0, haste_t - dt)
	if regen_t > 0.0:
		regen_t -= dt
		if not dead:
			Game.hp = min(Game.max_hp(), Game.hp + Game.max_hp() * 0.045 * dt)
	if Input.is_action_just_pressed("scroll"):
		use_scroll()
	if Input.is_action_just_pressed("block") and not Input.is_action_pressed("attack"):
		block_start()
	if blocking and not (Input.is_action_pressed("block") or hold_block):
		block_end()
	_block_visual()
	if Input.is_action_just_pressed("sneak"):
		toggle_sneak()
	if Input.is_action_just_pressed("shove"):
		signature()
	if Input.is_action_just_pressed("dodge"):
		dodge()
	if Input.is_action_just_pressed("potion"):
		drink()
	if Input.is_action_just_pressed("skill1"):
		caster.cast_slot(0)
	if Input.is_action_just_pressed("skill2"):
		caster.cast_slot(1)
	if Input.is_action_just_pressed("ult"):
		caster.ultimate()
	if Input.is_action_just_pressed("mana"):
		caster.drink_mana()
	_animate(dir)
	_look_tick(dt)
	_over_bosses()

## a boss that surfaces or stands right on the hero would hide him behind its big sprite: lift him above it
func _over_bosses() -> void:
	var r := body_rect()
	var over := 0
	for b in get_tree().get_nodes_in_group("bosses"):
		if not b.dead and b.hit_rect().intersects(r):
			over = 1
			break
	if z_index != over:
		z_index = over

func _animate(dir: Vector2) -> void:
	if _mage_cast_front_active:
		var can_continue_cast := Game.cls == "mage" and sheet == "mage_starter" \
			and facing == "down" and dir.length() <= 0.1 and move_dir.length() <= 0.1 \
			and attacking <= 0.0 and not blocking and roll_t <= 0.0 and dash_t <= 0.0 \
			and not sneaking and not dead
		if not can_continue_cast:
			_stop_mage_cast_front()
	var visual_facing := _attack_visual_facing if attacking > 0.0 and _attack_visual_facing != "" else facing
	var d := "side" if visual_facing == "left" or visual_facing == "right" else visual_facing
	anim.flip_h = visual_facing == "left"
	var want := ""
	if attacking > 0.0:
		want = "attack_" + d
	elif dir.length() > 0.1:
		want = "walk_" + d
	else:
		want = "idle_" + d
	if anim.animation != want:
		anim.play(want)
	var tint := Color(1, 1, 1)
	if statuses.has("freeze"):
		tint = Color(0.7, 0.92, 1.0)
	elif statuses.has("burn"):
		tint = Color(1.0, 0.78, 0.62)
	elif statuses.has("poison"):
		tint = Color(0.78, 1.0, 0.72)
	if _hurt_t > 0.0:
		tint = Color(1, 0.5, 0.5)
	tint.a = 0.45 if (invuln > 0.0 and roll_t <= 0.0 and int(invuln * 10.0) % 2 == 0) else 1.0
	if sneaking:
		tint.a = min(tint.a, 0.55 if world.in_grass(global_position) else 0.78)
	anim.modulate = tint
	_feel(dir)
	if _mage_cast_front_active and is_instance_valid(cast_anim):
		cast_anim.position = anim.position
		cast_anim.scale = anim.scale * MAGE_CAST_FRONT_DISPLAY_SCALE
		cast_anim.modulate = anim.modulate


## Play the separately authored front-facing Mage casting clip after a successful spell.
## It is a visual one-shot only; spell damage, cooldowns and existing movement clips stay unchanged.
func _on_spell_cast(_spell_id: String) -> void:
	if _mage_cast_front_active or dead or Game.cls != "mage" or sheet != "mage_starter":
		return
	if facing != "down" or moving or move_dir.length() > 0.1 or blocking or sneaking:
		return
	if attacking > 0.0 or roll_t > 0.0 or dash_t > 0.0:
		return
	var frames := Sheets.mage_starter_cast_front_frames()
	if frames == null or not frames.has_animation("cast_front"):
		return
	if cast_anim == null:
		cast_anim = AnimatedSprite2D.new()
		cast_anim.name = "MageCastFront"
		cast_anim.centered = false
		cast_anim.sprite_frames = frames
		cast_anim.offset = Sheets.mage_starter_cast_front_offset()
		cast_anim.position = anim.position
		cast_anim.scale = anim.scale * MAGE_CAST_FRONT_DISPLAY_SCALE
		cast_anim.z_index = anim.z_index + 1
		cast_anim.animation_finished.connect(_on_mage_cast_front_finished)
		body.add_child(cast_anim)
	else:
		cast_anim.sprite_frames = frames
	cast_anim.frame = 0
	cast_anim.flip_h = false
	cast_anim.modulate = anim.modulate
	cast_anim.visible = true
	anim.visible = false
	_mage_cast_front_active = true
	cast_anim.play("cast_front")

func _on_mage_cast_front_finished() -> void:
	_stop_mage_cast_front()

func _stop_mage_cast_front() -> void:
	if not _mage_cast_front_active and cast_anim == null:
		return
	_mage_cast_front_active = false
	if is_instance_valid(cast_anim):
		cast_anim.stop()
		cast_anim.visible = false
	if is_instance_valid(anim):
		anim.visible = true

## squash, bob, breathing, the roll's spin and hop, footfall dust (VIS player animation)
func _feel(dir: Vector2) -> void:
	var dt := get_physics_process_delta_time()
	var sx := 1.0
	var sy := 1.0
	var oy := 0.0
	var rot := 0.0
	var now := Time.get_ticks_msec() / 1000.0
	if dir.length() > 0.1 and dash_t <= 0.0:
		# A restrained lean gives directional movement more weight without tilting the sprite off its feet.
		rot += clampf(dir.x * 0.04 + dir.y * 0.012, -0.045, 0.045)
		walk_ph += dt * 14.0
		oy = -abs(sin(walk_ph)) * 2.4
		sx = 1.0 + sin(walk_ph * 2.0) * 0.045
		sy = 1.0 - sin(walk_ph * 2.0) * 0.055
		_dust_t -= dt
		if _dust_t <= 0.0 and world and world.fx and not sneaking:
			_dust_t = 0.19
			world.fx.dust(global_position + Vector2(0, -2), 2, -facing_vec(), _footstep_dust_color())
	else:
		var b := sin(now / 0.62)
		sy = 1.0 + b * 0.022
		sx = 1.0 - b * 0.022
		oy = -b * 0.6
	if roll_t > 0.0:
		roll_t = max(0.0, roll_t - dt)
		var k: float = 1.0 - roll_t / 0.26
		rot = k * TAU * (-1.0 if facing == "left" else 1.0)
		oy -= sin(k * PI) * 7.0
		_ghost_t -= dt
		if _ghost_t <= 0.0 and world and world.fx:
			_ghost_t = 0.05
			var tc: Color = Game.Looks.trail(look)
			world.fx.ghost(anim, Color(tc, 0.55) if tc.a > 0.0 else Color(0.62, 0.86, 1.0, 0.5))
			var dash_col := Color(tc, 0.86) if tc.a > 0.0 else Color(0.62, 0.86, 1.0, 0.86)
			world.fx.dash_trail(global_position + Vector2(0, -17), dash_v.normalized(), dash_col, 0.18, 38.0)
	if caster and caster.spin_t > 0.0:
		rot = caster.spin_ang
	if _hurt_t > 0.0:
		sx *= 1.09
		sy *= 0.91
	if attacking > 0.0:
		# a short lunge-squash on the swing
		var a: float = attacking / 0.2
		sx *= 1.0 + 0.06 * a
		sy *= 1.0 - 0.05 * a
	anim.scale = Vector2(Sheets.SCALE * sx, Sheets.SCALE * sy)
	body.position = Vector2(0, -17 + oy)
	body.rotation = rot
	if shadow:
		Fx.lift_shadow(shadow, -oy * 2.0)

## Dust colour follows the ground so footfalls belong to the region without adding texture assets.
func _footstep_dust_color() -> Color:
	if world == null:
		return Color(0.62, 0.56, 0.47, 0.55)
	match world.key:
		"sanctum", "frostvale", "wyrmhollow":
			return Color(0.72, 0.86, 1.0, 0.58)
		"shadowfen":
			return Color(0.44, 0.68, 0.43, 0.52)
		"peaks", "damavand":
			return Color(0.72, 0.43, 0.28, 0.58)
		"emberforge":
			return Color(0.95, 0.48, 0.22, 0.62)
		"dungeon", "zahhakcave", "trial":
			return Color(0.58, 0.56, 0.62, 0.5)
		"forest", "camp":
			return Color(0.52, 0.62, 0.39, 0.52)
		_:
			return Color(0.72, 0.62, 0.48, 0.55)

## (v0.17) footsteps on the map's ground while the hero really moves (not into a wall, not mid-roll);
## faster steps when hasted, soft ones when sneaking
func _footsteps(dt: float, spd: float) -> void:
	if not moving or dash_t > 0.0 or get_real_velocity().length() < 25.0:
		_step_t = min(_step_t, 0.06)
		return
	_step_t -= dt * clamp(spd / Game.speed(), 0.5, 1.6)
	if _step_t <= 0.0:
		_step_t += 0.34
		Sfx.step(world.key, sneaking)

func _hazards(_hz: String, dt: float) -> void:
	var body := body_rect()
	for t in world.hazard_hits(body, dt):
		match t:
			"poison":
				take_hit(4.0)
				apply_status("poison", 3.0, 1.0)
				world.burst(global_position + Vector2(0, -24), Color(0.37, 0.75, 0.35), 5, 70.0)
			"ice":
				apply_status("freeze", 1.2, 1.0)
			_:
				take_hit(5.0)
				world.burst(global_position + Vector2(0, -24), Color(1, 0.54, 0.24), 5, 80.0)
				Sfx.play("trap", -6.0)
	if world.on_ice(body):
		apply_status("freeze", 0.3, 1.0)

# ---------------------------------------------------------------- status effects (as STATUS_DEFS in the HTML game)
func apply_status(type: String, sec: float, potency := 1.0) -> void:
	if dead or not STATUS.has(type):
		return
	if fire_t > 0.0:
		return          # nothing clings to one who walks in fire
	if statuses.has(type):
		var s: Dictionary = statuses[type]
		s["t"] = max(float(s["t"]), sec)
		s["p"] = max(float(s["p"]), potency)
	else:
		statuses[type] = {"t": sec, "p": potency, "tick": 0.0}
		Sfx.play("ice" if type == "freeze" else ("poison" if type == "poison" else "hurt"), -6.0)
		if world:
			world.burst(global_position + Vector2(0, -17), STATUS[type]["col"], 6, 70.0)
		Game.stats_changed.emit()

func clear_statuses() -> void:
	statuses.clear()
	Game.stats_changed.emit()

func _statuses(dt: float) -> void:
	if statuses.is_empty():
		return
	var gone := []
	for k in statuses:
		var s: Dictionary = statuses[k]
		s["t"] = float(s["t"]) - dt
		s["tick"] = float(s["tick"]) - dt
		var def: Dictionary = STATUS[k]
		if float(def["dmg"]) > 0.0 and float(s["tick"]) <= 0.0:
			s["tick"] = float(def["tick"])
			take_hit(float(def["dmg"]) * float(s["p"]), true)
		if float(s["t"]) <= 0.0:
			gone.append(k)
	for k in gone:
		statuses.erase(k)
	if not gone.is_empty():
		Game.stats_changed.emit()

## the point boss telegraphs test against (V18.pc: a little above the feet)
func pc() -> Vector2:
	return global_position + Vector2(0, -12)

func body_rect() -> Rect2:
	return Rect2(global_position - Vector2(13, 34), Vector2(26, 34))

## pushed by a boss attack: slides along walls and never through a map exit
func knock(v: Vector2) -> void:
	if dead or world == null:
		return
	var old := global_position
	move_and_collide(v)
	global_position = global_position.clamp(Vector2(13, 34), world.size - Vector2(13, 0))
	var r := body_rect()
	for a in get_tree().get_nodes_in_group("exits"):
		if a.has_meta("rect") and r.intersects(a.get_meta("rect")):
			global_position = old
			return

func _find_npc() -> void:
	var best: Node = null
	var bd := 52.0
	for n in get_tree().get_nodes_in_group("npcs"):
		var d: float = n.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = n
	near_npc = best

# ---------------------------------------------------------------- actions
func attack_press() -> void:
	attack()
	charging = true
	charge = 0.0

func attack_release() -> void:
	if charging and charge >= HEAVY_AT:
		attack(true)
	cancel_attack_charge()

## Cancel a held charge when input is interrupted by a pause, focus loss, or another system action.
## Unlike attack_release(), this never turns an interrupted hold into a heavy attack.
func cancel_attack_charge() -> void:
	charging = false
	charge = 0.0
	if charge_fx:
		charge_fx.visible = false

func attack(heavy := false) -> void:
	if dead or not _pending_attack.is_empty() or (atk_cd > 0.0 and not heavy) or caster.ult_active() or blocking:
		return
	atk_cd = (0.28 if not heavy else 0.45) * Game.atk_speed_mul()
	combo = combo + 1 if combo_t > 0.0 and not heavy else 0
	combo_t = 0.9
	var lv: int = min(combo, 3)
	var mult: float = (1.0 + lv * 0.15) * Game.melee_mul() * (2.2 * Game.heavy_mul() if heavy else 1.0) * caster.dmg_mul()
	var reach := 26.0 + lv * 3.0 + (14.0 if heavy else 0.0)
	# aim assist (v12): turn to the best target in reach and lunge a little if it is just too far
	var tgt := _pick_target(70.0)
	var aim := Vector2.ZERO
	if tgt:
		var to: Vector2 = tgt.center() - (global_position + Vector2(0, -17))
		facing = _dir_name(to)
		aim = to.normalized()
		var gap: float = to.length() - (max(tgt.box.x, tgt.box.y) * 0.5 + 13.0)
		if gap > 16.0:
			move_and_collide(to.normalized() * min(14.0, gap - 12.0))
			global_position = global_position.clamp(Vector2(13, 34), world.size - Vector2(13, 0))
	# Keep the attack direction visually locked through the wind-up and impact.
	var attack_direction := "side" if facing == "left" or facing == "right" else facing
	_attack_visual_facing = facing
	# Restart the clip even when the previous attack used the same direction.
	var attack_animation := "attack_" + attack_direction
	if anim.sprite_frames and anim.sprite_frames.has_animation(attack_animation):
		anim.stop()
		anim.animation = attack_animation
		anim.frame = 0
		anim.frame_progress = 0.0
		anim.play()
	var minimum_attack_time := 0.16 if not heavy else 0.26
	attacking = Sheets.animation_duration(anim.sprite_frames, "attack_" + attack_direction, minimum_attack_time, anim.speed_scale)
	var hero_meta: Dictionary = Game.manifest.get("heroes", {}).get(sheet, {})
	var impact_frame := int(hero_meta.get("heavyImpactFrame", hero_meta.get("attackImpactFrame", 0))) if heavy else int(hero_meta.get("attackImpactFrame", 0))
	var impact_delay := Sheets.animation_impact_time(anim.sprite_frames, "attack_" + attack_direction, impact_frame, anim.speed_scale)
	# Only show anticipation when this attack has a real delayed contact frame.
	# Legacy one-pose attacks still hit immediately and must not display a late wind-up cue.
	if impact_delay > 0.000001 and world != null and world.fx != null:
		world.fx.attack_windup(self, _facing_vector(facing), str(Game.cls), heavy, impact_delay)

	var sneak_attack := sneaking
	var attack_data := {
		"heavy": heavy,
		"reach": reach,
		"aim": aim,
		"facing": facing,
		"target": tgt,
		"multiplier": mult,
		"combo_level": lv,
		"sneak_attack": sneak_attack,
	}
	Sfx.play("heavy" if heavy else ("swing" if combo % 2 == 0 else "swing2"), -2.0)
	if impact_delay <= 0.000001:
		_resolve_attack_impact(attack_data)
	else:
		_pending_attack = attack_data
		_attack_impact_remaining = impact_delay

## Resolves the gameplay hit on the configured impact frame. Animation wind-up is visual only;
## legacy one-frame attacks have impact_frame 0 and therefore keep their immediate hit timing.
func _resolve_attack_impact(data: Dictionary) -> void:
	if dead or world == null or data.is_empty():
		return
	var heavy := bool(data.get("heavy", false))
	var reach := float(data.get("reach", 26.0))
	var aim: Vector2 = data.get("aim", Vector2.ZERO)
	var attack_facing := str(data.get("facing", "down"))
	var fv := _facing_vector(attack_facing)
	var multiplier := float(data.get("multiplier", 1.0))
	var lv := int(data.get("combo_level", 0))
	var sneak_attack := bool(data.get("sneak_attack", false))
	# Keep the hero hidden during the wind-up; the sneak ends on the contact frame.
	if sneak_attack:
		sneak_end()
	var body_c := global_position + Vector2(0, -17)
	var box := swing_box_for(body_rect(), attack_facing, reach)
	var tgt: Node = data.get("target")
	if is_instance_valid(tgt) and not tgt.dead and tgt.targetable() and _gap(body_rect(), tgt.hit_rect()) <= reach + 6.0:
		box = box.merge(tgt.hit_rect())
	world.slash(body_c + fv * 8.0, aim if aim != Vector2.ZERO else fv, reach + 10.0, heavy)
	if world.get("shrine"):
		world.shrine.strike(box, fv, heavy)
	if world.get("vault"):
		world.vault.strike(box, fv, heavy)
	if world.get("altars"):
		world.altars.strike(box, fv, heavy)
	if world.get("training"):
		world.training.strike(box, fv, heavy)

	var landed := false
	var any_crit := false
	var stabbed := false
	var impact_pos := body_c + fv * (reach * 0.72)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or not e.targetable():
			continue
		if box.intersects(e.hit_rect()):
			var crit := randf() < Game.crit_chance()
			var dmg: float = Game.atk() * multiplier * ((2.3 if Game.cls == "rogue" else 2.0) if crit else 1.0)
			if sneak_attack and not e.is_in_group("bosses") and not bool(e.get("alert")):
				dmg *= 3.0
				backstabs += 1
				Game.Ach.add("backstabs")
				stabbed = true
				world.float_text(e.global_position + Vector2(0, -e.box.y - 22), Game.t("Backstab!", "ضربهٔ از پشت!"), Color(1, 0.55, 0.35), true)
			e.hurt(dmg, crit, fv * (2.2 if heavy else 1.0), heavy)
			impact_pos = e.center()
			if crit:
				Game.Ach.add("crits")
			var steal := Gear.sum("lifesteal")
			if steal > 0.0:
				Game.hp = min(Game.max_hp(), Game.hp + dmg * steal)
			_procs(e)
			landed = true
			any_crit = any_crit or crit
	swings += 1
	if stabbed:
		Game.add_ult(4.0)
	if landed:
		hits_landed += 1
		if world.fx:
			world.fx.class_impact(impact_pos, fv, str(Game.cls), heavy)
		Game.mp = min(Game.max_mp(), Game.mp + Game.Skills.MP_PER_HIT)
		Game.add_ult(3.0 + (2.0 if heavy else 0.0) + (2.0 if any_crit else 0.0))
		Sfx.play("crit" if any_crit else "hit")
		world.hitstop(0.08 if heavy else (0.05 if any_crit else 0.028))
		if heavy or any_crit:
			world.shake(5.0 if heavy else 3.0)
			world.punch(aim if aim != Vector2.ZERO else fv, 8.0 if heavy else 6.0)
			Game.vibrate(28 if heavy else 20, 0.8)
		else:
			Game.vibrate(10, 0.45)
	if lv >= 2:
		world.float_text(body_c + Vector2(0, -30), Game.t("Combo x%d" % (lv + 1), "ترکیب ×%s" % Game.num(lv + 1)), Color(1, 0.82, 0.48))

func _tick_attack_impact(dt: float) -> void:
	if _pending_attack.is_empty():
		return
	if dead or world == null or blocking or (caster and (caster.busy() or caster.ult_active())):
		_cancel_pending_attack()
		return
	_attack_impact_remaining -= dt
	if _attack_impact_remaining <= 0.0:
		var data := _pending_attack
		_pending_attack = {}
		_attack_impact_remaining = 0.0
		if world != null and world.fx != null:
			world.fx.cancel_attack_windup(self)
		_resolve_attack_impact(data)

func _cancel_pending_attack() -> void:
	if world != null and world.fx != null:
		world.fx.cancel_attack_windup(self)
	if _pending_attack.is_empty():
		return
	_pending_attack = {}
	_attack_impact_remaining = 0.0
	attacking = 0.0
	_attack_visual_facing = ""

func _facing_vector(direction: String) -> Vector2:
	match direction:
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
		"up": return Vector2.UP
	return Vector2.DOWN

## the swing: a strip in front of the hero (as getAttackHitbox) plus the hero's own body, so an enemy
## standing right on top of you is hit too
func _swing_box(reach: float) -> Rect2:
	return swing_box_for(body_rect(), facing, reach)

## Pure combat geometry shared by runtime and regression tests. The hero's body
## remains hittable even when the forward reach is zero.
static func swing_box_for(body_bounds: Rect2, attack_facing: String, reach: float) -> Rect2:
	var safe_reach := maxf(0.0, reach)
	var strip: Rect2
	match attack_facing:
		"down": strip = Rect2(body_bounds.position.x - 3.0, body_bounds.end.y, body_bounds.size.x + 6.0, safe_reach)
		"up": strip = Rect2(body_bounds.position.x - 3.0, body_bounds.position.y - safe_reach, body_bounds.size.x + 6.0, safe_reach)
		"left": strip = Rect2(body_bounds.position.x - safe_reach, body_bounds.position.y - 3.0, safe_reach, body_bounds.size.y + 6.0)
		_: strip = Rect2(body_bounds.end.x, body_bounds.position.y - 3.0, safe_reach, body_bounds.size.y + 6.0)
	return strip.merge(body_bounds.grow(4.0))

static func _gap(a: Rect2, b: Rect2) -> float:
	var dx: float = max(0.0, max(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy: float = max(0.0, max(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(dx, dy).length()

## nearest enemy whose edge is within `reach` of the hero's centre (V12.pickTarget)
func _pick_target(reach: float) -> Node:
	var c := global_position + Vector2(0, -17)
	var best: Node = null
	var bd := reach
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or not e.targetable():
			continue
		var d: float = c.distance_to(e.center()) - max(e.box.x, e.box.y) * 0.5
		if d < bd:
			bd = d
			best = e
	return best

## weapon tiers set things alight or stun; the mage's blows can freeze (as damageEnemy in the HTML game)
func _procs(e: Node) -> void:
	if not is_instance_valid(e) or e.dead:
		return
	var w := int(Game.state.get("weapon", 1))
	if w >= 3 and randf() < 0.25:
		e.apply_status("burn", 2.5, 1.0)
	if w >= 5 and randf() < 0.2:
		e.apply_status("stun", 1.2, 1.0)
	if Game.cls == "mage" and randf() < 0.15:
		e.apply_status("freeze", 2.0, 1.0)
	if Gear.uniq("venom") and randf() < 0.25:
		e.apply_status("poison", 3.0, 1.0)
	if Gear.uniq("frostbite") and randf() < 0.18:
		e.apply_status("freeze", 2.0, 1.0)
	if Gear.uniq("emberfall") and (hits_landed + 1) % 5 == 0:
		_emberfall(e)

func dodge() -> void:
	if dead or dodge_cd > 0.0 or stamina < 30.0 or caster.busy():
		return
	_cancel_pending_attack()
	block_end()
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if joy.length() > 0.12:
		dir = joy
	if dir.length() < 0.1:
		dir = facing_vec()
	dir = dir.normalized()
	var iframes := 0.42 + Gear.sum("dodgeBonus")
	if Game.cls == "rogue":
		iframes = 0.58
	elif Game.cls == "mage":
		iframes = 0.32
	iframes += 0.1 * Game.talent("dodge_master")
	invuln = max(invuln, iframes)
	dodge_iframes = iframes
	rolls_n += 1
	dodge_cd = 0.8 * (1.0 - Gear.sum("dashCd"))
	stamina -= 30.0
	dash_t = 0.12
	dash_v = dir * 95.0 / 0.12
	roll_t = 0.26
	_ghost_t = 0.0
	if dir.length() > 0.1:
		facing = _dir_name(dir)
	Sfx.play("dodge")
	Game.Ach.add("dodges")
	if world.fx:
		world.fx.dust(global_position + Vector2(0, -2), 6, -dir, _footstep_dust_color())
		world.fx.emit("shine", global_position + Vector2(0, -12), 6, Color(0.66, 0.85, 0.63), -dir, 70.0, 80.0)

func drink() -> void:
	if dead or Game.hp >= Game.max_hp():
		return
	# a Greater Potion (+50) is drunk first, but only when the hero is missing enough for it not to be wasted
	var big: bool = int(Game.state.get("greater", 0)) > 0 and (Game.max_hp() - Game.hp >= 50.0 + floorf(Game.max_hp() * 0.3) * 0.8
		or int(Game.state.get("potions", 0)) <= 0)
	if not big and int(Game.state.get("potions", 0)) <= 0:
		return
	if big:
		Game.state["greater"] = int(Game.state["greater"]) - 1
	else:
		Game.state["potions"] = int(Game.state["potions"]) - 1
	if not Game.rush.is_empty():
		Game.rush["drank"] = int(Game.rush.get("drank", 0)) + 1      # (v0.21) "no potions" in the Boss Rush
	# (v0.27, design: "from level 15 the Greater Potion heals less than a plain one, costs four times as much and is drunk
	# first") it grows with the hero too
	var heal: float = (50.0 + floorf(Game.max_hp() * 0.3) if big else 20.0 + floorf(Game.max_hp() * 0.2)) + Gear.sum("potionBonus")
	Game.hp = min(Game.max_hp(), Game.hp + heal)
	world.float_text(global_position + Vector2(0, -40), "+%d" % int(heal), Color(1, 0.45, 0.55))
	Sfx.play("potion")
	if world.fx:
		world.fx.emit("shine", global_position + Vector2(0, -14), 14, Color(1, 0.55, 0.65), Vector2.UP, 50.0, 90.0)
		world.fx.ring(global_position + Vector2(0, -6), Color(1, 0.6, 0.7), 16.0, 0.4)
		world.fx.flash_light(global_position + Vector2(0, -17), 120.0, 0.7, Color(1, 0.6, 0.7), 0.5)
	Game.stats_changed.emit()

var _hurt_t := 0.0
var damage_taken := 0.0       # running totals, read by the boss-fight bot
var swings := 0
var hits_landed := 0

func _process(dt: float) -> void:
	_hurt_t = max(0.0, _hurt_t - dt)

func take_hit(raw: float, from_status := false) -> void:
	if dead or (invuln > 0.0 and not from_status):
		return
	if ward_t > 0.0 and not from_status:
		# the Simorgh's feather turns the blow, and feeds the ember
		ward_t = 0.0
		invuln = max(invuln, 0.6)
		Game.mp = min(Game.max_mp(), Game.mp + 10.0)
		# (v0.26, playtest: "against a common foe the feather is almost nothing") its light dazzles whoever stands near:
		# the Sage wins the breath a spell needs
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.dead or e.world != world or e.center().distance_to(global_position + Vector2(0, -17)) > 110.0:
				continue
			if e.is_in_group("bosses"):
				if e.has_method("add_stagger"):
					e.add_stagger(15.0)
			else:
				e.apply_status("stun", 1.6, 1.0)
		world.float_text(global_position + Vector2(0, -52), Game.Skills.sig_name() + "!", Color(1.0, 0.86, 0.5), true)
		Sfx.play("shield", -2.0)
		if world.fx:
			world.fx.ring(global_position + Vector2(0, -17), Color(1.0, 0.86, 0.5), 46.0, 0.4)
			world.fx.ring(global_position + Vector2(0, -17), Color(1.0, 0.95, 0.75), 110.0, 0.5)
			world.fx.emit("shine", global_position + Vector2(0, -17), 18, Color(1.0, 0.9, 0.6), Vector2.UP, 180.0, 160.0)
		Game.stats_changed.emit()
		return
	if caster and caster.spin_t > 0.0 and not from_status:
		raw *= 0.5
	var guarded := false
	if sneaking and not from_status:
		sneaking = false
	if blocking and not from_status:
		raw = _guard(raw)
		if raw <= 0.0:
			return
		guarded = blocking      # false when the guard just broke: the blow lands in full
	var dmg: int = Game.incoming(raw, world.key, from_status)
	Game.hp -= dmg
	if dmg > 0 and not Game.fight.is_empty():
		Game.fight["hurt"] = true        # (v0.20) "Untouched": a boss beaten without a scratch
	if not from_status and caster and not caster.ult_active():
		Game.add_ult(4.0)
	damage_taken += dmg
	if Gear.uniq("thorns") and not from_status:
		_thorns(dmg)
	if from_status and world.bossfx:
		world.bossfx.dmg_by["status"] = float(world.bossfx.dmg_by.get("status", 0.0)) + dmg
	if not from_status:
		invuln = 0.3 if guarded else 0.7
	var col := Color(1, 0.35, 0.35)
	if from_status:
		for k in statuses:
			col = STATUS[k]["col"]
	world.float_text(global_position + Vector2(0, -38), "-%d" % dmg, col)
	if not from_status:
		Sfx.play("hurt")
		world.shake(4.0)
		_hurt_t = 0.12
		world.punch(Vector2(randf_range(-1, 1), randf_range(-1, 1)), 5.0)
		if world.fx:
			world.fx.sparks(global_position + Vector2(0, -17), 7, Color(1, 0.42, 0.35))
			world.fx.ring(global_position + Vector2(0, -17), Color(1, 0.5, 0.44), 14.0, 0.26)
		Game.vibrate(35, 0.9)
	Game.stats_changed.emit()
	if Game.hp <= 0 and _revive_item():
		return
	if Game.hp <= 0:
		if world and world.has_method("reset_wind"):
			world.reset_wind()
		_cancel_pending_attack()
		dead = true
		charging = false
		charge_fx.visible = false
		velocity = Vector2.ZERO
		died.emit()

## (v0.21) between two memories of the Boss Rush: statuses gone, stamina and guard back, the ultimate kept, health as it is
func refresh_between() -> void:
	sneaking = false
	block_end()
	stamina = Game.max_stamina()
	guard_broken = 0.0
	caster.roar_t = 0.0
	caster.spin_t = 0.0
	caster.dance = {}
	body.rotation = 0.0
	invuln = 1.0
	statuses.clear()
	Game.stats_changed.emit()

func revive() -> void:
	dead = false
	sneaking = false
	shove_cd = 0.0
	ward_t = 0.0
	fire_t = 0.0
	block_end()
	stamina = Game.max_stamina()
	guard_broken = 0.0
	Game.hp = Game.max_hp()
	Game.mp = Game.max_mp()
	caster.roar_t = 0.0
	caster.spin_t = 0.0
	caster.dance = {}
	body.rotation = 0.0
	stamina = 100.0
	invuln = 1.5
	statuses.clear()
	if world and world.has_method("reset_wind"):
		world.reset_wind()
	Game.stats_changed.emit()


# ---------------------------------------------------------------- block and parry (v0.7)
func block_start() -> void:
	if dead or blocking or guard_broken > 0.0 or caster.busy() or caster.ult_active() or dash_t > 0.0:
		return
	if stamina < 8.0:
		return
	_cancel_pending_attack()
	blocking = true
	block_t = 0.0
	charging = false
	charge = 0.0
	charge_fx.visible = false
	Sfx.play("clank", -10.0, 0.2)
	world.tip("block", "Hold Block to take a third of the damage — raise it just before a blow lands for a perfect parry that staggers the foe.", "دکمهٔ سپر را نگه دار تا یک‌سوم آسیب بخوری — درست قبل از برخورد بزنش تا دفاعِ بی‌نقص شود و دشمن گیج شود.")

func block_end() -> void:
	blocking = false
	hold_block = false
	block_t = 0.0
	if block_fx:
		block_fx.visible = false

## the shield takes the blow: returns what is left of it (0 = nothing, a perfect parry)
func _guard(raw: float) -> float:
	var c := global_position + Vector2(0, -17)
	if block_t <= PARRY_WIN:
		parries += 1
		Game.Ach.add("parries")
		invuln = 0.3
		Sfx.play("crit", -2.0, 0.1)
		Sfx.play("clank", -3.0, 0.0)
		world.hitstop(0.09)
		world.shake(3.0)
		Game.vibrate(24, 0.8)
		Game.add_ult(8.0)
		Game.mp = min(Game.max_mp(), Game.mp + 4.0)
		stamina = min(Game.max_stamina(), stamina + 10.0)
		world.float_text(c + Vector2(0, -34), Game.t("Parry!", "دفاعِ بی‌نقص!"), Color(1, 0.9, 0.5), true)
		if world.fx:
			world.fx.sparks(c + facing_vec() * 16.0, 16, Color(1, 0.94, 0.69), facing_vec())
			world.fx.ring(c + facing_vec() * 12.0, Color(1, 0.9, 0.5), 20.0, 0.32)
			world.fx.flash_light(c, 110.0, 0.9, Color(1, 0.88, 0.5), 0.3)
		_parry_stagger()
		block_t = 0.0
		return 0.0
	var cost: float = max(8.0, raw * 1.1)
	if stamina < cost:
		# the guard breaks: the blow lands in full, the shield drops and cannot be raised for a moment
		stamina = 0.0
		guard_broken = 1.4
		block_end()
		Sfx.play("hurt", -3.0, 0.2)
		world.float_text(c + Vector2(0, -50), Game.t("Guard broken!", "سپر شکست!"), Color(1, 0.5, 0.4))
		return raw
	blocks += 1
	stamina -= cost
	invuln = 0.3
	Sfx.play("clank", -2.0, 0.1)
	world.shake(2.0)
	Game.vibrate(16, 0.6)
	if world.fx:
		world.fx.sparks(c + facing_vec() * 14.0, 8, Color(0.85, 0.9, 1.0), facing_vec())
	var through: float = raw * BLOCK_TAKEN * (1.0 - Gear.sum("blockBonus"))
	return through

## a perfect parry staggers whatever stands close: foes are stunned, a boss's stagger meter jumps
func _parry_stagger() -> void:
	var c := global_position + Vector2(0, -17)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or not e.targetable():
			continue
		if c.distance_to(e.center()) < 120.0:
			if e.has_method("add_stagger"):
				e.add_stagger(40.0)
			else:
				e.apply_status("stun", 1.1, 1.0)
	for b in get_tree().get_nodes_in_group("bosses"):
		if not b.dead and c.distance_to(b.global_position) < 260.0 and b.has_method("add_stagger"):
			b.add_stagger(40.0)

## the shield drawn in front of the hero: an arc that flares gold during the parry window
func _block_visual() -> void:
	if block_fx == null:
		return
	block_fx.visible = blocking
	if not blocking:
		return
	var fv := facing_vec()
	block_fx.rotation = fv.angle()
	var gold := block_t <= PARRY_WIN
	var col := Color(1, 0.9, 0.5, 0.95) if gold else Color(0.75, 0.85, 1.0, 0.75)
	if block_fx.get_child_count() == 0:
		var arc := Line2D.new()
		arc.width = 4.0
		for i in 13:
			arc.add_point(Vector2.from_angle(lerpf(-0.9, 0.9, i / 12.0)) * 22.0)
		block_fx.add_child(arc)
	(block_fx.get_child(0) as Line2D).default_color = col


# ---------------------------------------------------------------- sneak and shove (v0.7)
func toggle_sneak() -> void:
	if dead or caster.busy() or caster.ult_active():
		return
	sneaking = not sneaking
	if sneaking:
		charging = false
		charge = 0.0
		charge_fx.visible = false
		world.tip("sneak", "Sneaking: you walk slower but foes notice you only from close by — tall grass and night help. Strike an unaware foe for a triple-damage backstab.", "پنهان‌روی: آهسته‌تر راه می‌روی ولی دشمن فقط از نزدیک می‌بیندت — علف بلند و شب کمک می‌کنند. دشمن بی‌خبر را بزن تا سه‌برابر آسیب ببیند.")
	world.float_text(global_position + Vector2(0, -42), Game.t("Sneaking", "پنهان‌روی") if sneaking else Game.t("Visible", "آشکار"), Color(0.75, 0.9, 0.7))

func sneak_end() -> void:
	sneaking = false

## how far foes can see the hero, as a share of their normal range (1.0 = normal)
func stealth_mul() -> float:
	if not sneaking or world == null:
		return 1.0
	var m := 0.45
	if world.in_grass(global_position):
		m *= 0.6
	if Game.phase() == 3 and not Game.indoor(world.key):
		m *= 0.8
	return max(0.18, m)

# ---------------------------------------------------------------- the calling's own move (v0.26)
func signature() -> void:
	var s: Dictionary = Game.Skills.sig()
	if dead or shove_cd > 0.0 or stamina < float(s["sta"]) or caster.busy() or caster.ult_active() or attacking > 0.0 or dash_t > 0.0:
		return
	stamina -= float(s["sta"])
	shove_cd = float(s["cd"])
	sig_uses += 1
	var c := global_position + Vector2(0, -17)
	var col: Color = s["col"]
	match str(s["id"]):
		"lasso":
			_lasso(c, col)
		"ward":
			ward_t = 6.0
			Sfx.play("quest", -6.0, 0.1)
			if world.fx:
				world.fx.ring(c, col, 40.0, 0.5)
				world.fx.emit("shine", c, 14, col, Vector2.UP, 30.0, 110.0)
		"arrow":
			var dir: Vector2 = caster.aim_dir(380.0)
			facing = _dir_name(dir)
			var hidden := sneaking
			var dmg: float = Game.atk() * Game.melee_mul() * 1.3 * (3.0 if hidden else 1.0)
			if hidden:
				sneak_end()
				world.float_text(c + Vector2(0, -34), Game.t("From hiding!", "از نهان!"), Color(0.8, 1.0, 0.7))
			if world.get("spells") and world.spells:
				world.spells.shoot("arrow", c + dir * 14.0, dir, {"speed": 760.0, "range": 460.0, "col": col, "size": 0.9}, dmg)
			Sfx.play("swing", -3.0, 0.15)
		"fire":
			fire_t = 4.0
			_fire_tick = 0.0
			clear_statuses()
			Sfx.play("bolt", -4.0, 0.1)
	world.float_text(c + Vector2(0, -46), Game.Skills.sig_name(), col.lightened(0.25), true)
	Game.vibrate(14, 0.6)
	if world.get("training") and world.training:
		world.training.on_sig()

## Rostam's lasso: the nearest foe ahead (within 230) is dragged to the hero's feet and stunned; a boss only staggers
func _lasso(c: Vector2, col: Color) -> void:
	var dir: Vector2 = caster.aim_dir(230.0)
	facing = _dir_name(dir)
	attacking = 0.15
	var best: Node = null
	var best_d := 240.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or not e.targetable():
			continue
		var to: Vector2 = e.center() - c
		var d: float = to.length() - max(e.box.x, e.box.y) * 0.4
		if d < best_d and (d < 40.0 or to.normalized().dot(dir) > 0.75):
			best = e
			best_d = d
	Sfx.play("swing", -2.0, 0.1)
	if best == null:
		if world.get("spells") and world.spells:
			world.spells.tether(c, c + dir * 200.0, col, 0.25)
		return
	if world.get("spells") and world.spells:
		world.spells.tether(c, best.center(), col, 0.4)
	if best.is_in_group("bosses"):
		if best.has_method("add_stagger"):
			best.add_stagger(20.0)
	else:
		var pull: Vector2 = (c - best.center())
		best.knock = pull.normalized() * clamp((pull.length() - 40.0) * 7.0, 0.0, 1100.0) * best.knock_mult
		best.apply_status("stun", 1.2, 1.0)
	Sfx.play("heavy", -5.0, 0.1)
	world.shake(2.5)

func _sig_step(dt: float) -> void:
	if ward_t > 0.0:
		ward_t = max(0.0, ward_t - dt)
		if world.fx and Engine.get_physics_frames() % 12 == 0:
			world.fx.emit("shine", global_position + Vector2(0, -20), 2, Color(1.0, 0.86, 0.5), Vector2.UP, 16.0, 50.0)
	if fire_t > 0.0:
		fire_t = max(0.0, fire_t - dt)
		# (v0.26, playtest: "the ring is faint") the fire stays on the ground between its bites
		if world.fx and Engine.get_physics_frames() % 10 == 0:
			world.fx.ring(global_position + Vector2(0, -17), Color(1.0, 0.5, 0.2), 74.0, 0.3)
			world.fx.emit("shine", global_position + Vector2(0, -8) + Vector2.RIGHT.rotated(randf() * TAU) * 60.0, 2, Color(1.0, 0.6, 0.25), Vector2.UP, 30.0, 70.0)
		_fire_tick -= dt
		if _fire_tick <= 0.0:
			_fire_tick = 1.0
			var c := global_position + Vector2(0, -17)
			caster.aoe(c, 74.0, Game.atk() * Game.melee_mul() * 0.6, "burn", 2.0)
			if world.fx:
				world.fx.ring(c, Color(1.0, 0.6, 0.3), 74.0, 0.45)
				world.fx.emit("shine", c, 10, Color(1.0, 0.55, 0.25), Vector2.UP, 40.0, 120.0)

## a short, hard shove: foes in front of the hero fly back and are stunned (a boss only loses some stagger);
## it also works with the shield up
func shove() -> void:
	if dead or shove_cd > 0.0 or stamina < 15.0 or caster.busy() or caster.ult_active() or attacking > 0.0 or dash_t > 0.0:
		return
	stamina -= 15.0
	sneaking = false
	attacking = 0.12
	var fv := facing_vec()
	var box := _swing_box(30.0)
	var c := global_position + Vector2(0, -17)
	var hit := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or not e.targetable() or not box.intersects(e.hit_rect()):
			continue
		hit = true
		if e.is_in_group("bosses"):
			if e.has_method("add_stagger"):
				e.add_stagger(12.0)
			knock(-fv * 6.0)
		else:
			e.knock = fv * 620.0 * e.knock_mult
			e.apply_status("stun", 0.8, 1.0)
		if world.fx:
			world.fx.sparks(e.center(), 8, Color(1, 0.94, 0.8), fv)
	shoves += 1
	if hit:
		shove_cd = 2.2
		Sfx.play("heavy", -4.0, 0.1)
		world.shake(3.0)
		world.hitstop(0.04)
		Game.vibrate(18, 0.7)
		world.float_text(c + Vector2(0, -34), Game.t("Shove!", "هل!"), Color(1, 0.9, 0.7))
	else:
		shove_cd = 0.8
		Sfx.play("swing", -6.0, 0.2)
	if world.fx:
		world.fx.ring(c + fv * 18.0, Color(1, 0.94, 0.8), 14.0, 0.2)


# ---------------------------------------------------------------- gear effects (v0.10)
## Emberheart of Mazandaran's relic: a third of the blow goes back at the nearest foe
func _thorns(dmg: float) -> void:
	var best = null
	var bd := 90.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead and e.targetable():
			var d: float = e.center().distance_to(global_position + Vector2(0, -17))
			if d < bd:
				bd = d
				best = e
	if best != null:
		best.hurt(max(1.0, dmg * 0.3), false, (best.center() - global_position).normalized())
		if world.fx:
			world.fx.sparks(best.center(), 6, Color(1, 0.6, 0.3))

## Puladvand's relic: every fifth blow erupts in flame around the foe it struck
func _emberfall(at: Node) -> void:
	var c: Vector2 = at.center()
	if world.fx:
		world.fx.ring(c, Color(1, 0.5, 0.2), 30.0, 0.4)
		world.fx.sparks(c, 14, Color(1, 0.55, 0.2))
	world.float_text(c + Vector2(0, -30), Game.t("Emberfall!", "سقوط اخگر!"), Color(1, 0.55, 0.25))
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead and e.targetable() and e.center().distance_to(c) < 60.0:
			e.hurt(Game.atk() * 0.8, false, Vector2.ZERO)
			e.apply_status("burn", 2.5, 1.0)

## a Simurgh's Feather saves the hero once: it burns up in the fire
func _revive_item() -> bool:
	var e := Gear.eq()
	for slot in e:
		var it = e[slot]
		if typeof(it) == TYPE_DICTIONARY and str(it.get("stat", {}).get("key", "")) == "revive":
			e.erase(slot)
			Game.hp = Game.max_hp() * 0.6
			invuln = 2.0
			world.float_text(global_position + Vector2(0, -48), Game.t("Revived!", "زنده شدی!"), Color(1, 0.8, 0.4), true)
			Sfx.play("quest")
			if world.fx:
				world.fx.ring(global_position + Vector2(0, -17), Color(1, 0.7, 0.3), 40.0, 0.6)
			Game.stats_changed.emit()
			return true
	return false


# ---------------------------------------------------------------- scrolls (v0.11)
func use_scroll() -> void:
	if dead or caster.busy() or caster.ult_active():
		return
	var id := Game.scroll_sel()
	if id == "":
		return
	var c := global_position + Vector2(0, -17)
	match id:
		"fire":
			if not Game.spend_scroll(id):
				return
			caster.cast_free("bolt", 1.4)
		"frost":
			if not Game.spend_scroll(id):
				return
			caster.cast_free("icelance", 1.8)
		"ice":
			var tgt = _scroll_target()
			if tgt == null:
				world.float_text(global_position + Vector2(0, -46), Game.t("No target", "هدفی نیست"), Color(0.8, 0.85, 1.0))
				return
			Game.spend_scroll(id)
			tgt.apply_status("freeze", 3.0, 1.0)
			Sfx.play("ice", -4.0)
			if world.fx:
				world.fx.ring(tgt.center(), Color(0.6, 0.85, 1.0), 26.0, 0.5)
				world.fx.sparks(tgt.center(), 12, Color(0.7, 0.9, 1.0))
		"regen":
			Game.spend_scroll(id)
			regen_t = 8.0
			Sfx.play("potion")
			world.float_text(global_position + Vector2(0, -46), Game.t("Regeneration", "بازسازی"), Color(0.5, 1.0, 0.6))
			if world.fx:
				world.fx.ring(c, Color(0.5, 1.0, 0.6), 22.0, 0.5)
		"haste":
			Game.spend_scroll(id)
			haste_t = 8.0
			Sfx.play("dash", -4.0)
			world.float_text(global_position + Vector2(0, -46), Game.t("Haste", "شتاب"), Color(1.0, 0.9, 0.45))
			if world.fx:
				world.fx.ring(c, Color(1.0, 0.9, 0.45), 22.0, 0.5)
	if Game.scroll_count(id) == 0:
		Game.state["scroll_sel"] = ""

func _scroll_target():
	var best = null
	var bd := 420.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead and e.targetable():
			var d: float = e.center().distance_to(global_position + Vector2(0, -17))
			if d < bd:
				bd = d
				best = e
	return best
