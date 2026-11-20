shader_type canvas_item;
// Nappe de corruption d'un Pylône de Merenor (planches/pylone-merenor-v2-propositions.html :
// forme « Nappe débordante », matière « D · Mousse veinée »). Même forme que Pylons.edge (sim/pylons.gd) :
// R(θ) lu dans `lobes`, bruit local dans TEXTURE (R = bruit + 0,5), flaques dans `sats`, retrait `cover`.
// Mousse alvéolée, veines rouges qui battent depuis le pylône, spores. Rendu en pixels natifs, 12 i/s.

uniform float size = 512.0;
uniform float extent = 32.0;
uniform vec2 origin_px;
uniform float cover = 1.0;
uniform sampler2D lobes : filter_linear, repeat_enable;
uniform sampler2D ground_mask : filter_nearest;
uniform vec4 sats[9];

const vec3 PORE = vec3(6.0, 5.0, 8.0) / 255.0;
const vec3 RIDGE = vec3(30.0, 26.0, 36.0) / 255.0;
const vec3 BODY = vec3(19.0, 16.0, 24.0) / 255.0;
const vec3 CREST = vec3(38.0, 34.0, 44.0) / 255.0;
const vec3 VEIN_DARK = vec3(46.0, 14.0, 18.0) / 255.0;
const vec3 RED0 = vec3(58.0, 12.0, 16.0) / 255.0;
const vec3 RED1 = vec3(110.0, 26.0, 28.0) / 255.0;
const vec3 RED2 = vec3(168.0, 48.0, 42.0) / 255.0;
const vec3 RED3 = vec3(224.0, 88.0, 58.0) / 255.0;
const vec3 RED4 = vec3(255.0, 180.0, 138.0) / 255.0;
const vec3 SPORE = vec3(78.0, 72.0, 86.0) / 255.0;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), u.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return vn(p) * 0.57 + vn(p * 2.1 + 7.0) * 0.29 + vn(p * 4.3 + 13.0) * 0.14;
}

// Distance au centre de l'alvéole la plus proche (cellules de 5 px).
float cells(vec2 p) {
	vec2 g = floor(p / 5.0);
	float d = 9.0;
	for (int a = -1; a <= 1; a++) {
		for (int b = -1; b <= 1; b++) {
			vec2 c = g + vec2(float(a), float(b));
			vec2 q = (c + vec2(h21(c + 3.1), h21(c + 4.7))) * 5.0;
			d = min(d, length(p - q));
		}
	}
	return d;
}

vec3 red(float lv) {
	float k = floor(clamp(lv, 0.0, 1.0) * 4.0 + 0.5);
	return k < 0.5 ? RED0 : k < 1.5 ? RED1 : k < 2.5 ? RED2 : k < 3.5 ? RED3 : RED4;
}

void fragment() {
	vec2 npx = floor(UV * size);
	if (texture(ground_mask, (npx + 0.5) / size).r < 0.5) discard;
	vec2 w = (npx + 0.5) / 8.0 - vec2(extent);
	float loc = texture(TEXTURE, UV).r - 0.5;
	float dx = w.x;
	float dz = w.y * 1.12;
	float d = length(vec2(dx, dz));
	float a = atan(dz, dx);
	float R = texture(lobes, vec2(fract(a / 6.2831853), 0.5)).r * 32.0;
	float e = R + 3.25 * loc - d;
	for (int k = 0; k < 9; k++) {
		vec4 s = sats[k];
		e = max(e, s.z + 0.75 * loc - length(w - s.xy));
	}
	e = min(e, cover * 26.0 - (d + 2.25 * loc));
	float epx = e * 8.0;
	if (epx < -1.5) discard;
	if (epx < 0.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.28);
	} else {
		float t = floor(TIME * 12.0) / 12.0;
		vec2 gp = origin_px + npx;
		float cd = cells(gp);
		vec3 c = cd < 0.9 ? PORE : cd < 1.6 ? RIDGE : BODY;
		if (fbm(gp * 0.3) > 0.68 && cd > 1.6) c = CREST;
		float v = abs(fbm(gp * 0.05 + 31.0) - 0.5);
		if (v < 0.011) {
			float rr = length(npx - vec2(size * 0.5));
			float lv = 0.2 + 0.6 * max(0.0, sin(rr * 0.18 - t * 3.2));
			c = red(lv);
			if (v >= 0.006) c = mix(c, vec3(30.0, 10.0, 14.0) / 255.0, 0.45);
		} else if (v < 0.02 && cd < 1.6) {
			c = VEIN_DARK;
		}
		// Spores : quelques points qui montent et s'effacent.
		vec2 sc = floor(gp / vec2(9.0, 14.0));
		float ph = fract(t / 1.6 + h21(sc + 9.3));
		vec2 sp = sc * vec2(9.0, 14.0) + vec2(floor(h21(sc + 2.2) * 9.0), 13.0 - floor(ph * 14.0));
		if (gp == sp && h21(sc + 5.5) > 0.8 && h21(gp + floor(t * 12.0)) > ph) c = h21(sc + 7.1) < 0.25 ? RED2 : SPORE;
		COLOR = vec4(c, epx < 1.2 ? 0.6 : 1.0);
	}
}
