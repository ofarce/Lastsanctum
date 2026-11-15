shader_type canvas_item;
// Orbe de l'Ancre (73b410f : drawDeco, Index.html). Position non arrondie (projection continue) ;
// éteinte, elle est dessinée avec ctx.filter = 'grayscale(.75) brightness(.55)' et globalAlpha = .75.

uniform bool active = false;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (!active) {
		// grayscale(a) des filtres CSS : mélange vers la luminance Rec. 709 ; puis brightness.
		float lum = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
		c.rgb = mix(c.rgb, vec3(lum), 0.75) * 0.55;
		c.a *= 0.75;
	}
	COLOR = c * COLOR;
}
