extends "res://scripts/enemy.gd"
## v18 bosses (port of v18_core.js + v18_bosses.js).
## Framework, for every boss and miniboss: a stagger meter (heavy blows, perfect dodges, crashes and
## ice/stun fill it; a staggered boss is helpless and takes +50%), phase changes at 66% / 33% with an
## invulnerable roar and a shockwave, telegraphed attacks only (bumping into a rebuilt boss just grazes).
## The four story bosses each get their signature moves:
##   Guardian  — sweep, a charge you bait into walls or his pillars, bolt rings, grave pillars, eclipse
##   Colossus  — magma armour (half damage) until an eruption vents his core; fist + fissures, stomp, boulders
##   Sorceress — dives under the mud and bursts out beneath you, eggs that hatch, tongue pull, poison pool, spit
##   White Div   — ice-lance lines, leap, bolt storm, ice echoes (break both fast = big stagger), hail
## Anvil Warden — three parallel forge furrows with dodgeable gaps, alongside its slam and charge.
## Other minibosses (Bid the Div, Ashkbus) and Puladvand keep a generic telegraphed kit.
## (v0.19, chapter 2 — mine):
##   Akvan the Div — ground slam, a frost wave you must roll through, icicles from above, a charge you bait into the
##                   spires; at half health it calls icelings from the snow and hurls ice boulders
##   Dragon of Kashaf  — frost breath (a cone in front), tail sweep (around it), a ring of ice shards, a lunge into the walls;
##                   phase II spreads its wings: it takes to the air and dives on your shadow, beats a gust of icicles,
##                   calls wyrmlings; the final phase sweeps its breath across the lair and brings a hailstorm
## (v0.23, chapter 3 — mine, from the Shahnameh):
##   Zahhak        — the serpent-shouldered king, chained beneath Damavand: his two serpents bite along lanes (both
##                   at once from phase II, three bites in a row in the last), venom that leaves poison on the ground,
##                   a sword sweep, the chains lashing out as a shockwave, rocks shaken from the cave roof; he calls
##                   his serpents. The chains hold him near his lair: one breaks at each phase, and his reach grows.

const STAG_MAX := 100.0

var cfg := {}
var reworked := false
var mini := false
var rgb := Color(1, 0.8, 0.5)
var bfx: Node = null
# stagger / phases
var stag := 0.0
var staggered := 0.0
var res := 1.0
var inv := 0.0
var ph := 1
var last_gain := 0.0
var engaged := false
var cc := {}
var n_stag := 0
var fight_t := 0.0
var phase_at := {1: 0.0}
# brain
var busy := 0.0
var motion := {}
var cd := {}
var gcd := 1.2
var windup := false
var moves := {}
var last_move := ""
var graze_cd := 0.0
var imm_t := 0.0
var knock_t := 0.0
var knock_v := Vector2.ZERO
var face_x := 1.0
# Gale Warden attack animation: open wings, lift for the telegraph, strike, then fold into recovery.
var warden_pose_step := -1
var warden_pose_t := 0.0

func _warden_pose_start(anticipation: float) -> void:
	if type != "alborzwarden" or anim == null or anim.sprite_frames == null or not anim.sprite_frames.has_animation("v0"):
		return
	warden_pose_step = 0
	warden_pose_t = maxf(0.05, anticipation)
	anim.stop()
	anim.animation = "v0"
	anim.frame = 1

func _warden_pose_tick(dt: float) -> void:
	if type != "alborzwarden" or warden_pose_step < 0 or anim == null:
		return
	warden_pose_t -= dt
	if warden_pose_t > 0.0:
		return
	match warden_pose_step:
		0:
			warden_pose_step = 1
			warden_pose_t = 0.18
			anim.frame = 2
		1:
			warden_pose_step = 2
			warden_pose_t = 0.54
			anim.frame = 3
		_:
			warden_pose_step = -1
			warden_pose_t = 0.0
			anim.play("v0")
			anim.frame = 0
# per-boss state
var cloaked := false
var shadow_on := false
var shadow := Vector2.ZERO
var shield := 0
var armor := false
var dazed := 0.0
var heat := -1.0
var vent := 0.0
var vent_t := 2.6
var burn_bonus := 1.0
var pillars: Array = []
var over: Node2D
var minions: Array = []            # (v0.19) Akvan's icelings, the Wyrm's wyrmlings

func _after_setup() -> void:
	cfg = Game.boss_cfg(type)
	reworked = bool(cfg.get("rework", false))
	mini = bool(cfg.get("mini", false))
	rgb = cfg.get("rgb", rgb)
	bfx = world.bossfx
	add_to_group("bosses")
	own_bar = false
	if bar_bg:
		bar_bg.visible = false
	# HTML enemies collide with walls using their whole w x h body (entRect); the arenas' columns and
	# walls were laid out for that, and charges crash into them — so bosses use the full body here too
	for ch in get_children():
		if ch is CollisionShape2D:
			ch.shape.size = box
			ch.position = Vector2(0, -box.y * 0.5)
	over = Node2D.new()
	over.z_index = 2
	over.draw.connect(_draw_over)
	add_child(over)
	if type == "boss2":
		heat = 100.0
		cd["erupt"] = 9.0
	if type == "arbiter":
		burn_bonus = 1.3

func targetable() -> bool:
	return not dead and not cloaked

func player() -> Node:
	return get_tree().get_first_node_in_group("player")

# ================================================================ framework
func add_stagger(amt: float) -> void:
	if dead or staggered > 0.0 or inv > 0.0 or cloaked:
		return
	stag = min(STAG_MAX, stag + amt / res)
	last_gain = 2.5
	if stag >= STAG_MAX:
		stagger()

func stagger(sec := 0.0, label := "") -> void:
	n_stag += 1
	staggered = sec if sec > 0.0 else (2.6 if mini else 3.2)
	stag = 0.0
	res = min(1.6, res + 0.2)
	motion = {}
	busy = 0.0
	windup = false
	var text := label if label != "" else Game.t("STAGGERED!", "گیج شد!")
	if not has_node("Arzhang3D"):
		world.float_text(global_position + Vector2(0, -box.y - 24), text, Color(1, 0.88, 0.54), true)
	world.burst(center(), Color(1, 0.88, 0.54), 18, 150.0)
	world.shake(8.0)
	Sfx.play("crit")
	Sfx.play("stun", -2.0)
	if not has_node("Arzhang3D"):
		world.tip("stagger", "Staggered! It takes 50% more damage for a moment — strike now.", "گیج شد! چند لحظه ۵۰٪ آسیب بیشتر می‌خورد — حالا بزن.")

func _cc_ready(kind: String) -> bool:
	if float(cc.get(kind, 0.0)) > 0.0:
		return false
	cc[kind] = 1.2
	return true

## ice and stun never lock a boss: they feed the stagger meter (fire too, if the boss is weak to it)
func apply_status(kind: String, sec: float, potency := 1.0) -> void:
	if dead:
		return
	var weak: Dictionary = cfg.get("weak", {})
	if kind == "freeze" or kind == "stun":
		if not _cc_ready(kind):
			return
		add_stagger((22.0 if kind == "stun" else 18.0) * float(weak.get(kind, 1.0)))
		if kind == "freeze" and heat >= 0.0:
			heat = max(0.0, heat - 45.0)
			world.burst(center(), Color(0.75, 0.94, 1.0), 10, 100.0)
		return
	super.apply_status(kind, sec, potency)
	if kind == "burn" and float(weak.get("burn", 1.0)) > 1.0 and _cc_ready("burn"):
		add_stagger(14.0 * float(weak["burn"]))

func hurt(amount: float, crit: bool, from_dir: Vector2, heavy := false) -> void:
	if dead:
		return
	if parley and world and world.has_method("truce_broken"):
		world.truce_broken()
	if inv > 0.0 or cloaked:
		if imm_t <= 0.0:
			imm_t = 0.6
			world.float_text(global_position + Vector2(0, -box.y - 10), Game.t("Immune", "آسیب‌ناپذیر"), Color(0.78, 0.78, 0.85))
			Sfx.play("shield", -4.0)
		return
	var mult := 1.0
	if staggered > 0.0:
		mult *= 1.5
	if shield > 0:
		mult *= max(0.55, 1.0 - 0.15 * shield)      # (v0.23, playtest) a little gentler: 15% a pillar, at most 45%
	if armor:
		mult *= 0.5
	if dazed > 0.0:
		mult *= 1.3
	if burn_bonus > 1.0 and has_status("burn"):
		mult *= burn_bonus
	super.hurt(amount * mult, crit or staggered > 0.0, from_dir, heavy)
	# the HTML knock: 6 px/frame x knockMult for 120 ms, during which the AI sits out
	knock = Vector2.ZERO
	if from_dir.length() > 0.01 and knock_mult > 0.0:
		knock_v = from_dir.normalized() * 6.0 * Game.PXS * knock_mult * (1.4 if heavy else 1.0)
		knock_t = 0.12
	if not dead:
		var g := 10.0 if heavy else 1.25
		if busy > 0.0 and windup:
			g += 8.0 if heavy else 0.8
		if dazed > 0.0:
			g *= 1.8
		add_stagger(g)
	if shield > 0 and not has_node("Arzhang3D") and not dead and randf() < 0.25:       # (v0.24, playtest: it still said so over his body)
		world.float_text(global_position + Vector2(0, -box.y - 2), Game.t("Shielded — break the pillars", "سپر دارد — ستون‌ها را بشکن"), Color(0.72, 0.56, 1.0))

func _check_phase() -> void:
	var th: Array = cfg.get("phases", [])
	if th.is_empty() or dead:
		return
	var f := hp / max_hp
	var want := 1
	for x in th:
		if f <= float(x):
			want += 1
	if want <= ph:
		return
	ph = want
	phase_at[ph] = fight_t
	# (v0.32) each later phase its own row when the sheet has one (Puladvand: phase III); otherwise the last row stays
	set_variant(ph - 1)
	if cloaked:
		if shadow_on:
			global_position = shadow + Vector2(0, box.y * 0.15)
		_set_hidden(false)
		shadow_on = false
		_unstick()
	inv = 1.5
	staggered = 0.0
	stag = 0.0
	motion = {}
	busy = 0.9
	windup = false
	bfx.clear()
	world.shake(12.0)
	Sfx.play("phase")
	Sfx.play("roar", -3.0)
	var phase_center := center()
	world.burst(phase_center, rgb, 30, 190.0)
	# A clear two-beat seal marks the transformation; low graphics keeps the outer ring only.
	if world.fx:
		var rich_fx: bool = world.fx.quality > 0
		world.fx.ring(phase_center, Color(rgb, 0.9), maxf(box.x, box.y) * 0.9, 0.62)
		if rich_fx:
			world.fx.ring(phase_center, Color(1.0, 0.94, 0.76, 0.82), maxf(box.x, box.y) * 0.56, 0.44)
		world.fx.emit("shine", phase_center, 16 if rich_fx else 8, Color(rgb, 0.95),
			Vector2.UP, 180.0, 150.0, 1.2 if rich_fx else 0.85)
		if rich_fx:
			world.fx.flash_light(phase_center, maxf(box.x, box.y) * 2.2, 0.85, rgb, 0.48)
	var p := player()
	if p:
		var off: Vector2 = p.pc() - center()
		if off.length() < 150.0:
			bfx.knock(off.normalized() * 55.0)
	world.banner.emit(Game.t("Phase II", "مرحلهٔ دوم") if ph == 2 else Game.t("Final phase", "واپسین مرحله"), Game.boss_name(type), rgb, 1.8)

func _engage() -> void:
	engaged = true
	world.boss_engaged.emit(self)

func _set_hidden(h: bool) -> void:
	cloaked = h
	if anim:
		anim.visible = not h
	if drop_shadow:
		drop_shadow.visible = not h

## a boss that reappears (eclipse, dive) may land inside a wall: push it out the short way
func _unstick() -> void:
	var sz := box
	for k in 4:
		var moved := false
		for w in world.wall_rects:
			var r := Rect2(global_position - Vector2(sz.x * 0.5, sz.y), sz)
			if not r.intersects(w):
				continue
			var pl: float = r.end.x - w.position.x
			var pr: float = w.end.x - r.position.x
			var pu: float = r.end.y - w.position.y
			var pd: float = w.end.y - r.position.y
			var m: float = min(min(pl, pr), min(pu, pd))
			if m == pl:
				global_position.x -= pl + 1.0
			elif m == pr:
				global_position.x += pr + 1.0
			elif m == pu:
				global_position.y -= pu + 1.0
			else:
				global_position.y += pd + 1.0
			moved = true
		if not moved:
			break
	_clamp()

func _clamp() -> void:
	global_position = global_position.clamp(Vector2(box.x * 0.5, box.y), world.size - Vector2(box.x * 0.5, 0))

# ================================================================ update
## (v0.26, the critic: "Arzhang's echo is as solid as any foe; nothing on screen says echo") the five foes Rostam once
## slew drag a pale after-image: close behind when they move, drifting off them when they stand
var _echo_t := 0.0
func _echo_look(dt: float) -> void:
	if has_node("Arzhang3D") or not bool(cfg.get("echo", false)) or anim == null or world == null or world.fx == null or world.fx.quality == 0:
		return
	_echo_t -= dt
	if _echo_t > 0.0:
		return
	var moving: bool = velocity.length() > 24.0
	_echo_t = 0.12 if moving else 0.5
	var tex: Texture2D = anim.sprite_frames.get_frame_texture(anim.animation, anim.frame) if anim.sprite_frames else null
	if tex == null:
		return
	var g := Sprite2D.new()
	g.texture = tex
	g.centered = anim.centered
	g.offset = anim.offset
	g.flip_h = anim.flip_h
	g.modulate = Color(0.72, 0.9, 1.0, 0.42 if moving else 0.5)
	g.z_index = -1
	world.ysort.add_child(g)
	g.global_transform = anim.global_transform
	var life := 0.42 if moving else 0.9
	var tw := g.create_tween().set_parallel(true)
	tw.tween_property(g, "modulate:a", 0.0, life)
	if not moving:
		tw.tween_property(g, "position", g.position + Vector2((1.0 if randf() < 0.5 else -1.0) * randf_range(12.0, 22.0), randf_range(-10.0, -2.0)), life)
	tw.chain().tween_callback(g.queue_free)

func _physics_process(dt: float) -> void:
	if dead:
		return
	if parley:
		_flash(dt)
		velocity = Vector2.ZERO
		move_and_slide()
		return
	_flash(dt)
	_hover(dt)
	if type == "boss":
		shield = _alive_pillars()
	_echo_look(dt)
	hit_cd = max(0.0, hit_cd - dt)
	imm_t = max(0.0, imm_t - dt)
	if engaged:
		fight_t += dt
	if last_gain > 0.0:
		last_gain -= dt
	elif stag > 0.0:
		stag = max(0.0, stag - 6.0 * dt)
	if inv > 0.0:
		inv -= dt
	for k in cc:
		cc[k] = float(cc[k]) - dt
	if dazed > 0.0:
		dazed -= dt
	if not cloaked:
		_estatus(dt)
		if dead:
			return
	var p := player()
	if not engaged and p and not p.dead:
		if (p.global_position + Vector2(0, -17)).distance_to(center()) < (260.0 if mini else 330.0):
			_engage()
	over.queue_redraw()
	if staggered > 0.0 or inv > 0.0:
		if staggered > 0.0:
			staggered -= dt
			if staggered <= 0.0:
				staggered = 0.0
				if not has_node("Arzhang3D"):
					world.float_text(global_position + Vector2(0, -box.y - 18), Game.t("Recovers", "به خود آمد"), Color(0.78, 0.78, 0.85))
		if knock_t > 0.0:
			knock_t -= dt
			_step(knock_v * 0.3)
		_check_phase()
		_clamp()
		return
	if knock_t > 0.0:
		knock_t -= dt
		_step(knock_v)
		_check_phase()
		_clamp()
		return
	if p == null or p.dead:
		velocity = Vector2.ZERO
		return
	var to: Vector2 = (p.global_position + Vector2(0, -17)) - center()
	var d: float = max(1.0, to.length())
	match type:
		"boss": _ai_guardian(dt, d, to)
		"boss2": _ai_colossus(dt, d, to)
		"matriarch": _ai_matriarch(dt, d, to)
		"arbiter": _ai_arbiter(dt, d, to)
		"glaciertitan": _ai_titan(dt, d, to)
		"ancientwyrm": _ai_wyrm(dt, d, to)
		"zahhak": _ai_zahhak(dt, d, to)
		"alborzwarden": _ai_alborz(dt, d, to)
		_: _ai_generic(dt, d, to)
	_check_phase()
	_clamp()
	if anim:
		anim.flip_h = face_x < 0.0

func _step(v: Vector2) -> void:
	velocity = v
	move_and_slide()

func _face(dx: float) -> void:
	if abs(dx) > 2.0:
		face_x = sign(dx)

func _chase(to: Vector2, d: float, k := 1.0, keep := 0.0) -> void:
	if d < keep:
		velocity = Vector2.ZERO
		return
	_step(to / d * spd * k)

func _ready_move(m: String) -> bool:
	return float(cd.get(m, 0.0)) <= 0.0

func _use(m: String, cooldown: float, global_cd := -1.0) -> void:
	cd[m] = cooldown
	gcd = global_cd if global_cd >= 0.0 else 0.55 + randf() * 0.4
	moves[m] = int(moves.get(m, 0)) + 1
	last_move = m
	windup = true

## shared bookkeeping; returns true while the boss is busy (moving in a motion or recovering)
func _brain(dt: float) -> bool:
	for k in cd:
		cd[k] = float(cd[k]) - dt
	if gcd > 0.0:
		gcd -= dt
	if graze_cd > 0.0:
		graze_cd -= dt
	var p := player()
	if reworked:
		# bumping into a rebuilt boss only grazes: the damage lives in its telegraphed attacks
		if not cloaked and motion.is_empty() and graze_cd <= 0.0 and hit_rect().intersects(p.body_rect()):
			bfx.cur_src = "graze"
			bfx.hit(self, 0.25, [], true)
			bfx.cur_src = ""
			graze_cd = 1.5
	elif not cloaked and hit_cd <= 0.0 and hit_rect().intersects(p.body_rect()):
		_contact(p)
		hit_cd = 0.9
	if not motion.is_empty():
		if _motion_step(dt):
			motion = {}
		return true
	if busy > 0.0:
		busy -= dt
		if busy <= 0.0:
			windup = false
		velocity = Vector2.ZERO
		return true
	return false

# ---------------------------------------------------------------- motions (dash, dive, tongue pull)
## a straight dash that crashes into walls (or grave pillars) and staggers the dasher
func _dash(ang: float, speed: float, sec: float, mult: float, crash := "stagger") -> void:
	motion = {"kind": "dash", "v": Vector2.from_angle(ang) * speed * Game.PXS, "t": sec, "hit": false, "mult": mult, "crash": crash}

func _motion_step(dt: float) -> bool:
	var m := motion
	var p := player()
	match str(m["kind"]):
		"dash":
			m["t"] = float(m["t"]) - dt
			var o := global_position
			var v: Vector2 = m["v"]
			_step(v)
			_clamp()
			if randf() < 0.5:
				world.burst(global_position, Color(0.78, 0.72, 0.66), 1, 40.0)
			if not m["hit"] and hit_rect().intersects(p.body_rect()):
				m["hit"] = true
				bfx.cur_src = last_move + ":dash"
				var landed: bool = bfx.hit(self, float(m["mult"]))
				bfx.cur_src = ""
				if landed:
					bfx.knock(v / Game.PXS * 6.0)
			var pillar: Node = null
			for a in get_tree().get_nodes_in_group("arena"):
				if a.type == "gravepillar" and not a.dead and hit_rect().intersects(a.hit_rect()):
					pillar = a
					break
			var moved := global_position.distance_to(o)
			if pillar != null or moved < v.length() * dt * 0.25:
				if pillar != null:
					pillar.hurt(pillar.hp + 1.0, true, Vector2.ZERO)
				world.shake(12.0)
				world.burst(center(), Color(0.85, 0.78, 0.69), 20, 170.0)
				Sfx.play("trap")
				if m["crash"] == "busy":
					busy = 0.5
				else:
					stagger(0.0, Game.t("Smashed the pillar — STAGGERED!", "ستون را شکست — گیج شد!") if pillar != null else Game.t("Hit the wall — STAGGERED!", "به دیوار خورد — گیج شد!"))
				return true
			if float(m["t"]) <= 0.0:
				busy = 0.65
				return true
			return false
		"dive":
			var target: Vector2 = bfx.pc()
			var to := target - shadow
			var l := to.length()
			if l > 6.0:
				shadow += to / l * min(3.1 * Game.PXS * dt, l)
			m["t"] = float(m["t"]) - dt
			if float(m["t"]) > 0.0:
				return false
			bfx.circle(shadow, 80.0, 0.56 if int(m["ph"]) >= 3 else 0.68, rgb, _fire_surface, self)
			busy = 0.9
			return true
		"fly":
			# (v0.19) the Wyrm in the air: its shadow hunts the hero, then it drops on the shadow
			var target2: Vector2 = bfx.pc()
			var to3 := target2 - shadow
			var l3 := to3.length()
			if l3 > 6.0:
				shadow += to3 / l3 * min(3.4 * Game.PXS * dt, l3)
			m["t"] = float(m["t"]) - dt
			if float(m["t"]) > 0.0:
				return false
			bfx.circle(shadow, 96.0, 0.58 if int(m["ph"]) >= 3 else 0.7, rgb, _fire_wyrm_land, self)
			busy = 0.95
			return true
		"tongue":
			m["t"] = float(m["t"]) - dt
			var mouth: Vector2 = m["mouth"]
			var to2: Vector2 = mouth - bfx.pc()
			var l2 := to2.length()
			if l2 > 8.0:
				bfx.knock(to2 / l2 * 10.0 * Game.PXS * dt)
			if float(m["t"]) > 0.0:
				return false
			bfx.circle(mouth, 66.0, 0.52, Color8(230, 90, 140), _fire_bite, self)
			busy = 0.7
			return true
	return true

# ================================================================ 1) THE DUNGEON GUARDIAN
func _alive_pillars() -> int:
	var n := 0
	for pl in pillars:
		if is_instance_valid(pl) and not pl.dead:
			n += 1
	return n

func _ai_guardian(dt: float, d: float, to: Vector2) -> void:
	if _brain(dt):
		return
	var c := center()
	var col := Color8(170, 110, 255)
	shield = _alive_pillars()
	_face(to.x)
	if d > 520.0:
		_chase(to, d, 0.5)
		return
	if gcd <= 0.0:
		# grave pillars: phase II onwards, whenever none stand
		if ph >= 2 and _ready_move("pillars") and shield == 0:
			_use("pillars", 17.0)
			busy = 1.0
			if not has_node("Arzhang3D"):
				world.float_text(global_position + Vector2(0, -box.y - 20), Game.t("Rise, stones of the dead!", "برخیزید، نگهبانان!"), Color(0.78, 0.66, 1.0), true)
			Sfx.play("roar", -4.0)
			pillars.clear()
			for spot in world.ring(c, 4 if ph >= 3 else 3, 130.0, 240.0, Vector2(30, 40)):
				pillars.append(world.spawn_arena("gravepillar", spot, {"hp": max(45.0, Game.atk() * 3.2), "owner": self, "col": Color(0.72, 0.56, 1.0)}))
			shield = _alive_pillars()
			# (v0.23, playtest) every time, not only the first: what to do, where the hero is looking; (v0.24) one message, not
			# a banner, a tip and the bar all at once — the tip's advice is the banner's second line
			if not has_node("Arzhang3D"):
				world.banner.emit(Game.t("BREAK THE PILLARS", "ستون‌ها را بشکن"), Game.t("they shield him — or bait his charge into one", "سپرِ اویند — یا یورشش را به یکی بکوبان"), Color(0.78, 0.66, 1.0), 2.2)
			return
		# In the shield lesson the player can concentrate on lining up a charge.
		if shield > 0 and Game.get("practice_stage") == "DuelQuickStart":
			_chase(to, d, 0.65, 80.0)
			return
		# final phase: he vanishes and strikes from where you stand
		if ph >= 3 and _ready_move("eclipse") and d < 420.0:
			_use("eclipse", 8.5)
			busy = 1.9
			world.burst(c, Color8(106, 74, 158), 22, 150.0)
			Sfx.play("tp")
			_set_hidden(true)
			bfx.later(self, 0.45, _eclipse_mark)
			return
		if d < 105.0 and _ready_move("sweep"):
			var a := to.angle()
			var ms := 0.48 if ph >= 3 else 0.62
			_use("sweep", 1.7 if ph >= 3 else (2.1 if ph >= 2 else 2.5))
			busy = ms + 0.52
			bfx.cone(c + Vector2(0, 6), 112.0, a, 1.05, ms, col, _fire_sweep.bind(a, c), self)
			return
		if d > 130.0 and d < 470.0 and _ready_move("charge"):
			var a := to.angle()
			var span: float = min(520.0, d + 160.0)
			var ms := 0.6 if ph >= 2 else 0.72
			_use("charge", 2.6 if ph >= 3 else 3.6)
			busy = ms + 0.05
			bfx.lane(c, c + Vector2.from_angle(a) * span, 50.0, ms, Color8(255, 80, 60), _fire_charge.bind(a, 7.6, 0.9), self)
			if not has_node("Arzhang3D"):
				world.tip("bait", "Dodge his charge so he slams into a wall — he will be stunned.", "از یورشش جاخالی بده تا به دیوار بکوبد — گیج می‌شود.")
			return
		if _ready_move("bolts"):
			_use("bolts", 4.2)
			busy = 0.92
			bfx.circle(c, 46.0, 0.52, col, _fire_bolts.bind(ph), self)
			return
	_chase(to, d, 1.25 if ph >= 3 else 1.0, 70.0)

func _fire_sweep(t: Dictionary, a: float, c: Vector2) -> void:
	Sfx.play("heavy", -2.0)
	world.burst(c + Vector2.from_angle(a) * 50.0, Color(0.72, 0.56, 1.0), 10, 130.0)
	if bfx.in_cone(t) and bfx.hit(self, 1.0):
		bfx.knock(Vector2.from_angle(a) * 30.0)

func _fire_charge(_t: Dictionary, a: float, speed: float, sec: float) -> void:
	Sfx.play("roar", -6.0)
	_dash(a, speed, sec, 1.3)

func _fire_bolts(_t: Dictionary, phase: int) -> void:
	Sfx.play("bolt")
	bfx.shoot(self, 10, 2.5, 0.55, Color8(154, 106, 208), "", randf())
	if phase >= 2:
		bfx.later(self, 0.38, _second_bolts)

func _second_bolts() -> void:
	bfx.shoot(self, 10, 2.5, 0.55, Color8(154, 106, 208), "", PI / 10.0)

func _eclipse_mark() -> void:
	bfx.circle(bfx.pc(), 82.0, 0.82, Color8(170, 110, 255), _fire_eclipse, self)

func _fire_eclipse(t: Dictionary) -> void:
	global_position = t["pos"] + Vector2(0, 10)
	_set_hidden(false)
	_unstick()
	world.burst(t["pos"], Color8(154, 106, 208), 24, 170.0)
	world.shake(10.0)
	Sfx.play("nova")
	if bfx.in_circle(t):
		bfx.hit(self, 1.35)
	busy = 0.8

# ================================================================ 2) THE EMBER COLOSSUS
func _ai_colossus(dt: float, d: float, to: Vector2) -> void:
	if vent > 0.0:
		vent -= dt
		heat = 0.0
		if randf() < 15.0 * dt:
			world.burst(global_position + Vector2(randf_range(-box.x, box.x) * 0.5, -box.y + 6), Color(0.91, 0.91, 0.94), 1, 50.0)
		if vent <= 0.0:
			world.float_text(global_position + Vector2(0, -box.y - 20), Game.t("Armour reforms", "زره‌اش دوباره شکل گرفت"), Color(1, 0.6, 0.31))
	else:
		heat = min(100.0, heat + 9.0 * dt)
	armor = heat > 25.0
	if _brain(dt):
		return
	var c := center()
	var col := Color8(255, 120, 40)
	_face(to.x)
	if d > 560.0:
		_chase(to, d, 0.5)
		return
	# final phase: vents burst open under the hero
	if ph >= 3:
		vent_t -= dt
		if vent_t <= 0.0:
			vent_t = 2.6
			var p: Vector2 = bfx.pc()
			for i in 2:
				var pos := p + Vector2((randf() - 0.5) * 160.0, (randf() - 0.5) * 120.0)
				bfx.circle(pos, 52.0, 0.95, col, _fire_vent, self)
	if gcd <= 0.0:
		if _ready_move("erupt") and d < 360.0:
			_use("erupt", 12.0 if ph >= 3 else 15.0)
			busy = 1.85
			world.float_text(global_position + Vector2(0, -box.y - 24), Game.t("The mountain stirs…", "کوه می‌جنبد…"), Color(1, 0.69, 0.38), true)
			bfx.circle(c + Vector2(0, 10), 70.0, 1.25, Color8(255, 200, 80), _fire_erupt.bind(c, ph), self)
			return
		if d < 170.0 and _ready_move("fist"):
			var a := to.angle()
			_use("fist", 2.8)
			busy = 1.45
			var v: Dictionary = bfx.vol()
			var o := c + Vector2(0, 10)
			bfx.circle(o, 92.0, 0.76, col, _fire_fist.bind(v), self)
			var offs := [-0.38, 0.0, 0.38]
			for i in 3:
				var aa: float = a + float(offs[i])
				bfx.lane(o, o + Vector2.from_angle(aa) * 300.0, 34.0, 0.86 + i * 0.12, col, _fire_fissure.bind(v), self)
			return
		if d < 120.0 and _ready_move("stomp"):
			_use("stomp", 3.4)
			busy = 0.94
			bfx.circle(c + Vector2(0, 14), 78.0, 0.56, col, _fire_stomp, self)
			return
		if ph >= 2 and d > 160.0 and d < 460.0 and _ready_move("charge"):
			var a := to.angle()
			var span: float = min(500.0, d + 140.0)
			_use("charge", 5.2)
			busy = 0.7
			bfx.lane(c, c + Vector2.from_angle(a) * span, 60.0, 0.65, Color8(255, 80, 40), _fire_charge.bind(a, 7.0, 0.85), self)
			return
		if _ready_move("boulders"):
			_use("boulders", 4.3)
			busy = 0.75
			var n := 5 if ph >= 3 else (4 if ph >= 2 else 3)
			bfx.later(self, 0.3, _throw_boulders.bind(bfx.pc(), n))
			return
	_chase(to, d, 1.2 if ph >= 3 else 1.0, 80.0)

func _fire_vent(t: Dictionary) -> void:
	world.burst(t["pos"], Color8(255, 138, 60), 14, 140.0)
	if bfx.in_circle(t):
		bfx.hit(self, 0.8, ["burn", 2.5, 2])

func _fire_erupt(_t: Dictionary, c: Vector2, phase: int) -> void:
	Sfx.play("nova")
	world.shake(14.0)
	world.burst(c, Color8(255, 138, 60), 30, 220.0)
	bfx.wave(c + Vector2(0, 10), 320.0, 6.5, self, 1.2)
	if phase >= 3:
		bfx.later(self, 0.55, _second_wave.bind(c))
	vent = 6.0
	heat = 0.0
	armor = false
	world.float_text(global_position + Vector2(0, -box.y - 30), Game.t("CORE EXPOSED!", "هسته‌اش باز شد!"), Color(1, 0.94, 0.63), true)
	world.tip("core", "Roll through the shockwave, then hit the exposed core. Ice also cools his armour.",
		"از موج ضربه با غلت رد شو، بعد هستهٔ بازش را بزن. یخ هم زره‌اش را خنک می‌کند.")

func _second_wave(c: Vector2) -> void:
	bfx.wave(c + Vector2(0, 10), 320.0, 6.5, self, 1.0)

func _fire_fist(t: Dictionary, v: Dictionary) -> void:
	Sfx.play("nova", -3.0)
	world.shake(9.0)
	world.burst(t["pos"], Color8(255, 138, 60), 20, 170.0)
	if bfx.in_circle(t):
		bfx.hit_v(v, self, 1.15, ["burn", 2.0, 1])

func _fire_fissure(t: Dictionary, v: Dictionary) -> void:
	world.burst(t["b"], Color8(255, 122, 48), 8, 110.0)
	if bfx.in_lane(t):
		bfx.hit_v(v, self, 0.9, ["burn", 2.5, 2])

func _fire_stomp(t: Dictionary) -> void:
	Sfx.play("trap")
	world.shake(7.0)
	world.burst(t["pos"], Color8(255, 138, 60), 16, 150.0)
	if bfx.in_circle(t):
		bfx.hit(self, 0.95)

func _throw_boulders(target: Vector2, n: int) -> void:
	Sfx.play("dodge", -2.0)
	var v: Dictionary = bfx.vol()
	var from := Vector2(center().x, global_position.y - box.y)
	for i in n:
		var r := 0.0 if i == 0 else 50.0 + randf() * 70.0
		var a := randf() * TAU
		bfx.lob(from, target + Vector2(cos(a) * r, sin(a) * r * 0.7), 1.05 + i * 0.14, 48.0, self, 0.9, Color8(255, 150, 70), "", v)

# ================================================================ 3) THE MARSH MATRIARCH
func _ai_matriarch(dt: float, d: float, to: Vector2) -> void:
	if _brain(dt):
		return
	var c := center()
	var col := Color8(120, 220, 90)
	_face(to.x)
	if d > 560.0:
		_chase(to, d, 0.5)
		return
	if gcd <= 0.0:
		if _ready_move("dive") and d < 480.0:
			_use("dive", 6.5 if ph >= 3 else 9.0, -1.0)
			Sfx.play("roar", -2.0)
			world.burst(c + Vector2(0, 20), Color8(74, 106, 58), 24, 150.0)
			_set_hidden(true)
			shadow_on = true
			shadow = c + Vector2(0, box.y * 0.35)
			motion = {"kind": "dive", "t": 1.3 if ph >= 3 else 1.6, "ph": ph}
			return
		if _ready_move("eggs") and world.count_arena("bogegg") < 2:
			_use("eggs", 15.0)
			busy = 0.9
			world.float_text(global_position + Vector2(0, -box.y - 20), Game.t("My children!", "بچه‌هایم!"), Color(0.72, 0.94, 0.56), true)
			Sfx.play("poison")
			var kids := ["toad", "mosquito"] if ph >= 2 else ["mosquito", "mosquito"]
			for spot in world.ring(c + Vector2(0, 20), 4 if ph >= 3 else 3, 80.0, 170.0, Vector2(22, 20)):
				world.spawn_arena("bogegg", spot, {"hp": max(28.0, Game.atk() * 2.4), "owner": self, "hatch": 7.0, "kids": kids, "col": Color8(168, 192, 112)})
			world.tip("eggs", "Break the eggs before they hatch — fire burns them instantly.", "تخم‌ها را قبل از بیرون آمدن جوجه‌ها بشکن — آتش فوراً می‌سوزاندشان.")
			return
		if d > 110.0 and d < 320.0 and _ready_move("tongue"):
			var a := to.angle()
			_use("tongue", 5.2)
			busy = 0.88
			bfx.lane(c, c + Vector2.from_angle(a) * 320.0, 30.0, 0.68, Color8(230, 90, 140), _fire_tongue.bind(a, c), self)
			return
		if _ready_move("pool") and d < 400.0:
			_use("pool", 7.0)
			busy = 0.75
			bfx.circle(bfx.pc(), 60.0, 0.75, Color8(110, 200, 80), _fire_pool, self)
			return
		if _ready_move("spit"):
			_use("spit", 4.2)
			busy = 0.83
			bfx.circle(c, 50.0, 0.48, col, _fire_spit.bind(ph), self)
			return
	_chase(to, d, 1.2 if ph >= 3 else 1.0, 70.0)

func _fire_surface(t: Dictionary) -> void:
	global_position = t["pos"] + Vector2(0, box.y * 0.15)
	_set_hidden(false)
	shadow_on = false
	_unstick()
	world.shake(12.0)
	Sfx.play("roar", -2.0)
	world.burst(t["pos"], Color8(95, 191, 90), 30, 200.0)
	if bfx.in_circle(t):
		bfx.hit(self, 1.3, ["poison", 4.5, 3])
	dazed = 1.6
	busy = 0.6
	world.tip("dazed", "She is dazed after surfacing — strike while she shakes off the mud!", "بعد از بیرون آمدن گیج است — تا لجن را می‌تکاند بزنش!")

func _fire_tongue(t: Dictionary, a: float, c: Vector2) -> void:
	Sfx.play("whisper")
	var p := player()
	if not bfx.in_lane(t) or p == null or p.invuln > 0.0:
		return
	# caught: dragged to her mouth, then a bite you can still roll out of
	bfx.hit(self, 0.5)
	motion = {"kind": "tongue", "t": 0.32, "mouth": c + Vector2(cos(a) * 40.0, sin(a) * 30.0)}

func _fire_bite(t: Dictionary) -> void:
	Sfx.play("hit")
	if bfx.in_circle(t):
		bfx.hit(self, 1.2, ["poison", 4.0, 3])

func _fire_pool(t: Dictionary) -> void:
	bfx.pool(t["pos"], 100.0, 6.0, "poison")
	world.burst(t["pos"], Color8(95, 191, 90), 16, 130.0)
	Sfx.play("poison")

func _fire_spit(_t: Dictionary, phase: int) -> void:
	Sfx.play("bolt")
	bfx.shoot(self, 10 if phase >= 2 else 7, 2.7, 0.55, Color8(95, 191, 90), "poison", randf())

# ================================================================ 4) THE FROSTBOUND ARBITER
func echoes() -> Array:
	var out := []
	for a in get_tree().get_nodes_in_group("arena"):
		if a.type == "arbiterclone" and not a.dead and a.owner_boss == self:
			out.append(a)
	return out

func _ai_arbiter(dt: float, d: float, to: Vector2) -> void:
	if _brain(dt):
		return
	var c := center()
	var col := Color8(70, 120, 255)   # deep blue reads on the pale ice floor
	_face(to.x)
	if d > 560.0:
		_chase(to, d, 0.5)
		return
	var ech := echoes()
	if gcd <= 0.0:
		if ph >= 2 and ech.is_empty() and _ready_move("echo"):
			_use("echo", 20.0)
			busy = 0.9
			Sfx.play("ice")
			world.float_text(global_position + Vector2(0, -box.y - 20), Game.t("Judgement multiplies.", "داوری چندبرابر می‌شود."), Color(0.81, 0.94, 1.0), true)
			for spot in world.ring(c, 2, 110.0, 170.0, box):
				world.spawn_arena("arbiterclone", spot, {"hp": 1.0, "speed": 0.6, "owner": self, "dmg": round(dmg * 0.6), "born": bfx.clock, "col": Color(0.81, 0.94, 1.0)})
			world.tip("echo", "Twins of ice copy his spells. One hit breaks a twin — fire melts them all.",
				"همزادهای یخی جادوی او را تکرار می‌کنند. با یک ضربه می‌شکنند — آتش همه را ذوب می‌کند.")
			return
		if ph >= 3 and _ready_move("hail"):
			_use("hail", 7.5)
			busy = 0.9
			var p: Vector2 = bfx.pc()
			var v: Dictionary = bfx.vol()
			for i in 8:
				var pos := p + Vector2((randf() - 0.5) * 300.0, (randf() - 0.5) * 220.0)
				bfx.circle(pos, 40.0, 0.75 + i * 0.11, col, _fire_hail.bind(v), self)
			return
		if d < 170.0 and _ready_move("leap"):
			var a := to.angle()
			var span: float = min(240.0, d + 30.0)
			_use("leap", 4.2)
			busy = 0.56
			bfx.lane(c, c + Vector2.from_angle(a) * span, 54.0, 0.56, col, _fire_leap.bind(a, span), self)
			return
		if _ready_move("lance") and d > 70.0:
			var a := to.angle()
			var n := 8 if ph >= 2 else 7
			_use("lance", 3.6)
			busy = 0.6 + n * 0.11
			var v: Dictionary = bfx.vol()
			for i in n:
				var pos := c + Vector2(cos(a) * (56.0 + i * 46.0), 14.0 + sin(a) * (56.0 + i * 46.0))
				bfx.circle(pos, 34.0, 0.6 + i * 0.11, col, _fire_lance.bind(v, self, 0.9, 1.5, i == 0), self)
			for o in ech:
				var oc: Vector2 = o.center()
				var oa: float = (bfx.pc() - oc).angle()
				for i in 5:
					var pos := oc + Vector2(cos(oa) * (50.0 + i * 46.0), 14.0 + sin(oa) * (50.0 + i * 46.0))
					bfx.circle(pos, 30.0, 0.7 + i * 0.11, col, _fire_lance.bind(v, o, 0.8, 1.2, false), o)
			return
		if _ready_move("storm"):
			_use("storm", 4.6)
			busy = 0.91
			bfx.circle(c, 50.0, 0.56, col, _fire_storm.bind(ph), self)
			return
	_chase(to, d, 1.2 if ph >= 3 else 1.0, 90.0)

func _fire_hail(t: Dictionary, v: Dictionary) -> void:
	world.burst(t["pos"], Color(0.91, 0.97, 1.0), 10, 120.0)
	Sfx.play("ice", -4.0)
	if bfx.in_circle(t):
		bfx.hit_v(v, self, 0.8, ["freeze", 1.5, 1])

func _fire_leap(_t: Dictionary, a: float, span: float) -> void:
	var h0: float = Game.hp
	var dur: float = min(0.52, span / (6.2 * Game.PXS))
	_dash(a, 6.2, dur, 1.1, "busy")
	bfx.later(self, dur, _leap_land.bind(h0))

func _leap_land(h0: float) -> void:
	bfx.circle(center() + Vector2(0, 14), 64.0, 0.28, Color8(70, 120, 255), _fire_land.bind(h0), self)

func _fire_land(t: Dictionary, h0: float) -> void:
	Sfx.play("ice")
	if Game.hp >= h0 and bfx.in_circle(t):
		bfx.hit(self, 0.9, ["freeze", 1.2, 1])

func _fire_lance(t: Dictionary, v: Dictionary, src: Node, mult: float, frz: float, first: bool) -> void:
	world.burst(t["pos"], Color(0.81, 0.94, 1.0), 9, 110.0)
	if first:
		Sfx.play("ice")
	if bfx.in_circle(t, 4.0):
		bfx.hit_v(v, src, mult, ["freeze", frz, 1])

func _fire_storm(_t: Dictionary, phase: int) -> void:
	Sfx.play("bolt")
	bfx.shoot(self, 12 if phase >= 3 else (10 if phase >= 2 else 8), 3.0, 0.55, Color8(168, 212, 255), "freeze", randf())
	for o in echoes():
		bfx.shoot(o, 6, 2.6, 0.6, Color8(168, 212, 255), "freeze", randf(), o.center())

# ================================================================ 5) THE GLACIER TITAN (v0.19)
func _alive_minions() -> int:
	minions = minions.filter(func(e): return is_instance_valid(e) and not e.dead)
	return minions.size()

func _call(kind: String, n: int, col: Color) -> void:
	for spot in world.ring(center() + Vector2(0, 20), n, 90.0, 180.0, Vector2(26, 26)):
		var e: Node = world.spawn_enemy(kind, spot)
		e.alert = true
		e.rally = true
		minions.append(e)
		world.burst(spot + Vector2(0, -12), col, 12, 110.0)

func _ai_titan(dt: float, d: float, to: Vector2) -> void:
	if _brain(dt):
		return
	var c := center()
	var col := Color8(90, 150, 255)
	_face(to.x)
	if d > 480.0:
		_chase(to, d, 0.6)
		return
	if gcd <= 0.0:
		if ph >= 2 and _ready_move("call") and _alive_minions() < 2:
			_use("call", 16.0)
			busy = 1.0
			if not has_node("Arzhang3D"):
				world.float_text(global_position + Vector2(0, -box.y - 20), Game.t("Rise from the snow!", "از برف برخیزید!"), Color(0.75, 0.9, 1.0), true)
			Sfx.play("roar", -2.0)
			_call("iceling", 3, Color(0.8, 0.94, 1.0))
			world.tip("titan_call", "The icelings come for you — or stay on Akvan and burn it down.", "یخچه‌ها سراغت می‌آیند — یا روی اکوان بمان و با آتش آبش کن.")
			return
		if d < 125.0 and _ready_move("slam"):
			_use("slam", 2.6 if ph >= 2 else 3.2)
			busy = 1.25
			bfx.circle(c + Vector2(0, 16), 138.0, 0.85, col, _fire_titan_slam, self)
			return
		if d < 400.0 and _ready_move("wave"):
			_use("wave", 6.5 if ph >= 2 else 8.0)
			busy = 1.0
			bfx.circle(c + Vector2(0, 16), 54.0, 0.6, col, _fire_titan_wave, self)
			world.tip("titan_wave", "Roll through the frost wave as it reaches you.", "درست وقتی موجِ یخ به تو می‌رسد، از میانش غلت بزن.")
			return
		if d > 140.0 and d < 420.0 and _ready_move("charge"):
			var a := to.angle()
			var span: float = min(480.0, d + 140.0)
			_use("charge", 5.0)
			busy = 0.75
			bfx.lane(c, c + Vector2.from_angle(a) * span, 64.0, 0.75, Color8(255, 90, 70), _fire_charge.bind(a, 6.4, 0.85), self)
			world.tip("titan_charge", "Make it charge into the ice spires — it will be stunned.", "کاری کن به ستون‌های یخ بکوبد — گیج می‌شود.")
			return
		if ph >= 2 and _ready_move("boulder"):
			_use("boulder", 4.5)
			busy = 0.8
			Sfx.play("heavy", -4.0)
			var p: Vector2 = bfx.pc()
			for i in 3:
				var dst := p + Vector2(randf_range(-70, 70), randf_range(-50, 50))
				bfx.lob(c + Vector2(0, -20), dst, 0.9 + i * 0.15, 44.0, self, 0.9, col, "ice")
			return
		if _ready_move("icicles"):
			_use("icicles", 5.0)
			busy = 0.8
			var pc: Vector2 = bfx.pc()
			var v: Dictionary = bfx.vol()
			for i in (7 if ph >= 2 else 5):
				var pos := pc + Vector2((randf() - 0.5) * 260.0, (randf() - 0.5) * 190.0)
				if i == 0:
					pos = pc
				bfx.circle(pos, 38.0, 0.8 + i * 0.12, col, _fire_hail.bind(v), self)
			return
	_chase(to, d, 1.15 if ph >= 2 else 1.0, 80.0)

func _fire_titan_slam(t: Dictionary) -> void:
	Sfx.play("trap")
	Sfx.play("ice", -2.0)
	world.shake(10.0)
	world.burst(t["pos"], Color(0.8, 0.94, 1.0), 26, 190.0)
	if bfx.in_circle(t):
		bfx.hit(self, 1.25, ["freeze", 1.4, 1])

func _fire_titan_wave(t: Dictionary) -> void:
	Sfx.play("nova", -2.0)
	world.shake(6.0)
	bfx.wave(t["pos"], 300.0, 4.2, self, 0.95, Color8(150, 210, 255))

# ================================================================ 6) THE ANCIENT WYRM (v0.19)
func _mouth() -> Vector2:
	return center() + Vector2(face_x * box.x * 0.42, -box.y * 0.18)

func _ai_wyrm(dt: float, d: float, to: Vector2) -> void:
	if _brain(dt):
		return
	var c := center()
	var col := Color8(80, 170, 255)
	var fast := 0.8 if ph >= 3 else 1.0
	_face(to.x)
	if d > 600.0:
		_chase(to, d, 0.5)
		return
	if gcd <= 0.0:
		if ph >= 2 and _ready_move("brood") and _alive_minions() < 2:
			_use("brood", 18.0)
			busy = 1.0
			world.float_text(global_position + Vector2(0, -box.y - 20), Game.t("Wake, my brood!", "بیدار شوید، بچه‌هایم!"), Color(0.75, 0.75, 1.0), true)
			Sfx.play("roar")
			_call("wyrmling", 2, Color(0.7, 0.65, 1.0))
			return
		if ph >= 2 and _ready_move("fly") and d < 520.0:
			_use("fly", 9.0 * fast, -1.0)
			Sfx.play("roar", -2.0)
			Sfx.play("dodge", 0.0)
			world.burst(c, Color(0.85, 0.94, 1.0), 30, 200.0)
			world.shake(6.0)
			_set_hidden(true)
			shadow_on = true
			shadow = global_position
			motion = {"kind": "fly", "t": 1.5 if ph >= 3 else 1.9, "ph": ph}
			world.tip("wyrm_fly", "It dives on its shadow — keep moving, then strike while it rises.", "روی سایه‌اش شیرجه می‌زند — حرکت کن، بعد وقتی بلند می‌شود بزن.")
			return
		if ph >= 3 and _ready_move("storm"):
			_use("storm", 7.5)
			busy = 1.0
			Sfx.play("ice")
			var pc: Vector2 = bfx.pc()
			var v: Dictionary = bfx.vol()
			for i in 10:
				var pos := pc + Vector2((randf() - 0.5) * 340.0, (randf() - 0.5) * 240.0)
				if i == 0:
					pos = pc
				bfx.circle(pos, 40.0, 0.75 + i * 0.1, col, _fire_hail.bind(v), self)
			return
		if d < 300.0 and _ready_move("breath"):
			var a: float = (bfx.pc() - _mouth()).angle()
			_use("breath", 4.2 * fast)
			if ph >= 3:
				# the sweep: three breaths across the lair, one after another
				busy = 2.1
				for i in 3:
					bfx.later(self, i * 0.5, _wyrm_breath.bind(a + (float(i) - 1.0) * 0.55, 0.62))
			else:
				busy = 1.35
				_wyrm_breath(a, 0.85)
			return
		if d < 135.0 and _ready_move("tail"):
			_use("tail", 3.0 * fast)
			busy = 1.05
			bfx.circle(c + Vector2(0, 18), 145.0, 0.7, col, _fire_wyrm_tail, self)
			return
		if ph >= 2 and _ready_move("gust"):
			_use("gust", 8.0 * fast)
			busy = 1.1
			Sfx.play("dodge", 2.0)
			var a2 := to.angle()
			for k in [-0.4, 0.0, 0.4]:
				var aa: float = a2 + k
				bfx.lane(c, c + Vector2.from_angle(aa) * 430.0, 40.0, 0.7, col, _fire_gust.bind(aa), self)
			return
		if d > 160.0 and d < 440.0 and _ready_move("lunge"):
			var a3 := to.angle()
			var span: float = min(520.0, d + 150.0)
			_use("lunge", 5.5 * fast)
			busy = 0.7
			bfx.lane(c, c + Vector2.from_angle(a3) * span, 70.0, 0.7, Color8(255, 90, 70), _fire_charge.bind(a3, 7.0, 0.85), self)
			return
		if _ready_move("shards"):
			_use("shards", 5.0 * fast)
			busy = 0.9
			bfx.circle(c, 50.0, 0.55, col, _fire_wyrm_shards, self)
			return
	_chase(to, d, 1.15 if ph >= 3 else 1.0, 110.0)

func _wyrm_breath(a: float, sec: float) -> void:
	if dead:
		return
	bfx.cone(_mouth(), 255.0, a, 0.52, sec, Color8(80, 170, 255), _fire_breath.bind(a), self)

func _fire_breath(t: Dictionary, a: float) -> void:
	Sfx.play("ice", 0.0)
	Sfx.play("whisper", -2.0)
	for i in 6:
		world.burst(_mouth() + Vector2.from_angle(a + randf_range(-0.4, 0.4)) * randf_range(40.0, 230.0), Color(0.8, 0.94, 1.0), 6, 90.0)
	if bfx.in_cone(t):
		bfx.hit(self, 1.15, ["freeze", 1.6, 1])

func _fire_wyrm_tail(t: Dictionary) -> void:
	Sfx.play("heavy", 0.0)
	world.shake(8.0)
	world.burst(t["pos"], Color(0.7, 0.85, 1.0), 20, 170.0)
	if bfx.in_circle(t) and bfx.hit(self, 1.2):
		bfx.knock((bfx.pc() - t["pos"]).normalized() * 60.0)

func _fire_gust(t: Dictionary, a: float) -> void:
	Sfx.play("ice", -4.0)
	if bfx.in_lane(t):
		bfx.hit(self, 0.8, ["freeze", 1.0, 1])
		bfx.knock(Vector2.from_angle(a) * 70.0)

func _fire_wyrm_shards(_t: Dictionary) -> void:
	Sfx.play("bolt")
	bfx.shoot(self, 14 if ph >= 2 else 10, 2.8, 0.55, Color8(168, 212, 255), "freeze", randf())

func _fire_wyrm_land(t: Dictionary) -> void:
	global_position = t["pos"] + Vector2(0, box.y * 0.2)
	_set_hidden(false)
	shadow_on = false
	_unstick()
	world.shake(14.0)
	Sfx.play("trap", 2.0)
	Sfx.play("roar", -4.0)
	world.burst(t["pos"], Color(0.85, 0.95, 1.0), 34, 220.0)
	if bfx.in_circle(t):
		bfx.hit(self, 1.4, ["freeze", 1.5, 1])
	bfx.wave(t["pos"], 170.0, 4.0, self, 0.6, Color8(150, 210, 255))
	dazed = 1.4
	busy = 0.7
	world.tip("wyrm_dazed", "It is dazed after the dive — now!", "بعد از شیرجه گیج است — حالا!")


# ================================================================ 7) ZAHHAK (v0.23)
## his lair (the map's "ch3" block): the chains run from the four anchors to him; while they hold he cannot leave it
var zh_lair := Vector2.INF
var zh_anchors: Array = []
## a serpent's strike: side (-1 left, 1 right) -> {"a": angle, "t": 0..1 drawn out, "hold": seconds}
var zh_strike := {}
const ZH_LEASH := [0.0, 230.0, 320.0, 99999.0]
const ZH_COL := Color8(120, 220, 110)

func _zh_setup() -> void:
	var ch3: Dictionary = Game.map_data(str(world.key)).get("ch3", {})
	if ch3.has("lair"):
		zh_lair = Game._v(ch3["lair"])
		for a in ch3.get("anchors", []):
			zh_anchors.append(Game._v(a))

## how many chains still hold him (4, then one breaks at each phase)
func zh_chains() -> int:
	return clampi(5 - ph, 2, 4) if not zh_anchors.is_empty() else 0

func _zh_shoulder(side: float) -> Vector2:
	return Vector2(side * box.x * 0.36, -box.y * 0.8)

func _ai_zahhak(dt: float, d: float, to: Vector2) -> void:
	if zh_lair == Vector2.INF and zh_anchors.is_empty():
		_zh_setup()
		if zh_lair == Vector2.INF:
			zh_lair = Vector2(-1, -1)
	for k in zh_strike.keys():
		var s: Dictionary = zh_strike[k]
		s["hold"] = float(s["hold"]) - dt
		if float(s["hold"]) <= 0.0:
			zh_strike.erase(k)
	var leash: float = ZH_LEASH[clampi(ph, 1, 3)]
	if zh_lair.x >= 0.0 and global_position.distance_to(zh_lair) > leash:
		global_position = zh_lair + (global_position - zh_lair).limit_length(leash)
		if not motion.is_empty() and str(motion.get("kind", "")) == "dash":
			motion = {}
			dazed = 0.8
			world.shake(6.0)
			Sfx.play("clank", 0.0)
			world.float_text(global_position + Vector2(0, -box.y - 20), Game.t("The chains hold!", "زنجیرها نگهش می‌دارند!"), Color(0.8, 0.8, 0.9))
	if _brain(dt):
		return
	var c := center()
	var fast := 0.8 if ph >= 3 else 1.0
	_face(to.x)
	if d > 620.0:
		_chase(to, d, 0.5)
		return
	if gcd <= 0.0:
		if ph >= 2 and _ready_move("call") and _alive_minions() < 2:
			_use("call", 17.0)
			busy = 1.0
			world.float_text(global_position + Vector2(0, -box.y - 24), Game.Ch3.line("z_call"), Color(0.7, 1.0, 0.6), true)
			Sfx.play("roar", -2.0)
			_call("serpent", 2 if ph == 2 else 3, Color(0.55, 0.9, 0.45))
			world.tip("zahhak_call", "His serpents come for you — or stay on Zahhak and finish him.", "مارهایش سراغت می‌آیند — یا روی ضحاک بمان و کارش را تمام کن.")
			return
		if ph >= 2 and _ready_move("lash"):
			_use("lash", 7.5 * fast)
			busy = 1.0
			bfx.circle(c + Vector2(0, 16), 60.0, 0.65, Color8(170, 150, 210), _fire_zh_lash, self)
			world.tip("zahhak_lash", "The chains lash out as a ring: roll through it as it reaches you.", "زنجیرها حلقه‌وار شلاق می‌زنند: وقتی به تو رسید از میانش غلت بزن.")
			return
		if ph >= 2 and _ready_move("quake"):
			_use("quake", 8.0 * fast)
			busy = 0.9
			Sfx.play("trap", -2.0)
			world.shake(5.0)
			var pc: Vector2 = bfx.pc()
			var v: Dictionary = bfx.vol()
			for i in (9 if ph >= 3 else 6):
				var pos := pc + Vector2((randf() - 0.5) * 300.0, (randf() - 0.5) * 220.0)
				if i == 0:
					pos = pc
				bfx.circle(pos, 40.0, 0.85 + i * 0.12, Color8(170, 140, 110), _fire_zh_rock.bind(v), self)
			return
		if d < 135.0 and _ready_move("sword"):
			var a0: float = (bfx.pc() - c).angle()
			_use("sword", 2.8 * fast)
			busy = 1.0
			bfx.cone(c, 165.0, a0, 0.85, 0.7, ZH_COL, _fire_zh_sword, self)
			return
		if d < 330.0 and _ready_move("bite"):
			var a: float = (bfx.pc() - (c + _zh_shoulder(sign(to.x)))).angle()
			_use("bite", 3.4 * fast)
			if ph >= 3:
				busy = 1.7
				for i in 3:
					bfx.later(self, i * 0.42, _zh_bite.bind(-1.0 if i % 2 == 0 else 1.0, 0.55))
			elif ph >= 2:
				busy = 1.2
				_zh_bite(-1.0, 0.75)
				_zh_bite(1.0, 0.75)
			else:
				busy = 1.1
				_zh_bite(sign(to.x) if to.x != 0.0 else 1.0, 0.8, a)
			world.tip("zahhak_bite", "The serpents strike along the marked lanes — step out of them.", "مارها در امتدادِ مسیرهای نشان‌دار نیش می‌زنند — از مسیر بیرون برو.")
			return
		if _ready_move("venom"):
			_use("venom", 5.5 * fast)
			busy = 0.85
			Sfx.play("whisper", -2.0)
			var pc2: Vector2 = bfx.pc()
			for i in (4 if ph >= 2 else 3):
				var dst := pc2 + (Vector2.ZERO if i == 0 else Vector2(randf_range(-90, 90), randf_range(-60, 60)))
				bfx.circle(dst, 34.0, 0.95 + i * 0.18, ZH_COL, _fire_zh_venom, self)
			return
	_chase(to, d, 1.1 if ph >= 3 else 0.95, 95.0)
	if zh_lair.x >= 0.0 and global_position.distance_to(zh_lair) > leash:
		global_position = zh_lair + (global_position - zh_lair).limit_length(leash)

## a serpent bite along a lane from its shoulder (a = toward the hero unless given)
func _zh_bite(side: float, sec: float, a := INF) -> void:
	if dead:
		return
	var from := center() + _zh_shoulder(side) + Vector2(0, box.y * 0.5)
	var ang: float = a if a != INF else (bfx.pc() - from).angle() + side * 0.12
	zh_strike[side] = {"a": ang, "t": 0.0, "hold": sec + 0.35, "fire": false}
	bfx.lane(from, from + Vector2.from_angle(ang) * 270.0, 46.0, sec, ZH_COL, _fire_zh_bite.bind(side), self)

func _fire_zh_bite(t: Dictionary, side: float) -> void:
	Sfx.play("whisper", 2.0)
	Sfx.play("swing2", 0.0)
	if zh_strike.has(side):
		zh_strike[side]["fire"] = true
		zh_strike[side]["hold"] = 0.35
	if bfx.in_lane(t):
		bfx.hit(self, 1.05, ["poison", 3.0, 2])

func _fire_zh_sword(t: Dictionary) -> void:
	Sfx.play("heavy", 0.0)
	world.shake(5.0)
	if bfx.in_cone(t) and bfx.hit(self, 1.3):
		bfx.knock((bfx.pc() - center()).normalized() * 50.0)

func _fire_zh_venom(t: Dictionary) -> void:
	world.burst(t["pos"], Color(0.5, 0.9, 0.4), 10, 100.0)
	Sfx.play("poison", -6.0)
	bfx.pool(t["pos"] + Vector2(0, 6), 52.0, 5.0, "poison")
	if bfx.in_circle(t):
		bfx.hit(self, 0.75, ["poison", 3.0, 2])

func _fire_zh_lash(t: Dictionary) -> void:
	Sfx.play("clank", 2.0)
	Sfx.play("nova", -4.0)
	world.shake(7.0)
	bfx.wave(t["pos"], 320.0, 4.0, self, 1.0, Color8(190, 170, 230))

func _fire_zh_rock(t: Dictionary, v: Dictionary) -> void:
	world.burst(t["pos"], Color(0.62, 0.55, 0.48), 12, 130.0)
	if world.fx:
		world.fx.dust(t["pos"], 6, Vector2.ZERO, Color(0.55, 0.5, 0.45, 0.6))
	Sfx.play("trap", -6.0)
	if bfx.in_circle(t):
		bfx.hit_v(v, self, 0.9)

## the two serpents from his shoulders (they sway, rear back on a telegraph and lunge on the bite) and his crown
func _draw_zahhak() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for side in [-1.0, 1.0]:
		var base := _zh_shoulder(side)
		var sway := Vector2(sin(t * 2.1 + side) * 6.0, cos(t * 1.7 + side * 2.0) * 4.0)
		var head := base + Vector2(side * box.x * 0.55, -box.y * 0.42) + sway
		if zh_strike.has(side):
			var s: Dictionary = zh_strike[side]
			var dir := Vector2.from_angle(float(s["a"]))
			if bool(s["fire"]):
				head = base + dir * 120.0          # the lunge
			else:
				head = base - dir * 16.0 + Vector2(0, -22) + sway * 0.3     # rearing back
		var ctrl := base + Vector2(side * box.x * 0.42, -box.y * 0.05)
		var pts := PackedVector2Array()
		for i in 13:
			var k := i / 12.0
			pts.append(base.lerp(ctrl, k).lerp(ctrl.lerp(head, k), k) + Vector2(sin(k * 9.0 + t * 5.0) * 2.5 * (1.0 - k), 0))
		over.draw_polyline(pts, Color(0.09, 0.08, 0.06), 12.0, true)
		over.draw_polyline(pts, Color8(52, 104, 50), 8.5, true)
		var belly := PackedVector2Array()
		for q in pts:
			belly.append(q + Vector2(side * 1.5, 1.5))
		over.draw_polyline(belly, Color8(210, 196, 112, 200), 2.5, true)
		var hd: Vector2 = (pts[12] - pts[10]).normalized()
		if hd == Vector2.ZERO:
			hd = Vector2(side, 0)
		var nrm := Vector2(-hd.y, hd.x)
		var tip := head + hd * 13.0
		var poly := PackedVector2Array([head - hd * 5.0 + nrm * 7.0, tip + nrm * 2.0, tip - nrm * 2.0, head - hd * 5.0 - nrm * 7.0])
		over.draw_colored_polygon(PackedVector2Array([poly[0] + nrm * 2.0 - hd * 2.0, tip + hd * 2.5, poly[3] - nrm * 2.0 - hd * 2.0]), Color(0.09, 0.08, 0.06))
		over.draw_colored_polygon(poly, Color8(64, 124, 58))
		over.draw_circle(head + hd * 2.0 + nrm * 3.5, 2.2, Color8(250, 220, 60))
		over.draw_circle(head + hd * 2.0 - nrm * 3.5, 2.2, Color8(250, 220, 60))
		if zh_strike.has(side) and bool(zh_strike[side]["fire"]):
			over.draw_line(tip, tip + hd * 9.0, Color8(200, 40, 60), 2.0)
	# the crown
	var cr := Vector2(0, -box.y * 1.02)
	var crown := PackedVector2Array([cr + Vector2(-13, 0), cr + Vector2(-13, -9), cr + Vector2(-7, -4), cr + Vector2(0, -12),
		cr + Vector2(7, -4), cr + Vector2(13, -9), cr + Vector2(13, 0)])
	over.draw_colored_polygon(crown, Color8(230, 180, 60))
	over.draw_polyline(crown + PackedVector2Array([crown[0]]), Color(0.25, 0.15, 0.05), 1.5, true)
	over.draw_circle(cr + Vector2(0, -4), 2.4, Color8(120, 220, 110))

# ================================================================ minibosses and late bosses (interim kit)
func _ai_generic(dt: float, d: float, to: Vector2) -> void:
	if _brain(dt):
		return
	var c := center()
	_face(to.x)
	if d > 420.0:
		_step(_wander(dt))
		return
	var big: float = max(box.x, box.y)
	if gcd <= 0.0:
		if d < big + 46.0 and _ready_move("slam"):
			_use("slam", 3.4)
			var r: float = 150.0 if type == "anvilward" else max(78.0, big * 1.5)
			busy = 0.8 + 0.4
			bfx.circle(c + Vector2(0, box.y * 0.3), r, 0.8, rgb, _fire_slam, self)
			return
		# The Anvil Warden heats three parallel tracks across the hero's last position.
		# Their 104 px spacing leaves a readable side-step/roll gap; the shared volley caps damage at one hit.
		if type == "anvilward" and d > 130.0 and d < 360.0 and _ready_move("furrows"):
			var axis: Vector2 = to / maxf(d, 1.0)
			var side: Vector2 = axis.orthogonal()
			var target: Vector2 = bfx.pc()
			var vol: Dictionary = bfx.vol()
			_use("furrows", 8.8)
			busy = 1.15
			for offset in [-104.0, 0.0, 104.0]:
				var shift: Vector2 = side * float(offset)
				var lane_a: Vector2 = target - axis * 210.0 + shift
				var lane_b: Vector2 = target + axis * 210.0 + shift
				bfx.lane(lane_a, lane_b, 48.0, 0.9, Color8(255, 145, 54), _fire_anvil_furrow.bind(vol), self)
			world.float_text(global_position + Vector2(0, -box.y - 20), Game.t("FORGE FURROWS!", "شیارهای آهنگری!"), Color(1.0, 0.62, 0.28), true)
			world.tip("anvil_furrows", "Three forge lanes are marked. Roll sideways into a gap before they ignite.",
				"سه مسیرِ آتشین مشخص شده‌اند. پیش از شعله‌ور شدن، به شکاف میانشان جاخالی بده.")
			Sfx.play("trap", -4.0)
			return
		# Ashkbus calls a Turanian arrowfall over the hero's last position. Three marks
		# leave a clear step-through gap; a shared token caps the whole volley at one hit.
		if type == "captain" and d > 145.0 and d < 370.0 and _ready_move("arrowfall"):
			var axis: Vector2 = to / maxf(d, 1.0)
			var side: Vector2 = axis.orthogonal()
			var target: Vector2 = bfx.pc()
			var vol: Dictionary = bfx.vol()
			_use("arrowfall", 9.2)
			busy = 1.3
			for offset in [-112.0, 0.0, 112.0]:
				var spot: Vector2 = target + side * float(offset)
				bfx.circle(spot, 30.0, 0.85, Color8(226, 170, 104), _fire_ashkbus_arrowfall.bind(vol), self)
			world.float_text(global_position + Vector2(0, -box.y - 20), Game.t("TURANIAN ARROWFALL!", "بارانِ تیرهای تورانی!"), Color8(235, 185, 118), true)
			world.tip("ashkbus_arrowfall", "Three arrow strikes are marked. Step between the circles before they land.",
				"سه نقطه برای فرود تیرها مشخص شده‌اند. پیش از اصابت، از میان دایره‌ها عبور کن.")
			Sfx.play("trap", -5.0)
			return
		if d > 120.0 and d < 380.0 and _ready_move("charge"):
			var a := to.angle()
			var span: float = min(420.0, d + 100.0)
			_use("charge", 4.6)
			busy = 0.7
			bfx.lane(c, c + Vector2.from_angle(a) * span, max(30.0, box.x * 0.8), 0.65, Color8(255, 80, 50), _fire_charge.bind(a, 6.5, 0.75), self)
			return
		if type in ["ignarok", "toadking", "kondrow"] and _ready_move("volley"):
			_use("volley", 5.0)
			busy = 0.9
			bfx.circle(c, 46.0, 0.55, rgb, _fire_volley, self)
			return
	_chase(to, d, 1.0, big * 0.6)


# ================================================================ chapter IV — the high eyrie
## Visible wind lanes, a close-range vortex and a final fan. A shared token caps each lane volley at one hit.
func _ai_alborz(dt: float, d: float, to: Vector2) -> void:
	_warden_pose_tick(dt)
	if _brain(dt):
		return
	var c := center()
	_face(to.x)
	if d > 520.0:
		_chase(to, d, 1.05, 250.0)
		return
	if gcd <= 0.0:
		if ph >= 3 and d > 150.0 and d < 390.0 and _ready_move("gale_fan"):
			_use("gale_fan", 10.5)
			_warden_pose_start(0.74)
			busy = 1.15
			bfx.cone(c, 310.0, to.angle(), 0.55, 0.92, Color8(164, 222, 249), _fire_gale_fan, self)
			world.float_text(global_position + Vector2(0, -box.y - 20), Game.t("HIGH-GALE SWEEP!", "یورشِ تندبادِ بلند!"), Color8(188, 232, 255), true)
			world.tip("gale_fan", "The Warden sweeps a broad cone of wind. Roll behind it or clear the marked arc.",
				"دیو قوسی پهن از باد می‌فرستد. پشت سرش جاخالی بده یا از کمانِ مشخص‌شده بیرون برو.")
			Sfx.play("trap", -4.0)
			return
		if d < 175.0 and _ready_move("vortex"):
			_use("vortex", 6.8)
			_warden_pose_start(0.70)
			busy = 1.0
			bfx.circle(c, 148.0, 0.88, Color8(128, 205, 241), _fire_gale_vortex, self)
			world.float_text(global_position + Vector2(0, -box.y - 20), Game.t("EYE OF THE GALE!", "چشمِ تندباد!"), Color8(188, 232, 255), true)
			world.tip("gale_vortex", "The wind coils around the Warden. Leave the expanding circle before it breaks.",
				"باد دور دیو حلقه می‌زند. پیش از شکستن حلقه، از دایره بیرون برو.")
			return
		if d > 150.0 and d < 445.0 and _ready_move("crosswind"):
			var axis: Vector2 = to / maxf(d, 1.0)
			var side: Vector2 = axis.orthogonal()
			var target: Vector2 = bfx.pc()
			var volley: Dictionary = bfx.vol()
			_use("crosswind", 8.2)
			_warden_pose_start(0.78)
			busy = 1.2
			for offset in [-96.0, 0.0, 96.0]:
				var shift: Vector2 = side * float(offset)
				var lane_a: Vector2 = target - axis * 235.0 + shift
				var lane_b: Vector2 = target + axis * 235.0 + shift
				bfx.lane(lane_a, lane_b, 42.0, 0.96, Color8(146, 216, 250), _fire_gale_lane.bind(volley), self)
			world.float_text(global_position + Vector2(0, -box.y - 20), Game.t("CROSSWIND!", "بادِ متقاطع!"), Color8(188, 232, 255), true)
			world.tip("gale_crosswind", "Three wind lanes are marked. Roll sideways into one of the two clear gaps.",
				"سه مسیرِ باد مشخص شده‌اند. به پهلو بغلت و وارد یکی از دو شکافِ امن شو.")
			Sfx.play("trap", -5.0)
			return
		if d > 270.0 and d < 480.0 and _ready_move("gust_dash"):
			var a := to.angle()
			_use("gust_dash", 5.6)
			_warden_pose_start(0.56)
			busy = 0.8
			bfx.lane(c, c + Vector2.from_angle(a) * minf(440.0, d + 110.0), 70.0, 0.74,
				Color8(164, 222, 249), _fire_charge.bind(a, 6.8, 0.82), self)
			return
	_chase(to, d, 1.0, box.x * 1.25)


func _fire_gale_lane(t: Dictionary, volley: Dictionary) -> void:
	if dead or staggered > 0.0 or world == null or bfx == null:
		return
	world.burst(t["b"], Color8(173, 226, 250), 7, 94.0)
	if bfx.in_lane(t):
		if bfx.hit_v(volley, self, 0.82):
			bfx.knock((bfx.pc() - center()).normalized() * 38.0)


func _fire_gale_vortex(t: Dictionary) -> void:
	if dead or staggered > 0.0 or world == null or bfx == null:
		return
	world.burst(t["pos"], Color8(150, 218, 247), 18, 145.0)
	world.shake(4.0)
	if bfx.in_circle(t) and bfx.hit(self, 1.02):
		bfx.knock((bfx.pc() - center()).normalized() * 48.0)


func _fire_gale_fan(t: Dictionary) -> void:
	if dead or staggered > 0.0 or world == null or bfx == null:
		return
	world.burst(t["pos"], Color8(180, 230, 251), 12, 125.0)
	if bfx.in_cone(t) and bfx.hit(self, 0.92):
		bfx.knock((bfx.pc() - center()).normalized() * 32.0)


## Each of the Warden's three tracks shares one volley token: at most one lane can damage the hero.
func _fire_anvil_furrow(t: Dictionary, vol: Dictionary) -> void:
	if dead or staggered > 0.0 or world == null or bfx == null:
		return
	world.burst(t["b"], Color8(255, 132, 42), 8, 105.0)
	if bfx.in_lane(t):
		bfx.hit_v(vol, self, 0.88, ["burn", 1.8, 1.0])


## Each of Ashkbus's marked arrow strikes shares one volley token. The warning is
## canceled by a stagger; once the arrows are in flight they finish their short fall.
func _fire_ashkbus_arrowfall(t: Dictionary, vol: Dictionary) -> void:
	if dead or staggered > 0.0 or world == null or bfx == null:
		return
	var spot: Vector2 = t["pos"]
	world.burst(spot, Color8(220, 160, 92), 4, 70.0)
	bfx.lob(spot + Vector2(0, -190.0), spot, 0.38, 30.0, self, 0.72, Color8(194, 128, 70), "arrow", vol)


func _fire_slam(t: Dictionary) -> void:
	Sfx.play("trap")
	world.shake(8.0)
	world.burst(t["pos"], rgb, 18, 160.0)
	if bfx.in_circle(t):
		bfx.hit(self, 1.2)

func _fire_volley(_t: Dictionary) -> void:
	Sfx.play("bolt")
	var kind := "burn"
	var col := Color8(255, 138, 60)
	if type in ["toadking", "kondrow"]:
		kind = "poison"
		col = Color8(95, 191, 90)
	bfx.shoot(self, 12 if type == "ignarok" else (9 if type == "kondrow" else 7), 2.6, 0.5, col, kind, randf())

# ================================================================ death
func die() -> void:
	if dead:
		return
	bfx.clear()
	for a in get_tree().get_nodes_in_group("arena"):
		if not a.dead:
			a.vanish()
	var k: Dictionary = Game.v18()["kills"]
	k[type] = int(k.get(type, 0)) + 1
	world.boss_victory.emit(self)
	super.die()

# ================================================================ drawing
func _ellipse(cv: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, width := -1.0) -> void:
	cv.draw_set_transform(c, 0.0, Vector2(1.0, ry / max(1.0, rx)))
	if width < 0.0:
		cv.draw_circle(Vector2.ZERO, rx, col)
	else:
		cv.draw_arc(Vector2.ZERO, rx, 0, TAU, 40, col, width * rx / max(1.0, ry), true)
	cv.draw_set_transform(Vector2.ZERO)

## stagger stars, the pillar shield, the phase-change glow, the King's armour or open core
func _draw_over() -> void:
	if dead or cloaked:
		return
	if type == "zahhak":
		_draw_zahhak()
	var t := Time.get_ticks_msec() / 1000.0
	var mid := Vector2(0, -box.y * 0.5)
	var has_dedicated_warden_sprite := anim != null and anim.visible and anim.sprite_frames != null and anim.sprite_frames.has_animation("v0")
	if type == "alborzwarden" and not has_dedicated_warden_sprite:
		_draw_alborzwarden(t)
	if staggered > 0.0:
		for i in 4:
			var a := t * 3.85 + i * PI * 0.5
			var p := Vector2(cos(a) * 22.0, -box.y - 8.0 + sin(a) * 6.0)
			var pts := PackedVector2Array()
			for kk in 10:
				var b := -PI * 0.5 + kk * PI * 0.2
				pts.append(p + Vector2(cos(b), sin(b)) * (5.5 if kk % 2 == 0 else 2.3))
			over.draw_colored_polygon(pts, Color(1, 0.88, 0.54))
	if shield > 0:
		_ellipse(over, mid, box.x * 0.95, box.y * 0.75, Color(0.75, 0.55, 1.0, 0.45 + 0.2 * sin(t * 6.6)), 3.0)
	if inv > 0.0:
		_ellipse(over, mid, box.x, box.y * 0.8, Color(rgb, 0.25))
	if dazed > 0.0:
		for i in 2:
			over.draw_arc(Vector2(-7 + i * 14, -box.y - 12), 4.0, PI, TAU, 8, Color(0.85, 1.0, 0.69), 2.0)
	if type == "boss2" and heat >= 0.0:
		if vent > 0.0:
			over.draw_circle(mid, 22.0, Color(1, 0.78, 0.35, 0.35))
			over.draw_circle(mid, 13.0, Color(1, 0.9, 0.6, 0.7))
			over.draw_circle(mid, 6.0, Color(1, 1, 0.86, 0.95))
		elif armor:
			_ellipse(over, mid, box.x * 0.8, box.y * 0.66, Color(1, 0.55, 0.2, 0.3 + 0.15 * sin(t * 7.1)), 3.0)


## In-engine placeholder silhouette; final painted sprite art is still an explicit art task.
func _draw_alborzwarden(t: float) -> void:
	var pulse := 0.82 + 0.12 * sin(t * 4.0)
	var left_wing := PackedVector2Array([
		Vector2(-13, -45), Vector2(-34, -61), Vector2(-59, -54), Vector2(-48, -39),
		Vector2(-66, -30), Vector2(-38, -25), Vector2(-22, -14)
	])
	var right_wing := PackedVector2Array([
		Vector2(13, -45), Vector2(34, -61), Vector2(59, -54), Vector2(48, -39),
		Vector2(66, -30), Vector2(38, -25), Vector2(22, -14)
	])
	over.draw_colored_polygon(left_wing, Color8(42, 73, 98, 235))
	over.draw_colored_polygon(right_wing, Color8(42, 73, 98, 235))
	over.draw_polyline(left_wing + PackedVector2Array([left_wing[0]]), Color8(146, 212, 240), 2.0, true)
	over.draw_polyline(right_wing + PackedVector2Array([right_wing[0]]), Color8(146, 212, 240), 2.0, true)
	var mantle := PackedVector2Array([
		Vector2(-22, -46), Vector2(-18, -68), Vector2(-9, -77), Vector2(9, -77),
		Vector2(18, -68), Vector2(22, -46), Vector2(15, -18), Vector2(0, -10), Vector2(-15, -18)
	])
	over.draw_colored_polygon(mantle, Color8(31, 48, 67))
	over.draw_polyline(mantle + PackedVector2Array([mantle[0]]), Color8(118, 174, 204), 2.0, true)
	over.draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -70), Vector2(-9, -84), Vector2(0, -89), Vector2(9, -84),
		Vector2(12, -70), Vector2(0, -62)
	]), Color8(180, 207, 219))
	over.draw_line(Vector2(-7, -83), Vector2(-22, -96), Color8(187, 221, 236), 4.0, true)
	over.draw_line(Vector2(7, -83), Vector2(22, -96), Color8(187, 221, 236), 4.0, true)
	over.draw_line(Vector2(-22, -96), Vector2(-29, -90), Color8(100, 148, 175), 2.0, true)
	over.draw_line(Vector2(22, -96), Vector2(29, -90), Color8(100, 148, 175), 2.0, true)
	over.draw_circle(Vector2(-5, -75), 2.7, Color8(220, 248, 255))
	over.draw_circle(Vector2(5, -75), 2.7, Color8(220, 248, 255))
	over.draw_circle(Vector2(0, -36), 8.0, Color(0.54, 0.83, 0.98, pulse))
	over.draw_circle(Vector2(0, -36), 3.2, Color(0.92, 0.98, 1.0, pulse))
	for i in range(3):
		var radius := 31.0 + float(i) * 8.0 + sin(t * 3.0 + float(i)) * 2.0
		over.draw_arc(Vector2(0, -44), radius, -2.65, -0.48, 24, Color(0.58, 0.83, 0.98, 0.28 - float(i) * 0.05), 2.0, true)
		over.draw_arc(Vector2(0, -44), radius, 0.48, 2.65, 24, Color(0.58, 0.83, 0.98, 0.28 - float(i) * 0.05), 2.0, true)

## called by the telegraph layer (under everything): tethers, the mud shadow, the heat glow
func draw_ground(cv: CanvasItem) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if type == "boss":
		var c := center()
		for pl in pillars:
			if not is_instance_valid(pl) or pl.dead or cloaked:
				continue
			var a: Vector2 = pl.global_position + Vector2(0, -pl.box.y + 8)
			var ctrl := Vector2((a.x + c.x) * 0.5, min(a.y, c.y) - 40.0)
			var pts := PackedVector2Array()
			for i in 13:
				var k := i / 12.0
				pts.append(a.lerp(ctrl, k).lerp(ctrl.lerp(c, k), k))
			cv.draw_polyline(pts, Color(0.7, 0.47, 1.0, 0.35 + 0.2 * sin(t * 8.3 + a.x)), 3.0, true)
	if type == "ancientwyrm" and shadow_on:
		_ellipse(cv, shadow, 46.0 + sin(t * 9.0) * 4.0, 20.0, Color(0.02, 0.05, 0.1, 0.5))
		_ellipse(cv, shadow, 30.0, 13.0, Color(0.02, 0.05, 0.1, 0.35))
	if type == "matriarch" and shadow_on:
		_ellipse(cv, shadow, 34.0 + sin(t * 11.0) * 3.0, 16.0, Color(0.08, 0.16, 0.06, 0.55))
		for i in 3:
			var r := fmod(t * 125.0 + i * 18.0, 54.0) + 10.0
			_ellipse(cv, shadow, r, r * 0.45, Color(0.59, 0.86, 0.43, 0.5 * (1.0 - r / 64.0)), 2.0)
	if type == "boss2" and heat >= 0.0 and not cloaked:
		var k2 := heat / 100.0
		for i in 4:
			_ellipse(cv, global_position, 70.0 - i * 15.0, 30.0 - i * 6.0, Color(1, 0.47, 0.16, 0.09 * k2))
