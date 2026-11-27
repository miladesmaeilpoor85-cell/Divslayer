extends Sprite2D
var vp: SubViewport
var stage: Node3D
func studio(pixels:Vector2i, span:float, focus:Vector3, elevation:float):
 vp=SubViewport.new()
 vp.size=pixels
 vp.transparent_bg=true
 vp.own_world_3d=true
 vp.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE
 add_child(vp)
 stage=Node3D.new()
 vp.add_child(stage)
 var cam=Camera3D.new()
 stage.add_child(cam)
 cam.projection=Camera3D.PROJECTION_ORTHOGONAL
 cam.size=span
 cam.position=focus+Vector3(0,elevation,5)
 cam.look_at(focus)
 var light=DirectionalLight3D.new()
 stage.add_child(light)
 light.rotation_degrees=Vector3(-48,-36,0)
 light.light_energy=1.1
 light.light_color=Color("#ffe6b9")
 var env=Environment.new()
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color=Color("#e5edff")
 env.ambient_light_energy=0.8
 cam.environment=env
 texture=vp.get_texture()
 texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
