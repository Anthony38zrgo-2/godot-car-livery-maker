extends SceneTree

# Run with GPU rendering after importing the project.
func sample_uv(node: MeshInstance3D, point: Vector3) -> Vector2:
 for surface in node.mesh.get_surface_count():
  var a=node.mesh.surface_get_arrays(surface)
  var vertices:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
  var uv:PackedVector2Array=a[Mesh.ARRAY_TEX_UV2]
  var ids:PackedInt32Array=a[Mesh.ARRAY_INDEX]
  for i in range(0,ids.size(),3):
   var x:Vector3=node.global_transform*vertices[ids[i]]
   var y:Vector3=node.global_transform*vertices[ids[i+1]]
   var z:Vector3=node.global_transform*vertices[ids[i+2]]
   var e0=y-x
   var e1=z-x
   var q=point-x
   var d00=e0.dot(e0)
   var d01=e0.dot(e1)
   var d11=e1.dot(e1)
   var d20=q.dot(e0)
   var d21=q.dot(e1)
   var denominator=d00*d11-d01*d01
   if absf(denominator)<0.0000001:continue
   var v=(d11*d20-d01*d21)/denominator
   var w=(d00*d21-d01*d20)/denominator
   var u=1.0-v-w
   if u>=-0.0001 and v>=-0.0001 and w>=-0.0001 and absf(q.dot(e0.cross(e1).normalized()))<0.001:
    return uv[ids[i]]*u+uv[ids[i+1]]*v+uv[ids[i+2]]*w
 return Vector2(-1,-1)

func _initialize(): call_deferred("run")
func run():
 var s=load("res://livery_studio.tscn").instantiate()
 root.add_child(s)
 await process_frame
 s.model_root=Node3D.new()
 s.add_child(s.model_root)
 var body=MeshInstance3D.new()
 body.name="Carroceria_atlas"
 var mesh=BoxMesh.new()
 mesh.size=Vector3(0.4,0.7,2.2)
 mesh.add_uv2=true
 mesh.lightmap_size_hint=Vector2i(128,128)
 var mat=StandardMaterial3D.new()
 mat.resource_name="Benetton B195 - atlas.fixture"
 mat.albedo_color=Color("102080")
 mesh.material=mat
 body.mesh=mesh
 body.position=Vector3(0.5,0.5,0)
 s.model_root.add_child(body)
 var protected=MeshInstance3D.new()
 protected.name="NO_PINTAR_Test"
 var protected_mesh=BoxMesh.new()
 protected_mesh.size=Vector3(0.25,0.25,0.25)
 protected_mesh.add_uv2=true
 protected_mesh.lightmap_size_hint=Vector2i(128,128)
 var protected_mat=StandardMaterial3D.new()
 protected_mat.albedo_color=Color("22dd33")
 protected_mesh.material=protected_mat
 protected.mesh=protected_mesh
 protected.position=Vector3(0.5,0.5,1.5)
 s.model_root.add_child(protected)
 s.body_materials.collect(s.model_root)
 s.manager=OverlayAtlasManager.new()
 s.manager.atlas_size=512
 s.manager.apply_on_ready=true
 s.model_root.add_child(s.manager)
 s.model_path="fixture://synthetic"
 s.vinyl_editor.bind_model()
 s.set_process(false)
 s.camera.position=Vector3(4,0.5,0.5)
 s.camera.look_at(Vector3(0.5,0.5,0.5))
 for frame in 10: await process_frame
 var hit=s.vinyl_editor.hit_test(s.camera.unproject_position(Vector3(0.5,0.5,0.5)))
 s.vinyl_editor.fill.color=Color("00ffff")
 s.vinyl_editor.fields.width.value=0.4
 s.vinyl_editor.fields.height.value=0.4
 s.vinyl_editor.place(hit)
 s.brush.position=Vector3(4,0.5,-0.5)
 s.brush.look_at(Vector3(0.5,0.5,-0.5))
 s.brush.projection=Camera3D.PROJECTION_ORTHOGONAL
 s.brush.size=0.3
 s.brush.color=Color.RED
 s.brush.drawing=true
 for frame in 45: await process_frame
 s.brush.drawing=false
 var path=ProjectSettings.globalize_path("user://test_complete_atlas.png")
 var error=await load("res://studio/atlas_exporter.gd").new().export_atlas(s,path)
 if not error.is_empty():push_error(error);quit(1);return
 var image=Image.load_from_file(path)
 var blue=0
 var red=0
 var cyan=0
 var green=0
 for y in range(0,image.get_height(),2):
  for x in range(0,image.get_width(),2):
   var c=image.get_pixel(x,y)
   if c.a<0.9:continue
   if c.r<0.2 and c.g<0.25 and c.b>0.3:blue+=1
   if c.r>0.6 and c.g<0.3 and c.b<0.3:red+=1
   if c.r<0.2 and c.g>0.6 and c.b>0.6:cyan+=1
   if c.r<0.3 and c.g>0.5 and c.b<0.4:green+=1
 var mapping=JSON.parse_string(FileAccess.get_file_as_string(path.get_basename()+"_mapeo.json"))
 var body_mapping={}
 for entry in mapping.surfaces:
  if entry.node=="Carroceria_atlas":body_mapping=entry
 var uv=sample_uv(body,hit.point + Vector3(0,0.015,0.02))
 if uv.x<0 or body_mapping.is_empty():print("UV_MAPPING_MISSING");quit(3);return
 var position=Vector2(body_mapping.position[0],body_mapping.position[1])
 var extent=Vector2(body_mapping.size[0],body_mapping.size[1])
 var pixel=Vector2i((position+uv*extent)*512)
 var sampled=image.get_pixelv(pixel)
 print("ATLAS_UV_SAMPLE ",pixel," ",sampled)
 var mapped_cyan=sampled.r<0.25 and sampled.g>0.5 and sampled.b>0.5
 var protected_in_mapping=false
 for entry in mapping.surfaces:
  if entry.node=="NO_PINTAR_Test" and entry.protected:protected_in_mapping=true
 print("ATLAS_TEST blue=",blue," red=",red," cyan=",cyan," protected_green=",green," mapping=",protected_in_mapping)
 var ok=blue>30 and red>5 and cyan>5 and green>5 and protected_in_mapping and mapped_cyan
 DirAccess.remove_absolute(path)
 DirAccess.remove_absolute(path.get_basename()+"_mapeo.json")
 quit(0 if ok else 2)
