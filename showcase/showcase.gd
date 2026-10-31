extends Node3D

@onready var sky = $DayNightSky
var _slider: HSlider
var _clock: Label
var _play: Button

func _ready() -> void:
	_build_landscape()
	_build_ui()

func _process(_delta: float) -> void:
	if _slider:
		_slider.set_value_no_signal(sky.time_of_day)
		_clock.text = _format_time(sky.time_of_day)

func _format_time(hour: float) -> String:
	var minutes := int(round(hour * 60.0)) % (24 * 60)
	return "%02d:%02d" % [minutes / 60, minutes % 60]

func _material(color: Color, roughness: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func _mesh(mesh: Mesh, pos: Vector3, mat: Material, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.scale = scale_value
	instance.material_override = mat
	add_child(instance)
	return instance

func _cylinder(pos: Vector3, top: float, bottom: float, height: float, color: Color, sides: int = 16) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	_mesh(mesh, pos, _material(color))

func _tree(pos: Vector3, size: float) -> void:
	_cylinder(pos + Vector3(0, size * 0.65, 0), size * 0.09, size * 0.14, size * 1.3, Color("766150"), 8)
	var crown := SphereMesh.new()
	crown.radius = size * 0.72
	crown.height = size * 1.48
	crown.radial_segments = 12
	crown.rings = 6
	_mesh(crown, pos + Vector3(0, size * 1.7, 0), _material(Color("496f65")))
	_mesh(crown, pos + Vector3(size * 0.38, size * 1.46, 0.18 * size), _material(Color("648774")), Vector3(0.72, 0.72, 0.72))

func _build_landscape() -> void:
	# A small, entirely disposable lighting reference: no gameplay dependencies.
	var water := PlaneMesh.new()
	water.size = Vector2(800, 800)
	_mesh(water, Vector3(0, -1.5, 0), _material(Color("456d7d"), 0.38))
	_cylinder(Vector3(0, -0.45, 0), 11.0, 9.3, 2.1, Color("8d8271"), 32)
	_cylinder(Vector3(0, 0.62, 0), 10.9, 11.0, 0.18, Color("879d82"), 32)
	for item in [[Vector3(-6, 0.7, -4), 2.1], [Vector3(-7, 0.7, 3), 1.5], [Vector3(4, 0.7, -6), 1.8], [Vector3(7, 0.7, 2), 2.2], [Vector3(4, 0.7, 6), 1.3]]:
		_tree(item[0], item[1])
	# Pale, simple forms show warm highlights and long contact shadows.
	var box := BoxMesh.new()
	box.size = Vector3(2.8, 2.7, 2.8)
	_mesh(box, Vector3(0, 2.0, 0), _material(Color("e8dec9")))
	var roof := CylinderMesh.new()
	roof.top_radius = 0.0
	roof.bottom_radius = 2.5
	roof.height = 1.7
	roof.radial_segments = 4
	var roof_instance := _mesh(roof, Vector3(0, 4.2, 0), _material(Color("b47e70")))
	roof_instance.rotation.y = PI / 4.0
	_cylinder(Vector3(-3.5, 1.05, 2.5), 0.65, 0.8, 0.7, Color("c5bba6"), 9)
	var sphere := SphereMesh.new()
	sphere.radius = 0.65
	sphere.height = 1.3
	_mesh(sphere, Vector3(-3.5, 1.95, 2.5), _material(Color("f2e7d2"), 0.3))

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	layer.add_child(margin)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.075, 0.78)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var title := Label.new()
	title.text = "THE SKY, IN MOTION"
	title.add_theme_font_size_override("font_size", 18)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "A study in light and atmosphere"
	subtitle.modulate = Color(0.75, 0.83, 0.88)
	column.add_child(subtitle)
	var row := HBoxContainer.new()
	column.add_child(row)
	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 24.0
	_slider.step = 0.01
	_slider.custom_minimum_size.x = 230
	_slider.value = sky.time_of_day
	_slider.value_changed.connect(func(value: float): sky.set_time(value))
	row.add_child(_slider)
	_clock = Label.new()
	_clock.custom_minimum_size.x = 52
	row.add_child(_clock)
	_play = Button.new()
	_play.text = "Play"
	_play.pressed.connect(func():
		sky.advance_time = not sky.advance_time
		_play.text = "Pause" if sky.advance_time else "Play"
	)
	row.add_child(_play)
	var presets := HBoxContainer.new()
	column.add_child(presets)
	for preset in [["Morning", 7.5], ["Midday", 12.0], ["Afternoon", 15.5], ["Golden", 17.5], ["Sunset", 17.9], ["Night", 22.0]]:
		var button := Button.new()
		button.text = preset[0]
		var hour: float = preset[1]
		button.pressed.connect(func(): sky.set_time(hour))
		presets.add_child(button)
