shader_type canvas_item;
// Province fill: colour comes from an N x 2 data texture (row 0 = base colour, row 1 = highlight overlay).
// UV.x carries the province index, so recolouring never touches the mesh.
uniform sampler2D colors : filter_nearest, repeat_disable;
uniform sampler2D grain : filter_linear, repeat_enable;
uniform float grain_amount = 0.07;
varying vec2 wpos;

void vertex() {
	wpos = VERTEX;
}

void fragment() {
	vec4 base = texture(colors, vec2(UV.x, 0.25));
	vec4 hi = texture(colors, vec2(UV.x, 0.75));
	vec3 c = mix(base.rgb, hi.rgb, hi.a);
	float g = texture(grain, wpos * 0.0035).r - 0.5;
	c *= 1.0 + g * grain_amount * 2.0;
	COLOR = vec4(c, 1.0);
}
