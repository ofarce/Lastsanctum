shader_type canvas_item;
render_mode unshaded, blend_add;
// Halo de l'étincelle de l'Ancre (AnchorSpark), appliqué au CanvasGroup « Glow ».
// Les enfants y dessinent des disques opaques dont le rouge code le palier (0,25 → palier 3 … 1 → palier 0),
// du plus large au plus serré : un disque recouvre les précédents, ce qui donne le maximum par pixel.
// Ici, chaque pixel natif (carré de px × px pixels d'écran) lit son centre, puis ajoute la lueur argentée
// du palier ; le palier le plus faible est tramé en damier.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float px = 1.0;
uniform vec3 glow_rgb = vec3(0.871, 0.894, 0.949);
uniform vec4 alphas = vec4(0.66, 0.48, 0.30, 0.17);

void fragment() {
	vec2 cell = floor(SCREEN_UV / SCREEN_PIXEL_SIZE / px);
	vec4 c = textureLod(screen_texture, (cell + 0.5) * px * SCREEN_PIXEL_SIZE, 0.0);
	float a = 0.0;
	if (c.a > 0.5) {
		float r = c.r / c.a;
		if (r > 0.875) {
			a = alphas.x;
		} else if (r > 0.625) {
			a = alphas.y;
		} else if (r > 0.375) {
			a = alphas.z;
		} else if (r > 0.125 && mod(cell.x + cell.y, 2.0) < 0.5) {
			a = alphas.w;
		}
	}
	COLOR = vec4(glow_rgb, a);
}
