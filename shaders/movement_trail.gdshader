shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 tint : source_color = vec4(0.75, 0.92, 1.0, 0.9);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float tail_power : hint_range(0.2, 4.0) = 1.6;

void fragment() {
	vec4 c = COLOR;

	float t = clamp(UV.x, 0.0, 1.0);
	float tail = pow(1.0 - t, tail_power);

	c.rgb *= tint.rgb;
	c.a *= tint.a * strength * tail;

	COLOR = c;
}
