shader_type canvas_item;
render_mode blend_add;
// Lueur colorée additive d'une source (drawLighting, lighting.js, 73b410f) : dégradé radial
// rgba(couleur, glow) → rgba(couleur, 0) sur 0,8 × le rayon, composé en « lighter » sur le jeu.
// Un quadrilatère par source (lighting.gd) : UV 0–1 sur le carré circonscrit au disque ; la couleur du
// quadrilatère porte couleur × glow.

void fragment() {
	float t = distance(UV, vec2(0.5)) * 2.0;
	COLOR = vec4(COLOR.rgb * max(0.0, 1.0 - t), 1.0);
}
