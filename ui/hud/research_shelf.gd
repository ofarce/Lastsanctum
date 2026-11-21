class_name ResearchShelf
extends Control
## Recherches achevées (2026-11-20) : une rangée de plaques en haut à gauche, sous la carte de vague, qui remplace
## les boutons « Déjà achevée » des bâtiments. Chaque plaque porte l'icône pleine de la recherche (celle du bouton
## achevé) ; le survol ouvre une bulle sous la plaque : nom et effet. En tête, la plaque au livre ouvre le grimoire
## des recherches (ResearchGrimoire, touche X), dès qu'un bâtiment à recherches est achevé.

signal open_grimoire

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


## Plaque au livre (grimoire) en tête, puis les recherches achevées, dans l'ordre du catalogue. Vrai si la liste a
## changé (la taille suit).
func update_ids() -> bool:
	var next: Array[String] = []
	for t: String in ResearchGrimoire.building_types():
		if ResearchGrimoire.host(t) != null or not GameState.research_done.is_empty():
			next.append("")
			break
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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _hover >= 0 and ids[_hover] == "":
		accept_event()
		open_grimoire.emit()
		return
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
	if ids[i] == "":
		_bubble.set_text("Grimoire des recherches", "Toutes les recherches, par bâtiment · touche %s" % ResearchGrimoire.KEY, "")
	else:
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
		if ids[i] == "":
			# Grimoire : livre au trait d'or et sa touche en pied.
			var book := HudStyle.icon("book", 22)
			draw_texture_rect(book, Rect2(r.position + Vector2(9, 4), Vector2(22, 22)), false, HudStyle.GOLD_LIGHT if i == _hover else Color("#e9ce9e"))
			var f := HudStyle.font()
			var kw := HudStyle.text_width(ResearchGrimoire.KEY, 9) + 6.0
			var kr := Rect2(r.position.x + (CELL - kw) / 2.0, r.end.y - 13.0, kw, 10.0)
			draw_rect(kr, Color("#10140d"))
			HudStyle.ring(self, kr, 1.0, Color("#8c744b"))
			draw_string(f, kr.position + Vector2(3.0, 8.5), ResearchGrimoire.KEY, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, HudStyle.MUTED)
			continue
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

	var _status := "Recherche achevée"

	func set_text(name: String, desc: String, status := "Recherche achevée") -> void:
		_name = name
		_desc = desc
		_status = status
		var f := HudStyle.font()
		var head := HudStyle.text_width(name, 15) + (HudStyle.text_width("  ·  " + status, 13) if status else 0.0)
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
		if _status:
			draw_string(f, Vector2(x, 21.0), "  ·  ", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, HudStyle.MUTED)
			x += HudStyle.text_width("  ·  ", 13)
			draw_string(f, Vector2(x, 21.0), _status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#a8d890"))
		if _desc:
			draw_multiline_string(f, Vector2(14.0, 32.0 + f.get_ascent(13)), _desc, HORIZONTAL_ALIGNMENT_LEFT, size.x - 28.0, 13, -1, HudStyle.MUTED)
