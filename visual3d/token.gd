extends "res://visual3d/stage.gd"
var form=""
func piece(obj,loc,color):
 var m=StandardMaterial3D.new()
 m.albedo_color=Color(color)
 m.roughness=.62
 var n=MeshInstance3D.new()
 n.mesh=obj
 n.material_override=m
 n.position=loc
 stage.add_child(n)
 return n
func disc(y,up,low,h,col):
 var m=CylinderMesh.new()
 m.top_radius=up
 m.bottom_radius=low
 m.height=h
 m.radial_segments=8
 return piece(m,Vector3(0,y,0),col)
func facet(at,dim,col):
 var cube=BoxMesh.new()
 cube.size=dim
 return piece(cube,at,col)
func _ready():
 studio(Vector2i(96,112),2.5,Vector3(0,.64,0),2.2)
 scale=Vector2.ONE*.53
 position.y=-18
 disc(.08,.6,.66,.16,"#665144")
 disc(.2,.52,.58,.13,"#bd9a64")
 disc(.31,.49,.50,.09,"#335a60")
 if form=="lantern":
  disc(.40,.30,.37,.13,"#c09956")
  disc(.65,.22,.22,.48,"#ffc879")
  for x in [-.22,.22]:
   for z in [-.15,.15]:facet(Vector3(x,.69,z),Vector3(.055,.56,.055),"#77503b")
  disc(.99,.12,.35,.22,"#3f7d80")
  disc(1.16,.03,.09,.15,"#d9ae69")
 else:
  for i in 3:
   var col="#5d4c68" if form=="shard" else "#a9814c"
   var f=facet(Vector3((i-1)*.20,.64+(.13 if i==1 else 0.),0),Vector3(.16,.64,.16),col)
   f.rotation.z=(1-i)*.23
   var jewel=facet(Vector3((i-1)*.25,.85+(.13 if i==1 else 0.),.09),Vector3(.10,.15,.055),"#f0bc68")
   jewel.rotation.z=.67
 vp.render_target_update_mode=SubViewport.UPDATE_ONCE
