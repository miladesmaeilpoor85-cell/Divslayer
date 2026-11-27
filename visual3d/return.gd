extends Node2D
const KEY="arzhang_memorial"
var village=false
var game
var world
var boss_ref
var model
var style="?"
var panel=PanelContainer.new()
var body=Label.new()
var row=HBoxContainer.new()
var first=Button.new()
var second=Button.new()
var screen=""
var guide_to_spring=false
var choice=false
var mode=""
func words(fa,en):
 return fa if game.lang=="fa" else en
func _ready():
 world=get_parent().get_parent()
 game=get_node("/root/Game")
 var layer=CanvasLayer.new()
 layer.layer=36
 add_child(layer)
 layer.add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
 panel.offset_left=-157
 panel.offset_right=157
 panel.offset_top=60
 panel.offset_bottom=144
 var box=StyleBoxFlat.new()
 box.bg_color=Color("#251e21ef")
 box.border_color=Color("#bf985c")
 box.set_border_width_all(1)
 box.set_corner_radius_all(8)
 for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:box.set_content_margin(side,6)
 panel.add_theme_stylebox_override("panel",box)
 var lines=VBoxContainer.new()
 panel.add_child(lines)
 lines.add_child(body)
 body.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 body.add_theme_font_size_override("font_size",14)
 lines.add_child(row)
 row.alignment=BoxContainer.ALIGNMENT_CENTER
 row.add_child(first)
 row.add_child(second)
 for btn in [first,second]:
  btn.custom_minimum_size=Vector2(112,38)
  btn.add_theme_font_size_override("font_size",14)
 first.pressed.connect(act.bind(0))
 second.pressed.connect(act.bind(1))
 panel.visible=false
func progress():
 return str(game.state.get(KEY,""))
func _process(_dt):
 var main=get_tree().current_scene
 if not main or main.get("world")!=world or not is_instance_valid(main.get("player")):
  panel.hide()
  return
 if not game.is_defeated("boss"):
  if not village:
   if not is_instance_valid(boss_ref):boss_ref=world.ysort.get_node_or_null("Enemy_boss")
   if is_instance_valid(boss_ref):position=boss_ref.position
  panel.hide()
  return
 var p=progress()
 var delivered=p in ["lantern","crown"]
 var want=""
 if delivered and village:
  want=p
  position=Vector2(492,443)
 elif not village and p=="":want="shard"
 if want!=style:
  style=want
  if is_instance_valid(model):model.queue_free()
  if want!="":
   model=preload("res://visual3d/token.gd").new()
   model.form=want
   add_child(model)
 var near=global_position.distance_to(main.player.global_position)<(105 if not village else 67)
 if delivered and village and guide_to_spring and not main.player.dead:
  if not near:
   body.text=words("یادمان را کنار چشمه ببین.","Visit the memorial by the spring.")
   first.hide()
   second.hide()
   panel.show()
   return
  guide_to_spring=false
  screen=""
 if not near or main.player.dead:
  panel.hide()
  choice=false
  return
 mode=""
 if village and delivered:mode="read"
 elif village and p=="carried":mode="choose" if choice else "give"
 elif village and p=="":mode="visit"
 elif not village and p=="":mode="take"
 elif not village and p=="carried":mode="travel"
 if mode=="":panel.hide();return
 if screen!=mode+p+game.lang:
  screen=mode+p+game.lang
  refresh()
 panel.show()
func refresh():
 second.hide()
 first.show()
 match mode:
  "take":
   body.text=words("سه پاره از سپر دیو کنار هم افتاده‌اند.","Three pieces of the div’s shield lie together.")
   first.text=words("برداشتن نشان","Take the pieces")
  "travel":
   body.text=words("نشان را به زال، کنار چشمهٔ زابل، برسان.","Bring the pieces to Zal at the spring in Zabol.")
   first.text=words("بازگشت به زابل","Return to Zabol")
  "visit":
   body.text=words("زال: از سپر دیو چیزی بر جای ماند؟","Zal: Did anything survive of the div’s shield?")
   first.text=words("رفتن به جای نبرد","Visit the battlefield")
  "give":
   body.text=words("زال دستش را می‌گشاید. «از آن شب چه به یادگار بماند؟»","Zal opens his palm. “What shall we remember of that night?”")
   first.text=words("سپردن نشان به زال","Give Zal the pieces")
  "choose":
   body.text=words("از سه پارهٔ سپر، چه چیزی برای زابل بسازیم؟","What shall Zabol make from the three pieces?")
   first.text=words("چراغ کاروان","Caravan lantern")
   second.text=words("تاج پیروزی","Victory crown")
   second.show()
  "read":
   body.text=words("زال: بگذار رهگذری که نام ما را نمی‌داند، در این نور راهش را بیابد.","Zal: May a traveller who never knew our names find the way by this light.") if progress()=="lantern" else words("زال: این سه پاره را کنار هم ببین؛ هر کدام جای یک ستون است.","Zal: Look at the three pieces together. Each marks a pillar that fell.")
   first.hide()
func act(index):
 if not panel.visible or not game.is_defeated("boss"):return
 var m=get_tree().current_scene
 if m.world!=world or m.player.dead:return
 match mode:
  "take":
   if progress()!="":return
   game.state[KEY]="carried"
   game.save_game()
  "travel","visit":
   panel.hide()
   if mode=="travel" and progress()=="carried":m.goto_map("village",Vector2(430,336))
   elif mode=="visit" and progress()=="":m.goto_map("dungeon",Vector2(805,665))
  "give":
   if progress()=="carried":choice=true
  "choose":
   if progress()!="carried":return
   game.state[KEY]="lantern" if index==0 else "crown"
   game.save_game()
   choice=false
   guide_to_spring=true
   # Keep Zal’s response legible while the memorial appears by the spring.
   body.text=words("زال: چراغش را کنار چشمه روشن می‌کنیم.","Zal: We shall light it by the spring.") if index==0 else words("زال: تاجش را کنار چشمه می‌گذاریم تا هر سه نشان پیدا باشد.","Zal: By the spring, all three marks on the crown will be seen.")
   first.hide()
   second.hide()
   set_process(false)
   if is_instance_valid(model):model.queue_free()
   style=progress()
   model=preload("res://visual3d/token.gd").new()
   model.form=style
   add_child(model)
   position=Vector2(492,443)
   await get_tree().create_timer(2.6).timeout
   set_process(true)
