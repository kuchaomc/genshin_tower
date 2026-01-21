shader_type canvas_item;
render_mode unshaded;

// CRT 后处理（全屏）
// 用法：挂到全屏 ColorRect（CanvasLayer 上）并配合 BackBufferCopy(copy_mode=2) 采样屏幕。
// 说明：为了兼容 mobile 渲染器，这里保持单 pass、少采样的轻量实现。

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

// 总开关（0=关闭，1=开启）
uniform float enabled : hint_range(0.0, 1.0) = 1.0;
// 总强度（建议 0.2~0.7）
uniform float strength : hint_range(0.0, 1.0) = 0.45;

// 色散强度（RGB 轻微错位）
uniform float aberration : hint_range(0.0, 0.01) = 0.0015;

// 栅格（aperture grille）强度
uniform float grille_intensity : hint_range(0.0, 1.0) = 0.08;

// 噪点强度
uniform float noise_intensity : hint_range(0.0, 1.0) = 0.035;

// 暗角强度
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.25;

float _hash(vec2 p) {
	// 简单 hash：稳定、便宜、适合噪点。
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

vec3 _sample_screen_rgb(vec2 uv, float ab) {
	// 轻微色散：R/B 左右偏移，G 居中。
	vec2 offs = vec2(ab, 0.0);
	float r = texture(screen_texture, uv + offs).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - offs).b;
	return vec3(r, g, b);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 base4 = texture(screen_texture, uv);
	vec3 base = base4.rgb;
	float out_a = base4.a;
	vec3 out_rgb = base;

	float t = clamp(enabled * strength, 0.0, 1.0);
	if (t > 0.0001) {
		vec2 cuv = uv;
		vec2 viewport_size = vec2(1.0 / SCREEN_PIXEL_SIZE.x, 1.0 / SCREEN_PIXEL_SIZE.y);

		// 基础采样（含色散）
		vec3 col = _sample_screen_rgb(cuv, aberration * t);

		// 栅格（RGB 三色条纹，按像素列）
		float x = cuv.x * viewport_size.x;
		float phase = x * (2.0 * PI / 3.0);
		vec3 grille = vec3(
			0.5 + 0.5 * sin(phase),
			0.5 + 0.5 * sin(phase + 2.09439510239),
			0.5 + 0.5 * sin(phase + 4.18879020479)
		);
		grille = mix(vec3(1.0), grille, grille_intensity * t);
		col *= grille;

		// 噪点（轻微亮度抖动）
		float n = _hash(cuv * viewport_size + vec2(TIME * 60.0, TIME * 17.0));
		col += (n - 0.5) * noise_intensity * t;

		// 暗角（边缘变暗）
		vec2 d = cuv - vec2(0.5);
		float dist = length(d) * 1.41421356237;
		float vig = 1.0 - smoothstep(0.45, 1.0, dist);
		col *= mix(1.0 - vignette_intensity * t, 1.0, vig);

		// 输出：与原图混合，保证强度可控
		out_rgb = mix(base, col, t);
		out_a = base4.a;
	}

	COLOR = vec4(out_rgb, out_a);
}
