extends VBoxContainer

const Shapes = preload("res://studio/vinyl_shapes.gd")
const MAX_LAYERS := 64
var studio: Node
var layers: Array = []
var selected := -1
var pending := false
var dragging := false
var drag_offset := Vector2.ZERO
var syncing := false
var triangles: Array = []
var paintable: Dictionary = {}
var previews: Array[Image] = []
var texture: ImageTexture
var style_cache: Dictionary = {}
var previous_styles := ""
var list: ItemList
var tools: CheckButton
var shape: OptionButton
var number: SpinBox
var fields: Dictionary = {}
var fill: ColorPickerButton
var border_color: ColorPickerButton
var visible_toggle: CheckButton
var locked_toggle: CheckButton
var name_field: LineEdit
var hint: Label
var gizmo: MeshInstance3D

func setup(controller: Node) -> void:
 studio = controller
 gizmo = MeshInstance3D.new()
 gizmo.name = "EditorVinylSelection"
 gizmo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 studio.add_child(gizmo)
 add_theme_font_size_override("font_size", 14)
 tools = CheckButton.new()
 tools.text = "Modo vinilos (desactiva el pincel)"
 tools.button_pressed = true
 tools.toggled.connect(func(value):
  if not value: dragging = false
  update_gizmo()
 )
 add_child(tools)
 var views := HBoxContainer.new()
 add_child(views)
 for spec in [["Lateral izq.",-PI/2,0.12], ["Lateral der.",PI/2,0.12], ["Superior",0.0,1.55], ["Libre",0.7,0.45]]:
  var button := Button.new()
  button.text = spec[0]
  button.pressed.connect(func():
   studio.yaw=spec[1]
   studio.pitch=spec[2]
   studio.camera.projection=Camera3D.PROJECTION_PERSPECTIVE if spec[0]=="Libre" else Camera3D.PROJECTION_ORTHOGONAL
   studio.camera.size=5.8
   studio._update_camera()
  )
  views.add_child(button)
 var library := HBoxContainer.new()
 add_child(library)
 shape = OptionButton.new()
 for index in Shapes.LABELS.size():
  var thumbnail: Image = Shapes.image({"shape":index,"number":1,"color":"ffffffff","border_color":"202020ff","border":0.015})
  thumbnail.resize(32,32,Image.INTERPOLATE_LANCZOS)
  shape.add_icon_item(ImageTexture.create_from_image(thumbnail),Shapes.LABELS[index])
 library.add_child(shape)
 var add := Button.new()
 add.text = "Anadir / colocar"
 add.pressed.connect(func():
  if layers.size() >= MAX_LAYERS: hint.text = "Limite: 64 capas"; return
  pending = true
  selected = -1
  list.deselect_all()
  tools.button_pressed = true
  hint.text = "Haz clic en una superficie pintable del coche"
 )
 library.add_child(add)
 list = ItemList.new()
 list.custom_minimum_size = Vector2(400, 140)
 list.item_selected.connect(func(index): selected = index; pending = false; sync())
 add_child(list)
 var actions := HBoxContainer.new()
 add_child(actions)
 for spec in [["Duplicar", "duplicate"], ["Reflejar", "mirror"], ["Subir", "up"], ["Bajar", "down"], ["Eliminar", "delete"]]:
  var button := Button.new()
  button.text = spec[0]
  button.pressed.connect(action.bind(spec[1]))
  actions.add_child(button)
 name_field = LineEdit.new()
 name_field.placeholder_text = "Nombre de capa"
 name_field.text_submitted.connect(func(value): edit("name", value))
 add_child(name_field)
 var grid := GridContainer.new()
 grid.columns = 4
 add_child(grid)
 fill = ColorPickerButton.new()
 fill.color = Color.WHITE
 fill.custom_minimum_size = Vector2(65, 28)
 fill.color_changed.connect(func(value): edit("color", value.to_html(true)))
 add_control(grid, "Color HEX / opacidad", fill)
 border_color = ColorPickerButton.new()
 border_color.color = Color.BLACK
 border_color.custom_minimum_size = Vector2(65,28)
 border_color.color_changed.connect(func(value): edit("border_color", value.to_html(true)))
 add_control(grid, "Color del borde", border_color)
 for spec in [["width","Ancho (m)",0.02,8.0,0.01,1.0], ["height","Alto (m)",0.02,8.0,0.01,0.3], ["rotation","Giro (grados)",-180.0,180.0,1.0,0.0], ["border","Borde",0.0,0.2,0.005,0.02], ["offset_x","Mover horizontal (m)",-5.0,5.0,0.01,0.0], ["offset_y","Mover vertical (m)",-5.0,5.0,0.01,0.0], ["depth","Profundidad (m)",0.01,0.5,0.01,0.12], ["number","Numero",0.0,99.0,1.0,1.0], ["curve","Curvatura",0.0,1.0,0.01,0.5]]:
  var spin := SpinBox.new()
  spin.min_value = spec[2]
  spin.max_value = spec[3]
  spin.step = spec[4]
  spin.value = spec[5]
  spin.custom_minimum_size.x = 100
  spin.value_changed.connect(func(value): edit(spec[0], value))
  fields[spec[0]] = spin
  add_control(grid, spec[1], spin)
 var toggles := HBoxContainer.new()
 add_child(toggles)
 visible_toggle = CheckButton.new()
 visible_toggle.text = "Visible"
 visible_toggle.toggled.connect(func(value): edit("visible", value))
 toggles.add_child(visible_toggle)
 locked_toggle = CheckButton.new()
 locked_toggle.text = "Bloquear capa"
 locked_toggle.toggled.connect(func(value):
  if syncing or selected < 0: return
  layers[selected].locked = value
  refresh_list()
 )
 toggles.add_child(locked_toggle)
 for degrees in [0, 90]:
  var button := Button.new()
  button.text = "Horizontal" if degrees == 0 else "Vertical"
  button.pressed.connect(func(): edit("rotation", float(degrees)))
  toggles.add_child(button)
 hint = Label.new()
 hint.text = "Anade una forma, colocala en el coche y arrastrala. Orden: abajo a arriba."
 hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 add_child(hint)

func add_control(grid: GridContainer, title: String, control: Control) -> void:
 var label := Label.new()
 label.text = title
 grid.add_child(label)
 grid.add_child(control)

func validate_layers(data: Array) -> String:
 if data.size()>MAX_LAYERS: return "El documento supera el limite de 64 capas"
 for layer in data:
  if not layer is Dictionary: return "Capa invalida"
  for key in ["name","shape","color","border_color","border","origin","right","up","width","height","rotation","depth","target"]:
   if not layer.has(key): return "Falta un parametro de capa: " + key
  for key in ["origin","right","up"]:
   if not layer[key] is Array or layer[key].size()!=3: return "Marco de proyeccion invalido"
   for value in layer[key]:
    if not (value is float or value is int) or not is_finite(float(value)): return "Coordenada invalida"
  for key in ["width","height","depth","rotation","border"]:
   if not (layer[key] is float or layer[key] is int) or not is_finite(float(layer[key])): return "Dimension invalida"
  if float(layer.width)<0.02 or float(layer.height)<0.02 or float(layer.depth)<=0: return "Dimension de capa invalida"
  if int(layer.shape)<0 or int(layer.shape)>=Shapes.LABELS.size(): return "Forma no admitida"
  if not layer.color is String or not layer.border_color is String or not layer.target is String or not layer.name is String: return "Propiedades de capa invalidas"
  var right:=vector(layer.right)
  var up:=vector(layer.up)
  if absf(right.length()-1)>0.02 or absf(up.length()-1)>0.02 or absf(right.dot(up))>0.02: return "Ejes de proyeccion invalidos"
 return ""

func bind_model(data: Array = []) -> void:
 layers = data.duplicate(true)
 selected = -1
 pending = false
 dragging = false
 triangles.clear()
 paintable.clear()
 for entry in studio.body_materials.surfaces: paintable[str(entry.node.name)] = true
 for node in studio.model_root.find_children("*", "MeshInstance3D", true, false):
  if not node.mesh: continue
  for surface in node.mesh.get_surface_count():
   var arrays: Array = node.mesh.surface_get_arrays(surface)
   var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
   var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
   if indices.is_empty():
    for index in vertices.size(): indices.append(index)
   for index in range(0, indices.size(), 3):
    var a: Vector3 = node.global_transform * vertices[indices[index]]
    var b: Vector3 = node.global_transform * vertices[indices[index+1]]
    var c: Vector3 = node.global_transform * vertices[indices[index+2]]
    triangles.append([a,b,c,str(node.name)])
 rebuild()
 sync()

func vector(value: Array) -> Vector3:
 return Vector3(float(value[0]),float(value[1]),float(value[2]))

func packed(value: Vector3) -> Array:
 return [value.x,value.y,value.z]

func hit_test(mouse: Vector2) -> Dictionary:
 var origin: Vector3 = studio.camera.project_ray_origin(mouse)
 var direction: Vector3 = studio.camera.project_ray_normal(mouse)
 var closest := INF
 var result := {}
 for tri in triangles:
  var hit: Variant = Geometry3D.ray_intersects_triangle(origin, direction, tri[0],tri[1],tri[2])
  if hit == null: continue
  var distance: float = origin.distance_squared_to(hit)
  if distance < closest:
   closest = distance
   var normal: Vector3 = (tri[1]-tri[0]).cross(tri[2]-tri[0]).normalized()
   if normal.dot(direction)>0: normal = -normal
   result = {"point": hit, "normal":normal, "node":tri[3]}
 return result

func protected_hit(hit: Dictionary) -> bool:
 if hit.is_empty() or not paintable.has(hit.node) or String(hit.node).begins_with("NO_PINTAR_"): return true
 var point: Vector3 = hit.point
 if studio.component_locks.front.button_pressed and point.z < -1.73 and point.y < 0.32: return true
 if studio.component_locks.rear.button_pressed and point.z > 1.55 and point.y > 0.29: return true
 if studio.component_locks.bargeboards.button_pressed and String(hit.node).contains("Bargeboard_F094H"): return true
 return false

func is_editable() -> bool:
 if selected < 0 or selected >= layers.size() or layers[selected].get("locked", false): return false
 var layer: Dictionary = layers[selected]
 return not protected_hit({"point": center(layer), "node":layer.target})

func center(layer: Dictionary) -> Vector3:
 return vector(layer.origin) + vector(layer.right)*float(layer.get("offset_x",0)) + vector(layer.up)*float(layer.get("offset_y",0))

func axes(layer: Dictionary) -> Array:
 var angle := deg_to_rad(float(layer.rotation))
 var right := vector(layer.right)
 var up := vector(layer.up)
 return [right*cos(angle)+up*sin(angle), up*cos(angle)-right*sin(angle)]

func place(hit: Dictionary) -> void:
 if protected_hit(hit): hint.text = "Esta superficie esta protegida o bloqueada"; return
 if not studio.supports_vinyls(): hint.text = "Los vinilos requieren el shader predeterminado o uno compatible"; return
 var normal: Vector3 = hit.normal
 var right: Vector3 = studio.camera.global_basis.x
 right = (right-normal*right.dot(normal)).normalized()
 if right.length()<0.1: right=normal.cross(Vector3.FORWARD).normalized()
 var up := normal.cross(right).normalized()
 var layer := {"name":Shapes.LABELS[shape.selected]+" "+str(layers.size()+1), "shape":shape.selected, "number":int(fields.number.value), "color":fill.color.to_html(true), "border_color":border_color.color.to_html(true), "border":fields.border.value, "curve":fields.curve.value, "origin":packed(hit.point), "right":packed(right), "up":packed(up), "width":fields.width.value, "height":fields.height.value, "rotation":fields.rotation.value, "depth":fields.depth.value, "offset_x":0.0,"offset_y":0.0,"target":hit.node,"visible":true,"locked":false,"protection":studio._lock_settings()}
 layers.append(layer)
 selected=layers.size()-1
 pending=false
 rebuild()
 sync()

func edit(property: String, value: Variant) -> void:
 if syncing or selected<0: return
 if not is_editable(): hint.text = "Desbloquea la capa o el componente para editar"; sync(); return
 layers[selected][property] = value
 layers[selected].protection = studio._lock_settings()
 rebuild()

func action(command: String) -> void:
 if not is_editable(): hint.text = "Selecciona una capa desbloqueada"; return
 match command:
  "delete": layers.remove_at(selected); selected=mini(selected,layers.size()-1)
  "duplicate", "mirror":
   if layers.size()>=MAX_LAYERS: hint.text="Limite: 64 capas"; return
   var copy: Dictionary = layers[selected].duplicate(true)
   copy.name += " copia" if command=="duplicate" else " reflejo"
   if command=="mirror":
    for key in ["origin","right","up"]: copy[key][0] = -float(copy[key][0])
    # Reverse horizontal direction to keep numbers readable on the opposite side.
    copy.right = packed(-vector(copy.right))
    copy.offset_x = -float(copy.offset_x)
    copy.rotation = -float(copy.rotation)
    if String(copy.target).contains("Izquierdo"): copy.target=String(copy.target).replace("Izquierdo","Derecho")
    elif String(copy.target).contains("Derecho"): copy.target=String(copy.target).replace("Derecho","Izquierdo")
   layers.append(copy)
   selected=layers.size()-1
  "up":
   if selected<layers.size()-1:
    var value=layers[selected];layers[selected]=layers[selected+1];layers[selected+1]=value;selected+=1
  "down":
   if selected>0:
    var value=layers[selected];layers[selected]=layers[selected-1];layers[selected-1]=value;selected-=1
 rebuild()
 sync()

func refresh_list() -> void:
 list.clear()
 for layer in layers:
  list.add_item(("[bloqueada] " if layer.get("locked",false) else "") + ("[oculta] " if not layer.get("visible",true) else "") + str(layer.name))
 if selected>=0: list.select(selected)

func sync() -> void:
 syncing=true
 refresh_list()
 if selected>=0 and selected<layers.size():
  var layer:Dictionary=layers[selected]
  name_field.text=layer.name
  fill.color=Color.from_string(layer.color,Color.WHITE)
  border_color.color=Color.from_string(layer.border_color,Color.BLACK)
  for key in fields: fields[key].value=layer.get(key,fields[key].value)
  visible_toggle.set_pressed_no_signal(layer.get("visible",true))
  locked_toggle.set_pressed_no_signal(layer.get("locked",false))
 syncing=false
 update_gizmo()

func update_gizmo() -> void:
 if not is_instance_valid(gizmo): return
 gizmo.visible = selected >= 0 and selected < layers.size() and tools.button_pressed
 if not gizmo.visible: return
 var layer:Dictionary=layers[selected]
 var basis:=axes(layer)
 var right:Vector3=basis[0]*float(layer.width)*0.5
 var up:Vector3=basis[1]*float(layer.height)*0.5
 var origin:=center(layer)
 var corners: Array[Vector3] = [origin-right-up,origin+right-up,origin+right+up,origin-right+up]
 var material:=StandardMaterial3D.new()
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.no_depth_test=true
 material.albedo_color=Color(1,0.8,0.1)
 var mesh:=ImmediateMesh.new()
 mesh.surface_begin(Mesh.PRIMITIVE_LINES,material)
 for index in 4:
  mesh.surface_add_vertex(corners[index])
  mesh.surface_add_vertex(corners[(index+1)%4])
 mesh.surface_end()
 gizmo.mesh=mesh

func rebuild() -> void:
 previews.clear()
 var styles: Array = []
 for layer in layers:
  var key := JSON.stringify([layer.shape,layer.get("number",1),layer.color,layer.border_color,layer.border,layer.get("curve",0.5)])
  styles.append(key)
  if not style_cache.has(key):
   if style_cache.size() >= 128: style_cache.erase(style_cache.keys()[0])
   var image: Image = Shapes.image(layer)
   image.convert(Image.FORMAT_RGBA8)
   style_cache[key] = image
  previews.append(style_cache[key])
 var signature := JSON.stringify(styles)
 if signature != previous_styles or texture == null:
  var atlas := Image.create(2048,2048,false,Image.FORMAT_RGBA8)
  for index in previews.size():
   atlas.blit_rect(previews[index],Rect2i(0,0,256,256),Vector2i((index%8)*256,(index/8)*256))
  texture=ImageTexture.create_from_image(atlas)
  previous_styles=signature
 if not is_instance_valid(studio.model_root): return
 for node in studio.model_root.find_children("*","MeshInstance3D",true,false):
  var material:=node.material_overlay as ShaderMaterial
  if not material: continue
  var origins:=PackedVector4Array()
  var rights:=PackedVector4Array()
  var ups:=PackedVector4Array()
  var protections:=PackedVector4Array()
  for index in MAX_LAYERS:
   if index>=layers.size():
    origins.append(Vector4(0,0,0,-1));rights.append(Vector4.ZERO);ups.append(Vector4.ZERO);protections.append(Vector4.ZERO);continue
   var layer:Dictionary=layers[index]
   var protection:Dictionary=layer.get("protection",{})
   protections.append(Vector4(1.0 if protection.get("front",false) else 0.0,1.0 if protection.get("rear",false) else 0.0,1.0 if protection.get("bargeboards",false) else 0.0,0.0))
   var point:=center(layer)
   var basis:=axes(layer)
   var right:Vector3=basis[0]
   var up:Vector3=basis[1]
   var active:bool=layer.get("visible",true) and str(node.name)==str(layer.target) and paintable.has(str(node.name))
   origins.append(Vector4(point.x,point.y,point.z,float(layer.depth) if active else -1.0))
   rights.append(Vector4(right.x,right.y,right.z,float(layer.width)))
   ups.append(Vector4(up.x,up.y,up.z,float(layer.height)))
  material.set_shader_parameter("vinyl_count",layers.size())
  material.set_shader_parameter("vinyl_atlas",texture)
  material.set_shader_parameter("vinyl_origins",origins)
  material.set_shader_parameter("vinyl_rights",rights)
  material.set_shader_parameter("vinyl_ups",ups)
  material.set_shader_parameter("vinyl_protections",protections)
 refresh_list()
 update_gizmo()

func select_at(hit: Dictionary) -> void:
 selected=-1
 if hit.is_empty(): sync(); return
 for index in range(layers.size()-1,-1,-1):
  var layer:Dictionary=layers[index]
  if not layer.get("visible",true) or layer.target!=hit.node:continue
  var basis:=axes(layer)
  var delta:Vector3=hit.point-center(layer)
  var uv:=Vector2(delta.dot(basis[0])/float(layer.width)+0.5,0.5-delta.dot(basis[1])/float(layer.height))
  if uv.x<0 or uv.y<0 or uv.x>=1 or uv.y>=1:continue
  if absf(delta.dot(basis[0].cross(basis[1])))>float(layer.depth):continue
  if previews[index].get_pixelv(Vector2i(uv*256)).a>0.05:selected=index;break
 sync()

func handle(event: InputEvent) -> bool:
 if not tools.button_pressed:return false
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if not event.pressed:dragging=false;return true
  var hit:=hit_test(event.position)
  if pending:place(hit)
  else:
   select_at(hit)
   dragging=is_editable()
   if dragging:
    var delta:Vector3=center(layers[selected])-hit.point
    drag_offset=Vector2(delta.dot(vector(layers[selected].right)),delta.dot(vector(layers[selected].up)))
  return true
 if event is InputEventMouseMotion and dragging:
  if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
   dragging=false
   return false
  var hit:=hit_test(event.position)
  if not protected_hit(hit) and is_editable() and hit.node==layers[selected].target:
   var right := vector(layers[selected].right)
   var normal: Vector3 = hit.normal
   right = (right - normal * right.dot(normal)).normalized()
   if right.length() > 0.1:
    layers[selected].right=packed(right)
    layers[selected].up=packed(normal.cross(right).normalized())
   layers[selected].origin=packed(hit.point + vector(layers[selected].right)*drag_offset.x + vector(layers[selected].up)*drag_offset.y)
   layers[selected].protection=studio._lock_settings()
   layers[selected].offset_x=0.0;layers[selected].offset_y=0.0
   rebuild()
  return true
 return false
