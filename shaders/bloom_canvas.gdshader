shader_type canvas_item;
render_mode unshaded;

// Bloom（泛光）后处理：
// - 用法：挂到全屏 ColorRect（UI 之前的 CanvasLayer）上，作为屏幕后处理。
// - 原理：屏幕采样 -> 亮部提取（阈值+软过渡）-> 少量采样模糊 -> 加法叠加到原图。
// - 注意：这是单 pass 轻量实现，效果/性能折中，适合 2D 战斗场景。

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// 亮度阈值：越大越“只保留高光”
uniform float threshold : hint_range(0.0, 2.0) = 0.5;
// Bloom 强度
uniform float intensity : hint_range(0.0, 3.0) = 2.0;
// 模糊半径：这里用作 mipmap LOD（越大越糊，性能更好）
uniform float radius : hint_range(0.0, 6.0) = 3.0;
// 阈值软过渡（减少硬边），越大过渡越柔
uniform float soft_knee : hint_range(0.0, 1.0) = 0.5;

// 调试模式：
// 0 = 正常输出
// 1 = 仅显示原图
// 2 = 仅显示模糊图（mipmap）
// 3 = 仅显示亮部掩码（黑=未触发阈值）
// 4 = 仅显示 bloom（未叠加原图）
uniform float debug_mode : hint_range(0.0, 4.0, 1.0) = 0.0;

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float soft_threshold(float x, float t, float knee) {
	float k = max(1e-5, t * knee);
	float a = x - t + k;
	float s = clamp(a / (2.0 * k), 0.0, 1.0);
	return max(x - t, 0.0) + (s * s) * k;
}

void fragment() {
	vec4 base = texture(screen_texture, SCREEN_UV);

	// 用 mipmap 近似大范围模糊：LOD 越大越糊（需要 screen_texture 开 mipmap 过滤）
	float lod = clamp(radius, 0.0, 6.0);
	vec3 blurred = textureLod(screen_texture, SCREEN_UV, lod).rgb;

	// 在模糊图上做亮部提取，会让泛光向外扩散更明显
	float lum = luma(blurred);
	float b = soft_threshold(lum, threshold, soft_knee);
	float inv_lum = 1.0 / max(lum, 1e-5);
	vec3 bloom = blurred * (b * inv_lum);

	int dbg = int(debug_mode + 0.5);

	vec3 out_rgb;
	float out_a;
	if (dbg == 1) {
		out_rgb = base.rgb;
		out_a = 1.0;
	} else if (dbg == 2) {
		out_rgb = blurred;
		out_a = 1.0;
	} else if (dbg == 3) {
		out_rgb = vec3(clamp(b, 0.0, 1.0));
		out_a = 1.0;
	} else if (dbg == 4) {
		out_rgb = bloom * intensity;
		out_a = 1.0;
	} else {
		out_rgb = base.rgb + bloom * intensity;
		out_a = base.a;
	}

	COLOR = vec4(out_rgb, out_a);
}
