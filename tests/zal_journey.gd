extends "res://tests/playtest.gd"
## Fresh Persian campaign, driven through touch. Navigation uses positions of visible
## labels, character art and the quest compass; this is not pixel-only perception.
## Full world state is captured as diagnostic evidence at the end.
var touch_trace: FileAccess
var started_frame := 0
var report := {"result":"running", "milestones":[], "actions":[], "screens":[]}
var can_talk := false
var claimed := false
var returned_to_zal := false
var memorial_goal := true
var rewarded := false
var next_heal := 0
var last_objective := ""
var course := Vector2.ZERO
var last_position := Vector2.ZERO
var stalled := 0
var side_steps := 0

# Keep exact player inputs separately from the human-readable checkpoint log.
func touch(idx: int, pos: Vector2, down: bool) -> void:
	if touch_trace:
		var event := {"frame": Engine.get_process_frames() - started_frame, "finger": idx,
			"event": "down" if down else "up", "x": pos.x, "y": pos.y}
		touch_trace.store_line(JSON.stringify(event))
	super.touch(idx, pos, down)

func drag_ev(idx: int, pos: Vector2, relative: Vector2) -> void:
	if touch_trace:
		var event := {"frame": Engine.get_process_frames() - started_frame, "finger": idx,
			"event": "drag", "x": pos.x, "y": pos.y, "dx": relative.x, "dy": relative.y}
		touch_trace.store_line(JSON.stringify(event))
	super.drag_ev(idx, pos, relative)

func record(action: String) -> void:
	report.actions.append({"frame":Engine.get_process_frames()-started_frame,"action":action})
	_log(action)

func evidence(stage: String) -> void:
	report.milestones.append(stage)
	report.screens.append({"stage":stage,"visible":_texts()})
	if DisplayServer.get_name() != "headless":
		await shot("stage_%02d" % report.milestones.size())

func finish_journey(ok: bool, reason: String) -> void:
	await stick(Vector2.ZERO)
	await evidence("end")
	report.result = "passed" if ok else "blocked"
	report.reason = reason
	report.expected="Claim the shield pieces, return and give them to Zal." if memorial_goal else "Return to Zal and collect his chapter reward."
	if is_instance_valid(main.player):
		report.diagnostics = state()
	var file := FileAccess.open(out.path_join("journey.json"),FileAccess.WRITE)
	if not file:
		printerr("Could not write journey report: ", out)
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	touch_trace.close()
	_log("%s: %s" % [report.result,reason])
	get_tree().quit(0 if ok else 1)

func tap_choice(label: String) -> bool:
	var button := find_text(label)
	if not button or not (button is Button) or button.disabled:
		return false
	var point := button.get_global_transform_with_canvas() * (button.size / 2)
	if not get_viewport_rect().has_point(point):
		return false
	record("tap " + label)
	await tap(_win(point))
	await wait(0.4)
	return true

func get_viewport_rect() -> Rect2:
	return get_viewport().get_visible_rect()

func bearing(labels: Array) -> Vector2:
	can_talk=false
	var origin: Vector2 = main.player.get_global_transform_with_canvas().origin
	var best := INF
	var direction := Vector2.ZERO
	for plate in main.world.find_children("NamePlate","Label",true,false):
		if plate.text not in labels or not plate.is_visible_in_tree():continue
		var center: Vector2 = plate.get_global_transform_with_canvas() * (plate.size / 2)
		if not get_viewport_rect().has_point(center):continue
		var prompt=plate.get_parent().get_node_or_null("TalkHint")
		if prompt and prompt.is_visible_in_tree():can_talk=true
		var delta: Vector2 = center + Vector2.DOWN * 55 * plate.get_global_transform_with_canvas().get_scale().y - origin
		if delta.length()<38.0*absf(plate.get_global_transform_with_canvas().get_scale().y):can_talk=true
		if delta.length()<best:
			best=delta.length()
			direction=delta.normalized()
	if direction!=Vector2.ZERO:return direction
	var compass=main.world.find_child("Compass",true,false)
	if compass and compass.is_visible_in_tree():return Vector2.RIGHT.rotated(compass.global_rotation)
	return course

# Read projected, visible enemy artwork. Do not query HP, telegraph timers or quest targets.
func visible_opponent(boss_fight: bool) -> Dictionary:
	var feet: Vector2=main.player.get_global_transform_with_canvas().origin
	var reach: float=absf(main.player.get_global_transform_with_canvas().get_scale().x)
	var best={}
	var best_cost=INF
	for actor in main.world.ysort.get_children():
		if not String(actor.name).begins_with("Enemy_"):continue
		var art=actor.get_node_or_null("Arzhang3D")
		if not art:art=actor.get("anim")
		if not art or not art.is_visible_in_tree() or _alpha(art)<0.1:continue
		var center: Vector2=art.get_global_transform_with_canvas().origin
		if not get_viewport_rect().has_point(center):continue
		var offset: Vector2=center+Vector2.DOWN*18*reach-feet
		var distance=offset.length()/maxf(0.01,reach)
		if distance>(320 if boss_fight else 100):continue
		var cost:float=distance
		if boss_fight and "gravepillar" in String(actor.name):cost-=350
		if cost<best_cost:
			best_cost=cost
			best={"dir":offset.normalized(),"distance":distance}
	return best

func run(m: Node) -> void:
	main=m
	started_frame=Engine.get_process_frames()
	var requested_seed=int(_arg("--journey-seed","705"))
	seed(requested_seed)
	report.seed=requested_seed
	memorial_goal=ResourceLoader.exists("res://visual3d/return.gd")
	report.goal="memorial" if memorial_goal else "chapter_reward"
	report.display=DisplayServer.get_name()
	if DisplayServer.get_name()=="headless":get_tree().root.size=Vector2i(1600,720)
	main.show_menu()
	out=_arg("--out","user://zal-journey")
	DirAccess.make_dir_recursive_absolute(out.path_join("shots"))
	log_f=FileAccess.open(out.path_join("log.txt"),FileAccess.WRITE)
	touch_trace=FileAccess.open(out.path_join("touches.jsonl"), FileAccess.WRITE)
	if not log_f or not touch_trace:
		printerr("Cannot open journey evidence directory: ", out)
		get_tree().quit(2)
		return
	await frames(60)
	if Game.has_save():
		await finish_journey(false,"Use an empty tester profile to protect the existing save.")
		return
	for label in ["بازی تازه","آغاز ماجرا"]:
		if not await tap_choice(label):
			await finish_journey(false,"Expected visible new-game button: " + label)
			return
	await frames(90)
	if not is_instance_valid(main.player):
		await finish_journey(false,"New game did not enter the world.")
		return
	var labels: Array=[]
	var seen_objective := ""
	var quiet := 0
	for tick in 2200:
		if main.player.dead:
			await finish_journey(false,"Hero fell while following: " + last_objective)
			return
		var hud=main.hud
		if hud.quest_l.is_visible_in_tree():seen_objective=hud.quest_l.text
		if seen_objective!=last_objective:
			await evidence(seen_objective)
			last_objective=seen_objective
			quiet=0
			if "زال" in last_objective:labels=["زال","Zal"]
			elif "نشانه" in last_objective:labels=["کاروان شکسته","بیرق پاره","سنگِ خاکسترنشان"]
			elif "سنگ‌نوشته" in last_objective:labels=["سنگ‌نوشتهٔ مهرگاه"]
			else:labels=[]
		if hud.dialogue.visible:
			await stick(Vector2.ZERO)
			var readout=await dialog_all()
			record(readout)
			if returned_to_zal and not memorial_goal and hud.quest_l.text!=last_objective and "نزد زال برگرد" not in hud.quest_l.text:
				await finish_journey(true,"Returned to Zal, read his dialogue and advanced the objective.")
				return
			if hud.dialogue.visible and hud.dialogue.choosing():
				await finish_journey(false,"Unexpected dialogue choice; see visible options.")
				return
			continue
		if await tap_choice("برداشتن نشان"):
			claimed=true
			await evidence("نشان برداشته شد")
			continue
		if claimed and await tap_choice("بازگشت به زابل"):continue
		if claimed and await tap_choice("سپردن نشان به زال"):continue
		if claimed and await tap_choice("چراغ کاروان"):
			var response=find_text("چراغش را کنار چشمه")
			rewarded=response!=null and response.is_visible_in_tree()
			await finish_journey(rewarded,"Zal acknowledged the lantern." if rewarded else "No on-screen handoff confirmation.")
			return
		if get_tree().paused:
			if hud.intro.visible:
				await tap(_win(get_viewport_rect().get_center()))
				continue
			await finish_journey(false,"Unexpected modal; see visible controls.")
			return
		if stick_down and hud.pad.joy_id != 0:
			await stick(Vector2.ZERO)
		var delta_pos: Vector2=main.player.global_position-last_position
		last_position=main.player.global_position
		stalled=stalled+1 if delta_pos.length()<2 else 0
		var dir=bearing(labels)
		if dir==Vector2.ZERO:dir=Vector2.UP
		if stalled>=3 and side_steps==0:
			side_steps=5
			stalled=0
		if side_steps>0:
			dir=dir.rotated(PI/2)
			side_steps-=1
		else:course=dir
		if can_talk and hud.pad.buttons().has("talk"):
			await stick(Vector2.ZERO)
			if "نزد زال برگرد" in last_objective and labels.has("زال"):
				returned_to_zal=true
			record("touch interact")
			await press("talk")
			await frames(8)
			if hud.dialogue.visible:continue
		if hud.hp_bar.is_visible_in_tree() and hud.hp_bar.value<0.67 and tick>=next_heal:
			record("touch potion at " + hud.hp_bar.text)
			await press("potion")
			next_heal=tick+10
		var foe=visible_opponent(hud.boss_ui.showing())
		if not foe.is_empty():
			dir=foe.dir
			await stick(dir)
			record("touch attack")
			await press("attack",0.32)
			if tick%3==0 and hud.pad.buttons().has("skill1"):await press("skill1")
			if hud.boss_ui.showing() and tick%7==0:await press("dodge")
		else:
			await stick(dir)
		await frames(12)
		if tick%8==0:record("stick %s, objective %s" % [dir,last_objective])
		quiet+=1
		if quiet>=160:
			await finish_journey(false,"No visible objective progress after 160 steering attempts: " + last_objective)
			return
	await finish_journey(false,"Journey budget exhausted before the memorial handoff.")
