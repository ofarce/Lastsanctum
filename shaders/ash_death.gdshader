shader_type canvas_item;
// Mort « Souffle » des ennemis (entities/unit/ash_death.gd, planche planches/mort-ennemis-propositions.html,
// piste 3). Un grain par instance du MultiMesh ; toute la trajectoire est une formule de l'âge, rien n'est
// simulé côté script. INSTANCE_CUSTOM = (vx, vz, départ t0 [+1 pour une étincelle], hauteur de départ z0),
// en px natifs et en secondes. Le reste de l'aléa vient d'INSTANCE_ID.
// Paliers de couleur francs, aucun fondu : blanc tant que le grain tient au corps, rampe de braise en vol,
// cendre au sol (quelques braises y luisent encore un instant).

uniform float age = 0.0;
uniform vec4 ramp[7] : source_color;

const float DRAG = 5.0;        // frein horizontal (1/s)
const float GRAV = 600.0;      // chute des grains (px/s²)
const float SPARK_GRAV = 240.0;
const vec3 WHITE = vec3(1.0, 0.965, 0.863);

varying vec3 tint;
varying float gone;

float hash(float n) {
	return fract(sin(n * 12.9898 + 4.137) * 43758.5453);
}

void vertex() {
	float id = float(INSTANCE_ID);
	float h1 = hash(id), h2 = hash(id + 71.3), h3 = hash(id * 1.7 + 13.1), h4 = hash(id * 2.3 + 5.7);
	bool spark = INSTANCE_CUSTOM.z >= 1.0;
	float t0 = spark ? INSTANCE_CUSTOM.z - 1.0 : INSTANCE_CUSTOM.z;
	float vx = INSTANCE_CUSTOM.x, vz = INSTANCE_CUSTOM.y, z0 = max(INSTANCE_CUSTOM.w, 0.0);
	float grav = spark ? SPARK_GRAV : GRAV;
	// Instant où le grain touche le sol : chute sans frein, donc solution directe.
	float land = (vz + sqrt(vz * vz + 2.0 * grav * z0)) / grav;
	float t = age - t0;
	float tau = clamp(t, 0.0, land);
	float e = exp(-DRAG * tau);
	float vg = (h1 + h2 + h3 - 1.5) * 60.0;                   // dérive en profondeur, resserrée au centre
	vec2 vel = vec2(vx * e, -(vz - grav * tau) + vg * e);
	vec2 move = vec2(vx, vg) * (1.0 - e) / DRAG;
	move.y -= vz * tau - 0.5 * grav * tau * tau;
	bool flying = t > 0.0 && t < land;
	float heat = 1.0 - (spark ? 2.6 + h4 * 1.6 : 2.0 + h4 * 1.5) * max(t, 0.0);
	vec2 corner = UV * 2.0 - 1.0;
	gone = 0.0;
	if (spark) {
		if (t <= 0.0 || t >= min(land, 0.22 + h3 * 0.3)) {
			gone = 1.0;
		}
	} else if (t <= 0.0) {
		move += corner * 0.25;                                 // attaché : le grain couvre son pixel entier
	} else {
		move += vec2(h1 < 0.5 ? -0.25 : 0.25, h2 < 0.5 ? -0.25 : 0.25);
		if (t >= land) {
			move += corner * 0.25;                             // posé : un pixel plein, pour que le tas se lise
		}
	}
	// En vol et encore chaud : le grain s'étire en trait dans le sens de sa course.
	if (flying && (spark || heat > 0.3) && dot(corner, vel) < 0.0) {
		move -= vel * (spark ? 0.03 : 0.016);
	}
	VERTEX += move;
	vec3 ash = h2 < 0.25 ? vec3(0.549, 0.533, 0.573) : h2 < 0.55 ? vec3(0.431, 0.416, 0.455)
			: h2 < 0.8 ? vec3(0.333, 0.322, 0.361) : vec3(0.247, 0.235, 0.275);
	float ember = 0.25 + h1 * 0.8;
	if (t <= 0.0) {
		tint = WHITE;
	} else if (heat > 0.0) {
		tint = ramp[int(clamp(floor((1.0 - heat) * 7.0), 0.0, 6.0))].rgb;
	} else if (!flying && h3 < 0.07 && t - land < ember) {
		tint = ramp[2 + int(clamp(floor((t - land) / ember * 4.0), 0.0, 3.0))].rgb;
	} else {
		tint = ash;
	}
}

void fragment() {
	if (gone > 0.5) {
		discard;
	}
	COLOR = vec4(tint, COLOR.a);
}
