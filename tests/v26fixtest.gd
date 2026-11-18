extends Node
## v0.26 checks on what the playtest panel found in the callings' build: a drill left half-way gives the objective, the
## compass and the glowing button back to the tale (and Rostam says the yard will wait); his new word replaces the old one
## on the bar; the post has no body; the feather's light stuns the foes near; the Sneak button sits under the band the
## hero is drawn in; and the echoes are named on the bosses' cards and in Zal's tasks.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/v26fixtest.gd

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

func run(m: Node) -> void:
	main = m
	await frames(5)
	Game.lang = "fa"
	Game.new_game("mage")
	main.start_world()
	await frames(6)
	var T = Game.Tut
	var tr = main.world.training
	var p = main.player
	var note = main.hud.notify
	var post: Vector2 = tr.POST

	# ---- a drill left half-way
	T.start()
	p.global_position = tr.POST + Vector2(-80, 20)
	await frames(4)
	check("drill_leads_in_the_yard", T.drilling() and Game.objective().begins_with("تمرینِ رستم") and T.teaches() == "attack" and not T.target().is_empty(),
		[Game.objective(), T.teaches()])
	note.clear()
	p.global_position = tr.POST + Vector2(-420, 60)
	await frames(4)
	check("walked_off_the_tale_leads", T.away and not T.drilling() and not Game.objective().begins_with("تمرینِ رستم") and T.teaches() == "" and T.target().is_empty(),
		[T.away, Game.objective(), T.teaches()])
	check("rostam_says_the_yard_waits", note.showing_text().contains("میدان همین‌جاست"), note.showing_text())
	check("still_his_news", T.has_news() and T.active())
	var qt: Dictionary = Game.quest_target()
	check("compass_to_zal", str(qt.get("kind", "")) == "npc" and qt.get("pos", Vector2.ZERO).distance_to(tr.POST) > 100.0, qt)
	p.global_position = tr.POST + Vector2(-80, 20)
	await frames(4)
	check("back_in_the_yard_the_drill_leads", not T.away and Game.objective().begins_with("تمرینِ رستم") and note.showing_text() == T.line("t_strike"),
		[Game.objective(), note.showing_text()])
	# in another map nothing of the drill follows the hero
	main.goto_map("forest", Vector2(500, 500))
	await frames(6)
	check("nothing_follows_to_the_forest", T.active() and not T.drilling() and T.teaches() == "" and not Game.objective().begins_with("تمرینِ رستم"), Game.objective())
	main.goto_map("village", post + Vector2(-80, 20))
	await frames(8)
	tr = main.world.training
	p = main.player
	check("and_waits_in_zabol", T.drilling() and T.teaches() == "attack", [T.away, T.teaches()])

	# ---- the post has no body
	var q := PhysicsPointQueryParameters2D.new()
	q.position = tr.POST - Vector2(0, 5)
	q.collision_mask = 1
	var hit: Array = main.world.get_world_2d().direct_space_state.intersect_point(q)
	check("post_has_no_body", hit.is_empty(), hit.size())

	# ---- his new word replaces the old one
	T.set_step("spell")
	tr._say(T.line("t_spell"))
	await frames(3)
	tr.on_cast("x")
	await frames(3)
	check("new_word_at_once", T.step() == "sig" and note.showing_text() == T.line("t_sig_mage") and note.queue.is_empty(), note.showing_text())
	check("spell_words_fit_the_small_pad", not T.line("t_spell").contains("دو دکمه") and T.line("t_sig_mage").contains("بر آتشش بنه"))

	# ---- the feather's light
	Game.state["level"] = 5
	Game.state["pad_all"] = true
	main.goto_map("forest", Vector2(500, 500))
	await frames(6)
	p = main.player
	var near: Node = null
	var far: Node = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or e.boss:
			continue
		e.calm = 99.0
		if near == null:
			near = e
			e.global_position = p.global_position + Vector2(60, 0)
		elif far == null:
			far = e
			e.global_position = p.global_position + Vector2(260, 0)
		else:
			e.global_position = Vector2(-4000, -4000)
	await frames(2)
	p.invuln = 0.0
	p.stamina = 100.0
	p.shove_cd = 0.0
	Game.mp = 1.0
	var hp0: float = Game.hp
	p.signature()
	check("feather_waits_ten", is_equal_approx(float(Game.Skills.sig()["cd"]), 10.0) and p.shove_cd > 9.0)
	p.take_hit(40.0)
	check("feather_dazzles_the_near", Game.hp == hp0 and near.has_status("stun") and not far.has_status("stun") and Game.mp >= 10.9, [Game.hp, near.est.keys(), far.est.keys(), Game.mp])

	# ---- the pad: Sneak under the band the hero is drawn in; a roll is counted
	var pad = main.hud.pad
	var bs: Dictionary = pad.buttons()
	var sn: Dictionary = bs["sneak"]
	check("sneak_below_the_hero", float(sn["pos"].y) - float(sn["r"]) > pad.size.y * 0.7, [sn["pos"], pad.size])
	var clear := true
	for k in bs:
		if k != "sneak" and Vector2(bs[k]["pos"]).distance_to(sn["pos"]) < float(bs[k]["r"]) + float(sn["r"]) + 2.0:
			clear = false
	check("sneak_touches_no_button", clear)
	var r0: int = p.rolls_n
	p.stamina = 100.0
	p.dodge_cd = 0.0
	p.dodge()
	check("a_roll_is_counted", p.rolls_n == r0 + 1)

	# ---- the echoes, named
	Game.lang = "fa"
	var cards := []
	for b in ["boss", "boss2", "matriarch"]:
		cards.append(str(Game.BOSS_CFG.get(b, {}).get("title", ["", ""])[1]))
	check("echo_on_the_cards", cards.all(func(x): return str(x).begins_with("پژواکِ")), cards)
	Game.new_game("warrior")
	var said := []
	for st in [["not_started", "", ""], ["complete", "", ""], ["done", "not_started", ""], ["done", "done", "not_started"], ["done", "done", "complete"]]:
		Game.set_q(1, st[0])
		if st[1] != "":
			Game.set_q(2, st[1])
		if st[2] != "":
			Game.set_q(3, st[2])
		said.append(" ".join(Game.elder_lines()))
	check("zal_names_the_echoes", said.all(func(x): return str(x).contains("پژواک")), said.map(func(x): return str(x).left(30)))
	check("one_image_blade_and_mist", said[0].contains("تیغِ رستم") and said[0].contains("مه") and T.line("r2").contains("تیغم") and not said[0].contains("دود") and T.line("r2").contains("مه"))

	Game.set_q(3, "active")
	check("objective_names_the_echo", Game.objective().contains("پژواکِ زنِ جادو"), Game.objective())
	check("an_echo_goes_back_to_dust", Game.is_echo("boss") and Game.is_echo("arbiter") and not Game.is_echo("ancientwyrm") and not Game.is_echo("ignarok"))

	# ---- an echo falls: the banner and the message say so, and the banner is not under the message
	Game.new_game("warrior")
	Game.Tut.skip()
	Game.set_q(1, "active")
	Game.state["level"] = 9
	main.goto_map("dungeon", Vector2(470, 700))
	await frames(8)
	var arz: Node = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.boss and e.type == "boss":
			arz = e
	check("arzhang_is_here", arz != null)
	if arz:
		arz.hurt(1e9, false, Vector2.ZERO)
		await frames(40)
		var ui = main.hud.boss_ui
		var note2 = main.hud.notify
		check("banner_dust_again", ui.banner_a.text == "به خاک برگشت" and ui.banner_b.text == "پژواکِ ارژنگ دیو", [ui.banner_a.text, ui.banner_b.text])
		# the message comes when the banner has faded (3.2 s); the level banner that follows sits below it
		await frames(190)
		check("message_dust_again", note2.showing_text().contains("پژواکِ ارژنگ دیو به خاک برگشت!"), note2.showing_text().left(60))
		main.hud.banner("x", "y", Color.WHITE, 1.0)
		await frames(3)
		var toast_bottom: float = note2.panel.get_global_rect().end.y
		check("banner_below_the_message", note2.showing_text() != "" and ui.banner_box.get_global_rect().position.y >= toast_bottom, [ui.banner_box.get_global_rect().position.y, toast_bottom])

	print("V26FIXTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()
