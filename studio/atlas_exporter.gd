extends RefCounted

# Rasterize the same meshes and projected layers into the addon atlas UV layout.
# The export is a color texture; material finish remains in the editable document.
func export_atlas(studio: Node, path: String) -> String:
 if not is_instance_valid(studio.manager) or not studio.manager.atlas_texture_rid.is_valid():
  return "Abre un modelo antes de exportar"
 if not studio.supports_vinyls() or not studio.applied_shader_path.is_empty():
  return "La exportacion completa requiere el shader predeterminado"
 var size: int = studio.manager.atlas_size
 var viewport := SubViewport.new()
 viewport.size = Vector2i(size,size)
 viewport.own_world_3d = true
 viewport.transparent_bg = true
 viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
 studio.add_child(viewport)
 var camera := Camera3D.new()
 camera.current = true
 camera.cull_mask = 1
 viewport.add_child(camera)
 camera.position = Vector3(0,0,10)
 camera.fov = 100.0
 var original_shader: Shader = studio.manager.overlay_shader
 var code: String = original_shader.code
 for marker in ["render_mode cull_disabled;", "varying vec3 model_world_position;", "ALBEDO = atlas_color.rgb;", "ALPHA = atlas_color.a;"]:
  if not code.contains(marker):
   viewport.queue_free()
   return "El shader no admite esta exportacion"
 code = code.replace("render_mode cull_disabled;", "render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;")
 code = code.replace("varying vec3 model_world_position;", """varying vec3 model_world_position;
 uniform sampler2D bake_base_texture : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
 uniform vec4 bake_base_color : source_color = vec4(1.0);
 uniform bool bake_vertex_color = false;
 uniform float bake_alpha_cutoff = 0.0;
 uniform vec2 export_position;
 uniform vec2 export_size;
 uniform vec3 bake_uv_scale = vec3(1.0);
 uniform vec3 bake_uv_offset = vec3(0.0);
 """)
 code = code.replace("model_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;", """model_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 vec2 bake_uv = UV2 * export_size + export_position;
 POSITION = vec4(bake_uv.x * 2.0 - 1.0, bake_uv.y * 2.0 - 1.0, 0.5, 1.0);
 """)
 code = code.replace("bool is_camera_brush = (CAMERA_VISIBLE_LAYERS & (1u << uint(20))) != 0u;", "bool is_camera_brush = false;")
 code = code.replace("ALBEDO = atlas_color.rgb;", """vec4 base = texture(bake_base_texture, UV * bake_uv_scale.xy + bake_uv_offset.xy) * bake_base_color;
        if (bake_vertex_color) base *= COLOR;
        if (base.a < bake_alpha_cutoff) discard;
        ALBEDO = mix(base.rgb, atlas_color.rgb, atlas_color.a);""")
 code = code.replace("ALPHA = atlas_color.a;", "ALPHA = base.a;")
 var shader := Shader.new()
 shader.code = code
 var mappings: Array = []
 var nodes: Array[MeshInstance3D] = []
 var sizes: Array[Vector2] = []
 for node in studio.model_root.find_children("*", "MeshInstance3D", true, false):
  if not node.mesh: continue
  for surface in node.mesh.get_surface_count():
   var uv2: Variant = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV2]
   if uv2 == null or uv2.is_empty():
    viewport.queue_free()
    return "La pieza %s no tiene UV2" % node.name
  nodes.append(node)
  var hint: Vector2i = node.mesh.lightmap_size_hint
  sizes.append(Vector2(hint if hint.x > 0 and hint.y > 0 else Vector2i(128,128)))
 if nodes.is_empty():
  viewport.queue_free()
  return "No hay superficies para exportar"
 var packed: Array[Rect2] = MaxRectsPacker.pack_into_square(sizes)
 var empty_image := Image.create(1,1,false,Image.FORMAT_RGBA8)
 empty_image.fill(Color(0,0,0,0))
 var empty_texture := ImageTexture.create_from_image(empty_image)
 var mesh_count := 0
 for node_index in nodes.size():
  var node := nodes[node_index]
  var overlay := node.material_overlay as ShaderMaterial
  var export_rect := packed[node_index]
  var copy := MeshInstance3D.new()
  copy.name = node.name
  copy.mesh = node.mesh
  copy.extra_cull_margin = 100.0
  copy.transform = node.global_transform
  viewport.add_child(copy)
  mappings.append({"node":str(node.name),"position":[export_rect.position.x,export_rect.position.y],"size":[export_rect.size.x,export_rect.size.y],"protected":overlay == null})
  for index in node.mesh.get_surface_count():
   var source: Material = node.get_active_material(index)
   if not source is StandardMaterial3D:
    viewport.queue_free()
    return "Material no compatible en %s; no se exporto" % node.name
   var bake := ShaderMaterial.new()
   bake.shader = shader
   if overlay:
    for uniform_name in ["overlay_texture","position_in_atlas","size_in_atlas","atlas_index","vinyl_atlas","vinyl_count","vinyl_origins","vinyl_rights","vinyl_ups","vinyl_protections","is_bargeboard"]:
     var value: Variant = overlay.get_shader_parameter(uniform_name)
     if value != null: bake.set_shader_parameter(uniform_name,value)
   else:
    bake.set_shader_parameter("overlay_texture",empty_texture)
    bake.set_shader_parameter("vinyl_count",0)
   bake.set_shader_parameter("export_position",export_rect.position)
   bake.set_shader_parameter("export_size",export_rect.size)
   bake.set_shader_parameter("bake_base_color",source.albedo_color)
   bake.set_shader_parameter("bake_uv_scale",source.uv1_scale)
   bake.set_shader_parameter("bake_uv_offset",source.uv1_offset)
   if source.albedo_texture: bake.set_shader_parameter("bake_base_texture",source.albedo_texture)
   bake.set_shader_parameter("bake_vertex_color",source.vertex_color_use_as_albedo)
   if source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
    bake.set_shader_parameter("bake_alpha_cutoff",source.alpha_scissor_threshold)
   copy.set_surface_override_material(index,bake)
  mesh_count += 1
 if mesh_count == 0:
  viewport.queue_free()
  return "No hay superficies del atlas para exportar"
 viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
 await RenderingServer.frame_post_draw
 var image := viewport.get_texture().get_image()
 viewport.queue_free()
 if image == null or image.is_empty(): return "No se pudo leer el atlas generado"
 var extension := path.get_extension().to_lower()
 var error := image.save_exr(path) if extension == "exr" else image.save_png(path)
 if error != OK: return "No se pudo guardar el atlas (error %s)" % error
 var manifest_path := path.get_basename() + "_mapeo.json"
 var manifest := FileAccess.open(manifest_path,FileAccess.WRITE)
 if not manifest: return "Atlas guardado, pero no se pudo guardar el mapeo: " + manifest_path
 manifest.store_string(JSON.stringify({"version":1,"model":studio.model_path,"atlas":path.get_file(),"size":size,"uv_channel":"TEXCOORD_1 / UV2","surfaces":mappings},"  "))
 manifest.close()
 return ""


