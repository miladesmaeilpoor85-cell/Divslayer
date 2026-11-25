extends Node

const PlayerAgent = preload("res://tests/player_agent.gd")
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
var player_agent: RefCounted
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
var assertion_failures: Array[String] = []
var fight_evidence: Dictionary = {}
var last_danger_eta := 1.0
var last_danger_kind := ""

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
	player_agent = PlayerAgent.new()
	player_agent.attach(self)
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
		# Stop at the first failed checkpoint or required map transition. Continuing
		# would execute later stages on the wrong map and waste the CI time budget.
		if not assertion_failures.is_empty():
			_log("PLAYTEST_STOPPED_EARLY after a failed required checkpoint")
			break
	_finish()

func _heartbeat() -> void:
	if current_step >= 0:
		var elapsed := (Time.get_ticks_msec() - current_step_started_ms) / 1000.0
		_log("PLAYTEST_HEARTBEAT step=%d action=%s elapsed=%.1f s" % [current_step, current_action, elapsed])

func _finish() -> void:
	if stage_started_ms > 0:
		var stage_elapsed := (Time.get_ticks_msec() - stage_started_ms) / 1000.0
		_log("STAGE_END %s wall=%.1f s potions_remaining=%d" % [active_stage, stage_elapsed, int(Game.state.get("potions", 0))])
	if assertion_failures.is_empty():
		_log("PLAYTEST_ASSERTIONS_PASSED")
	else:
		_log("PLAYTEST_ASSERTIONS_FAILED %d" % assertion_failures.size())
		for failure in assertion_failures:
			_log("PLAYTEST_ASSERTION: " + failure)
	_log("PLAYTEST_DONE  %.1f s wall" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if log_f:
		log_f.flush()
	get_tree().quit(1 if not assertion_failures.is_empty() else 0)

func _assert_state(s: Dictionary) -> String:
	var failures: Array[String] = []
	var snapshot := state()
	var label := str(s.get("label", "checkpoint"))
	if s.has("map") and str(snapshot.get("map", "")) != str(s["map"]):
		failures.append("expected map %s, got %s" % [str(s["map"]), str(snapshot.get("map", ""))])
	var objective := str(snapshot.get("objective", ""))
	if s.has("objective_contains") and objective.find(str(s["objective_contains"])) < 0:
		failures.append("objective did not contain '%s': %s" % [str(s["objective_contains"]), objective])
	if s.has("brann_state") and Game.brann() != str(s["brann_state"]):
		failures.append("expected Jamshid quest state %s, got %s" % [str(s["brann_state"]), Game.brann()])
	if s.has("brann_key") and Game.brann_key() != bool(s["brann_key"]):
		failures.append("expected Kindling Key=%s, got %s" % [str(bool(s["brann_key"])), str(Game.brann_key())])
	if bool(s.get("player_alive", false)) and bool(snapshot.get("dead", false)):
		failures.append("player is dead")
	if bool(s.get("game_unpaused", false)) and get_tree().paused:
		failures.append("game remained paused")
	if s.has("potions_at_least") and int(snapshot.get("potions", 0)) < int(s["potions_at_least"]):
		failures.append("expected at least %d health potions, got %d" % [int(s["potions_at_least"]), int(snapshot.get("potions", 0))])
	if s.has("armor_at_least") and int(Game.state.get("armor", 0)) < int(s["armor_at_least"]):
		failures.append("expected armour tier at least %d, got %d" % [int(s["armor_at_least"]), int(Game.state.get("armor", 0))])
	if s.has("weapon_at_least") and int(Game.state.get("weapon", 1)) < int(s["weapon_at_least"]):
		failures.append("expected weapon tier at least %d, got %d" % [int(s["weapon_at_least"]), int(Game.state.get("weapon", 1))])
	if s.has("tutorial_step") and Game.Tut.step() != str(s["tutorial_step"]):
		failures.append("expected Rostam tutorial step '%s', got '%s'" % [str(s["tutorial_step"]), Game.Tut.step()])
	var required_foe := str(s.get("foe_type", ""))
	if required_foe != "":
		var found := false
		var foe_candidates: Array = get_tree().get_nodes_in_group("enemies")
		for boss_candidate in get_tree().get_nodes_in_group("bosses"):
			if not foe_candidates.has(boss_candidate):
				foe_candidates.append(boss_candidate)
		for e in foe_candidates:
			if e.world != main.world or str(e.type) != required_foe:
				continue
			found = true
			if bool(s.get("foe_must_be_alive", false)) and e.dead:
				failures.append("%s was already defeated before its combat checkpoint" % required_foe)
		if bool(s.get("foe_must_exist", false)) and not found:
			failures.append("required foe %s was not present on %s" % [required_foe, str(snapshot.get("map", ""))])
		if s.has("foe_hp_below"):
			# A missing enemy node is not proof of victory: the scene might never have
			# spawned the boss. Require evidence captured at the start/end of its fight.
			var evidence: Dictionary = fight_evidence.get(required_foe, {})
			if evidence.is_empty() or not bool(evidence.get("present_before", false)):
				failures.append("no verified combat evidence: %s was not present when its fight began" % required_foe)
			elif bool(evidence.get("defeated", false)):
				_log("ASSERTION_INFO %s: %s defeat was confirmed by the boss kill counter" % [label, required_foe])
			elif not bool(evidence.get("present_after", false)):
				failures.append("%s disappeared during combat without a recorded boss defeat" % required_foe)
			else:
				var hp_percent := float(evidence.get("hp_after", 100.0))
				if hp_percent >= float(s["foe_hp_below"]):
					failures.append("%s health did not fall below %.0f%% (currently %.0f%%)" % [required_foe, float(s["foe_hp_below"]), hp_percent])
		if bool(s.get("foe_defeated", false)):
			var defeat_evidence: Dictionary = fight_evidence.get(required_foe, {})
			if required_foe == "" or defeat_evidence.is_empty() or not bool(defeat_evidence.get("present_before", false)):
				failures.append("no verified encounter evidence to confirm %s was defeated" % required_foe)
			elif not bool(defeat_evidence.get("defeated", false)):
				failures.append("%s victory was not confirmed by the real boss kill counter" % required_foe)
			else:
				_log("ASSERTION_INFO %s: %s victory confirmed by the real boss kill counter" % [label, required_foe])
	if s.has("quest_index") and s.has("quest_status"):
		var quest_index := int(s.get("quest_index", 0))
		var actual_quest_status := Game.q(quest_index) if quest_index >= 1 and quest_index <= 3 else "invalid quest index"
		if actual_quest_status != str(s.get("quest_status", "")):
			failures.append("expected q%d status %s, got %s" % [quest_index, str(s.get("quest_status", "")), actual_quest_status])
	if failures.is_empty():
		_log("ASSERTION_PASSED %s" % label)
		return "assertion passed: " + label
	var message := "ASSERTION_FAILED %s: %s" % [label, "; ".join(failures)]
	assertion_failures.append(message)
	_log(message)
	return message

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
		# Shop item names are labels inside full-card Buttons. Resolve the matching
		# label to its clickable Button so a touch taps the item card, not just text.
		var ancestor: Node = n.get_parent()
		while ancestor != null and ancestor != get_tree().root:
			if ancestor is Button and (ancestor as Control).is_visible_in_tree():
				return ancestor as Control
			ancestor = ancestor.get_parent()
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

func walk_to(goal: Vector2, max_sec: float, near := 14.0, intended_exit := "") -> String:
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
		# Keep collision detours from taking the touch bot through an unrelated
		# map exit (notably the hidden shrine entrance in the Whispering Forest).
		dir = _avoid_exits(dir, intended_exit)
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
## Test-only staging helper: a direct goto skips the map route, so unrelated roaming
## foes must not pile into a boss-only combat sample. The boss and its later summons remain.
func _isolate_boss(target_type: String) -> String:
	if target_type == "":
		return "isolate_boss requires target_foe"
	var targets: Array = []
	for candidate in get_tree().get_nodes_in_group("bosses"):
		if candidate.world == main.world and not candidate.dead and str(candidate.type) == target_type:
			targets.append(candidate)
	if targets.size() != 1:
		var failure := "isolate_boss expected exactly one live %s on %s, found %d" % [target_type, str(main.world.key), targets.size()]
		assertion_failures.append(failure)
		_log("ASSERTION_FAILED " + failure)
		return "ASSERTION_FAILED " + failure
	var target: Node = targets[0]
	var foes: Array = get_tree().get_nodes_in_group("enemies")
	for candidate in get_tree().get_nodes_in_group("bosses"):
		if not foes.has(candidate):
			foes.append(candidate)
	var removed := 0
	for foe in foes:
		if not is_instance_valid(foe) or foe.world != main.world or foe.dead or foe == target:
			continue
		foe.queue_free()
		removed += 1
	await frames(2)
	if not is_instance_valid(target) or target.dead:
		var failure := "isolate_boss removed or lost the required %s target" % target_type
		assertion_failures.append(failure)
		_log("ASSERTION_FAILED " + failure)
		return "ASSERTION_FAILED " + failure
	var live_left := 0
	var remaining: Array = get_tree().get_nodes_in_group("enemies")
	for candidate in get_tree().get_nodes_in_group("bosses"):
		if not remaining.has(candidate):
			remaining.append(candidate)
	for foe in remaining:
		if is_instance_valid(foe) and foe.world == main.world and not foe.dead:
			live_left += 1
	_log("BOSS_ISOLATION type=%s removed_unrelated=%d live_at_start=%d" % [target_type, removed, live_left])
	return "isolated %s; removed %d unrelated foes; %d live target(s) remain" % [target_type, removed, live_left]

func _fight_target_is_live(target: Variant) -> bool:
	# A target can be freed by an enemy death animation during any awaited touch.
	# Accept Variant so GDScript does not try to cast the stale object before this guard runs.
	if target == null or not is_instance_valid(target) or not (target is Node):
		return false
	var live_node := target as Node
	if live_node.is_queued_for_deletion():
		return false
	return not bool(live_node.get("dead"))

## Report only real pillar HP loss after a touch attack; selecting a pillar is not enough.
func _record_pillar_attack(target: Variant, hp_before: float) -> bool:
	if target == null or not is_instance_valid(target) or not (target is Node):
		return false
	var pillar := target as Node
	var hp_after := float(pillar.get("hp"))
	if hp_after >= hp_before - 0.01:
		return false
	if bool(pillar.get("dead")) or pillar.is_queued_for_deletion():
		_log("PLAYER_AGENT_PILLAR_DESTROYED hp=%.1f->%.1f" % [hp_before, hp_after])
	else:
		_log("PLAYER_AGENT_PILLAR_DAMAGED hp=%.1f->%.1f" % [hp_before, hp_after])
	return true

func fight(sec: float, shots_every: float, focus_type := "") -> String:
	var p = main.player
	var t := 0.0
	var dmg0: float = p.damage_taken
	var kills := 0
	var seen := {}
	var next_shot := shots_every
	var spell_interval_min := 1.0 if Game.cls == "mage" else 2.2
	var spell_interval_max := 1.5 if Game.cls == "mage" else 3.4
	var spell_t := 1.0 if Game.cls == "mage" else 1.8
	var heavy_t := randf_range(5.0, 8.0)
	var signature_t := randf_range(3.0, 5.0)
	var pots := 0
	var potion_ready_at := 0.0
	var dodges := 0
	var block_actions := 0
	var signature_actions := 0
	var spell_actions := 0
	var ult_actions := 0
	var heavy_actions := 0
	var sneak_actions := 0
	var hp_low := 1.0
	# Mage keeps one health potion in reserve during ordinary encounters for the
	# chapter boss. The boss encounter then uses the normal early-heal threshold.
	var potion_threshold := 0.68 if focus_type == "anvilward" else (0.64 if Game.cls == "mage" and focus_type != "" else (0.42 if Game.cls == "mage" else (0.48 if focus_type != "" else 0.38)))
	var potion_reserve := 1 if Game.cls == "mage" and focus_type == "" else 0
	var swings0: int = p.swings
	var hits0: int = p.hits_landed
	var boss_hp_before := {}
	var focus_present_before := false
	var focus_hp_before := 100.0
	var focus_kills_before := 0
	if focus_type != "":
		fight_evidence.erase(focus_type)
		focus_kills_before = int(Game.v18().get("kills", {}).get(focus_type, 0))
	for boss in get_tree().get_nodes_in_group("bosses"):
		if boss.world == main.world:
			var boss_type := str(boss.type)
			boss_hp_before[boss_type] = 100.0 * float(boss.hp) / maxf(1.0, float(boss.max_hp))
			if boss_type == focus_type and not boss.dead:
				focus_present_before = true
				focus_hp_before = boss_hp_before[boss_type]
	var ended := "time"
	if focus_type != "":
		_log("PLAYER_AGENT_POLICY target=%s telegraph_read=75%% projectile_prediction=enabled reaction=humanized shield_parry=enabled spells=adaptive" % focus_type)
	if Game.cls == "mage":
		_log("PLAYER_AGENT_MAGE_POLICY potion_reserve=%d preferred_range=210 retreat_distance=%d spell_interval=%.1f-%.1fs" % [
			potion_reserve, 180 if focus_type != "" else 150, spell_interval_min, spell_interval_max
		])
	var map0: String = main.world.key
	var last := _feet()
	var stuck := 0.0
	var detour := 0.0
	var side := 1.0
	var quiet := 0.0
	var last_progress := -5.0
	var recovery_attempts := 0
	var last_add_priority_id := 0
	var last_pillar_priority_id := 0
	var last_pillar_approach_id := 0
	var last_mage_threat_id := 0
	var pillar_damage_events := 0
	while t < sec:
		if focus_type != "" and int(Game.v18().get("kills", {}).get(focus_type, 0)) > focus_kills_before:
			ended = "defeated %s through the live combat encounter" % focus_type
			break
		if p.dead:
			if main.hud.death.visible and recovery_attempts < 3:
				recovery_attempts += 1
				var recovery_result: String = await player_agent.recover_from_death()
				if not main.player.dead and main.hud.death.visible == false:
					_log("PLAYER_AGENT_RECOVERED count=%d result=%s" % [recovery_attempts, recovery_result])
					if main.world.key != map0:
						ended = "respawned in %s after defeat; objective route must be followed again" % main.world.key
						break
					p = main.player
					last = _feet()
					t += 1.2
					continue
			ended = "the hero fell"
			break
		if get_tree().paused:
			await stick(Vector2.ZERO)
			if main.hud.dialogue.visible:
				await dialog_all()
			elif main.hud.intro.visible:
				await tap(_win(get_viewport().get_visible_rect().get_center()))
			elif main.hud.death.visible:
				var recovery_result: String = await player_agent.recover_from_death()
				if not main.player.dead and main.world.key == map0:
					p = main.player
					t += 1.2
					continue
				ended = recovery_result
				break
			else:
				await wait(0.3)
			t += 0.3
			continue
		if main.world.key != map0:
			ended = "walked into an exit -> %s" % main.world.key
			var route_failure := "combat unexpectedly changed map from %s to %s; the fight must not consume a portal" % [map0, main.world.key]
			assertion_failures.append(route_failure)
			_log("ASSERTION_FAILED " + route_failure)
			break
		var tgt: Node = null
		var focused_tgt: Node = null
		var urgent_add_tgt: Node = null
		var urgent_add_dist := INF
		var bd := INF
		var any_alive := false
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.world == main.world and not e.dead and not seen.has(e.get_instance_id()):
				seen[e.get_instance_id()] = weakref(e)
			if e.dead or e.world != main.world:
				continue
			var dd: float = e.center().distance_to(p.global_position + Vector2(0, -17))
			# Keep the authored boss target even when it begins farther than the ordinary
			# 650 px encounter scan. Otherwise a Rogue can clear every add and incorrectly
			# conclude the arena is empty while Anvilward is still untouched.
			if focus_type != "" and e.is_in_group("bosses") and str(e.type) == focus_type:
				any_alive = true
				if e.targetable():
					focused_tgt = e
				continue
			if dd > 650.0:
				continue
			any_alive = true
			if not e.targetable():
				continue
			if not _clear_line(_feet(), e.global_position):
				dd += 400.0          # behind a wall: a player picks another foe first
			# Close Anvilward adds and the Ancient Wyrm's wyrmlings can interrupt the
			# boss approach, so clear those immediate threats before returning to the focus.
			if PlayerAgent.should_prioritize_focus_add(focus_type, str(e.type), e.is_in_group("bosses"), dd) and dd < urgent_add_dist:
				urgent_add_tgt = e
				urgent_add_dist = dd
			if dd < bd:
				bd = dd
				tgt = e
		if urgent_add_tgt != null:
			tgt = urgent_add_tgt
			var add_id := urgent_add_tgt.get_instance_id()
			if add_id != last_add_priority_id:
				_log("PLAYER_AGENT_ADD_PRIORITY type=%s distance=%d" % [str(urgent_add_tgt.type), int(urgent_add_dist)])
				if focus_type == "anvilward":
					_log("PLAYER_AGENT_ANVILWARD_ADD_PRIORITY type=%s distance=%d" % [str(urgent_add_tgt.type), int(urgent_add_dist)])
			last_add_priority_id = add_id
		elif focused_tgt != null:
			last_add_priority_id = 0
			var pillar_target: Node = null
			var pillar_distance := INF
			var active_pillars := 0
			# Arzhang's pillars each absorb 15% of incoming damage, up to 45%.
			# Break the nearest pillars, but leave one standing: its small shield
			# prevents another full wave from being summoned after the 17 s cooldown.
			# A real player can then trade that 15% damage reduction for uninterrupted
			# pressure on the boss instead of chasing a repeating set around the arena.
			if focus_type == "boss" and int(focused_tgt.get("ph")) >= 2:
				for pillar in get_tree().get_nodes_in_group("arena"):
					if not _fight_target_is_live(pillar) or pillar.world != main.world or str(pillar.type) != "gravepillar":
						continue
					active_pillars += 1
					var pillar_dist: float = pillar.center().distance_to(p.global_position + Vector2(0, -17))
					if pillar_dist < pillar_distance:
						pillar_distance = pillar_dist
						pillar_target = pillar
			if pillar_target != null and PlayerAgent.should_prioritize_grave_pillars(active_pillars):
				tgt = pillar_target
				var pillar_id := pillar_target.get_instance_id()
				if pillar_id != last_pillar_priority_id:
					_log("PLAYER_AGENT_PILLAR_PRIORITY type=gravepillar active=%d distance=%d hp=%d/%d" % [
						active_pillars, int(pillar_distance), int(pillar_target.hp), int(pillar_target.max_hp)
					])
				last_pillar_priority_id = pillar_id
			else:
				if focus_type == "boss" and active_pillars == 1 and last_pillar_priority_id != 0:
					_log("PLAYER_AGENT_PILLAR_POLICY remaining=1 action=engage_boss shield_reduction=15%")
				tgt = focused_tgt
				last_pillar_priority_id = 0
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
			_log("FIGHT_PROGRESS elapsed=%.1f/%.1f hp=%d/%d potions=%d live_foes=%d" % [t, sec, int(Game.hp), int(Game.max_hp()), int(Game.state.get("potions", 0)), live_foes])
			last_progress = t
		hp_low = min(hp_low, Game.hp / Game.max_hp())
		var potion_stock_before := int(Game.state.get("potions", 0)) + int(Game.state.get("greater", 0))
		if PlayerAgent.should_use_health_potion(Game.hp, Game.max_hp(), potion_stock_before, potion_reserve, t, potion_ready_at, potion_threshold):
			var potion_hp_before := float(Game.hp)
			await press("potion")
			await wait(0.08)
			var potion_stock_after := int(Game.state.get("potions", 0)) + int(Game.state.get("greater", 0))
			var potion_consumed := maxi(0, potion_stock_before - potion_stock_after)
			potion_ready_at = PlayerAgent.next_health_potion_time(t) if potion_consumed > 0 else PlayerAgent.next_health_potion_time(t, 0.5)
			pots += potion_consumed
			if potion_consumed > 0:
				_log("PLAYER_AGENT_POTION_USED class=%s hp=%.1f->%.1f stock=%d->%d next_ready=%.1f" % [Game.cls, potion_hp_before, float(Game.hp), potion_stock_before, potion_stock_after, potion_ready_at])
			else:
				_log("PLAYER_AGENT_POTION_NOT_CONSUMED class=%s hp=%.1f stock=%d" % [Game.cls, potion_hp_before, potion_stock_before])
		if not _fight_target_is_live(tgt):
			await stick(Vector2.ZERO)
			continue
		var target_center: Vector2 = tgt.center()
		var hero_center: Vector2 = p.global_position + Vector2(0, -17)
		var to: Vector2 = target_center - hero_center
		var target_is_pillar := str(tgt.type) == "gravepillar" and tgt.is_in_group("arena")
		var movement_to := to
		# The player attack's own aim-assist chooses the nearest enemy, not the
		# test driver's preferred target. Stand on the side of a grave pillar
		# opposite Arzhang so the pillar, rather than the overlapping boss hitbox,
		# becomes the closest valid attack target.
		if target_is_pillar and _fight_target_is_live(focused_tgt):
			var flank_direction: Vector2 = target_center - focused_tgt.center()
			if flank_direction.length_squared() < 1.0:
				flank_direction = hero_center - target_center
			if flank_direction.length_squared() < 1.0:
				flank_direction = Vector2.RIGHT
			var flank_clearance := maxf(42.0, maxf(float(tgt.box.x), float(tgt.box.y)) * 0.5 + 24.0)
			var flank_goal := target_center + flank_direction.normalized() * flank_clearance
			movement_to = flank_goal - hero_center
			var approach_id := tgt.get_instance_id()
			if approach_id != last_pillar_approach_id:
				_log("PLAYER_AGENT_PILLAR_APPROACH distance=%d flank_distance=%d side=opposite_boss" % [
					int(to.length()), int(movement_to.length())
				])
			last_pillar_approach_id = approach_id
		else:
			last_pillar_approach_id = 0
		if verbose and int(t * 10) % 5 == 0:
			_log("  t %.1f feet %s joy %s tgt %s at %d reach %d" % [t, str(p.global_position.round()), str(p.joy), tgt.type, int(to.length()), int(46.0 + float(tgt.hit_rect().size.x) * 0.5)])
		if verbose and tgt.is_in_group("bosses") and int(t * 10) % 5 == 0:
			_log("BOSS_TARGET type=%s dist=%d hp=%.1f/%.1f targetable=%s hidden=%s inv=%.2f phase=%d busy=%.2f last_move=%s" % [
				str(tgt.type), int(to.length()), float(tgt.hp), float(tgt.max_hp), tgt.targetable(),
				bool(tgt.get("cloaked")), float(tgt.get("inv")), int(tgt.get("ph")),
				float(tgt.get("busy")), str(tgt.get("last_move"))
			])
		var reach: float = 46.0 + (float(tgt.hit_rect().size.x) * 0.5 if tgt.has_method("hit_rect") else 12.0)
		# Rogues use the actual stealth toggle to approach an unaware ordinary foe before
		# the opening strike; the game itself decides whether the enemy remains unaware.
		if Game.cls == "rogue" and not tgt.is_in_group("bosses") and not bool(tgt.get("alert")) and not p.sneaking and to.length() > reach + 8.0:
			await press("sneak")
			sneak_actions += 1
		# A boss-only diagnostic sample reacts to every readable telegraph; ordinary
		# campaign skirmishes preserve the imperfect 75% response of the original bot.
		var away := _danger_away()
		if away != Vector2.ZERO:
			# A marked lane explicitly teaches a sideways roll; blocking it does not leave the
			# damaging strip. Evade as soon as its 0.45 s warning is visible.
			var lane_warning := last_danger_kind == "lane"
			var parry_chance := 0.72 if Game.cls == "paladin" else (0.62 if Game.cls == "warrior" else 0.44)
			var parry_attempt: bool = not lane_warning and last_danger_eta <= 0.18 and to.length() <= 165.0 and p.guard_broken <= 0.0 and p.stamina >= 12.0 and randf() < parry_chance
			if parry_attempt:
				await stick(Vector2.ZERO)
				var parry_hold := maxf(0.22, last_danger_eta + 0.08)
				await press("block", parry_hold)
				block_actions += 1
			elif not lane_warning and last_danger_kind != "projectile" and to.length() <= 210.0 and p.guard_broken <= 0.0 and p.stamina >= 12.0:
				# If the parry window is already too close, hold the shield through impact
				# instead of tapping it for 0.18 s and releasing before the attack lands.
				await stick(Vector2.ZERO)
				var shield_hold := maxf(0.18, last_danger_eta + 0.08)
				await press("block", shield_hold)
				block_actions += 1
				_log("PLAYER_AGENT_BLOCK kind=%s eta=%.2f hold=%.2f" % [last_danger_kind, last_danger_eta, shield_hold])
			else:
				# Combat evasions must respect the same hard portal boundary as normal movement.
				var escape_dir := _avoid_exits(away.normalized())
				await stick(escape_dir)
				var dodge_window := 0.45 if lane_warning else 0.34
				if p.dodge_cd <= 0.0 and p.stamina >= 30.0 and (last_danger_eta <= dodge_window or Game.hp < Game.max_hp() * 0.55):
					await press("dodge")
					dodges += 1
				else:
					await wait(randf_range(0.12, 0.22))
			# Do not let the normal attack branch below zero the joystick and cancel the
			# escape movement in the very same frame as a boss telegraph.
			await wait(0.1)
			t += 0.1
			continue
		if not _fight_target_is_live(tgt):
			await stick(Vector2.ZERO)
			continue
		var preferred_range := reach
		var mage_retreat_distance := 180.0 if focus_type != "" else 150.0
		if Game.cls == "mage" and not target_is_pillar:
			preferred_range = maxf(reach + 130.0, 210.0)
		if Game.cls == "mage" and to.length() < mage_retreat_distance and away == Vector2.ZERO and not target_is_pillar:
			# A mage keeps more room against ordinary melee threats; when pressure closes,
			# retreat through the real movement control and sometimes roll to create space.
			# The earlier 82 px threshold let several crypt foes overlap the light-armour Mage.
			var retreat := (-to.normalized() + Vector2(randf_range(-0.18, 0.18), randf_range(-0.18, 0.18))).normalized()
			await stick(_avoid_exits(retreat))
			var threat_id := tgt.get_instance_id()
			if threat_id != last_mage_threat_id:
				_log("PLAYER_AGENT_MAGE_EVASION kind=retreat distance=%d hp=%d/%d" % [
					int(to.length()), int(Game.hp), int(Game.max_hp())
				])
				last_mage_threat_id = threat_id
			var should_dodge: bool = p.dodge_cd <= 0.0 and p.stamina >= 30.0 and (
				to.length() <= 95.0 or Game.hp < Game.max_hp() * 0.62
			) and (randf() < 0.72 or Game.hp < Game.max_hp() * 0.40)
			if should_dodge:
				await press("dodge")
				dodges += 1
				_log("PLAYER_AGENT_MAGE_EVASION kind=dodge distance=%d hp=%d/%d stamina=%.0f" % [
					int(to.length()), int(Game.hp), int(Game.max_hp()), p.stamina
				])
			await wait(0.12)
		elif target_is_pillar and movement_to.length() > 10.0:
			var flank_dir := _avoid_exits(movement_to.normalized())
			if detour > 0.0:
				flank_dir = flank_dir.rotated(side * 1.3)
				detour -= 0.1
			await stick(flank_dir)
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
		elif to.length() > preferred_range:
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
		elif Game.cls == "mage" and to.length() > reach and not target_is_pillar:
			# Hold a safe casting distance; do not swing a melee weapon out of range.
			# A grave pillar is different: the player must close in and break it.
			await stick(Vector2.ZERO)
		else:
			await stick(Vector2.ZERO)
			await stick(to.normalized() * 0.2)
			await stick(Vector2.ZERO)
			var pillar_hp_before := float(tgt.hp) if target_is_pillar else -1.0
			await press("attack")
			if target_is_pillar:
				await wait(0.22)
				if _record_pillar_attack(tgt, pillar_hp_before):
					pillar_damage_events += 1
		if not _fight_target_is_live(tgt):
			await stick(Vector2.ZERO)
			continue
		# Use charged heavy blows only after the target commits to an animation, rather than
		# holding attack continuously and ignoring the fight around the hero.
		heavy_t -= 0.1
		var heavy_window := target_is_pillar or (tgt.is_in_group("bosses") and float(tgt.get("busy")) > 0.25)
		if heavy_t <= 0.0 and to.length() <= reach + 12.0 and heavy_window and away == Vector2.ZERO:
			heavy_t = randf_range(5.0, 8.0)
			var pillar_hp_before_heavy := float(tgt.hp) if target_is_pillar else -1.0
			await press("attack", 0.55)
			heavy_actions += 1
			if target_is_pillar:
				await wait(0.32)
				if _record_pillar_attack(tgt, pillar_hp_before_heavy):
					pillar_damage_events += 1
		if not _fight_target_is_live(tgt):
			await stick(Vector2.ZERO)
			continue
		# Class signature moves have separate stamina/cooldown costs and should be woven
		# into melee instead of ignored by the old one-button bot.
		signature_t -= 0.1
		if signature_t <= 0.0 and to.length() <= 235.0 and p.shove_cd <= 0.0 and p.stamina >= 20.0 and away == Vector2.ZERO:
			signature_t = randf_range(4.0, 7.0)
			await press("shove")
			signature_actions += 1
		if not _fight_target_is_live(tgt):
			await stick(Vector2.ZERO)
			continue
		# Choose either of the two currently bound spells using the situation, not a fixed
		# skill-1 spam timer. The mana/cooldown rules remain enforced by the real caster.
		var enemies_close := 0
		for candidate in get_tree().get_nodes_in_group("enemies"):
			if candidate.world == main.world and not candidate.dead and candidate.targetable() and candidate.center().distance_to(p.global_position + Vector2(0, -17)) <= 145.0:
				enemies_close += 1
		spell_t -= 0.1
		if spell_t <= 0.0 and away == Vector2.ZERO:
			spell_t = randf_range(spell_interval_min, spell_interval_max)
			var slots: Array = Game.slots()
			for slot_index in 2:
				var spell_id := str(slots[slot_index])
				if p.caster.block(spell_id) != "":
					continue
				var spell_data: Dictionary = Game.Skills.spell(spell_id)
				var should_cast := false
				match spell_id:
					"mend": should_cast = Game.hp < Game.max_hp() * 0.68
					"roar": should_cast = float(p.caster.roar_t) <= 0.4 and to.length() <= 230.0
					"nova", "quake": should_cast = to.length() <= float(spell_data.get("r", 80.0)) + 45.0 or enemies_close >= 2
					"chain": should_cast = to.length() <= float(spell_data.get("reach", 260.0))
					"drain": should_cast = to.length() <= float(spell_data.get("reach", 170.0)) and Game.hp < Game.max_hp() * 0.82
					"blink": should_cast = to.length() > 190.0 and Game.hp < Game.max_hp() * 0.5
					_: should_cast = to.length() <= float(spell_data.get("range", 420.0)) and _clear_line(_feet(), target_center)
				if should_cast:
					await press("skill%d" % (slot_index + 1))
					spell_actions += 1
					break
		if not _fight_target_is_live(tgt):
			await stick(Vector2.ZERO)
			continue
		# Save ultimates for a real threat or a cluster; the Paladin may also spend it to heal.
		if p.caster.ult_ready() and (tgt.is_in_group("bosses") or enemies_close >= 3 or (Game.cls == "paladin" and Game.hp < Game.max_hp() * 0.72)):
			await press("ult")
			ult_actions += 1
		await wait(0.1)
		t += 0.1
		next_shot -= 0.1
		if shots_every > 0.0 and next_shot <= 0.0:
			next_shot = shots_every
			await shot("fight_%ds" % int(t))
	await stick(Vector2.ZERO)
	# The final combat tick can cross an exit after the loop's last boundary check.
	# Never let the next scenario step silently continue on a different map.
	if main.world == null or not is_instance_valid(main.world) or main.world.key != map0:
		var map_after := str(main.world.key) if main.world != null else "none"
		ended = "combat unexpectedly left %s for %s" % [map0, map_after]
		var route_failure := "combat unexpectedly changed map from %s to %s; the fight must not consume a portal" % [map0, map_after]
		assertion_failures.append(route_failure)
		_log("ASSERTION_FAILED " + route_failure)
	for id in seen:
		var e = seen[id].get_ref()
		if e == null or e.dead:
			kills += 1
	var boss_report: Array[String] = []
	var boss_hp_after := {}
	for boss in get_tree().get_nodes_in_group("bosses"):
		if boss.world == main.world:
			boss_hp_after[str(boss.type)] = 0.0 if boss.dead else 100.0 * float(boss.hp) / maxf(1.0, float(boss.max_hp))
	for boss_type in boss_hp_before:
		var before_percent := float(boss_hp_before[boss_type])
		var after_percent := float(boss_hp_after.get(boss_type, 0.0))
		boss_report.append("%s %.0f%%→%.0f%%" % [str(boss_type), before_percent, after_percent])
	if focus_type != "":
		var focus_present_after := false
		var focus_hp_after := 0.0
		for boss in get_tree().get_nodes_in_group("bosses"):
			if boss.world == main.world and str(boss.type) == focus_type:
				focus_present_after = true
				focus_hp_after = 0.0 if boss.dead else 100.0 * float(boss.hp) / maxf(1.0, float(boss.max_hp))
				break
		var focus_kills_after := int(Game.v18().get("kills", {}).get(focus_type, 0))
		var focus_defeated := focus_kills_after > focus_kills_before
		fight_evidence[focus_type] = {
			"present_before": focus_present_before,
			"hp_before": focus_hp_before,
			"present_after": focus_present_after,
			"hp_after": focus_hp_after,
			"defeated": focus_defeated
		}
		_log("FIGHT_EVIDENCE type=%s present_before=%s hp_before=%.1f present_after=%s hp_after=%.1f defeated=%s" % [
			focus_type, focus_present_before, focus_hp_before, focus_present_after, focus_hp_after, focus_defeated
		])
	var arena_report: Array[String] = []
	for arena_obj in get_tree().get_nodes_in_group("arena"):
		if arena_obj.world == main.world and not arena_obj.dead and str(arena_obj.type) == "gravepillar":
			arena_report.append("gravepillar %d%%" % int(100.0 * float(arena_obj.hp) / maxf(1.0, float(arena_obj.max_hp))))
	var detail := ""
	if pillar_damage_events > 0:
		detail += " · grave-pillar HP reductions %d" % pillar_damage_events
	if not boss_report.is_empty():
		detail += " · bosses " + ", ".join(boss_report)
	if not arena_report.is_empty():
		detail += " · arena " + ", ".join(arena_report)
	_log("PLAYER_AGENT_ACTIONS class=%s blocks=%d parries_total=%d rolls=%d sneak_uses=%d signatures=%d spells=%d ultimates=%d heavy=%d" % [Game.cls, block_actions, p.parries, dodges, sneak_actions, signature_actions, spell_actions, ult_actions, heavy_actions])
	return "%s after %.1f s · foes down %d · damage taken %d · lowest hp %d%% · potions %d · rolls %d · blocks %d · signatures %d · spells %d · ultimates %d · heavy %d · swings %d, hits %d%s" % [ended, t, kills,
		int(p.damage_taken - dmg0), int(hp_low * 100.0), pots, dodges, block_actions, signature_actions, spell_actions, ult_actions, heavy_actions, p.swings - swings0, p.hits_landed - hits0, detail]

## the way out of the nearest imminent telegraph or projectile (Vector2.ZERO: nothing to dodge)
## Boss-focused playtests retain the same imperfect 75% telegraph recognition as other fights.
func _danger_away() -> Vector2:
	var bfx = main.world.get("bossfx") if main.world else null
	last_danger_eta = 1.0
	last_danger_kind = ""
	if bfx == null:
		return Vector2.ZERO
	var pc: Vector2 = main.player.global_position + Vector2(0, -17)
	for t in bfx.tele:
		if not t.has("_pt"):
			t["_pt"] = randf() < 0.75
		if not bool(t["_pt"]) or float(t["t"]) > 0.45 or not bfx.inside(t):
			continue
		last_danger_eta = float(t["t"])
		last_danger_kind = str(t["kind"])
		match str(t["kind"]):
			"lane":
				var lv: Vector2 = t["b"] - t["pos"]
				var sg := 1.0 if (pc - t["pos"]).cross(lv) >= 0.0 else -1.0
				return Vector2(lv.y * sg, -lv.x * sg)
			_:
				var aw: Vector2 = pc - t["pos"]
				return aw if aw.length() > 1.0 else Vector2.RIGHT

	# Boss bolts are live projectiles, not telegraphs. Predict their closest approach
	# to the real player hitbox so the agent can step off a collision course in time.
	var body: Rect2 = main.player.body_rect()
	var collision_radius := body.size.length() * 0.5 + 4.0
	var best_eta := INF
	var best_away := Vector2.ZERO
	for shot_data in bfx.shots:
		var velocity: Vector2 = shot_data.get("v", Vector2.ZERO)
		var speed_sq := velocity.length_squared()
		if speed_sq < 1.0:
			continue
		var shot_pos: Vector2 = shot_data.get("pos", pc)
		var rel: Vector2 = pc - shot_pos
		var eta := rel.dot(velocity) / speed_sq
		var available_life := float(shot_data.get("life", 0.0))
		if eta < 0.04 or eta > minf(available_life, 0.65) or eta >= best_eta:
			continue
		var closest: Vector2 = shot_pos + velocity * eta
		var offset: Vector2 = pc - closest
		if offset.length() > collision_radius:
			continue
		var side := 1.0 if velocity.cross(offset) >= 0.0 else -1.0
		best_away = velocity.normalized().orthogonal() * side
		best_eta = eta
	if best_away != Vector2.ZERO:
		last_danger_eta = best_eta
		last_danger_kind = "projectile"
		return best_away
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

## A fighter must not enter a portal while navigating or fighting. Treat each
## non-target exit as a hard boundary and remove movement toward its safe zone.
func _avoid_exits(dir: Vector2, intended_exit := "") -> Vector2:
	var f := _feet()
	for e in main.world.data.get("exits", []):
		# A route may intentionally enter its selected exit. Every other portal is
		# protected during combat and local exploration.
		if intended_exit != "" and str(e.get("to", "")) == intended_exit:
			continue
		var authored := Rect2(float(e["x"]), float(e["y"]), float(e["w"]), float(e["h"]))
		var safe_rect := authored.grow(52.0)
		var inside_buffer := safe_rect.has_point(f)
		var approaching_exit := inside_buffer
		if not approaching_exit:
			for distance in [24.0, 48.0, 72.0, 96.0]:
				if safe_rect.has_point(f + dir * distance):
					approaching_exit = true
					break
		if not approaching_exit:
			continue

		# Find the side of the portal from the player's actual position. Exit
		# rectangles are not guaranteed to be aligned with the edge they occupy:
		# the Sunken Crypt's west-side Shrine of Weight entrance is a horizontal
		# strip, so deriving its escape direction from rectangle width/height is
		# wrong and can leave a component of movement into the portal.
		var outward := Vector2.ZERO
		if inside_buffer:
			var edge_distances := [
				{"distance": absf(f.x - safe_rect.position.x), "direction": Vector2.LEFT},
				{"distance": absf(safe_rect.end.x - f.x), "direction": Vector2.RIGHT},
				{"distance": absf(f.y - safe_rect.position.y), "direction": Vector2.UP},
				{"distance": absf(safe_rect.end.y - f.y), "direction": Vector2.DOWN}
			]
			var nearest_distance := INF
			for edge in edge_distances:
				if float(edge["distance"]) < nearest_distance:
					nearest_distance = float(edge["distance"])
					outward = edge["direction"]
		else:
			var nearest_point := Vector2(
				clampf(f.x, safe_rect.position.x, safe_rect.end.x),
				clampf(f.y, safe_rect.position.y, safe_rect.end.y)
			)
			outward = (f - nearest_point).normalized()
		if outward.length_squared() < 0.5:
			return dir
		if inside_buffer:
			return outward

		# Outside the buffer, slide along its boundary and add a small outward
		# bias. Merely adding a weighted repulsion preserved enough forward input
		# to enter the trigger on long approaches and combat-flank detours.
		var inward_component := minf(dir.dot(outward), 0.0)
		var tangent := dir - outward * inward_component
		return (tangent + outward * 0.35).normalized()
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
		"close_intro":
			if main.hud.intro.visible:
				await tap(_win(get_viewport().get_visible_rect().get_center()))
				await wait(0.6)
				return "dismissed map intro"
			return "no map intro"
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
		"new_real":
			var chosen := str(s.get("class", "warrior"))
			if main.menu == null:
				main.show_menu()
			var new_game_button: Control = player_agent._named_control("NewGame")
			if new_game_button == null or not await player_agent._tap_control(new_game_button):
				var menu_failure := "could not tap the actual NewGame button on the title screen"
				assertion_failures.append(menu_failure)
				return menu_failure
			await wait(0.5)
			if main.menu == null or str(main.menu.view) != "classes":
				var class_page_failure := "NewGame touch did not open class selection"
				assertion_failures.append(class_page_failure)
				return class_page_failure
			var class_card: Control = player_agent._named_control("Card_" + chosen)
			if class_card == null or not await player_agent._tap_control(class_card):
				var card_failure := "class card was not visible or tappable: " + chosen
				assertion_failures.append(card_failure)
				return card_failure
			await wait(0.25)
			var begin_button: Control = player_agent._named_control("Begin")
			if begin_button == null or not await player_agent._tap_control(begin_button):
				var begin_failure := "could not tap the actual Begin button for " + chosen
				assertion_failures.append(begin_failure)
				return begin_failure
			await wait(1.0)
			if Game.cls != chosen or main.world == null:
				var failure := "real new-game flow did not start %s (class=%s world=%s)" % [chosen, Game.cls, str(main.world != null)]
				assertion_failures.append(failure)
				return failure
			return "started %s through actual title, class card and Begin touch controls" % Game.hero_role()
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
		"agent_training":
			return await player_agent.complete_training()
		"agent_spells":
			return await player_agent.bind_adaptive_spells()
		"agent_gear":
			return await player_agent.equip_best_accessory()
		"agent_collect":
			return await player_agent.collect_nearby_pickups(clampi(int(s.get("max_items", 8)), 1, 16))
		"agent_objective":
			var boss_fight_sec := clampf(float(s.get("boss_fight_sec", 75.0)), 30.0, 240.0)
			return await player_agent.follow_objective(
				clampi(int(s.get("max_steps", 1)), 1, 12),
				bool(s.get("stop_after_interaction", false)),
				boss_fight_sec
			)
		"agent_recover":
			return await player_agent.recover_from_death()
		"agent_talents":
			return await player_agent.spend_talents()
		"agent_shop":
			return await player_agent.visit_shop(str(s.get("vendor", "merchant")))
		"agent_loadout":
			return await player_agent.prepare_loadout()
		"tap":
			var vs: Vector2 = get_tree().root.size
			var p := Vector2(float(s.get("x", vs.x * float(s.get("fx", 0.5)))), float(s.get("y", vs.y * float(s.get("fy", 0.5)))))
			await tap(p)
			await wait(float(s.get("after", 0.4)))
			return "tapped %s" % str(p)
		"tap_text":
			var tx := str(s.get("text", ""))
			var tap_result: String = await player_agent.tap_text(tx)
			await wait(float(s.get("after", 0.6)))
			return tap_result
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
			var target_map := str(s.get("to", ""))
			for e in main.world.data.get("exits", []):
				if str(e.get("to", "")) == target_map:
					var c2 := Vector2(float(e["x"]) + float(e["w"]) * 0.5, float(e["y"]) + float(e["h"]) * 0.5)
					# Ignore the destination exit while steering, but continue avoiding
					# every unrelated exit. Confirm the world transition, not just arrival
					# near the exit rectangle.
					var route_result: String = await walk_to(c2, float(s.get("max_sec", 40.0)), 6.0, target_map)
					var actual_map := str(main.world.key) if main.world else ""
					if actual_map != target_map:
						var failure := "walk_to_exit_%s: expected map %s, got %s (%s)" % [target_map, target_map, actual_map, route_result]
						assertion_failures.append(failure)
						_log("ASSERTION_FAILED " + failure)
						return "ASSERTION_FAILED " + failure
					return "entered map %s" % target_map
			return "no exit to '%s' here" % target_map
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
			return await fight(float(s.get("sec", 30.0)), float(s.get("shots_every", 0.0)), str(s.get("target_foe", "")))
		"wait":
			await wait(float(s.get("sec", 1.0)))
			return "waited"
		"shot":
			return await shot(str(s.get("name", "shot")))
		"burst":
			return await burst(str(s.get("name", "burst")), clampi(int(s.get("n", 6)), 2, 12), float(s.get("every", 0.2)))
		"assert_state":
			return _assert_state(s)
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
		"isolate_boss":
			return await _isolate_boss(str(s.get("target_foe", "")))
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
