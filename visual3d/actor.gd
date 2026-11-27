extends "res://visual3d/stage.gd"
var figure: Node3D
var pivot=Node3D.new()
var phase=0.
var roll=0.
var swing=0.
var prev_swings=0
var angle=0.
var arms=[]
var legs=[]
var weapon:Node3D
var actor
func _ready():
 actor=get_parent()
 studio(Vector2i(128,128),2.95,Vector3(0,0.96,0),3.3)
 scale=Vector2.ONE*.56
 position=Vector2(0,-20)
 stage.add_child(pivot)
 pivot.position.y=0.95
 pivot.add_child(figure)
 figure.position.y=-0.95
 for suffix in ["R","L"]:
  arms.append(figure.find_child("Arm"+suffix,true,false))
  legs.append(figure.find_child("Leg"+suffix,true,false))
 weapon=Node3D.new()
 arms[0].add_child(weapon)
 weapon.position=Vector3(-.16,-.53,.07)
 weapon.rotation.x=.9
 blade(Vector3(.055,.57,.032),Vector3(0,.34,0),Color("#d3e8e8"))
 blade(Vector3(.19,.034,.048),Vector3(0,.046,0),Color("#d79e50"))
 blade(Vector3(.042,.14,.04),Vector3(0,-.03,0),Color("#684033"))
 prev_swings=actor.swings
func blade(dim,at,tint):
 var box=BoxMesh.new()
 box.size=dim
 var mat=StandardMaterial3D.new()
 mat.albedo_color=tint
 box.material=mat
 var part=MeshInstance3D.new()
 part.mesh=box
 weapon.add_child(part)
 part.position=at
func _process(delta):
 if not is_instance_valid(actor.anim):return
 actor.anim.self_modulate.a=0
 var facing:Vector2=actor.facing_vec()
 if facing.length_squared()>.05: angle=lerp_angle(angle,atan2(facing.x,facing.y),minf(1,delta*18))
 pivot.rotation.y=angle
 phase+=delta*(10.5 if actor.moving else 2.3)
 var stride=sin(phase)*(.55 if actor.moving else .025)
 if actor.swings!=prev_swings or (actor.attacking>0 and swing<=0):
  if actor.swings!=prev_swings: swing=.34
 prev_swings=actor.swings
 swing=maxf(0,swing-delta)
 var arc=sin((1-swing/.34)*PI) if swing>0 else 0.
 arms[0].rotation=Vector3(-stride-1.9*arc,arc*.65,-.07-arc*.28)
 arms[1].rotation=Vector3(stride-1.15*float(actor.blocking),0,.07)
 legs[0].rotation.x=stride
 legs[1].rotation.x=-stride
 if actor.roll_t>0: roll+=delta*19
 else: roll=0
 figure.rotation.x=roll
 figure.position=Vector3(0,-.95,0).rotated(Vector3.RIGHT,roll)
 pivot.position.y=.95+absf(stride)*.085
 modulate.a=.62 if actor.sneaking else actor.anim.modulate.a
 visible=actor.anim.visible and actor.body.visible
