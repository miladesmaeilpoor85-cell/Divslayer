extends Node
## v0.20 checks: the achievements (the HTML game's 21 and the port's own), their profile apart from the save, the hooks in
## play (kills, parries, dodges, crafts, the ultimate, backstabs, bosses, "untouched"), the ones read from the save (level,
## gold, bosses, forge...), the quiet count for an older save, the card in the HUD, the Hero page's Achievements and Looks,
## the hero looks (the recolour, aura, crown, trail, the dodge's after-images), and Zabol's fountain.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/achtest.gd

var main: Node
var results := {}
var fails: Array = []
var A = null
var L = null

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func secs(t: float) -> void:
	var w := Time.get_ticks_msec()
	while Time.get_ticks_msec() - w < int(t * 1000.0):
		await get_tree().process_frame

func check(n: String, ok: bool, info = null) -> void:
	results[n] = ok if info == null else {"ok": ok, "info": info}
	if not ok:
		fails.append(n)
	printerr(("PASS " if ok else "FAIL ") + n + ("" if info == null else "  " + str(info)))

func find(node: Node, nm: String) -> Node:
	if node.name == nm:
		return node
	for c in node.get_children():
		var f := find(c, nm)
		if f:
			return f
	return null

func run(m: Node) -> void:
	main = m
	A = Game.Ach
	L = Game.Looks
	await get_tree().process_frame
	Game.lang = "fa"
	A.reset()

	# ---- the data
	var ids: Array = A.ids()
	var uniq := {}
	var bad := []
	for e in A.LIST:
		uniq[e[0]] = true
		if str(e[3]) == "" or str(e[5]) == "" or not UI.has_icon(str(e[1])):
			bad.append(e[0])
	check("list_complete", ids.size() == 42 and uniq.size() == 42 and bad.is_empty(), [ids.size(), bad])
	var html: Array = Game.table("ACHIEVEMENTS")
	var missing := []
	for h in html:
		if not str(h["id"]) in ids:
			missing.append(h["id"])
	check("html_achievements_all_here", html.size() == 21 and missing.is_empty(), missing)
	var lbad := []
	for k in L.ORDER:
		if L.def(k).is_empty() or (L.EARN[k] != "" and A.entry(L.EARN[k]).is_empty()):
			lbad.append(k)
	check("looks_defined", L.ORDER.size() == 13 and lbad.is_empty(), lbad)
	check("profile_apart_from_save", A.path() == "user://profile_test.json" and A.count() == 0)

	Game.new_game("warrior")
	for k in Game.BOSS_CFG:
		Game.v18()["seen"][k] = true
	main.start_world()
	await frames(10)
	main.player.invuln = 99999.0
	var card = main.hud.ach_card
	var shown0: int = card.shown

	# ---- counters in play
	var e: Node = main.world.spawn_enemy("slime", main.player.global_position + Vector2(60, 0))
	await frames(2)
	e.hurt(99999.0, false, Vector2.ZERO, false)
	await frames(3)
	check("kill_counts", A.stat("kills") == 1 and A.has("first_blood"), A.stat("kills"))
	await frames(4)
	check("card_shows", card.shown > shown0 and card.panel.modulate.a > 0.0 and card.name_l.text == A.title("first_blood"), [card.shown, card.name_l.text])
	var p: Node = main.player
	for i in 20:
		p.blocking = true
		p.block_t = 0.0
		p._guard(10.0)
	p.block_end()
	check("parries_count", A.stat("parries") == 20 and A.has("parry_master"), A.stat("parries"))
	for i in 30:
		p.dodge_cd = 0.0
		p.stamina = 100.0
		p.dodge()
		await frames(1)
	check("dodges_count", A.stat("dodges") == 30 and A.has("dodge_master"), A.stat("dodges"))
	await frames(20)
	Game.state["ult"] = 100.0
	p.caster.ultimate()
	check("ultimate_counts", A.has("first_ult"))
	Game.state["herbs"] = 99
	Game.state["essence"] = 99
	Game.state["gold"] = 5000
	var rid: String = str(Game.recipes()[0]["id"])
	for i in 10:
		Game.craft(rid)
	check("crafts_count", A.stat("crafts") == 10 and A.has("alchemist"), A.stat("crafts"))
	# a backstab: sneaking up on a foe that has not noticed you
	p.caster.spin_t = 0.0          # the warrior's whirlwind would kill the foe before the backstab
	p.caster.dance = {}
	p.body.rotation = 0.0
	await frames(2)
	var e2: Node = main.world.spawn_enemy("slime", p.global_position + Vector2(0, 22))
	await frames(2)
	e2.hp = 99999.0
	e2.max_hp = 99999.0
	e2.spd = 0.0
	e2.global_position = p.global_position + Vector2(0, 22)
	e2.alert = false
	p.facing = "down"
	p.sneaking = true
	p.atk_cd = 0.0
	var cd: Dictionary = Game.table("CLASSES")["warrior"]
	var cc = cd.get("critChance", 0.18)
	cd["critChance"] = 1.0
	p.attack(false)
	cd["critChance"] = cc
	# Warrior Starter now lands on zero-based impact frame 2 at 24 FPS.
	await frames(7)
	check("backstab_counts", A.stat("backstabs") >= 1, A.stat("backstabs"))
	check("crit_counts", A.stat("crits") >= 1, A.stat("crits"))

	# ---- read from the save
	check("rich_on_gold", A.has("rich"))
	Game.add_xp(200000)
	await frames(2)
	check("levels_unlock", A.has("apprentice") and A.has("veteran"), Game.lvl())
	Game.forge()["w"] = 5
	Game.forge()["a"] = 5
	Game.stats_changed.emit()
	check("forge_max", A.has("forge_max"))
	var pr: Array = A.progress("exterminator")
	check("progress_numbers", int(pr[1]) == 200 and int(pr[0]) == A.stat("kills"), pr)
	check("secret_hidden", A.desc("wyrm_slayer") != A.entry("wyrm_slayer")[5])

	# ---- bosses: "Untouched" only when nothing touched the hero during the fight
	Game.fight = {"type": "boss", "map": "dungeon", "hurt": false}
	Game.boss_defeated("boss")
	check("boss_untouched", A.has("boss_slayer") and A.has("untouched") and A.stat("boss_kills") == 1)
	A.p()["ach"].erase("untouched")
	Game.fight = {"type": "boss2", "map": "peaks"}
	p.invuln = 0.0
	p.take_hit(5.0)
	p.invuln = 99999.0
	check("hurt_flag", bool(Game.fight.get("hurt", false)))
	Game.boss_defeated("boss2")
	check("hurt_not_untouched", not A.has("untouched") and A.has("champion"))
	Game.fight = {}

	# ---- looks
	check("crimson_after_5_bosses", not L.unlocked("crimson"))
	check("cannot_wear_locked", not L.wear("crimson") and L.current() == "ember")
	for t in ["matriarch", "arbiter", "glaciertitan"]:
		Game.boss_defeated(t)
	check("crimson_unlocked", A.has("boss_master") and L.unlocked("crimson") and L.unlocked("frost") and L.unlocked("verdant"))
	check("wear_crimson", L.wear("crimson") and L.current() == "crimson")
	p.refresh_look()
	await frames(2)
	var mat = p.anim.material
	check("hero_recoloured", mat is ShaderMaterial and mat.get_shader_parameter("mask_tex") != null and p.look == "crimson")
	check("aura_shown", p.aura != null and p.aura.visible)
	var n0: int = main.world.ysort.get_child_count()
	p.roll_t = 0.26
	p._ghost_t = 0.0
	await frames(2)
	var ghost_mat := false
	for c in main.world.ysort.get_children():
		if c is Sprite2D and c.material == mat:
			ghost_mat = true
	check("ghost_in_look", ghost_mat, main.world.ysort.get_child_count() - n0)
	A.unlock("completionist")
	check("gold_crown", L.wear("gold") and true)
	p.refresh_look()
	check("crown_shown", p.crown_n != null and p.crown_n.visible)
	L.wear("ember")
	p.refresh_look()
	check("default_look_plain", p.anim.material == null and (p.aura == null or not p.aura.visible) and not p.crown_n.visible)
	var masks := []
	for c in ["warrior", "mage", "rogue", "paladin"]:
		for t in ["starter", "mid", "endgame"]:
			if L.material(c + "_" + t, "void") == null:
				masks.append(c + "_" + t)
	check("every_sheet_has_a_mask", masks.is_empty(), masks)

	# ---- the menu: the dot, the Hero page's two new pages
	main.hud.refresh()
	check("menu_dot_for_new", main.hud.menu_dot.visible)
	var pm = main.hud.pause
	pm.open()
	pm.hsub = "ach"
	pm._show("hero")
	await frames(3)
	var cards := 0
	for id in ids:
		if find(pm.body, "Ach_" + str(id)):
			cards += 1
	check("achievements_page", cards == 42, cards)
	check("seen_after_page", A.unseen().is_empty())
	pm.hsub = "looks"
	pm._show("hero")
	await frames(3)
	var lc := 0
	for k in L.ORDER:
		if find(pm.body, "Look_" + k):
			lc += 1
	check("looks_page", lc == 13, lc)
	var tap: Button = find(find(pm.body, "Look_frost"), "Tap")
	tap.pressed.emit()
	await frames(3)
	check("tap_wears_look", L.current() == "frost" and main.player.look == "frost")
	pm.hsub = "sheet"
	pm.close()
	await frames(2)

	# ---- the profile persists, and an older save counts quietly
	A.save()
	var had: int = A.count()
	A.load_profile()
	check("profile_saved", A.count() == had and L.current() == "frost")
	A.reset()
	Game.state["defeated"] = {"boss": true, "boss2": true, "matriarch": true}
	Game.v18()["kills"] = {"boss": 1, "boss2": 1, "matriarch": 1}
	var before_cards: int = card.shown
	var came: int = A.sync()
	await frames(2)
	check("sync_counts_old_save", came >= 5 and A.has("champion") and A.has("legend") and A.has("boss_slayer") and A.stat("boss_kills") == 3, came)
	check("sync_is_quiet", card.shown == before_cards)

	# ---- completionist comes by itself
	A.reset()
	for id in ids:
		if id != "completionist":
			A.quiet = true
			A.unlock(str(id))
	A.quiet = false
	check("completionist_auto", A.has("completionist") and A.count() == 42)

	# ---- the fountain
	main.goto_map("village", Vector2(452, 490))
	await frames(5)
	main.player.invuln = 99999.0
	var f = main.world.fountain
	check("fountain_built", f != null and f.is_inside_tree() and f.snd != null)
	f.in_tests = true
	Game.hp = Game.max_hp() * 0.3
	main.player.apply_status("poison", 5.0, 1.0)
	var h0: float = Game.hp
	await secs(0.6)
	check("fountain_restores", Game.hp > h0 + 1.0 and main.player.statuses.is_empty(), [h0, Game.hp])
	main.player.global_position = Vector2(700, 560)
	Game.hp = Game.max_hp() * 0.3
	var h1: float = Game.hp
	await secs(0.3)
	check("fountain_only_close", absf(Game.hp - h1) < 0.01, Game.hp - h1)
	f.in_tests = false

	print("ACHTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()
