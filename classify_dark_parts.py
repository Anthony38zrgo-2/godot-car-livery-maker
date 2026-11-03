import bpy,pathlib,sys,shutil,datetime,json
p=pathlib.Path(sys.argv[sys.argv.index('--')+1]); stem=p.with_suffix(''); stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S'); backup=p.parent/('backup_clasificacion_'+stamp);backup.mkdir()
for ext in ['.blend','.glb','.json']:
 f=stem.with_suffix(ext)
 if f.exists():shutil.copy2(f,backup/f.name)
report=[]
for o in bpy.context.scene.objects:
 if o.type!='MESH':continue
 used={f.material_index for f in o.data.polygons}; mats=[o.data.materials[i] for i in used if i<len(o.data.materials) and o.data.materials[i]]
 def dark(m):
  if m.name.startswith(('Material_8.','Material_33.','Bargeboards - soportes negro')):return True
  if not m.use_nodes:return max(m.diffuse_color[:3])<0.06
  bs=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
  if bs and not bs.inputs['Base Color'].is_linked:return max(bs.inputs['Base Color'].default_value[:3])<0.06
  return False
 protected=bool(mats) and all(dark(m) for m in mats)
 tyre='Neumatico_' in o.name or 'tyre' in o.name.lower()
 category='protegido_negro' if protected else ('protegido_neumatico' if tyre else 'pendiente')
 if protected and not o.name.startswith('NO_PINTAR_'):o.name='NO_PINTAR_Negro_'+o.name.replace('_REVISAR','')
 elif tyre and not o.name.startswith('NO_PINTAR_'):o.name='NO_PINTAR_'+o.name
 o.data.name=o.name+'_mesh';o['livery_category']=category;o['livery_editable']=not(protected or tyre)
 if protected or tyre:o['classification_review_required']=False
 report.append({'node':o.name,'category':category,'materials':[m.name for m in mats]})
bpy.ops.wm.save_as_mainfile(filepath=str(p))
bpy.ops.export_scene.gltf(filepath=str(stem.with_suffix('.glb')),export_format='GLB',export_animations=False,export_extras=True)
stem.with_suffix('.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print('CLASSIFIED',p.name,'protected',sum(r['category'].startswith('protegido') for r in report))
