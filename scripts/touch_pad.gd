extends Control
## Phone controls: a floating joystick on the left half, icon buttons on the right.
## Multi-touch is handled here directly so moving and attacking work at the same time.
## Attack shows its charge (hold for a heavy blow), Roll its cooldown and stamina, Potion its count;
## the two spell buttons (v0.6) show the bound spell, its cooldown and when mana is short; the ultimate
## button fills as you fight and glows when it is ready. A tap goes to the nearest button under the thumb.

const Skills = preload("res://scripts/skills.gd")

var player: Node = null
var joy_id := -1
var joy_origin := Vector2.ZERO
var joy_knob := Vector2.ZERO
var held := {}            # touch index -> button name
var _press_t := {}        # button -> time of the last press (for the squash animation)
var _talk_k := 0.0
const JOY_R := 52.0

const BTN := {
	"attack": {"icon": "sword", "r": 46.0, "col": Color(0.88, 0.33, 0.25), "en": "Attack", "fa": "حمله"},
	"sneak": {"icon": "footprints", "r": 27.0, "col": Color(0.55, 0.75, 0.55), "en": "Sneak", "fa": "پنهان"},
	"shove": {"icon": "zap", "r": 27.0, "col": Color(0.95, 0.65, 0.35), "en": "Shove", "fa": "هل"},
	"block": {"icon": "shield", "r": 31.0, "col": Color(0.6, 0.72, 0.95), "en": "Block", "fa": "سپر"},
	"dodge": {"icon": "wind", "r": 31.0, "col": Color(0.45, 0.8, 0.5), "en": "Roll", "fa": "غلت"},
	"potion": {"icon": "flask-conical", "r": 28.0, "col": Color(0.95, 0.42, 0.55), "en": "Potion", "fa": "معجون"},
	"scroll": {"icon": "scroll-text", "r": 28.0, "col": Color(0.65, 0.75, 1.0), "en": "Scroll", "fa": "طومار"},
	"talk": {"icon": "message-circle", "r": 31.0, "col": Color(0.95, 0.78, 0.35), "en": "Talk", "fa": "صحبت"},
	"skill1": {"icon": "sparkle", "r": 29.0, "col": Color(0.6, 0.65, 1.0), "en": "Spell 1", "fa": "جادو ۱"},
	"skill2": {"icon": "flame", "r": 29.0, "col": Color(0.6, 0.65, 1.0), "en": "Spell 2", "fa": "جادو ۲"},
	"ult": {"icon": "star", "r": 31.0, "col": Color(1, 0.8, 0.4), "en": "Ultimate", "fa": "نهایی"},
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## button centres in this control's own (UI-scaled, safe-area) space
func buttons() -> Dictionary:
	var s := size
	# an arc around the attack button: roll low-left, the spells above it, the ultimate at the top right,
	# the potion further left (out of the way of the fighting thumb)
	var b := {
		"attack": Vector2(s.x - 70, s.y - 72),
		"dodge": Vector2(s.x - 172, s.y - 44),
		"skill1": Vector2(s.x - 174, s.y - 124),
		"skill2": Vector2(s.x - 120, s.y - 172),     # (v0.27, UX: 10 px from the ultimate; now 16)
		"ult": Vector2(s.x - 44, s.y - 178),
		"potion": Vector2(s.x - 258, s.y - 36),
		"block": Vector2(s.x - 250, s.y - 112),
		"shove": Vector2(s.x - 328, s.y - 88),
		# (v0.26, playtest: at a map's east edge the hero stood right behind it) low and to the left of the cluster, under
		# the band the hero is drawn in
		"sneak": Vector2(s.x - 394, s.y - 58),
	}
	if not Game.Tut.pad_open():
		for k in ["skill2", "ult", "shove", "sneak"]:
			b.erase(k)
		var drill: String = Game.Tut.step() if Game.Tut.drilling() else ""
		if drill != "spell":
			b.erase("skill1")
		if drill == "sig":
			b["shove"] = Vector2(s.x - 328, s.y - 88)
	if Game.scroll_sel() != "":
		b["scroll"] = Vector2(s.x - 244, s.y - 252)
	if player and player.near_npc:
		b["talk"] = Vector2(s.x - 240, s.y - 180)
	# Mirror the complete action cluster, including contextual buttons, for left-handed play.
	if bool(Game.settings.get("left_hand", false)):
		for k in b:
			var p: Vector2 = b[k]
			b[k] = Vector2(s.x - p.x, p.y)
	var out := {}
	for k in b:
		var col: Color = BTN[k]["col"]
		var label := Game.t(BTN[k]["en"], BTN[k]["fa"])
		if k == "skill1" or k == "skill2":
			var id := spell_of(k)
			col = Skills.spell_col(id)
			label = Skills.spell_name(id)
		elif k == "shove":
			col = Skills.sig()["col"]        # (v0.26) the calling's own move
			label = Skills.sig_name()
		elif k == "scroll":
			label = Game.scroll_name(Game.scroll_sel()) + " ×" + Game.num(Game.scroll_count(Game.scroll_sel()))
		elif k == "ult":
			col = Skills.ult()["col"]
			label = Skills.ult_name()
		label = _compact_button_label(k, label)
		out[k] = {"pos": b[k], "r": BTN[k]["r"], "label": label, "col": col}
	return out

const COMPACT_SPELL_LABELS := {
	"nova": ["Nova", "اخگر"],
	"bolt": ["Bolt", "تیر"],
	"chain": ["Chain", "زنجیر"],
	"icelance": ["Ice", "یخ"],
	"mend": ["Heal", "درمان"],
	"blink": ["Blink", "جهش"],
	"quake": ["Quake", "سنگ"],
	"drain": ["Drain", "کشش"],
	"roar": ["Roar", "نعره"],
	"firewall": ["Wall", "دیوار"],
}
const COMPACT_ACTION_LABELS := {
	"lasso": ["Lasso", "کمند"],
	"ward": ["Feather", "پر"],
	"arrow": ["Arrow", "تیر"],
	"fire": ["Fire-walk", "گذر از آتش"],
	"whirlwind": ["Spin", "گردباد"],
	"arcane_tempest": ["Tempest", "توفان"],
	"shadow_dance": ["Shadow", "سایه"],
	"holy_smite": ["Smite", "فرّه"],
}

func _compact_button_label(b_name: String, fallback: String) -> String:
	var id := ""
	if b_name == "skill1" or b_name == "skill2":
		id = spell_of(b_name)
	elif b_name == "shove":
		id = str(Skills.sig().get("id", ""))
	elif b_name == "ult":
		id = str(Skills.ult().get("id", ""))
	var pair: Array = COMPACT_SPELL_LABELS.get(id, COMPACT_ACTION_LABELS.get(id, []))
	return Game.t(str(pair[0]), str(pair[1])) if pair.size() == 2 else fallback

func _compact_spell_label(id: String) -> String:
	var pair: Array = COMPACT_SPELL_LABELS.get(id, [])
	return Game.t(str(pair[0]), str(pair[1])) if pair.size() == 2 else id

func spell_of(b_name: String) -> String:
	var sl: Array = Game.slots()
	return str(sl[0 if b_name == "skill1" else 1])

func _local(p: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * p

## Prefer a button's visible circle. The 12 px forgiving edge is used only when it selects one control;
## overlapping forgiving edges are treated as an ambiguous tap, not guessed as another action.
func _button_at(pos: Vector2, bs: Dictionary) -> String:
	var exact := ""
	var exact_score := INF
	var expanded := ""
	var expanded_score := INF
	var expanded_count := 0
	for b_name in bs:
		var b: Dictionary = bs[b_name]
		var radius := float(b["r"])
		var distance := pos.distance_to(b["pos"])
		if distance <= radius:
			var score: float = distance / maxf(1.0, radius)
			if score < exact_score:
				exact_score = score
				exact = str(b_name)
		elif distance <= radius + 12.0:
			expanded_count += 1
			if distance - radius < expanded_score:
				expanded_score = distance - radius
				expanded = str(b_name)
	if exact != "":
		return exact
	return expanded if expanded_count == 1 else ""

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		queue_redraw()
	if player == null or not is_visible_in_tree():
		return
	# while the game is paused (talk, shop, boss intro, death) presses go to that UI, but a finger
	# lifted during the pause must still let go of the stick / attack button, or the hero walks on alone
	if get_tree().paused and not (event is InputEventScreenTouch and not event.pressed):
		return
	if event is InputEventScreenTouch:
		var pos := _local(event.position)
		if event.pressed:
			var bs := buttons()
			var best := _button_at(pos, bs)
			if best != "":
				held[event.index] = best
				_press(best)
				get_viewport().set_input_as_handled()
				return
			var mid := size.x * 0.5
			var move_on_right := bool(Game.settings.get("left_hand", false))
			var on_move_side := pos.x > mid if move_on_right else pos.x < mid
			if on_move_side and pos.y > 70.0 and joy_id == -1:
				joy_id = event.index
				joy_origin = pos
				joy_knob = pos
				player.joy = Vector2.ZERO
				get_viewport().set_input_as_handled()
		else:
			if event.index == joy_id:
				joy_id = -1
				player.joy = Vector2.ZERO
			if held.has(event.index):
				if held[event.index] == "attack":
					player.hold_attack = false
					player.attack_release()
				elif held[event.index] == "block":
					player.hold_block = false
					player.block_end()
				held.erase(event.index)
	elif event is InputEventScreenDrag and event.index == joy_id:
		var fp: Vector2 = _local(event.position)
		var d: Vector2 = fp - joy_origin
		# the stick follows a thumb that drifts far past its rim, so it never "runs out"
		if d.length() > JOY_R * 1.5:
			joy_origin = fp - d.normalized() * JOY_R * 1.5
			d = fp - joy_origin
		if d.length() > JOY_R:
			d = d.normalized() * JOY_R
		joy_knob = joy_origin + d
		player.joy = d / JOY_R
		get_viewport().set_input_as_handled()

## let go of everything (used when the hero dies or a menu opens under the player's fingers)
func release_all() -> void:
	joy_id = -1
	held.clear()
	if player:
		player.joy = Vector2.ZERO
		player.hold_attack = false
		player.cancel_attack_charge()
		player.hold_block = false
		player.block_end()

func _press(b: String) -> void:
	_press_t[b] = Time.get_ticks_msec()
	var used: Dictionary = _used()
	used[b] = int(used.get(b, 0)) + 1
	match b:
		"attack":
			player.hold_attack = true
			player.attack_press()
		"talk":
			if player.near_npc:
				player.interact.emit(player.near_npc)
		"dodge":
			player.dodge()
		"block":
			player.hold_block = true
			player.block_start()
		"scroll":
			player.use_scroll()
		"sneak":
			player.toggle_sneak()
		"shove":
			player.signature()
		"potion":
			player.drink()
		"skill1":
			player.caster.cast_slot(0)
		"skill2":
			player.caster.cast_slot(1)
		"ult":
			player.caster.ultimate()

## (v0.27, engineering: "the pad is redrawn every frame: about 40% of the game's frame time") every frame while a
## thumb is on it, a button glows or animates; every second frame while a cooldown or the charge runs; ten times a
## second otherwise (stamina, mana, the ghosting over the hero)
var _redraw_t := 0.0
var _odd := false
func _process(dt: float) -> void:
	var want := 1.0 if (player != null and player.near_npc != null) else 0.0
	var talk_moving := not is_equal_approx(_talk_k, want)
	_talk_k = move_toward(_talk_k, want, dt * 6.0)
	_redraw_t -= dt
	_odd = not _odd
	if joy_id != -1 or not held.is_empty() or talk_moving or Game.Tut.teaches() != "" or _pressed_lately():
		queue_redraw()
	elif _ticking() and _odd:
		queue_redraw()
	elif _redraw_t <= 0.0:
		queue_redraw()
	else:
		return
	_redraw_t = 0.1

func _pressed_lately() -> bool:
	var now := Time.get_ticks_msec()
	for k in _press_t:
		if now - int(_press_t[k]) < 200:
			return true
	return false

func _ticking() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if player.dodge_cd > 0.0 or player.shove_cd > 0.0 or player.charging or player.caster.ult_ready():
		return true
	for id in Game.slots():
		if player.caster.cd_left(id) > 0.0:
			return true
	return false

# ---------------------------------------------------------------- drawing
func _draw() -> void:
	if player == null or get_tree().paused:
		return
	var s := size
	if joy_id != -1:
		var dv: Vector2 = joy_knob - joy_origin
		var k: float = dv.length() / JOY_R
		draw_circle(joy_origin, JOY_R + 8.0, Color(0, 0, 0, 0.22))
		draw_arc(joy_origin, JOY_R + 8.0, 0, TAU, 56, Color(UI.GOLD, 0.5), 2.0, true)
		draw_arc(joy_origin, JOY_R * 0.55, 0, TAU, 40, Color(UI.GOLD, 0.18), 1.0, true)
		if k > 0.15:
			# the rim lights up in the direction you push
			var a: float = dv.angle()
			draw_arc(joy_origin, JOY_R + 8.0, a - 0.55, a + 0.55, 16, Color(UI.GOLD_HI, 0.35 + 0.55 * k), 4.0, true)
		draw_circle(joy_knob + Vector2(0, 2), 25.0, Color(0, 0, 0, 0.3))
		draw_circle(joy_knob, 24.0, Color(0.16, 0.12, 0.09, 0.75))
		draw_circle(joy_knob, 20.0, Color(UI.GOLD, 0.22 + 0.25 * k))
		draw_arc(joy_knob, 23.0, 0, TAU, 36, Color(UI.GOLD_HI, 0.9), 2.0, true)
	else:
		# resting: where the stick usually sits (it appears under your thumb anywhere on the left half)
		var hint_x := s.x - 104.0 if bool(Game.settings.get("left_hand", false)) else 104.0
		var hint := Vector2(hint_x, s.y - 98)
		draw_circle(hint, JOY_R + 6.0, Color(0, 0, 0, 0.14))
		draw_arc(hint, JOY_R + 6.0, 0, TAU, 56, Color(UI.CREAM, 0.26), 2.0, true)
		draw_circle(hint, 20.0, Color(UI.CREAM, 0.14))
		draw_arc(hint, 20.0, 0, TAU, 32, Color(UI.CREAM, 0.3), 1.5, true)
		for i in 4:
			var a2 := i * PI * 0.5
			var c2 := hint + Vector2.from_angle(a2) * (JOY_R - 6.0)
			draw_colored_polygon(PackedVector2Array([c2 + Vector2.from_angle(a2) * 5.0, c2 + Vector2.from_angle(a2 + 2.2) * 4.0, c2 + Vector2.from_angle(a2 - 2.2) * 4.0]), Color(UI.CREAM, 0.3))
	var bs := buttons()
	var behind := _behind_spots()
	var teach: String = Game.Tut.teaches()      # (v0.24) the button Rostam's drill asks for: never faded, it glows
	for b_name in bs:
		var b: Dictionary = bs[b_name]
		var k := 1.0
		if b_name == "talk":
			k = ease(_talk_k, -2.0)
			if k <= 0.01:
				continue
		var pressed: bool = b_name in held.values() or (b_name == "sneak" and player.sneaking)
		var since: float = (Time.get_ticks_msec() - int(_press_t.get(b_name, -100000))) / 1000.0
		var squash: float = 1.0 - 0.08 * max(0.0, 1.0 - since / 0.15)
		if pressed:
			squash = min(squash, 0.94)
		var ghost := false
		for sp in behind:
			if (b["pos"] as Vector2).distance_to(sp) < float(b["r"]) + 18.0:
				ghost = true
		if b_name == teach:
			ghost = false
			var tp := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
			draw_texture_rect(_halo(), Rect2(b["pos"] - Vector2(b["r"], b["r"]) * 1.9, Vector2(b["r"], b["r"]) * 3.8), false, Color(UI.GOLD_HI, 0.3 + 0.35 * tp))
			draw_arc(b["pos"], float(b["r"]) + 5.0 + 3.0 * tp, 0, TAU, 48, Color(UI.GOLD_HI, 0.55 + 0.4 * tp), 3.0, true)
		_draw_button(b_name, b["pos"], float(b["r"]) * k * squash, b["col"], pressed, ghost, str(b["label"]) if needs_label(b_name) else "")
	if _talk_k > 0.5 and player.near_npc:
		var t: Dictionary = bs.get("talk", {})
		if not t.is_empty():
			var nm := Game.t(str(player.near_npc.get_meta("name_en", "")))
			_label(t["pos"] + Vector2(0, -t["r"] - 10), nm, 11, UI.GOLD_HI)

## (v0.23, playtest: "nine buttons and no names") each button wears its name under it until it has been used a few
## times (or the hero reaches level 5) — the first minutes teach the controls without a tutorial screen
const LEARN_USES := 3

func _used() -> Dictionary:
	var v: Dictionary = Game.v18()
	if typeof(v.get("btn", null)) != TYPE_DICTIONARY:
		v["btn"] = {}
	return v["btn"]

func needs_label(b_name: String) -> bool:
	if Game.lvl() >= 5 or b_name == "talk":
		return false
	return int(_used().get(b_name, 0)) < LEARN_USES

## (v0.23, playtest) where the hero and the bosses stand on screen, in this control's space: a button over them fades
## to a ghost so the fight shows through
func _behind_spots() -> Array:
	var out := []
	if player and is_instance_valid(player):
		out.append(_local(player.get_global_transform_with_canvas() * Vector2(0, -17)))
	for b in get_tree().get_nodes_in_group("bosses"):
		if is_instance_valid(b) and not b.dead and b.world == player.world:
			out.append(_local(b.get_global_transform_with_canvas() * Vector2(0, -float(b.box.y) * 0.5)))
	return out

func _draw_button(b_name: String, c: Vector2, r: float, col: Color, pressed: bool, ghost := false, lab := "") -> void:
	var usable := true
	var icon_name: String = BTN[b_name]["icon"]
	if b_name == "potion":
		usable = int(Game.state.get("potions", 0)) + int(Game.state.get("greater", 0)) > 0 and Game.hp < Game.max_hp()
	elif b_name == "dodge":
		usable = player.stamina >= 30.0
	elif b_name == "block":
		usable = player.guard_broken <= 0.0 and player.stamina >= 8.0
	elif b_name == "shove":
		# (v0.26, playtest: "waiting, it is almost black, and I cannot tell when it returns") only too little stamina
		# dims it; the wait is the pie and the seconds on it
		usable = player.stamina >= float(Skills.sig()["sta"]) or player.shove_cd > 0.0
		icon_name = str(Skills.sig()["icon"])
	elif b_name == "skill1" or b_name == "skill2":
		var id := spell_of(b_name)
		icon_name = Skills.spell_icon(id)
		var why: String = player.caster.block(id)
		usable = why == "" or why == "cooldown"
	elif b_name == "ult":
		icon_name = Skills.ult()["icon"]
		usable = player.caster.ult_ready()
	var a := 1.0 if usable else 0.45
	if ghost and not pressed:
		a *= 0.38
	if b_name == "ult" and usable:
		# ready: a soft pulsing halo
		var p := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)
		draw_texture_rect(_halo(), Rect2(c - Vector2(r, r) * 1.9, Vector2(r, r) * 3.8), false, Color(col, 0.35 + 0.3 * p))
	draw_circle(c + Vector2(0, 3), r + 2.0, Color(0, 0, 0, 0.32 * a))
	draw_circle(c, r, Color(UI.INK, (0.78 if pressed else 0.55) * a))
	draw_circle(c, r * 0.86, Color(col, (0.32 if pressed else 0.16) * a))
	draw_arc(c, r - 1.5, 0, TAU, 56, Color(col, 0.95 * a), 3.0, true)
	draw_arc(c, r - 5.0, 0, TAU, 56, Color(UI.GOLD, 0.35 * a), 1.0, true)
	var ic := UI.icon(icon_name, 96, 2.2)
	if ic:
		var isz := r * (0.95 if lab == "" else 0.7)
		var ic_c := c if lab == "" else c - Vector2(0, r * 0.24)
		draw_texture_rect(ic, Rect2(ic_c - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false, Color(UI.GOLD_HI if pressed else UI.CREAM, a))
	if lab != "":
		# Compact names keep the learning labels inside their rings, with larger type on small touch controls.
		var label_size := (12 if Game.lang == "fa" else 11) if r < 33.0 else (13 if Game.lang == "fa" else 12)
		_label(c + Vector2(0, r * 0.62), lab, label_size, Color(UI.CREAM, a))
	match b_name:
		"attack":
			if player.charging and player.hold_attack:
				var k: float = clamp(player.charge / 0.45, 0.0, 1.0)
				var rc := Color(1, 0.75, 0.35)
				if k >= 1.0:
					rc = Color(1, 0.92, 0.6).lerp(Color(1, 1, 1), 0.5 + 0.5 * sin(Time.get_ticks_msec() / 60.0))
				draw_arc(c, r + 5.0, -PI * 0.5, -PI * 0.5 + TAU * k, 56, rc, 4.0, true)
		"dodge":
			if player.dodge_cd > 0.0:
				var k2: float = player.dodge_cd / 0.8
				_pie(c, r - 3.0, k2, Color(0, 0, 0, 0.55))
		"shove":
			if player.shove_cd > 0.0:
				_pie(c, r - 3.0, min(1.0, player.shove_cd / float(Skills.sig()["cd"])), Color(0, 0, 0, 0.5))
				_secs(c, player.shove_cd)
		"potion":
			var n := int(Game.state.get("potions", 0)) + int(Game.state.get("greater", 0))
			var bc := c + Vector2(r * 0.72, -r * 0.72)
			draw_circle(bc, 10.0, Color(0, 0, 0, 0.4))
			draw_circle(bc, 9.0, col if n > 0 else Color(0.4, 0.35, 0.33))
			_label(bc + Vector2(0, 4), Game.num(n), 11, Color(1, 1, 1), false)
		"skill1", "skill2":
			var id := spell_of(b_name)
			var cd: float = player.caster.cd_left(id)
			if cd > 0.0:
				_pie(c, r - 3.0, cd / max(0.1, Skills.cooldown(id)), Color(0, 0, 0, 0.55))
				_secs(c, cd)
			if not Skills.known(id):
				var lk := UI.icon("lock", 48, 2.4)
				draw_texture_rect(lk, Rect2(c + Vector2(r * 0.25, r * 0.2), Vector2(14, 14)), false, Color(UI.CREAM, 0.9))
			# mana cost, blue when you have it, red when you don't
			var cost := Skills.cost(id)
			var ok := Game.mp >= cost
			var bc2 := c + (Vector2(-r * 0.74, r * 0.66) if lab == "" else Vector2(-r * 0.8, -r * 0.55))      # clear of the name
			draw_circle(bc2, 9.0, Color(0, 0, 0, 0.5))
			draw_circle(bc2, 8.0, Color(0.3, 0.45, 0.95) if ok else Color(0.7, 0.25, 0.25))
			_label(bc2 + Vector2(0, 4), Game.num(cost), 10, Color(1, 1, 1), false)
		"ult":
			var k3: float = clamp(Game.ult() / 100.0, 0.0, 1.0)
			draw_arc(c, r + 5.0, 0, TAU, 48, Color(0, 0, 0, 0.45), 5.0, true)
			if k3 > 0.0:
				draw_arc(c, r + 5.0, -PI * 0.5, -PI * 0.5 + TAU * k3, 48, Color(col, 0.95) if k3 < 1.0 else UI.GOLD_HI, 4.0, true)

var _halo_tex: Texture2D

func _halo() -> Texture2D:
	if _halo_tex == null:
		_halo_tex = preload("res://scripts/fx/tex.gd").glow()
	return _halo_tex

## the seconds a button still waits, on its face (shown from one second up, so short waits do not flicker)
func _secs(c: Vector2, left: float) -> void:
	if left >= 1.0:
		_label(c + Vector2(0, 7), Game.num(int(ceil(left))), 18, Color(1, 1, 1, 0.95))

func _pie(c: Vector2, r: float, k: float, col: Color) -> void:
	if k <= 0.0:
		return
	var pts := PackedVector2Array([c])
	var n := 32
	for i in n + 1:
		var a := -PI * 0.5 + TAU * k * float(i) / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, col)

func _label(pos: Vector2, t: String, fs: int, col: Color, outline := true) -> void:
	var f: Font = UI.font_bold if UI.font_bold else ThemeDB.fallback_font
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := pos - Vector2(w * 0.5, 0)
	if outline:
		draw_string_outline(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.85))
	draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
