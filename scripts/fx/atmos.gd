extends CanvasLayer
## The air of each region and its weather (port of the HTML updateWeather / drawWeatherOverlay, plus
## ambient life the static ground images lack): rain over Zabol, fog in the Whispering Forest and the
## Shadowfen, ash storms on the Ashen Peaks, snow in the Crystal Sanctum; falling leaves, fireflies at dusk
## and night, dust motes in the crypt, rising embers near fire, spores over the bog, glints of ice.
## Particles live in world space (they stay put when the camera moves); fog banks drift across the map.
## A weather spell lasts 30–60 s, then the sky is rolled again (70% chance of the region's weather).

const Tex = preload("res://scripts/fx/tex.gd")

const WEATHER := {"village": "rain", "forest": "fog", "peaks": "ash", "shadowfen": "fog", "sanctum": "snow", "frostvale": "snow",
	"damavand": "ash"}
## ambient particle sets per region: names of the presets below
const AIR := {
	"village": ["leaves_few", "fireflies"], "forest": ["leaves", "fireflies", "pollen"], "camp": ["leaves_few", "fireflies"],
	"dungeon": ["motes"], "peaks": ["embers", "ash_flecks"], "shadowfen": ["spores", "fireflies"],
	"sanctum": ["glints"], "emberforge": ["embers", "heat"], "trial": ["motes", "embers_few"],
	"frostvale": ["glints"], "wyrmhollow": ["motes", "glints"],
	"damavand": ["embers", "ash_flecks"], "zahhakcave": ["motes", "embers_few"],
}

## (v0.17) the ambience loops under each region (Music.ambience): fire in the bandit camp and the forge, the drip
## and hum of the crypt and the sanctum, water in the bog; birds by day and crickets by night outdoors, wind on the
## peaks and in snow or ash storms, rain with the rain
const AMB_BASE := {"camp": ["fire"], "emberforge": ["fire"], "dungeon": ["cave"], "sanctum": ["cave"], "trial": ["cave"],
	"shadowfen": ["water"], "shrine_tides": ["water", "cave"], "wyrmhollow": ["cave"],
	"damavand": ["fire"], "zahhakcave": ["cave"]}
const AMB_BIRDS := ["village", "forest", "camp", "shadowfen"]
const AMB_CRICKETS := ["village", "forest", "camp", "shadowfen"]

var world: Node = null
var weather := ""
var timer := 0.0
var emitters := {}             # preset -> CPUParticles2D
var clouds: Array = []         # fog banks: Sprite2D
var haze: ColorRect            # ash storm tint / fog veil (screen space)
var fog_k := 0.0
var _night_state := -1
var forced := ""               # tests can force a weather
var calm := false              # the title screen: no weather
var wind_clock := 0.0           # slow phase for continuous, weather-aware gusts

func setup(w: Node) -> void:
	world = w
	name = "Atmos"
	layer = 2
	follow_viewport_enabled = true
	haze = ColorRect.new()
	haze.color = Color(0, 0, 0, 0)
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	haze.visible = false
	# the haze is screen space: put it on its own layer under the effects
	var hl := CanvasLayer.new()
	hl.layer = 2
	hl.name = "Haze"
	add_child(hl)
	hl.add_child(haze)
	haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sound()
	if not enabled():
		return
	for k in AIR.get(world.key, ["motes"] if world.key.begins_with("shrine_") else []):
		_preset(k)
	_roll(true)

func enabled() -> bool:
	return int(Game.settings.get("fx", 1)) >= 1

# ---------------------------------------------------------------- weather
func _roll(first := false) -> void:
	var want := ""
	if forced != "":
		want = forced
	elif calm:
		want = ""
	elif WEATHER.has(world.key) and randf() < 0.7:
		want = WEATHER[world.key]
	timer = randf_range(30.0, 60.0)
	if first and forced == "" and want != "" and randf() < 0.35:
		want = ""          # arriving: not always mid-storm
	set_weather(want)

func set_weather(w: String) -> void:
	weather = w
	for k in ["rain", "splash", "snow", "ash_storm"]:
		if emitters.has(k):
			emitters[k].emitting = false
	match w:
		"rain":
			_preset("rain").emitting = true
			_preset("splash").emitting = true
		"snow":
			_preset("snow").emitting = true
		"ash":
			_preset("ash_storm").emitting = true
	if w == "fog" and clouds.is_empty():
		_make_clouds()
	var lit = world.lighting
	if lit:
		lit.weather_dark = 0.06 if w == "rain" else (0.05 if w == "ash" else 0.0)
	sound()

func night() -> bool:
	var n: bool = Game.indoor(world.key) or Game.phase() >= 2 or Game.phase() == 0
	if world.lighting and world.lighting.forced_phase >= 0:
		n = world.lighting.forced_phase >= 2
	return n

## (v0.17) set the ambience loops for this map, the hour and the weather. It runs whatever the graphics setting
## (light graphics have no weather, so no rain or storm loops, but the region's own sounds stay)
func sound() -> void:
	var mu = get_node_or_null("/root/Music")
	if mu == null or world == null or not is_inside_tree() or world.is_queued_for_deletion():
		return
	var k: String = world.key
	var outdoor: bool = not Game.indoor(k)
	var n := night()
	var base: Array = AMB_BASE.get(k, ["cave"] if k.begins_with("shrine_") else [])
	for a in ["fire", "cave", "water"]:
		mu.ambience(a, a in base)
	mu.ambience("rain", weather == "rain")
	mu.ambience("wind", weather == "ash" or weather == "snow" or k == "peaks" or k == "frostvale")
	mu.ambience("birds", outdoor and not n and k in AMB_BIRDS and weather != "rain")
	mu.ambience("crickets", outdoor and n and k in AMB_CRICKETS and weather != "rain")

func _process(dt: float) -> void:
	if Engine.get_process_frames() % 60 == 0:
		sound()
	var on := enabled()
	if visible != on:
		visible = on
		for c in get_children():
			if c is CanvasLayer:
				c.visible = on
	if world == null or not on:
		return
	timer -= dt
	if timer <= 0.0:
		_roll()
	wind_clock += dt
	var gust := sin(wind_clock * 0.63) * 0.65 + sin(wind_clock * 1.37 + 0.8) * 0.35
	_apply_wind(gust)
	var vp := get_viewport()
	var vis := vp.get_visible_rect().size
	var inv := vp.get_canvas_transform().affine_inverse()
	var center: Vector2 = inv * (vis * 0.5)
	var half: Vector2 = vis * 0.5 / vp.get_canvas_transform().get_scale()
	for k in emitters:
		var e: CPUParticles2D = emitters[k]
		e.global_position = center + (Vector2(0, -half.y * 0.6) if k in ["rain", "snow"] else Vector2.ZERO)
		e.emission_rect_extents = half + Vector2(40, 40)
	# fireflies and other night life only from dusk to dawn (outdoors)
	var is_night := night()
	if int(is_night) != _night_state or Engine.get_process_frames() % 120 == 0:
		if int(is_night) != _night_state:
			sound()
		_night_state = int(is_night)
		if emitters.has("fireflies"):
			emitters["fireflies"].emitting = is_night
		if emitters.has("pollen"):
			emitters["pollen"].emitting = not is_night
	# fog banks drift with the wind and wrap around the view
	var want_fog := 1.0 if weather == "fog" else 0.0
	fog_k = move_toward(fog_k, want_fog, dt * 0.25)
	for c in clouds:
		c.position += Vector2(c.get_meta("v")) * dt + Vector2(gust * 3.0, gust * 0.8) * dt
		var rel: Vector2 = c.position - center
		var lim := half + Vector2(260, 200)
		if rel.x > lim.x:
			c.position.x -= lim.x * 2.0
		elif rel.x < -lim.x:
			c.position.x += lim.x * 2.0
		if rel.y > lim.y:
			c.position.y -= lim.y * 2.0
		elif rel.y < -lim.y:
			c.position.y += lim.y * 2.0
		c.modulate.a = fog_k * float(c.get_meta("a"))
		c.visible = fog_k > 0.01
	# screen veil: ash storm brown, fog grey
	var hc := Color(0, 0, 0, 0)
	if weather == "ash":
		hc = Color(0.47, 0.31, 0.16, 0.16)
	elif fog_k > 0.0:
		hc = Color(0.63, 0.63, 0.67, 0.09 * fog_k)
	haze.color = haze.color.lerp(hc, min(1.0, dt * 1.5))
	haze.visible = haze.color.a > 0.005

## Return a gentle horizontal force for the current weather and gust phase.
func _wind_force(weather_type: String, gust: float) -> float:
	var strength := 0.06
	match weather_type:
		"rain": strength = 0.32
		"snow": strength = 0.22
		"ash": strength = 0.55
		"fog": strength = 0.12
	return clampf(gust, -1.0, 1.0) * strength

## Keep each particle family readable while letting new particles follow the changing wind.
func wind_direction_for(preset: String, weather_type: String, gust: float) -> Vector2:
	var force := _wind_force(weather_type, gust)
	match preset:
		"rain": return Vector2(-0.22 + force * 0.9, 1.0).normalized()
		"snow": return Vector2(0.15 + force, 1.0).normalized()
		"ash_storm": return Vector2(1.0, 0.35 + force * 0.45).normalized()
		"leaves", "leaves_few": return Vector2(0.45 + force * 1.8, 1.0).normalized()
		"ash_flecks": return Vector2(0.60 + force * 1.8, 1.0).normalized()
		"embers", "embers_few", "heat": return Vector2(force * 1.5, -1.0).normalized()
		"spores": return Vector2(force * 0.9, -1.0).normalized()
		_: return Vector2(force * 0.35, -1.0).normalized()

func _apply_wind(gust: float) -> void:
	for k in emitters:
		var e: CPUParticles2D = emitters[k]
		if k in ["rain", "snow", "ash_storm", "leaves", "leaves_few", "ash_flecks", "embers", "embers_few", "heat", "spores", "motes", "glints", "fireflies", "pollen"]:
			e.direction = wind_direction_for(str(k), weather, gust)

func _make_clouds() -> void:
	var vp := get_viewport()
	var inv := vp.get_canvas_transform().affine_inverse()
	var vis := vp.get_visible_rect().size
	var center: Vector2 = inv * (vis * 0.5)
	for i in 6:
		var s := Sprite2D.new()
		s.texture = Tex.cloud()
		s.scale = Vector2.ONE * randf_range(3.2, 5.0)
		s.rotation = randf() * TAU
		s.position = center + Vector2(randf_range(-500, 500), randf_range(-300, 300))
		s.set_meta("v", Vector2(randf_range(8, 18), randf_range(-3, 3)))
		s.set_meta("a", randf_range(0.16, 0.26))
		s.modulate = Color(0.86, 0.88, 0.9, 0.0)
		add_child(s)
		clouds.append(s)

# ---------------------------------------------------------------- presets
func _preset(k: String) -> CPUParticles2D:
	if emitters.has(k):
		return emitters[k]
	var q: float = 1.0
	var e := CPUParticles2D.new()
	e.name = k
	e.local_coords = false
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	e.emission_rect_extents = Vector2(500, 300)
	e.texture = Tex.dot()
	e.color_ramp = Tex.pulse_ramp()
	e.gravity = Vector2.ZERO
	e.spread = 180.0
	e.direction = Vector2.UP
	var add := true
	match k:
		"rain":
			e.texture = Tex.rain()
			e.amount = int(150 * q)
			e.lifetime = 0.55
			e.direction = Vector2(-0.22, 1).normalized()
			e.spread = 2.0
			e.initial_velocity_min = 560.0
			e.initial_velocity_max = 680.0
			e.particle_flag_align_y = true
			e.scale_amount_min = 0.6
			e.scale_amount_max = 0.8
			e.color = Color(0.8, 0.88, 1.0, 0.8)
			e.color_ramp = Tex.fade_ramp(0.8)
			add = false
		"splash":
			e.texture = Tex.pip()
			e.amount = 26
			e.lifetime = 0.25
			e.initial_velocity_max = 0.0
			e.scale_amount_min = 0.12
			e.scale_amount_max = 0.3
			e.scale_amount_curve = Tex.curve([[0.0, 0.3], [1.0, 1.0]])
			e.color = Color(0.8, 0.88, 1.0, 0.45)
			e.color_ramp = Tex.fade_ramp()
			add = false
		"snow":
			e.amount = 80
			e.lifetime = 7.0
			e.direction = Vector2(0.15, 1).normalized()
			e.spread = 25.0
			e.initial_velocity_min = 22.0
			e.initial_velocity_max = 42.0
			e.scale_amount_min = 0.08
			e.scale_amount_max = 0.17
			e.color = Color(1, 1, 1, 0.85)
			e.color_ramp = Tex.fade_ramp(0.75)
			add = false
		"ash_storm":
			e.amount = 60
			e.lifetime = 3.0
			e.direction = Vector2(1, 0.35).normalized()
			e.spread = 18.0
			e.initial_velocity_min = 70.0
			e.initial_velocity_max = 130.0
			e.scale_amount_min = 0.05
			e.scale_amount_max = 0.11
			e.color = Color(1, 0.55, 0.24, 0.7)
		"fireflies":
			e.amount = 26
			e.lifetime = 4.5
			e.initial_velocity_min = 6.0
			e.initial_velocity_max = 18.0
			e.scale_amount_min = 0.16
			e.scale_amount_max = 0.24
			e.color = Color(0.9, 1.0, 0.5, 1.0)
			e.emitting = false
		"pollen":
			e.amount = 16
			e.lifetime = 5.0
			e.initial_velocity_min = 4.0
			e.initial_velocity_max = 10.0
			e.scale_amount_min = 0.04
			e.scale_amount_max = 0.07
			e.color = Color(1, 0.96, 0.75, 0.55)
		"leaves", "leaves_few":
			e.texture = Tex.leaf()
			e.amount = 14 if k == "leaves" else 6
			e.lifetime = 6.0
			e.direction = Vector2(0.45, 1).normalized()
			e.spread = 20.0
			e.initial_velocity_min = 14.0
			e.initial_velocity_max = 28.0
			e.angular_velocity_min = -90.0
			e.angular_velocity_max = 90.0
			e.angle_min = 0.0
			e.angle_max = 360.0
			e.scale_amount_min = 0.45
			e.scale_amount_max = 0.7
			var g := Gradient.new()
			g.set_color(0, Color(0.42, 0.62, 0.24))
			g.set_color(1, Color(0.78, 0.55, 0.22))
			g.add_point(0.5, Color(0.6, 0.66, 0.26))
			e.color_initial_ramp = g
			e.color_ramp = Tex.fade_ramp(0.7)
			add = false
		"motes":
			e.amount = 26
			e.lifetime = 7.0
			e.initial_velocity_min = 3.0
			e.initial_velocity_max = 9.0
			e.scale_amount_min = 0.04
			e.scale_amount_max = 0.08
			e.color = Color(0.95, 0.86, 0.7, 0.32)
		"embers", "embers_few":
			e.amount = 28 if k == "embers" else 10
			e.lifetime = 3.2
			e.direction = Vector2.UP
			e.spread = 35.0
			e.initial_velocity_min = 16.0
			e.initial_velocity_max = 45.0
			e.scale_amount_min = 0.05
			e.scale_amount_max = 0.1
			e.color = Color(1, 0.58, 0.22, 0.85)
		"ash_flecks":
			e.texture = Tex.pip()
			e.amount = 20
			e.lifetime = 5.0
			e.direction = Vector2(0.6, 1).normalized()
			e.spread = 25.0
			e.initial_velocity_min = 12.0
			e.initial_velocity_max = 26.0
			e.scale_amount_min = 0.1
			e.scale_amount_max = 0.18
			e.color = Color(0.3, 0.27, 0.26, 0.6)
			e.color_ramp = Tex.fade_ramp(0.6)
			add = false
		"heat":
			e.amount = 14
			e.lifetime = 2.0
			e.direction = Vector2.UP
			e.spread = 15.0
			e.initial_velocity_min = 40.0
			e.initial_velocity_max = 80.0
			e.texture = Tex.streak()
			e.particle_flag_align_y = true
			e.scale_amount_min = 0.16
			e.scale_amount_max = 0.26
			e.color = Color(1, 0.7, 0.3, 0.6)
		"spores":
			e.amount = 22
			e.lifetime = 5.5
			e.direction = Vector2.UP
			e.spread = 60.0
			e.initial_velocity_min = 5.0
			e.initial_velocity_max = 14.0
			e.scale_amount_min = 0.05
			e.scale_amount_max = 0.1
			e.color = Color(0.6, 1.0, 0.65, 0.6)
		"glints":
			e.amount = 26
			e.lifetime = 1.8
			e.initial_velocity_max = 4.0
			e.scale_amount_min = 0.05
			e.scale_amount_max = 0.11
			e.color = Color(0.78, 0.94, 1.0, 0.9)
	if add:
		e.material = Tex.add_material()
	if int(Game.settings.get("fx", 1)) == 0:
		e.amount = max(4, int(e.amount * 0.5))
	e.preprocess = e.lifetime * 0.6 if k not in ["rain", "splash"] else 0.3
	add_child(e)
	emitters[k] = e
	return e
