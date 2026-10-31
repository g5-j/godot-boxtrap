# Day / night sky

`day_night_sky.tscn` is a self-contained Godot 4.7 sky, sun, moon and environment rig. The project starts in a standalone showcase; use its slider and preset buttons to examine the lighting. Play advances a 10-minute day by default.

## Use in a game

Instance `res://sky/day_night_sky.tscn` once under your 3D world. Remove or disable other `WorldEnvironment` nodes in that world and avoid duplicate sun/moon lights. The rig creates its own environment and sky resources, so changes do not leak between instances. The inspector groups expose time, sun intensity and angular size, scattering, brightness/saturation, palette tints, cloud coverage/speed/direction, exposure, glow, ambient strength and shadow blur. The `@tool` rig previews changes in the editor. To control from code:

```gdscript
$DayNightSky.set_time(17.9) # hours in [0, 24), wraps around
$DayNightSky.advance_time = true
$DayNightSky.day_length_seconds = 900.0
```

Palette keys in `day_night_sky.gd` are in sRGB and can be edited for a different art direction. The preset buttons simply set the continuous clock: morning 07:30, midday 12:00, afternoon 15:30, golden hour 17:30, sunset 17:54, night 22:00. Sunrise and sunset are approximately 06:00 and 18:00. `sun_azimuth_degrees` rotates the entire path. This is an art-directed, fixed-latitude cycle, not an astronomical simulation.

## Rendering and cost

The project uses Godot's Mobile renderer. The sky uses a Rayleigh phase approximation and a forward Mie lobe, not a costly physical atmosphere integrator. Clouds are four value-noise octaves evaluated in the half-resolution sky pass, with no external textures. Stars and moon are procedural. The sun disc and halos are in the sky itself, so they do not depend on glow. A 128-pixel incremental radiance map limits reflection cost; shader/lighting updates are throttled to 10 Hz, while the clock remains continuous. The rig uses a constant ambient color that follows the palette; the sky supplies reflections. One shadowed sun and an unshadowed moon limit mobile shadow costs. Glow is optional and depends on renderer/platform support. For constrained devices, reduce shadow distance in the Sun node, disable shadows or glow, or lower the radiance size in the script. Animated cloud movement also causes radiance updates, so profile on the target hardware.

The showcase is a lighting test only; it is not required by the rig. Its camera, terrain, UI and main scene setting can be replaced by your game.

## Smoke test

Run `godot --headless --path . --script res://tests/sky_smoke_test.gd` to exercise the showcase, shader-language compilation, palette wrapping, and sun/moon transitions. Headless validation cannot assess GPU rendering or visual quality; also run the showcase on the target Mobile renderer.
