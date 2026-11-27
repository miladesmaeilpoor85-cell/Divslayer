extends Node
## Sound effects (autoload "Sfx"). Since v0.17 most sounds are recorded CC0 samples from assets/audio/sfx/
## (Kenney's RPG / Impact / Interface / UI audio and jingles, and OpenGameArt packs — see assets/audio/CREDITS.md),
## each with a few variations played at random (never the same one twice in a row) with a little pitch jitter.
## The synthesised sounds of the HTML game stay: for the magic (nova, bolt, ice, poison, phase ...), the heartbeat,
## the kill pop, and as a fallback for any sound whose files are missing.
##   play("hit")            — a variation of "hit" (file) or the synthesised "hit"
##   step(map_key, quiet)   — one footstep on that map's ground (grass, stone or snow)

const RATE := 44100
const DIR := "res://assets/audio/sfx/"
const MAX_VARIATIONS := 12
## the sounds that have recorded variations (<name>_0.ogg, <name>_1.ogg ...)
const FILE_SOUNDS := ["swing", "swing2", "heavy", "hit", "crit", "hurt", "clank", "trap", "dodge", "coin", "door", "talk",
	"book", "equip", "latch", "chest", "ui", "error", "potion", "quest", "levelup", "victory", "defeat", "found", "roar",
	"growl", "die", "slime", "bug", "step_grass", "step_stone", "step_snow", "achieve"]
## the recorded files are peak-normalised (-1 dBFS): this sets each one against the synthesised sounds of the HTML game.
## Measured, not guessed (loudest 150 ms, see DEV_NOTES "Audio levels"): a recording plays about 3 dB above the synthesised
## sound it replaces — the music is fuller now too; the new sounds sit with their nearest neighbours
const GAIN := {"swing": -7.0, "swing2": -7.0, "heavy": -1.0, "hit": -4.5, "crit": -2.0, "hurt": -5.0, "clank": 0.0,
	"trap": 0.0, "dodge": -7.0, "coin": 0.0, "door": -1.0, "talk": -1.0, "book": -2.0, "equip": 0.0, "latch": 0.0,
	"chest": -2.0, "ui": -2.0, "error": -4.0, "potion": -4.0, "quest": -9.0, "levelup": -8.0, "victory": -8.0,
	"defeat": -9.0, "found": -10.0, "roar": -2.0, "growl": -6.0, "die": -7.0, "slime": -2.0, "bug": -3.0,
	"step_grass": -11.5, "step_stone": -12.5, "step_snow": -17.0, "achieve": -5.0}
## a heavier swing is the same swish played lower
const PITCH := {"heavy": 0.84, "roar": 0.92}
## sounds that also play their synthesised version under the recording, at this offset (dB): the glass clink of a potion
## keeps its rising shimmer, a heavy blow its low thump
const LAYER := {"potion": -2.0, "heavy": -6.0}
## names kept for old calls
const ALIAS := {"dash": "dodge"}
## a voice does not repeat within this many seconds (a pack of wolves noticing you growls once, not six times)
const COOLDOWN := {"growl": 0.6, "bug": 0.35, "slime": 0.3, "die": 0.15, "roar": 0.4, "found": 0.5, "levelup": 0.5,
	"quest": 0.25, "victory": 1.0, "defeat": 1.0, "coin": 0.05, "talk": 0.08, "achieve": 0.6}
## the ground underfoot, by map
const GROUND := {"village": "grass", "forest": "grass", "camp": "grass", "shadowfen": "grass", "peaks": "snow",
	"dungeon": "stone", "sanctum": "stone", "emberforge": "stone", "trial": "stone", "frostvale": "snow", "wyrmhollow": "stone",
	"damavand": "stone", "zahhakcave": "stone"}
## the bus volume for each "Sound volume" setting: quiet, normal, loud
const LEVEL_DB := [-8.0, 0.0, 4.0]

var streams := {}            # name -> synthesised AudioStreamWAV
var files := {}              # name -> Array of recorded AudioStreams
var players: Array[AudioStreamPlayer] = []
var step_player: AudioStreamPlayer
var next := 0
var muted := false
var _last := {}              # name -> index of the variation played last
var _last_t := {}            # name -> time (s) it was last played

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	muted = not bool(Game.settings.get("sound", true))
	_buses()
	for i in 14:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		players.append(p)
	step_player = AudioStreamPlayer.new()
	step_player.bus = "SFX"
	add_child(step_player)
	_build()
	_load_files()
	apply_volume()
	if Game.has_signal("item_found"):
		Game.item_found.connect(func(_t, _c): play("found"))

## the "SFX" bus (sound effects and, through Music's "Ambience" bus, the ambience) and a limiter on the master bus,
## so a pile of sounds at once never clips
func _buses() -> void:
	if AudioServer.get_bus_index("SFX") < 0:
		var i := AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, "SFX")
		AudioServer.set_bus_send(i, "Master")
	var has_lim := false
	for e in AudioServer.get_bus_effect_count(0):
		has_lim = has_lim or AudioServer.get_bus_effect(0, e) is AudioEffectHardLimiter
	if not has_lim:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -0.5
		AudioServer.add_bus_effect(0, lim)

func apply_volume() -> void:
	var i := AudioServer.get_bus_index("SFX")
	if i >= 0:
		AudioServer.set_bus_volume_db(i, float(LEVEL_DB[clamp(int(Game.settings.get("svol", 1)), 0, LEVEL_DB.size() - 1)]))

func _load_files() -> void:
	for n in FILE_SOUNDS:
		var arr: Array = []
		for i in MAX_VARIATIONS:
			var path := DIR + "%s_%d.ogg" % [n, i]
			if not ResourceLoader.exists(path):
				break
			var s = load(path)
			if s is AudioStream:
				arr.append(s)
		if not arr.is_empty():
			files[n] = arr

func has_sound(sound_name: String) -> bool:
	sound_name = ALIAS.get(sound_name, sound_name)
	return files.has(sound_name) or streams.has(sound_name)

func play(sound_name: String, vol_db := 0.0, pitch_jitter := 0.06) -> void:
	sound_name = ALIAS.get(sound_name, sound_name)
	if muted or not (files.has(sound_name) or streams.has(sound_name)):
		return
	var now := Time.get_ticks_msec() * 0.001
	if now - float(_last_t.get(sound_name, -9.0)) < float(COOLDOWN.get(sound_name, 0.02)):
		return
	_last_t[sound_name] = now
	var p := _voice()
	if files.has(sound_name):
		var arr: Array = files[sound_name]
		var k := randi() % arr.size()
		if arr.size() > 1 and k == int(_last.get(sound_name, -1)):
			k = (k + 1 + randi() % (arr.size() - 1)) % arr.size()
		_last[sound_name] = k
		p.stream = arr[k]
		p.volume_db = vol_db + float(GAIN.get(sound_name, -3.0))
		p.pitch_scale = float(PITCH.get(sound_name, 1.0)) * (1.0 + randf_range(-pitch_jitter, pitch_jitter))
		p.play()
		if LAYER.has(sound_name) and streams.has(sound_name):
			var q := _voice()
			q.stream = streams[sound_name]
			q.volume_db = vol_db + float(LAYER[sound_name])
			q.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			q.play()
		return
	p.stream = streams[sound_name]
	p.volume_db = vol_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()

## a free player, else the one that has played longest
func _voice() -> AudioStreamPlayer:
	for i in players.size():
		var p := players[(next + i) % players.size()]
		if not p.playing:
			next = (next + i + 1) % players.size()
			return p
	var q := players[next]
	next = (next + 1) % players.size()
	return q

## one footstep on the ground of this map (a sneaking hero treads softly)
func step(map_key: String, quiet := false) -> void:
	if muted:
		return
	var g: String = GROUND.get(map_key, "stone" if map_key.begins_with("shrine_") else "grass")
	var n := "step_" + g
	if not files.has(n):
		return
	var arr: Array = files[n]
	var k := randi() % arr.size()
	if arr.size() > 1 and k == int(_last.get(n, -1)):
		k = (k + 1) % arr.size()
	_last[n] = k
	step_player.stream = arr[k]
	step_player.volume_db = float(GAIN.get(n, -17.0)) - (7.0 if quiet else 0.0)
	step_player.pitch_scale = randf_range(0.92, 1.08)
	step_player.play()

# ---------------------------------------------------------------- synthesis
## one voice: frequency sweep f0->f1, wave = sine|square|saw|tri|noise, simple attack/decay envelope
func _voice_synth(buf: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, wave: String, vol: float, attack := 0.005) -> void:
	var n := int(dur * RATE)
	var off := int(start * RATE)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var k: float = float(i) / max(1, n - 1)
		var f: float = f0 * pow(f1 / f0, k) if f0 > 0.0 and f1 > 0.0 else f0
		phase += f / RATE
		var s := 0.0
		match wave:
			"sine": s = sin(phase * TAU)
			"square": s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			"saw": s = 2.0 * fmod(phase, 1.0) - 1.0
			"tri": s = 4.0 * abs(fmod(phase, 1.0) - 0.5) - 1.0
			"noise":
				var r: float = randf() * 2.0 - 1.0
				lp += (r - lp) * clamp(f / 8000.0, 0.02, 1.0)   # crude low-pass: f is the "brightness"
				s = lp * 2.0
		var env: float = min(1.0, t / attack) * pow(1.0 - k, 2.2)
		var idx := off + i
		if idx < buf.size():
			buf[idx] += s * vol * env

func _make(dur: float, parts: Array) -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	buf.resize(int(dur * RATE) + 8)
	for p in parts:
		_voice_synth(buf, p[0], p[1], p[2], p[3], p[4], p[5])
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clamp(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w

func _build() -> void:
	# [start, duration, f0, f1, wave, volume]
	streams["swing"] = _make(0.16, [[0, 0.15, 2200, 500, "noise", 0.55]])
	streams["heavy"] = _make(0.3, [[0, 0.28, 1400, 220, "noise", 0.7], [0, 0.22, 140, 60, "sine", 0.5]])
	streams["charge"] = _make(0.35, [[0, 0.34, 220, 660, "tri", 0.25]])
	streams["hit"] = _make(0.14, [[0, 0.12, 260, 90, "square", 0.35], [0, 0.08, 3000, 800, "noise", 0.4]])
	streams["crit"] = _make(0.22, [[0, 0.1, 900, 1400, "square", 0.25], [0.04, 0.16, 1400, 700, "tri", 0.3], [0, 0.1, 4000, 1000, "noise", 0.35]])
	streams["hurt"] = _make(0.25, [[0, 0.22, 300, 110, "saw", 0.4], [0, 0.1, 2000, 600, "noise", 0.3]])
	streams["kill"] = _make(0.4, [[0, 0.35, 500, 80, "square", 0.3], [0, 0.3, 1800, 300, "noise", 0.35]])
	streams["dodge"] = _make(0.2, [[0, 0.18, 600, 1600, "noise", 0.4]])
	streams["coin"] = _make(0.28, [[0, 0.09, 1320, 1320, "square", 0.22], [0.08, 0.18, 1760, 1760, "square", 0.22]])
	# the bright blip of coins flying to the hero (the recorded "coin" is a purse: too much for every coin)
	streams["coin_tick"] = streams["coin"]
	streams["potion"] = _make(0.4, [[0, 0.35, 400, 900, "sine", 0.4], [0.1, 0.25, 800, 1300, "sine", 0.25]])
	streams["levelup"] = _make(0.7, [[0, 0.16, 523, 523, "tri", 0.35], [0.14, 0.16, 659, 659, "tri", 0.35], [0.28, 0.16, 784, 784, "tri", 0.35], [0.42, 0.28, 1046, 1046, "tri", 0.4]])
	streams["talk"] = _make(0.08, [[0, 0.07, 700, 900, "square", 0.15]])
	streams["ui"] = _make(0.07, [[0, 0.06, 1000, 1200, "sine", 0.3]])
	streams["error"] = _make(0.22, [[0, 0.2, 180, 150, "square", 0.25]])
	streams["door"] = _make(0.45, [[0, 0.42, 300, 80, "noise", 0.5], [0, 0.3, 120, 70, "sine", 0.35]])
	streams["roar"] = _make(0.9, [[0, 0.85, 140, 60, "saw", 0.45], [0, 0.8, 700, 200, "noise", 0.35]])
	streams["quest"] = _make(0.8, [[0, 0.2, 392, 392, "tri", 0.3], [0.18, 0.2, 523, 523, "tri", 0.3], [0.36, 0.4, 784, 784, "tri", 0.35]])
	# v18 boss fights
	streams["nova"] = _make(0.6, [[0, 0.55, 90, 38, "sine", 0.7], [0, 0.45, 1600, 200, "noise", 0.55]])
	streams["trap"] = _make(0.3, [[0, 0.26, 120, 50, "sine", 0.6], [0, 0.18, 900, 200, "noise", 0.45]])
	streams["bolt"] = _make(0.3, [[0, 0.28, 1800, 300, "saw", 0.22], [0, 0.2, 5000, 1500, "noise", 0.25]])
	streams["tp"] = _make(0.4, [[0, 0.38, 300, 1500, "sine", 0.3], [0, 0.3, 3000, 6000, "noise", 0.2]])
	streams["ice"] = _make(0.35, [[0, 0.12, 6000, 3000, "noise", 0.45], [0.02, 0.3, 2200, 1500, "tri", 0.2], [0.06, 0.2, 3100, 2600, "tri", 0.15]])
	streams["poison"] = _make(0.4, [[0, 0.12, 300, 520, "sine", 0.3], [0.12, 0.12, 280, 480, "sine", 0.28], [0.24, 0.14, 260, 440, "sine", 0.26]])
	streams["phase"] = _make(1.1, [[0, 1.0, 55, 110, "saw", 0.4], [0, 0.9, 110, 220, "tri", 0.3], [0.1, 0.8, 800, 300, "noise", 0.3]])
	streams["whisper"] = _make(0.45, [[0, 0.42, 2500, 900, "noise", 0.3]])
	streams["stun"] = _make(0.5, [[0, 0.15, 1200, 900, "tri", 0.25], [0.12, 0.15, 1400, 1000, "tri", 0.22], [0.24, 0.2, 1600, 1100, "tri", 0.2]])
	streams["shield"] = _make(0.25, [[0, 0.22, 1500, 1300, "sine", 0.22], [0, 0.18, 2250, 1950, "sine", 0.12]])
	# v0.5: a second swing, metal on armour, a heartbeat at low health, the poof of a kill
	streams["swing2"] = _make(0.15, [[0, 0.14, 2800, 700, "noise", 0.5]])
	streams["clank"] = _make(0.3, [[0, 0.18, 1800, 1500, "square", 0.14], [0, 0.28, 2650, 2380, "tri", 0.2], [0, 0.06, 5200, 2000, "noise", 0.32]])
	streams["heart"] = _make(0.4, [[0, 0.12, 62, 44, "sine", 0.75], [0.2, 0.12, 56, 42, "sine", 0.55]])
	streams["poof"] = _make(0.3, [[0, 0.28, 900, 180, "noise", 0.4], [0, 0.12, 300, 120, "sine", 0.3]])
