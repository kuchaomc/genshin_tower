shader_type canvas_item;
render_mode unshaded;

uniform float pixel_size : hint_range(1.0, 32.0, 1.0) = 6.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 size = VIEWPORT_SIZE;
	float p = max(pixel_size, 1.0);
	vec2 step_uv = p / size;
	vec2 snapped_uv = floor(uv / step_uv) * step_uv;
	COLOR = texture(SCREEN_TEXTURE, snapped_uv);
}
