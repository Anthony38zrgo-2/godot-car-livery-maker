"""Run with Blender -b INPUT.blend --python prepare_polyphony.py -- OUTPUT_DIR."""
import bpy
import bmesh
import pathlib
import sys

out = pathlib.Path(sys.argv[sys.argv.index('--') + 1])
name = pathlib.Path(bpy.data.filepath).stem
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
body = bpy.data.objects['body_lod0']
head_indices = {p.index for p in body.data.polygons if body.data.materials[p.material_index].name == 'Material_1'}
if len(head_indices) != 132:
    raise RuntimeError(f'{name}: unexpected helmet face count {len(head_indices)}')

visible = [o for o in bpy.context.view_layer.objects if o.visible_get() and o.type in {'MESH', 'CURVE'}]
bpy.ops.object.select_all(action='DESELECT')
for obj in visible:
    obj.select_set(True)
    if obj.type == 'MESH':
        obj.data = obj.data.copy()

helmet = body.copy()
helmet.data = body.data.copy()
bpy.context.collection.objects.link(helmet)
helmet.name = 'Helmet'
for obj, remove_head in [(body, True), (helmet, False)]:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    remove = [f for f in bm.faces if (f.index in head_indices) == remove_head]
    bmesh.ops.delete(bm, geom=remove, context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.to_mesh(obj.data)
    bm.free()

def unwrap(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    if obj.type != 'MESH':
        bpy.ops.object.convert(target='MESH')
    mesh = obj.data
    # Preserve per-material texture coordinates in UV0 before dedicating UV1
    # to the paint overlay. Some source materials explicitly use Benetton_atlas.
    if mesh.uv_layers:
        uv0 = mesh.uv_layers[0]
        for poly in mesh.polygons:
            mat = mesh.materials[poly.material_index] if poly.material_index < len(mesh.materials) else None
            if not mat or not mat.use_nodes:
                continue
            uv_nodes = [n for n in mat.node_tree.nodes if n.type == 'UVMAP' and n.uv_map]
            names = {n.uv_map for n in uv_nodes}
            if len(names) > 1:
                raise RuntimeError(f'{obj.name}: material uses multiple explicit UV maps')
            if names:
                source = mesh.uv_layers.get(next(iter(names)))
                if source is None:
                    raise RuntimeError(f'{obj.name}: missing UV map {next(iter(names))}')
                for index in poly.loop_indices:
                    uv0.data[index].uv = source.data[index].uv[:]
    while len(mesh.uv_layers) > 1:
        mesh.uv_layers.remove(mesh.uv_layers[-1])
    if not mesh.uv_layers:
        mesh.uv_layers.new(name='UVMap')
    mesh.uv_layers.new(name='PaintUV')
    mesh.uv_layers.active_index = 1
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(island_margin=0.015)
    bpy.ops.object.mode_set(mode='OBJECT')
    mesh.uv_layers.active_index = 0
    # Export from independent material copies so explicit UV nodes use UV0.
    for index, mat in enumerate(mesh.materials):
        if mat and mat.use_nodes:
            mat = mat.copy()
            mesh.materials[index] = mat
            for node in mat.node_tree.nodes:
                if node.type == 'UVMAP' and node.uv_map:
                    node.uv_map = mesh.uv_layers[0].name

def export(objects, path):
    if path.exists():
        raise RuntimeError(f'Refusing to overwrite {path}')
    for obj in objects:
        unwrap(obj)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True, export_animations=False)

out.joinpath('helmets').mkdir(exist_ok=True)
export(visible, out / 'models' / name / (name + '_sin_casco.glb'))
export([helmet], out / 'helmets' / (name + '_casco.glb'))
print('PREPARED', name, len(head_indices))
