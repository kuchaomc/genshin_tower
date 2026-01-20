shader_type canvas_item;

// 受伤屏幕效果 shader
// 在屏幕边缘显示红色暗角效果

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.8, 0.0, 0.0, 1.0);
uniform float vignette_radius : hint_range(0.0, 1.0) = 0.4;
uniform float vignette_softness : hint_range(0.0, 1.0) = 0.5;
uniform float darkening : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	// 计算到屏幕中心的距离
	vec2 center = vec2(0.5, 0.5);
	vec2 uv = UV;
	
	// 计算椭圆距离（考虑屏幕宽高比，这里假设16:9）
	vec2 diff = (uv - center) * vec2(1.0, 0.5625);
	float dist = length(diff) * 2.0;
	
	// 计算暗角强度
	float vignette = smoothstep(vignette_radius, vignette_radius + vignette_softness, dist);
	
	// 混合红色和暗角
	vec3 color = mix(vec3(0.0), vignette_color.rgb, vignette);
	float darkness = vignette * darkening;
	
	// 应用强度
	float final_alpha = vignette * intensity * 0.7;
	
	// 输出颜色：红色边缘 + 暗角效果
	COLOR = vec4(color, final_alpha);
}
