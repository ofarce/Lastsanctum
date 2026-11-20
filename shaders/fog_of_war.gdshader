shader_type canvas_item;
render_mode unshaded;
uniform sampler2D fog : filter_linear, repeat_disable;
uniform vec2 map_position;
uniform vec2 map_size;

// Brouillard : bleu ardoise très sombre plutôt que noir pur, bord en paliers tramés ancrés à la carte.
uniform float px = 2.0;
const vec3 VEIL = vec3(0.027, 0.035, 0.055);
const float STEPS = 4.0;
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

// Seuil de trame ordonnée (0–1) du pixel natif qui contient ce fragment : la trame est ancrée au monde
// (`origin` = position écran de l'origine du monde) et son point fait `px` pixels d'écran, comme un texel de sprite.
float bayer(vec2 frag, vec2 anchor, float cell) {
	ivec2 c = ivec2(floor((frag - anchor) / cell));
	return (BAYER[(c.y & 3) * 4 + (c.x & 3)] + 0.5) / 16.0;
}

void fragment() {
	vec2 uv = (FRAGCOORD.xy - map_position) / map_size;
	float opacity = 1.0;
	if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)))) {
		opacity = texture(fog, uv).a;
	}
	opacity = min(1.0, floor(opacity * STEPS + bayer(FRAGCOORD.xy, map_position, px)) / STEPS);
	COLOR = vec4(VEIL, opacity);
}
