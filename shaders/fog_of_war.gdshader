shader_type canvas_item;
render_mode unshaded;
uniform sampler2D fog : filter_linear, repeat_disable;
uniform vec2 map_position;
uniform vec2 map_size;

void fragment() {
	vec2 uv = (FRAGCOORD.xy - map_position) / map_size;
	float opacity = 1.0;
	if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)))) {
		opacity = texture(fog, uv).a;
	}
	COLOR = vec4(0.0, 0.0, 0.0, opacity);
}
