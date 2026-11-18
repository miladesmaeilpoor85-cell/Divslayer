extends Node
## UI checks:  godot --headless --fixed-fps 60 --path . -- --test res://tests/uitest.gd
## Theme reaches every control, icons render, the title flow (new game, class pick, continue), the pause
## menu and its settings (language, sound, UI size), save & quit, dialogue typing, shop states,
## the message queue, map fades, touch targets and the talk button — driven by real input events.

var main: Node
var results := {}
var fails: Array = []

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func check(n: String, ok: bool, info = null) -> void:
	results[n] = ok if info == null else {"ok": ok, "info": info}
	if not ok:
		fails.append(n)
	printerr(("PASS " if ok else "FAIL ") + n + ("" if info == null else "  " + str(info)))

func click(c: Control) -> void:
	var p := c.get_global_rect().get_center()
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = p
		ev.global_position = p
		ev.pressed = down
		get_viewport().push_input(ev, true)
		await frames(2)

func touch(i: int, pos: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = i
	ev.position = pos
	ev.pressed = down
	get_viewport().push_input(ev, true)

func run(m: Node) -> void:
	main = m
	await get_tree().process_frame
	Game.lang = "fa"
	Game.set_setting("ui", 1)
	Game.set_setting("sound", true)

	# ---- the kit
	var b := Button.new()
	add_child(b)
	var sb = b.get_theme_stylebox("normal")
	check("theme_reaches_controls", sb is StyleBoxFlat and sb.border_color.is_equal_approx(UI.GOLD_DIM), sb)
	b.queue_free()
	var ic: Texture2D = UI.icon("sword", 48)
	check("icons_render", ic != null and ic.get_width() == 48 and UI.icon("sword", 48) == ic)
	check("fonts_loaded", UI.font_body != null and UI.font_bold != null and UI.font_display_en != null)

	# ---- title: new game -> pick a class -> begin
	Game.new_game("warrior")
	Game.save_game()
	main.show_menu()
	await frames(10)
	var cont: Control = main.menu.find_child("Continue", true, false)
	check("title_offers_continue", cont != null and cont.visible)
	await click(main.menu.find_child("NewGame", true, false))
	await frames(4)
	var card: Control = main.menu.find_child("Card_paladin", true, false)
	check("class_cards_shown", card != null)
	await click(card)
	await frames(4)
	await click(main.menu.find_child("Begin", true, false))
	await frames(30)
	check("new_game_with_picked_class", Game.cls == "paladin" and main.hud != null and main.menu == null and main.menu_bg == null, Game.cls)
	for k in Game.BOSS_CFG:
		Game.v18()["seen"][k] = true
	var hud: Node = main.hud

	# ---- HUD reflects the hero
	Game.state["gold"] = 777
	Game.stats_changed.emit()
	await frames(2)
	check("hud_gold_chip", hud.gold_chip.get_node("Value").text == Game.num(777))
	main.player.apply_status("poison", 5.0, 1.0)
	await frames(3)
	check("status_chip_shown", hud.status_row.get_child_count() == 1)
	Game.hp = Game.max_hp() * 0.15
	Game.stats_changed.emit()
	await frames(60)
	check("low_health_vignette", hud.vignette.modulate.a > 0.2, hud.vignette.modulate.a)
	Game.hp = Game.max_hp()
	main.player.statuses.clear()

	# ---- touch targets are thumb-sized (>= 44 px in the 854-wide layout)
	var bs: Dictionary = hud.pad.buttons()
	var small := []
	for k in bs:
		if float(bs[k]["r"]) * 2.0 < 44.0:
			small.append(k)
	check("touch_targets_44px", small.is_empty() and hud.menu_btn.size.x >= 44.0, small)

	# ---- pause menu through the menu button, settings
	await click(hud.menu_btn)
	await frames(4)
	check("menu_button_pauses", hud.pause.visible and get_tree().paused)
	hud.pause._show("settings")
	await frames(2)
	Game.set_setting("ui", 2)
	await frames(2)
	check("ui_size_large", is_equal_approx(hud.root.scale.x, 1.15), hud.root.scale)
	Game.set_setting("ui", 1)
	Game.set_setting("sound", false)
	check("sound_off_mutes", Sfx.muted)
	Game.set_setting("sound", true)
	hud.pause._set_lang("en")
	await frames(2)
	check("language_switch_updates_hud", Game.lang == "en" and hud.name_l.text == "Oathbearer", hud.name_l.text)
	hud.pause._set_lang("fa")
	hud.pause.close()
	await frames(2)
	check("resume_unpauses", not get_tree().paused and not hud.pause.visible)
	# (v0.24, playtest) the whole menu column fits — "Save & quit" is never cut off at the foot
	var fits := {}
	for ui in [1, 2]:
		Game.set_setting("ui", ui)
		await frames(2)
		hud.pause.open()
		await frames(4)
		var nv: Control = hud.pause.nav
		fits[ui] = [int(nv.size.y), int(nv.get_parent().size.y)]
		hud.pause.close()
		await frames(2)
	Game.set_setting("ui", 1)
	check("pause_menu_fits", fits[1][0] <= fits[1][1] + 1 and fits[2][0] <= fits[2][1] + 1, fits)

	# ---- v0.5: the minimap opens the map; the hero sheet draws the gear; the new settings exist
	await click(hud.minimap)
	await frames(4)
	check("minimap_tap_opens_map", hud.pause.visible and hud.pause.tab == "map" and hud.pause.body.get_child_count() >= 3, hud.pause.tab)
	hud.pause._show("hero")
	await frames(3)
	var icons: Array = hud.pause.body.find_children("*", "Control", true, false).filter(func(c): return c.get_script() == preload("res://scripts/ui/item_icon.gd"))
	check("hero_sheet_item_pictures", icons.size() >= 3, icons.size())
	hud.pause._show("settings")
	await frames(3)
	var texts := []
	for l in hud.pause.body.find_children("*", "Label", true, false):
		texts.append(l.text)
	var want := ["دوربین", "گرافیک", "روشنایی", "موسیقی", "لرزش گوشی"]
	var missing: Array = want.filter(func(w): return not w in texts)
	check("new_settings_listed", missing.is_empty(), missing)
	hud.pause.close()
	await frames(2)

	# ---- talk button near a villager opens the dialogue; typing then paging
	var elder = null
	for n in get_tree().get_nodes_in_group("npcs"):
		if n.get_meta("id") == "elder":
			elder = n
	main.player.global_position = elder.global_position + Vector2(30, 6)
	await frames(30)
	var tb: Dictionary = hud.pad.buttons()
	check("talk_button_appears", tb.has("talk"))
	if tb.has("talk"):
		touch(3, hud.pad.get_global_transform_with_canvas() * tb["talk"]["pos"], true)
		await frames(3)
		touch(3, hud.pad.get_global_transform_with_canvas() * tb["talk"]["pos"], false)
		await frames(3)
	var dl: Control = hud.dialogue
	check("talk_opens_dialogue", dl.visible and get_tree().paused)
	await frames(2)
	var typing: bool = not dl.typing_done()
	dl._block_until = 0
	dl.advance()
	var full: bool = dl.typing_done()
	var page0: int = dl.idx
	dl._block_until = 0
	dl.advance()
	check("tap_completes_then_pages", typing and full and dl.idx == page0 + 1, [typing, full, dl.idx])
	while dl.visible:
		dl._block_until = 0
		dl.advance()
		await frames(1)

	# ---- shop: the whole ladder with states; a locked tier cannot be bought
	Game.state["gold"] = 500
	hud.shop.open("merchant")
	await frames(3)
	var cat: Array = Game.shop_catalog("merchant")
	var states := {}
	for it in cat:
		states[it["id"]] = it["state"]
	check("shop_catalog_states", states.get("weapon_1") == "owned" and states.get("weapon_2") == "next" and states.get("weapon_3") == "locked", states)
	var w3 := {}
	for it in cat:
		if it["id"] == "weapon_3":
			w3 = it
	check("locked_tier_not_sold", Game.buy("merchant", w3) == "" and int(Game.state["gold"]) == 500)
	check("shop_cards_built", hud.shop.grid.get_child_count() == cat.size())
	await click(hud.shop.close_btn)
	await frames(2)
	check("shop_close_button", not hud.shop.visible and not get_tree().paused)

	# ---- messages queue instead of piling up; a new map clears them
	hud.toast("one")
	hud.toast("two")
	hud.toast("three")
	await frames(4)
	check("messages_queue", hud.notify.showing_text() == "one" and hud.notify.queue.size() == 2)
	main.goto_map("forest", Vector2(560, 470))
	await frames(3)
	check("messages_cleared_on_new_map", hud.notify.queue.is_empty())

	# ---- walking through an exit fades out and back in
	main.goto_map("village", Vector2(433, 524))
	await frames(40)
	var ex: Rect2
	for a in get_tree().get_nodes_in_group("exits"):
		if a.get_meta("to") == "forest":
			ex = a.get_meta("rect")
	main.player.global_position = ex.get_center() + Vector2(0, 17)
	await frames(6)
	var dark: float = hud.fade.modulate.a
	await frames(60)
	check("map_change_fades", dark > 0.1 and hud.fade.modulate.a < 0.05 and main.world.key == "forest", [dark, main.world.key])

	# ---- save & quit to the title, then continue
	Game.state["gold"] = 4321
	hud.open_pause()
	await frames(2)
	hud.pause._quit()
	await frames(10)
	check("quit_to_title", main.menu != null and main.hud == null and main.menu_bg != null and not get_tree().paused)
	await click(main.menu.find_child("Continue", true, false))
	await frames(30)
	check("continue_restores", main.hud != null and int(Game.state["gold"]) == 4321 and main.world.key == "forest")

	print("UITEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()
