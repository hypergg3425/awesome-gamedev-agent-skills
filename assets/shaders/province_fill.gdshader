shader_type canvas_item;
// Province fill: colour comes from an N x 3 data texture (row 0 = base colour, row 1 = highlight overlay, row 2 = relief
// amplitude in .r). UV.x carries the province index, so recolouring never touches the mesh.
// Relief: a cheap hillshade of a tiling noise height field (NW light), scaled per province by its relief amplitude
// (mountains strong, plains faint). The fine octave fades in with zoom, so low zoom stays calm and cheap.
uniform sampler2D colors : filter_nearest, repeat_disable;
uniform sampler2D grain : filter_linear, repeat_enable;
uniform float grain_amount = 0.05;
uniform float relief_strength = 1.0;
uniform float zoom = 1.0;
varying vec2 wpos;

void vertex() {
	wpos = VERTEX;
}

float height_at(vec2 p, float detail) {
	float h = texture(grain, p * 0.0035).r * 0.7;
	h += texture(grain, p * 0.0150).r * 0.3 * detail;
	return h;
}

void fragment() {
	vec4 base = texture(colors, vec2(UV.x, 1.0 / 6.0));
	vec4 hi = texture(colors, vec2(UV.x, 3.0 / 6.0));
	float amp = texture(colors, vec2(UV.x, 5.0 / 6.0)).r;
	vec3 c = mix(base.rgb, hi.rgb, hi.a);
	float detail = smoothstep(1.2, 3.5, zoom);
	float e = mix(3.0, 1.2, detail);
	float h0 = height_at(wpos, detail);
	float dx = (height_at(wpos + vec2(e, 0.0), detail) - h0) / e;
	float dy = (height_at(wpos + vec2(0.0, e), detail) - h0) / e;
	vec3 n = normalize(vec3(-dx * 9.0 * amp, -dy * 9.0 * amp, 1.0));
	vec3 l = normalize(vec3(-0.55, -0.6, 0.62));
	float shade = clamp(dot(n, l) - l.z, -0.35, 0.35);
	c *= 1.0 + shade * relief_strength * 1.1;
	float g = h0 - 0.5;
	c *= 1.0 + g * grain_amount * 2.0;
	COLOR = vec4(c, 1.0);
}
