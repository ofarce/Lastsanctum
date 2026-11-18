shader_type canvas_item;
// Bassin souterrain (planche ambiances-montagne-detail.html, piste 01). Texture d'entrée :
// R = profondeur (0 = berge), G = contour, B = berge mouillée, A = emprise. Rendu en paliers, 12 i/s.

uniform vec2 size;

const vec3 OUT = vec3(0.043, 0.035, 0.043);
const vec3 SHALLOW = vec3(0.180, 0.290, 0.369);
const vec3 WATER = vec3(0.157, 0.251, 0.353);
const vec3 DEEP = vec3(0.075, 0.125, 0.188);
const vec3 CREST = vec3(0.290, 0.404, 0.510);
const vec3 LIP = vec3(0.357, 0.478, 0.573);

void fragment() {
	vec4 d = texture(TEXTURE, UV);
	if (d.a < 0.5) discard;
	vec2 p = floor(UV * size);
	float t = floor(TIME * 12.0) / 12.0;
	if (d.g > 0.5) {
		COLOR = vec4(OUT, 1.0);
	} else if (d.r <= 0.001) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.38 * d.b);
	} else {
		float depth = d.r;
		vec4 c;
		if (depth < 0.18) {
			c = vec4(SHALLOW, 0.55);
		} else {
			float k = floor(clamp((depth - 0.18) * 1.6, 0.0, 1.0) * 4.0) / 4.0;
			c = vec4(mix(WATER, DEEP, k), 1.0);
		}
		float w = sin(p.x * 0.32 + t * 1.8 + sin(p.y * 0.7 + t) * 1.5) + sin(p.x * 0.11 - t * 1.1 + p.y * 0.4);
		if (w > 1.25 && depth > 0.1) c = vec4(CREST, max(c.a, 0.85));
		if (d.b > 0.5 && depth < 0.3) c = vec4(LIP, 0.75);
		COLOR = c;
	}
}
