extends "res://visual3d/stage.gd"
var drops=[]
var time=0.
func part(top,bottom,height,y,tint,sides=12):
 var m=CylinderMesh.new()
 m.top_radius=top
 m.bottom_radius=bottom
 m.height=height
 m.radial_segments=sides
 m.rings=1
 var mat=StandardMaterial3D.new()
 mat.albedo_color=Color(tint)
 m.material=mat
 var n=MeshInstance3D.new()
 n.mesh=m
 stage.add_child(n)
 n.position.y=y
 return n
func _ready():
 studio(Vector2i(168,168),4.0,Vector3(0,.42,0),4.5)
 scale=Vector2.ONE*.66
 position.y=-24
 get_parent().self_modulate.a=0
 part(1.43,1.53,.17,.085,"#5f5548")
 part(1.47,1.35,.27,.29,"#c39661")
 part(1.48,1.49,.09,.455,"#e6c487")
 part(1.38,1.38,.025,.51,"#397e83")
 part(1.30,1.32,.012,.532,"#4f9d9f")
 part(.34,.48,.12,.60,"#d9bc88")
 part(.16,.26,.39,.83,"#376d77")
 part(.52,.18,.20,1.10,"#c6a06a")
 part(.46,.46,.015,1.21,"#75b7bb")
 part(.075,.10,.19,1.30,"#dcb775")
 var first_drop=part(.023,.035,.09,0,"#bce8e4",5)
 drops.append(first_drop)
 for i in 15:
  var drop=MeshInstance3D.new()
  drop.mesh=first_drop.mesh
  stage.add_child(drop)
  drops.append(drop)
func _process(delta):
 time+=delta
 if time<.055:return
 time=0
 var on_screen=get_global_transform_with_canvas()*get_rect()
 if not is_visible_in_tree() or not on_screen.intersects(get_viewport_rect()):return
 var ticks=Time.get_ticks_msec()*.001
 for i in drops.size():
  var u=fmod(ticks*.9+float(i%4)/4,1.)
  var angle=TAU*floori(i/4)/4+.4
  drops[i].position=Vector3(cos(angle)*(.22+.72*u),1.23+.45*sin(PI*u)-.68*u,sin(angle)*(.22+.72*u))
 vp.render_target_update_mode=SubViewport.UPDATE_ONCE
