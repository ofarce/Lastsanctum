class_name SnesBanner
extends RefCounted
## Bannière de texte façon RPG 16 bits (référence fournie le 2026-11-19 : boîte bleue en dégradé, double
## liseré clair, coins cassés, texte blanc ombré). Sert à toutes les notifications et à tous les dialogues,
## en haut de l'écran.

const TOP := 70.0  # sous le bandeau des ressources
const MAX_W := 680.0
const PAD := Vector2(18, 12)
const FONT_SIZE := 15
const LINE_H := 22.0
const SKY := Color("#5a6ad0")
const DEEP := Color("#141c6a")
const RIM := Color("#e6e8f4")
const RIM_LO := Color("#8a90b8")
const EDGE := Color("#0a0c26")
const INK := Color("#ffffff")
const SHADOW := Color("#10123a")


## Largeur de la bannière pour un écran donné.
static func width(screen: Vector2) -> float:
	return minf(MAX_W, screen.x - 32.0)


## Libellé blanc ombré, police du HUD.
static func label() -> Label:
	var l := HudStyle.label(FONT_SIZE, INK)
	l.add_theme_color_override("font_shadow_color", SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("line_spacing", int(LINE_H) - FONT_SIZE - 4)
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Hauteur nécessaire au texte dans une bannière de largeur w.
static func height(text: String, w: float) -> float:
	var f := HudStyle.font()
	var inner := w - 2.0 * PAD.x
	var lines := 0
	for part in text.split("\n"):
		lines += maxi(1, roundi(f.get_multiline_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, inner, FONT_SIZE).y / f.get_height(FONT_SIZE)))
	return lines * LINE_H + 2.0 * PAD.y


## Deux teintes pour un seul cadre : DIALOGUE (bleu, bannières et invites) et INFO (ardoise, panneaux du HUD).
## Chaque teinte = [haut du dégradé, bas du dégradé], puis facultativement [liseré clair, liseré bas, contour].
const DIALOGUE: Array[Color] = [SKY, DEEP]
## INFO = « Sarcelle » (choix du 2026-11-19, planches/hud-teintes-propositions.html) : le cyan des Exilés assombri.
const INFO: Array[Color] = [Color("#1f4f5c"), Color("#0a1d24"), Color("#d6f6fb"), Color("#5fa9b8"), Color("#04141a")]


## Dessine la boîte dans r (coordonnées du CanvasItem). `small` : cadre resserré (liseré simple, sans ombre)
## pour les petites étiquettes posées dans le monde.
static func paint(ci: CanvasItem, r: Rect2, tone: Array[Color] = DIALOGUE, small := false) -> void:
	r = Rect2(r.position.round(), r.size.round())
	var rim: Color = tone[2] if tone.size() > 2 else RIM
	var rim_lo: Color = tone[3] if tone.size() > 3 else RIM_LO
	var edge: Color = tone[4] if tone.size() > 4 else EDGE
	if small:
		_chamfer(ci, r, 2.0, edge)
		_chamfer(ci, r.grow(-1.0), 1.0, rim)
		var core := r.grow(-2.0)
		ci.draw_rect(Rect2(core.position, Vector2(core.size.x, ceilf(core.size.y / 2.0))), tone[0].lerp(tone[1], 0.25))
		ci.draw_rect(Rect2(core.position + Vector2(0, ceilf(core.size.y / 2.0)), Vector2(core.size.x, floorf(core.size.y / 2.0))), tone[0].lerp(tone[1], 0.75))
		return
	# Ombre portée.
	ci.draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.35))
	# Contour sombre, coins cassés de 3 px.
	_chamfer(ci, r, 3.0, edge)
	_chamfer(ci, r.grow(-1.0), 3.0, rim)
	_chamfer(ci, r.grow(-3.0), 2.0, rim_lo)
	var inner := r.grow(-4.0)
	# Dégradé vertical par bandes (rendu tramé 16 bits).
	var bands := 12
	for i in bands:
		var y0 := inner.position.y + inner.size.y * i / bands
		var y1 := inner.position.y + inner.size.y * (i + 1) / bands
		ci.draw_rect(Rect2(inner.position.x, floorf(y0), inner.size.x, ceilf(y1) - floorf(y0)), tone[0].lerp(tone[1], float(i) / (bands - 1)))
	# Reflet haut.
	ci.draw_rect(Rect2(inner.position + Vector2(1, 1), Vector2(inner.size.x - 2, 1)), Color(1, 1, 1, 0.25))


static func _chamfer(ci: CanvasItem, r: Rect2, c: float, col: Color) -> void:
	var p := r.position
	var s := r.size
	ci.draw_colored_polygon(PackedVector2Array([
		p + Vector2(c, 0), p + Vector2(s.x - c, 0), p + Vector2(s.x, c), p + Vector2(s.x, s.y - c),
		p + Vector2(s.x - c, s.y), p + Vector2(c, s.y), p + Vector2(0, s.y - c), p + Vector2(0, c)]), col)
