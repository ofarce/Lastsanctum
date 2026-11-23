extends Control
## Barre d'objets de l'Ingénieur incarné : trois cases sous sa barre de PV (ExileGallery), en bas de l'écran.
## Sceau de minage (remis par la capsule), Arbalestrie (en main droite), balles en service (data/ammo.gd).
## Une case vide reste dessinée, assombrie. Survol : bulle 16 bits avec le nom de l'objet. Les clics traversent.

const Ammo := preload("res://data/ammo.gd")
const GearItems := preload("res://data/gear_items.gd")
const ItemIcon := preload("res://ui/inventory/item_icon.gd")
const SLOT := 40.0
const GAP := 6.0
## Marge sous la barre (bord bas de l'écran) et écart avec la barre de PV au-dessus.
const MARGIN := 18.0
const HP_GAP := 6.0
const COUNT := 3
## Pixel des balles dessinées dans la case (comme le barillet).
const ICON_PX := 3.0

var _hover := -1
var _drawer := EffectsDrawer.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_drawer.ci = self
	_drawer.px = ICON_PX


static func available() -> bool:
	var u := GameState.incarnated
	return u != null and u.alive() and not u.hidden and u.role == "engineer" and not GameState.ended \
		and not HudModel.incarnated_panel()


static func has_crossbow() -> bool:
	return GearItems.weapon(GameState.incarnated).get("piece", "") == "cannon"


func _slot(i: int) -> Rect2:
	var screen := get_viewport_rect().size
	var w := COUNT * SLOT + (COUNT - 1) * GAP
	# Le paquetage (ui/hud/pack_bar.gd) prolonge la rangée à droite : l'ensemble reste centré.
	var extra := PackBar.row_extra()
	return Rect2(roundf((screen.x - w - extra) / 2.0) + i * (SLOT + GAP), screen.y - MARGIN - SLOT, SLOT, SLOT)


## Nom affiché au survol de la case `i` ("" : case vide).
func _name_of(i: int) -> String:
	match i:
		0: return "Sceau de minage" if GameState.mining_seal else ""
		1: return "Arbalestrie" if has_crossbow() else ""
		2: return String(Ammo.AMMO[Ammo.current()]["name"]) if has_crossbow() else ""
	return ""


func _pick(p: Vector2) -> int:
	if not available():
		return -1
	for i in COUNT:
		if _slot(i).has_point(p):
			return i
	return -1


func _has_point(p: Vector2) -> bool:
	return _pick(p) != -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = _pick(event.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = -1


func _process(_delta: float) -> void:
	if not available():
		_hover = -1
	queue_redraw()


func _draw() -> void:
	if not available():
		return
	for i in COUNT:
		var r := _slot(i)
		var filled := not _name_of(i).is_empty()
		paint_case(self, r, filled, _hover == i)
		if not filled:
			continue
		var c := r.get_center()
		match i:
			0: draw_texture_rect(HudStyle.icon("mining_seal", 32), Rect2(c - Vector2(16, 16), Vector2(32, 32)), false)
			1: ItemIcon.draw_item(self, "cannon", c, 1.0)
			2:
				_ball(c, Ammo.current())
	if _hover >= 0 and not _name_of(_hover).is_empty():
		_tip(_slot(_hover), _name_of(_hover))


## Case carrée 16 bits (mêmes teintes que le barillet) : contour sombre, liseré blanc, fond bleu en bandes.
## Partagée avec le paquetage (ui/hud/pack_bar.gd).
static func paint_case(ci: CanvasItem, r: Rect2, filled: bool, hover: bool) -> void:
	ci.draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.35))
	ci.draw_rect(r, SnesBanner.EDGE)
	ci.draw_rect(r.grow(-1.0), SnesBanner.RIM if filled else SnesBanner.RIM_LO)
	ci.draw_rect(r.grow(-3.0), SnesBanner.RIM_LO)
	var inner := r.grow(-4.0)
	var bands := 8
	for k in bands:
		var t := float(k) / (bands - 1)
		var col := SnesBanner.SKY.lerp(SnesBanner.DEEP, t)
		ci.draw_rect(Rect2(inner.position.x, inner.position.y + k * inner.size.y / bands, inner.size.x, inner.size.y / bands),
			col if filled else col.darkened(0.55))
	if hover and filled:
		ci.draw_rect(r.grow(-1.0), Color.WHITE, false, 2.0)


## La balle en service, dessinée comme en vol (EffectsDrawer), en pixels de ICON_PX.
func _ball(c: Vector2, id: String) -> void:
	var n := (c / ICON_PX).floor()
	match id:
		"spirit": _drawer._ball_spirit(n.x, n.y, 0.04, 11)
		"indra": _drawer._ball_indra(n.x + 1, n.y, Vector2.RIGHT, 0.04, 11)
		"medeina": _drawer._ball_medeina(n.x, n.y, Vector2.RIGHT, 0.04)
		"sigil":
			_drawer._ball_sigil(n.x, n.y - 2, Vector2.RIGHT, 0.0)
			_drawer._ball_sigil(n.x, n.y + 2, Vector2.RIGHT, 0.0)
		"aether": _drawer._ball_aether(n.x, n.y, Vector2.RIGHT, 0.04)


func _tip(slot: Rect2, text: String) -> void:
	var f := HudStyle.font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 24.0
	# Au-dessus de la barre de PV, pour ne pas la masquer.
	var top := slot.position.y - HP_GAP - ExileGallery.HP_H - 8.0 - 28.0
	var r := Rect2(roundf(slot.get_center().x - w / 2.0), top, w, 28.0)
	r.position.x = clampf(r.position.x, 8.0, get_viewport_rect().size.x - 8.0 - w)
	SnesBanner.paint(self, r)
	draw_string(f, r.position + Vector2(13.0, 20.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, SnesBanner.SHADOW)
	draw_string(f, r.position + Vector2(12.0, 19.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, SnesBanner.INK)
