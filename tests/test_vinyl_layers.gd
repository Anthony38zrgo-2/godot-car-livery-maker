extends SceneTree

# Run after importing the project:
# Godot --path . --script res://tests/test_vinyl_layers.gd
# Synthetic geometry only: no extracted game assets are needed.
var failures := 0

func check(condition: bool, message: String) -> void:
 if not condition:
  failures += 1
  push_error(message)

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var studio = load("res://livery_studio.tscn").instantiate()
 root.add_child(studio)
 await process_frame
 studio.settings_panel.hide()
 studio.set_process(false)
 studio.model_root = Node3D.new()
 studio.add_child(studio.model_root)
 var panel := MeshInstance3D.new()
 panel.name = "Carroceria_atlas"
 var box := BoxMesh.new()
 box.size = Vector3(0.4,0.7,2.2)
 box.add_uv2 = true
 box.lightmap_size_hint = Vector2i(128,128)
 var material := StandardMaterial3D.new()
 material.resource_name = "Benetton B195 - atlas.fixture"
 material.albedo_color = Color(0.03,0.08,0.4)
 box.material = material
 panel.mesh = box
 panel.position = Vector3(0.5,0.5,0)
 studio.model_root.add_child(panel)
 var occluder := MeshInstance3D.new()
 occluder.name = "NO_PINTAR_Test"
 var obstacle := BoxMesh.new()
 obstacle.size = Vector3(0.2,0.3,0.3)
 occluder.mesh = obstacle
 occluder.position = Vector3(2,0.5,0)
 studio.model_root.add_child(occluder)
 studio.body_materials.collect(studio.model_root)
 studio.manager = OverlayAtlasManager.new()
 studio.manager.atlas_size = 512
 studio.manager.apply_on_ready = true
 studio.model_root.add_child(studio.manager)
 studio.model_path = "fixture://synthetic"
 studio.camera.position = Vector3(4,0.5,0)
 studio.camera.look_at(Vector3(0.5,0.5,0))
 var editor = studio.vinyl_editor
 editor.bind_model()
 for frame in 5: await process_frame
 var mouse: Vector2 = studio.camera.unproject_position(Vector3(0.5,0.5,0))
 var blocked: Dictionary = editor.hit_test(mouse)
 check(blocked.get("node", "") == "NO_PINTAR_Test", "Nearest protected surface must occlude the ray")
 editor.place(blocked)
 check(editor.layers.is_empty(), "Protected surface accepted a vinyl")
 occluder.queue_free()
 await process_frame
 editor.bind_model()
 var hit: Dictionary = editor.hit_test(mouse)
 check(not editor.protected_hit(hit), "Fixture body should be paintable")
 var shapes = load("res://studio/vinyl_shapes.gd")
 for index in shapes.LABELS.size():
  var image: Image = shapes.image({"shape":index,"number":95,"color":"00aaffff","border_color":"ffffffff","border":0.03})
  check(not image.is_empty() and not image.is_invisible(), "Shape failed: " + str(index))
 for number in 100:
  var image: Image = shapes.image({"shape":13,"number":number,"color":"ffffffff","border_color":"000000ff","border":0.01})
  check(not image.is_empty() and not image.is_invisible(), "Number failed: " + str(number))
 editor.fill.color = Color.RED
 editor.place(hit)
 check(editor.layers.size() == 1, "Placement failed")
 editor.edit("width",1.2)
 editor.edit("height",0.45)
 editor.edit("rotation",30.0)
 check(editor.layers[0].width == 1.2 and editor.layers[0].height == 0.45 and editor.layers[0].rotation == 30.0, "Independent scale/rotation failed")
 editor.action("duplicate")
 editor.edit("color","00ffffff")
 editor.action("down")
 check(editor.selected == 0 and editor.layers[0].color == "00ffffff", "Ordering failed")
 editor.action("mirror")
 check(is_equal_approx(float(editor.layers[-1].origin[0]), -float(editor.layers[0].origin[0])), "Mirror failed")
 editor.layers[-1].locked = true
 var previous: float = editor.layers[-1].width
 editor.edit("width",3.0)
 check(editor.layers[-1].width == previous, "Locked layer was edited")
 editor.layers[-1].locked = false
 editor.edit("visible",false)
 studio.component_locks.front.button_pressed = true
 check(editor.protected_hit({"node":"Carroceria_atlas","point":Vector3(0,0.2,-2)}), "Front component lock ignored")
 studio.component_locks.front.button_pressed = false
 # Keep one visible layer for a GPU appearance test.
 editor.layers = [editor.layers[0].duplicate(true)]
 editor.selected = 0
 editor.edit("rotation",0.0)
 editor.edit("visible",false)
 for frame in 5: await process_frame
 var baseline: Image = root.get_texture().get_image()
 editor.edit("visible",true)
 for frame in 5: await process_frame
 var painted: Image = root.get_texture().get_image()
 var changed := 0
 for y in range(0,painted.get_height(),4):
  for x in range(0,painted.get_width(),4):
   if absf(painted.get_pixel(x,y).g-baseline.get_pixel(x,y).g)>0.05: changed += 1
 check(changed>10, "Vinyl did not render on the surface")
 var path := ProjectSettings.globalize_path("user://test_vinyl_layers.json")
 studio._save_livery(path)
 var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
 check(int(document.get("version",0)) == 2, "Missing document version")
 var serialized: String = JSON.stringify(JSON.parse_string(JSON.stringify(editor.layers)))
 editor.bind_model(document.get("vinyl_layers",[]))
 check(JSON.stringify(editor.layers) == serialized, "Layer document roundtrip failed")
 # Translation must reuse the generated shape texture, not regenerate all SVGs.
 editor.selected=0
 var texture_before: ImageTexture = editor.texture
 var start := Time.get_ticks_usec()
 for index in 20: editor.edit("offset_x",index*0.001)
 var elapsed := (Time.get_ticks_usec()-start)/20000.0
 check(editor.texture == texture_before, "Moving a vinyl rebuilt its texture atlas")
 print("VINYL_TESTS failures=",failures," changed_pixels=",changed," move_ms=",elapsed)
 DirAccess.remove_absolute(path)
 DirAccess.remove_absolute(path.get_basename()+".exr")
 quit(0 if failures == 0 else 1)
