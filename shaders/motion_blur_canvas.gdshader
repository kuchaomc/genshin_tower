shader_type canvas_item;
render_mode unshaded;

// 运动模糊（全屏）
// 用法：挂到全屏 ColorRect（CanvasLayer 上）并配合 BackBufferCopy(copy_mode=2) 采样屏幕。
// 说明：这是轻量实现，主要用于 2D 移动产生的动态拖影。

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

// 总开关（0=关闭，1=开启）
uniform float enabled : hint_range(0.0, 1.0) = 1.0;

// 动态强度（0~1），通常由脚本根据速度实时驱动
uniform float strength : hint_range(0.0, 1.0) = 0.0;

// 运动方向（世界速度方向），脚本会传入并做归一化
uniform vec2 direction = vec2(1.0, 0.0);

// 最大模糊长度（像素）：strength=1 时的最大拖影长度
uniform float max_blur_pixels : hint_range(0.0, 64.0) = 18.0;

const int SAMPLE_COUNT = 8;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 base4 = texture(screen_texture, uv);
	vec3 base = base4.rgb;
	float out_a = base4.a;

	float t = clamp(enabled * strength, 0.0, 1.0);
	if (t <= 0.0001) {
		COLOR = vec4(base, out_a);
		return;
	}

	vec2 dir = direction;
	float dir_len = length(dir);
	if (dir_len <= 0.0001) {
		COLOR = vec4(base, out_a);
		return;
	}
	dir /= dir_len;

	// SCREEN_PIXEL_SIZE 是“一个像素对应的 UV 尺寸”
	vec2 offset_uv = dir * SCREEN_PIXEL_SIZE * (max_blur_pixels * t);

	vec3 acc = vec3(0.0);
	float wsum = 0.0;

	// 只向“反方向”采样，形成拖影（越靠近当前帧权重越大）
	for (int i = 0; i < SAMPLE_COUNT; i++) {
		float fi = float(i);
		float denom = max(1.0, float(SAMPLE_COUNT - 1));
		float s = fi / denom; // 0..1
		float w = 1.0 - s;
		vec2 suv = uv - offset_uv * s;
		acc += texture(screen_texture, suv).rgb * w;
		wsum += w;
	}

	vec3 blurred = (wsum > 0.0) ? (acc / wsum) : base;
	vec3 out_rgb = mix(base, blurred, t);
	COLOR = vec4(out_rgb, out_a);
}
