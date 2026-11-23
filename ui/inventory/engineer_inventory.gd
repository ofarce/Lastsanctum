extends Control
## Inventaire de l’Ingénieur : proposition C, sans objets de démonstration.
## À gauche, le réseau des coffres (coffre antique, coffres bleus et rouges : un seul stockage infini), par pages
## de 10 × 10 ; flèches, molette, ←/→ ou Page préc./suiv. pour changer de page, et survol d'une flèche pendant un
## glisser-déposer pour emporter la pile sur la page voisine.

const Storage := preload("res://sim/item_storage.gd")
const ItemIcon := preload("res://ui/inventory/item_icon.gd")
const ItemTooltip := preload("res://ui/inventory/item_tooltip.gd")
const Blocks := preload("res://data/mineable_blocks.gd")
const Gear := preload("res://data/gear_items.gd")
const Recipes := preload("res://data/recipes.gd")
const CYAN := Color("#5ce8ff")
const MUTED := Color("#5aa6b4")
const QTY_SIZE := 17
const QTY_COLOR := Color("#fff4c8")
## Cases de la fiche : uniquement les 6 mods (data/gear_items.gd, MODULE_SLOTS), trois de chaque côté de la silhouette.
const SLOTS := Gear.MODULE_SLOTS
const SIL := [".........aaaaaa.........","........abbbbbba........",".......abccccccba.......",".......abcffffcba.......",".......abccccccba.......","........abbbbbba........",".........aabbaa.........",
"....aaaaabbbbbbaaaaa....","...abbbbaccccccabbbba...","..abccbbacffffcabbccba..","..abcba.acccccca.abcba..","..abcba.abcffcba.abcba..","..abcba.abccccba.abcba..","..abcba.aabbbbaa.abcba..","..abcba.abbbbbba.abcba..",
".abccba..abbbba..abccba.",".abffba..aaaaaa..abffba.",".abccba.aabbbbaa.abccba.","..aaaa..abbbbbba..aaaa..","........abbaabba........",".......abba..abba.......",".......abca..acba.......",".......abca..acba.......",".......abfa..afba.......",
".......abca..acba.......",".......abba..abba.......",".......abca..acba.......",".......abca..acba.......","......abbba..abbba......",".....abbbba..abbbba.....",".....aaaaaa..aaaaaa....."]
var _owner: Unit
## Page affichée du réseau des coffres (0 = cases 1 à 100) ; survol d'une flèche pendant un glisser (début, sens).
var _page := 0
var _flip_since := 0.0
var _flip_dir := 0
const PREV_RECT := Rect2(446, 72, 30, 28)
const NEXT_RECT := Rect2(584, 72, 30, 28)
const BASE_RECT := Rect2(20, 64, 600, 604)
const FLIP_DELAY := 0.45
var opened := false
var _drag_slot := {}
var _consume_right_release := false
var _font: Font = SystemFont.new()
var _bold: Font = SystemFont.new()
var _scale := 1.0
var _origin := Vector2.ZERO
## Pile survolée pour l'infobulle dessinée (_make_custom_tooltip), et vrai si elle est dans une case de la fiche.
var _tip_stack := {}
var _tip_equipped := false


static func engineer() -> Unit:
	for u: Unit in GameState.units:
		if u.role == "engineer" and u.alive() and not u.hidden:
			return u
	return null


static func available() -> bool:
	var u := engineer()
	return Storage.character_available(u) and not GameState.ended


static func mining_item() -> String:
	return "Sceau de minage" if GameState.mining_seal else ""


func _ready() -> void:
	(_font as SystemFont).font_names = PackedStringArray(["DejaVu Sans Mono", "monospace"])
	(_bold as SystemFont).font_names = (_font as SystemFont).font_names
	(_bold as SystemFont).font_weight = 700
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Infobulle dessinée (ui/inventory/item_tooltip.gd) : pas de fond de panneau natif autour.
	var tip_theme := Theme.new()
	tip_theme.set_stylebox("panel", "TooltipPanel", StyleBoxEmpty.new())
	theme = tip_theme
	# Un coffre de bâtiment ouvre le même réseau que le coffre antique.
	Events.production_chest_requested.connect(func(_b: Building, _kind: String, u: Unit) -> void:
		if Storage.character_available(u) and not GameState.ended:
			_owner = u
			_drag_slot = {}
			if not opened:
				Sfx.play("ui_inventaire")
			opened = true
			show())
	Events.game_reset.connect(close)
	Events.inventory_requested.connect(func() -> void:
		if not opened and available():
			opened = true
			Sfx.play("ui_inventaire")
			show())
	Events.game_over.connect(func(_won: bool) -> void: close())


func close() -> void:
	GameState.hud_chest = {}
	_owner = null
	opened = false
	_drag_slot = {}
	visible = false


func _input(event: InputEvent) -> void:
	if HelpPanel.open:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed and _consume_right_release:
		_consume_right_release = false
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key: Key = event.key_label if event.key_label != KEY_NONE else event.keycode
		if key == KEY_C and not event.ctrl_pressed and not event.meta_pressed and not event.alt_pressed:
			if event.pressed and not event.echo:
				if opened:
					close()
				elif available():
					opened = true
					Sfx.play("ui_inventaire")
					show()
			get_viewport().set_input_as_handled()
			return
		if opened and key == KEY_ESCAPE:
			if event.pressed:
				close()
			get_viewport().set_input_as_handled()
			return
		if opened and event.pressed and key in [KEY_LEFT, KEY_PAGEUP, KEY_RIGHT, KEY_PAGEDOWN]:
			_turn(-1 if key in [KEY_LEFT, KEY_PAGEUP] else 1)
			get_viewport().set_input_as_handled()
			return
	if opened:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_consume_right_release = true
			_drag_slot = {}
			var p: Vector2 = (event.position - _origin) / _scale
			if not Rect2(20, 12, 1140, 796).has_point(p):
				close()
			else:
				_equip_slot(slot_at(p))
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if BASE_RECT.has_point((event.position - _origin) / _scale):
				_turn(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			var p: Vector2 = (event.position - _origin) / _scale
			if event.pressed:
				if not Rect2(20, 12, 1140, 796).has_point(p) or Rect2(1010, 12, 150, 40).has_point(p):
					close()
				elif Storage.network_open() and PREV_RECT.grow(4).has_point(p):
					_turn(-1)
				elif Storage.network_open() and NEXT_RECT.grow(4).has_point(p):
					_turn(1)
				else:
					_drag_slot = slot_at(p)
					if _slot_content(_drag_slot).is_empty():
						_drag_slot = {}
			else:
				var target := slot_at(p)
				if not _drag_slot.is_empty() and not target.is_empty():
					_drop(_drag_slot, target)
				_drag_slot = {}
		# Laisser le GUI suivre le survol pour afficher les infobulles natives.
		if not event is InputEventMouseMotion:
			get_viewport().set_input_as_handled()


func _equip_slot(slot: Dictionary) -> void:
	var stack := _slot_content(slot)
	if stack.is_empty() or slot.has("equip"):
		return
	if stack["item"] == "ration":
		Loot.use_ration(_owner if _owner else engineer(), slot["items"], slot["index"])
		return
	var destination := Gear.slot_of(stack["item"])
	if destination.is_empty():
		return
	# Mod : la première case libre (sinon la première).
	if destination == Gear.MODULE:
		var wearer := _owner if _owner else engineer()
		destination = Gear.MODULE_SLOTS[0]
		for ms: String in Gear.MODULE_SLOTS:
			if wearer and not wearer.equipment.has(ms):
				destination = ms
				break
	Gear.equip(_owner if _owner else engineer(), slot["items"], slot["index"], destination)


func _get_tooltip(at_position: Vector2) -> String:
	if not opened or not _drag_slot.is_empty():
		return ""
	var hovered := slot_at((at_position - _origin) / _scale)
	var stack := _slot_content(hovered)
	_tip_stack = stack
	_tip_equipped = hovered.has("equip")
	if stack.is_empty():
		return ""
	var item: String = stack["item"]
	var gear: Dictionary = Gear.ITEMS.get(item, {})
	var lines: PackedStringArray = [Recipes.name_of(item)]
	# Nom de l'ancien porteur, sous le titre (armes et armures prises à un ennemi).
	if String(stack.get("owner", "")) != "":
		lines.append("Porteur : " + String(stack["owner"]))
	lines.append("Rareté : " + Loot.rarity_name(item))
	lines.append("Quantité : %d" % stack["quantity"])
	if gear.has("slot"):
		lines.append("Emplacement : " + gear["slot"])
	var stats := {"damage": "Dégâts", "armor": "Défense", "melee": "Portée (unités)", "reach": "Portée (unités)", "cd": "Recharge (s)"}
	for stat: String in stats:
		if gear.has(stat):
			lines.append("%s : %s" % [stats[stat], str(gear[stat])])
	if gear.get("two_hands", false):
		lines.append("Arme à deux mains")
	if gear.has("ammo"):
		lines.append("Munition : " + Recipes.name_of(gear["ammo"]))
	var description := Recipes.desc_of(item)
	if not description.is_empty():
		lines.append(description)
	return "\n".join(lines)


func _make_custom_tooltip(_for_text: String) -> Object:
	return null if _tip_stack.is_empty() else ItemTooltip.make(_tip_stack, _tip_equipped)


## Glisser-déposer entre réseau des coffres, paquetage et emplacements d'équipement (data/gear_items.gd).
func _drop(from: Dictionary, to: Dictionary) -> void:
	Sfx.play("coffre")
	var u := _owner if _owner else engineer()
	if to.has("equip") and not from.has("equip"):
		Gear.equip(u, from["items"], from["index"], to["equip"])
	elif from.has("equip") and not to.has("equip"):
		Gear.unequip(u, from["equip"], to["items"], to["index"], to["capacity"])
	elif not from.has("equip") and not to.has("equip"):
		Storage.move_stack(from["items"], from["index"], to["items"], to["index"], to["capacity"])


func _pack_count(u: Unit) -> int:
	return clampi(u.inventory_capacity, Gear.PACK, Gear.PACK * 2) if u else Gear.PACK


## Case i du paquetage : une rangée de 10 grandes cases, ou deux rangées resserrées avec le Sac sans fond.
static func pack_rect(i: int, count: int) -> Rect2:
	if count <= Gear.PACK:
		return Rect2(268 + i * 65, 727, 58, 58)
	return Rect2(274 + (i % Gear.PACK) * 65, 714 + (i / Gear.PACK) * 48, 46, 44)


static func equip_rect(i: int) -> Rect2:
	return Rect2(1060.0 if i >= 3 else 664.0, 176.0 + (i % 3) * 130, 68, 64)


func _process(_delta: float) -> void:
	if opened:
		if not available() or (_owner and not Storage.character_available(_owner)):
			close()
			return
		_page = clampi(_page, 0, page_count() - 1)
		_hover_flip()
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
	for i in range(SLOTS.size()):
		var right := i >= 3
		var row := i % 3
		var r := equip_rect(i)
		var worn: String = u_eq.equipment.get(SLOTS[i], "") if u_eq else ""
		var filled := worn != ""
		var target := Vector2(932 if right else 868, 214 + row * 120)
		draw_line(Vector2(r.position.x + (0.0 if right else r.size.x), r.position.y + 32), target, CYAN if filled else Color("#1f9fb8"), 1, true)
		_slot(r, filled)
		# Numéro et nom du mod sous la case, alignés sur le bord extérieur de la fiche.
		var lines := ["MOD %d" % (i + 1), Gear.name_of(worn) if filled else "Libre"]
		for k in range(2):
			var fs := 11 if k == 0 else 10
			var lx := r.position.x - 4.0
			if right:
				lx = r.end.x + 4.0 - _font.get_string_size(lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			_text(Vector2(lx, r.position.y + 80 + k * 14), lines[k], CYAN if filled and k == 1 else MUTED, fs)
		if filled:
			ItemIcon.draw_item(self, worn, r.get_center(), 1.8)
	_text(Vector2(812, 584), "6 CASES · MODS SEULEMENT", MUTED, 11)
	_text(Vector2(662, 637), "MINAGE · " + ("SCEAU DE MINAGE ÉQUIPÉ" if not mining_item().is_empty() else "AUCUN SCEAU"), CYAN if not mining_item().is_empty() else MUTED, 13)
	_panel(Rect2(250, 688, 680, 120))
	var u := _owner if _owner else engineer()
	_text(Vector2(268, 708), "// PAQUETAGE · %d" % _pack_count(u), MUTED, 11)
	for i in range(_pack_count(u)):
		var rect := pack_rect(i, _pack_count(u))
		var filled := u != null and i < u.inventory.size() and not u.inventory[i].is_empty()
		_slot(rect, filled)
		if filled:
			_draw_item(rect, u.inventory[i])
	_draw_drag()
	draw_set_transform(Vector2.ZERO)


## Contenu d'une case : {"item", "quantity"} ou {} si vide.
func _slot_content(slot: Dictionary) -> Dictionary:
	if slot.has("equip"):
		var u := _owner if _owner else engineer()
		var worn: String = u.equipment.get(slot["equip"], "") if u else ""
		return {} if worn.is_empty() else Storage.stack_of(worn, String(u.equipment_owner.get(slot["equip"], "")))
	if slot.has("items"):
		var items: Array = slot["items"]
		return items[slot["index"]] if slot["index"] < items.size() else {}
	return {}


func _slot_rect(slot: Dictionary) -> Rect2:
	if slot.has("equip"):
		return equip_rect(SLOTS.find(slot["equip"]))
	if slot.has("items"):
		var i: int = slot["index"]
		if is_same(slot["items"], GameState.base_inventory):
			# Case d'une autre page : rien à dessiner.
			return base_rect(i - _page * Storage.PAGE) if i / Storage.PAGE == _page else Rect2()
		return pack_rect(i, _pack_count(_owner if _owner else engineer()))
	return Rect2()


## Objet en cours de glisser-déposer : case d'origine estompée, cible surlignée, icône sous le curseur.
func _draw_drag() -> void:
	if _drag_slot.is_empty():
		return
	var stack := _slot_content(_drag_slot)
	if stack.is_empty():
		_drag_slot = {}
		return
	var origin := _slot_rect(_drag_slot)
	if origin.has_area():
		draw_rect(origin, Color("#02080dc0"))
	var p := (get_local_mouse_position() - _origin) / _scale
	var target := slot_at(p)
	if not target.is_empty() and target != _drag_slot:
		draw_rect(_slot_rect(target).grow(2), Color.WHITE, false, 2)
	ItemIcon.draw_item(self, stack["item"], p, 1.8)
	if stack["quantity"] > 1:
		_quantity(p + Vector2(34, 28), stack["quantity"])


static func base_rect(i: int) -> Rect2:
	return Rect2(40 + (i % 10) * 56, 108 + (i / 10) * 54, 51, 49)


## Pages du réseau : jusqu'à la dernière case occupée, plus une page vide quand la dernière est pleine.
static func page_count() -> int:
	var last := -1
	var inv := GameState.base_inventory
	for i in range(inv.size() - 1, -1, -1):
		if not inv[i].is_empty():
			last = i
			break
	return (last + 1) / Storage.PAGE + 1


func _turn(dir: int) -> void:
	var to := clampi(_page + dir, 0, page_count() - 1)
	if to != _page:
		_page = to
		Sfx.play("ui_inventaire")


## Pendant un glisser-déposer, rester sur une flèche tourne la page (la pile suit le curseur).
func _hover_flip() -> void:
	var dir := 0
	if not _drag_slot.is_empty() and Storage.network_open():
		var p := (get_local_mouse_position() - _origin) / _scale
		dir = -1 if PREV_RECT.grow(4).has_point(p) else (1 if NEXT_RECT.grow(4).has_point(p) else 0)
	var now := Time.get_ticks_msec() / 1000.0
	if dir != _flip_dir:
		_flip_dir = dir
		_flip_since = now
	elif dir != 0 and now - _flip_since >= FLIP_DELAY:
		_turn(dir)
		_flip_since = now


func _draw_base() -> void:
	var open := Storage.network_open()
	_panel(BASE_RECT, Color("#1f9fb8") if open else Color("#586063"))
	_text(Vector2(38, 92), "// RÉSEAU DES COFFRES · 10×10", CYAN if open else Color("#788589"))
	if open:
		var pages := page_count()
		var p := (get_local_mouse_position() - _origin) / _scale
		_arrow(PREV_RECT, -1, _page > 0, PREV_RECT.grow(4).has_point(p))
		_arrow(NEXT_RECT, 1, _page < pages - 1, NEXT_RECT.grow(4).has_point(p))
		var label := "%d / %d" % [_page + 1, pages]
		var w := _bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(_bold, Vector2((PREV_RECT.end.x + NEXT_RECT.position.x - w) / 2.0, 92), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, CYAN)
	var inv := GameState.base_inventory
	for i in range(Storage.PAGE):
		var index := _page * Storage.PAGE + i
		var rect := base_rect(i)
		var filled := index < inv.size() and not inv[index].is_empty()
		_slot(rect, filled, not open)
		if open and filled:
			_draw_item(rect, inv[index])
	if not open:
		draw_rect(Rect2(30, 312, 580, 72), Color("#10181af5"))
		_text(Vector2(84, 345), "Coffre antique ou bâtiment à coffres nécessaire", Color("#b6bfc0"), 17)
		_text(Vector2(140, 370), "Tous les coffres forment un seul réseau infini.", MUTED, 13)


## Flèche de page : triangle plein, éteinte en bout de réseau, surlignée au survol.
func _arrow(r: Rect2, dir: int, enabled: bool, hover: bool) -> void:
	_slot(r, enabled and hover, not enabled)
	var c := r.get_center()
	var tip := Vector2(7.0 * dir, 0)
	var col := (Color.WHITE if hover else CYAN) if enabled else Color("#3a4447")
	draw_colored_polygon(PackedVector2Array([c + tip, c - tip + Vector2(0, -8), c - tip + Vector2(0, 8)]), col)


## Liseré de rareté (sim/loot.gd) : rien pour un objet normal, la couleur de la rareté au-delà. Pas pour un mod :
## sa rareté est la couleur du cadre de son icône (ui/inventory/item_icon.gd, draw_mod).
func _rarity_edge(rect: Rect2, item: String) -> void:
	if Loot.rarity_of(item) != "normal" and not Gear.ITEMS.get(item, {}).has("module"):
		draw_rect(rect.grow(-1.5), Loot.rarity_color(item), false, 2.0)


func _draw_item(rect: Rect2, stack: Dictionary) -> void:
	_rarity_edge(rect, stack["item"])
	var item: String = stack["item"]
	# Un mod remplit sa case (cartouche 32 × 32) : un peu plus petit, pour laisser son nom lisible dessous.
	var k := rect.size.x / 58.0
	ItemIcon.draw_item(self, item, rect.get_center() - Vector2(0, 5) * k, (1.35 if Gear.ITEMS.get(item, {}).has("module") else 1.8) * k)
	_text(rect.position + Vector2(4, rect.size.y - 5), preload("res://data/recipes.gd").name_of(item), CYAN, 10)

	_quantity(rect.position + Vector2(rect.size.x - 3, 15), stack["quantity"])


## Quantité d'une pile : gros chiffres clairs, cernés de noir, sur cartouche sombre.
## `right` est le bord droit de la ligne de base.
func _quantity(right: Vector2, amount: int) -> void:
	var text := str(amount)
	var width := _bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, QTY_SIZE).x
	var p := right - Vector2(width, 0)
	draw_rect(Rect2(p - Vector2(3, QTY_SIZE - 2), Vector2(width + 6, QTY_SIZE + 2)), Color("#02080de0"))
	draw_string_outline(_bold, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, QTY_SIZE, 4, Color.BLACK)
	draw_string(_bold, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, QTY_SIZE, QTY_COLOR)


func slot_at(p: Vector2) -> Dictionary:
	if Storage.network_open():
		for i in range(Storage.PAGE):
			if base_rect(i).has_point(p):
				return {"items": GameState.base_inventory, "index": _page * Storage.PAGE + i, "capacity": Storage.BASE_CAPACITY}
	var u := _owner if _owner else engineer()
	if u:
		for i in range(SLOTS.size()):
			if equip_rect(i).has_point(p):
				return {"equip": SLOTS[i]}
		for i in range(_pack_count(u)):
			if pack_rect(i, _pack_count(u)).has_point(p):
				return {"items": u.inventory, "index": i, "capacity": u.inventory_capacity}
	return {}
