extends Node

const HERO = preload("res://visual3d/hero.scn")
var hero_view = preload("res://visual3d/actor.gd")
var pool_view = preload("res://visual3d/pool.gd")

func _ready():
 get_tree().node_added.connect(_added)

func _added(n):
 if n is Button and n.name=="NewGame":call_deferred("_quick_button",weakref(n))
 var script = n.get_script()
 if script == null: return
 if script.resource_path=="res://scripts/boss.gd":call_deferred("_boss_visual",weakref(n))
 if script.resource_path == "res://scripts/world.gd":
  call_deferred("_forest", weakref(n))
  call_deferred("_crypt", weakref(n))
  call_deferred("_relic", weakref(n))
 if script.resource_path == "res://scripts/player.gd":
  call_deferred("_dress", weakref(n))
 elif script.resource_path == "res://scripts/fx/fountain.gd":
  call_deferred("_fountain", weakref(n))

func _dress(ref):
 var p = ref.get_ref()
 if not is_instance_valid(p) or p.is_queued_for_deletion() or get_node("/root/Game").cls != "warrior": return
 var view = hero_view.new()
 view.name = "Pahlavan3D"
 view.figure = HERO.instantiate()
 p.add_child(view)

func _fountain(ref):
 var f = ref.get_ref()
 if not is_instance_valid(f) or f.is_queued_for_deletion(): return
 var pool = pool_view.new()
 pool.name = "ZabolSpring3D"
 f.add_child(pool)

func _forest(ref):
 var world=ref.get_ref()
 if not is_instance_valid(world) or world.is_queued_for_deletion() or world.key!="forest":return
 if not is_instance_valid(world.ysort):return
 if get_node("/root/Game").rehearsal and get_node("/root/Game").practice_stage=="ForestQuickStart":
  for enemy in get_tree().get_nodes_in_group("enemies"):
   if enemy.world==world and enemy.type=="slime":enemy.queue_free()
 var wheel=preload("res://visual3d/wheel.gd").new()
 wheel.name="SplinteredWheel"
 wheel.position=Vector2(739,578)
 world.ysort.add_child(wheel)
 var ambush=preload("res://visual3d/ambush.gd").new()
 ambush.name="AshAmbush"
 world.ysort.add_child(ambush)

func _crypt(ref):
 var w=ref.get_ref()
 if not is_instance_valid(w) or w.is_queued_for_deletion() or w.key!="dungeon":return
 var echo=preload("res://visual3d/echo.gd").new()
 echo.name="EmberEcho"
 echo.position=Vector2(426,654)
 w.ysort.add_child(echo)

func _quick_button(ref):
 var source=ref.get_ref()
 if not is_instance_valid(source) or source.is_queued_for_deletion():return
 var game=get_node("/root/Game")
 if game.rehearsal and game.has_save():game.load_game()
 game.rehearsal=false
 game.practice_stage=""
 var fa=game.lang=="fa"
 var menu=VBoxContainer.new()
 menu.name="PracticeMenu"
 source.add_child(menu)
 menu.top_level=true
 menu.layout_direction=Control.LAYOUT_DIRECTION_LTR
 var layout=func():
  if not is_instance_valid(menu) or not menu.is_inside_tree():return
  menu.size=Vector2(204,menu.get_combined_minimum_size().y)
  menu.position=Vector2(16,menu.get_viewport_rect().size.y-menu.size.y-12)
 menu.minimum_size_changed.connect(layout,CONNECT_DEFERRED)
 var viewport=menu.get_viewport()
 viewport.size_changed.connect(layout)
 menu.tree_exiting.connect(func():viewport.size_changed.disconnect(layout),CONNECT_ONE_SHOT)
 var toggle=Button.new()
 toggle.text="تمرین مرحله‌ها" if fa else "Practice stages"
 menu.add_child(toggle)
 var options=VBoxContainer.new()
 menu.add_child(options)
 options.hide()
 toggle.pressed.connect(func():
  options.visible=not options.visible
  toggle.text=("بستن تمرین‌ها" if fa else "Close practice") if options.visible else ("تمرین مرحله‌ها" if fa else "Practice stages")
  layout.call_deferred()
 )
 var classes=GridContainer.new()
 classes.columns=2
 classes.layout_direction=Control.LAYOUT_DIRECTION_RTL if fa else Control.LAYOUT_DIRECTION_LTR
 options.add_child(classes)
 var group=ButtonGroup.new()
 for id in game.table("CLASSES"):
  var role=Button.new()
  role.name=id
  role.text=game.hero_role(id)
  role.toggle_mode=true
  role.button_group=group
  role.button_pressed=id=="warrior"
  role.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  classes.add_child(role)
 for item in [
  ["ForestQuickStart","کاروان شکسته","Broken caravan"],
  ["CryptQuickStart","پژواک سرداب","Crypt echo"],
  ["DuelQuickStart","تمرین سپر ارژنگ","Arzhang shield practice"]
 ]:
  var entry=Button.new()
  entry.name=item[0]
  entry.text=item[1] if fa else item[2]
  options.add_child(entry)
  entry.pressed.connect(_start_practice.bind(entry,group),CONNECT_ONE_SHOT)

 layout.call_deferred()

func _start_practice(entry,group):
 get_node("/root/Game").practice_stage=String(entry.name)
 var selected=group.get_pressed_button()
 if not is_instance_valid(selected):return
 var hero_class=String(selected.name)
 if entry.name=="DuelQuickStart":
  _duel(entry,hero_class)
 else:
  _quick_start(entry,entry.name=="CryptQuickStart",hero_class)

func _quick_start(button,crypt,hero_class):
 get_node("/root/Game").rehearsal=true
 button.disabled=true
 var main=get_tree().current_scene
 main._on_start(hero_class,false)
 await get_tree().process_frame
 if not is_instance_valid(main) or not is_instance_valid(main.player):return
 if crypt:main.goto_map("dungeon",Vector2(426,715))
 else:main.goto_map("forest",Vector2(756,579))
 var hint_layer=CanvasLayer.new()
 main.add_child(hint_layer)
 hint_layer.layer=25
 var hint=Label.new()
 hint_layer.add_child(hint)
 hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
 hint.position.y=64
 hint.grow_horizontal=Control.GROW_DIRECTION_BOTH
 hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 hint.add_theme_constant_override("outline_size",5)
 hint.text="کنار اخگر بایست؛ ترتیب روشن شدن سنگ‌ها را به خاطر بسپار." if get_node("/root/Game").lang=="fa" else "Stand by the ember. Remember the order of the stones."
 if not crypt:hint.text="چرخ از درون شکسته است." if get_node("/root/Game").lang=="fa" else "The wheel split from within."
 await get_tree().create_timer(4.).timeout
 if is_instance_valid(hint_layer):hint_layer.queue_free()

func _boss_visual(ref):
 var b=ref.get_ref()
 if not is_instance_valid(b) or b.is_queued_for_deletion() or b.type!="boss":return
 var skin=preload("res://visual3d/div.gd").new()
 skin.name="Arzhang3D"
 b.add_child(skin)
 var director=preload("res://visual3d/ward_duel.gd").new()
 director.name="WardDuel"
 b.add_child(director)

func _duel(button,hero_class):
 var g=get_node("/root/Game")
 g.rehearsal=true
 button.disabled=true
 var m=get_tree().current_scene
 m._on_start(hero_class,false)
 await get_tree().process_frame
 if not is_instance_valid(m) or not is_instance_valid(m.player):return
 g.set_q(1,"active")
 g.set_quest_step("q1","boss_ready")
 m.goto_map("dungeon",Vector2(715,670))
 await get_tree().process_frame
 var boss=m.world.ysort.get_node_or_null("Enemy_boss")
 if boss and not boss.dead:
  boss.max_hp=minf(boss.max_hp,480.)
  boss.hp=boss.max_hp*.60
  boss._check_phase()

func _relic(ref):
 var world=ref.get_ref()
 if not is_instance_valid(world) or world.is_queued_for_deletion() or world.key not in ["village","dungeon"]:return
 var relic=preload("res://visual3d/return.gd").new()
 relic.name="ZabolKeepsake"
 relic.village=world.key=="village"
 relic.position=Vector2(430,309) if relic.village else Vector2(812,632)
 world.ysort.add_child(relic)
