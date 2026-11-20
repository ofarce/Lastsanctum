class_name ResearchShelf
extends Control
## Recherches achevées (2026-11-20) : une rangée de plaques en haut à gauche, sous la carte de vague, qui remplace
## les boutons « Déjà achevée » des bâtiments. Chaque plaque porte l'icône pleine de la recherche (celle du bouton
## achevé) ; le survol ouvre une bulle sous la plaque : nom et effet.

const CELL := 40.0
const GAP := 6.0
const ICON := 32.0
const BUBBLE_W := 340.0

var ids: Array[String] = []
var _hover := -1
var _bubble := _Bubble.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_bubble.visible = false
	_bubble.z_index = 20
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bubble)
	mouse_exited.connect(func() -> void: _set_hover(-1))


## Recherches achevées, dans l'ordre du catalogue. Vrai si la liste a changé (la taille suit).
func update_ids() -> bool:
	var next: Array[String] = []
	for id: String in Catalog.RESEARCH:
		if GameState.research_done.has(id):
			next.append(id)
	if next == ids:
		return false
	ids = next
	visible = not ids.is_empty()
	size = Vector2(maxf(0.0, ids.size() * (CELL + GAP) - GAP), CELL)
	_set_hover(-1)
	queue_redraw()
	return true


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var px: float = (event as InputEventMouseMotion).position.x
		var i := int(floorf(px / (CELL + GAP)))
		var inside: bool = i >= 0 and i < ids.size() and px - i * (CELL + GAP) <= CELL
		_set_hover(i if inside else -1)


func _set_hover(i: int) -> void:
	if i == _hover:
		return
	_hover = i
	queue_redraw()
	if i < 0:
		_bubble.visible = false
		return
	var R: Dictionary = Catalog.RESEARCH[ids[i]]
	_bubble.set_text(R["name"], String(R.get("desc", "")))
	var cx := i * (CELL + GAP) + CELL / 2.0
	var screen_w := get_viewport_rect().size.x
	var x := clampf(cx - _bubble.size.x / 2.0, 8.0 - global_position.x, screen_w - 8.0 - global_position.x - _bubble.size.x)
	_bubble.position = Vector2(x, CELL + 10.0)
	_bubble.tip_x = cx - x
	_bubble.visible = true
	_bubble.queue_redraw()


func _draw() -> void:
	for i in ids.size():
		var r := Rect2(i * (CELL + GAP), 0.0, CELL, CELL)
		draw_rect(r, Color("#0d0f0be6"))
		HudStyle.ring(self, r, 1.0, HudStyle.GOLD_LIGHT if i == _hover else HudStyle.GOLD)
		var inner := r.grow(-3.0)
		HudStyle.ring(self, inner, 1.0, Color("#3a2f1c"))
		var tex := ActionButton._Glyph._full_tex(ids[i])
		var pos := r.position + Vector2((CELL - ICON) / 2.0, (CELL - ICON) / 2.0)
		draw_texture_rect(tex, Rect2(pos, Vector2(ICON, ICON)), false, Color.WHITE if i == _hover else Color(0.92, 0.92, 0.9))


## Bulle dorée sous la plaque, pointe vers le haut : nom (ivoire), « Recherche achevée » (vert), effet sur
## plusieurs lignes.
class _Bubble extends Control:
	var tip_x := 0.0
	var _name := ""
	var _desc := ""
	var _desc_h := 0.0

	func set_text(name: String, desc: String) -> void:
		_name = name
		_desc = desc
		var f := HudStyle.font()
		var head := HudStyle.text_width(name, 15) + HudStyle.text_width("  ·  Recherche achevée", 13)
		var w := clampf(maxf(head, HudStyle.text_width(desc, 13)), head, BUBBLE_W)
		_desc_h = 0.0
		if desc:
			_desc_h = f.get_multiline_string_size(desc, HORIZONTAL_ALIGNMENT_LEFT, w, 13).y
		size = Vector2(w + 28.0, 32.0 + (_desc_h + 6.0 if desc else 0.0))

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("#0d0f0bf2"))
		HudStyle.ring(self, r, 1.0, Color("#e8c35a"))
		var t := clampf(tip_x, 10.0, size.x - 10.0)
		draw_colored_polygon(PackedVector2Array([Vector2(t - 7, 0), Vector2(t + 7, 0), Vector2(t, -7)]), Color("#e8c35a"))
		draw_colored_polygon(PackedVector2Array([Vector2(t - 5.5, 1), Vector2(t + 5.5, 1), Vector2(t, -4.5)]), Color("#0d0f0b"))
		var f := HudStyle.font()
		draw_string(f, Vector2(14.0, 21.0), _name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, HudStyle.IVORY)
		var x := 14.0 + HudStyle.text_width(_name, 15)
		draw_string(f, Vector2(x, 21.0), "  ·  ", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, HudStyle.MUTED)
		x += HudStyle.text_width("  ·  ", 13)
		draw_string(f, Vector2(x, 21.0), "Recherche achevée", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#a8d890"))
		if _desc:
			draw_multiline_string(f, Vector2(14.0, 32.0 + f.get_ascent(13)), _desc, HORIZONTAL_ALIGNMENT_LEFT, size.x - 28.0, 13, -1, HudStyle.MUTED)
