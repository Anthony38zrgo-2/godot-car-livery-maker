extends Node3D

const BASE := "../extracted/cars/polyphony001"
var models_dir: String
var liveries_dir: String
var model_path := ""
var model_root: Node3D
var manager: OverlayAtlasManager
var brush: CameraBrush
var camera: Camera3D
var dialog: FileDialog
var status: Label
var color_picker: ColorPickerButton
var brush_size: HSlider
var atlas_size_control: OptionButton
var projection_control: OptionButton
var fov_control: SpinBox
var size_control: SpinBox
var brush_enabled: CheckButton
var shader_path := ""
var applied_shader_path := ""
var apply_confirmation: ConfirmationDialog
var yaw := 0.7
var pitch := 0.45
var distance := 7.0
var target := Vector3(0, 0.5, 0)
var painting := false
var body_materials = preload("res://base_body_materials.gd").new()
var base_enabled: CheckButton
var base_color: ColorPickerButton
var base_finish: OptionButton
var rim_materials = preload("res://rim_materials.gd").new()
var rim_controls: Dictionary = {}
var component_locks: Dictionary = {}
var vinyl_editor: VBoxContainer
var vinyl_window: Window
var settings_panel: PanelContainer

func _ready() -> void:
	var base := ProjectSettings.globalize_path("res://" + BASE).simplify_path()
	models_dir = base.path_join("models")
	liveries_dir = base.path_join("liveries")
	DirAccess.make_dir_recursive_absolute(liveries_dir)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.16, 0.18, 0.21)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.8
	env.environment = environment
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	add_child(light)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	_update_camera()
	brush = CameraBrush.new()
	brush.projection = Camera3D.PROJECTION_ORTHOGONAL
	brush.size = 0.12
	brush.max_distance = 20.0
	brush.min_bleed = 1
	brush.max_bleed = 1
	add_child(brush)
	_build_ui()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	layer.add_child(panel)
	settings_panel = panel
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "GT3 Livery Studio"
	box.add_child(title)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	for spec in [["Abrir GLB", "model"], ["Abrir librea", "open"], ["Guardar librea", "save"]]:
		var button := Button.new()
		button.text = spec[0]
		button.pressed.connect(_show_dialog.bind(spec[1]))
		buttons.add_child(button)
	var vinyl_button := Button.new()
	vinyl_button.text = "Vinilos por capas..."
	vinyl_button.pressed.connect(func():
		vinyl_window.popup()
		vinyl_editor.tools.button_pressed = true
		settings_panel.hide()
		_update_camera()
	)
	box.add_child(vinyl_button)
	vinyl_window = Window.new()
	vinyl_window.title = "Vinilos - formas y numeros"
	vinyl_window.size = Vector2i(560, 690)
	vinyl_window.position = Vector2i(20,40)
	vinyl_window.min_size = Vector2i(540,400)
	vinyl_window.close_requested.connect(func():
		vinyl_window.hide()
		vinyl_editor.tools.button_pressed = false
		settings_panel.show()
		_update_camera()
	)
	layer.add_child(vinyl_window)
	vinyl_window.hide()
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vinyl_window.add_child(scroll)
	vinyl_editor = preload("res://studio/vinyl_editor.gd").new()
	scroll.add_child(vinyl_editor)
	vinyl_editor.setup(self)
	vinyl_editor.tools.button_pressed = false
	var base_controls := HBoxContainer.new()
	box.add_child(base_controls)
	base_enabled = CheckButton.new()
	base_enabled.text = "Color base carroceria"
	base_controls.add_child(base_enabled)
	base_color = ColorPickerButton.new()
	base_color.color = Color.WHITE
	base_color.edit_alpha = false
	base_color.custom_minimum_size = Vector2(70, 32)
	base_color.tooltip_text = "Color exacto mediante HEX en el selector"
	base_controls.add_child(base_color)
	base_finish = OptionButton.new()
	for finish_name in ["Mate", "Satinado", "Brillante", "Metalizado"]:
		base_finish.add_item(finish_name)
	base_finish.select(2)
	base_controls.add_child(base_finish)
	base_enabled.toggled.connect(func(_v): _apply_base())
	base_color.color_changed.connect(func(_v): base_enabled.button_pressed = true; _apply_base())
	base_finish.item_selected.connect(func(_v): _apply_base())
	_build_rim_controls(box, "rim1", "Rin 1 - centro", Color("404040"))
	_build_rim_controls(box, "rim2", "Rin 2 - anillo intermedio", Color("b59628"))
	_build_rim_controls(box, "rim3", "Rin 3 - anillo exterior", Color("404040"))
	var lock_row := HBoxContainer.new()
	box.add_child(lock_row)
	for spec in [["front", "Bloquear aleron delantero"], ["rear", "Bloquear aleron trasero"], ["bargeboards", "Bloquear bargeboards"]]:
		var check := CheckButton.new()
		check.text = spec[1]
		lock_row.add_child(check)
		component_locks[spec[0]] = check
		check.toggled.connect(func(_v): _apply_component_locks())
	var controls := HBoxContainer.new()
	box.add_child(controls)
	color_picker = ColorPickerButton.new()
	color_picker.color = Color.RED
	color_picker.custom_minimum_size = Vector2(65, 32)
	controls.add_child(color_picker)
	var label := Label.new()
	label.text = "Pincel"
	controls.add_child(label)
	brush_size = HSlider.new()
	brush_size.min_value = 0.02
	brush_size.max_value = 0.8
	brush_size.step = 0.01
	brush_size.value = 0.12
	brush_size.custom_minimum_size.x = 150
	controls.add_child(brush_size)
	var options := GridContainer.new()
	options.columns = 4
	box.add_child(options)
	atlas_size_control = OptionButton.new()
	for value in [512, 1024, 2048, 4096]:
		atlas_size_control.add_item(str(value), value)
	atlas_size_control.select(2)
	_add_control(options, "Atlas (proximo modelo)", atlas_size_control)
	projection_control = OptionButton.new()
	projection_control.add_item("Ortogonal", Camera3D.PROJECTION_ORTHOGONAL)
	projection_control.add_item("Perspectiva", Camera3D.PROJECTION_PERSPECTIVE)
	projection_control.item_selected.connect(func(index: int): brush.projection = projection_control.get_item_id(index))
	_add_control(options, "Proyeccion", projection_control)
	size_control = _number(options, "Tamano ortogonal", 0.01, 10.0, 0.01, 0.12, func(v): brush.size = v; brush_size.value = clampf(v, brush_size.min_value, brush_size.max_value))
	brush_size.value_changed.connect(func(v): size_control.value = v)
	fov_control = _number(options, "FOV perspectiva", 0.1, 179.0, 0.1, 5.0, func(v): brush.fov = v)
	_number(options, "Distancia maxima", 0.1, 1000.0, 0.1, 20.0, func(v): brush.max_distance = v)
	_number(options, "Inicio desvanecimiento", 0.0, 1.0, 0.01, 1.0, func(v): brush.start_distance_fade = v)
	_number(options, "Sangrado minimo", 0, 16, 1, 1, func(v): brush.min_bleed = int(v))
	_number(options, "Sangrado maximo", 0, 16, 1, 1, func(v): brush.max_bleed = int(v))
	_number(options, "Resolucion pincel", 64, 2048, 64, 256, func(v): brush.resolution = Vector2i(int(v), int(v)))
	_number(options, "Velocidad", 0.1, 500.0, 0.1, 100.0, func(v): brush.draw_speed = v)
	brush_enabled = CheckButton.new()
	brush_enabled.button_pressed = true
	_add_control(options, "Pintura habilitada", brush_enabled)
	var shape_button := Button.new()
	shape_button.text = "Elegir imagen..."
	shape_button.pressed.connect(_show_dialog.bind("shape"))
	_add_control(options, "Forma del pincel", shape_button)
	var shader_button := Button.new()
	shader_button.text = "Elegir shader..."
	shader_button.pressed.connect(_show_dialog.bind("shader"))
	_add_control(options, "Shader (proximo modelo)", shader_button)
	var apply_button := Button.new()
	apply_button.text = "Aplicar atlas..."
	apply_button.pressed.connect(func(): apply_confirmation.popup_centered())
	_add_control(options, "Recrear atlas", apply_button)
	status = Label.new()
	status.text = "Abre un GLB. Izquierdo: pintar | Derecho: orbitar | Rueda: zoom"
	box.add_child(status)
	dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	layer.add_child(dialog)
	dialog.file_selected.connect(_selected)
	apply_confirmation = ConfirmationDialog.new()
	apply_confirmation.dialog_text = "Se recreara el atlas y se perdera la pintura actual no guardada. Guarda la librea primero si deseas conservarla."
	apply_confirmation.confirmed.connect(func():
		if not model_path.is_empty(): _load_model(model_path, "", vinyl_editor.layers)
	)
	layer.add_child(apply_confirmation)

func _build_rim_controls(box: VBoxContainer, group: String, title: String, initial: Color) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var enabled := CheckButton.new()
	enabled.text = title
	row.add_child(enabled)
	var color := ColorPickerButton.new()
	color.color = initial
	color.edit_alpha = false
	color.custom_minimum_size = Vector2(70, 32)
	row.add_child(color)
	var finish := OptionButton.new()
	for label in ["Mate", "Satinado", "Brillante", "Metalizado"]: finish.add_item(label)
	finish.select(3)
	row.add_child(finish)
	rim_controls[group] = {"enabled": enabled, "color": color, "finish": finish}
	enabled.toggled.connect(func(_v): _apply_rims())
	color.color_changed.connect(func(_v): enabled.button_pressed = true; _apply_rims())
	finish.item_selected.connect(func(_v): _apply_rims())

func _apply_rims() -> void:
	for group in rim_controls:
		var controls: Dictionary = rim_controls[group]
		rim_materials.apply(group, controls.enabled.button_pressed, controls.color.color, controls.finish.selected)

func _rim_settings() -> Dictionary:
	var settings := {}
	for group in rim_controls:
		var controls: Dictionary = rim_controls[group]
		settings[group] = {"enabled": controls.enabled.button_pressed, "color": controls.color.color.to_html(true), "finish": controls.finish.selected}
	return settings

func _restore_rims(settings: Dictionary) -> void:
	for group in rim_controls:
		var controls: Dictionary = rim_controls[group]
		# Migrate the former two-zone document without changing its appearance.
		var legacy_group := "outer" if group == "rim2" else "inner"
		var values: Dictionary = settings.get(group, settings.get(legacy_group, {}))
		controls.enabled.set_pressed_no_signal(values.get("enabled", false))
		controls.color.color = Color.from_string(values.get("color", "b59628" if group == "rim2" else "404040"), Color.WHITE)
		controls.finish.select(clampi(int(values.get("finish", 3)), 0, 3))

func _add_control(grid: GridContainer, label_text: String, control: Control) -> void:
	var label := Label.new()
	label.text = label_text
	grid.add_child(label)
	grid.add_child(control)

func _number(grid: GridContainer, label_text: String, minimum: float, maximum: float, step: float, value: float, callback: Callable) -> SpinBox:
	var control := SpinBox.new()
	control.min_value = minimum
	control.max_value = maximum
	control.step = step
	control.value = value
	control.custom_minimum_size.x = 105
	control.value_changed.connect(callback)
	_add_control(grid, label_text, control)
	return control

func _show_dialog(mode: String) -> void:
	dialog.set_meta("mode", mode)
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if mode == "save" else FileDialog.FILE_MODE_OPEN_FILE
	match mode:
		"model": dialog.filters = PackedStringArray(["*.glb ; Modelo GLB"])
		"shape": dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Imagen"])
		"shader": dialog.filters = PackedStringArray(["*.gdshader ; Shader Godot"])
		_: dialog.filters = PackedStringArray(["*.json ; Librea"])
	dialog.current_dir = models_dir if mode in ["model", "shape"] else liveries_dir
	dialog.current_file = "librea.json" if mode == "save" else ""
	dialog.popup_centered_ratio(0.75)

func _selected(path: String) -> void:
	match dialog.get_meta("mode"):
		"model": _load_model(path, "")
		"open":
			var f := FileAccess.open(path, FileAccess.READ)
			var data: Variant = JSON.parse_string(f.get_as_text()) if f else null
			if not data is Dictionary or not data.has("model") or not data.has("atlas"):
				status.text = "Archivo de librea invalido"
				return
			if not data.get("vinyl_layers", []) is Array:
				status.text = "Lista de capas invalida"
				return
			var saved_shader: String = data.get("shader", "")
			if not saved_shader.is_empty() and not FileAccess.file_exists(saved_shader):
				status.text = "No se encontro el shader de la librea: " + saved_shader
				return
			shader_path = saved_shader
			_restore_rims(data.get("rims", {}))
			for group in component_locks:
				component_locks[group].set_pressed_no_signal(data.get("component_locks", {}).get(group, false))
			var base_settings: Dictionary = data.get("body_base", {})
			base_enabled.set_pressed_no_signal(base_settings.get("enabled", false))
			base_color.color = Color.from_string(base_settings.get("color", "ffffffff"), Color.WHITE)
			base_finish.select(clampi(int(base_settings.get("finish", 2)), 0, 3))
			_load_model(data.model, path.get_base_dir().path_join(data.atlas), data.get("vinyl_layers", []))
		"save": _save_livery(path)
		"shape":
			var img := Image.load_from_file(path)
			if img and not img.is_empty():
				brush.brush_shape = img
				status.text = "Forma del pincel: " + path.get_file()
			else: status.text = "No se pudo abrir la imagen"
		"shader":
			if not FileAccess.file_exists(path):
				status.text = "No se encontro el shader"
				return
			shader_path = path
			status.text = "Shader seleccionado para el proximo modelo: " + path.get_file()

func _load_model(path: String, atlas: String, vinyl_layers: Array = []) -> void:
	var layer_error: String = vinyl_editor.validate_layers(vinyl_layers)
	if not layer_error.is_empty():
		status.text = layer_error
		return
	if not vinyl_layers.is_empty() and not shader_path.is_empty():
		var code := FileAccess.get_file_as_string(shader_path)
		if not code.contains("uniform vec4 vinyl_origins[64]"):
			status.text = "La librea contiene vinilos: utiliza el shader predeterminado o uno compatible"
			return
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		status.text = "No se pudo abrir: " + path
		return
	var root := doc.generate_scene(state)
	if not root:
		status.text = "No se pudo crear el modelo"
		return
	if model_root:
		model_root.queue_free()
		await get_tree().process_frame
	model_root = Node3D.new()
	add_child(model_root)
	model_root.add_child(root)
	_set_hints(root)
	body_materials.collect(root)
	rim_materials.collect(root)
	_apply_rims()
	_apply_base()
	manager = OverlayAtlasManager.new()
	manager.atlas_size = atlas_size_control.get_selected_id()
	if not atlas.is_empty():
		var atlas_image := Image.load_from_file(atlas)
		if atlas_image and atlas_image.get_width() == atlas_image.get_height() and atlas_image.get_width() in [512, 1024, 2048, 4096]:
			manager.atlas_size = atlas_image.get_width()
			atlas_size_control.select(atlas_size_control.get_item_index(manager.atlas_size))
		else:
			status.text = "Atlas ausente o de tamano no admitido: " + atlas
			model_root.queue_free()
			manager = null
			return
	if not shader_path.is_empty():
		var custom_shader := Shader.new()
		custom_shader.code = FileAccess.get_file_as_string(shader_path)
		manager.overlay_shader = custom_shader
	manager.atlas_texture_path = atlas
	manager.apply_on_ready = true
	model_root.add_child(manager)
	model_path = path
	applied_shader_path = shader_path
	_apply_component_locks()
	brush.get_atlas_textures()
	vinyl_editor.bind_model(vinyl_layers)
	status.text = "Modelo: " + path.get_file() + " | Izquierdo: pintar | Derecho: orbitar | Rueda: zoom"

func _set_hints(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		node.mesh.lightmap_size_hint = Vector2i(128, 128)
	for child in node.get_children():
		_set_hints(child)

func _save_livery(path: String) -> void:
	if not manager or not manager.atlas_texture_rid.is_valid():
		status.text = "Abre un modelo antes de guardar"
		return
	if path.get_extension().to_lower() != "json":
		path += ".json"
	var atlas_path := path.get_basename() + ".exr"
	var bytes := manager.rd.texture_get_data(manager.atlas_texture_rid, 0)
	var img := Image.create_from_data(manager.atlas_size, manager.atlas_size, false, Image.FORMAT_RGBAH, bytes)
	if img.save_exr(atlas_path) != OK:
		status.text = "No se pudo guardar el atlas"
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if not f:
		status.text = "No se pudo guardar la librea"
		return
	f.store_string(JSON.stringify({"version": 2, "vinyl_layers": vinyl_editor.layers, "model": model_path, "atlas": atlas_path.get_file(), "shader": applied_shader_path, "component_locks": _lock_settings(), "rims": _rim_settings(), "body_base": {"enabled": base_enabled.button_pressed, "color": base_color.color.to_html(true), "finish": base_finish.selected}}, "  "))
	status.text = "Guardada: " + path

func supports_vinyls() -> bool:
	return is_instance_valid(manager) and manager.overlay_shader != null and manager.overlay_shader.code.contains("uniform vec4 vinyl_origins[64]")

func _lock_settings() -> Dictionary:
	var settings := {}
	for group in component_locks: settings[group] = component_locks[group].button_pressed
	return settings

func _apply_component_locks() -> void:
	brush.suppress_bleed = component_locks.front.button_pressed or component_locks.rear.button_pressed or component_locks.bargeboards.button_pressed
	if not is_instance_valid(model_root): return
	for node in model_root.find_children("*", "MeshInstance3D", true, false):
		var overlay: Material = node.material_overlay
		if not overlay is ShaderMaterial: continue
		overlay.set_shader_parameter("lock_front_wing", component_locks.front.button_pressed)
		overlay.set_shader_parameter("lock_rear_wing", component_locks.rear.button_pressed)
		overlay.set_shader_parameter("lock_bargeboards", component_locks.bargeboards.button_pressed)
		overlay.set_shader_parameter("is_bargeboard", String(node.name).contains("Bargeboard_F094H"))

func _apply_base() -> void:
	body_materials.apply(base_enabled.button_pressed, base_color.color, base_finish.selected)

func _update_camera() -> void:
	camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(target)
	camera.h_offset = -(camera.size if camera.projection == Camera3D.PROJECTION_ORTHOGONAL else distance) * 0.3 if is_instance_valid(vinyl_window) and vinyl_window.visible else 0.0

func _unhandled_input(event: InputEvent) -> void:
	if vinyl_editor.handle(event):
		painting = false
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			painting = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var zoom := 0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1
			if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
				camera.size = clampf(camera.size * zoom, 0.4, 20.0)
			else:
				distance = clampf(distance * zoom, 0.4, 30.0)
			_update_camera()
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * 0.01
		pitch = clampf(pitch + event.relative.y * 0.01, -1.45, 1.45)
		_update_camera()

func _process(_delta: float) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		painting = false
	brush.drawing = painting and manager != null and brush_enabled.button_pressed and not vinyl_editor.tools.button_pressed
	if brush.drawing:
		var mouse := get_viewport().get_mouse_position()
		var dir := camera.project_ray_normal(mouse)
		brush.global_position = camera.project_ray_origin(mouse)
		brush.look_at(brush.global_position + dir, Vector3.UP)
		brush.color = color_picker.color
