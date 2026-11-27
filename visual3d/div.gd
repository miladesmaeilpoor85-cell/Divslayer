extends "res://visual3d/stage.gd"

var b
var body=Node3D.new()
var chest=Node3D.new()
var head=Node3D.new()
var arms=[]
var wards=[]
var last_ward=-1
var burst=0.
var heading=Vector2.DOWN
var aiming=false
var time=0.
var palette={}
const STONE=Color("#463852")
const LIGHT=Color("#736084")
const BRONZE=Color("#ba824e")
const EMBER=Color("#ffa74e")
const IVORY=Color("#e0c8a0")
func material(col):
 if palette.has(col):return palette[col]
 var m=StandardMaterial3D.new()
 m.albedo_color=col
 m.roughness=.76
 if col==EMBER:
  m.emission_enabled=true
  m.emission=col
  m.emission_energy_multiplier=.65
 palette[col]=m
 return m
func piece(root,shape,at,size,col):
 var ob=MeshInstance3D.new()
 ob.mesh=shape
 root.add_child(ob)
 ob.position=at
 ob.scale=size
 ob.material_override=material(col)
 return ob
func oval(root,at,size,col):
 var shape=SphereMesh.new()
 shape.radial_segments=10
 shape.rings=4
 return piece(root,shape,at,size,col)
func link(root,a,c,r1,r2,col):
 var s=CylinderMesh.new()
 s.bottom_radius=r1
 s.top_radius=r2
 s.height=a.distance_to(c)
 s.radial_segments=7
 s.rings=0
 var o=piece(root,s,(a+c)*.5,Vector3.ONE,col)
 o.quaternion=Quaternion(Vector3.UP,(c-a).normalized())
 return o
func _ready():
 b=get_parent()
 studio(Vector2i(160,160),3.65,Vector3(0,1.17,0),2.8)
 scale=Vector2.ONE*.60
 position=Vector2(0,-30)
 stage.add_child(body)
 body.add_child(chest)
 chest.position.y=1.02
 oval(chest,Vector3.ZERO,Vector3(1.15,.89,.68),STONE)
 oval(chest,Vector3(0,.38,.02),Vector3(1.56,.91,.86),LIGHT)
 for sign_x in [-1,1]:
  var s=float(sign_x)
  oval(body,Vector3(.37*s,.54,0),Vector3(.57,.96,.56),STONE)
  oval(body,Vector3(.40*s,.16,.16),Vector3(.56,.31,.75),LIGHT)
  var shoulder=Node3D.new()
  chest.add_child(shoulder)
  shoulder.position=Vector3(s*.73,.48,0)
  oval(shoulder,Vector3(0,-.06,0),Vector3(.7,.68,.72),LIGHT)
  oval(shoulder,Vector3(s*.16,-.43,.04),Vector3(.49,.77,.52),STONE)
  oval(shoulder,Vector3(s*.19,-.7,.12),Vector3(.52,.36,.56),BRONZE)
  oval(shoulder,Vector3(s*.21,-.89,.18),Vector3(.51,.45,.52),LIGHT)
  for k in 3:
   var base=Vector3(s*(.02+.13*k),.13,-.13+.07*k)
   link(shoulder,base,base+Vector3(s*(.13+k*.032),.22+.065*k,-.035),.123,0.,BRONZE)
  arms.append(shoulder)
 chest.add_child(head)
 head.position=Vector3(0,.85,.14)
 oval(head,Vector3.ZERO,Vector3(.83,.76,.70),STONE)
 oval(head,Vector3(0,-.13,.24),Vector3(.63,.38,.47),LIGHT)
 for s in [-1,1]:
  var a=Vector3(s*.28,.19,-.015)
  var c=Vector3(s*.55,.34,-.04)
  var d=Vector3(s*.63,.60,-.06)
  link(head,a,c,.147,.116,IVORY)
  link(head,c,d,.116,.067,IVORY)
  link(head,d,Vector3(s*.54,.79,-.05),.067,0.,IVORY)
  var eye=oval(head,Vector3(s*.17,.035,.313),Vector3(.16,.08,.09),EMBER)
  eye.rotation.z=s*.23
  var brow=oval(head,Vector3(s*.18,.112,.286),Vector3(.33,.13,.18),BRONZE)
  brow.rotation.z=s*.23
  link(head,Vector3(.21*s,-.20,.41),Vector3(.22*s,-.05,.44),.063,0.,IVORY)
 for j in 3:
  var ward=oval(chest,Vector3((j-1)*.25,.36,.433),Vector3(.19,.24,.1),EMBER)
  wards.append(ward)
func _physics_process(dt):
 if not is_instance_valid(b.anim):return
 b.anim.self_modulate.a=0
 visible=not b.dead and b.anim.visible
 if not visible:return
 time+=dt
 var player=b.player()
 if not is_instance_valid(player):return
 var dest:Vector2=b.global_position.direction_to(player.global_position)
 aiming=false
 var fraction=0.
 for t in b.bfx.tele:
  if t.get("en")==b and t.get("src")=="charge" and not t.get("done",false):
   dest=t.pos.direction_to(t.b)
   fraction=1.-clampf(t.t/maxf(t.total,.01),0,1)
   aiming=true
   break
 var rush:bool=b.motion.get("kind","")=="dash"
 if rush:dest=b.motion.v.normalized()
 if dest.length_squared()>.1:heading=dest
 var yaw=atan2(heading.x,heading.y)
 body.rotation.y=yaw if aiming or rush else lerp_angle(body.rotation.y,yaw,minf(1,dt*14))
 var braced= .48+fraction*.42 if aiming else (1. if rush else 0.)
 var stunned:bool=b.staggered>0.
 chest.rotation.x=.12*sin(time*2)+.40*braced+(.43 if stunned else 0.)
 head.rotation.x=-.24*braced+(.40 if stunned else 0.)
 arms[0].rotation.x=-.95*braced-.11*sin(time*3)
 arms[1].rotation.x=.63*braced+.11*sin(time*3)
 arms[0].position.y=.48-.30*braced
 chest.position.y=1.02-.18*braced+sin(time*2.4)*.025-(.18 if stunned else 0.)
 if b.shield<last_ward:burst=.52
 last_ward=b.shield
 for j in wards.size():wards[j].visible=j<b.shield
 burst=maxf(0,burst-dt)
 self_modulate=Color(1.5,1.23,.95) if burst>0 else Color.WHITE
