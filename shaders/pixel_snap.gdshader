shader_type canvas_item;
// Aligne l'origine de chaque sprite sur la grille des pixels natifs, comme natP() dans le
// prototype (Index.html) : position native = Math.round(position projetée / PX).
// Le monde est dessiné à la résolution écran, dans un nœud mis à l'échelle ×PX. Chaque sprite est
// arrondi individuellement, comme dans le prototype (la caméra, elle, se déplace de façon continue).
// Le décalage est ramené dans le repère local du sprite (inverse de sa base) : il reste correct pour
// un sprite retourné (échelle −1, unités tournées vers la gauche).

uniform float px = 1.0;

void vertex() {
	vec2 native_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy / px;
	vec2 delta = (floor(native_origin + 0.5) - native_origin) * px;
	mat2 basis = mat2(MODEL_MATRIX[0].xy, MODEL_MATRIX[1].xy);
	VERTEX += inverse(basis) * delta;
}
