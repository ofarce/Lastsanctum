shader_type canvas_item;
render_mode unshaded;
// Aura de la Martyre de Byrsa (planches/martyre-aura-propositions.html, bilan du 2026-11-20 : teinte C Améthyste,
// forme C « Dégradé tramé », la teinte suit ses pieds, lever et chute B « Front tramé »).
// Dessiné sous le voile du dôme (MartyreDome.AuraTint), après le sol et avant les sprites : chaque pixel natif lit
// le sol déjà peint et le remplace par la rampe améthyste à sa valeur (carte de valeurs), en trame Bayer 4 × 4.
// Force : pleine à NEAR px de ses pieds, `far_level` à FAR px ; front de lever/chute tramé sur FRONT_W px.
// Repère : VERTEX en pixels natifs du monde (le nœud World est mis à l'échelle ×px).

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float px = 1.0;
uniform vec2 dome_center;
uniform float dome_radius = 384.0;
uniform vec2 feet;
uniform float front = 100000.0;
uniform float strength = 1.0;
uniform float far_level = 0.4;

const float NEAR = 24.0;
const float FAR = 144.0;
const float FRONT_W = 26.0;
const vec3 RAMP0 = vec3(23.0, 8.0, 38.0) / 255.0;
const vec3 RAMP1 = vec3(46.0, 18.0, 80.0) / 255.0;
const vec3 RAMP2 = vec3(76.0, 34.0, 128.0) / 255.0;
const vec3 RAMP3 = vec3(116.0, 68.0, 176.0) / 255.0;

varying vec2 native;

void vertex() {
	native = VERTEX;
}

float bayer(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[y * 4 + x]) + 0.5) / 16.0;
}

vec3 ramp(int i) {
	return i <= 0 ? RAMP0 : i == 1 ? RAMP1 : i == 2 ? RAMP2 : RAMP3;
}

void fragment() {
	vec2 cell = floor(native);
	if (length(cell + 0.5 - dome_center) >= dome_radius) discard;
	vec2 rel = cell + 0.5 - feet;
	float d = length(vec2(rel.x, rel.y * 1.15));
	float s = mix(1.0, far_level, smoothstep(NEAR, FAR, d));
	s *= clamp((front - d) / FRONT_W, 0.0, 1.0) * strength;
	if (s <= bayer(cell)) discard;
	vec2 uv = SCREEN_UV + (cell + 0.5 - native) * px * SCREEN_PIXEL_SIZE;
	vec3 g = textureLod(screen_texture, uv, 0.0).rgb;
	float lum = dot(g, vec3(0.3, 0.59, 0.11));
	float t = clamp((lum - 0.07) / 0.3, 0.0, 1.0) * 3.0;
	int ti = int(floor(t));
	int tc = min(3, ti + (fract(t) > bayer(cell + vec2(2.0, 1.0)) ? 1 : 0));
	COLOR = vec4(ramp(tc), 1.0);
}
