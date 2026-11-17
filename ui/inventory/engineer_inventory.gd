extends Control
## Inventaire de l’Ingénieur : proposition C, sans objets de démonstration.

const Storage := preload("res://sim/item_storage.gd")
const ItemIcon := preload("res://ui/inventory/item_icon.gd")
const Blocks := preload("res://data/mineable_blocks.gd")
const Gear := preload("res://data/gear_items.gd")
const CYAN := Color("#5ce8ff")
const MUTED := Color("#5aa6b4")
const SLOTS := ["Tête", "Torse", "Gants", "Main droite", "Bottes", "Capteur oculaire", "Dos", "Anneau", "Main gauche", "Minage"]
const SIL := [".........aaaaaa.........","........abbbbbba........",".......abccccccba.......",".......abcffffcba.......",".......abccccccba.......","........abbbbbba........",".........aabbaa.........",
"....aaaaabbbbbbaaaaa....","...abbbbaccccccabbbba...","..abccbbacffffcabbccba..","..abcba.acccccca.abcba..","..abcba.abcffcba.abcba..","..abcba.abccccba.abcba..","..abcba.aabbbbaa.abcba..","..abcba.abbbbbba.abcba..",
".abccba..abbbba..abccba.",".abffba..aaaaaa..abffba.",".abccba.aabbbbaa.abccba.","..aaaa..abbbbbba..aaaa..","........abbaabba........",".......abba..abba.......",".......abca..acba.......",".......abca..acba.......",".......abfa..afba.......",
".......abca..acba.......",".......abba..abba.......",".......abca..acba.......",".......abca..acba.......","......abbba..abbba......",".....abbbba..abbbba.....",".....aaaaaa..aaaaaa....."]
var _chest: Building
var _kind: String
var _owner: Unit
var opened := false
var _drag_slot := {}
var _font: Font = SystemFont.new()
var _scale := 1.0
var _origin := Vector2.ZERO


static func engineer() -> Unit:
	for u: Unit in GameState.units:
		if u.role == "engineer" and u.alive() and not u.hidden:
			return u
	return null


static func available() -> bool:
	var u := engineer()
	return Storage.character_available(u) and not GameState.ended


static func mining_item() -> String:
	return "Sceau de minage" if GameState.research_done.has("mining_artifact") else ""


func _ready() -> void:
	(_font as SystemFont).font_names = PackedStringArray(["DejaVu Sans Mono", "monospace"])
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Events.production_chest_requested.connect(func(b: Building, kind: String, u: Unit) -> void:
		if Storage.character_available(u):
			_chest = b
			_kind = kind
			_owner = u
			_drag_slot = {}
			opened = true
			show())
	Events.game_reset.connect(close)
	Events.inventory_requested.connect(func() -> void:
		if not opened and available():
			opened = true
			show())
	Events.game_over.connect(func(_won: bool) -> void: close())


func close() -> void:
	_chest = null
	_owner = null
	opened = false
	_drag_slot = {}
	visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: Key = event.key_label if event.key_label != KEY_NONE else event.keycode
		if key == KEY_C and not event.ctrl_pressed and not event.meta_pressed and not event.alt_pressed:
			if event.pressed and not event.echo:
				if opened:
					close()
				elif available():
					opened = true
					show()
			get_viewport().set_input_as_handled()
			return
		if opened and key == KEY_ESCAPE:
			if event.pressed:
				close()
			get_viewport().set_input_as_handled()
			return
	if opened:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			var p: Vector2 = (event.position - _origin) / _scale
			if event.pressed:
				if Rect2(1010, 12, 150, 40).has_point(p):
					close()
				else:
					_drag_slot = slot_at(p)
					if _slot_content(_drag_slot).is_empty():
						_drag_slot = {}
			else:
				var target := slot_at(p)
				if not _drag_slot.is_empty() and not target.is_empty():
					_drop(_drag_slot, target)
				_drag_slot = {}
		get_viewport().set_input_as_handled()


## Glisser-déposer entre stock, paquetage et emplacements d'équipement (objets de data/gear_items.gd).
func _drop(from: Dictionary, to: Dictionary) -> void:
	if from.has("box"):
		if to == from:
			_withdraw(from["box"])
		elif to.has("items") and is_same(to["items"], _owner.inventory):
			Storage.move_stack(_box(), from["box"], _owner.inventory, to["index"], _owner.inventory_capacity)
		return
	if to.has("box"):
		return
	var u := _owner if _owner else engineer()
	if to.has("equip") and not from.has("equip"):
		Gear.equip(u, from["items"], from["index"], to["equip"])
	elif from.has("equip") and not to.has("equip"):
		Gear.unequip(u, from["equip"], to["items"], to["index"], to["capacity"])
	elif not from.has("equip") and not to.has("equip"):
		Storage.move_stack(from["items"], from["index"], to["items"], to["index"], to["capacity"])


static func equip_rect(i: int) -> Rect2:
	return Rect2(1060.0 if i >= 5 else 664.0, 156.0 + (i % 5) * 87, 68, 64)


func _process(_delta: float) -> void:
	if opened:
		if not available() or (_chest and (not GameState.buildings.has(_chest) or not Storage.character_available(_owner))):
			close()
		else:
			queue_redraw()


func _text(p: Vector2, text: String, color: Color = CYAN, font_size: int = 14) -> void:
	draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _panel(rect: Rect2, color: Color = Color("#1f9fb8")) -> void:
	var p := rect.position
	var s := rect.size
	var points := PackedVector2Array([p, p + Vector2(s.x - 16, 0), p + Vector2(s.x, 16), p + s, p + Vector2(16, s.y), p + Vector2(0, s.y - 16), p])
	draw_colored_polygon(points, Color("#081920f5"))
	draw_polyline(points, color, 1.0, true)
	for y in range(int(p.y + 3), int(p.y + s.y - 3), 3):
		draw_line(Vector2(p.x + 3, y), Vector2(p.x + s.x - 3, y), Color("#5ce8ff06"))


func _slot(rect: Rect2, filled: bool = false, disabled: bool = false) -> void:
	draw_rect(rect, Color("#182124") if disabled else Color("#0a2a33"))
	draw_rect(rect, Color("#3a4447") if disabled else (CYAN if filled else Color("#1f9fb855")), false)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#02080de8"))
	_scale = minf(0.8, minf(size.x / 1500.0, size.y / 1050.0))
	_origin = (size - Vector2(1180, 820) * _scale) * 0.5
	draw_set_transform(_origin, 0, Vector2.ONE * _scale)
	_text(Vector2(20, 35), "// INVENTAIRE · INGÉNIEUR EXILÉ", CYAN, 20)
	_text(Vector2(1015, 35), "C / ÉCHAP · FERMER", MUTED, 12)
	if _chest:
		_draw_chest()
	else:
		_draw_base()
	_panel(Rect2(640, 64, 520, 604))
	_text(Vector2(658, 92), "// DIAGNOSTIC EXO")
	_text(Vector2(788, 119), "INGÉNIEUR · ARMURE BRISÉE", MUTED, 12)
	# Silhouette filaire pixel de la planche C.
	for y in range(SIL.size()):
		for x in range(SIL[y].length()):
			if SIL[y][x] == ".":
				continue
			var edge: bool = x == 0 or x == SIL[y].length() - 1 or y == 0 or y == SIL.size() - 1
			if not edge:
				edge = SIL[y][x-1] == "." or SIL[y][x+1] == "." or SIL[y-1][x] == "." or SIL[y+1][x] == "."
			draw_rect(Rect2(792 + x * 9, 172 + y * 12, 9, 12), CYAN if edge else (Color("#12596b") if (x + y) % 2 else Color("#0a2a33")))
	var u_eq := _owner if _owner else engineer()
	for i in range(10):
		var right := i >= 5
		var row := i % 5
		var x := 1060.0 if right else 664.0
		var y := 156.0 + row * 87
		var worn: String = u_eq.equipment.get(SLOTS[i], "") if u_eq else ""
		var filled := (i == 9 and not mining_item().is_empty()) or worn != ""
		var target := Vector2(932 if right else 868, 192 + row * 75)
		draw_line(Vector2(x + (0 if right else 68), y + 34), target, CYAN if filled else Color("#1f9fb8"), 1, true)
		_slot(Rect2(x, y, 68, 64), filled)
		_text(Vector2(x - 4, y + 80), SLOTS[i], MUTED, 11)
		if filled:
			# Même prisme de forage que dans les quatre recherches.
			if i == 9:
				draw_texture_rect(HudStyle.icon("mining_seal", 64), Rect2(x + 2, y, 64, 64), false)
			else:
				ItemIcon.draw_item(self, worn, Vector2(x + 34, y + 32), 1.8)
	_text(Vector2(662, 637), "MINAGE · " + ("SCEAU DE MINAGE ÉQUIPÉ" if not mining_item().is_empty() else "AUCUN SCEAU"), CYAN if not mining_item().is_empty() else MUTED, 13)
	_panel(Rect2(250, 688, 680, 120))
	_text(Vector2(268, 708), "// PAQUETAGE · 10", MUTED, 11)
	var u := _owner if _owner else engineer()
	for i in range(10):
		var rect := Rect2(268 + i * 65, 727, 58, 58)
		var filled := u != null and i < u.inventory.size() and not u.inventory[i].is_empty()
		_slot(rect, filled)
		if filled:
			_draw_item(rect, u.inventory[i])
	_draw_drag()
	draw_set_transform(Vector2.ZERO)


## Contenu d'une case : {"item", "quantity"} ou {} si vide.
func _slot_content(slot: Dictionary) -> Dictionary:
	if slot.has("box"):
		var box := _box()
		return box[slot["box"]] if slot["box"] < box.size() else {}
	if slot.has("equip"):
		var u := _owner if _owner else engineer()
		var worn: String = u.equipment.get(slot["equip"], "") if u else ""
		return {} if worn.is_empty() else {"item": worn, "quantity": 1}
	if slot.has("items"):
		var items: Array = slot["items"]
		return items[slot["index"]] if slot["index"] < items.size() else {}
	return {}


func _slot_rect(slot: Dictionary) -> Rect2:
	if slot.has("box"):
		return _box_rect(slot["box"])
	if slot.has("equip"):
		return equip_rect(SLOTS.find(slot["equip"]))
	if slot.has("items"):
		var i: int = slot["index"]
		if slot["capacity"] == 100:
			return Rect2(40 + (i % 10) * 56, 108 + (i / 10) * 54, 51, 49)
		return Rect2(268 + i * 65, 727, 58, 58)
	return Rect2()


## Objet en cours de glisser-déposer : case d'origine estompée, cible surlignée, icône sous le curseur.
func _draw_drag() -> void:
	if _drag_slot.is_empty():
		return
	var stack := _slot_content(_drag_slot)
	if stack.is_empty():
		_drag_slot = {}
		return
	draw_rect(_slot_rect(_drag_slot), Color("#02080dc0"))
	var p := (get_local_mouse_position() - _origin) / _scale
	var target := slot_at(p)
	if not target.is_empty() and target != _drag_slot:
		draw_rect(_slot_rect(target).grow(2), Color.WHITE, false, 2)
	ItemIcon.draw_item(self, stack["item"], p, 1.8)
	if stack["quantity"] > 1:
		_text(p + Vector2(14, 26), str(stack["quantity"]), CYAN, 12)


func _draw_base() -> void:
	_panel(Rect2(20, 64, 600, 604), Color("#586063"))
	_text(Vector2(38, 92), "// STOCK BASE · 10×10", Color("#788589"))
	for row in range(10):
		for col in range(10):
			var index := row * 10 + col
			var rect := Rect2(40 + col * 56, 108 + row * 54, 51, 49)
			var filled := index < GameState.base_inventory.size() and not GameState.base_inventory[index].is_empty()
			_slot(rect, filled, not GameState.base_inventory_unlocked)
			if GameState.base_inventory_unlocked and filled:
				_draw_item(rect, GameState.base_inventory[index])
	if not GameState.base_inventory_unlocked:
		draw_rect(Rect2(30, 312, 580, 72), Color("#10181af5"))
		_text(Vector2(184, 355), "Coffre antique nécessaire", Color("#b6bfc0"), 20)


func _box() -> Array[Dictionary]:
	return _chest.input_box if _kind == "in" else _chest.output_box


func _box_rect(i: int) -> Rect2:
	return Rect2(40 + (i % 4) * 140, 135 + (i / 4) * 125, 132, 116)


func _draw_chest() -> void:
	var tint := Color("#62adff") if _kind == "in" else Color("#ff817a")
	_panel(Rect2(20, 64, 600, 604), tint)
	_text(Vector2(38, 92), "Coffre bleu" if _kind == "in" else "Coffre rouge", tint, 20)
	_text(Vector2(38, 117), "Cliquez sur une pile pour la transférer au paquetage.", MUTED)
	var box := _box()
	for i in Production.BOX_CAPACITY:
		var rect := _box_rect(i)
		var filled := i < box.size() and not box[i].is_empty()
		_slot(rect, filled)
		if filled:
			_draw_item(rect, box[i])


func _withdraw(index: int) -> void:
	var box := _box()
	if index >= box.size() or box[index].is_empty():
		return
	var bag := _owner.inventory
	for i in bag.size():
		if not bag[i].is_empty() and bag[i]["item"] == box[index]["item"]:
			Storage.move_stack(box, index, bag, i, _owner.inventory_capacity)
			if box[index].is_empty():
				return
	for i in _owner.inventory_capacity:
		if i >= bag.size() or bag[i].is_empty():
			Storage.move_stack(box, index, bag, i, _owner.inventory_capacity)
			return


func _draw_item(rect: Rect2, stack: Dictionary) -> void:
	var item: String = stack["item"]
	ItemIcon.draw_item(self, item, rect.get_center() - Vector2(0, 5), 1.8)
	_text(rect.position + Vector2(4, rect.size.y - 5), preload("res://data/recipes.gd").name_of(item), CYAN, 10)

	var quantity := str(stack["quantity"])
	var width := _font.get_string_size(quantity, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var position := rect.position + Vector2(rect.size.x - width - 3, 12)
	draw_rect(Rect2(position - Vector2(2, 10), Vector2(width + 4, 13)), Color("#06121aee"))
	_text(position, quantity, CYAN, 11)


func slot_at(p: Vector2) -> Dictionary:
	if _chest:
		for i in Production.BOX_CAPACITY:
			if _box_rect(i).has_point(p):
				return {"box": i}
	elif GameState.base_inventory_unlocked:
		for i in range(100):
			if Rect2(40 + (i % 10) * 56, 108 + (i / 10) * 54, 51, 49).has_point(p):
				return {"items": GameState.base_inventory, "index": i, "capacity": 100}
	var u := _owner if _owner else engineer()
	if u:
		for i in range(9):
			if equip_rect(i).has_point(p):
				return {"equip": SLOTS[i]}
		for i in range(10):
			if Rect2(268 + i * 65, 727, 58, 58).has_point(p):
				return {"items": u.inventory, "index": i, "capacity": u.inventory_capacity}
	return {}
