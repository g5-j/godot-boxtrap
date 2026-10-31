@tool
extends Node3D
## Self-contained sky rig. Instance once in a 3D world; avoid another WorldEnvironment.

const SKY_SHADER: Shader = preload("res://sky/stylized_sky.gdshader")

@export_group("Time")
@export_range(0.0, 24.0, 0.01) var time_of_day: float = 17.5
@export var advance_time: bool = false
@export_range(10.0, 7200.0, 1.0, "or_greater") var day_length_seconds: float = 600.0
@export_range(-180.0, 180.0, 1.0) var sun_azimuth_degrees: float = 0.0
@export_group("Sun and atmosphere")
@export_range(0.0, 5.0, 0.01) var sun_intensity: float = 1.0
@export_range(0.002, 0.08, 0.001) var sun_size: float = 0.014
@export_range(0.0, 3.0, 0.01) var atmospheric_scattering: float = 1.0
@export_range(0.0, 3.0, 0.01) var sky_brightness: float = 1.0
@export_range(0.0, 2.0, 0.01) var sky_saturation: float = 1.05
@export var day_sky_tint: Color = Color.WHITE
@export var horizon_tint: Color = Color.WHITE
@export var sunset_tint: Color = Color.WHITE
@export var night_sky_tint: Color = Color.WHITE
@export_group("Clouds")
@export_range(0.0, 1.0, 0.01) var cloud_density: float = 0.52
@export_range(0.0, 1.0, 0.001) var cloud_speed: float = 0.025
@export var cloud_direction: Vector2 = Vector2(1.0, 0.35)
@export_group("Environment")
@export_range(0.1, 4.0, 0.01) var exposure: float = 1.0
@export_range(0.0, 2.0, 0.01) var glow_intensity: float = 0.12
@export_range(0.0, 3.0, 0.01) var ambient_intensity: float = 1.0
@export_range(0.0, 16.0, 0.1) var shadow_blur: float = 2.0

# Cyclic, deliberately asymmetric palette: sunrise is softer than sunset.
# Values are sRGB artist colors; source_color uniforms convert them for rendering.
const KEYS := [
	{"hour": 0.0, "zenith": Color("101b38"), "horizon": Color("253650"), "dusk": Color("353553"), "light": Color("a6bce8"), "cloud": Color("33415a"), "shadow": Color("172238"), "ambient": Color("34476c")},
	{"hour": 5.0, "zenith": Color("24365f"), "horizon": Color("766782"), "dusk": Color("c17877"), "light": Color("ffbc88"), "cloud": Color("ad8790"), "shadow": Color("505174"), "ambient": Color("626282")},
	{"hour": 7.5, "zenith": Color("558ec6"), "horizon": Color("c4d7dc"), "dusk": Color("f8ba8d"), "light": Color("ffe0b0"), "cloud": Color("fff0dd"), "shadow": Color("859db4"), "ambient": Color("a8bdce")},
	{"hour": 12.0, "zenith": Color("357bc2"), "horizon": Color("b9d9eb"), "dusk": Color("e8d4be"), "light": Color("fff4d9"), "cloud": Color("fffaf2"), "shadow": Color("91aec4"), "ambient": Color("b3cbe0")},
	{"hour": 15.5, "zenith": Color("3874b9"), "horizon": Color("bdd8e6"), "dusk": Color("f3c3a0"), "light": Color("ffdfb1"), "cloud": Color("fff1db"), "shadow": Color("8fa2ba"), "ambient": Color("b4c5d6")},
	{"hour": 17.5, "zenith": Color("525d9c"), "horizon": Color("e8a28b"), "dusk": Color("ff8665"), "light": Color("ffbd7c"), "cloud": Color("ffd2af"), "shadow": Color("716583"), "ambient": Color("aa96a7")},
	{"hour": 18.5, "zenith": Color("343c72"), "horizon": Color("c77880"), "dusk": Color("f47860"), "light": Color("ff9a72"), "cloud": Color("e5a3a1"), "shadow": Color("594963"), "ambient": Color("806c88")},
	{"hour": 20.0, "zenith": Color("19264b"), "horizon": Color("514b6b"), "dusk": Color("a66575"), "light": Color("b7bfe6"), "cloud": Color("686278"), "shadow": Color("30344d"), "ambient": Color("4b5271")},
	{"hour": 24.0, "zenith": Color("101b38"), "horizon": Color("253650"), "dusk": Color("353553"), "light": Color("a6bce8"), "cloud": Color("33415a"), "shadow": Color("172238"), "ambient": Color("34476c")},
]

var _material: ShaderMaterial
var _environment: Environment
var _cloud_offset := Vector2.ZERO
var _update_timer := 0.0
@onready var _world: WorldEnvironment = $WorldEnvironment
@onready var _sun: DirectionalLight3D = $Sun
@onready var _moon: DirectionalLight3D = $Moon

func _ready() -> void:
	# Private resources prevent one instance's settings from mutating another's.
	_material = ShaderMaterial.new()
	_material.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = _material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.glow_enabled = true
	_environment.glow_bloom = 0.0
	_world.environment = _environment
	_update_sky()

func _process(delta: float) -> void:
	if advance_time and not Engine.is_editor_hint():
		time_of_day = fposmod(time_of_day + delta * 24.0 / maxf(day_length_seconds, 10.0), 24.0)
	_cloud_offset += cloud_direction.normalized() * cloud_speed * delta
	# Throttle updates (and sky radiance refreshes) to keep mobile costs bounded.
	_update_timer += delta
	if _update_timer >= 0.1:
		_update_timer = 0.0
		_update_sky()

func set_time(hour: float) -> void:
	time_of_day = fposmod(hour, 24.0)
	if is_node_ready():
		_update_sky()

func _palette(hour: float) -> Dictionary:
	var t := fposmod(hour, 24.0)
	for i in range(KEYS.size() - 1):
		var a: Dictionary = KEYS[i]
		var b: Dictionary = KEYS[i + 1]
		if t <= b.hour:
			var f: float = (t - a.hour) / (b.hour - a.hour)
			f = f * f * (3.0 - 2.0 * f)
			var result := {}
			for key in ["zenith", "horizon", "dusk", "light", "cloud", "shadow", "ambient"]:
				result[key] = (a[key] as Color).lerp(b[key], f)
			return result
	return KEYS[0]

func _update_sky() -> void:
	if not _material:
		return
	var h := fposmod(time_of_day, 24.0)
	var angle := (h - 6.0) * TAU / 24.0
	var direction := Vector3(cos(angle), sin(angle), -0.3).normalized().rotated(Vector3.UP, deg_to_rad(sun_azimuth_degrees))
	var day := smoothstep(-0.14, 0.12, direction.y)
	var sun_visible := smoothstep(-0.06, 0.045, direction.y)
	var twilight := (1.0 - smoothstep(0.03, 0.48, absf(direction.y))) * smoothstep(-0.22, -0.04, direction.y)
	var p := _palette(h)
	var sky_tint := night_sky_tint.lerp(day_sky_tint, day)
	_material.set_shader_parameter("zenith_color", p.zenith * sky_tint)
	_material.set_shader_parameter("horizon_color", p.horizon * horizon_tint)
	_material.set_shader_parameter("dusk_color", p.dusk * sunset_tint)
	_material.set_shader_parameter("cloud_light", p.cloud)
	_material.set_shader_parameter("cloud_shadow", p.shadow)
	_material.set_shader_parameter("sun_color", p.light)
	_material.set_shader_parameter("sun_direction", direction)
	_material.set_shader_parameter("daylight", day)
	_material.set_shader_parameter("twilight", twilight)
	_material.set_shader_parameter("sun_visibility", sun_visible)
	_material.set_shader_parameter("sun_size", sun_size)
	_material.set_shader_parameter("sun_intensity", sun_intensity)
	_material.set_shader_parameter("scattering", atmospheric_scattering)
	_material.set_shader_parameter("sky_brightness", sky_brightness)
	_material.set_shader_parameter("saturation", sky_saturation)
	_material.set_shader_parameter("cloud_density", cloud_density)
	_material.set_shader_parameter("cloud_offset", _cloud_offset)
	_sun.global_basis = Basis.looking_at(-direction, Vector3.UP)
	_sun.light_color = p.light
	_sun.light_energy = sun_intensity * sun_visible * lerpf(0.35, 1.15, smoothstep(0.0, 0.55, direction.y))
	_sun.shadow_blur = shadow_blur + twilight * 1.5
	_moon.global_basis = Basis.looking_at(direction, Vector3.UP)
	_moon.light_energy = 0.12 * (1.0 - day) * smoothstep(-0.03, 0.18, -direction.y)
	_environment.ambient_light_color = p.ambient
	_environment.ambient_light_energy = ambient_intensity * lerpf(0.24, 0.65, day)
	_environment.tonemap_exposure = exposure
	_environment.glow_intensity = glow_intensity
