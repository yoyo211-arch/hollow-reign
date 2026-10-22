shader_type canvas_item;
// Gritty post-process: slight desaturation and contrast, vignette, film grain,
// a red edge pulse when hurt and chromatic aberration on hits.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float vignette = 0.55;
uniform float grain = 0.05;
uniform float aberration = 0.0;
uniform float hurt = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	float ab = aberration * 0.004;
	vec3 col;
	col.r = texture(screen_tex, uv + d * ab).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - d * ab).b;

	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, 0.82);
	col = (col - 0.5) * 1.1 + 0.5;

	float v = smoothstep(0.9, 0.3, length(d * vec2(1.25, 1.0)));
	col *= mix(1.0 - vignette, 1.0, v);
	col = mix(col, col * vec3(1.6, 0.4, 0.4) + vec3(0.12, 0.0, 0.0), hurt * (1.0 - v));

	float n = fract(sin(dot(uv + fract(TIME * 0.37), vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * grain;
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
