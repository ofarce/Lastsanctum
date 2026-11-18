shader_type canvas_item;
render_mode blend_disabled;
// Calque d'obscurité (drawLighting, lighting.js, 73b410f), rendu comme dans le prototype dans un calque au
// QUART de la résolution (SubViewport ceil(W/4) × ceil(H/4), couleurs 8 bits prémultipliées), puis agrandi
// en bilinéaire par lighting_upscale.gdshader (l'agrandissement CSS du navigateur) :
// - ambiance rgba(12, 7, 4, 0,28) ;
// - « destination-out » : chaque source creuse l'ombre avec un dégradé radial (1 → 0,8 à 45 % → 0) ;
// - vignette « source-over » rgba(6, 3, 2, 0 → 0,3), du rayon min(w, h)·0,35 au rayon max(w, h)·0,75.
// Une évaluation par pixel du calque (au centre du pixel), au lieu de quatre par pixel d'écran.

const int MAX_LIGHTS = 128;
uniform vec2 qsize = vec2(360.0, 225.0);
// Sources en pixels du calque au quart : (x, y, rayon, inutilisé).
uniform vec4 lights[MAX_LIGHTS];
uniform int light_count = 0;
// Cycle jour/nuit (core/day_night.gd) : obscurité du dehors (non prémultipliée), appliquée au sud du flanc
// de la montagne seulement. Repère : caméra (unités de monde), facteur de pixel, taille de l'écran.
uniform vec4 sky = vec4(0.047, 0.027, 0.016, 0.28);
uniform vec2 cam = vec2(0.0);
uniform float px = 2.0;
uniform vec2 screen = vec2(1440.0, 900.0);

void fragment() {
	vec2 p = UV * qsize;
	vec2 sp = p * 4.0;
	float wx = (sp.x - screen.x * 0.5) / (8.0 * px) + cam.x;
	float wz = (sp.y - screen.y * 0.45) / (8.0 * px) + cam.y;
	float edge = -78.0 + 4.0 * sin(wx * 0.13) + 3.0 * sin(wx * 0.31 + 1.0);
	float w = smoothstep(edge - 2.0, edge + 5.0, wz);
	float a = mix(0.28, sky.a, w);
	vec3 rgb = mix(vec3(12.0, 7.0, 4.0) / 255.0, sky.rgb, w) * a;
	for (int i = 0; i < MAX_LIGHTS; i++) {
		if (i >= light_count) break;
		vec4 l = lights[i];
		if (abs(p.x - l.x) > l.z || abs(p.y - l.y) > l.z) continue;
		float t = distance(p, l.xy) / l.z;
		float g = t < 0.45 ? mix(1.0, 0.8, t / 0.45) : (t < 1.0 ? mix(0.8, 0.0, (t - 0.45) / 0.55) : 0.0);
		a *= 1.0 - g;
		rgb *= 1.0 - g;
	}
	vec2 c = vec2(qsize.x / 2.0, qsize.y * 0.48);
	float r0 = min(qsize.x, qsize.y) * 0.35;
	float r1 = max(qsize.x, qsize.y) * 0.75;
	float va = 0.3 * clamp((distance(p, c) - r0) / (r1 - r0), 0.0, 1.0);
	rgb = vec3(6.0, 3.0, 2.0) / 255.0 * va + rgb * (1.0 - va);
	a = va + a * (1.0 - va);
	// Prémultiplié, comme le canvas du prototype.
	COLOR = vec4(rgb, a);
}
