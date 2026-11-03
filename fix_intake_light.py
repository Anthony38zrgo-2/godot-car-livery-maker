import bpy,pathlib,sys,shutil,datetime
from mathutils import Vector
p=pathlib.Path(sys.argv[sys.argv.index('--')+1]);source=p.parent/(p.parent.name+'.blend');backup=p.parent/('backup_luz_toma_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S'));backup.mkdir()
for ext in ['.blend','.glb','.json']:
 f=p.with_suffix(ext)
 if f.exists():shutil.copy2(f,backup/f.name)
with bpy.data.libraries.load(str(source),link=False) as (a,b):b.objects=['body_lod0.001']
original=b.objects[0]
def key(v):return tuple(round(x,4) for x in v)
def facekey(o,poly):return tuple(sorted(key(o.matrix_world@o.data.vertices[i].co) for i in poly.vertices))
lookup={}
for poly in original.data.polygons:
 vs=[original.matrix_world@original.data.vertices[i].co for i in poly.vertices]
 if all(abs(v.x)<.105 and .054<v.y<.12 and .74<v.z<.94 for v in vs):lookup[facekey(original,poly)]=poly
body=bpy.data.objects.get('Carroceria_atlas');found=[]
for poly in body.data.polygons:
 if facekey(body,poly) in lookup:found.append(poly)
if len(found)!=32:raise RuntimeError(f'Expected 32 inlet faces: {len(found)}')
mat=original.data.materials[lookup[facekey(body,found[0])].material_index].copy();mat.name='Toma_aire_material_original';body.data.materials.append(mat);slot=len(body.data.materials)-1
for poly in body.data.polygons:poly.select=False
for poly in found:
 old=lookup[facekey(body,poly)];uvs={key(original.matrix_world@original.data.vertices[original.data.loops[i].vertex_index].co):original.data.uv_layers[0].data[i].uv.copy() for i in old.loop_indices}
 for i in poly.loop_indices:body.data.uv_layers[0].data[i].uv=uvs[key(body.matrix_world@body.data.vertices[body.data.loops[i].vertex_index].co)]
 poly.material_index=slot;poly.select=True
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.separate(type='SELECTED');bpy.ops.object.mode_set(mode='OBJECT')
intake=next(o for o in bpy.context.selected_objects if o!=body);intake.name='NO_PINTAR_Toma_aire_motor';intake.data.name='Toma_aire_motor_mesh';intake['livery_editable']=False;intake['livery_category']='protegido_toma_aire'
lights=[]
for o in bpy.context.scene.objects:
 if o.type!='MESH':continue
 used={f.material_index for f in o.data.polygons}
 mats=[o.data.materials[i] for i in used]
 if mats and all(m and m.name.startswith('Material_9.') for m in mats):
  o.name='NO_PINTAR_Luz_trasera';o.data.name='Luz_trasera_mesh';o['livery_editable']=False;o['livery_category']='protegido_luz';lights.append(o)
 if 'Bargeboard_F094H' in o.name:
  o['livery_editable']=True;o['livery_category']='carroceria'
if len(lights)!=1:raise RuntimeError('Expected rear light')
bpy.data.objects.remove(original,do_unlink=True)
bpy.ops.wm.save_as_mainfile(filepath=str(p));bpy.ops.export_scene.gltf(filepath=str(p.with_suffix('.glb')),export_format='GLB',export_animations=False,export_extras=True)
print('FIXED',p.name,'intake',len(found),'lights',len(lights))
