extends Node2D
# Local coordinates put all pads west of the first spike trap.
const PADS=[Vector2(-37,0),Vector2(0,-42),Vector2(37,0)]
const ORDER=[1,0,2]
const TINT=[Color("#55c4c1"),Color("#ffb65b"),Color("#9aaafd")]
enum {WAITING,SHOW,REPEAT,WRONG,WON}
var phase=WAITING
var elapsed=0.
var step=0
var previous=-1
var flash=-1
var flash_time=0.
var sounded=-1
var audio=AudioStreamPlayer2D.new()
var tones=[]
var label=Label.new()
var game
func _ready():
 game=get_node("/root/Game")
 if game.state.get("ember_echo_solved",false):
  phase=WON
  elapsed=5.
 add_child(audio)
 audio.volume_db=-11
 for hz in [392,523,659]:
  var wav=AudioStreamWAV.new()
  wav.mix_rate=22050
  wav.format=AudioStreamWAV.FORMAT_16_BITS
  var data=PackedByteArray()
  data.resize(13230)
  for j in 6615:
   var t=j/22050.
   data.encode_s16(j*2,int(22000*minf(1,t*120)*exp(-14*t)*(sin(TAU*hz*t)*.79+sin(TAU*hz*2*t)*.21)))
  wav.data=data
  tones.append(wav)
 label.position=Vector2(-165,-92)
 label.size=Vector2(330,24)
 label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 label.add_theme_font_size_override("font_size",13)
 label.add_theme_constant_override("outline_size",4)
 add_child(label)
 caption()
func caption():
 var fa=["اخگرِ پژواک","ببین و گوش کن","روی سه نشان به همان ترتیب قدم بگذار","پژواک خاموش شد؛ دوباره گوش کن","مُهر روشن شد · راهِ سنگ‌نوشته ↗"]
 var en=["Ember of echoes","Watch and listen","Step on the marks in the same order","The echo faded. Listen again.","Seal lit · inscription ↗"]
 label.text=(fa if game.lang=="fa" else en)[phase]
func tone(i):
 audio.stream=tones[i]
 audio.play()
func show_pattern():
 phase=SHOW
 step=0
 elapsed=0.
 sounded=-1
 flash=-1
 caption()
func _physics_process(dt):
 var main=get_tree().current_scene
 if not main or not is_instance_valid(main.get("player")):return
 var p=main.player
 if p.dead or p.world!=get_parent().get_parent() or not p.can_process():return
 var feet=to_local(p.global_position)
 var near=feet.length()<115
 label.visible=near
 if not near:
  if phase!=WAITING and phase!=WON:
   phase=WAITING
   flash=-1
   previous=-1
   caption()
  queue_redraw()
  return
 elapsed+=dt
 var pad=-1
 for i in PADS.size():
  if feet.distance_to(PADS[i])<=15:pad=i
 var beat_just_ended=false
 match phase:
  WAITING:
   if feet.length()<76:show_pattern()
  SHOW:
   var beat=floori(elapsed/.8)
   if beat>=ORDER.size():
    beat_just_ended=true
    phase=REPEAT
    flash=-1
    caption()
   else:
    flash=ORDER[beat] if fmod(elapsed,.8)<.54 else -1
    if beat!=sounded:
     tone(ORDER[beat])
     sounded=beat
  REPEAT:
   flash_time-=dt
   if flash_time<=0:flash=-1
   if pad>=0 and pad!=previous:
    tone(pad)
    flash=pad
    flash_time=.32
    if pad!=ORDER[step]:
     phase=WRONG
     elapsed=0
    else:
     step+=1
     if step==ORDER.size():
      phase=WON
      game.state["ember_echo_solved"]=true
      game.stats_changed.emit()
      game.state["potions"]=int(game.state.get("potions",0))+1
      game.save_game()
      elapsed=0
    caption()
  WRONG:
   if elapsed>.85:show_pattern()
  WON:
   if elapsed<4:
    label.text="یک معجون به کوله اضافه شد" if game.lang=="fa" else "One potion added to your pack"
   else:caption()
 previous=-1 if beat_just_ended else pad
 queue_redraw()
func _draw():
 for i in PADS.size():
  var c=Vector2(PADS[i])
  var lit=phase==WON or i==flash
  var color=Color(TINT[i]) if lit else Color("#a79c8a")
  var rim=PackedVector2Array()
  for j in 8:rim.append(c+Vector2(cos(j*TAU/8)*16,sin(j*TAU/8)*10))
  var base=rim.duplicate()
  for j in base.size():base[j]+=Vector2(0,5)
  draw_colored_polygon(base,Color("#392e32"))
  draw_colored_polygon(rim,Color("#554b4c"))
  rim.append(rim[0])
  draw_polyline(rim,color,1.8,true)
  if lit:draw_circle(c,20,Color(color,.14))
  if i==0:draw_polyline(PackedVector2Array([c+Vector2(-7,0),c+Vector2(-3,-3),c+Vector2(1,2),c+Vector2(6,-1)]),color,2,true)
  elif i==1:draw_polyline(PackedVector2Array([c+Vector2(-5,3),c+Vector2(0,-5),c+Vector2(5,3),c+Vector2(-5,3)]),color,2,true)
  else:draw_arc(c,4,0,TAU,14,color,2,true)
 if phase==WON:
  for i in 5:
   var c=Vector2(55+i*11,-16-i*4)
   draw_polyline(PackedVector2Array([c+Vector2(-4,-2),c,c+Vector2(-2,4)]),Color("#ffd385"),1.6,true)
