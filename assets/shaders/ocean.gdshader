shader_type canvas_item;
// Sea backdrop: noise depth tint and a subtle drifting shimmer.
// `animate` is 0 when Settings "animations" is off (the shimmer is then frozen, not removed).
uniform vec4 deep : source_color = vec4(0.055, 0.12, 0.2, 1.0);
uniform vec4 shallow : source_color = vec4(0.10, 0.22, 0.33, 1.0);
uniform sampler2D grain : filter_linear, repeat_enable;
uniform float animate = 1.0;
uniform float zoom = 1.0;
varying vec2 wpos;
void vertex() { wpos = VERTEX; }
void fragment() {
	float g = texture(grain, wpos * 0.0025).r;
	vec3 c = mix(deep.rgb, shallow.rgb, g * 0.9);
	float t = TIME * animate;
	float a = texture(grain, wpos * 0.0062 + vec2(t * 0.0045, t * 0.0021)).r;
	float b = texture(grain, wpos * 0.0113 - vec2(t * 0.0030, -t * 0.0052)).r;
	float glint = smoothstep(0.55, 0.85, a * b * 2.4);
	c += vec3(0.035, 0.06, 0.075) * glint * (0.55 + 0.45 * smoothstep(0.3, 2.0, zoom));
	COLOR = vec4(c, 1.0);
}
