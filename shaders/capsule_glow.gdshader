shader_type canvas_item;
// Ingénieur dans le puits de lumière (planches/capsule-dais-propositions.html, 14C, rendu « baigné de
// lumière ») : le sprite est mêlé à la teinte de la colonne. La part de teinte passe par le rouge de la
// couleur de dessin (modulate.r : 0 = vraies couleurs, 1 = teinte unie), l'opacité par son alpha.
uniform vec4 tint : source_color = vec4(0.624, 0.902, 1.0, 1.0);

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	COLOR = vec4(mix(t.rgb, tint.rgb, COLOR.r), t.a * COLOR.a);
}
