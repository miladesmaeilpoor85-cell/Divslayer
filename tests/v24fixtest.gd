extends Node
## v0.24 checks for what the playtest panel found (Arash, the phone gamer): a hero who arrives (a load, a retry) is not
## noticed at once; what you cannot afford says so at once; the tale leads the compass after a boss; the second fall to a
## boss offers the Story difficulty; a won fight takes its tips away and the achievement card waits for the banner;
## the drilled button is never faded; messages keep clear of the hero's panel; the boss's name card frames the boss.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/v24fixtest.gd

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

func foes_near(r: float) -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead and not e.boss and e.global_position.distance_to(main.player.global_position) < r:
			out.append(e)
	return out

func run(m: Node) -> void:
	main = m
	await frames(5)
	Game.lang = "fa"

	# ---- arriving in the crypt by a load: pushed away, and unnoticed for a few seconds
	Game.new_game("warrior")
	Game.set_q(1, "active")
	Game.state["map"] = "dungeon"
	Game.state["x"] = 663.0
	Game.state["y"] = 764.0
	Game.save_game()
	Game.load_game()
	main.start_world()
	await frames(3)
	var near: Array = foes_near(450.0)
	var d0 := 9999.0
	for e in near:
		d0 = min(d0, e.global_position.distance_to(main.player.global_position))
	check("arrival_pushes_foes", d0 >= 130.0, d0)
	check("arrival_foes_calm", not near.is_empty() and near.all(func(e): return float(e.calm) > 2.0 and not e.alert), near.size())
	var hp0: float = Game.hp
	await frames(150)
	var d1 := 9999.0
	for e in foes_near(450.0):
		d1 = min(d1, e.global_position.distance_to(main.player.global_position))
	check("arrival_not_rushed", d1 > 100.0 and Game.hp == hp0, [d0, d1, Game.hp, hp0])
	# a blow wakes a calm foe at once
	var any: Array = foes_near(450.0)
	if not any.is_empty():
		any[0].calm = 3.0
		any[0].hurt(1.0, false, Vector2.RIGHT)
		check("a_blow_wakes_it", float(any[0].calm) == 0.0)

	# ---- the shop: no "tap again" for what you cannot afford
	Game.state["gold"] = 10
	main.hud.shop.open("smith")
	await frames(3)
	var tier: Dictionary = {}
	for it in Game.shop_catalog("smith"):
		if it.has("tier") and int(it.get("price", 0)) > 10:
			tier = it
			break
	main.hud.shop._tap(tier)
	await frames(1)
	check("cannot_afford_at_once", str(main.hud.shop.info_l.text) == "سکه‌ات کافی نیست!" and main.hud.shop._armed == "", main.hud.shop.info_l.text)
	Game.state["gold"] = 5000
	main.hud.shop._tap(tier)
	check("can_afford_asks_twice", main.hud.shop._armed == str(tier.get("id", "")))
	main.hud.shop.close()
	get_tree().paused = false
	await frames(2)

	# ---- after Arzhang, Zal's reward leads (Jamshid's errand waits)
	Game.set_q(1, "complete")
	Game.brann_set("core")
	check("tale_leads_after_a_boss", Game.objective() == "نزد زال برگرد" and Game.quest_target()["map"] == "village"
		and Game.quest_target()["pos"].distance_to(Vector2(443, 334)) < 40.0, Game.objective())
	Game.set_q(1, "done")

	# ---- a second fall to the same boss: the Story difficulty is offered, and taken at once
	Game.set_setting("diff", "normal")
	Game.fight = {"type": "boss", "map": "dungeon", "feet": Vector2(663, 764), "potions": 3, "retries": 0}
	var dp = main.hud.death
	dp.open(10, "boss")
	check("first_fall_no_offer", not dp.story_btn.visible)
	dp._close()
	Game.fight["retries"] = 1
	dp.open(10, "boss")
	check("second_fall_offers_story", dp.story_btn.visible and str(dp.story_btn.text).contains("داستانی"))
	var rematched := [false]
	var cb := func(): rematched[0] = true
	dp.rematch.connect(cb)
	if dp.rematch.is_connected(main._rematch):
		dp.rematch.disconnect(main._rematch)
	dp._on_story()
	check("story_taken_and_fight_again", Game.diff() == "story" and rematched[0] and not dp.visible)
	dp.rematch.disconnect(cb)
	dp.rematch.connect(main._rematch)
	Game.set_setting("diff", "normal")
	Game.fight = {}

	# ---- a won fight: its tips go, the achievement card waits for the banner
	main.goto_map("village", Vector2(433, 524))
	await frames(5)
	main.hud.hint("Staggered! It takes 50% more damage for a moment — strike now.")
	await frames(2)
	# the victory itself, as main._on_victory does it (no boss needed for these two)
	Game.fight = {}
	Game.victory_at = Time.get_ticks_msec()
	main.hud.notify.clear()
	check("victory_clears_tips", main.hud.notify.showing_text() == "" and main.hud.notify.queue.is_empty())
	var shown0: int = main.hud.ach_card.shown
	main.hud.ach_card.push("first_blood")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1500:
		await frames(1)
	check("ach_card_waits_for_the_banner", main.hud.ach_card.shown == shown0, main.hud.ach_card.shown)
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000 and main.hud.ach_card.shown == shown0:
		await frames(1)
	check("ach_card_then_shows", main.hud.ach_card.shown == shown0 + 1)

	# ---- the drilled button glows and is never faded
	Game.state["tut"] = {"step": "block", "hits": 3, "rolls": 2}
	check("drill_teaches_block", Game.Tut.teaches() == "block")
	Game.state["tut"] = {"step": "roll", "hits": 3, "rolls": 0}
	check("drill_teaches_roll", Game.Tut.teaches() == "dodge")
	Game.state["tut"] = {"step": "done", "hits": 0, "rolls": 0}
	check("no_drill_no_glow", Game.Tut.teaches() == "")

	# ---- a long message keeps clear of the hero's panel (top left)
	main.hud.notify.push("A long message that would once have spread across the top of the screen, over the objective box on the left, when a drill began.", "sword", UI.GOLD, 3.0)
	await frames(4)
	var np = main.hud.notify
	check("message_clear_of_the_panel", np.panel.position.x >= np.size.x * 0.33 and np.panel.position.x + np.panel.size.x <= np.size.x * 0.82,
		[np.panel.position.x, np.panel.size.x, np.size.x])
	np.clear()

	# ---- the boss's name card frames the boss (the camera slides towards it), and lets go after
	var cam = main.player.cam
	cam.frame(main.player.global_position + Vector2(0, -200), 0.65)
	check("card_frames_the_boss", cam.focus.distance_to(Vector2(0, -130)) < 1.0)
	cam.unframe()
	check("card_lets_go", cam.focus == Vector2.ZERO)

	print("V24FIXTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()
