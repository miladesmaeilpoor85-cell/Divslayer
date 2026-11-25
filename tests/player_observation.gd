extends RefCounted

const PlayerVision = preload("res://tests/player_vision.gd")
## Reads only controls that are visible inside the rendered viewport.
## This adapter deliberately does not inspect Game state, world entities, quests, or enemy nodes.

static func capture(root: Node, viewport: Viewport) -> Dictionary:
	var visible_texts: Array[Dictionary] = []
	var visible_buttons: Array[Dictionary] = []
	var visible_panels: Array[String] = []
	var visible_meters: Dictionary = {}
	var visible_resources: Dictionary = {}
	if root == null or viewport == null:
		return {
			"captured_at_msec": Time.get_ticks_msec(),
			"texts": visible_texts,
			"buttons": visible_buttons,
			"panels": visible_panels,
			"meters": visible_meters,
			"resources": visible_resources,
			"vision": {"valid": false, "warnings": []}
		}
	_collect_visible(root, root, viewport, visible_texts, visible_buttons, visible_panels, visible_meters, visible_resources)
	return {
		"captured_at_msec": Time.get_ticks_msec(),
		"texts": visible_texts,
		"buttons": visible_buttons,
		"panels": visible_panels,
		"meters": visible_meters,
		"resources": visible_resources,
		"vision": PlayerVision.capture(viewport)
	}

static func _collect_visible(node: Node, root: Node, viewport: Viewport, texts: Array, buttons: Array, panels: Array, meters: Dictionary, resources: Dictionary) -> void:
	if node is Control:
		var control := node as Control
		if _is_visible_on_screen(control, viewport):
			var control_name := str(control.name)
			if control_name in ["HealthMeter", "StaminaMeter", "ManaMeter"] and control.has_method("get_value"):
				meters[control_name] = float(control.get("value"))
			elif control_name in ["HealthMeter", "StaminaMeter", "ManaMeter"] and control.get("value") != null:
				meters[control_name] = float(control.get("value"))
			if control_name == "PotionChip":
				var value_label := control.get_node_or_null("Value") as Label
				if value_label != null and value_label.is_visible_in_tree():
					resources["potions_text"] = value_label.text
			var lower_name := control_name.to_lower()
			if lower_name in ["dialogue", "shop", "death", "pause", "craft", "forge", "ending", "intro"]:
				if not panels.has(lower_name):
					panels.append(lower_name)
			var value := _control_text(control)
			if not value.is_empty():
				var kind := "button" if control is Button else "text"
				texts.append({
					"text": value,
					"kind": kind,
					"path": str(root.get_path_to(control))
				})
			if control is Button and not value.is_empty():
				var button := control as Button
				buttons.append({
					"text": value,
					"enabled": not button.disabled,
					"visible": true,
					"path": str(root.get_path_to(button)),
					"control": button
				})
	for child in node.get_children():
		_collect_visible(child, root, viewport, texts, buttons, panels, meters, resources)

static func _control_text(control: Control) -> String:
	if control is Button:
		return (control as Button).text.strip_edges()
	if control is Label:
		return (control as Label).text.strip_edges()
	if control is RichTextLabel:
		return (control as RichTextLabel).get_parsed_text().strip_edges().replace("\n", " / ")
	if control is LineEdit:
		return (control as LineEdit).text.strip_edges()
	return ""

static func _is_visible_on_screen(control: Control, viewport: Viewport) -> bool:
	if not control.is_visible_in_tree() or _effective_alpha(control) < 0.25:
		return false
	var transform := control.get_global_transform_with_canvas()
	var bounds := Rect2(transform * Vector2.ZERO, control.size * transform.get_scale())
	return viewport.get_visible_rect().intersects(bounds)

static func _effective_alpha(node: Node) -> float:
	var alpha := 1.0
	var current: Node = node
	while current != null:
		if current is CanvasItem:
			var item := current as CanvasItem
			alpha *= item.modulate.a * item.self_modulate.a
		current = current.get_parent()
	return alpha
