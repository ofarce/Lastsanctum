class_name PackBar
extends Control
## Paquetage de l'Ingénieur (ses 10 cases, Unit.inventory), toujours affiché en bas de l'écran.
## Désincarné : rangée centrée juste au-dessus du bandeau de commandement. Incarné : seule rangée de la console, centrée
## sous la barre de PV (ExileGallery). Cases dessinées par ItemBar.paint_case.
## Survol : bulle avec le nom et la quantité. Clic gauche : ouvre l'inventaire (touche C). Masqué pendant la
## cinématique d'ouverture, les menus de construction et tant que l'Ingénieur n'a pas de paquetage.

const Storage := preload("res://sim/item_storage.gd")
const ItemBar := preload("res://ui/hud/item_bar.gd")
const ItemIcon := preload("res://ui/inventory/item_icon.gd")
const Recipes := preload("res://data/recipes.gd")
const SLOT := ItemBar.SLOT
const GAP := ItemBar.GAP
const COUNT := 10
## Écart avec la barre d'objets (incarné) et avec le haut du bandeau (désincarné).
const SEP := 18.0
const ABOVE := 8.0
const QTY_SIZE := 12

var _hover := -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func engineer() -> Unit:
	for u: Unit in GameState.units:
		if u.role == "engineer" and u.alive() and not u.hidden:
			return u
	return null


static func available() -> bool:
	return Storage.character_available(engineer()) and not GameState.ended and not Opening.cinematic() \
		and GameState.hud_menu == "" and GameState.hud_mode not in ["build", "place"]


## Incarné sans panneau de bâtiment ouvert : le bandeau est masqué, la rangée se loge au bas de l'écran.
static func in_row() -> bool:
	return HudModel.hud_exile() != null and not HudModel.incarnated_panel()


static func width() -> float:
	return COUNT * SLOT + (COUNT - 1) * GAP


## Lignes de la rangée incarnée (2 avec le Sac sans fond), 0 si le paquetage n'est pas dans la rangée.
static func rows() -> int:
	if not (available() and in_row()):
		return 0
	var u := engineer()
	return 2 if u and u.inventory_capacity > COUNT else 1


## Largeur que la barre d'objets doit céder à droite quand les deux partagent la rangée du bas (0 sinon).
static func row_extra() -> float:
	return width() + SEP if available() and in_row() else 0.0


func _slot(i: int) -> Rect2:
	var screen := get_viewport_rect().size
	var x0 := roundf((screen.x - width()) / 2.0)
	var y := screen.y - ItemBar.MARGIN - SLOT
	if not in_row():
		y = float(get_parent().get("hud_bottom")) - ABOVE - SLOT
	# Sac sans fond : la seconde rangée (cases 11 à 20) au-dessus de la première.
	return Rect2(x0 + (i % COUNT) * (SLOT + GAP), y - (i / COUNT) * (SLOT + GAP), SLOT, SLOT)


## Cases montrées : 10, ou 20 avec le Sac sans fond (Unit.inventory_capacity, data/gear_items.gd).
func _count() -> int:
	var u := engineer()
	return clampi(u.inventory_capacity, COUNT, COUNT * 2) if u else COUNT


func _stack(i: int) -> Dictionary:
	var u := engineer()
	return u.inventory[i] if u and i < u.inventory.size() else {}


func _pick(p: Vector2) -> int:
	if not available():
		return -1
	for i in _count():
		if _slot(i).has_point(p):
			return i
	return -1


func _has_point(p: Vector2) -> bool:
	return _pick(p) != -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = _pick(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _pick(event.position) != -1:
		Events.inventory_requested.emit()
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and _pick(event.position) != -1:
		# Clic droit sur une ration : l'Exilé la mange (sim/loot.gd).
		var i := _pick(event.position)
		var u := engineer()
		if u and _stack(i).get("item", "") == "ration":
			Loot.use_ration(u, u.inventory, i)
		accept_event()


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
	for i in _count():
		var r := _slot(i)
		var stack := _stack(i)
		ItemBar.paint_case(self, r, not stack.is_empty(), _hover == i, in_row())
		if stack.is_empty():
			continue
		var item: String = stack["item"]
		if Loot.rarity_of(item) != "normal" and not ItemIcon.Gear.ITEMS.get(item, {}).has("module"):
			draw_rect(r.grow(-2.5), Loot.rarity_color(item), false, 1.5)
		ItemIcon.draw_item(self, item, r.get_center() - Vector2(0, 2), 1.0)
		if int(stack["quantity"]) > 1:
			_quantity(r.end - Vector2(4, 4), int(stack["quantity"]))
	if _hover >= 0 and not _stack(_hover).is_empty():
		var stack := _stack(_hover)
		var text := Recipes.name_of(stack["item"])
		if int(stack["quantity"]) > 1:
			text += " × %d" % int(stack["quantity"])
		_tip(_slot(_hover), text)


## Quantité au coin bas droit, cernée de noir (lisible sur toutes les icônes).
func _quantity(right: Vector2, amount: int) -> void:
	var f := HudStyle.font()
	var text := str(amount)
	var p := right - Vector2(f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, QTY_SIZE).x, 0)
	draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, QTY_SIZE, 4, Color.BLACK)
	draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, QTY_SIZE, SnesBanner.INK)


func _tip(slot: Rect2, text: String) -> void:
	var f := HudStyle.font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 24.0
	# Incarné : au-dessus de la barre de PV, pour ne pas la masquer.
	var top := slot.position.y - 8.0 - 28.0
	if in_row():
		top = ExileGallery.console_top(get_viewport_rect().size) - 8.0 - 28.0
	var r := Rect2(roundf(slot.get_center().x - w / 2.0), top, w, 28.0)
	r.position.x = clampf(r.position.x, 8.0, get_viewport_rect().size.x - 8.0 - w)
	SnesBanner.paint(self, r)
	draw_string(f, r.position + Vector2(13.0, 20.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, SnesBanner.SHADOW)
	draw_string(f, r.position + Vector2(12.0, 19.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, SnesBanner.INK)
