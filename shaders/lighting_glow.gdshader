shader_type canvas_item;
render_mode blend_add;
// Lueur colorée additive d'une source (drawLighting, lighting.js, 73b410f) : dégradé radial
// rgba(couleur, glow) → rgba(couleur, 0) sur 0,8 × le rayon, composé en « lighter » sur le jeu.
// Un quadrilatère par source (lighting.gd) : UV 0–1 sur le carré circonscrit au disque ; la couleur du
// quadrilatère porte couleur × glow.

// Charte : la lueur tombe par paliers tramés (STEPS), au grain des sprites.
uniform float px = 2.0;
uniform vec2 origin = vec2(0.0);
const float STEPS = 5.0;
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

// Seuil de trame ordonnée (0–1) du pixel natif qui contient ce fragment : la trame est ancrée au monde
// (`origin` = position écran de l'origine du monde) et son point fait `px` pixels d'écran, comme un texel de sprite.
float bayer(vec2 frag, vec2 anchor, float cell) {
	ivec2 c = ivec2(floor((frag - anchor) / cell));
	return (BAYER[(c.y & 3) * 4 + (c.x & 3)] + 0.5) / 16.0;
}

void fragment() {
	float t = distance(UV, vec2(0.5)) * 2.0;
	float g = floor(max(0.0, 1.0 - t) * STEPS + bayer(FRAGCOORD.xy, origin, px)) / STEPS;
	COLOR = vec4(COLOR.rgb * g, 1.0);
}
