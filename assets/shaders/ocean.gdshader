shader_type canvas_item;
// Soft parchment-sea backdrop with vignette; cheap (no loops).
uniform vec4 deep : source_color = vec4(0.055, 0.12, 0.2, 1.0);
uniform vec4 shallow : source_color = vec4(0.10, 0.22, 0.33, 1.0);
uniform sampler2D grain : filter_linear, repeat_enable;
varying vec2 wpos;
void vertex() { wpos = VERTEX; }
void fragment() {
	float g = texture(grain, wpos * 0.0025).r;
	vec3 c = mix(deep.rgb, shallow.rgb, g * 0.9);
	COLOR = vec4(c, 1.0);
}
