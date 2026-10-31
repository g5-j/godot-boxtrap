extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://showcase/showcase.tscn")
	assert(scene != null)
	var demo := scene.instantiate()
	root.add_child(demo)
	await process_frame
	var rig = demo.get_node("DayNightSky")
	var sun: DirectionalLight3D = rig.get_node("Sun")
	var moon: DirectionalLight3D = rig.get_node("Moon")
	var world: WorldEnvironment = rig.get_node("WorldEnvironment")
	assert(world.environment != null and world.environment.sky != null)
	var material: ShaderMaterial = world.environment.sky.sky_material
	var shader: Shader = material.shader
	assert(shader.get_shader_uniform_list().size() >= 15, "Sky shader failed to compile")
	for hour in [7.5, 12.0, 15.5, 17.5, 17.9, 22.0]:
		rig.set_time(hour)
		assert(is_equal_approx(rig.time_of_day, hour))
		assert(sun.light_energy >= 0.0 and moon.light_energy >= 0.0)
	rig.set_time(12.0)
	assert(sun.light_energy > 0.5 and moon.light_energy < 0.01)
	rig.set_time(0.0)
	assert(sun.light_energy < 0.01 and moon.light_energy > 0.05)
	rig.set_time(25.0)
	assert(is_equal_approx(rig.time_of_day, 1.0))
	var before: Color = rig._palette(23.999).zenith
	var after: Color = rig._palette(0.001).zenith
	assert(before.is_equal_approx(after))
	rig.advance_time = true
	rig.day_length_seconds = 10.0
	var initial: float = rig.time_of_day
	rig._process(0.5)
	assert(rig.time_of_day > initial)
	print("Sky smoke test passed")
	demo.queue_free()
	quit()
