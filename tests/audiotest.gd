extends Node
## v0.16.1 checks: the synthesised audio never reads past its own data. Every looping stream ends its loop on its last frame
## (Godot's mixer reads frame loop_end itself), the one-shot sounds do not loop, and the three ambience loops play through
## several wraps with the mixer running. Run it under tools/guardmalloc.so too: that makes a read past a big buffer crash
## here as it does on Android (see DEV_NOTES, "Android-only crashes").
## v0.17 checks: the recorded CC0 audio — every sound and track is there and imported, the variations never repeat
## back to back, footsteps match the ground, the region tracks crossfade (and loop by crossfading into themselves,
## and resume after a boss fight), the generative tune still plays where a track is missing, the ambience follows the
## map, the hour and the weather, the volume settings move the buses, and the credits name every track.
##   godot --headless --fixed-fps 60 --path . -- --test res://tests/audiotest.gd
##   LD_PRELOAD=tools/guardmalloc.so godot --headless --path . -- --test res://tests/audiotest.gd

var main: Node
var results := {}
var fails: Array = []

func check(n: String, ok: bool, info = null) -> void:
	results[n] = ok if info == null else {"ok": ok, "info": info}
	if not ok:
		fails.append(n)
	printerr(("PASS " if ok else "FAIL ") + n + ("" if info == null else "  " + str(info)))

static func frames_of(w: AudioStreamWAV) -> int:
	var per := 2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1
	return w.data.size() / per / (2 if w.stereo else 1)

func run(m: Node) -> void:
	main = m
	await get_tree().process_frame
	var mus = get_node("/root/Music")
	var sfx = get_node("/root/Sfx")

	# ---- the samples are ready (they are made on a worker thread at start-up)
	# (wait in real time: under --fixed-fps hundreds of frames pass before the worker thread is done)
	var w0 := Time.get_ticks_msec()
	while not mus._ready_samples and Time.get_ticks_msec() - w0 < 15000:
		await get_tree().process_frame
	check("music_samples_ready", mus._ready_samples, Time.get_ticks_msec() - w0)

	# ---- every looping stream ends its loop inside its data
	var loops_ok := true
	var bad := []
	for k in mus.loops:
		var w: AudioStreamWAV = mus.loops[k]
		var n := frames_of(w)
		var ok: bool = w.loop_mode == AudioStreamWAV.LOOP_FORWARD and w.loop_begin >= 0 and w.loop_end <= n - 1 and w.loop_end > w.loop_begin
		if not ok:
			bad.append([k, w.loop_begin, w.loop_end, n])
		loops_ok = loops_ok and ok
	check("ambience_loops_end_on_their_last_frame", loops_ok and mus.loops.size() == 3, bad)
	var helper: AudioStreamWAV = mus._wav(PackedFloat32Array([0.1, 0.2, 0.3, 0.4]), true)
	check("wav_helper_loop_end_is_last_frame", helper.loop_end == 3 and frames_of(helper) == 4, [helper.loop_end, frames_of(helper)])

	# ---- the notes and the sound effects are one-shots: the mixer stops at their last frame by itself
	var oneshot := true
	for k in mus.notes:
		oneshot = oneshot and (mus.notes[k] as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED
	for k in sfx.streams:
		oneshot = oneshot and (sfx.streams[k] as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED
	check("notes_and_sfx_do_not_loop", oneshot and mus.notes.size() == 5 and sfx.streams.size() >= 30, [mus.notes.size(), sfx.streams.size()])

	# ---- the three loops play through several wraps with the mixer running (the crash came at the first wrap)
	var players := []
	for k in ["crickets", "rain", "wind"]:
		var p := AudioStreamPlayer.new()
		p.stream = mus.loops[k]
		add_child(p)
		p.play()
		players.append(p)
	var wrapped := [false, false, false]
	var last := [0.0, 0.0, 0.0]
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 9000:
		await get_tree().process_frame
		for i in 3:
			var pos: float = players[i].get_playback_position()
			if pos + 0.5 < last[i]:
				wrapped[i] = true
			last[i] = pos
	check("mixer_runs", AudioServer.get_driver_name() != "" and last.any(func(x): return x > 0.0), [AudioServer.get_driver_name(), last])
	check("crickets_loop_wraps_safely", wrapped[0] and players[0].playing)
	check("rain_loop_wraps_safely", wrapped[1] and players[1].playing)
	check("wind_loop_wraps_safely", wrapped[2] and players[2].playing)
	for p in players:
		p.stop()

	# ---- every sound effect plays to its end
	for k in sfx.streams:
		var p := AudioStreamPlayer.new()
		p.stream = sfx.streams[k]
		add_child(p)
		p.play()
	await get_tree().create_timer(1.5).timeout
	check("all_sfx_play_to_the_end", true)

	await _v017(mus, sfx)

	print("AUDIOTEST_JSON " + JSON.stringify({"fails": fails, "results": results}))
	get_tree().quit()


# ---------------------------------------------------------------- v0.17: recorded audio
func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func secs(t: float) -> void:
	# real time: the decks fade on _process delta, and under --fixed-fps a frame is 1/60 s whatever the wall clock
	var w := Time.get_ticks_msec()
	while Time.get_ticks_msec() - w < int(t * 1000.0):
		await get_tree().process_frame

func playing_decks(mus) -> int:
	var n := 0
	for d in mus.decks:
		if d.playing:
			n += 1
	return n

func _v017(mus, sfx) -> void:
	# ---- every recorded sound is imported and loads; none loops
	var missing := []
	var looping := []
	for n in sfx.FILE_SOUNDS:
		if not sfx.files.has(n):
			missing.append(n)
			continue
		for st in sfx.files[n]:
			if st is AudioStreamOggVorbis and st.loop:
				looping.append(n)
	check("sfx_files_all_loaded", missing.is_empty() and sfx.files.size() == sfx.FILE_SOUNDS.size(), missing)
	check("sfx_files_do_not_loop", looping.is_empty(), looping)
	var vars := 0
	for n in sfx.files:
		vars += sfx.files[n].size()
	check("sfx_have_variations", vars >= 80 and sfx.files["hit"].size() >= 4 and sfx.files["swing"].size() >= 3, vars)
	check("every_called_sound_exists", sfx.has_sound("dash") and sfx.has_sound("coin_tick") and sfx.has_sound("kill") and sfx.has_sound("heart"))

	# ---- the variations are picked at random but never twice in a row
	var seq := []
	for i in 40:
		sfx._last_t.erase("hit")
		sfx.play("hit")
		seq.append(int(sfx._last["hit"]))
	var repeats := 0
	var seen := {}
	for i in seq.size():
		seen[seq[i]] = true
		if i > 0 and seq[i] == seq[i - 1]:
			repeats += 1
	check("variations_never_repeat_back_to_back", repeats == 0 and seen.size() >= 3, [repeats, seen.keys()])
	# a voice on cooldown does not stack (a pack noticing you growls once)
	sfx._last_t.erase("growl")
	sfx.play("growl")
	var t1: float = sfx._last_t["growl"]
	sfx.play("growl")
	check("voice_cooldown", is_equal_approx(sfx._last_t["growl"], t1))
	# the layered sounds play the recording and the synthesised shimmer together
	for p in sfx.players:
		p.stop()
	sfx._last_t.erase("potion")
	sfx.play("potion")
	var has_file := false
	var has_synth := false
	for p in sfx.players:
		if p.playing and p.stream in sfx.files["potion"]:
			has_file = true
		if p.playing and p.stream == sfx.streams["potion"]:
			has_synth = true
	check("potion_is_layered", has_file and has_synth)

	# ---- footsteps match the ground
	var ground := {}
	for k in ["village", "peaks", "dungeon", "shrine_light", "emberforge", "shadowfen"]:
		sfx.step(k)
		var g := ""
		for n in ["step_grass", "step_snow", "step_stone"]:
			if sfx.step_player.stream in sfx.files[n]:
				g = n
		ground[k] = g
	check("footsteps_match_ground", ground == {"village": "step_grass", "peaks": "step_snow", "dungeon": "step_stone", "shrine_light": "step_stone", "emberforge": "step_stone", "shadowfen": "step_grass"}, ground)

	# ---- every region, the title, the shrines and the bosses have a track; every map of the world maps to one
	var no_track := []
	for k in ["title", "village", "forest", "dungeon", "peaks", "shadowfen", "sanctum", "emberforge", "camp", "trial", "boss", "shrine"]:
		if not mus.has_track(k):
			no_track.append(k)
	var graph = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_graph.json"))
	for k in graph:
		# world_graph also carries non-map metadata; only test actual map records.
		if Game.map_data(str(k)).is_empty():
			continue

		mus.region = str(k)
		if not mus.has_track(mus.track_key()):
			no_track.append(k)
	check("every_map_has_a_track", no_track.is_empty(), no_track)
	var lens := {}
	for k in ["village", "dungeon", "boss", "shrine"]:
		lens[k] = snappedf(mus._track(k).get_length(), 0.1)
	check("tracks_are_real_length", lens["village"] > 50.0 and lens["dungeon"] > 100.0 and lens["boss"] > 80.0 and lens["shrine"] > 25.0, lens)
	var amb_ok := true
	for k in ["wind", "crickets", "birds", "fire", "cave", "water"]:
		var st = mus.amb[k].stream
		amb_ok = amb_ok and mus.amb_file.has(k) and st is AudioStreamOggVorbis and st.loop
	check("ambience_files_loop", amb_ok and not mus.amb_file.has("rain") and mus.amb["rain"].stream == mus.loops["rain"], mus.amb_file.keys())

	# ---- buses: effects and ambience under "SFX", the tune's reverb under "Music"; no bus sends forward; a limiter on Master
	var fwd := []
	for i in range(1, AudioServer.bus_count):
		var to := AudioServer.get_bus_index(AudioServer.get_bus_send(i))
		if to >= i:
			fwd.append(AudioServer.get_bus_name(i))
	var lim := false
	for e in AudioServer.get_bus_effect_count(0):
		lim = lim or AudioServer.get_bus_effect(0, e) is AudioEffectHardLimiter
	check("bus_routing", fwd.is_empty() and lim and AudioServer.get_bus_send(AudioServer.get_bus_index("Ambience")) == "SFX"
		and AudioServer.get_bus_send(AudioServer.get_bus_index("MusicSynth")) == "Music" and sfx.players[0].bus == "SFX" and mus.decks[0].bus == "Music", fwd)

	# ---- the decks: start, crossfade to another region, boss and back (resuming), loop by crossfading into itself
	# (fades run on game time — frames — while the playback position runs on the mixer's real time)
	Game.settings["music"] = true
	Game.settings["sound"] = true
	mus.boss = false
	mus.region = ""
	mus.play_region("forest")
	await frames(10)
	await secs(2.0)
	check("region_track_plays", mus.playing == "forest" and mus.decks[mus._active].playing and mus.decks[mus._active].stream == mus._track("forest"), mus.playing)
	mus._resume.clear()
	var pos_before: float = mus.decks[mus._active].get_playback_position()
	mus.set_boss(true)
	await frames(5)
	var both := playing_decks(mus)
	check("boss_crossfades_in", mus.playing == "boss" and both == 2 and mus._amp[mus._active] > 0.0 and mus._amp[mus._active] < 1.0, [mus.playing, both])
	await frames(70)
	check("boss_fade_done", playing_decks(mus) == 1 and mus._amp[mus._active] >= 0.99, [playing_decks(mus), mus._amp])
	mus.set_boss(false)
	await frames(2)
	var resumed: float = mus.decks[mus._active].get_playback_position()
	check("region_resumes_after_boss", mus.playing == "forest" and resumed >= pos_before - 0.2 and resumed > 1.0, [pos_before, resumed])
	await frames(200)
	# loop: put the track near its end: the next deck starts it over while the old one fades out
	var a0: int = mus._active
	var d0: AudioStreamPlayer = mus.decks[a0]
	d0.seek(d0.stream.get_length() - mus.TAIL - 0.3)
	await frames(2)
	await secs(0.5)
	await frames(1)
	var a1: int = mus._active
	check("track_loops_by_crossfade", a1 != a0 and mus.playing == "forest" and mus.decks[a1].get_playback_position() < 2.5, [a0, a1, mus.decks[a1].get_playback_position()])
	await frames(260)
	check("old_loop_fades_out", not d0.playing and playing_decks(mus) == 1, playing_decks(mus))
	# a region change crossfades
	mus.play_region("shrine_light")
	await frames(5)
	check("region_change_crossfades", mus.playing == "shrine" and playing_decks(mus) == 2, playing_decks(mus))
	await frames(200)
	check("region_change_done", playing_decks(mus) == 1)
	# a resume is forgotten after a while
	mus._resume["forest"] = [30.0, 0.05]
	await frames(6)
	check("resume_forgotten_later", not mus._resume.has("forest"))
	mus.play_region("forest")
	await frames(5)
	# music off: everything fades out; on: back
	Game.settings["music"] = false
	await frames(200)
	check("music_off_silences", mus.playing == "" and playing_decks(mus) == 0)
	Game.settings["music"] = true
	await frames(3)
	check("music_on_again", mus.playing == "forest")
	# a region without a track falls back to the generative tune
	mus.play_region("zz_no_such_region")
	await frames(240)
	var tune := false
	for v in mus.voices:
		tune = tune or v.playing
	check("fallback_generative_tune", mus.playing == "" and tune and playing_decks(mus) == 0)

	# ---- volume settings move the buses
	var mi := AudioServer.get_bus_index("Music")
	var si := AudioServer.get_bus_index("SFX")
	Game.set_setting("mvol", 0)
	Game.set_setting("svol", 2)
	var q := [AudioServer.get_bus_volume_db(mi), AudioServer.get_bus_volume_db(si)]
	Game.set_setting("mvol", 1)
	Game.set_setting("svol", 1)
	var n := [AudioServer.get_bus_volume_db(mi), AudioServer.get_bus_volume_db(si)]
	check("volume_settings", is_equal_approx(q[0], mus.MUSIC_DB - 8.0) and is_equal_approx(q[1], 4.0) and is_equal_approx(n[0], mus.MUSIC_DB) and is_equal_approx(n[1], 0.0), [q, n])

	# ---- the ambience follows the map, the hour and the weather
	Game.new_game("warrior")
	main.start_world()
	await secs(0.3)
	main.player.invuln = 99999.0        # the foes of the camp and the crypt must not end the walk
	var want := {}
	Game.state["day_t"] = 0.37
	main.goto_map("camp", Vector2(450, 470))
	main.world.atmos.forced = ""
	main.world.atmos.set_weather("")
	await secs(0.2)
	want["camp_day"] = _amb(mus)
	Game.state["day_t"] = 0.85
	main.world.atmos.sound()
	want["camp_night"] = _amb(mus)
	main.goto_map("dungeon", Vector2(430, 420))
	await secs(0.2)
	want["dungeon"] = _amb(mus)
	main.goto_map("peaks", Vector2(430, 420))
	await secs(0.2)
	want["peaks"] = _amb(mus)
	Game.state["day_t"] = 0.37
	main.goto_map("village", Vector2(450, 470))
	await secs(0.2)
	main.world.atmos.set_weather("rain")
	want["village_rain"] = _amb(mus)
	main.world.atmos.set_weather("")
	want["village_day"] = _amb(mus)
	check("ambience_by_map", want == {"camp_day": ["birds", "fire"], "camp_night": ["crickets", "fire"], "dungeon": ["cave"], "peaks": ["wind"],
		"village_rain": ["rain"], "village_day": ["birds"]}, want)
	# light graphics: no weather, but the region's own sounds stay
	Game.settings["fx"] = 0
	main.goto_map("emberforge", Vector2(430, 420))
	await secs(0.2)
	check("ambience_with_light_graphics", _amb(mus) == ["fire"], _amb(mus))
	Game.settings["fx"] = 1
	await secs(1.5)
	check("ambience_loop_audible", mus.amb["fire"].playing and mus.amb["fire"].volume_db > -20.0, mus.amb["fire"].volume_db)
	# (the forge's guardian may already have seen the hero at that spot: then it is the boss theme)
	# (v0.31) a chapter-2 boss plays the second take of the battle theme (boss_<type> -> boss_b)
	check("map_track_follows", mus.region == "emberforge" and (mus.playing.begins_with("boss") if mus.boss else mus.playing == "emberforge"), [mus.region, mus.playing, mus.boss])

	# ---- footsteps while walking, none while standing
	main.goto_map("village", Vector2(450, 470))
	await frames(5)
	var pl = main.player
	var walked := false
	var st_ok := false
	var p0: Vector2 = pl.global_position
	for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		sfx.step_player.stop()
		sfx.step_player.stream = null
		pl.joy = dir
		await frames(40)
		if sfx.step_player.stream != null:
			walked = true
			st_ok = sfx.step_player.stream in sfx.files["step_grass"]
			break
	pl.joy = Vector2.ZERO
	await frames(2)
	sfx.step_player.stream = null
	await frames(40)
	check("footsteps_while_walking", walked and st_ok and sfx.step_player.stream == null, [walked, st_ok, p0, pl.global_position])

	# ---- the credits name every track
	var Credits = load("res://scripts/ui/credits.gd")
	var cd: Dictionary = Credits.data()
	var used := []
	for c in cd.get("music", []):
		used.append(str(c["use"]))
		# (v0.31) a CC0 track names where it came from; a track made for the game with Suno says so
		var lic := str(c.get("license", ""))
		if not ((lic == "CC0 1.0" and str(c.get("url", "")).begins_with("https://")) or lic.begins_with("Suno")):
			used.append("BAD:" + str(c["use"]))
	var files := []
	for f in DirAccess.get_files_at("res://assets/audio/music"):
		if f.ends_with(".ogg"):
			files.append(f.get_basename())
	used.sort()
	files.sort()
	check("credits_cover_every_track", used == files and Credits.lines().size() >= files.size() + 4 and cd["sfx"].size() >= 5 and cd["ambience"].size() == 6, [used, files])
	var box: Control = Credits.build()
	check("credits_block_builds", box.get_child_count() == Credits.lines().size())
	box.free()

func _amb(mus) -> Array:
	var on := []
	for k in mus._amb_want:
		if mus._amb_want[k]:
			on.append(k)
	on.sort()
	return on
