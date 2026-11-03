import bpy,pathlib,sys,json
src=pathlib.Path(sys.argv[sys.argv.index('--')+1]); out=src.with_name(src.stem+'_partes')
if out.with_suffix('.blend').exists() or out.with_suffix('.glb').exists():raise RuntimeError('Output exists')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(src))
for o in list(bpy.context.scene.objects):
 if o.type!='MESH':continue
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
 if len(o.data.materials)>1:
  bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.separate(type='MATERIAL');bpy.ops.object.mode_set(mode='OBJECT')
report=[]
for o in bpy.context.scene.objects:
 if o.type!='MESH':continue
 original=o.name; mats=[m.name for m in o.data.materials if m]; mat=mats[0] if mats else ''
 if 'tyre' in original: name='Neumatico_'+original
 elif original.startswith('wheel_'):name='Conjunto_rin_'+original
 elif original.startswith('body_lod0'):
  if mat.startswith('Benetton'):name='Carroceria_atlas'
  elif mat.startswith('Material_8.'):name='Superficies_negras_mixtas_REVISAR'
  elif mat.startswith('Material_9.'):name='Superficies_recorte_alfa_REVISAR'
  else:name='Detalles_carroceria_REVISAR'
 else:name=original
 o.name=name;o.data.name=name+'_mesh';o['source_node']=original;o['classification_review_required']='REVISAR' in name
 report.append({'name':o.name,'source_node':original,'materials':mats,'triangles':len(o.data.polygons),'review_required':'REVISAR' in name})
bpy.ops.wm.save_as_mainfile(filepath=str(out.with_suffix('.blend')))
bpy.ops.export_scene.gltf(filepath=str(out.with_suffix('.glb')),export_format='GLB',export_animations=False)
out.with_suffix('.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print('NAMED',out)
