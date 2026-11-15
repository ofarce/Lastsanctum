shader_type canvas_item;
// Orbe de l'Ancre (73b410f : drawDeco, Index.html). Position non arrondie (projection continue) ;
// éteinte, elle est dessinée avec ctx.filter = 'grayscale(.75) brightness(.55)' et globalAlpha = .75.
// Surcharge de l'Ancre (sim/overload.gd) : la sphère seule se soulève de `lift` pixels de texture,
// l'anneau runique et la lueur restent au sol.

uniform bool active = false;
uniform bool hovered = false;
uniform int lift = 0;
// Segments de l'anneau runique (8, masque de bits) : éteints (rompus) ou en éclat.
uniform int ring_dark = 0;
uniform int ring_flash = 0;
const vec2 RING_C = vec2(32.5, 38.5);
const vec3 RING_COL = vec3(154.0, 58.0, 184.0) / 255.0;
// Sphère dans orb_01 (64 × 64) : centre et rayon en pixels de texture, contour compris.
const vec2 SPHERE_C = vec2(32.5, 24.5);
const float SPHERE_R = 11.7;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (lift > 0) {
		vec2 p = floor(UV / TEXTURE_PIXEL_SIZE) + 0.5;
		vec2 q = p + vec2(0.0, float(lift));
		if (distance(q, SPHERE_C) <= SPHERE_R) {
			c = texture(TEXTURE, q * TEXTURE_PIXEL_SIZE);
		} else if (distance(p, SPHERE_C) <= SPHERE_R) {
			c = vec4(0.0);
		}
	}
	if ((ring_dark | ring_flash) != 0 && distance(c.rgb, RING_COL) < 0.02) {
		vec2 d = (floor(UV / TEXTURE_PIXEL_SIZE) + 0.5 - RING_C) / vec2(15.0, 6.0);
		float e = length(d);
		if (e > 0.8 && e < 1.25) {
			// orbDraw : 64 points sur l'ellipse, segment k = points 8k à 8k + 4.
			float a = fract(atan(d.y, d.x) / 6.2831853 + 1.0);
			int k = int(floor(a * 8.0 + 0.03)) & 7;
			if (((ring_flash >> k) & 1) != 0) {
				c.rgb = vec3(0.902, 0.722, 1.0);
			} else if (((ring_dark >> k) & 1) != 0) {
				c.rgb = vec3(0.078, 0.024, 0.11);
			}
		}
	}
	if (!active) {
		// grayscale(a) des filtres CSS : mélange vers la luminance Rec. 709 ; puis brightness.
		float lum = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
		c.rgb = mix(c.rgb, vec3(lum), 0.75) * (hovered ? 0.72 : 0.55);
		c.a *= hovered ? 0.85 : 0.75;
	}
	COLOR = c * COLOR;
}
