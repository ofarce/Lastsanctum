shader_type canvas_item;
// Matériau unique des objets triés par profondeur (décor, bâtiments, unités) — étape 12 : une seule
// texture (planche du décor) et un seul matériau permettent à Godot de regrouper les appels de dessin.
//
// 1. Cas général (pixel_snap.gdshader) : l'origine de chaque sprite est alignée sur la grille des pixels
//    natifs, comme natP() dans le prototype (Index.html) : position native = Math.round(position / PX).
//    Le décalage est ramené dans le repère local du sprite (sprite retourné compris).
// 2. Feuillage (ancien wind_foliage.gdshader ; drawWindTree, wind.js ; treeVariant, decor-renderer.js) : reconnu
//    par la texture de métadonnées de la planche (decor_atlas_meta.png), lue au point d'ancrage du sprite
//    (retrouvé depuis UV et VERTEX) : (255, ay, type, 255). Cisaillement par le vent quantifié autour du point
//    au sol (le sommet, à la hauteur ay, se décale par pas de PX/3 pixels d'écran), et dessin LISSÉ : filtrage
//    bilinéaire fait ici (texelFetch), les bords de chaque sprite étant prolongés dans la planche.
//    Pas de modulation propre au feuillage : elle casserait le regroupement des appels de dessin.

uniform float px = 1.0;
// Position écran de l'origine du monde (natW = 0) : permet de retrouver (x, z) du sprite.
uniform vec2 world_origin = vec2(0.0);
uniform float sim_time = 0.0;
// 1 en jeu ; 0 pour figer le vent (captures de validation).
uniform float wind_scale = 1.0;
// (amplitude, hauteur de référence) par type d'arbre (WIND_TREES, wind.js:2), dans l'ordre de Wind.KINDS.
uniform vec2 kinds[8];
uniform sampler2D meta : filter_nearest, repeat_disable;
uniform vec2 atlas_size = vec2(1024.0, 512.0);

varying float leaf;

float wind_at(float x, float z, float t) {
	float phase = x * 0.047 + z * 0.031;
	return sin(t * 1.05 - phase) * 0.72 + sin(t * 1.83 + phase * 1.7) * 0.28;
}

void vertex() {
	vec2 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	vec2 native_origin = origin / px;
	leaf = 0.0;
	vec4 m = vec4(0.0);
	if (all(lessThan(abs(1.0 / TEXTURE_PIXEL_SIZE - atlas_size), vec2(0.5)))) {
		// Point d'ancrage du sprite (origine locale) dans la planche : UV est affine en VERTEX, pente 1 texel.
		vec2 anchor = floor((UV - VERTEX * TEXTURE_PIXEL_SIZE) * atlas_size + 0.5);
		m = texelFetch(meta, ivec2(anchor), 0);
		leaf = m.r > 0.5 ? 1.0 : 0.0;
	}
	if (leaf > 0.5) {
		float anchor_y = floor(m.g * 255.0 + 0.5);
		vec2 k = kinds[int(floor(m.b * 255.0 + 0.5))];
		// natW(x, 0, z) = (x·8, z·8) : inversion pour retrouver x et z.
		vec2 world = (origin - world_origin) / px / 8.0;
		float shear = -wind_at(world.x, world.y, sim_time) * k.x / k.y * wind_scale;
		// Math.round du JS : floor(v + 0,5).
		float n = floor(shear * anchor_y * 3.0 + 0.5);
		VERTEX.x += n / (3.0 * anchor_y) * VERTEX.y;
		VERTEX += floor(native_origin + 0.5) - native_origin;
	} else {
		vec2 delta = (floor(native_origin + 0.5) - native_origin) * px;
		mat2 basis = mat2(MODEL_MATRIX[0].xy, MODEL_MATRIX[1].xy);
		VERTEX += inverse(basis) * delta;
	}
}

void fragment() {
	if (leaf > 0.5) {
		vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
		vec2 p = UV * size - 0.5;
		vec2 i0 = floor(p);
		vec2 f = p - i0;
		ivec2 a = ivec2(i0);
		vec4 c00 = texelFetch(TEXTURE, a, 0);
		vec4 c10 = texelFetch(TEXTURE, a + ivec2(1, 0), 0);
		vec4 c01 = texelFetch(TEXTURE, a + ivec2(0, 1), 0);
		vec4 c11 = texelFetch(TEXTURE, a + ivec2(1, 1), 0);
		COLOR = mix(mix(c00, c10, f.x), mix(c01, c11, f.x), f.y);
	}
	// Sinon : COLOR reçu = texture (filtre du nœud) × modulation, comme le fragment par défaut.
}
