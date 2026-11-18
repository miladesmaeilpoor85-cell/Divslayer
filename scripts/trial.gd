extends Node
## The Trial of Embers (v0.16): endless waves in the Trial Grounds, one after another until the hero falls or walks out of the
## southern gate. Every wave is bigger and tougher; from wave 4 some foes are elites; every fifth wave brings a champion.
## The foe tiers come from the HTML game (EI_TRIAL); the numbers are mine.

signal wave_started(n: int)
signal wave_cleared(n: int)
signal run_ended(cleared: int)

const START_DELAY := 3.0
const REST := 5.0

var world: Node = null
var wave := 0                 # the wave being fought (0 before the first)
var cleared := 0              # waves fully cleared in this run
var mode := "idle"            # idle | countdown | fighting | rest | over
var timer := 0.0
var active := false
var foes: Array = []

## what wave n holds (pure: tests read it)
static func plan(n: int) -> Dictionary:
	var tier: int = mini(2, int((n - 1) / 3))
	var champ: bool = n % 5 == 0
	return {
		"n": n, "tier": tier,
		"count": mini(14, 3 + n) if not champ else mini(8, 2 + n / 2),
		"champion": champ,
		"elite": 0.0 if n < 4 else minf(0.35, 0.10 + 0.02 * n),
		"hp": 1.0 + 0.10 * (n - 1), "dmg": 1.0 + 0.05 * (n - 1),
		"gold": 20 + 8 * n, "xp": 15 + 6 * n,
	}

static func pool(tier: int) -> Array:
	var t: Array = Game.table("EI_TRIAL")
	var out: Array = []
	for i in range(maxi(0, tier - 1), tier + 1):
		out.append_array(t[mini(i, t.size() - 1)])
	return out

func _ready() -> void:
	tree_exiting.connect(end_run)
	start_run()

func start_run() -> void:
	wave = 0
	cleared = 0
	active = true
	mode = "countdown"
	timer = START_DELAY
	if world:
		world.banner.emit(Game.t("Trial of Embers", "آزمونِ اخگر"), Game.t("The Trial begins! Survive the endless waves.", "آزمون آغاز شد! در برابر موج‌های بی‌پایان بایست."), Color(1.0, 0.55, 0.2), 2.2)

func _process(dt: float) -> void:
	if not active:
		return
	match mode:
		"countdown", "rest":
			timer -= dt
			if timer <= 0.0:
				start_wave()
		"fighting":
			timer -= dt
			if timer <= 0.0:
				timer = 0.4
				foes = foes.filter(func(e): return is_instance_valid(e) and not e.dead)
				if foes.is_empty():
					_clear_wave()

func start_wave() -> void:
	wave += 1
	var pl := plan(wave)
	foes = []
	var names := pool(int(pl["tier"]))
	var hero = get_tree().get_first_node_in_group("player")
	for i in int(pl["count"]):
		_spawn(names[randi() % names.size()], pl, hero, randf() < float(pl["elite"]))
	if bool(pl["champion"]):
		var cp := pool(2)
		_spawn(cp[randi() % cp.size()], pl, hero, true, true)
	mode = "fighting"
	timer = 1.0
	wave_started.emit(wave)
	if world:
		var sub := Game.t("%d foes" % foes.size(), "%s دشمن" % Game.num(foes.size()))
		if bool(pl["champion"]):
			sub = Game.t("A champion of the foe comes!", "گُردی از سپاهِ دشمن می‌آید!")
		world.banner.emit(Game.t("Wave ", "موج ") + Game.num(wave), sub, Color(1.0, 0.6, 0.25) if not bool(pl["champion"]) else Color(1.0, 0.35, 0.25), 1.8)
		Sfx.play("quest", -6.0)

func _spawn(type: String, pl: Dictionary, hero, elite: bool, champion := false) -> void:
	if world == null:
		return
	var feet := Vector2(550, 360)
	for tries in 30:
		var f := Vector2(randf_range(80, world.size.x - 80), randf_range(100, world.size.y - 140))
		if world.free_spot(f, Vector2(30, 30)) and (hero == null or f.distance_to(hero.global_position) > 220.0):
			feet = f
			break
	var e = world.spawn_enemy(type, feet)
	e.max_hp = e.max_hp * float(pl["hp"])
	e.hp = e.max_hp
	e.dmg = e.dmg * float(pl["dmg"])
	e.rally = true                 # the arena foes come for you from the first moment
	if elite:
		var els := ["fire", "ice", "storm"]
		e.make_elite(els[randi() % 3], 4.0 if champion else 1.0)
	if world.fx:
		world.fx.ring(e.global_position + Vector2(0, -12), Color(1, 0.6, 0.3), 16.0, 0.4)
	foes.append(e)

func _clear_wave() -> void:
	cleared = wave
	var pl := plan(wave)
	var g := int(round(float(pl["gold"]) * Game.gold_mul()))
	var x := int(round(float(pl["xp"]) * Game.xp_mul()))
	Game.state["gold"] = int(Game.state.get("gold", 0)) + g
	var lvl0 := Game.lvl()
	Game.add_xp(x)
	if Game.lvl() > lvl0 and world:
		world.level_up.emit(Game.lvl())
	var tr := Game.trial()
	tr["best"] = maxi(int(tr.get("best", 0)), cleared)
	Game.save_game()
	var extra := ""
	if bool(pl["champion"]):
		Game.Gear.grant(Game.Gear.roll("epic" if wave >= 10 else "rare"))
	if world:
		world.banner.emit(Game.num(wave) + " " + Game.t("waves cleared", "موجِ پاک‌شده"), "+%s %s" % [Game.num(g), Game.t("gold", "سکه")] + Game.sep() + "+%s %s" % [Game.num(x), Game.t("XP", "تجربه")], Color(0.6, 0.9, 0.5), 2.0)
		Sfx.play("coin", -3.0)
	wave_cleared.emit(wave)
	mode = "rest"
	timer = REST

## the run is over: the hero died, left by the gate, or the map is going away
func end_run() -> void:
	if not active:
		return
	active = false
	mode = "over"
	var tr := Game.trial()
	tr["best"] = maxi(int(tr.get("best", 0)), cleared)
	tr["runs"] = int(tr.get("runs", 0)) + 1
	Game.save_game()
	run_ended.emit(cleared)
