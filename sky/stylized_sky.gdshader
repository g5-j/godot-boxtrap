shader_type sky;
render_mode use_half_res_pass;

// The controller updates the palette and the direction together with the lights.
uniform vec3 zenith_color : source_color = vec3(0.16, 0.38, 0.76);
uniform vec3 horizon_color : source_color = vec3(0.65, 0.79, 0.91);
uniform vec3 dusk_color : source_color = vec3(1.0, 0.39, 0.24);
uniform vec3 cloud_light : source_color = vec3(1.0, 0.92, 0.82);
uniform vec3 cloud_shadow : source_color = vec3(0.42, 0.54, 0.68);
uniform vec3 sun_color : source_color = vec3(1.0, 0.78, 0.53);
uniform vec3 sun_direction = vec3(0.0, 0.8, -0.6);
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
uniform float twilight : hint_range(0.0, 1.0) = 0.0;
uniform float sun_visibility : hint_range(0.0, 1.0) = 1.0;
uniform float sun_size : hint_range(0.002, 0.08) = 0.014;
uniform float sun_intensity : hint_range(0.0, 10.0) = 1.0;
uniform float scattering : hint_range(0.0, 3.0) = 1.0;
uniform float sky_brightness : hint_range(0.0, 3.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float cloud_density : hint_range(0.0, 1.0) = 0.53;
uniform vec2 cloud_offset = vec2(0.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float cloud_field(vec2 p) {
	// Three non-aligned octaves, with a broad coverage layer; no texture fetches.
	float a = noise2(p * 0.48 + vec2(17.3, 3.1));
	float b = noise2(p);
	float c = noise2(p * 2.07 + vec2(8.2, 19.4));
	float d = noise2(p * 4.13 + vec2(31.7, 5.6));
	return a * 0.24 + b * 0.43 + c * 0.23 + d * 0.10;
}
void sky() {
	vec3 dir = normalize(EYEDIR);
	float height = max(dir.y, 0.0);
	float mu = clamp(dot(dir, sun_direction), -1.0, 1.0);
	if (AT_HALF_RES_PASS) {
		// Project onto a gently curved cloud layer. Fade before the projection
		// becomes singular at the horizon and below it.
		vec2 uv = dir.xz / (height + 0.24) * 2.4 + cloud_offset;
		float n = cloud_field(uv);
		float threshold = mix(0.76, 0.35, cloud_density);
		float coverage = smoothstep(threshold - 0.09, threshold + 0.09, n);
		coverage *= smoothstep(0.015, 0.16, dir.y) * smoothstep(0.0, 0.06, cloud_density);
		float relief = smoothstep(threshold - 0.05, threshold + 0.20, n);
		vec3 lit = mix(cloud_shadow, cloud_light, 0.32 + 0.68 * relief);
		lit += sun_color * pow(max(mu, 0.0), 10.0) * (0.12 + 0.3 * twilight) * sun_visibility;
		COLOR = lit;
		ALPHA = coverage * 0.88;
	} else {
		float horizon = exp(-height * 4.5);
		vec3 sky = mix(zenith_color, horizon_color, horizon);
		// Approximate Rayleigh phase and broad forward Mie lobe, artistically
		// weighted rather than an expensive atmospheric integration.
		float rayleigh = 0.75 * (1.0 + mu * mu);
		float mie = pow(max(mu, 0.0), 8.0);
		sky += zenith_color * rayleigh * 0.09 * scattering * daylight;
		sky += sun_color * mie * (0.10 + twilight * 0.25) * scattering * sun_visibility;
		float sunset_band = exp(-height * 7.0) * (0.25 + 0.75 * pow(max(mu, 0.0), 3.0));
		sky = mix(sky, dusk_color, clamp(sunset_band * twilight * 0.75 * scattering, 0.0, 0.85));
		// A compact HDR disc plus two broad halos, with no post-process dependency.
		float angle = acos(clamp(mu, -1.0, 1.0));
		float disc = 1.0 - smoothstep(sun_size * 0.82, sun_size * 1.18, angle);
		float halo = exp(-angle * 13.0) * 0.45 + exp(-angle * 3.5) * 0.11;
		sky += sun_color * (disc * 3.0 + halo * scattering) * sun_visibility * sun_intensity;
		// Sparse stationary stars mapped on the sphere without an equirectangular seam.
		vec3 star_dir = dir * 175.0;
		vec3 cell = floor(star_dir);
		float star_hash = hash21(cell.xy + cell.z * vec2(37.0, 71.0));
		float star = step(0.997, star_hash) * pow(max(0.0, 1.0 - length(fract(star_dir) - 0.5) * 2.0), 5.0);
		sky += vec3(0.7, 0.8, 1.0) * star * (1.0 - daylight) * smoothstep(0.0, 0.15, dir.y) * 2.0;
		// The moon follows the opposite arc. It is deliberately softer and dimmer.
		float moon_angle = acos(clamp(dot(dir, -sun_direction), -1.0, 1.0));
		float moon = 1.0 - smoothstep(0.012, 0.016, moon_angle);
		sky += vec3(0.65, 0.76, 1.0) * (moon * 1.2 + exp(-moon_angle * 24.0) * 0.13) * (1.0 - daylight) * smoothstep(-0.03, 0.08, -sun_direction.y);
		vec4 clouds = HALF_RES_COLOR;
		sky = mix(sky, clouds.rgb, clouds.a);
		float luminance = dot(sky, vec3(0.2126, 0.7152, 0.0722));
		sky = mix(vec3(luminance), sky, saturation) * sky_brightness;
		COLOR = max(sky, vec3(0.0));
	}
}
