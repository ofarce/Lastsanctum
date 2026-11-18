shader_type canvas_item;
// Fin de l'arrivée d'un esprit à l'autel (planches/esprits-v3-propositions.html, « Germe de l'autel ») :
// les pixels du sprite passent de la couleur unie du dieu à leurs vraies couleurs par une trame ordonnée
// (Bayer 4×4) calée sur les texels de l'atlas. Le contour noir reste net.
uniform float tint : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flat_color : source_color = vec4(1.0);
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	ivec2 p = ivec2(floor(UV / TEXTURE_PIXEL_SIZE));
	float b = BAYER[(p.y & 3) * 4 + (p.x & 3)] / 16.0;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	if (b < tint && lum > 0.08) {
		c.rgb = mix(flat_color.rgb, vec3(1.0), 0.15);
	}
	COLOR = c;
}
