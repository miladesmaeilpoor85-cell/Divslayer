extends Node
## Music and ambience (autoload "Music").
## Since v0.17 every region has a recorded CC0 track (assets/audio/music/<region>.ogg — see assets/audio/CREDITS.md):
## a change of region or a boss fight crossfades between them, a track you left a moment ago picks up where it was,
## and each track starts over a few seconds before its end, crossfading into itself, so no loop point is ever heard.
## Ambience loops (assets/audio/amb/): crickets, wind, birds, fire, cave and water; rain is synthesised.
## The generative tune of the HTML game (a sampler of synthesised notes into a reverb) is kept as the fallback for
## a region without a track; wind and crickets fall back to synthesised loops the same way.
## Settings: music on/off and music volume; sound off mutes everything; the sound volume covers the ambience.

const RATE := 22050
const BASE := 220.0
const TRACK_DIR := "res://assets/audio/music/%s.ogg"
const AMB_DIR := "res://assets/audio/amb/%s.ogg"
const XFADE := 2.4            # seconds: a region change crossfades this long
const XFADE_BOSS := 0.9       # a boss fight cuts in faster
const TAIL := 4.5             # a track starts over this many seconds before its end
const RESUME_SEC := 150.0     # a track left less than this long ago resumes where it was
const MUSIC_DB := -6.0        # the Music bus at "Normal" volume
const LEVEL_DB := [-8.0, 0.0, 4.0]     # the "Music volume" setting: quiet, normal, loud
## a track's level against the others (they are loudness-matched by tools/build_audio.py)
const TRACK_DB := {"boss": 0.5, "dungeon": 0.0, "shrine": 0.0}
## (v0.23) regions without a track of their own borrow one: Damavand's ash slopes the Peaks', the Cave of Chains the
## crypt's, Zahhak the Dragon's battle theme
const TRACK_ALIAS := {
	# (v0.31) the second take of the battle theme for the bosses of chapters 2 and 3 (the first take stays with chapter 1)
	"boss_arbiter": "boss_b", "boss_glaciertitan": "boss_b", "boss_ignarok": "boss_b", "boss_anvilward": "boss_b", "boss_kondrow": "boss_b", "alborz": "peaks", "alborz_eyrie": "peaks"}
const AMB_KEYS := ["rain", "wind", "crickets", "birds", "fire", "cave", "water"]
## each loop's level: the recorded loops, and the synthesised ones (rain; wind and crickets when their files are missing)
const AMB_DB_FILE := {"wind": -3.0, "crickets": -4.0, "birds": -2.0, "fire": -2.0, "cave": 0.0, "water": -3.0}
const AMB_DB_SYNTH := {"rain": -6.0, "wind": -6.0, "crickets": -12.0}
const PATTERNS := {
	"title": {"scale": [262, 294, 330, 392, 440], "bass": [131, 98, 110, 131], "tempo": 0.62, "wave": "tri"},
	"village": {"scale": [262, 294, 330, 392, 440], "bass": [131, 98, 110, 131], "tempo": 0.54, "wave": "tri"},
	"forest": {"scale": [220, 247, 277, 330, 370], "bass": [110, 83, 93, 110], "tempo": 0.66, "wave": "tri"},
	"dungeon": {"scale": [196, 220, 233, 277, 311], "bass": [98, 73, 78, 98], "tempo": 0.78, "wave": "sine"},
	"peaks": {"scale": [147, 165, 175, 196, 220], "bass": [74, 58, 62, 74], "tempo": 0.56, "wave": "saw"},
	"shadowfen": {"scale": [175, 196, 220, 262, 311], "bass": [58, 68, 49, 55], "tempo": 0.62, "wave": "sine"},
	"sanctum": {"scale": [262, 311, 370, 440, 523], "bass": [65, 52, 58, 49], "tempo": 0.78, "wave": "tri"},
	"emberforge": {"scale": [147, 175, 196, 233, 262], "bass": [73, 55, 62, 49], "tempo": 0.6, "wave": "saw"},
	"camp": {"scale": [196, 220, 247, 294, 330], "bass": [49, 55, 44, 49], "tempo": 0.7, "wave": "tri"},
	"trial": {"scale": [196, 220, 262, 294, 330], "bass": [98, 87, 73, 82], "tempo": 0.6, "wave": "tri"},
	"shrine": {"scale": [262, 330, 392, 494, 587], "bass": [131, 110, 98, 110], "tempo": 0.8, "wave": "sine"},
	"boss": {"scale": [147, 156, 196, 208, 233, 294], "bass": [73, 73, 69, 65], "tempo": 0.3, "wave": "saw", "drum": true},
}

var notes := {}               # "sine" | "tri" | "saw" | "bass" | "drum" -> AudioStreamWAV
var loops := {}               # synthesised loops: "rain" | "wind" | "crickets" -> AudioStreamWAV (looping)
var voices: Array[AudioStreamPlayer] = []      # the generative tune's sampler
var decks: Array[AudioStreamPlayer] = []       # three players for the recorded tracks (crossfades)
var amb := {}                 # loop name -> AudioStreamPlayer
var amb_file := {}            # loop name -> true when it plays a recorded loop
var _amb_want := {}
var _next := 0
var region := ""
var boss := false
var boss_type := ""
var _turn := {}               # (v0.31) a track with a second take (<key>_2.ogg) plays the two in turn, one per loop
var moment := ""             # (v0.31) a moment with its own track over everything else: "ending" (the chapter's end card)
var step := 0
var _t := 0.0
var _ready_samples := false
var _task := -1
var playing := ""             # the recorded track now playing ("" = none: silence or the generative tune)
var _active := -1             # its deck
var _amp: Array[float] = [0.0, 0.0, 0.0]
var _want: Array[float] = [0.0, 0.0, 0.0]
var _rate: Array[float] = [1.0, 1.0, 1.0]
var _tracks := {}             # key -> AudioStream (or null when there is no file), loaded on first use
var _resume := {}             # key -> [position, time left]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bus("Music", MUSIC_DB, false, "Master")
	_bus("MusicSynth", 0.0, true, "Music")
	_bus("Ambience", -8.0, false, "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master")
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "MusicSynth"
		add_child(p)
		voices.append(p)
	for i in 3:
		var d := AudioStreamPlayer.new()
		d.bus = "Music"
		d.volume_db = -80.0
		add_child(d)
		decks.append(d)
	for k in AMB_KEYS:
		var a := AudioStreamPlayer.new()
		a.bus = "Ambience"
		a.volume_db = -60.0
		add_child(a)
		amb[k] = a
		_amb_want[k] = false
		if k != "rain" and ResourceLoader.exists(AMB_DIR % k):
			var s = load(AMB_DIR % k)
			if s is AudioStreamOggVorbis:
				s.loop = true
				a.stream = s
				amb_file[k] = true
	apply_volume()
	# synthesise in the background: no hitch at start-up
	_task = WorkerThreadPool.add_task(_synth_all)

## quitting while the samples are still being made (the first ~0.1 s) crashed the engine at exit: the worker thread wrote
## into dictionaries that were being freed. Wait for it (v0.19).
func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1

func _bus(bus_name: String, db: float, reverb: bool, send: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	var i := AudioServer.bus_count
	AudioServer.add_bus(i)
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, send)
	AudioServer.set_bus_volume_db(i, db)
	if reverb:
		var r := AudioEffectReverb.new()
		r.room_size = 0.72
		r.damping = 0.55
		r.spread = 0.8
		r.wet = 0.32
		r.dry = 0.85
		AudioServer.add_bus_effect(i, r)

func apply_volume() -> void:
	var i := AudioServer.get_bus_index("Music")
	if i >= 0:
		AudioServer.set_bus_volume_db(i, MUSIC_DB + float(LEVEL_DB[clamp(int(Game.settings.get("mvol", 1)), 0, LEVEL_DB.size() - 1)]))

func on() -> bool:
	return bool(Game.settings.get("music", true)) and bool(Game.settings.get("sound", true))

## the region's music (map key, or "title")
func play_region(key: String) -> void:
	if key == region:
		return
	region = key
	step = 0
	_t = 0.0

## a boss fight on or off; a boss with its own track (assets/audio/music/boss_<type>.ogg, v0.19: the Dragon of Kashaf) plays it
func set_boss(b: bool, type := "") -> void:
	if b == boss and (not b or type == boss_type):
		return
	boss = b
	boss_type = type if b else ""
	step = 0
	_t = 0.0

## (v0.31) a moment's own track ("ending"), or "" to go back to the region's or the boss's
func set_moment(k: String) -> void:
	if k == moment:
		return
	moment = k
	step = 0
	_t = 0.0

## an ambience loop on or off (fades)
func ambience(k: String, want: bool) -> void:
	if _amb_want.has(k):
		_amb_want[k] = want

## the track key for what is happening now: the boss theme, the shrine theme, or the region's own
func track_key() -> String:
	if moment != "" and has_track(moment):
		return moment
	if boss:
		return "boss_" + boss_type if boss_type != "" and has_track("boss_" + boss_type) else "boss"
	if region.begins_with("shrine_"):
		return "shrine"
	return region

func has_track(k: String) -> bool:
	return _track(k) != null

func _track(k: String) -> AudioStream:
	if k == "":
		return null
	if not _tracks.has(k):
		var src: String = TRACK_ALIAS.get(k, k)
		var s = load(TRACK_DIR % src) if ResourceLoader.exists(TRACK_DIR % src) else null
		if s is AudioStreamOggVorbis:
			s.loop = false          # the decks loop it themselves, with a crossfade
		_tracks[k] = s if s is AudioStream else null
	return _tracks[k]

func _process(dt: float) -> void:
	var muted: bool = not bool(Game.settings.get("sound", true))
	_ambience(dt, muted)
	_decks(dt)
	if not _ready_samples:
		if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
			WorkerThreadPool.wait_for_task_completion(_task)
			_task = -1
			_ready_samples = true
			for k in loops:
				if not amb_file.has(k):
					amb[k].stream = loops[k]
		return
	var k := track_key() if on() and region != "" else ""
	if k == "" or has_track(k):
		return
	_tune(dt, k)

# ---------------------------------------------------------------- recorded tracks
func _decks(dt: float) -> void:
	for k in _resume.keys():
		_resume[k][1] = float(_resume[k][1]) - dt
		if float(_resume[k][1]) <= 0.0:
			_resume.erase(k)
	var want := track_key() if on() and region != "" else ""
	if want != "" and not has_track(want):
		want = ""
	if want != playing:
		var fade := XFADE_BOSS if want.begins_with("boss") or playing.begins_with("boss") and want == "" else XFADE
		_leave(fade)
		if want != "":
			var from := 0.0
			if _resume.has(want):
				from = float(_resume[want][0])
				_resume.erase(want)
			_start(want, from, fade)
	elif playing != "":
		var p := decks[_active]
		var ln: float = p.stream.get_length() if p.stream else 0.0
		if not p.playing or (ln > TAIL * 3.0 and p.get_playback_position() > ln - TAIL):
			if has_track(playing + "_2"):
				_turn[playing] = not bool(_turn.get(playing, false))     # (v0.31) the other take this time
			_start(playing, 0.0, TAIL * 0.8)        # start over, crossfading into itself
	for i in decks.size():
		_amp[i] = move_toward(_amp[i], _want[i], dt / max(0.05, _rate[i]))
		var d := decks[i]
		# equal-power fades: the sum of two crossfading tracks keeps its loudness
		d.volume_db = linear_to_db(max(0.0001, sin(_amp[i] * PI * 0.5))) + float(TRACK_DB.get(_deck_key(d), 0.0))
		if _amp[i] <= 0.0 and _want[i] <= 0.0 and d.playing:
			d.stop()

func _deck_key(d: AudioStreamPlayer) -> String:
	return str(d.get_meta("key", ""))

## (v0.31) the take of a track to play now: its second take (<key>_2) on every other loop, if it has one
func _take(k: String) -> AudioStream:
	if bool(_turn.get(k, false)) and has_track(k + "_2"):
		return _track(k + "_2")
	return _track(k)

## fade out what plays now, and remember where it was
func _leave(fade: float) -> void:
	if playing != "" and _active >= 0:
		var d := decks[_active]
		if d.playing and not playing.begins_with("boss"):
			var ln: float = d.stream.get_length() if d.stream else 0.0
			var pos := d.get_playback_position()
			if pos < ln - TAIL - 6.0:
				_resume[playing] = [pos, RESUME_SEC]
		_want[_active] = 0.0
		_rate[_active] = fade
	playing = ""
	_active = -1

func _start(k: String, from: float, fade: float) -> void:
	# the quietest deck that is not the one playing
	var best := -1
	for i in decks.size():
		if i != _active and (best < 0 or _amp[i] < _amp[best]):
			best = i
	if _active >= 0:
		_want[_active] = 0.0
		_rate[_active] = fade
	var d := decks[best]
	d.stop()
	d.stream = _take(k)
	d.set_meta("key", k)
	_amp[best] = 0.0
	_want[best] = 1.0
	_rate[best] = fade
	d.volume_db = -80.0
	d.play(from)
	_active = best
	playing = k

# ---------------------------------------------------------------- ambience
func _ambience(dt: float, muted: bool) -> void:
	for k in amb:
		var a: AudioStreamPlayer = amb[k]
		if a.stream == null:
			continue
		var want: bool = _amb_want[k] and not muted
		var lvl: float = float(AMB_DB_FILE.get(k, -4.0)) if amb_file.has(k) else float(AMB_DB_SYNTH.get(k, -6.0))
		var target := lvl if want else -60.0
		a.volume_db = move_toward(a.volume_db, target, dt * (24.0 if want else 30.0))
		if want and not a.playing:
			a.volume_db = min(a.volume_db, -40.0)
			a.play(randf() * max(0.0, a.stream.get_length() - 1.0) if amb_file.has(k) else 0.0)
		elif not want and a.playing and a.volume_db <= -59.0:
			a.stop()

# ---------------------------------------------------------------- the generative tune (fallback)
func _tune(dt: float, k: String) -> void:
	var pat: Dictionary = PATTERNS.get(k, PATTERNS["village"])
	var tempo: float = pat["tempo"]
	_t += dt
	if _t < tempo:
		return
	_t -= tempo
	var s := step
	step += 1
	var bass: Array = pat["bass"]
	if pat.get("drum", false):
		if s % 2 == 0:
			_play("drum", 1.0 if s % 4 == 0 else 1.25, -8.0 if s % 4 == 0 else -13.0)
		if s % 4 == 0:
			_play("bass", float(bass[(s / 4) % bass.size()]) / (BASE * 0.5), -7.0)
	elif s % 4 == 0:
		_play("bass", float(bass[(s / 4) % bass.size()]) / (BASE * 0.5), -9.0)
	if randf() < (0.62 if boss else 0.55):
		var sc: Array = pat["scale"]
		var f: float = float(sc[randi() % sc.size()]) * (2.0 if randf() < 0.18 else 1.0)
		_play(str(pat["wave"]), f / BASE, -13.0 if pat["wave"] != "saw" else -16.0)

func _play(n: String, pitch: float, db: float) -> void:
	if not notes.has(n):
		return
	var p := voices[_next]
	_next = (_next + 1) % voices.size()
	p.stream = notes[n]
	p.pitch_scale = clamp(pitch, 0.25, 4.0)
	p.volume_db = db
	p.play()

# ---------------------------------------------------------------- synthesis (worker thread)
func _synth_all() -> void:
	notes["sine"] = _note("sine", BASE, 1.9, 0.02)
	notes["tri"] = _note("tri", BASE, 1.9, 0.02)
	notes["saw"] = _note("saw", BASE, 1.6, 0.015)
	notes["bass"] = _note("sine", BASE * 0.5, 2.6, 0.03)
	notes["drum"] = _drum()
	loops["rain"] = _noise_loop(2.5, 0.35, 0.0)
	loops["wind"] = _noise_loop(4.0, 0.06, 0.5)
	loops["crickets"] = _crickets()

static func _wav(buf: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clamp(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		# loop_end is the LAST frame played, not one past it: Godot's mixer reads frame loop_end itself.
		# loop_end = size read one frame past the buffer — harmless on a PC, but on Android (Scudo puts big blocks
		# right before a guard page) it crashed the audio thread when the cricket loop wrapped (v0.16.1).
		w.loop_end = buf.size() - 1
	return w

## a soft note: gentle attack, exponential fade; the saw is low-passed so it does not buzz
static func _note(wave: String, f: float, dur: float, attack: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		ph = fmod(ph + f / RATE, 1.0)
		var s := 0.0
		match wave:
			"sine": s = sin(ph * TAU)
			"tri": s = 4.0 * abs(ph - 0.5) - 1.0
			_:
				s = 2.0 * ph - 1.0
		lp += (s - lp) * 0.18
		if wave == "saw":
			s = lp
		var env: float = min(1.0, t / attack) * exp(-t * 2.6 / dur * 2.0)
		if t > dur - 0.05:
			env *= (dur - t) / 0.05
		buf[i] = s * env * 0.55
	return _wav(buf)

static func _drum() -> AudioStreamWAV:
	var n := int(0.32 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f: float = 110.0 * exp(-t * 9.0) + 42.0
		ph += f / RATE
		var env: float = exp(-t * 11.0)
		buf[i] = (sin(ph * TAU) * 0.9 + (randf() * 2.0 - 1.0) * 0.12 * exp(-t * 40.0)) * env * 0.8
	return _wav(buf)

## seamless filtered noise: rain (bright, with drops) or wind (dark, swelling)
static func _noise_loop(dur: float, bright: float, swell: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var r := randf() * 2.0 - 1.0
		lp += (r - lp) * bright
		lp2 += (lp - lp2) * bright
		var t := float(i) / n
		var amp := 1.0
		if swell > 0.0:
			amp = 1.0 - swell + swell * (0.5 + 0.5 * sin(t * TAU))
		var s: float = lp2 * 2.2 * amp
		if bright > 0.2 and randf() < 0.0009:
			s += (randf() - 0.5) * 0.9           # a drop
		buf[i] = s * 0.6
	# crossfade the ends so the loop has no click
	var x := int(0.12 * RATE)
	for i in x:
		var k := float(i) / x
		buf[i] = buf[i] * k + buf[n - x + i] * (1.0 - k)
	return _wav(buf.slice(0, n - x), true)

static func _crickets() -> AudioStreamWAV:
	var dur := 2.4
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var starts := [0.1, 0.18, 0.26, 1.2, 1.28, 1.36, 1.44]
	for st in starts:
		var a := int(float(st) * RATE)
		var ln := int(0.05 * RATE)
		for i in ln:
			if a + i >= n:
				break
			var t := float(i) / RATE
			var env: float = sin(PI * float(i) / ln)
			buf[a + i] += sin(t * TAU * 4300.0) * env * 0.35 * (0.6 + 0.4 * sin(t * TAU * 60.0))
	return _wav(buf, true)
