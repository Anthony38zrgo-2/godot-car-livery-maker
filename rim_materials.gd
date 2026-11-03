extends RefCounted

const FINISHES = preload("res://base_body_materials.gd").FINISHES
var surfaces: Array[Dictionary] = []

func collect(root: Node) -> void:
	surfaces.clear()
	_visit(root)

func _visit(node: Node) -> void:
	if node is MeshInstance3D and node.mesh and String(node.name).begins_with("Conjunto_rin_"):
		for index in node.mesh.get_surface_count():
			var original: Material = node.get_active_material(index)
			if not original is StandardMaterial3D:
				continue
			var name: String = original.resource_name
			var group := ""
			if name.begins_with("Material_31."): group = "rim1"
			elif name.begins_with("Material_30."): group = "rim2"
			elif name.begins_with("Material_29."): group = "rim3"
			else: continue
			var material := original.duplicate() as StandardMaterial3D
			material.vertex_color_use_as_albedo = false
			material.set_texture(BaseMaterial3D.TEXTURE_ROUGHNESS, null)
			material.set_texture(BaseMaterial3D.TEXTURE_METALLIC, null)
			if group == "rim2":
				material.albedo_texture = null
			elif original.albedo_texture:
				var image: Image = original.albedo_texture.get_image()
				if image.is_compressed(): image.decompress()
				image.convert(Image.FORMAT_RGBA8)
				var peak := 0.001
				for y in image.get_height():
					for x in image.get_width():
						var pixel := image.get_pixel(x, y)
						peak = maxf(peak, maxf(pixel.r, maxf(pixel.g, pixel.b)))
				for y in image.get_height():
					for x in image.get_width():
						var pixel := image.get_pixel(x, y)
						# Preserve cutout coverage; keep the centre's shading and black recesses.
						var shade := 1.0 if name.begins_with("Material_29.") else maxf(pixel.r, maxf(pixel.g, pixel.b)) / peak
						image.set_pixel(x, y, Color(shade, shade, shade, pixel.a))
				material.albedo_texture = ImageTexture.create_from_image(image)
			surfaces.append({"node": node, "index": index, "group": group, "original": original, "base": material})
	for child in node.get_children(): _visit(child)

func apply(group: String, enabled: bool, color: Color, finish: int) -> void:
	var values: Vector2 = FINISHES[clampi(finish, 0, 3)]
	for entry in surfaces:
		if entry.group != group or not is_instance_valid(entry.node): continue
		var material: StandardMaterial3D = entry.base
		material.albedo_color = Color(color.r, color.g, color.b, 1)
		material.roughness = values.x
		material.metallic = values.y
		entry.node.set_surface_override_material(entry.index, material if enabled else entry.original)
