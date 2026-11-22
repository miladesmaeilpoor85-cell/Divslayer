extends Node
## The playtest runner (v0.23): plays the game the way a phone player does — through touches — from a scenario file,
## and writes what the player saw: screenshots, the text on screen, the hero's state, and a log of every step.
## Made for the playtest agents (a pro mobile gamer, a mobile-games critic); tools/playtest/play.sh runs it.
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1600x720 --fixed-fps 60 \
##       -- --test res://tests/playtest.gd --playtest --script scenario.json --out DIR
##
## --playtest keeps the game as a player gets it (Game.testing stays off: elites roll, the real profile is used).
## Give every tester its own XDG_DATA_HOME so saves never mix (play.sh does).
##
## A scenario is a JSON array of steps; every step is an object with "do":
##   {"do":"menu"}                                   the title screen (then tap your way in: tap_text)
##   {"do":"new","class":"warrior"}                  skip the menu: a new hero (warrior | mage | rogue | paladin)
##   {"do":"continue"}                               skip the menu: load this tester's save
##   {"do":"preset","name":"act1","class":"mage"}    a hero at a point of the story: start act1 act2 act3 ch2 ch3 endgame
##   {"do":"lang","v":"fa"}                          fa | en
##   {"do":"tap","x":800,"y":360}                    a finger tap at window pixels (or "fx","fy": 0..1 of the screen)
##   {"do":"tap_text","text":"شروع"}                 tap the visible button (or label) whose text contains this
##   {"do":"drag","from":[x,y],"to":[x,y],"sec":0.4} a swipe (note: lists do not scroll by dragging here — use scroll)
##   {"do":"scroll","fx":0.6,"fy":0.5,"dir":"down","n":4}  scroll the list under that point (the mouse wheel)
##   {"do":"stick","dir":[1,0],"sec":2}              hold the joystick in a direction (screen: x right, y down)
##   {"do":"walk_to","x":600,"y":400,"max_sec":15}  steer with the joystick to a map point (feet)
##   {"do":"walk_to_npc","id":"elder"}               steer to a villager (elder smith merchant alchemist brann keeper hesk)
##   {"do":"walk_to_exit","to":"forest"}             steer into the exit that leads to that map
##   {"do":"button","id":"attack","hold":0.1}        press a touch button: attack dodge block potion skill1 skill2 ult
##                                                   sneak shove talk scroll  (hold "attack" ~0.8 s = heavy blow)
##   {"do":"talk"}                                   the Talk button (if a villager is near), then read every page
##   {"do":"dialog_all"}                             tap through an open dialogue to its end
##   {"do":"fight","sec":40,"shots_every":8}         fight like a decent phone player until the area is clear or sec runs out
##   {"do":"wait","sec":1.5}
##   {"do":"shot","name":"village"}                  a screenshot (shots/NN_name.png) + the text on screen in the log
##   {"do":"burst","name":"combo","n":6,"every":0.2} a contact sheet of n frames (motion, animation, effects)
##   {"do":"state"}                                  the hero, the map, foes near, open panels, the objective (JSON)
##   {"do":"goto","map":"forest","x":500,"y":400}   (test shortcut) move to a map point at once
##   {"do":"invuln","v":true}                        (test shortcut) the hero cannot be hurt
##   {"do":"set","key":"gold","v":500}               (test shortcut) set a value of the saved state
##   {"do":"setting","key":"ui","v":2}               a game setting: ui (0 small, 1 normal, 2 large) cam (zoom 0..2) fx (0..2)
##                                                   shake haptics sound music compass (true/false or 0/1)
##   {"do":"save"}
## The log: DIR/log.txt (also printed). Each step: "STEP n do ... -> result". A failed step is logged, the run goes on.

var main: Node
var out := ""
var steps: Array = []
var n_shot := 0
var stick_down := false
var stick_origin := Vector2.ZERO        # window pixels
var log_f: FileAccess
var t0 := 0
var verbose := false
var current_step := -1
var current_action := ""
var current_step_started_ms := 0
var active_stage := "startup"
var stage_started_ms := 0

const PRESETS := {
	# level, weapon, armour, potions, gold
	"start": [1, 1, 0, 2, 0],
	"act1": [4, 2, 1, 3, 120],
	"act2": [8, 3, 2, 4, 300],
	"act3": [12, 4, 3, 5, 500],
	"ch2": [16, 5, 4, 6, 900],
	"ch3": [18, 6, 5, 7, 1500],
	"endgame": [22, 6, 5, 8, 2500],
}

func _arg(k: String, d: String) -> String:
	var i := Game.args.find(k)
	return Game.args[i + 1] if i >= 0 and i + 1 < Game.args.size() else d

func run(m: Node) -> void:
	main = m
	t0 = Time.get_ticks_msec()
	stage_started_ms = t0
	out = _arg("--out", "user://playtest")
	DirAccess.make_dir_recursive_absolute(out.path_join("shots"))
	log_f = FileAccess.open(out.path_join("log.txt"), FileAccess.WRITE)
	var sp := _arg("--script", "")
	var txt := FileAccess.get_file_as_string(sp)
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_ARRAY:
		_log("SCENARIO_ERROR could not read a JSON array from '%s'" % sp)
		_finish()
		return
	steps = parsed
	var heartbeat := Timer.new()
	heartbeat.wait_time = 20.0
	heartbeat.timeout.connect(_heartbeat)
	add_child(heartbeat)
	heartbeat.start()
	var vs := get_viewport().get_visible_rect().size
	var ws := get_tree().root.size
	_log("PLAYTEST v%s  window %dx%d  layout %dx%d  lang %s  steps %d" % [Game.VERSION, ws.x, ws.y, vs.x, vs.y, Game.lang, steps.size()])
	await frames(10)
	for i in steps.size():
		var s = steps[i]
		if typeof(s) != TYPE_DICTIONARY:
			_log("STEP %d  (not an object) skipped" % i)
			continue
		current_step = i
		current_action = str(s.get("do", ""))
		current_step_started_ms = Time.get_ticks_msec()
		_log("STEP_START %d %s" % [i, current_action])
		var res = await _step(s)
		var step_elapsed := (Time.get_ticks_msec() - current_step_started_ms) / 1000.0
		_log("STEP %d %.2f s %s -> %s" % [i, step_elapsed, JSON.stringify(s), str(res)])
		current_step = -1
		current_action = ""
	_finish()

func _heartbeat() -> void:
	if current_step >= 0:
		var elapsed := (Time.get_ticks_msec() - current_step_started_ms) / 1000.0
		_log("PLAYTEST_HEARTBEAT step=%d action=%s elapsed=%.1f s" % [current_step, current_action, elapsed])

func _finish() -> void:
	if stage_started_ms > 0:
		var stage_elapsed := (Time.get_ticks_msec() - stage_started_ms) / 1000.0
		_log("STAGE_END %s wall=%.1f s potions_remaining=%d" % [active_stage, stage_elapsed, int(Game.state.get("potions", 0))])
	_log("PLAYTEST_DONE  %.1f s wall" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if log_f:
		log_f.flush()
	get_tree().quit()

func _log(s: String) -> void:
	print(s)
	if log_f:
		log_f.store_line(s)
		log_f.flush()

# ---------------------------------------------------------------- time
func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func wait(sec: float) -> void:
	await frames(maxi(1, int(round(sec * 60.0))))

# ---------------------------------------------------------------- touches (window pixels)
func _win(p_canvas: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * p_canvas

func _canvas(p_win: Vector2) -> Vector2:
	return get_tree().root.get_final_transform().affine_inverse() * p_win

func touch(idx: int, p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = p
	e.pressed = down
	Input.parse_input_event(e)

func drag_ev(idx: int, p: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = p
	e.relative = rel
	Input.parse_input_event(e)

func tap(p: Vector2, idx := 0) -> void:
	touch(idx, p, true)
	await frames(4)
	touch(idx, p, false)
	await frames(4)

## the joystick: a thumb held on the left half, pushed in a direction (dir = Vector2.ZERO lets go)
func stick(dir: Vector2) -> void:
	var pad = main.hud.pad if main.hud else null
	if pad == null:
		return
	if dir == Vector2.ZERO:
		if stick_down:
			touch(0, stick_origin, false)
			stick_down = false
			await frames(1)
		return
	if not stick_down:
		stick_origin = _win(pad.get_global_transform_with_canvas() * Vector2(110, pad.size.y - 100))
		touch(0, stick_origin, true)
		stick_down = true
		await frames(1)
	var k: float = get_tree().root.get_final_transform().get_scale().x
	var ps: float = pad.get_global_transform_with_canvas().get_scale().x
	var to: Vector2 = stick_origin + dir.normalized() * 48.0 * k * ps
	drag_ev(0, to, to - stick_origin)
	await frames(1)

func button_pos(id: String) -> Vector2:
	var pad = main.hud.pad
	var bs: Dictionary = pad.buttons()
	if not bs.has(id):
		return Vector2(-1, -1)
	return _win(pad.get_global_transform_with_canvas() * bs[id]["pos"])

func press(id: String, hold := 0.08) -> String:
	var p := button_pos(id)
	if p.x < 0:
		return "no '%s' button on screen now" % id
	touch(3, p, true)
	await wait(hold)
	touch(3, p, false)
	await frames(2)
	return "ok"

# ---------------------------------------------------------------- what is on the screen
func _alpha(ci: CanvasItem) -> float:
	var a := ci.self_modulate.a
	var n: Node = ci
	while n and n is CanvasItem:
		a *= (n as CanvasItem).modulate.a
		n = n.get_parent()
	return a

func _texts() -> Array:
	var outl := []
	var vr := get_viewport().get_visible_rect()
	for n in _all(get_tree().root):
		if not (n is Label or n is Button or n is RichTextLabel or n is LineEdit):
			continue
		var c := n as Control
		if not c.is_visible_in_tree() or _alpha(c) < 0.25:
			continue
		var tx := ""
		if n is RichTextLabel:
			tx = (n as RichTextLabel).get_parsed_text()
		else:
			tx = str(n.get("text"))
		tx = tx.strip_edges().replace("\n", " / ")
		if tx == "":
			continue
		var r := Rect2(c.get_global_transform_with_canvas() * Vector2.ZERO, c.size * c.get_global_transform_with_canvas().get_scale())
		if not vr.intersects(r):
			continue
		var kind := "button" if n is Button else "text"
		outl.append({"t": tx, "k": kind, "at": [int(_win(r.get_center()).x), int(_win(r.get_center()).y)]})
	return outl

func _all(n: Node) -> Array:
	var a := [n]
	for c in n.get_children():
		a.append_array(_all(c))
	return a

func find_text(s: String, buttons_first := true) -> Control:
	var best: Control = null
	for n in _all(get_tree().root):
		if not (n is Button or n is Label or n is RichTextLabel):
			continue
		var c := n as Control
		if not c.is_visible_in_tree() or _alpha(c) < 0.25:
			continue
		var tx := (n as RichTextLabel).get_parsed_text() if n is RichTextLabel else str(n.get("text"))
		if tx.find(s) < 0 and tx.to_lower().find(s.to_lower()) < 0:
			continue
		if n is Button:
			return c
		if best == null:
			best = c
	return best if not buttons_first or best != null else null

func shot(name: String) -> String:
	await RenderingServer.frame_post_draw
	n_shot += 1
	var fn := "%02d_%s.png" % [n_shot, name.validate_filename()]
	get_viewport().get_texture().get_image().save_png(out.path_join("shots").path_join(fn))
	var tl := []
	for t in _texts():
		tl.append(t["t"] if t["k"] == "text" else "[" + t["t"] + "]")
	_log("SCREEN %s: %s" % [fn, " | ".join(tl)])
	if Game.lang == "fa":
		var latin := []
		var rx := RegEx.create_from_string("[A-Za-z]{2,}")
		for t in tl:
			if rx.search(str(t)) and str(t) != "[English]":
				latin.append(str(t))
		if not latin.is_empty():
			_log("LATIN_IN_FA %s: %s" % [fn, " | ".join(latin)])
	return "shots/" + fn

func burst(name: String, n: int, every: float) -> String:
	var imgs := []
	for i in n:
		await RenderingServer.frame_post_draw
		var im := get_viewport().get_texture().get_image()
		im.resize(im.get_width() / 2, im.get_height() / 2, Image.INTERPOLATE_BILINEAR)
		imgs.append(im)
		if i < n - 1:
			await wait(every)
	var cols := 3 if n > 4 else 2
	var rows := int(ceil(float(n) / cols))
	var w: int = imgs[0].get_width()
	var h: int = imgs[0].get_height()
	var sheet := Image.create(w * cols + 4 * (cols - 1), h * rows + 4 * (rows - 1), false, imgs[0].get_format())
	sheet.fill(Color(0, 0, 0))
	for i in imgs.size():
		sheet.blit_rect(imgs[i], Rect2i(0, 0, w, h), Vector2i((i % cols) * (w + 4), (i / cols) * (h + 4)))
	n_shot += 1
	var fn := "%02d_%s_sheet.png" % [n_shot, name.validate_filename()]
	sheet.save_png(out.path_join("shots").path_join(fn))
	return "shots/" + fn + "  (%d frames, %.2f s apart, read left to right, top to bottom)" % [n, every]

func state() -> Dictionary:
	var d := {"map": "", "objective": Game.objective(), "level": Game.lvl(), "xp": "%d/%d" % [int(Game.state.get("xp", 0)), int(Game.state.get("xp_next", 0))],
		"gold": int(Game.state.get("gold", 0)), "potions": int(Game.state.get("potions", 0)), "mana_potions": int(Game.state.get("mana_potions", 0)),
		"hero": "%s (%s)" % [Game.hero_role(), Game.cls], "paused": get_tree().paused}
	var p = main.player
	if p and main.world and is_instance_valid(main.world):
		d["map"] = main.world.key
		d["pos"] = [int(p.global_position.x), int(p.global_position.y)]
		d["hp"] = "%d/%d" % [int(Game.hp), int(Game.max_hp())]
		d["mp"] = "%d/%d" % [int(Game.mp), int(Game.max_mp())]
		d["stamina"] = int(p.stamina)
		d["dead"] = p.dead
		d["statuses"] = p.statuses.keys()
		d["near_npc"] = str(p.near_npc.get_meta("id", "")) if p.near_npc else ""
		var foes := []
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.dead or e.world != main.world:
				continue
			var dist: float = e.center().distance_to(p.global_position + Vector2(0, -17))
			if dist < 700.0:
				foes.append([dist, "%s%s%s hp %d%% at %d px" % [e.type, " (boss)" if e.boss else "", (" elite:" + e.elite) if e.elite != "" else "", int(100.0 * e.hp / max(1.0, e.max_hp)), int(dist)]])
		foes.sort_custom(func(a, b): return a[0] < b[0])
		d["foes_near"] = foes.slice(0, 8).map(func(f): return f[1])
		var ex := []
		for e2 in main.world.data.get("exits", []):
			ex.append("%s at (%d,%d)" % [e2.get("to", "?"), int(e2["x"] + e2["w"] * 0.5), int(e2["y"] + e2["h"] * 0.5)])
		d["exits"] = ex
		d["map_size"] = [int(main.world.size.x), int(main.world.size.y)]
	if main.hud:
		var panels := []
		for k in ["dialogue", "shop", "craft", "forge", "pause", "death", "ending", "intro"]:
			var c = main.hud.get(k)
			if c and c.visible:
				panels.append(k)
		d["open_panels"] = panels
	return d

# ---------------------------------------------------------------- the hero at a point of the story
func preset(name: String, cls: String) -> String:
	if not PRESETS.has(name):
		return "unknown preset (start act1 act2 act3 ch2 ch3 endgame)"
	var s: Array = PRESETS[name]
	Game.new_game(cls)
	Game.state["level"] = s[0]
	var xn := 40
	for i in s[0] - 1:
		xn = int(floor(xn * 1.35))
	Game.state["xp_next"] = xn
	Game.state["weapon"] = s[1]
	Game.state["armor"] = s[2]
	Game.state["potions"] = s[3]
	Game.state["gold"] = s[4]
	var dfd := {}
	match name:
		"act1":
			Game.set_q(1, "active")
		"act2":
			Game.set_q(1, "done")
			Game.set_q(2, "active")
			dfd = {"boss": true}
			Game.brann_set("core")
		"act3":
			for q in [1, 2]:
				Game.set_q(q, "done")
			Game.set_q(3, "active")
			dfd = {"boss": true, "boss2": true}
			Game.brann_set("done")
		"ch2", "endgame", "ch3":
			for q in [1, 2, 3]:
				Game.set_q(q, "done")
			dfd = {"boss": true, "boss2": true, "matriarch": true, "ignarok": true, "anvilward": true, "toadking": true}
			Game.brann_set("done")
			if name == "ch3":
				for b in ["arbiter", "glaciertitan", "ancientwyrm"]:
					dfd[b] = true
				Game.state["c2"] = {"step": "done"}
				Game.state["c3"] = {"step": "jewels"}
			if name == "endgame":
				for b in ["arbiter", "glaciertitan", "ancientwyrm", "captain"]:
					dfd[b] = true
				Game.state["c2"] = {"step": "done", "shards": {"judgement": true, "frost": true, "memory": true}, "heart": "forged",
					"vault": [], "vault_open": true, "hesk": {"met": true, "wolves": 8, "wolves_st": "done", "pages": 3, "pages_st": "done"}}
	Game.state["defeated"] = dfd
	# (v0.24) past the start, Rostam's training counts as done
	Game.state["tut"] = {"step": "" if name == "start" else "done", "hits": 0, "rolls": 0}
	for b in dfd:
		Game.v18()["seen"][b] = true
	Game.hp = Game.max_hp()
	Game.mp = Game.max_mp()
	Game.save_game()
	_enter_world()
	return "%s · %s · level %d · objective: %s" % [name, Game.hero_role(), Game.lvl(), Game.objective()]

func _enter_world() -> void:
	if main.menu:
		main.menu.get_parent().queue_free()
		main.menu = null
	if main.menu_bg:
		main.menu_bg.queue_free()
		main.menu_bg = null
	if main.player == null:
		main.start_world()
	else:
		main.player.revive()
		main.player.refresh_look()
		main.goto_map(str(Game.state.get("map", "village")), Vector2(float(Game.state.get("x", 420)), float(Game.state.get("y", 490))))

# ---------------------------------------------------------------- steering
func _feet() -> Vector2:
	return main.player.global_position

func walk_to(goal: Vector2, max_sec: float, near := 14.0) -> String:
	var t := 0.0
	var last := _feet()
	var stuck := 0.0
	var side := 1.0
	var detour := 0.0
	var map0: String = main.world.key
	while t < max_sec:
		if main.world == null or not is_instance_valid(main.world) or main.world.key != map0:
			await stick(Vector2.ZERO)
			return "changed map -> %s" % (main.world.key if main.world else "?")
		if get_tree().paused:
			await stick(Vector2.ZERO)
			return "stopped: the game paused (%s)" % str(state().get("open_panels", []))
		var d := goal - _feet()
		if d.length() <= near:
			await stick(Vector2.ZERO)
			return "arrived (%.1f s)" % t
		var dir := d.normalized()
		if detour > 0.0:
			dir = dir.rotated(side * 1.2)
			detour -= 0.1
		await stick(dir)
		await wait(0.1)
		t += 0.1
		if _feet().distance_to(last) < 1.5:
			stuck += 0.1
			if stuck > 0.4:
				side = -side if randf() < 0.35 else side
				detour = 0.8
				stuck = 0.0
		else:
			stuck = 0.0
		last = _feet()
	await stick(Vector2.ZERO)
	return "gave up after %.0f s, %d px short" % [max_sec, int(goal.distance_to(_feet()))]

func npc_node(id: String) -> Node:
	for n in get_tree().get_nodes_in_group("npcs"):
		if str(n.get_meta("id", "")) == id:
			return n
	return null

# ---------------------------------------------------------------- dialogue
func dialog_all() -> String:
	var pages := []
	var guard := 0
	var dl = main.hud.dialogue
	while dl.visible and guard < 40:
		var w := 0
		while not dl.typing_done() and w < 240:      # let the line type out, as a reader would
			await frames(5)
			w += 5
		await wait(0.4)
		if dl.choosing():
			return "read %d pages: %s // then a choice: %s" % [pages.size(), " // ".join(pages), " | ".join(_texts().filter(func(x): return x["k"] == "button").map(func(x): return x["t"]))]
		var tx := str(dl.text_l.text)
		if pages.is_empty() or pages[-1] != tx:
			pages.append(tx)
		await tap(_win(dl.panel.get_global_transform_with_canvas() * (dl.panel.size * 0.5)))
		await wait(0.25)
		guard += 1
	return "read %d pages: %s" % [pages.size(), " // ".join(pages)]

# ---------------------------------------------------------------- the fighting bot (a decent phone player, not a perfect one)
func fight(sec: float, shots_every: float) -> String:
	var p = main.player
	var t := 0.0
	var dmg0: float = p.damage_taken
	var kills := 0
	var seen := {}
	var next_shot := shots_every
	var spell_t := 2.0
	var pots := 0
	var dodges := 0
	var hp_low := 1.0
	var swings0: int = p.swings
	var hits0: int = p.hits_landed
	var ended := "time"
	var map0: String = main.world.key
	var last := _feet()
	var stuck := 0.0
	var detour := 0.0
	var side := 1.0
	var quiet := 0.0
	var last_progress := -5.0
	while t < sec:
		if p.dead:
			ended = "the hero fell"
			break
		if get_tree().paused:
			await stick(Vector2.ZERO)
			if main.hud.dialogue.visible:
				await dialog_all()
			elif main.hud.intro.visible:
				await tap(_win(get_viewport().get_visible_rect().get_center()))
			elif main.hud.death.visible:
				ended = "the hero fell"
				break
			else:
				await wait(0.3)
			t += 0.3
			continue
		if main.world.key != map0:
			ended = "walked into an exit -> %s" % main.world.key
			break
		var tgt: Node = null
		var bd := INF
		var any_alive := false
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.world == main.world and not e.dead and not seen.has(e.get_instance_id()):
				seen[e.get_instance_id()] = weakref(e)
			if e.dead or e.world != main.world:
				continue
			var dd: float = e.center().distance_to(p.global_position + Vector2(0, -17))
			if dd > 650.0:
				continue
			any_alive = true
			if not e.targetable():
				continue
			if not _clear_line(_feet(), e.global_position):
				dd += 400.0          # behind a wall: a player picks another foe first
			if dd < bd:
				bd = dd
				tgt = e
		if tgt == null:
			if any_alive and quiet < 4.0:
				quiet += 0.2          # a foe out of reach for a moment (a boss between phases, a burrowed thing): wait for it
				await stick(Vector2.ZERO)
				await wait(0.2)
				t += 0.2
				continue
			ended = "no foe within reach — the area is clear"
			break
		quiet = 0.0
		if t - last_progress >= 5.0:
			var live_foes := 0
			for progress_enemy in get_tree().get_nodes_in_group("enemies"):
				if progress_enemy.world == main.world and not progress_enemy.dead:
					live_foes += 1
			_log("FIGHT_PROGRESS elapsed=%.1f/%0.1f hp=%d/%d potions=%d live_foes=%d" % [t, sec, int(Game.hp), int(Game.max_hp()), int(Game.state.get("potions", 0)), live_foes])
			last_progress = t
		hp_low = min(hp_low, Game.hp / Game.max_hp())
		if Game.hp < 0.35 * Game.max_hp() and int(Game.state.get("potions", 0)) > 0:
			await press("potion")
			pots += 1
		var to: Vector2 = tgt.center() - (p.global_position + Vector2(0, -17))
		if verbose and int(t * 10) % 5 == 0:
			_log("  t %.1f feet %s joy %s tgt %s at %d reach %d" % [t, str(p.global_position.round()), str(p.joy), tgt.type, int(to.length()), int(46.0 + float(tgt.hit_rect().size.x) * 0.5)])
		var reach: float = 46.0 + (float(tgt.hit_rect().size.x) * 0.5 if tgt.has_method("hit_rect") else 12.0)
		# (v0.23) a marked attack about to land where the hero stands: step or roll out of it, as a player reading the
		# ground would (about three times in four — nobody reads every one)
		var away := _danger_away()
		if away != Vector2.ZERO:
			await stick(away.normalized())
			if p.dodge_cd <= 0.0 and p.stamina >= 30.0:
				await press("dodge")
				dodges += 1
			else:
				await wait(0.15)
		elif to.length() > reach:
			var dir := _avoid_exits(to.normalized())
			if detour > 0.0:
				dir = dir.rotated(side * 1.3)
				detour -= 0.1
			await stick(dir)
			if _feet().distance_to(last) < 1.0:
				stuck += 0.1
				if stuck >= 0.4:
					stuck = 0.0
					detour = 0.9
					if randf() < 0.4:
						side = -side
			else:
				stuck = 0.0
			last = _feet()
		else:
			await stick(Vector2.ZERO)
			await stick(to.normalized() * 0.2)
			await stick(Vector2.ZERO)
			await press("attack")
		spell_t -= 0.1
		if spell_t <= 0.0 and to.length() < 260.0:
			spell_t = 3.5
			await press("skill1")
			if p.caster.ult_ready():
				await press("ult")
		await wait(0.1)
		t += 0.1
		next_shot -= 0.1
		if shots_every > 0.0 and next_shot <= 0.0:
			next_shot = shots_every
			await shot("fight_%ds" % int(t))
	await stick(Vector2.ZERO)
	for id in seen:
		var e = seen[id].get_ref()
		if e == null or e.dead:
			kills += 1
	return "%s after %.1f s · foes down %d · damage taken %d · lowest hp %d%% · potions %d · rolls %d · swings %d, hits %d" % [ended, t, kills,
		int(p.damage_taken - dmg0), int(hp_low * 100.0), pots, dodges, p.swings - swings0, p.hits_landed - hits0]

## the way out of the nearest marked attack that is about to land on the hero (Vector2.ZERO: nothing to dodge)

func _danger_away() -> Vector2:
	var bfx = main.world.get("bossfx") if main.world else null
	if bfx == null:
		return Vector2.ZERO
	var pc: Vector2 = main.player.global_position + Vector2(0, -17)
	for t in bfx.tele:
		if not t.has("_pt"):
			t["_pt"] = randf() < 0.75
		if not bool(t["_pt"]) or float(t["t"]) > 0.45 or not bfx.inside(t):
			continue
		match str(t["kind"]):
			"lane":
				var lv: Vector2 = t["b"] - t["pos"]
				var sg := 1.0 if (pc - t["pos"]).cross(lv) >= 0.0 else -1.0
				return Vector2(lv.y * sg, -lv.x * sg)
			_:
				var aw: Vector2 = pc - t["pos"]
				return aw if aw.length() > 1.0 else Vector2.RIGHT
	return Vector2.ZERO

## nothing solid between a and b (the map's walls)
func _clear_line(a: Vector2, b: Vector2) -> bool:
	for r in main.world.wall_rects:
		var rr: Rect2 = r
		if rr.has_point(a) or rr.has_point(b):
			continue
		# sample the segment: walls are big rectangles, 12 px steps never jump one
		var n := int(a.distance_to(b) / 12.0)
		for i in range(1, n):
			if rr.has_point(a.lerp(b, float(i) / n)):
				return false
	return true

## a fighter does not walk out of the fight: steer along an exit's mouth, not into it
func _avoid_exits(dir: Vector2) -> Vector2:
	var f := _feet()
	for e in main.world.data.get("exits", []):
		var r := Rect2(float(e["x"]), float(e["y"]), float(e["w"]), float(e["h"])).grow(36.0)
		if r.has_point(f + dir * 30.0):
			var away: Vector2 = (f - r.get_center()).normalized()
			return (dir + away * 1.6).normalized()
	return dir

# ---------------------------------------------------------------- one step
func _step(s: Dictionary) -> Variant:
	var what := str(s.get("do", ""))
	match what:
		"checkpoint":
			var now := Time.get_ticks_msec()
			var elapsed := (now - stage_started_ms) / 1000.0
			_log("STAGE_END %s wall=%.1f s potions_remaining=%d" % [active_stage, elapsed, int(Game.state.get("potions", 0))])
			active_stage = str(s.get("name", "unnamed stage"))
			stage_started_ms = now
			_log("STAGE_START %s potions=%d" % [active_stage, int(Game.state.get("potions", 0))])
			return "stage checkpoint: " + active_stage
		"menu":
			if main.menu == null:
				main.show_menu()
			await wait(1.0)
			return "title screen"
		"new":
			Game.new_game(str(s.get("class", "warrior")))
			Game.save_game()
			_enter_world()
			await wait(1.0)
			return "new %s" % Game.hero_role()
		"continue":
			if not Game.load_game():
				return "no save"
			_enter_world()
			await wait(1.0)
			return "loaded: %s level %d on %s" % [Game.hero_role(), Game.lvl(), str(Game.state.get("map", ""))]
		"preset":
			var r: String = preset(str(s.get("name", "start")), str(s.get("class", "warrior")))
			await wait(1.0)
			return r
		"lang":
			Game.lang = str(s.get("v", "fa"))
			Game.lang_changed.emit()
			await wait(0.3)
			return "lang " + Game.lang
		"tap":
			var vs: Vector2 = get_tree().root.size
			var p := Vector2(float(s.get("x", vs.x * float(s.get("fx", 0.5)))), float(s.get("y", vs.y * float(s.get("fy", 0.5)))))
			await tap(p)
			await wait(float(s.get("after", 0.4)))
			return "tapped %s" % str(p)
		"tap_text":
			var c := find_text(str(s.get("text", "")))
			if c == null:
				return "NOT FOUND. On screen: " + " | ".join(_texts().map(func(x): return x["t"]))
			var cp := _win(c.get_global_transform_with_canvas() * (c.size * 0.5))
			var ctext := str(c.get("text")).left(40)          # read before the tap: the tap may rebuild the menu and free it
			await tap(cp)
			await wait(float(s.get("after", 0.6)))
			return "tapped '%s' at %s" % [ctext, str(cp)]
		"drag":
			var a: Array = s.get("from", [400, 300])
			var b: Array = s.get("to", [400, 100])
			var pa := Vector2(a[0], a[1])
			var pb := Vector2(b[0], b[1])
			touch(0, pa, true)
			var n := maxi(2, int(float(s.get("sec", 0.4)) * 60.0 / 2.0))
			for i in n:
				var q := pa.lerp(pb, float(i + 1) / n)
				drag_ev(0, q, (pb - pa) / n)
				await frames(2)
			touch(0, pb, false)
			await wait(0.3)
			return "dragged"
		"scroll":
			# a list scrolled by the wheel at a point (this kit's drags cannot scroll lists: Godot scrolls a list by
			# dragging only on a real touch screen)
			var sv: Vector2 = get_tree().root.size
			var at := Vector2(float(s.get("x", sv.x * float(s.get("fx", 0.6)))), float(s.get("y", sv.y * float(s.get("fy", 0.5)))))
			var down := str(s.get("dir", "down")) != "up"
			for i in int(s.get("n", 4)):
				for pressed in [true, false]:
					var mb := InputEventMouseButton.new()
					mb.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
					mb.pressed = pressed
					mb.position = at
					mb.global_position = at
					Input.parse_input_event(mb)
				await frames(2)
			await wait(0.3)
			return "scrolled %s ×%d at %s" % ["down" if down else "up", int(s.get("n", 4)), str(at)]
		"stick":
			var dv: Array = s.get("dir", [1, 0])
			await stick(Vector2(dv[0], dv[1]))
			await wait(float(s.get("sec", 1.0)))
			await stick(Vector2.ZERO)
			return "at %s" % str(_feet().round())
		"walk_to":
			return await walk_to(Vector2(float(s.get("x", 0)), float(s.get("y", 0))), float(s.get("max_sec", 15.0)))
		"walk_to_npc":
			var npc := npc_node(str(s.get("id", "")))
			if npc == null:
				return "no villager '%s' on this map" % str(s.get("id", ""))
			var r2 := await walk_to(npc.global_position + Vector2(0, 26), float(s.get("max_sec", 20.0)), 22.0)
			return r2 + (" · Talk button showing" if main.player.near_npc else " · not close enough to talk")
		"walk_to_exit":
			for e in main.world.data.get("exits", []):
				if str(e.get("to", "")) == str(s.get("to", "")):
					var c2 := Vector2(float(e["x"]) + float(e["w"]) * 0.5, float(e["y"]) + float(e["h"]) * 0.5)
					return await walk_to(c2, float(s.get("max_sec", 40.0)), 6.0)
			return "no exit to '%s' here" % str(s.get("to", ""))
		"button":
			return await press(str(s.get("id", "attack")), float(s.get("hold", 0.08)))
		"talk":
			if main.player.near_npc == null:
				return "nobody near to talk to"
			var who := str(main.player.near_npc.get_meta("id", ""))
			await press("talk")
			await wait(0.5)
			if main.hud.dialogue.visible:
				return "talked to %s: %s" % [who, await dialog_all()]
			return "talked to %s (a menu or shop opened: %s)" % [who, str(state()["open_panels"])]
		"dialog_all":
			return await dialog_all()
		"fight":
			verbose = bool(s.get("verbose", false))
			return await fight(float(s.get("sec", 30.0)), float(s.get("shots_every", 0.0)))
		"wait":
			await wait(float(s.get("sec", 1.0)))
			return "waited"
		"shot":
			return await shot(str(s.get("name", "shot")))
		"burst":
			return await burst(str(s.get("name", "burst")), clampi(int(s.get("n", 6)), 2, 12), float(s.get("every", 0.2)))
		"state":
			return JSON.stringify(state())
		"ending":  # (test shortcut, v0.29) open a chapter's end card: {"do":"ending","ch":3}
			main.hud.ending.open(int(s.get("ch", 3)))
			await wait(1.5)
			return "ending %d" % int(s.get("ch", 3))
		"say":     # (test shortcut, v0.28) open the dialogue box as this speaker: {"do":"say","who":"Zal","sheet":"elder","text":"…"}
			main.hud.dialogue.open(str(s.get("who", "?")), [str(s.get("text", "…"))], str(s.get("sheet", "")))
			var w := 0
			while not main.hud.dialogue.typing_done() and w < 300:
				await frames(5)
				w += 5
			await wait(0.3)
			return "said as %s" % s.get("sheet", "")
		"goto":
			main.goto_map(str(s.get("map", "village")), Vector2(float(s.get("x", 420)), float(s.get("y", 490))))
			await wait(1.0)
			return "on %s" % main.world.key
		"invuln":
			main.player.invuln = 999999.0 if bool(s.get("v", true)) else 0.0
			return "invuln %s" % str(bool(s.get("v", true)))
		"set":
			Game.state[str(s.get("key", ""))] = s.get("v")
			if str(s.get("key", "")) == "talents":
				# (v0.27) talent points spent as a player would; the health they add comes filled
				for k in Game.state["talents"]:
					Game.state["talents"][k] = int(Game.state["talents"][k])
				Game.hp = Game.max_hp()
			Game.stats_changed.emit()
			return "set"
		"setting":
			var v = s.get("v")
			if typeof(v) == TYPE_FLOAT and float(v) == round(float(v)):
				v = int(v)
			Game.set_setting(str(s.get("key", "")), v)
			await wait(0.3)
			return "setting %s = %s" % [str(s.get("key", "")), str(s.get("v"))]
		"save":
			Game.save_game()
			return "saved"
	return "unknown step '%s'" % what
