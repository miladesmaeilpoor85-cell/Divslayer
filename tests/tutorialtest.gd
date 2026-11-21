extends Node
## v0.24 checks: the Ember-bearer and Rostam's training. The hero has no name of his own (four callings); Zal is the lord of
## Zabol, Rostam, Siavash and Gordafarid are villagers (drawn from the heroes' sheets in their own colours); Rostam's
## training runs through the real talk paths and the real hooks (the post takes the hero's blows, his marked blows are the
## bosses' telegraphs, the roll and the shield are judged as they land) and can be skipped; an old save never meets it.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/tutorialtest.gd

var main: Node
var results := {}
var fails: Array = []
var T = null

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func check(n: String, ok: bool, info = null) -> void:
	results[n] = ok if info == null else {"ok": ok, "info": info}
	if not ok:
		fails.append(n)
	printerr(("PASS " if ok else "FAIL ") + n + ("" if info == null else "  " + str(info)))

func npc(id: String) -> Node:
	for n in get_tree().get_nodes_in_group("npcs"):
		if str(n.get_meta("id", "")) == id:
			return n
	return null

func read_all() -> Array:
	var dlg = main.hud.dialogue
	var pages := []
	while dlg.visible and not dlg.choosing() and pages.size() < 40:
		pages.append(str(dlg.text_l.text))
		if not dlg.typing_done():
			dlg._block_until = 0
			dlg.advance()
		dlg._block_until = 0
		dlg.advance()
		await frames(1)
	return pages

func pick(i: int) -> void:
	var dlg = main.hud.dialogue
	await frames(1)
	dlg._block_until = 0
	dlg._pick(i)
	await frames(2)

## wait (game time) for Rostam's next marked blow; returns its telegraph
func next_mark(limit := 400) -> Dictionary:
	var bfx = main.world.bossfx
	for i in limit:
		for t in bfx.tele:
			if not t.has("_seen"):
				t["_seen"] = true
				return t
		await frames(1)
	return {}

func land(t: Dictionary) -> void:
	var guard := 0
	while main.world.bossfx.tele.has(t) and guard < 300:
		await frames(1)
		guard += 1
	await frames(2)

func run(m: Node) -> void:
	main = m
	T = Game.Tut
	await get_tree().process_frame
	Game.lang = "fa"
	Game.new_game("paladin")
	main.start_world()
	await frames(10)
	var p = main.player

	# ---- the Ember-bearer and his calling
	check("nameless_hero", Game.hero_name() == "اخگردار" and Game.hero_role() == "سوگندوَر" and Game.hero_role("warrior") == "پهلوان"
		and Game.hero_role("mage") == "فرزانه" and Game.hero_role("rogue") == "عیّار", [Game.hero_name(), Game.hero_role()])
	# (v0.25) in Zabol a new hero's pad shows only what the yard teaches
	var pb: Dictionary = main.hud.pad.buttons()
	check("village_pad_is_small", pb.has("attack") and pb.has("dodge") and pb.has("block") and pb.has("potion")
		and not pb.has("ult") and not pb.has("skill1") and not pb.has("skill2") and not pb.has("shove") and not pb.has("sneak"), pb.keys())
	check("hud_shows_the_calling", main.hud.name_l.text == "سوگندوَر", main.hud.name_l.text)
	check("paths", Game.hero_path("warrior") == "راهِ رستم" and Game.hero_path("paladin") == "راهِ سیاوش")

	# ---- Zabol's people
	var zal = npc("elder")
	check("zal_is_the_elder", zal != null and str(zal.get_node("NamePlate").text) == "زال", str(zal.get_node("NamePlate").text) if zal else "")
	var plates := {}
	for id in ["rostam", "siavash", "gordafarid", "smith", "merchant", "alchemist"]:
		var n = npc(id)
		plates[id] = str(n.get_node("NamePlate").text) if n else "?"
	check("new_villagers", plates["rostam"] == "رستم" and plates["siavash"] == "سیاوش" and plates["gordafarid"] == "گردآفرید", plates)
	check("renamed_villagers", plates["smith"] == "کاویانِ آهنگر" and plates["merchant"] == "سیندختِ کابلی" and plates["alchemist"] == "رودابهٔ درمانگر", plates)
	var rs = npc("rostam")
	var spr = rs.get_child(0) if rs else null
	# (v0.30) his own painted sheet now; a calling's sheet in his colours until a hero of the tale has one
	var rsheet := str(rs.get_meta("sheet", "")) if rs else ""
	check("rostam_drawn_as_a_hero", rs != null and spr is AnimatedSprite2D
		and (rsheet == "npc:rostam" or (rsheet == "hero:warrior_endgame" and spr.material != null))
		and spr.scale.x > npc("siavash").get_child(0).scale.x * 1.1, rsheet)
	check("training_yard", main.world.training != null and main.world.find_child("TrainingPost", true, false) != null)

	# ---- a new hero: the training is offered, Rostam has news, the compass points at the yard
	check("offered", T.offered() and Game.objective() == T.line("o_meet") and Game.quest_target()["map"] == "village"
		and Game.quest_target()["pos"].distance_to(rs.global_position) < 40.0, Game.objective())
	check("rostam_has_news", rs.get_node("NewsMarker").visible)

	# ---- talk: a line, then the choice (in his own colours); train
	p.invuln = 99999.0
	p.global_position = rs.global_position + Vector2(0, 24)
	await frames(2)
	main._on_interact(rs)
	await frames(2)
	var pages: Array = await read_all()
	var pf = main.hud.dialogue.portrait.face
	check("rostam_introduces_himself", pages.size() == 1 and str(pages[0]).find("رستم") >= 0 and main.hud.dialogue.choosing()
		and str(main.hud.dialogue.text_l.text) == T.line("r2"), pages)
	# (v0.28+) his painted portrait now comes from the owner-supplied Rostam atlas cell;
	# the sprite in his colours stays the fallback when the painting is missing.
	var dp = main.hud.dialogue.portrait
	var user_rostam_portrait: bool = dp._tex != null and dp.art_facing != 0 \
		and str(dp._tex.resource_path).ends_with("character_portraits_2026.webp") \
		and dp._src == Rect2(Vector2.ZERO, Vector2(192, 192))
	check("rostam_portrait_in_his_colours", user_rostam_portrait
		or (pf.material != null and dp.sheet == "warrior_endgame"), dp._tex.resource_path if dp._tex else null)
	await pick(0)
	check("training_starts", T.step() == "strike" and Game.objective() == T.fmt("o_strike", [0, T.STRIKES]), [T.step(), Game.objective()])

	# ---- the post: three blows, then a heavy one (a plain blow does not count for the heavy)
	var tr = main.world.training
	for i in 3:
		tr.strike(tr.rect.grow(2), Vector2.RIGHT, false)
	check("three_blows", T.step() == "heavy", T.step())
	tr.strike(tr.rect.grow(2), Vector2.RIGHT, false)
	check("plain_blow_is_not_heavy", T.step() == "heavy")
	tr.strike(tr.rect.grow(2), Vector2.RIGHT, true)
	check("heavy_blow", T.step() == "roll", T.step())

	# ---- the roll: a blow that would land does no harm, and does not count
	p.global_position = tr.POST + Vector2(-80, 20)
	var hp0: float = Game.hp
	var t1: Dictionary = await next_mark()
	check("rostam_marks_a_blow", not t1.is_empty() and str(t1.get("kind", "")) == "circle" and t1["pos"].distance_to(p.global_position) < 20.0)
	await land(t1)
	check("a_miss_does_not_hurt", int(T.st()["rolls"]) == 0 and Game.hp == hp0 and T.step() == "roll", [T.st()["rolls"], Game.hp, hp0])
	# out of it
	# (v0.26) walking out of the ring does not count: the drill teaches the button
	var t2w: Dictionary = await next_mark()
	p.global_position = t2w["pos"] + Vector2(110, 10)
	await land(t2w)
	check("walking_out_does_not_count", int(T.st()["rolls"]) == 0 and T.step() == "roll", T.st()["rolls"])
	p.global_position = tr.POST + Vector2(-80, 20)
	var t2: Dictionary = await next_mark()
	p.rolls_n += 1
	p.global_position = t2["pos"] + Vector2(110, 10)
	await land(t2)
	check("rolled_out", int(T.st()["rolls"]) == 1)
	# through it, rolling as it lands
	p.global_position = tr.POST + Vector2(-80, 20)
	var t3: Dictionary = await next_mark()
	while main.world.bossfx.tele.has(t3) and float(t3["t"]) > 0.05:
		await frames(1)
	p.dodge_iframes = 0.3
	await land(t3)
	check("rolled_through", T.step() == "block", [T.step(), T.st()["rolls"]])

	# ---- the shield: hold Block as his blow falls
	var gold0: int = int(Game.state["gold"])
	var pot0: int = int(Game.state["potions"])
	p.global_position = tr.POST + Vector2(-80, 20)
	var t4: Dictionary = await next_mark()
	p.hold_block = true
	p.block_start()
	await land(t4)
	check("held_the_blow", T.step() == "spell" and T.teaches() == "skill1", T.step())
	p.hold_block = false
	p.block_end()
	await frames(4)
	# ---- the last drill: a spell, cast through the real button path (the caster), in the yard
	check("not_paid_before_the_spell", int(Game.state["gold"]) == gold0)
	check("spell_button_comes_for_its_drill", main.hud.pad.buttons().has("skill1") and not main.hud.pad.buttons().has("ult"))
	Game.mp = Game.max_mp()
	var cast_ok: bool = p.caster.cast_slot(0)
	await frames(4)
	check("the_ember_answers", cast_ok and T.step() == "sig" and T.teaches() == "shove", [cast_ok, T.step()])
	# ---- (v0.26) the calling's own move closes the training; its button comes for the drill
	check("calling_button_comes", main.hud.pad.buttons().has("shove") and str(main.hud.pad.buttons()["shove"]["label"]) == "گذر از آتش"
		and Game.objective().find("گذر از آتش") >= 0, Game.objective())
	check("not_paid_before_the_calling", int(Game.state["gold"]) == gold0)
	p.stamina = 100.0
	p.shove_cd = 0.0
	await frames(30)
	p.signature()
	await frames(4)
	check("the_calling_move_ends_it", T.step() == "done" and p.fire_t > 0.0, [T.step(), p.fire_t])
	check("rostam_pays", int(Game.state["gold"]) == gold0 + T.GIFT_GOLD and int(Game.state["potions"]) == pot0 + T.GIFT_POTIONS)
	var done_pages: Array = await read_all()
	check("rostam_sends_you_to_zal", done_pages.size() >= 2 and str(done_pages[-1]).find("زال") >= 0, done_pages)
	check("objective_moves_to_zal", Game.objective().find("زال") >= 0 and not T.has_news(), Game.objective())
	# afterwards: a word for the fight ahead
	main._on_interact(rs)
	await frames(2)
	var hint: Array = await read_all()
	check("rostam_advises", hint.size() == 1 and str(hint[0]) == T.hint(), hint)

	# ---- Zal: the tale begins, he knows the Ember-bearer
	main._on_interact(zal)
	await frames(2)
	var zp: Array = await read_all()
	check("zal_greets_the_ember_bearer", zp.size() >= 4 and str(zp[0]).find("اخگردار") >= 0 and str(zp[0]).find("زال") >= 0 and Game.q(1) == "active", zp)
	check("advice_follows_the_tale", T.hint() == T.line("h_q1"))
	# the tale moved on: Rostam has a new word ("!"), and telling it clears the mark
	await frames(2)
	check("rostam_has_new_advice", T.has_news() and rs.get_node("NewsMarker").visible)
	main._on_interact(rs)
	await frames(2)
	var adv: Array = await read_all()
	await frames(2)
	check("advice_told", adv.size() == 1 and str(adv[0]) == T.line("h_q1") and not T.has_news() and not rs.get_node("NewsMarker").visible, adv)

	# ---- Siavash keeps the Trial, Gordafarid the bounties
	main._on_interact(npc("siavash"))
	await frames(2)
	var dl = main.hud.dialogue
	check("siavash_at_the_trial", dl.visible and dl.choosing() and str(dl.name_l.text) == "سیاوش" and str(dl.text_l.text).find("آتش") >= 0, dl.text_l.text)
	await pick(dl._choice_box.get_child_count() - 1)
	main._on_interact(npc("gordafarid"))
	await frames(2)
	check("gordafarid_at_the_board", dl.visible and dl.choosing() and str(dl.name_l.text) == "گردآفرید" and str(dl.text_l.text).find("سهراب") >= 0, dl.text_l.text)
	await pick(dl._choice_box.get_child_count() - 1)

	# ---- leaving Zabol once brings the whole pad, for good
	main.goto_map("forest", Vector2(300, 300))
	await frames(4)
	var pf2: Dictionary = main.hud.pad.buttons()
	main.goto_map("village", Vector2(600, 560))
	await frames(4)
	check("whole_pad_after_leaving", pf2.has("ult") and pf2.has("sneak") and main.hud.pad.buttons().has("skill2") and bool(Game.state.get("pad_all", false)))
	# ---- skipping, and an old save
	Game.new_game("mage")
	check("fresh_hero_offered_again", T.offered())
	main.goto_map("village", Vector2(600, 560))
	await frames(5)
	rs = npc("rostam")
	main._on_interact(rs)
	await frames(2)
	await read_all()
	await pick(1)
	check("skip", T.step() == "skipped" and Game.objective().find("زال") >= 0, [T.step(), Game.objective()])
	var sk: Array = await read_all()
	check("skip_sends_to_zal", sk.size() == 1 and str(sk[0]).find("زال") >= 0, sk)
	Game.new_game("rogue")
	Game.set_q(1, "active")
	Game.state.erase("tut")
	check("old_save_never_meets_it", T.step() == "skipped" and not T.offered() and Game.objective().find("ارژنگ") >= 0, Game.objective())
	# to Zal first: Rostam still offers the training (not as the objective), and sends you onward after it
	Game.new_game("paladin")
	main.goto_map("village", Vector2(600, 560))
	await frames(5)
	main._on_interact(npc("elder"))
	await frames(2)
	await read_all()
	check("zal_first", Game.q(1) == "active" and Game.quest_step("q1") == "forest_clues"
		and Game.quest_collection("q1", "forest_clues").is_empty() and T.fresh() and not T.offered()
		and Game.objective().find("دو نشانه از پژواک") >= 0
		and npc("rostam").get_node("NewsMarker").visible, Game.objective())
	main._on_interact(npc("rostam"))
	await frames(2)
	await read_all()
	check("offered_after_zal", main.hud.dialogue.choosing() and str(main.hud.dialogue.text_l.text) == T.line("r2"))
	await pick(1)
	var sk2: Array = await read_all()
	check("skip_after_zal_sends_onward", T.step() == "skipped" and sk2.size() == 1 and str(sk2[0]) == T.line("r_skip2"), sk2)
	# mid-way: Rostam asks whether to go on
	Game.new_game("warrior")
	T.start()
	main.goto_map("village", Vector2(600, 560))
	await frames(5)
	main._on_interact(npc("rostam"))
	await frames(2)
	check("midway_choice", main.hud.dialogue.choosing() and str(main.hud.dialogue.text_l.text) == T.line("r_mid"))
	await pick(1)
	check("stop_midway", T.step() == "skipped")
	await read_all()
	# (v0.24, playtest) the yard stays open: after a "no", Rostam gives his word and offers the training again
	main._on_interact(npc("rostam"))
	await frames(2)
	check("skipped_hero_can_come_back", main.hud.dialogue.choosing() and str(main.hud.dialogue.text_l.text) == T.hint())
	await pick(0)
	check("training_after_all", T.step() == "strike" and T.has_news())

	print("TUTORIALTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()
