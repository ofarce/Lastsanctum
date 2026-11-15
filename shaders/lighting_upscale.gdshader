shader_type canvas_item;
// Agrandissement du calque d'obscurité au quart (lighting_dark.gdshader) à la taille de l'écran : filtrage
// bilinéaire des couleurs prémultipliées (agrandissement CSS du navigateur), bords prolongés, puis
// composition « source-over » sur le jeu.

uniform sampler2D quarter : filter_linear, repeat_disable;
uniform vec2 screen_size = vec2(1440.0, 900.0);
uniform vec2 qsize = vec2(360.0, 225.0);

void fragment() {
	// Centre du pixel d'écran, en pixels du calque, ramené aux coordonnées de texture.
	vec2 uv = UV * screen_size / (4.0 * qsize);
	vec4 v = texture(quarter, uv);
	COLOR = v.a > 0.0 ? vec4(v.rgb / v.a, v.a) : vec4(0.0);
}
