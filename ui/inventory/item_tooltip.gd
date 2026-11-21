extends Control
## Infobulle d'objet de l'inventaire (planches/mods-icones-propositions.html, « Au survol », gardée le 2026-11-21).
## Cadre Sarcelle des panneaux du HUD (SnesBanner.INFO). Titre à la couleur de la rareté (sim/loot.gd), rareté redite
## en clair dessous. Pour un mod : l'effet, les caractéristiques chiffrées (gear « stats »), ce qu'on voit sur
## l'Ingénieur (« worn »), le boss d'origine (« from ») et le geste pour l'équiper ou le retirer.

const Gear := preload("res://data/gear_items.gd")
const Recipes := preload("res://data/recipes.gd")
const ItemIcon := preload("res://ui/inventory/item_icon.gd")
const WIDTH := 364.0
const PAD := Vector2(14, 12)
const ICON := 58.0
const KEY := Color("#8ac4d0")
const VALUE := Color("#f0e6b8")
const TEXT := Color("#ffffff")
const WORN := Color("#a8d8e0")
const FROM := Color("#d0a038")
const HINT := Color("#5fa9b8")
const RULE := Color("#5fa9b8")
const SLOT := Color("#0a2a33")
const CYAN := Color("#5ce8ff")
var _item := ""
## Lignes sous le titre : [type, texte, couleur, taille] ; type « text » (repliée), « row » (clé · valeur), « rule ».
var _rows: Array = []
var _font: Font = SystemFont.new()
var _bold: Font = SystemFont.new()
var _title := ""
var _sub := ""
var _sub_rarity := ""


## `stack` : pile survolée ({item, quantity, owner?}) ; `equipped` : vrai si elle est dans une case de la fiche.
static func make(stack: Dictionary, equipped: bool) -> Control:
	var t := new()
	t._setup(stack, equipped)
	return t


func _setup(stack: Dictionary, equipped: bool) -> void:
	(_font as SystemFont).font_names = PackedStringArray(["DejaVu Sans Mono", "monospace"])
	(_bold as SystemFont).font_names = (_font as SystemFont).font_names
	(_bold as SystemFont).font_weight = 700
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item = stack["item"]
	var gear: Dictionary = Gear.ITEMS.get(_item, {})
	_title = Recipes.name_of(_item)
	_sub_rarity = Loot.rarity_name(_item)
	if gear.has("module"):
		_sub = " · Mod d’exo" + (" · " + String(gear["family"]) if gear.has("family") else "")
		_rows.append(["rule"])
		_rows.append(["text", String(gear.get("desc", "")).trim_prefix("Module d’exo. "), TEXT, 13])
		for s: Array in gear.get("stats", []):
			_rows.append(["row", s[0], s[1]])
		if gear.has("worn"):
			_rows.append(["gap"])
			_rows.append(["text", "Sur l’Ingénieur : " + String(gear["worn"]), WORN, 11])
		if gear.has("from"):
			_rows.append(["text", "Butin : " + String(gear["from"]), FROM, 11])
		_rows.append(["gap"])
		_rows.append(["text", "GLISSER VERS LE PAQUETAGE POUR RETIRER" if equipped else "CLIC DROIT : ÉQUIPER · GLISSER VERS UNE CASE MOD", HINT, 10])
	else:
		_sub = (" · " + String(gear["slot"])) if gear.has("slot") else ""
		_rows.append(["rule"])
		if String(stack.get("owner", "")) != "":
			_rows.append(["row", "Porteur", String(stack["owner"])])
		_rows.append(["row", "Quantité", str(stack.get("quantity", 1))])
		var stats := {"damage": "Dégâts", "armor": "Défense", "melee": "Portée (unités)", "reach": "Portée (unités)", "cd": "Recharge (s)"}
		for stat: String in stats:
			if gear.has(stat):
				_rows.append(["row", stats[stat], str(gear[stat])])
		if gear.get("two_hands", false):
			_rows.append(["row", "Prise", "à deux mains"])
		if gear.has("ammo"):
			_rows.append(["row", "Munition", Recipes.name_of(gear["ammo"])])
		var d := Recipes.desc_of(_item)
		if not d.is_empty():
			_rows.append(["text", d, TEXT, 12])
	custom_minimum_size = Vector2(WIDTH, _height())
	size = custom_minimum_size


func _inner() -> float:
	return WIDTH - PAD.x * 2.0


func _text_h(text: String, fs: int, w: float) -> float:
	return _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w, fs).y


func _head_h() -> float:
	var w := _inner() - ICON - 12.0
	return maxf(ICON, _text_h(_title, 16, w) + 18.0)


func _row_h(r: Array) -> float:
	match r[0]:
		"rule": return 13.0
		"gap": return 6.0
		"row": return 17.0
		_: return _text_h(r[1], r[3], _inner()) + 3.0


func _height() -> float:
	var h := PAD.y * 2.0 + _head_h()
	for r: Array in _rows:
		h += _row_h(r)
	return ceilf(h)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size - Vector2(4, 5))
	SnesBanner.paint(self, r, SnesBanner.INFO)
	var x := PAD.x
	var y := PAD.y
	var rc := Loot.rarity_color(_item)
	# Icône dans sa case, comme dans la fiche.
	var ic := Rect2(x, y, ICON, ICON)
	draw_rect(ic, SLOT)
	draw_rect(ic.grow(-0.5), CYAN, false, 1.0)
	ItemIcon.draw_item(self, _item, ic.get_center(), 1.7)
	var tx := x + ICON + 12.0
	var tw := _inner() - ICON - 12.0
	var th := _text_h(_title, 16, tw)
	var ty := y + maxf(0.0, (_head_h() - th - 18.0) * 0.5)
	draw_multiline_string(_bold, Vector2(tx + 1, ty + 15), _title, HORIZONTAL_ALIGNMENT_LEFT, tw, 16, -1, Color("#04141a"))
	draw_multiline_string(_bold, Vector2(tx, ty + 14), _title, HORIZONTAL_ALIGNMENT_LEFT, tw, 16, -1, rc)
	var sy := ty + th + 13.0
	draw_string(_bold, Vector2(tx, sy), _sub_rarity, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, rc)
	draw_string(_font, Vector2(tx + _bold.get_string_size(_sub_rarity, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, sy), _sub,
			HORIZONTAL_ALIGNMENT_LEFT, tw, 11, KEY)
	y += _head_h()
	for row: Array in _rows:
		var h := _row_h(row)
		match row[0]:
			"rule":
				draw_rect(Rect2(x, roundf(y + 6), _inner(), 1), Color(RULE, 0.5))
			"row":
				draw_string(_font, Vector2(x, y + 12), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, KEY)
				draw_string(_font, Vector2(x, y + 12), row[2], HORIZONTAL_ALIGNMENT_RIGHT, _inner(), 12, VALUE)
			"text":
				draw_multiline_string(_font, Vector2(x, y + row[3]), row[1], HORIZONTAL_ALIGNMENT_LEFT, _inner(), row[3], -1, row[2])
		y += h
