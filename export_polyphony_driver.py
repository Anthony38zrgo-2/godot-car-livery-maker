"""Export the visible LOD0 driver's helmet and body from an original blend."""
import bpy
import bmesh
import pathlib
import sys

output = pathlib.Path(sys.argv[sys.argv.index('--') + 1])
if output.exists():
    raise RuntimeError(f'Output already exists: {output}')
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
source = bpy.data.objects['body_lod0']
parts = []
for material_name, name, expected in [('Material_1', 'Casco', 132), ('Material_2', 'Cuerpo_piloto', 76)]:
    indices = {p.index for p in source.data.polygons if source.data.materials[p.material_index].name == material_name}
    if len(indices) != expected:
        raise RuntimeError(f'{material_name}: expected {expected} faces, got {len(indices)}')
    obj = source.copy()
    obj.data = source.data.copy()
    obj.name = name
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in indices], context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.to_mesh(obj.data)
    bm.free()
    while len(obj.data.uv_layers) > 1:
        obj.data.uv_layers.remove(obj.data.uv_layers[-1])
    obj.data.uv_layers.new(name='PaintUV')
    obj.data.uv_layers.active_index = 1
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(island_margin=0.015)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.data.uv_layers.active_index = 0
    parts.append(obj)
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', use_selection=True, export_animations=False)
print('PILOT_EXPORTED', output)
