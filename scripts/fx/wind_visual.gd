extends Node2D
## Lightweight procedural wind cues. No texture or generated artwork is required.

var host: Node2D


func setup(world: Node2D) -> void:
	host = world
	name = "WindVisual"
	z_index = -2
	queue_redraw()


func _process(_delta: float) -> void:
	if host != null and is_instance_valid(host) and not host.wind_zones.is_empty():
		queue_redraw()


func _draw() -> void:
	if host == null or not is_instance_valid(host):
		return
	var clock := float(Time.get_ticks_msec()) * 0.001
	for zone in host.wind_zones:
		var area: Rect2 = zone["rect"]
		var controller = zone["controller"]
		var direction: Vector2 = controller.direction
		var active: bool = controller.is_active()
		var warning: bool = controller.phase == 0
		if active or warning:
			var count := 16 if active else 9
			for i in count:
				var x := fposmod(float(i) * 83.0 + clock * (controller.drift_speed * (2.8 if active else 1.0)), maxf(1.0, area.size.x))
				var y := fposmod(float(i) * 57.0 + clock * (11.0 if active else 3.0), maxf(1.0, area.size.y))
				var from := area.position + Vector2(x, y)
				var length := 25.0 if active else 14.0
				var col := Color(0.74, 0.84, 0.92, 0.24) if active else Color(1.0, 0.82, 0.55, 0.34)
				draw_line(from, from + direction * length, col, 1.4 if active else 1.8, true)
		for shelter in zone["shelters"]:
			var safe: Rect2 = shelter
			draw_rect(safe, Color(0.92, 0.78, 0.49, 0.045), true)
			draw_rect(safe, Color(0.92, 0.78, 0.49, 0.18), false, 1.2, true)
