extends Node
## v0.28 checks on the painted dialogue portraits (eleven since 0.28.1, with Qaren): every portrait file exists and ships on Android, each speaker shows his
## painting (heroes of the tale by their look), a speaker with no painting keeps his sprite face, the painted face turns
## toward the text in both languages, Jamshid's painting is not tinted twice, and the HUD's own hero portrait is untouched.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/v28portraittest.gd

const Portrait = preload("res://scripts/ui/portrait.gd")
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

func excludes(preset: String) -> Array:
	var cfg := ConfigFile.new()
	cfg.load("res://export_presets.cfg")
	for sec in cfg.get_sections():
		if sec.ends_with(".options") or not cfg.has_section_key(sec, "name"):
			continue
		if str(cfg.get_value(sec, "name")) == preset:
			var out := []
			for p in str(cfg.get_value(sec, "exclude_filter", "")).split(","):
				if p.strip_edges() != "":
					out.append(p.strip_edges())
			return out
	return []

func run(m: Node) -> void:
	main = m
	await frames(5)
	Game.lang = "fa"

	# ---- the files
	var missing := []
	var left_out := []
	var no_mip := []
	var ex := excludes("Android")
	for k in Portrait.ART:
		var path: String = Portrait.ART_DIR % Portrait.ART[k][0]
		if not ResourceLoader.exists(path):
			missing.append(path)
			continue
		for pat in ex:
			if path.trim_prefix("res://").match(pat):
				left_out.append(path)
		var t: Texture2D = load(path)
		if not t.get_image().has_mipmaps():
			no_mip.append(path)
	check("eleven_portraits", Portrait.ART.size() == 11, Portrait.ART.size())
	check("portrait_files_exist", missing.is_empty(), missing)
	check("portraits_ship_on_android", left_out.is_empty(), left_out)
	check("portraits_have_mipmaps", no_mip.is_empty(), no_mip)

	# ---- (v0.30) the people of the tale walk the world in their own painted sheets
	var bad_sheets := []
	for k in Game.manifest.get("npcs", {}):
		var sp := "assets/art/Npcs/%s.png" % k
		var ok := ResourceLoader.exists("res://" + sp)
		for pat in ex:
			if sp.match(pat):
				ok = false
		if ok:
			var tx: Texture2D = load("res://" + sp)
			ok = tx.get_width() == 600 and tx.get_height() == 468
		if not ok:
			bad_sheets.append(k)
	check("villager_sheets_ship", bad_sheets.is_empty() and Game.manifest["npcs"].size() >= 11, bad_sheets)
	var W = load("res://scripts/world.gd")
	var no_own := []
	for id in W.HERO_NPCS:
		if not Game.manifest["npcs"].has(id):
			no_own.append(id)
	check("heroes_of_the_tale_have_own_sheets", no_own.is_empty(), no_own)

	# ---- (v0.33) the hero's twelve painted sheets: the wide cell, a colour mask for the looks, nothing cut at the edge
	var bad_heroes := []
	for k in Game.manifest.get("heroes", {}):
		var hm: Dictionary = Game.manifest["heroes"][k]
		var tx: Texture2D = load("res://assets/art/Heroes/%s.png" % k)
		var ok: bool = int(hm.get("cellW", 0)) == 160 and tx != null and tx.get_width() == 800 and tx.get_height() == 468 \
			and ResourceLoader.exists("res://assets/art/Heroes/%s_mask.png" % k)
		if not ok:
			bad_heroes.append(k)
	check("hero_sheets_painted", bad_heroes.is_empty() and Game.manifest["heroes"].size() == 12, bad_heroes)

	# ---- (v0.34) the 26 common foes are painted Shahnameh foes: each sheet is exactly its manifest's cells (frames along a
	# row, one row a variant), ships on Android, and the foe has a Persian name of its own
	var FOES := ["slime", "skeleton", "archer", "wraith", "bat", "imp", "golem", "mosquito", "toad", "lurker", "iceling",
		"frostknight", "crystalSpider", "icegolem", "cinderhound", "slagbrute", "bellowdrone", "moltencore", "bandit",
		"banditArcher", "frostwolf", "rimewraith", "wyrmling", "serpentguard", "serpentarcher", "serpent"]
	var bad_foes := []
	for k in FOES:
		var em: Dictionary = Game.manifest["enemies"].get(k, {})
		var sp := "assets/art/Enemies/%s.png" % k
		var ok: bool = em.has("cellW") and ResourceLoader.exists("res://" + sp)
		for pat in ex:
			if sp.match(pat):
				ok = false
		if ok:
			var tx: Texture2D = load("res://" + sp)
			ok = tx.get_width() == int(em["cellW"]) * int(em.get("frames", 1)) and tx.get_height() == int(em["cellH"]) * int(em.get("variants", 1))
		Game.lang = "fa"
		if ok:
			ok = Game.enemy_name(k) != Game.enemy_def(k).get("name", k)
		if not ok:
			bad_foes.append(k)
	check("foe_sheets_painted", bad_foes.is_empty(), bad_foes)

	# ---- (v0.35) the green region is painted: its ground from tiled textures (mipmapped, shipped), every object a
	# painted one (g_) whose picture is there and ships on Android
	var TerrainT = load("res://scripts/fx/terrain.gd")
	var bad_land := []
	for mk in ["village", "forest", "camp"]:
		if not TerrainT.has_terrain(mk):
			bad_land.append(mk + ": no terrain")
		for o in Game.map_data(mk).get("objects", []):
			var sn := str(o.get("sprite", ""))
			if sn == "":
				continue
			var fp := "assets/art/MapObjects/%s.png" % str(Game.obj_sprites.get(sn, {}).get("file", sn))
			var shipped := ResourceLoader.exists("res://" + fp)
			for pat in ex:
				if fp.match(pat):
					shipped = false
			if not sn.begins_with("g_") or not shipped:
				bad_land.append(mk + ": " + sn)
	for tn in TerrainT.cfg().get("textures", {}):
		var tp := "res://assets/art/Terrain/" + str(TerrainT.cfg()["textures"][tn]["file"])
		var tt: Texture2D = load(tp) if ResourceLoader.exists(tp) else null
		if tt == null or not tt.get_image().has_mipmaps():
			bad_land.append(tp)
	check("green_region_painted", bad_land.is_empty(), bad_land)

	# ---- every speaker of the game shows his painted portrait or approved atlas region
	Game.new_game("warrior")
	if main.hud == null:
		main.start_world()
	await frames(10)
	var dl = main.hud.dialogue
	var p = dl.portrait
	var sheets := ["elder", "merchant", "alchemist", "brann", "keeper", "hesk", "smith", "qaren",
		"hero:warrior_endgame:npc_rostam", "hero:paladin_endgame:npc_siavash", "hero:rogue_endgame:npc_gordafarid"]
	var wrong := []
	for s in sheets:
		dl.open("x", ["..."], s)
		await frames(2)
		var key := Portrait.art_key(s)
		var user_portrait := Portrait.USER_ART.has(key)
		var wrong_source := false
		if user_portrait:
			var spec: Array = Portrait.USER_ART[key]
			wrong_source = p._tex != Portrait.USER_ART_ATLAS or p._src != Rect2(spec[0], Vector2(192, 192))
		else:
			var want: String = Portrait.ART[key][0]
			wrong_source = p._tex == null or not str(p._tex.resource_path).ends_with(want + ".webp")
		if p.art_facing == 0 or wrong_source or p.face.material != null:
			wrong.append([s, p.art_facing, p._tex.resource_path if p._tex else null, p._src])
		dl.visible = false
		get_tree().paused = false
	check("every_speaker_painted", wrong.is_empty(), wrong)

	# ---- a speaker with no painting (here a hero sheet with no look) keeps his sprite face, not the last painting
	dl.open("x", ["..."], "elder")
	await frames(2)
	dl.open("x", ["..."], "hero:mage_endgame")
	await frames(2)
	check("no_painting_keeps_sprite", p.art_facing == 0 and not str(p._tex.resource_path).ends_with(".webp") and p.face.texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE, p._tex.resource_path if p._tex else null)

	# ---- the face turns toward the text: right-facing paintings are mirrored in Persian (portrait on the right)
	Game.lang = "fa"
	dl.open("x", ["..."], "hesk")
	await frames(3)
	var fa_hom: bool = p.mirror
	var right_side_fa: bool = p.get_global_rect().get_center().x > dl.panel.get_global_rect().get_center().x
	dl.open("x", ["..."], "alchemist")
	await frames(3)
	var fa_rud: bool = p.mirror
	Game.lang = "en"
	dl.open("x", ["..."], "hesk")
	await frames(3)
	var en_hom: bool = p.mirror
	var left_side_en: bool = p.get_global_rect().get_center().x < dl.panel.get_global_rect().get_center().x
	dl.open("x", ["..."], "alchemist")
	await frames(3)
	var en_rud: bool = p.mirror
	check("portrait_side_follows_language", right_side_fa and left_side_en, [right_side_fa, left_side_en])
	check("faces_turn_to_text", fa_hom and not fa_rud and not en_hom and en_rud, [fa_hom, fa_rud, en_hom, en_rud])
	Game.lang = "fa"

	# ---- Jamshid's painting is a shade already: no second tint
	dl.open("x", ["..."], "brann")
	await frames(2)
	check("jamshid_painting_not_tinted", p.face.modulate == Color.WHITE, p.face.modulate)

	# ---- the frame fits the panel
	check("portrait_fits_panel", p.size.y <= dl.panel.size.y - 4.0, [p.size, dl.panel.size])

	# ---- the HUD's own hero portrait is still the hero's sprite face
	var hp = main.hud.portrait
	check("hud_portrait_untouched", hp.art_facing == 0 and hp._tex != null and not str(hp._tex.resource_path).ends_with(".webp"), hp._tex.resource_path if hp._tex else null)

	# ---- (v0.31) the end card plays the second take of the main theme, and the region's music comes back after it
	Music.region = "village"
	main.hud.ending.open(3)
	await frames(2)
	var during: String = Music.track_key()
	main.hud.ending.close()
	await frames(2)
	# (v0.31) a region with two takes plays them in turn
	Music._turn["shadowfen"] = false
	var t1: AudioStream = Music._take("shadowfen")
	Music._turn["shadowfen"] = true
	var t2: AudioStream = Music._take("shadowfen")
	Music._turn["shadowfen"] = false
	check("second_take_in_turn", t1 != null and t2 != null and t1 != t2 and str(t2.resource_path).ends_with("shadowfen_2.ogg"), [t1, t2])
	check("ending_has_its_own_music", during == "ending" and Music.track_key() == "village" and Music.has_track("title"), [during, Music.track_key()])

	print("V28PORTRAITTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()
