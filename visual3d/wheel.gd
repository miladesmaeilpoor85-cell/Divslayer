extends Node2D
var memorial=""
var caption:Label
var game
var ambush

func _ready():
 game=get_node("/root/Game")
 memorial=str(game.state.get("arzhang_memorial",""))
 if memorial not in ["lantern","crown"]:
  set_process(false)
  return
 caption=Label.new()
 caption.position=Vector2(-125,-82)
 caption.size=Vector2(250,42)
 caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
 caption.add_theme_font_size_override("font_size",13)
 caption.add_theme_constant_override("outline_size",4)
 caption.z_index=8
 caption.hide()
 add_child(caption)
 ambush=get_parent().get_node_or_null("AshAmbush")
 if not ambush:call_deferred("_find_ambush")

func _find_ambush():
 ambush=get_parent().get_node_or_null("AshAmbush")

func _process(_dt):
 var main=get_tree().current_scene
 var player=main.get("player") if main else null
 caption.visible=is_instance_valid(ambush) and ambush.phase==ambush.Phase.FINISHED and is_instance_valid(player) and player.world==get_parent().get_parent() and not player.dead and global_position.distance_to(player.global_position)<64
 if not caption.visible:return
 var fa=game.lang=="fa"
 if memorial=="lantern":
  caption.text="کاروان‌نویس: «چراغِ چشمه را که دیدیم، راه زابل را پیدا کردیم.»" if fa else "Caravan log: “The lamp at the spring showed us the way to Zabol.”"
 else:
  caption.text="روی گاری سه دندانه کنده‌اند؛ به یاد تاجی که زال کنار چشمه گذاشت." if fa else "Three points are carved into the cart, like the crown Zal set by the spring."

func _draw():
 draw_set_transform(Vector2(0,-6),-.36,Vector2(1,.71))
 draw_arc(Vector2.ZERO,13,.79,5.92,24,Color("#422f23"),5,true)
 draw_arc(Vector2.ZERO,13,.79,5.92,24,Color("#ba884c"),2,true)
 for a in [1.1,2.1,3.1,4.2,5.1]:
  draw_line(Vector2.ZERO,Vector2.from_angle(a)*12,Color("#aa7a47"),2,true)
 draw_circle(Vector2.ZERO,3,Color("#514033"))
 draw_line(Vector2(13,3),Vector2(20,-1),Color("#efc486"),2,true)
 draw_line(Vector2(11,7),Vector2(17,5),Color("#d4ab76"),2,true)
 if memorial not in ["lantern","crown"]:return
 draw_set_transform(Vector2(19,-4),0,Vector2.ONE)
 if memorial=="lantern":
  draw_line(Vector2.ZERO,Vector2(0,-23),Color("#654834"),3)
  draw_line(Vector2(0,-22),Vector2(8,-22),Color("#936c46"),2)
  draw_line(Vector2(7,-22),Vector2(7,-17),Color("#513a31"),1.5)
  draw_circle(Vector2(7,-13),9,Color("#ffcc682b"))
  draw_rect(Rect2(4,-17,6,8),Color("#5b4237"))
  draw_rect(Rect2(5,-16,4,6),Color("#ffe094"))
 else:
  draw_rect(Rect2(-8,-10,18,10),Color("#755139"))
  var carving=PackedVector2Array([Vector2(-6,-8),Vector2(-4,-4),Vector2(0,-9),Vector2(4,-4),Vector2(8,-8)])
  draw_polyline(carving,Color("#dfbd79"),1.5,true)
