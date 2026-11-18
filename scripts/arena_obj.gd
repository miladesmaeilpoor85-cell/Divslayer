extends "res://scripts/enemy.gd"
## Boss arena objects (v18_bosses.js "V18.obj"): Arzhang's grave pillars (each one standing
## soaks 20% of his damage), the Sorceress's bog eggs (hatch after 7 s), the White Div's ice echoes
## (drift after you, copy her spells, break in one hit; break both within 7 s for a big stagger).
## They give no XP or gold; fire burns eggs and melts echoes at once; ice and stun do nothing to them.

var owner_boss: Node = null
var hatch := -1.0
var kids: Array = []
var born := 0.0
var col := Color(0.8, 0.8, 0.8)
var wob := 0.0

func configure(opts: Dictionary) -> void:
	if opts.has("hp"):
		max_hp = max(1.0, round(float(opts["hp"])))
		hp = max_hp
	if opts.has("speed"):
		spd = float(opts["speed"]) * Game.PXS
	if opts.has("dmg"):
		dmg = float(opts["dmg"])
	owner_boss = opts.get("owner", null)
	hatch = float(opts.get("hatch", -1.0))
	kids = opts.get("kids", [])
	born = float(opts.get("born", 0.0))
	col = opts.get("col", col)
	world.burst(center(), col, 10, 110.0)

func _after_setup() -> void:
	add_to_group("arena")
	knock_mult = 0.0
	xp = 0
	gold = 0
	boss = false
	if anim and type == "arbiterclone":
		anim.modulate.a = 0.42

func apply_status(kind: String, sec: float, potency := 1.0) -> void:
	if dead:
		return
	if kind == "burn" and (type == "bogegg" or type == "arbiterclone"):
		world.float_text(global_position + Vector2(0, -box.y - 8), Game.t("Burnt!", "سوخت!") if type == "bogegg" else Game.t("Melted!", "ذوب شد!"), Color(1, 0.69, 0.38))
		die()
		return
	if kind == "freeze" or kind == "stun":
		return
	super.apply_status(kind, sec, potency)

func _physics_process(dt: float) -> void:
	if dead:
		return
	_flash(dt)
	_hover(dt)
	hit_cd = max(0.0, hit_cd - dt)
	if type == "arbiterclone" and anim:
		var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 110.0 + global_position.x * 0.1)
		anim.modulate = Color(0.85 + 0.6 * k, 0.95 + 0.5 * k, 1.4, 0.32 + 0.22 * k) if flash <= 0.0 else Color(3, 3, 3, 0.6)
	_estatus(dt)
	if dead:
		return
	var p = get_tree().get_first_node_in_group("player")
	if p == null or p.dead:
		return
	match type:
		"bogegg":
			hatch -= dt
			var k2: float = clamp(1.0 - hatch / 7.0, 0.0, 1.0)
			wob += dt
			if anim:
				var w := sin(wob * 1000.0 / (120.0 - 80.0 * k2)) * 0.05 * (0.3 + k2)
				anim.scale = Vector2(1.0 + w, 1.0 - w) * (1.0 / 3.0)
				if hatch < 2.5 and flash <= 0.0:
					anim.modulate = Color(1.0 + 0.6 * (0.5 + 0.5 * sin(wob * 11.0)), 1.4, 1.0)
			if hatch <= 0.0:
				_hatch()
		"arbiterclone":
			var to: Vector2 = p.pc() - center()
			var l := to.length()
			if l > 90.0:
				velocity = to / l * spd
				move_and_slide()
			if anim and abs(to.x) > 2.0:
				anim.flip_h = to.x < 0.0
			if hit_cd <= 0.0 and hit_rect().intersects(p.body_rect()) and owner_boss and is_instance_valid(owner_boss):
				owner_boss.bfx.hit(self, 1.0, ["freeze", 1.2, 1])
				hit_cd = 0.9

func _hatch() -> void:
	dead = true
	remove_from_group("enemies")
	world.burst(center(), Color(0.72, 0.94, 0.56), 14, 140.0)
	Sfx.play("poison")
	# (v0.23, playtest: "48 foes in the Sorceress's fight") the brood is capped: no more than five small foes around
	var near := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead and not e.boss and e.world == world and e.global_position.distance_to(global_position) < 420.0:
			near += 1
	for i in kids.size():
		if near >= 5:
			break
		world.spawn_enemy(str(kids[i]), global_position + Vector2(i * 14 - 7, 0))
		near += 1
	queue_free()

func die() -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemies")
	collision_layer = 0
	world.burst(center(), col, 12, 130.0)
	Sfx.play("ice" if type == "arbiterclone" else "kill", -3.0)
	if type == "arbiterclone" and owner_boss and is_instance_valid(owner_boss) and not owner_boss.dead:
		var left := 0
		for e in owner_boss.echoes():
			if e != self:
				left += 1
		if left == 0 and owner_boss.bfx.clock - born < 7.0:
			world.float_text(owner_boss.global_position + Vector2(0, -owner_boss.box.y - 28), Game.t("Shattered!", "خرد شد!"), Color(0.81, 0.94, 1.0), true)
			owner_boss.add_stagger(45.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)

## the boss fell: its arena crumbles
func vanish() -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemies")
	world.burst(center(), Color(0.8, 0.8, 0.8), 8, 90.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)
