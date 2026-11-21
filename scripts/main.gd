extends Node
## Owns the flow: title menu -> world. Switches maps when the hero walks through an exit,
## handles death/respawn and autosaves. Test modes: `-- --autotest` and `-- --shots <dir>`.

const World = preload("res://scripts/world.gd")
const Player = preload("res://scripts/player.gd")
const Hud = preload("res://scripts/hud.gd")
const Menu = preload("res://scripts/menu.gd")

var world: Node2D = null
var player: CharacterBody2D = null
var hud: CanvasLayer = null
var menu: Control = null
var switching := false
var quiet_until := -1.0     # after a rematch the boss is met again without a card or banner
var rush_run: Node = null   # (v0.21) the Boss Rush in progress (scripts/rush.gd)
var clock := 0.0

func _ready() -> void:
	# (v0.27, engineering) a store build runs no test hook
	var dbg := OS.is_debug_build()
	var ti := Game.args.find("--test") if dbg else -1
	# (v0.23) --playtest: the playtest runner drives the game, but the game stays as a player gets it
	Game.testing = dbg and (Game.has_arg("--autotest") or ti >= 0) and not Game.has_arg("--playtest")
	if Game.testing:
		Game.Ach.reset()          # (v0.20) every test run starts from an empty test profile (no look worn, nothing earned)
	if dbg and (Game.has_arg("--autotest") or Game.has_arg("--shots") or ti >= 0):
		var path := "res://tests/autotest.gd" if ti < 0 or ti + 1 >= Game.args.size() else Game.args[ti + 1]
		var T = load(path)
		if T == null or not T.can_instantiate():
			printerr("AUTOTEST_FAILED_TO_LOAD")
			get_tree().quit(1)
			return
		var t = T.new()
		add_child(t)
		t.run(self)
		return
	show_menu()
	var i := Game.args.find("--menushot") if dbg else -1
	if i >= 0 and i + 1 < Game.args.size():
		for k in 40:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(Game.args[i + 1])
		get_tree().quit()

var menu_bg: Node2D = null

func show_menu() -> void:
	_menu_backdrop()
	var layer := CanvasLayer.new()
	layer.name = "MenuLayer"
	layer.layer = 10
	add_child(layer)
	menu = Menu.new()
	layer.add_child(menu)
	menu.start_game.connect(_on_start)
	# A debug-only readiness probe prevents Android QA from mistaking the native
	# Godot splash screen for a successfully rendered game title screen.
	if OS.is_debug_build():
		call_deferred("_qa_validate_title_menu")

func _qa_validate_title_menu() -> void:
	await get_tree().process_frame
	if menu == null or not is_instance_valid(menu):
		push_error("DIVSLAYER_TITLE_MENU_FAIL: menu node was not created")
		return
	var logo_found := false
	var labels: Array[Node] = menu.find_children("*", "Label", true, false)
	for candidate in labels:
		var label := candidate as Label
		if label != null and label.text.strip_edges() in ["Divslayer", "دیوکُش"]:
			logo_found = true
			break
	var new_game := menu.find_child("NewGame", true, false) as Button
	var new_game_ready := new_game != null and new_game.is_visible_in_tree()
	var background_ready := menu_bg != null and is_instance_valid(menu_bg) and menu_bg.get_child_count() > 0
	if not logo_found or not new_game_ready or not background_ready:
		push_error("DIVSLAYER_TITLE_MENU_FAIL: logo=%s new_game=%s village_background=%s" % [
			logo_found, new_game_ready, background_ready
		])
		return
	print("DIVSLAYER_TITLE_MENU_READY title=true new_game=true background=true")

## the title screen sits over the living village: a camera drifts slowly across it
func _menu_backdrop() -> void:
	if menu_bg:
		menu_bg.queue_free()
	menu_bg = World.new()
	add_child(menu_bg)
	menu_bg.build("village")
	# the title shows Zabol by night: lamps lit, fireflies out
	menu_bg.lighting.forced_phase = 3
	menu_bg.atmos.calm = true
	menu_bg.atmos.set_weather("")
	Music.set_boss(false)
	Music.play_region("title")
	var cam := Camera2D.new()
	cam.position = Vector2(300, 330)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(menu_bg.size.x)
	cam.limit_bottom = int(menu_bg.size.y)
	menu_bg.add_child(cam)
	cam.make_current()
	var tw := cam.create_tween().set_loops()
	tw.tween_property(cam, "position", Vector2(620, 380), 18.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "position", Vector2(300, 330), 18.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_start(cls: String, cont: bool) -> void:
	if cont and Game.load_game():
		pass
	else:
		if cont and FileAccess.file_exists(Game.SAVE_PATH):
			# (v0.27, engineering) neither the save nor its .bak can be read: keep it for the developer, do not overwrite it
			DirAccess.rename_absolute(Game.SAVE_PATH, "user://save.broken.json")
		Game.new_game(cls if cls != "" else "warrior")
	if menu:
		menu.get_parent().queue_free()
		menu = null
	if menu_bg:
		menu_bg.queue_free()
		menu_bg = null
	start_world()

func start_world() -> void:
	player = Player.new()
	player.setup()
	player.died.connect(_on_died)
	player.interact.connect(_on_interact)
	hud = Hud.new()
	add_child(hud)
	hud.build(player)
	hud.death.rematch.connect(_rematch)
	hud.death.respawn.connect(_respawn)
	hud.quit_to_title.connect(_quit_to_title)
	# (v0.20) what an older save already did counts toward the achievements (quietly, then one line about it)
	var came: int = Game.Ach.sync()
	goto_map(str(Game.state.get("map", "village")), Vector2(float(Game.state.get("x", 433)), float(Game.state.get("y", 524))))
	_safe_arrival()
	if came > 0:
		hud.toast(Game.t("Achievements earned so far: %d — see Menu → Hero" % came,
			"%s دستاورد از سفرت تا این‌جا به دست آمد — فهرست ← قهرمان" % Game.num(came)), "trophy", UI.GOLD_HI)

func goto_map(key: String, feet: Vector2) -> void:
	if player.get_parent():
		player.get_parent().remove_child(player)
	if world:
		# (v0.27, QA: "goto shadowfen -> on dungeon") the old map lives until the end of the frame and shares the physics
		# space: its exits are switched off and cut from the map change before it goes
		world.exits_armed = false
		if world.exit_reached.is_connected(_on_exit):
			world.exit_reached.disconnect(_on_exit)
		world.queue_free()
		preload("res://scripts/sheets.gd").forget_enemies()
	world = World.new()
	add_child(world)
	world.build(key)
	world.exit_reached.connect(_on_exit)
	world.message.connect(func(t): hud.toast(t, "lock"))
	world.notice.connect(func(t, ic): hud.toast(t, ic, UI.GOLD_HI))
	world.lore.connect(_on_lore.bind(""))
	world.lore_sheet.connect(_on_lore)
	world.boss_down.connect(_on_boss_down)
	world.parley_started.connect(_on_parley)
	if not Game.item_found.is_connected(_on_item_found):
		Game.item_found.connect(_on_item_found)
	world.boss_engaged.connect(_on_engage)
	world.boss_victory.connect(_on_victory)
	world.banner.connect(func(a, b, c, sec): hud.banner(a, b, c, sec))
	world.tip_shown.connect(func(t): hud.hint(t))
	world.level_up.connect(_on_level_up)
	if not Game.fight.is_empty() and Game.fight.get("map", "") != key:
		Game.fight = {}
	world.ysort.add_child(player)
	player.enter_world(world, feet)
	world._arrived_at = player.global_position
	Game.state["map"] = key
	var seen: Dictionary = Game.state.get("visited", {})
	seen[key] = true
	Game.state["visited"] = seen
	Game.state["x"] = feet.x
	Game.state["y"] = feet.y
	Game.save_game()
	hud.clear_msgs()
	hud.show_title(Game.map_title(key))
	hud.refresh()
	Music.set_boss(false)
	Music.play_region(key)
	switching = false
	if not hud.shop.bought.is_connected(player.refresh_look):
		hud.shop.bought.connect(player.refresh_look)

func _on_exit(to: String, spawn: Vector2) -> void:
	if switching:
		return
	switching = true
	_travel.call_deferred(to, spawn)

## a short fade to black between maps
func _travel(to: String, spawn: Vector2) -> void:
	hud.pad.release_all()
	await hud.fade_out()
	goto_map(to, spawn)
	hud.fade_in()

## Pause menu -> Save & quit: back to the title screen
func _quit_to_title() -> void:
	var keep_spot := rush_run == null and Game.fight.is_empty()
	if rush_run:
		rush_run.abort()          # (v0.21) a run cut short gives back what it set aside
		rush_run = null
	# (v0.27, QA: "Save & quit, Continue: the hero is back at the map's entrance") the spot he stands on is saved too —
	# (code review) not out of a Boss Rush memory (its abort has already set the Sanctum's spot), nor from the middle
	# of a boss fight (he would come back beside a boss at full health)
	if keep_spot and player and is_instance_valid(player) and not player.dead and world:
		Game.state["x"] = player.global_position.x
		Game.state["y"] = player.global_position.y
	Game.save_game()
	Game.fight = {}
	if world:
		world.queue_free()
		world = null
	if hud:
		hud.queue_free()
		hud = null
	player = null
	get_tree().paused = false
	show_menu()

func _physics_process(dt: float) -> void:
	clock += dt
	if world and player and not player.dead:
		Game.tick_day(dt)

var _lost := 0

func _on_died() -> void:
	if rush_run and not Game.rush.is_empty():
		# (v0.21) a memory of the Boss Rush: the run ends, no gold is lost, you wake by Sorush
		hud.pad.release_all()
		Sfx.play("defeat")
		Game.vibrate(200, 1.0)
		rush_run.on_died()
		return
	var in_trial: bool = world != null and world.key == "trial"
	if in_trial and world.trial:
		world.trial.end_run()
	# Keep the purse unchanged while the player chooses. The respawn option applies this loss;
	# a rematch costs nothing and therefore never needs a temporary refund.
	_lost = 0 if in_trial else int(floor(int(Game.state.get("gold", 0)) * 0.2))
	hud.pad.release_all()
	Music.set_boss(false)
	Sfx.play("defeat")
	Game.vibrate(200, 1.0)
	await get_tree().create_timer(1.0, false).timeout
	if hud == null or world == null or player == null or not is_instance_valid(player) or not player.dead:
		return
	# a rematch is offered when the boss of the fight in progress still stands on this map
	var bt := ""
	if not Game.fight.is_empty() and Game.fight.get("map", "") == world.key:
		for b in get_tree().get_nodes_in_group("bosses"):
			if b.type == Game.fight["type"] and not b.dead:
				bt = b.type
		if bt == "":
			# the boss of the fight fell, but another one here was in it too
			for b2 in get_tree().get_nodes_in_group("bosses"):
				if not b2.dead and b2.engaged and b2.world == world:
					bt = b2.type
					Game.fight["type"] = bt
	hud.death.open(_lost, bt)

func _respawn() -> void:
	Game.fight = {}
	if _lost > 0:
		Game.state["gold"] = max(0, int(Game.state.get("gold", 0)) - _lost)
		_lost = 0
		Game.stats_changed.emit()
	player.revive()
	goto_map("village", Vector2(433, 524))
	_safe_arrival()

## (v0.23, playtest: "after a load or a retry a foe stands 3 px away and hits at once") a moment's grace on arrival, and
## the foes on the doorstep (not a boss) are pushed back
func _safe_arrival() -> void:
	if player == null or world == null:
		return
	player.invuln = max(player.invuln, 2.0)
	var feet: Vector2 = player.global_position
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead or e.boss or e.world != world:
			continue
		var d: Vector2 = e.global_position - feet
		# (v0.24, playtest: pushed away, it simply walked back while the screen still faded in) the ones near have not
		# noticed the hero yet: a few seconds to look around
		if d.length() < 450.0:
			e.alert = false
			e.calm = 3.5
		if d.length() < 130.0:
			var dir: Vector2 = d.normalized() if d.length() > 1.0 else Vector2.RIGHT.rotated(randf() * TAU)
			for step in [170.0, 140.0, 200.0, 240.0]:
				var to: Vector2 = feet + dir * step
				if not world.wall_hit(Rect2(to - Vector2(10, 20), Vector2(20, 20))):
					e.global_position = to
					break

## V18 retry: back at the arena where the fight began without a gold penalty; potions are restored
func _rematch() -> void:
	var f: Dictionary = Game.fight
	_lost = 0
	player.revive()
	Game.state["potions"] = max(int(Game.state.get("potions", 0)), int(f.get("potions", 0)))
	quiet_until = clock + 4.0
	goto_map(str(f["map"]), f["feet"])
	_safe_arrival()
	f["retries"] = int(f.get("retries", 0)) + 1
	Game.fight = f
	hud.banner(Game.t("Again!", "دوباره!"), Game.boss_name(str(f["type"])), Game.boss_cfg(str(f["type"])).get("rgb", Color.WHITE), 1.2)
	hud.refresh()

## the hero walks into a boss's arena (V18.engage): remember the fight for a rematch,
## play the name card the first time, otherwise a short banner
func _on_engage(b: Node) -> void:
	var again: int = int(Game.fight.get("retries", 0)) if Game.fight.get("type", "") == b.type else 0
	Game.fight = {"type": b.type, "map": world.key, "feet": player.global_position, "potions": int(Game.state.get("potions", 0)), "retries": again}
	hud.boss_ui.track(b)
	Music.set_boss(true, b.type)
	if clock < quiet_until:
		quiet_until = -1.0
	elif not b.mini and not Game.v18()["seen"].has(b.type):
		Game.v18()["seen"][b.type] = true
		hud.pad.release_all()
		# (v0.24, critic: the letterbox cut Zahhak's serpents off) the card frames the boss's upper body, not the hero
		if player and player.cam and player.cam.has_method("frame"):
			# (v0.26, the critic: the White Div's card opened from far off and showed only the edge of him under the lower
			# bar) the further the boss, the more of the way the camera goes: he is never more than 30 px off its centre
			var bust: Vector2 = b.global_position + Vector2(0, -float(b.box.y) * 0.5)
			player.cam.frame(bust, clamp(1.0 - 30.0 / max(1.0, bust.distance_to(player.global_position)), 0.65, 1.0))
			if not hud.intro.done.is_connected(player.cam.unframe):
				hud.intro.done.connect(player.cam.unframe)
		hud.intro.play(b.type)
	else:
		hud.banner(Game.boss_name(b.type), Game.boss_title(b.type), b.rgb, 1.6)
	Game.state["x"] = player.global_position.x
	Game.state["y"] = player.global_position.y
	Game.save_game()

## level up: a pillar of light on the hero and a banner with what grew
func _on_level_up(lv: int) -> void:
	if world and world.fx and player:
		var c: Vector2 = player.global_position + Vector2(0, -17)
		world.fx.ring(c, UI.GOLD_HI, 24.0, 0.6)
		world.fx.ring(c, Color(1, 1, 1), 12.0, 0.4)
		world.fx.emit("shine", player.global_position, 30, UI.GOLD_HI, Vector2.UP, 14.0, 230.0, 1.2)
		world.fx.emit("ember", c, 16, Color(1, 0.9, 0.5), Vector2.UP, 60.0, 90.0)
		world.fx.flash_light(c, 260.0, 1.0, Color(1, 0.88, 0.5), 1.0)
	Game.vibrate(60, 0.8)
	if hud:
		hud.level_up(lv)

## a talk that opens from the game itself (not from a tap on Talk): a little longer before a tap can skip it, so the
## blows and shields still being pressed do not throw it away unread (v0.24, playtest)
func _on_lore(title: String, ls: Array, sheet: String) -> void:
	hud.dialogue.open(title, ls, sheet)
	hud.dialogue._block_until = Time.get_ticks_msec() + 700

func _on_victory(b: Node) -> void:
	Game.fight = {}
	Game.victory_at = Time.get_ticks_msec()
	Music.set_boss(false)
	Sfx.play("victory")
	# (v0.24, playtest: five messages at once over a dead boss) the fight's tips ("Staggered — strike now!") go with it
	hud.notify.clear()
	if Game.is_echo(b.type):
		hud.banner(Game.t("DUST AGAIN", "به خاک برگشت"), Game.t("The echo of %s" % Game.no_the(Game.boss_name(b.type)), "پژواکِ %s" % Game.boss_name(b.type)), b.rgb, 2.6)
	else:
		hud.banner(Game.t("VANQUISHED", "از پا درآمد"), Game.boss_name(b.type), b.rgb, 2.6)
	if rush_run:
		rush_run.on_victory(b)
	elif b.type == "zahhak":
		_zahhak_bound()
	# (v0.23, playtest: in the bog, Bid the Div fell first and the Sorceress lost her health bar and her rematch)
	if not rush_run:
		for o in get_tree().get_nodes_in_group("bosses"):
			if o != b and is_instance_valid(o) and not o.dead and o.engaged and o.world == world:
				Game.fight = {"type": o.type, "map": world.key, "feet": player.global_position, "potions": int(Game.state.get("potions", 0)), "retries": 0}
				hud.boss_ui.track(o)
				Music.set_boss(true, o.type)
				break

func _notification(what: int) -> void:
	# (v0.27, engineering: "the Back gesture starts at the left edge, where the joystick thumb rests, and quits mid-fight")
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if hud and is_instance_valid(hud):
			# (v0.27, UX: "panels close only by the corner X") Back closes the panel on top first
			for pnl in [hud.shop, hud.forge, hud.craft]:
				if pnl and pnl.visible:
					pnl.close()
					return
			if get_tree().paused and hud.pause.visible:
				hud.pause.close()
			else:
				hud.open_pause()
		elif menu == null or not menu.has_method("back") or not menu.back():
			get_tree().quit()
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if player and world:
			Game.state["x"] = player.global_position.x
			Game.state["y"] = player.global_position.y
			Game.save_game()

# ---------------------------------------------------------------- people
const PLACEHOLDER := {
	# (v0.24) Rudabeh: Zal's wife, Rostam's mother — the Simorgh's herbs once saved her life when Rostam was born
	"alchemist": [["I am Rudabeh — Zal's wife, Rostam's mother. When Rostam was born, the Simorgh's feather and its herbs saved my life.", "من رودابه‌ام — همسرِ زال، مادرِ رستم. وقتی رستم به دنیا آمد، پرِ سیمرغ و گیاهانش جانم را نجات داد."],
		["Since then I brew what heals. Bring me Bogbloom from the Shadowfen, and I will brew potions and scrolls for you.", "از آن روز آنچه درمان می‌کند دم می‌کنم. برایم گلِ مرداب از مردابِ سایه بیاور تا برایت معجون و طومار بسازم."]],
	# (v0.25, the critic: Zahhak sawed Jamshid in two — and he says nothing of the ember of his own farr) he is a shade
	"brann": [["That ember on your hand... it was mine once. I lost the farr to my own pride, and Zahhak's saw found me after.", "آن اخگرِ روی دستت... روزی از آنِ من بود. فرّه را به غرورِ خودم باختم و پس از آن ارّهٔ ضحاک مرا یافت."],
		["I am only a shade now, bound to the First Flame that stirs beneath the mountain. Come back when the peaks no longer frighten you.", "اکنون تنها روانی‌ام، بسته به نخستین شعله که زیرِ کوه بیدار می‌شود. وقتی قله‌ها دیگر تو را نترساندند، برگرد."]],
	"keeper": [["The memories here are restless.", "یادهای این‌جا بی‌قرارند."],
		["One day I will show you what they remember.", "روزی نشانت می‌دهم که چه به یاد دارند."]],
}

func _on_interact(npc: Node) -> void:
	if get_tree().paused:
		return
	var id := str(npc.get_meta("id", ""))
	var who := Game.t(str(npc.get_meta("name_en", id)))
	match id:
		"quest_point":
			var result: Dictionary = Game.quest_point_interact(world.key, str(npc.get_meta("point_id", "")))
			if result.is_empty():
				return
			hud.dialogue.open(str(result.get("title", who)), [str(result.get("text", ""))], "")
			if world and world.has_method("_ensure_q1_boss"):
				world.call("_ensure_q1_boss")
			hud.refresh()
		"merchant":
			_talk_thalia(who)
		"strongbox":
			_take_strongbox()
		"ledger":
			_take_ledger()
		"smith":
			_talk_garen(who)
		"alchemist":
			_talk_miri(who)
		"board":
			_open_board()
		"altar":
			_shrine_altar()
		"tablet":
			var tabs: Array = Game.shrine_def(world.key).get("tablets", [])
			if not tabs.is_empty():
				hud.dialogue.open(Game.t("Ancient Tablet", "لوح کهن"), [Game.t(str(tabs[0][0]), str(tabs[0][1]))], "")
		"arena":
			_open_arena()
		"elder":
			hud.dialogue.open(who, Game.elder_lines(), "elder")
			hud.dialogue.finished.connect(_after_elder, CONNECT_ONE_SHOT)
			hud.refresh()
		"keeper":
			_talk_keeper(who)
		"hesk":
			_talk_hesk(who)
		"qaren":
			_talk_qaren(who)
		"alborz_scout":
			hud.dialogue.open(who, Game.Ch4.scout_lines(world), "hesk")
			hud.dialogue.finished.connect(_after_alborz_scout.bind(world), CONNECT_ONE_SHOT)
		"rostam":
			_talk_rostam(who)
		"siavash":
			_open_arena(who)
		"gordafarid":
			_open_board(who)
		"brann":
			var fl: Array = Game.Ch2.brann_lines()
			if not fl.is_empty():
				hud.dialogue.open(who, fl, "brann")
				hud.dialogue.finished.connect(_brann_frost, CONNECT_ONE_SHOT)
				return
			if Game.is_defeated("boss2") and not bool(Game.state.get("gift_firewall", false)):
				var gift := [["You brought the King of Mazandaran down. The mountain breathes easier — and so do I.", "شاه مازندران را زمین زدی. کوه راحت‌تر نفس می‌کشد — من هم."],
					["Take this. Fire answers those who are not afraid of it.", "این را بگیر. آتش جواب کسی را می‌دهد که از آن نمی‌ترسد."],
					["Emberwall: seven burning bolts, fanned before you. Bind it in your Skills.", "دیوارِ اخگر: هفت تیرِ سوزان که پیش رویت باز می‌شوند. در مهارت‌هایت ببندش."]]
				var gl := []
				for pair in gift:
					gl.append(Game.t(pair[0], pair[1]))
				hud.dialogue.open(who, gl, "brann")
				hud.dialogue.finished.connect(_brann_gift, CONNECT_ONE_SHOT)
				return
			var bl: Array = Game.brann_lines()
			if not bl.is_empty():
				hud.dialogue.open(who, bl, "brann")
				hud.dialogue.finished.connect(_brann_step, CONNECT_ONE_SHOT)
				return
			var lines2 := []
			for pair in PLACEHOLDER.get(id, [["...", "..."]]):
				lines2.append(Game.t(pair[0], pair[1]))
			hud.dialogue.open(who, lines2, "brann")
		_:
			var lines := []
			for pair in PLACEHOLDER.get(id, [["...", "..."]]):
				lines.append(Game.t(pair[0], pair[1]))
			hud.dialogue.open(who, lines, id if id in World.NPC_LOOKS else "merchant")

## (v0.18) a shrine's altar: its gold and treasure, then the Shrine Sigil — the hero chooses its gift
func _after_alborz_scout(active_world: Node) -> void:
	if world == null or active_world != world or not is_instance_valid(active_world):
		return
	var msg := Game.Ch4.scout_done(active_world)
	if msg != "":
		hud.toast(msg, "check", UI.GOLD_HI)
		Sfx.play("quest", -2.0)
	hud.refresh()


func _shrine_altar() -> void:
	var sh = world.get("shrine") if world else null
	if sh == null:
		return
	if not sh.door_open:
		return
	var s: Dictionary = Game.shrine(world.key)
	if str(s.get("gift", "")) != "":
		hud.toast(Game.t("The altar is silent. Its gift is yours.", "محراب خاموش است. هدیه‌اش از آنِ توست."), "check")
		return
	for line in sh.claim():
		hud.toast(line, "coins", UI.GOLD_HI)
	var opts := []
	_sigil_ids = []
	for id in Game.SIGILS:
		var g: Dictionary = Game.SIGILS[id]
		var have := Game.sigil(id)
		opts.append({"label": Game.t(g["name"][0], g["name"][1]) + "  —  " + Game.t(g["label"][0], g["label"][1]) +
			("" if have == 0 else Game.t("  (×%d)" % have, "  (×%s)" % Game.num(have))), "ok": true})
		_sigil_ids.append(id)
	hud.dialogue.choose(Game.t("Shrine Sigil"), Game.t("The sigil answers your will. Choose its gift — it lasts forever."), opts, "")
	if not hud.dialogue.chosen.is_connected(_on_sigil):
		hud.dialogue.chosen.connect(_on_sigil, CONNECT_ONE_SHOT)

var _sigil_ids: Array = []

func _on_sigil(i: int) -> void:
	if world == null or i < 0 or i >= _sigil_ids.size():
		return
	var msg := Game.take_sigil(world.key, str(_sigil_ids[i]))
	if msg != "":
		hud.toast(msg, str(Game.SIGILS[_sigil_ids[i]]["icon"]), UI.GOLD_HI)
		Sfx.play("levelup", -2.0)
		var done := Game.shrines_done()
		hud.banner(Game.t("SHRINE CLEANSED", "زیارتگاه پاک شد"), Game.t("%d of %d shrines" % [done, Game.SHRINE_ORDER.size()], "%s از %s زیارتگاه" % [Game.num(done), Game.num(Game.SHRINE_ORDER.size())]), UI.GOLD_HI, 2.2)
		if world.fx and player:
			world.fx.ring(player.pc(), UI.GOLD_HI, 30.0, 0.6)
			world.fx.emit("shine", player.global_position, 24, UI.GOLD_HI, Vector2.UP, 20.0, 200.0, 1.1)
	hud.refresh()

## Jamshid's parting gift once the King of Mazandaran has fallen: the Emberwall spell
func _brann_step() -> void:
	var msg := Game.brann_step()
	if msg != "":
		hud.toast(msg, "key-round" if Game.brann() == "anvil" else "coins", UI.GOLD_HI)
		Sfx.play("quest", -2.0)
		Sfx.play("coin", -4.0)
		if Game.brann() == "done":
			await get_tree().create_timer(1.6).timeout
			if hud:
				hud.toast(Game.t("+3 talent points", "+۳ امتیاز استعداد"), "sparkles", UI.GOLD_HI)
	hud.refresh()

func _brann_gift() -> void:
	Game.state["gift_firewall"] = true
	Game.save_game()
	hud.toast(Game.t("Skill learned: ", "مهارت آموختی: ") + Game.Skills.spell_name("firewall"), "flame-kindling", Game.Skills.spell_col("firewall"))
	Sfx.play("quest", -2.0)
	hud.refresh()

func _after_elder() -> void:
	var msg := Game.elder_dialog_done()
	if msg != "":
		hud.toast(msg, "coins", UI.GOLD_HI)
		Sfx.play("coin")
		Sfx.play("quest", -4.0)
	match Game.Ch2.elder_done():
		"stirs":
			_wyrm_stirs()
		"end":
			_chapter_end()
	if Game.Ch3.elder_done() == "end":
		_chapter_end(3)
	var c4_message := Game.Ch4.elder_done()
	if c4_message != "":
		hud.toast(c4_message, "feather", UI.GOLD_HI)
		Sfx.play("quest", -2.0)
	hud.refresh()

# ---------------------------------------------------------------- chapter 2: The Sleeper Beneath (v0.19)
## the ground shakes under Zabol: the Wyrm wakes
func _wyrm_stirs() -> void:
	if world:
		world.shake(14.0)
	Game.vibrate(260, 1.0)
	Sfx.play("roar", 2.0)
	Sfx.play("trap", -2.0)
	hud.banner(Game.Ch2.line("stirs"), Game.Ch2.line("title"), Color8(110, 200, 240), 2.6)
	await get_tree().create_timer(2.8).timeout
	if hud:
		hud.toast(Game.Ch2.line("o_keeper"), "scroll-text", UI.GOLD_HI)
		Sfx.play("quest", -2.0)

func _talk_keeper(who: String) -> void:
	if Game.Rush.available():
		_keeper_menu(who)          # (v0.21) after the chapter: the Boss Rush and New Game+
		return
	hud.dialogue.open(who, Game.Ch2.keeper_lines(), "keeper")
	hud.dialogue.finished.connect(_after_keeper, CONNECT_ONE_SHOT)

# ---------------------------------------------------------------- Sorush's offer (v0.21): Boss Rush, New Game+
var _keeper_opts: Array = []
var _keeper_who := ""

func _keeper_menu(who: String) -> void:
	_keeper_who = who
	var R = Game.Rush
	_keeper_opts = [
		{"id": "rush", "label": Game.t("Relive the battles — the Boss Rush", "نبردها را دوباره از سر بگذران — نبردهای به‌یادمانده"), "ok": true},
		{"id": "ng", "label": Game.t("Begin the tale anew — New Game+ %d" % (Game.ng() + 1), "داستان را از نو آغاز کن — بازیِ نو+ %s" % Game.num(Game.ng() + 1)), "ok": true},
		{"id": "leave", "label": Game.t("Leave", "برگشتن"), "ok": true},
	]
	var head := ""
	if Game.Ch2.step() in ["shards", "descend"]:
		head = str(Game.Ch2.keeper_lines()[0]) + "  "          # (New Game+) where the chapter stands
	head += Game.t("Every battle you won is kept here. I can open them again, one after another: seven bosses, stronger than you met them, four of my potions, no way out but through.",
		"هر نبردی که بردی این‌جا نگه داشته شده. می‌توانم دوباره بازشان کنم، یکی پس از دیگری: هفت سرکرده، قوی‌تر از آن‌چه دیدی، چهار معجون از من، و هیچ راهی جز گذشتن.")
	if R.best() > 0.0:
		head += "  " + Game.t("Best time: ", "بهترین زمان: ") + R.clock(R.best())
	if hud.dialogue.chosen.is_connected(_keeper_pick):
		hud.dialogue.chosen.disconnect(_keeper_pick)
	hud.dialogue.choose(who, head, _keeper_opts, "keeper")
	hud.dialogue.chosen.connect(_keeper_pick, CONNECT_ONE_SHOT)
	hud.refresh()

func _keeper_pick(i: int) -> void:
	match str(_keeper_opts[i]["id"]):
		"rush":
			start_rush()
		"ng":
			_ng_confirm()

func start_rush() -> void:
	if rush_run:
		return
	rush_run = Game.Rush.new()
	rush_run.main = self
	rush_run.finished.connect(func(_won): rush_run = null)
	add_child(rush_run)
	rush_run.begin()

var _ng_opts: Array = []

func _ng_confirm() -> void:
	_ng_opts = [
		{"id": "go", "label": Game.t("Begin New Game+", "بازیِ نو+ را آغاز کن"), "ok": true},
		{"id": "no", "label": Game.t("Not yet", "هنوز نه"), "ok": true},
	]
	var head := Game.t("New Game+: you keep your level, gear, gold, spells, talents, sigils and forge. The quests, the bosses and the story begin again — every foe stronger, and worth more. This cannot be undone.",
		"بازیِ نو+: سطح، تجهیزات، سکه، جادوها، استعدادها، نشان‌ها و آهنگری‌ات می‌مانند. مأموریت‌ها، سرکرده‌ها و داستان از نو آغاز می‌شوند — هر دشمنی قوی‌تر و پُرپاداش‌تر. این کار برگشت ندارد.")
	if hud.dialogue.chosen.is_connected(_ng_pick):
		hud.dialogue.chosen.disconnect(_ng_pick)
	hud.dialogue.choose(_keeper_who, head, _ng_opts, "keeper")
	hud.dialogue.chosen.connect(_ng_pick, CONNECT_ONE_SHOT)

func _ng_pick(i: int) -> void:
	if str(_ng_opts[i]["id"]) == "go":
		start_ng()

## (v0.21) New Game+: the story starts over in Zabol, the hero as he is
func start_ng() -> void:
	hud.pad.release_all()
	await hud.fade_out()
	Game.start_ng()
	player.revive()
	player.refresh_look()
	goto_map("village", Vector2(420, 490))
	hud.fade_in()
	hud.banner(Game.t("New Game+ %d" % Game.ng(), "بازیِ نو+ %s" % Game.num(Game.ng())), Game.t("The tale begins again — and the world remembers you.", "داستان دوباره آغاز می‌شود — و جهان تو را به یاد دارد."), UI.GOLD_HI, 3.0)
	Sfx.play("quest")
	hud.refresh()

func _after_keeper() -> void:
	var was: String = Game.Ch2.step()
	var out: Array = Game.Ch2.keeper_done()
	for i in out.size():
		if str(out[i]) == "":
			continue
		hud.toast(str(out[i]), "trophy" if was == "forge" else "gem", UI.GOLD_HI)
	if not out.is_empty():
		Sfx.play("quest", -2.0)
		if was == "forge":
			Sfx.play("latch")
			Sfx.play("found")
	hud.refresh()

func _talk_hesk(who: String) -> void:
	hud.dialogue.open(who, Game.Ch2.hesk_lines(), "hesk")
	hud.dialogue.finished.connect(_after_hesk, CONNECT_ONE_SHOT)

func _after_hesk() -> void:
	var first: bool = not bool(Game.Ch2.hesk()["met"])
	for line in Game.Ch2.hesk_done():
		hud.toast(str(line), "coins", UI.GOLD_HI)
		Sfx.play("coin")
		Sfx.play("quest", -4.0)
	if first:
		hud.toast(Game.Ch2.line("q_wolves") + Game.sep() + Game.Ch2.line("q_pages"), "scroll-text", UI.GOLD_HI)
		Sfx.play("quest", -2.0)
	hud.refresh()
	hud.shop.open("hesk")

## (v0.23) Qaren, Kaveh's son, keeps watch at the camp on the Slopes of Damavand
func _talk_qaren(who: String) -> void:
	hud.dialogue.open(who, Game.Ch3.qaren_lines(), "qaren")
	hud.dialogue.finished.connect(_after_qaren, CONNECT_ONE_SHOT)

func _after_qaren() -> void:
	var first: bool = not bool(Game.Ch3.qaren()["met"])
	for line in Game.Ch3.qaren_done():
		hud.toast(str(line), "gem", UI.GOLD_HI)
		Sfx.play("coin")
		Sfx.play("quest", -4.0)
	if first:
		hud.toast(Game.Ch3.fmt("t_qtask", [int(Game.Ch3.qaren()["kills"]), Game.Ch3.GUARDS_NEED]), "scroll-text", UI.GOLD_HI)
		Sfx.play("quest", -2.0)
	hud.refresh()

## (v0.23) Zahhak overcome: Sorush stays the hero's hand — he is bound to the mountain, as Fereydun bound him
func _zahhak_bound() -> void:
	await get_tree().create_timer(2.9).timeout
	if hud == null:
		return
	hud.banner(Game.Ch3.line("bound"), Game.Ch3.line("title"), Color8(170, 140, 230), 2.4)
	Sfx.play("clank")
	Sfx.play("phase", -4.0)
	if world:
		world.shake(8.0)
	await get_tree().create_timer(2.5).timeout
	if hud == null or world == null or world.key != "zahhakcave" or player == null or player.dead or hud.dialogue.visible:
		return
	hud.dialogue.open(Game.t("Sorush", "سروش"), [Game.Ch3.line("s1"), Game.Ch3.line("s2"), Game.Ch3.line("s3")], "keeper")
	hud.refresh()

func _brann_frost() -> void:
	var msg: String = Game.Ch2.brann_done()
	if msg != "":
		hud.toast(msg, "sword", UI.GOLD_HI)
		Sfx.play("clank")
		Sfx.play("equip")
		Sfx.play("levelup", -2.0)
		player.refresh_look()
	hud.refresh()

## the end of the chapter: a card with what the hero did, then back to the world
func _chapter_end(ch := 2) -> void:
	await get_tree().create_timer(0.4).timeout
	if hud == null:
		return
	Sfx.play("victory")
	hud.ending.open(ch)

func _on_boss_down(text: String) -> void:
	hud.refresh()
	await get_tree().create_timer(3.2).timeout      # after the VANQUISHED banner has faded
	if hud == null:
		return
	hud.toast(text, "trophy", UI.GOLD_HI)
	Sfx.play("quest", -2.0)
	hud.refresh()


# ---------------------------------------------------------------- Thornwood Toll (v0.9): Sindokht's strongbox
const TOLL_REWARD := {"ghost": 150, "snatch": 100, "fight": 100, "pay": 300, "fame": 100, "oath": 100, "hand": 100, "dragon": 120, "ledger": 150}
const TOLL_REACT := {"ghost": "r_ghost", "snatch": "r_snatch", "fight": "r_fight", "pay": "r_pay", "fame": "r_fame", "oath": "r_oath", "hand": "r_hand", "dragon": "r_dragon", "ledger": "r_ledger"}
const TOLL_LABEL := {"ghost": "o_ghost", "snatch": "o_snatch", "fight": "o_fight", "pay": "o_pay", "fame": "o_fame", "oath": "o_oath", "hand": "o_hand", "dragon": "o_dragon", "ledger": "o_ledger"}

func _talk_thalia(who: String) -> void:
	var T = Game.Toll
	match Game.toll_st():
		"none":
			hud.dialogue.open(who, [T.line("t_intro_a"), T.line("t_intro_b"), T.line("t_after")], "merchant")
			hud.dialogue.finished.connect(_thalia_gives_quest, CONNECT_ONE_SHOT)
		"box":
			var how := str(Game.toll().get("how", "snatch"))
			var ls := [T.line("t_box"), T.line(TOLL_REACT.get(how, "r_snatch")), T.line("t_reward")]
			ls.append(T.line("r_friend_ghost") if how == "ghost" else T.line("r_friend"))
			hud.dialogue.open(who, ls, "merchant")
			hud.dialogue.finished.connect(_thalia_pays, CONNECT_ONE_SHOT)
		_:
			hud.shop.open("merchant")

func _thalia_gives_quest() -> void:
	Game.toll_set("active")
	hud.toast(Game.Toll.line("new_quest"), "scroll-text", UI.GOLD_HI)
	Sfx.play("quest", -2.0)
	hud.refresh()
	hud.shop.open("merchant")      # "a word before you browse"

func _thalia_pays() -> void:
	var how := str(Game.toll().get("how", "snatch"))
	var gold: int = int(TOLL_REWARD.get(how, 100))
	Game.state["gold"] = int(Game.state.get("gold", 0)) + gold
	Game.toll_set("done")
	hud.toast("+%s %s" % [Game.num(gold), Game.t("Gold Reward!", "سکه پاداش!")], "coins", UI.GOLD_HI)
	Sfx.play("coin")
	Sfx.play("quest", -4.0)
	await get_tree().create_timer(1.4).timeout
	if hud:
		hud.toast(Game.Toll.line(TOLL_LABEL.get(how, "o_snatch")), "feather", UI.CREAM)
		await get_tree().create_timer(1.4).timeout
	if hud:
		hud.toast(Game.Toll.line("t_discount"), "badge-percent", UI.GOLD_HI)
		hud.refresh()

func _take_strongbox() -> void:
	if Game.toll_st() != "active":
		return
	var how := str(Game.toll().get("how", ""))
	if how == "":
		if world.camp_noticed:
			how = "snatch"
			world.raise_alarm()
			world.float_text(player.global_position + Vector2(0, -60), Game.Toll.line("thief"), Color(1, 0.55, 0.45))
		else:
			how = "ghost"
	Game.toll_set("box", how)
	world.remove_pickup("strongbox")
	hud.toast(Game.Toll.line("got_box"), "package", UI.GOLD_HI)
	Sfx.play("coin")
	Sfx.play("quest", -4.0)
	hud.refresh()

func _take_ledger() -> void:
	if bool(Game.toll().get("ledger", false)):
		return
	Game.toll()["ledger"] = true
	Game.save_game()
	world.remove_pickup("ledger")
	var T = Game.Toll
	hud.dialogue.open(T.line("ledger_title"), [T.line("ledger_a"), T.line("ledger_b"), T.line("ledger_c")], "")
	hud.toast(T.line("found_ledger"), "book-open", UI.GOLD_HI)
	Sfx.play("quest", -4.0)
	hud.refresh()

## the camp calls a parley: Ashkbus's offer, and every way out that the hero has earned
var _parley_opts: Array = []

func _on_parley() -> void:
	var T = Game.Toll
	var who := Game.boss_name("captain")
	hud.dialogue.open(who, [T.line("halt"), T.line("easy"), T.line("smell")], "")
	hud.dialogue.finished.connect(_parley_choices, CONNECT_ONE_SHOT)

func parley_options() -> Array:
	var T = Game.Toll
	var gold := int(Game.state.get("gold", 0))
	var opts := []
	opts.append({"id": "pay", "label": Game.t("Pay the toll (200 gold)", "باج را بپرداز (۲۰۰ سکه)"), "ok": gold >= 200, "note": T.line("no_coin")})
	opts.append({"id": "fame", "label": Game.t("Tell him about the Crypt", "از سرداب برایش بگو"), "ok": Game.is_defeated("boss"), "note": Game.t("Arzhang's echo still stands.", "ارژنگ را هنوز نکشته‌ای.")})
	match Game.cls:
		"paladin":
			opts.append({"id": "oath", "label": "[%s] " % Game.hero_role() + Game.t("Offer mercy, sworn on the Ember", "رحم پیشنهاد کن، با سوگند به اخگر"), "ok": true})
		"rogue":
			opts.append({"id": "hand", "label": "[%s] " % Game.hero_role() + Game.t("Show the Ashen Hand's mark", "نشان دست خاکستر را نشان بده"), "ok": true})
		"mage":
			opts.append({"id": "dragon", "label": "[%s] " % Game.hero_role() + Game.t("Conjure a dragon of flame (6 mana)", "اژدهایی از شعله احضار کن (۶ مانا)"), "ok": Game.mp >= 6.0, "note": T.line("no_mana")})
	opts.append({"id": "ledger", "label": T.line("lbl_ledger"), "ok": bool(Game.toll().get("ledger", false)), "note": T.line("no_ledger")})
	opts.append({"id": "fight", "label": T.line("lbl_fight"), "ok": true})
	return opts

func _parley_choices() -> void:
	_parley_opts = parley_options()
	if hud.dialogue.chosen.is_connected(_parley_pick):
		hud.dialogue.chosen.disconnect(_parley_pick)
	hud.dialogue.choose(Game.boss_name("captain"), Game.Toll.line("offer"), _parley_opts)
	hud.dialogue.chosen.connect(_parley_pick, CONNECT_ONE_SHOT)

func _parley_pick(i: int) -> void:
	_parley_resolve(str(_parley_opts[i]["id"]))

## apply the answer: payments, Ashkbus's reply, how the quest will be remembered, and what the camp does next
func _parley_resolve(id: String) -> void:
	var T = Game.Toll
	var who := Game.boss_name("captain")
	var lines := []
	var gain := 0
	match id:
		"pay":
			Game.state["gold"] = int(Game.state.get("gold", 0)) - 200
			lines = [T.line("deal_done")]
		"fame":
			lines = [T.line("crypt1"), T.line("crypt2")]
		"oath":
			lines = [T.line("mercy1"), T.line("mercy2")]
			gain = 50
			Game.state["potions"] = int(Game.state.get("potions", 0)) + 2
			Game.toll()["charm"] = true
		"hand":
			lines = [T.line("hand1"), T.line("hand2")]
			gain = 100
		"dragon":
			Game.mp = max(0.0, Game.mp - 6.0)
			lines = [T.line("dragon1")]
		"ledger":
			lines = [T.line("ledger1"), T.line("ledger2")]
			gain = 150
		"fight":
			lines = [T.line("fight1")]
	if gain > 0:
		Game.state["gold"] = int(Game.state.get("gold", 0)) + gain
	if id != "fight":
		Game.toll()["how"] = id
	else:
		# Choosing to fight resolves the parley permanently, even before Ashkbus falls.
		Game.toll()["fight_started"] = true
	Game.save_game()
	world.parley_done(id)
	hud.dialogue.open(who, lines, "")
	hud.refresh()

func _on_item_found(text: String, col: Color) -> void:
	if hud:
		hud.toast(text, "gem", col)
		Sfx.play("coin", -4.0)


## Rudabeh the Alchemist (v0.11): the first visit is a few words, then the cauldron
func _talk_miri(who: String) -> void:
	if bool(Game.state.get("miri_met", false)):
		hud.craft.open()
		return
	var ls := []
	for pair in PLACEHOLDER["alchemist"]:
		ls.append(Game.t(pair[0], pair[1]))
	hud.dialogue.open(who, ls, "alchemist")
	hud.dialogue.finished.connect(_miri_met, CONNECT_ONE_SHOT)

func _miri_met() -> void:
	Game.state["miri_met"] = true
	Game.save_game()
	hud.craft.open()


## Kavian the Smith (v0.12): armour to buy, or the forge to refine what you carry
var _garen_opts: Array = []

func _talk_garen(who: String) -> void:
	# (v0.23) chapter 3: Kaveh's forge-fire burned black — the story first, then his shop and forge
	if Game.Ch3.has_news("smith"):
		var ls: Array = Game.Ch3.kaveh_lines()
		if not ls.is_empty():
			hud.dialogue.open(who, ls, "smith")
			hud.dialogue.finished.connect(_after_kaveh.bind(who), CONNECT_ONE_SHOT)
			return
	_garen_menu(who)

func _after_kaveh(who: String) -> void:
	var was: String = Game.Ch3.step()
	var out: Array = Game.Ch3.kaveh_done()
	for line in out:
		hud.toast(str(line), "flag" if was == "forge" else "scroll-text", UI.GOLD_HI)
	if not out.is_empty():
		Sfx.play("quest", -2.0)
	if was == "forge" and Game.Ch3.step() == "descend":
		Sfx.play("clank")
		Sfx.play("levelup", -2.0)
		hud.banner(Game.Ch3.line("banner").to_upper() if Game.lang != "fa" else Game.Ch3.line("banner"), Game.Ch3.line("title"), Color8(230, 90, 70), 2.6)
		if world and world.fx and player:
			world.fx.emit("shine", player.global_position, 30, Color8(255, 200, 90), Vector2.UP, 20.0, 220.0, 1.2)
	hud.refresh()

func _garen_menu(who: String) -> void:
	var head := Game.t("Iron tempered in Kaveh's forge does not break.", "آهنی که در کورهٔ کاوه تافته شود، نمی‌شکند.")
	var kl: Array = Game.Ch3.kaveh_lines() if Game.Ch3.step() in ["jewels", "descend"] else []
	Game.Ch3.told = "-"
	if not kl.is_empty():
		head = str(kl[0]) + "  " + head
	_garen_opts = [
		{"id": "shop", "label": Game.t("Buy armour", "خرید زره"), "ok": true},
		{"id": "forge", "label": Game.t("The Forge — refine your gear", "کوره — تقویت تجهیزات"), "ok": true},
		{"id": "leave", "label": Game.t("Leave", "برگشتن"), "ok": true},
	]
	if hud.dialogue.chosen.is_connected(_garen_pick):
		hud.dialogue.chosen.disconnect(_garen_pick)
	hud.dialogue.choose(who, head, _garen_opts, "smith")
	hud.dialogue.chosen.connect(_garen_pick, CONNECT_ONE_SHOT)

func _garen_pick(i: int) -> void:
	match str(_garen_opts[i]["id"]):
		"shop":
			hud.shop.open("smith")
		"forge":
			hud.forge.open()


# ---------------------------------------------------------------- the Bounty Board (v0.15)
var _board_opts: Array = []

func _open_board(who := "") -> void:
	Game.contract_fill()
	_board_opts = []
	var list: Array = Game.contracts()["list"]
	for i in list.size():
		var c: Dictionary = list[i]
		var done := Game.contract_done(c)
		var lbl: String = Game.contract_label(c) + Game.sep(true) + "%s %s" % [Game.num(int(c["gold"])), Game.t("gold", "سکه")] + Game.sep(true) + "%s %s" % [Game.num(int(c["xp"])), Game.t("XP", "تجربه")]
		if Game.lang == "fa":
			lbl = "%s — پاداش: %s سکه و %s تجربه" % [Game.contract_label(c), Game.num(int(c["gold"])), Game.num(int(c["xp"]))]
		if done:
			lbl = Game.t("[Claim] ", "[دریافت] ") + lbl
		_board_opts.append({"id": "c%d" % i, "label": lbl, "ok": done, "note": "%s/%s" % [Game.num(int(c["have"])), Game.num(int(c["need"]))]})
	_board_opts.append({"id": "leave", "label": Game.t("Leave", "برگشتن"), "ok": true})
	if hud.dialogue.chosen.is_connected(_board_pick):
		hud.dialogue.chosen.disconnect(_board_pick)
	var head := Game.t("Three contracts. Finish one, another appears.", "سه قرارداد. یکی را تمام کن، یکی دیگر می‌آید.") + " " + Game.t("Contracts completed: ", "قراردادهای انجام‌شده: ") + Game.num(Game.contracts_done())
	if who != "":
		# (v0.24) Gordafarid keeps the bounties: she fought Sohrab at the White Fortress and slipped his grasp
		head = Game.t("I fought Sohrab at the White Fortress and slipped from his grasp; keeping a list of beasts is nothing. Only, never speak that name before Rostam.", "من پای دژِ سپید با سهراب جنگیدم و از چنگش گریختم؛ نگه داشتنِ فهرستِ چند جانور کاری نیست. فقط آن نام را پیشِ رستم بر زبان نیاور.") + "\n" + head
	hud.dialogue.choose(who if who != "" else Game.t("Bounty Board", "تابلوی قراردادها"), head, _board_opts, "hero:rogue_endgame:npc_gordafarid" if who != "" else "")
	hud.dialogue.chosen.connect(_board_pick, CONNECT_ONE_SHOT)

func _board_pick(i: int) -> void:
	var id := str(_board_opts[i]["id"])
	if id == "leave":
		return
	var idx := int(id.substr(1))
	var c: Dictionary = Game.contracts()["list"][idx]
	var g := int(round(float(c["gold"]) * Game.gold_mul()))
	var x := int(round(float(c["xp"]) * Game.xp_mul()))
	var lvl0 := Game.lvl()
	if Game.contract_claim(idx):
		hud.toast("+%s %s" % [Game.num(g), Game.t("gold", "سکه")] + Game.sep() + "+%s %s" % [Game.num(x), Game.t("XP", "تجربه")], "coins", UI.GOLD_HI)
		Sfx.play("coin")
		if Game.lvl() > lvl0:
			Sfx.play("levelup")
			player.world.level_up.emit(Game.lvl())
		hud.refresh()
	_open_board()


# ---------------------------------------------------------------- the Trial of Embers gate (v0.16)
var _arena_opts: Array = []

## (v0.24) Rostam in his training yard: the training (offered to a new Ember-bearer), or a word for the fight ahead
var _rostam_opts: Array = []
const ROSTAM_SHEET := "hero:warrior_endgame:npc_rostam"

func _talk_rostam(who: String) -> void:
	var T = Game.Tut
	if T.fresh():
		hud.dialogue.open(who, [T.line("r1")], ROSTAM_SHEET)
		hud.dialogue.finished.connect(_rostam_offer.bind(who, T.line("r2")), CONNECT_ONE_SHOT)
	elif T.active():
		_rostam_offer(who, T.line("r_mid"))
	elif T.step() == "skipped":
		# (v0.24, playtest: "no way back to the yard once you said no") his word for the fight ahead, and the yard still open
		T.told()
		_rostam_opts = [{"id": "late", "label": T.line("o_train_late"), "ok": true}, {"id": "bye", "label": T.line("o_bye"), "ok": true}]
		if hud.dialogue.chosen.is_connected(_rostam_pick):
			hud.dialogue.chosen.disconnect(_rostam_pick)
		hud.dialogue.choose(who, T.hint(), _rostam_opts, ROSTAM_SHEET)
		hud.dialogue.chosen.connect(_rostam_pick, CONNECT_ONE_SHOT)
	else:
		T.told()
		hud.dialogue.open(who, [T.hint()], ROSTAM_SHEET)

func _rostam_offer(who: String, head: String) -> void:
	var T = Game.Tut
	var fresh: bool = T.fresh()
	_rostam_opts = [{"id": "train", "label": T.line("o_train") if fresh else T.line("o_go_on"), "ok": true},
		{"id": "skip", "label": T.line("o_skip") if fresh else T.line("o_stop"), "ok": true}]
	if hud.dialogue.chosen.is_connected(_rostam_pick):
		hud.dialogue.chosen.disconnect(_rostam_pick)
	hud.dialogue.choose(who, head, _rostam_opts, ROSTAM_SHEET)
	hud.dialogue.chosen.connect(_rostam_pick, CONNECT_ONE_SHOT)

func _rostam_pick(i: int) -> void:
	var T = Game.Tut
	match str(_rostam_opts[i]["id"]):
		"train":
			if T.fresh():
				T.start()
			hud.toast(T.line("t_" + T.step()) if T.step() != "" else "", "sword", UI.GOLD_HI)
			Sfx.play("quest", -4.0)
		"skip":
			T.skip()
			hud.dialogue.open(T.line("name"), [T.skip_line()], ROSTAM_SHEET)
		"late":
			T.start()
			hud.toast(T.line("t_strike"), "sword", UI.GOLD_HI)
			Sfx.play("quest", -4.0)
	hud.refresh()

func _open_arena(who := "") -> void:
	_arena_opts = [
		{"id": "enter", "label": Game.t("Enter the Arena", "ورود به میدان"), "ok": true},
		{"id": "leave", "label": Game.t("Leave", "برگشتن"), "ok": true},
	]
	if hud.dialogue.chosen.is_connected(_arena_pick):
		hud.dialogue.chosen.disconnect(_arena_pick)
	var best: int = int(Game.trial().get("best", 0))
	var head := Game.t("Waves come one after another; leave by the southern gate whenever you wish.", "موج‌ها پیاپی می‌آیند؛ هر گاه خواستی از دروازهٔ جنوبی بیرون شو.")
	if who != "":
		# (v0.24) Siavash keeps the Trial: he walked through fire once
		head = Game.t("Rostam raised me here in Zabol. I rode through fire once and came out whole — the Trial of Embers is a fire too, ember-bearer.", "رستم مرا در همین زابل پرورد. روزی از میانِ آتش گذشتم و بی‌گزند بیرون آمدم — آزمونِ اخگر هم آتش است، اخگردار.") + "\n" + head
	if best > 0:
		head += "  " + Game.t("Best trial wave: ", "بهترین موج آزمون: ") + Game.num(best)
	hud.dialogue.choose(who if who != "" else Game.t("Trial of Embers", "آزمونِ اخگر"), head, _arena_opts, "hero:paladin_endgame:npc_siavash" if who != "" else "")
	hud.dialogue.chosen.connect(_arena_pick, CONNECT_ONE_SHOT)

func _arena_pick(i: int) -> void:
	if str(_arena_opts[i]["id"]) == "enter":
		_travel.call_deferred("trial", Vector2(550, 690))
