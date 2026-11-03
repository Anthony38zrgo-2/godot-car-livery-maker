extends RefCounted

var surfaces: Array[Dictionary] = []
const FINISHES := [Vector2(0.9, 0.0), Vector2(0.45, 0.0), Vector2(0.16, 0.0), Vector2(0.25, 0.75)]

func collect(root: Node) -> void:
	surfaces.clear()
	_visit(root)

func _visit(node: Node) -> void:
	if node is MeshInstance3D and node.mesh and not String(node.name).begins_with("NO_PINTAR_"):
		for index in node.mesh.get_surface_count():
			var original: Material = node.get_active_material(index)
			if not original is StandardMaterial3D:
				continue
			var name: String = original.resource_name
			if not (name.begins_with("Benetton B195 - atlas") or name.begins_with("Bargeboards - blanco sin patrocinio")):
				continue
			var material := original.duplicate() as StandardMaterial3D
			material.set_texture(BaseMaterial3D.TEXTURE_ALBEDO, null)
			material.vertex_color_use_as_albedo = false
			material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			material.set_texture(BaseMaterial3D.TEXTURE_ROUGHNESS, null)
			material.set_texture(BaseMaterial3D.TEXTURE_METALLIC, null)
			surfaces.append({"node": node, "index": index, "original": original, "base": material})
	for child in node.get_children():
		_visit(child)

func apply(enabled: bool, color: Color, finish: int) -> void:
	var values: Vector2 = FINISHES[clampi(finish, 0, FINISHES.size() - 1)]
	for entry in surfaces:
		if not is_instance_valid(entry.node):
			continue
		var material: StandardMaterial3D = entry.base
		material.albedo_color = Color(color.r, color.g, color.b, 1.0)
		material.roughness = values.x
		material.metallic = values.y
		entry.node.set_surface_override_material(entry.index, material if enabled else entry.original)
