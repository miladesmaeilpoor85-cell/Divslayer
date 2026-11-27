extends Node2D
var b
var deployed=false
var cooldown=0.
var lane_visible=false
var lane_start=Vector2.ZERO
var lane_end=Vector2.ZERO
var warning_time=0.0
var marked_pillar

func _ready():
 b=get_parent()
 top_level=true
 global_position=Vector2.ZERO
 z_index=8

func _process(_dt):
 var was_visible=lane_visible
 lane_visible=false
 marked_pillar=null
 if not b.dead:
  for attack in b.bfx.tele:
   if attack.get("en")!=b or attack.get("src")!="charge" or attack.get("done",false):continue
   lane_start=to_local(attack.pos)
   lane_end=to_local(attack.b)
   lane_visible=lane_start.distance_squared_to(lane_end)>1.0
   warning_time=clampf(attack.t/maxf(attack.total,0.01),0.0,1.0)
   if lane_visible:
    var axis=lane_start.direction_to(lane_end)
    var nearest=lane_start.distance_to(lane_end)
    for pillar in b.pillars:
     if not is_instance_valid(pillar) or pillar.dead:continue
     var offset=to_local(pillar.center())-lane_start
     var along=offset.dot(axis)
     if along>0.0 and along<nearest and absf(offset.cross(axis))<=20.0:
      nearest=along
      marked_pillar=pillar
   break
 if lane_visible or was_visible:queue_redraw()

func _draw():
 if not lane_visible:return
 var axis=lane_start.direction_to(lane_end)
 var normal=axis.orthogonal()
 var length=lane_start.distance_to(lane_end)
 var ink=Color("#382120")
 var light=Color("#ffecaa").lerp(Color.WHITE,1.0-warning_time)
 # The native lane underneath still marks the full hit width.
 for distance in range(28,int(length)-7,48):
  var tip=lane_start+axis*distance
  var mark=PackedVector2Array([tip-axis*7+normal*5,tip,tip-axis*7-normal*5])
  draw_polyline(mark,ink,4.0,true)
  draw_polyline(mark,light,1.8,true)
 if is_instance_valid(marked_pillar) and not marked_pillar.dead:
  var center=to_local(marked_pillar.center())
  var radius=18.0+4.0*warning_time
  for quarter in 4:
   var start=quarter*PI/2.0+0.16
   draw_arc(center,radius,start,start+1.25,12,ink,4.0,true)
   draw_arc(center,radius,start,start+1.25,12,light,2.0,true)

func _physics_process(dt):
 if b.dead or not b.engaged or b.shield<=0:return
 if not deployed and b.pillars.size()==3:
  deployed=true
  # The southern hall is clear of walls and spike plates.
  var places=[Vector2(725,685),Vector2(799,573),Vector2(906,644)]
  for i in 3:
   var col=b.pillars[i]
   if not is_instance_valid(col) or col.dead:continue
   col.position=places[i]
   col.home=places[i]
   var sigil=Node2D.new()
   col.add_child(sigil)
   sigil.draw.connect(_draw_sigil.bind(sigil,i))
   sigil.queue_redraw()
 if not deployed:return
 cooldown=maxf(0,cooldown-dt)
 if cooldown>0 or b.staggered>0 or b.busy>0 or b.windup or not b.motion.is_empty():return
 var p=b.player()
 if not is_instance_valid(p) or p.dead:return
 var a:Vector2=b.center()
 var target:Vector2=p.pc()
 var direction=a.direction_to(target)
 var distance=a.distance_to(target)
 if distance<42 or distance>280:return
 for c in b.pillars:
  if not is_instance_valid(c) or c.dead:continue
  var offset:Vector2=c.center()-a
  var ahead=offset.dot(direction)
  if ahead<5 or ahead>distance+8 or absf(offset.cross(direction))>20:continue
  # The native attack resolves the dash, pillar destruction, damage and stun.
  b._use("charge",3.4,1.3)
  b.busy=.98
  b.windup=true
  var t=b.bfx.lane(a,a+direction*325.,50.,.88,Color("#ff754c"),b._fire_charge.bind(direction.angle(),7.6,.73),b)
  t["src"]="charge"
  cooldown=3.4
  break
func _draw_sigil(sigil,index):
 sigil.draw_arc(Vector2(0,1),18,0,TAU,28,Color("#c6a3ef"),1.2,true)
 for k in index+1:
  var x=(k-index*.5)*6
  sigil.draw_colored_polygon(PackedVector2Array([Vector2(x,-32),Vector2(x+2,-29),Vector2(x,-26),Vector2(x-2,-29)]),Color("#fff0b8"))
