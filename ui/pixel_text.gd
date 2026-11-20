class_name PixelText
extends RefCounted
## Texte « bitmap » pour ce qui vit dans le monde (chiffres de dégâts, invites, badges) : DejaVu Sans rendue
## sans lissage à 8 px puis agrandie par un facteur entier, pour garder le grain des sprites. La serif lissée
## du HUD (HudStyle.font) reste réservée aux panneaux.

const SIZE := 8
const INK := Color("#0b090b")
static var _font: FontFile


static func font() -> Font:
	if _font == null:
		_font = (load("res://assets/fonts/DejaVuSans.ttf") as FontFile).duplicate()
		_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_font.hinting = TextServer.HINTING_NORMAL
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return _font


## Largeur du texte, en pixels du repère de `draw` (déjà multipliée par `scale`).
static func width(text: String, scale := 2) -> float:
	return font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x * scale


## Texte centré sur `at` (ligne de base), contour d'un pixel de texte. Remet la transformation de `ci` à zéro.
static func draw(ci: CanvasItem, at: Vector2, text: String, color: Color, scale := 2, alpha := 1.0) -> void:
	var f := font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x
	ci.draw_set_transform(at.round(), 0.0, Vector2(scale, scale))
	var base := Vector2(-roundf(w / 2.0), 0)
	var ink := Color(INK, alpha)
	for d: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(1, 1)]:
		ci.draw_string(f, base + d, text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, ink)
	ci.draw_string(f, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, Color(color, alpha))
	ci.draw_set_transform(Vector2.ZERO)
