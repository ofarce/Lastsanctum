shader_type canvas_item;
// Agrandissement du calque d'obscurité au quart (lighting_dark.gdshader) à la taille de l'écran : filtrage
// bilinéaire des couleurs prémultipliées (agrandissement CSS du navigateur), bords prolongés, puis
// composition « source-over » sur le jeu.

uniform sampler2D quarter : filter_linear, repeat_disable;
uniform vec2 screen_size = vec2(1440.0, 900.0);
uniform vec2 qsize = vec2(360.0, 225.0);

// Charte : halos en paliers tramés. L'obscurité est ramenée à STEPS paliers, raccordés par une trame ordonnée
// au grain des sprites, au lieu d'un dégradé continu posé sur le pixel art.
uniform float px = 2.0;
uniform vec2 origin = vec2(0.0);
const float STEPS = 6.0;
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

// Seuil de trame ordonnée (0–1) du pixel natif qui contient ce fragment : la trame est ancrée au monde
// (`origin` = position écran de l'origine du monde) et son point fait `px` pixels d'écran, comme un texel de sprite.
float bayer(vec2 frag, vec2 anchor, float cell) {
	ivec2 c = ivec2(floor((frag - anchor) / cell));
	return (BAYER[(c.y & 3) * 4 + (c.x & 3)] + 0.5) / 16.0;
}

void fragment() {
	// Centre du pixel d'écran, en pixels du calque, ramené aux coordonnées de texture.
	vec2 uv = UV * screen_size / (4.0 * qsize);
	vec4 v = texture(quarter, uv);
	float a = floor(v.a * STEPS + bayer(FRAGCOORD.xy, origin, px)) / STEPS;
	COLOR = v.a > 0.0 ? vec4(v.rgb / v.a, a) : vec4(0.0);
}
