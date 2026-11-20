shader_type canvas_item;
// Sol de la jungle teinté par sous-zone (world/terrain/ground_zones.gd). Texture d'entrée, 1 texel par
// unité de monde, lue en bilinéaire : R = marais, G = clairière, B = forêt dense, A = coin rocheux
// (0 sur les chemins et sous la montagne). Rendu au pixel natif, en deux paliers aux bords déchiquetés
// par un grain (pas de trame régulière), avec quelques détails : flaques, brins clairs, cailloutis.

uniform vec2 origin; // pixel natif du coin haut gauche
uniform float texel = 8.0; // pixels natifs par texel

const vec3 MARSH = vec3(0.330, 0.270, 0.150);
const vec3 PUDDLE = vec3(0.150, 0.250, 0.260);
const vec3 CLEARING = vec3(0.560, 0.640, 0.270);
const vec3 BLADE = vec3(0.740, 0.790, 0.360);
const vec3 DENSE = vec3(0.050, 0.130, 0.085);
const vec3 ROCKY = vec3(0.400, 0.405, 0.375);
const vec3 PEBBLE = vec3(0.600, 0.600, 0.560);
const vec3 PEBBLE_DARK = vec3(0.210, 0.220, 0.215);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Deux paliers (0, 0,5, 1), bord cassé par le grain.
float steps(float w, float grain) {
	float v = w + (grain - 0.5) * 0.34;
	return v < 0.3 ? 0.0 : (v < 0.68 ? 0.5 : 1.0);
}

void over(inout vec4 acc, vec3 c, float a) {
	float o = a + acc.a * (1.0 - a);
	if (o > 0.0) acc.rgb = (c * a + acc.rgb * acc.a * (1.0 - a)) / o;
	acc.a = o;
}

void fragment() {
	vec4 w = texture(TEXTURE, UV);
	vec2 p = origin + floor(UV / TEXTURE_PIXEL_SIZE * texel);
	float g = hash(floor(p / 2.0));
	float g1 = hash(p + 31.0);
	vec4 acc = vec4(0.0);
	float dense = steps(w.b, g);
	over(acc, DENSE, dense * 0.46);
	float clearing = steps(w.g, g);
	over(acc, CLEARING, clearing * 0.36);
	if (clearing > 0.0 && g1 < 0.035 * clearing) over(acc, BLADE, 0.7);
	float rocky = steps(w.a, g);
	over(acc, ROCKY, rocky * 0.46);
	if (rocky > 0.0) {
		float k = hash(floor(p / 2.0) + 7.0);
		if (k < 0.09 * rocky) over(acc, PEBBLE, 0.85);
		else if (k < 0.16 * rocky) over(acc, PEBBLE_DARK, 0.6);
	}
	float marsh = steps(w.r, g);
	over(acc, MARSH, marsh * 0.66);
	if (marsh > 0.0 && hash(floor(p / vec2(6.0, 2.0)) + 3.0) < 0.13 * marsh) over(acc, PUDDLE, 0.85);
	COLOR = acc;
}
