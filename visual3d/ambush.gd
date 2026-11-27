extends Node2D

enum Phase { DORMANT, TRACKING, WARNING, ERUPTION, SETTLING, FINISHED }
const WAGON=Vector2(760,560)
const RADIUS=34.
const WARNING_TIME=1.25
var phase=Phase.DORMANT
var age=0.
var escaped=false
var player
var game
var branches=[]
var shard_angles=[-2.76,-2.26,-1.84,-1.45,-1.04,-.50]
func _ready():
 game=get_node("/root/Game")
 if game.state.get("ash_wheel_encounter",false):
  phase=Phase.FINISHED
 for i in 6:
  var direction=Vector2.from_angle(i*TAU/6+.24)
  branches.append(PackedVector2Array([Vector2.ZERO,direction*9,direction*16+direction.orthogonal()*4,direction*27,direction*34-direction.orthogonal()*2]))
func _physics_process(dt):
 if phase==Phase.FINISHED:return
 var main=get_tree().current_scene
 if not main or not is_instance_valid(main.get("player")):return
 player=main.player
 if player.dead or player.world!=get_parent().get_parent() or not player.can_process():return
 var pos:Vector2=player.global_position
 var gap=pos.distance_to(WAGON)
 match phase:
  Phase.DORMANT:
   if gap<51:phase=Phase.TRACKING
  Phase.TRACKING:
   if gap>=62 and gap<=108:
    global_position=pos+player.move_dir.normalized()*11
    phase=Phase.WARNING
    age=0
  Phase.WARNING:
   age+=dt
   if age>=WARNING_TIME:
    escaped=pos.distance_to(global_position)>RADIUS or player.roll_t>0 or player.dodge_iframes>0
    if not escaped:player.take_hit(7.)
    game.state["ash_wheel_encounter"]=true
    game.stats_changed.emit()
    game.state["x"]=player.position.x
    game.state["y"]=player.position.y
    game.save_game()
    phase=Phase.ERUPTION
    age=0
  Phase.ERUPTION:
   age+=dt
   if age>.42:
    phase=Phase.SETTLING
    age=0
  Phase.SETTLING:
   age+=dt
   if age>.8:phase=Phase.FINISHED
 queue_redraw()
func _draw():
 if phase not in [Phase.WARNING,Phase.ERUPTION,Phase.SETTLING]:return
 var fade=1.-age/.8 if phase==Phase.SETTLING else 1.
 var progress=clampf(age/WARNING_TIME,0,1) if phase==Phase.WARNING else 1.
 draw_set_transform(Vector2.ZERO,0,Vector2(1,1))
 draw_circle(Vector2.ZERO,RADIUS,Color(.21,.11,.07,.28*fade))
 draw_arc(Vector2.ZERO,RADIUS,-PI/2,-PI/2+TAU*maxf(.03,progress),48,Color(.98,.67,.25,.88*fade),1.6,true)
 for points in branches:
  var path=PackedVector2Array()
  for v in points:path.append(v*(.42+.58*progress))
  draw_polyline(path,Color(.16,.10,.08,fade),3.5,true)
  draw_polyline(path,Color(.97,.58,.23,fade),1,true)
 if phase==Phase.WARNING:return
 var height=(sin(clampf(age/.42,0,1)*PI*.66) if phase==Phase.ERUPTION else .88*fade)
 for i in shard_angles.size():
  var a:float=shard_angles[i]
  var start=Vector2((i-2.5)*5,4-absf(i-2.5))
  var tip=start+Vector2.from_angle(a)*(20.+13.*sin(i*1.4+1.))*height
  draw_colored_polygon(PackedVector2Array([start+Vector2(-4,2),tip,start+Vector2(4,2)]),Color(.39,.23,.13,fade))
  draw_line(start+Vector2(3,1),tip,Color(.91,.65,.34,fade),1.6,true)
