shader_type canvas_item;
// Rivière de la jungle (world/terrain/river.gd). Texture d'entrée :
// R = profondeur relative (0 berge → 1 milieu), G = rapide (eau qui écume), B = crue (0 hors crue),
// A = emprise de l'eau. Rendu en paliers (pixel art), 12 i/s, courant d'ouest en est.

uniform vec2 origin; // pixel monde du coin haut gauche
uniform float flood = 0.0; // seuil de crue lu dans B (0 = pas de crue)
uniform bool flood_only = false; // couche posée sur les berges : seulement l'eau de crue

const vec3 SHALLOW = vec3(0.243, 0.420, 0.380);
const vec3 WATER = vec3(0.165, 0.318, 0.337);
const vec3 DEEP = vec3(0.098, 0.208, 0.247);
const vec3 CREST = vec3(0.392, 0.565, 0.522);
const vec3 FOAM = vec3(0.737, 0.812, 0.749);

void fragment() {
	vec4 d = texture(TEXTURE, UV);
	bool flooded = flood > 0.0 && d.b > 0.0 && d.b <= flood;
	if (d.a < 0.5 && !flooded) discard;
	if (flood_only && !flooded) discard;
	vec2 p = origin + floor(UV / TEXTURE_PIXEL_SIZE);
	float t = floor(TIME * 12.0) / 12.0;
	if (flooded) {
		float edge = smoothstep(flood - 0.03, flood, d.b);
		float w = sin((p.x - t * 9.0) * 0.21 + p.y * 0.4);
		COLOR = vec4(w > 1.2 ? CREST : SHALLOW, 0.7 - edge * 0.3);
	} else {
		float depth = d.r;
		vec3 c;
		if (depth < 0.15) c = SHALLOW;
		else c = mix(WATER, DEEP, floor(clamp((depth - 0.15) * 1.4, 0.0, 1.0) * 3.0) / 3.0);
		float w = sin((p.x - t * 9.0) * 0.21 + sin(p.y * 0.5 + t * 0.7) * 1.4) + sin((p.x - t * 14.0) * 0.07 + p.y * 0.33);
		if (w > 1.35 && depth > 0.12) c = CREST;
		float f = fract(sin(dot(floor((p - vec2(t * 18.0, 0.0)) / 2.0), vec2(12.9898, 78.233))) * 43758.5453);
		if (d.g > 0.0 && f < d.g * 0.55) c = FOAM;
		if (depth < 0.05 && fract(p.x * 0.5 + p.y * 0.5) < 0.5 && f < 0.5) c = CREST;
		COLOR = vec4(c, 1.0);
	}
}
