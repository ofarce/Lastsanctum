extends Control
## Étagère des mods de l'Exilé incarné (planches/console-mods-propositions.html, piste A « Étagère », choisie le
## 2026-11-24) : les 6 cases Module 1…6 (data/gear_items.gd MODULE_SLOTS) sur la plaque que ExileGallery dessine
## au-dessus de la barre PV. Icône Cartouche à la rareté (ItemIcon.draw_mod). Ancre de rappel en recharge : voile
## sombre qui tourne et secondes restantes ; Culasse froide active (FROST_TIME s après un changement de balle) :
## liseré cyan qui bat. Survol : infobulle d'objet de l'inventaire (ItemTooltip). Les clics traversent.

const Gear := preload("res://data/gear_items.gd")
const ItemBar := preload("res://ui/hud/item_bar.gd")
const ItemIcon := preload("res://ui/inventory/item_icon.gd")
const ItemTooltip := preload("res://ui/inventory/item_tooltip.gd")
const CYAN := Color("#5ce8ff")

var _hover := -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func available() -> bool:
	var u := HudModel.hud_exile()
	return u != null and u.alive() and not GameState.ended and not HudModel.incarnated_panel()


func _item(i: int) -> String:
	var u := HudModel.hud_exile()
	return String(u.equipment.get(Gear.MODULE_SLOTS[i], "")) if u else ""


func _pick(p: Vector2) -> int:
	if not available():
		return -1
	for i in Gear.MODULE_SLOTS.size():
		if ExileGallery.shelf_slot(get_viewport_rect().size, i).has_point(p):
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


## Le texte change d'une case à l'autre : Godot rouvre l'infobulle sur la nouvelle case.
func _get_tooltip(at: Vector2) -> String:
	var i := _pick(at)
	return "" if i < 0 or _item(i).is_empty() else "%d:%s" % [i, _item(i)]


func _make_custom_tooltip(for_text: String) -> Object:
	if for_text.is_empty():
		return null
	return ItemTooltip.make({"item": for_text.get_slice(":", 1), "quantity": 1}, true)


func _process(_delta: float) -> void:
	if not available():
		_hover = -1
	queue_redraw()


func _draw() -> void:
	if not available():
		return
	var screen := get_viewport_rect().size
	var u := HudModel.hud_exile()
	for i in Gear.MODULE_SLOTS.size():
		var r := ExileGallery.shelf_slot(screen, i)
		var item := _item(i)
		ItemBar.paint_case(self, r, not item.is_empty(), _hover == i, true)
		if item.is_empty():
			continue
		ItemIcon.draw_mod(self, item, r.get_center(), 1.0)
		match String(Gear.ITEMS.get(item, {}).get("module", "")):
			"anchor": _recharge(r, u)
			"frost":
				if GameState.sim_time - GameState.ammo_changed_at < Mods.FROST_TIME:
					_glow(r)


## Ancre en recharge : voile en part de tarte (part restante, sens horaire depuis midi) et secondes au centre.
func _recharge(r: Rect2, u: Unit) -> void:
	var left := Mods.at(u, "recall_ready") - GameState.sim_time
	if left <= 0.0:
		return
	var inner := r.grow(-2.0)
	var c := r.get_center()
	var k := clampf(left / Mods.RECALL_CD, 0.0, 1.0)
	var pie := PackedVector2Array([c])
	var steps := maxi(2, ceili(k * 32.0))
	for s in steps + 1:
		var a := -PI / 2.0 + TAU * k * float(s) / steps
		pie.append(c + Vector2(cos(a), sin(a)) * r.size.x)
	var box := PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)])
	for poly in Geometry2D.intersect_polygons(pie, box):
		draw_colored_polygon(poly, Color(0.016, 0.02, 0.03, 0.72))
	var f := HudStyle.font()
	var txt := "%d s" % ceili(left)
	var size := 11
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(roundf(c.x - w / 2.0), roundf(c.y + 4.0))
	draw_string_outline(f, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color.BLACK)
	draw_string(f, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)


## Culasse froide active : liseré cyan qui bat et voile cyan léger.
func _glow(r: Rect2) -> void:
	var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
	draw_rect(r.grow(-2.0), Color(CYAN, 0.12 * k))
	draw_rect(r.grow(-1.0), Color(CYAN, 0.45 + 0.5 * k), false, 2.0)
