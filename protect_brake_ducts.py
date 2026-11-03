import bpy,pathlib,sys,datetime,shutil,json
p=pathlib.Path(sys.argv[sys.argv.index('--')+1]);backup=p.parent/('backup_conductos_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S'));backup.mkdir()
for ext in ['.blend','.glb','.json']:
 f=p.with_suffix(ext)
 if f.exists():shutil.copy2(f,backup/f.name)
with bpy.data.libraries.load(str(p.parent/(p.parent.name+'.blend')),link=False) as (a,b):b.objects=['body_lod0.001']
source=b.objects[0]
def key(v):return tuple(round(x,4) for x in v)
def fk(o,poly):return tuple(sorted(key(o.matrix_world@o.data.vertices[i].co) for i in poly.vertices))
lookup={fk(source,poly):poly for poly in source.data.polygons if source.data.materials[poly.material_index].name.split('.')[0] in ['Material_11','Material_12']}
body=bpy.data.objects['Carroceria_atlas'];found=[poly for poly in body.data.polygons if fk(body,poly) in lookup]
if len(found)!=18:raise RuntimeError(f'Expected 18 duct faces, found {len(found)}')
slots={}
for poly in body.data.polygons:poly.select=False
for poly in found:
 old=lookup[fk(body,poly)];mat=source.data.materials[old.material_index]
 if mat.name not in slots:
  copy=mat.copy();copy.name='Conducto_freno_'+mat.name;body.data.materials.append(copy);slots[mat.name]=len(body.data.materials)-1
 poly.material_index=slots[mat.name];poly.select=True
 uv={key(source.matrix_world@source.data.vertices[source.data.loops[i].vertex_index].co):source.data.uv_layers[0].data[i].uv.copy() for i in old.loop_indices}
 for i in poly.loop_indices:body.data.uv_layers[0].data[i].uv=uv[key(body.matrix_world@body.data.vertices[body.data.loops[i].vertex_index].co)]
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.separate(type='SELECTED');bpy.ops.object.mode_set(mode='OBJECT')
duct=next(o for o in bpy.context.selected_objects if o!=body);duct.name='NO_PINTAR_Conductos_freno_delanteros';duct.data.name='Conductos_freno_delanteros_mesh';duct['livery_editable']=False;duct['livery_category']='protegido_conductos_freno'
bpy.data.objects.remove(source,do_unlink=True)
bpy.ops.wm.save_as_mainfile(filepath=str(p));bpy.ops.export_scene.gltf(filepath=str(p.with_suffix('.glb')),export_format='GLB',export_animations=False,export_extras=True)
report=[{'node':o.name,'editable':not o.name.startswith('NO_PINTAR_'),'materials':[m.name for m in o.data.materials if m]} for o in bpy.context.scene.objects if o.type=='MESH'];p.with_suffix('.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print('DUCTS_PROTECTED',p.name,len(found))
