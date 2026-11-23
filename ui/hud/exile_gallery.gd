class_name ExileGallery
extends Control
## Galerie des Exilés débloqués (en bas à gauche, au-dessus de la minicarte). Seul l'Ingénieur est un
## Exilé au départ ; ni les adeptes ni les soldats n'en sont. Au survol d'un portrait, il s'éclaire et un
## bouton « Incarner » apparaît au-dessus. Pendant l'incarnation (GameState.incarnated), la galerie est
## masquée (plus de bouton « Désincarner » depuis le 2026-11-19 : seule la capsule désincarne, Échap ne le fait plus).

const PORTRAITS := "res://assets/baked/hud/portraits/%s.png"
const EXILE_ROLES := ["engineer"]
const SIZE := 58.0
const GAP := 6.0
const BTN_H := 26.0

var hud_bottom := 0.0
var world: World

var _slots: Array[_Slot] = []
var _incarnate := _TextButton.new("Incarner")
var _hover: _Slot = null
var _hide_at := INF


## Exilés débloqués : unités de rôle Exilé, vivantes et sorties du portail.
static func unlocked() -> Array[Unit]:
	var out: Array[Unit] = []
	for u: Unit in GameState.units:
		if EXILE_ROLES.has(u.role) and u.alive() and not u.hidden:
			out.append(u)
	return out


static func incarnate(u: Unit) -> void:
	GameState.incarnated = u
	GameState.selected = [u]
	GameState.anchor_selected = false
	GameState.hud_mode = ""
	GameState.hud_menu = ""
	GameState.hud_building = null
	GameState.hud_enemy = null


static func disincarnate() -> void:
	GameState.incarnated = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_incarnate.visible = false
	_incarnate.pressed.connect(func() -> void:
		if _hover and _hover.unit:
			incarnate(_hover.unit)
		_incarnate.visible = false)
	_incarnate.mouse_entered.connect(func() -> void: _hide_at = INF)
	_incarnate.mouse_exited.connect(_schedule_hide)
	add_child(_incarnate)
	# Barillet des munitions de l'Arbalestrie, à gauche de la barre PV (Arbalestrie modulaire).
	add_child(preload("res://ui/hud/ammo_barrel.gd").new())
	# Barre d'objets (sceau de minage, Arbalestrie, balles), sous la barre PV.
	add_child(ItemBar.new())
	# Paquetage de l'Ingénieur (10 cases), en bas de l'écran.
	add_child(PackBar.new())


func _schedule_hide() -> void:
	_hide_at = Time.get_ticks_msec() + 150.0


## Incarné : vie de l'Exilé en bas de l'écran (cadre 16 bits, SnesBanner).
const HP_W := 260.0
const HP_H := 34.0
const ItemBar := preload("res://ui/hud/item_bar.gd")
## Écart entre le bas de la barre PV et le bas de l'écran : la barre d'objets se loge dessous.
const HP_BOTTOM := ItemBar.MARGIN + ItemBar.SLOT + ItemBar.HP_GAP


func _draw() -> void:
	var inc := GameState.incarnated
	if inc == null or not inc.alive() or HudModel.incarnated_panel():
		return
	var screen := get_viewport_rect().size
	var r := Rect2(roundf((screen.x - HP_W) / 2.0), screen.y - HP_BOTTOM - HP_H, HP_W, HP_H)
	SnesBanner.paint(self, r)
	var f := HudStyle.font()
	var k := clampf(inc.hp / maxf(1.0, inc.max_hp), 0.0, 1.0)
	var bar := Rect2(r.position + Vector2(46, 12), Vector2(HP_W - 58, 10))
	draw_string(f, r.position + Vector2(12, 23), "PV", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, SnesBanner.INK)
	draw_rect(bar, Color("#0a0c26"))
	var col := UnitView.HP_ALLY if k > 0.5 else (Color("#e8c04a") if k > 0.25 else Color("#e05a4a"))
	draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * k), bar.size.y)), col)
	draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * k), 2)), Color(1, 1, 1, 0.3))
	var txt := "%d / %d" % [ceili(inc.hp), roundi(inc.max_hp)]
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(f, bar.position + Vector2((bar.size.x - tw) / 2.0 + 1, 10), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SnesBanner.SHADOW)
	draw_string(f, bar.position + Vector2((bar.size.x - tw) / 2.0, 9), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SnesBanner.INK)


func _process(_delta: float) -> void:
	queue_redraw()
	var inc := GameState.incarnated
	if inc and (not inc.alive() or inc.hidden or GameState.ended):
		disincarnate()
		inc = null
	var exiles := unlocked() if inc == null else ([] as Array[Unit])
	while _slots.size() < exiles.size():
		var s := _Slot.new()
		s.mouse_entered.connect(_on_slot_enter.bind(s))
		s.mouse_exited.connect(_schedule_hide)
		add_child(s)
		_slots.append(s)
	var screen := get_viewport_rect().size
	for i in _slots.size():
		var s := _slots[i]
		s.visible = i < exiles.size()
		if s.visible:
			if s.unit != exiles[i] or s.key != HudModel.portrait_key(exiles[i]):
				s.unit = exiles[i]
				s.key = HudModel.portrait_key(s.unit)
				s.texture = _portrait(s.key)
				s.tooltip_text = s.unit.name
				s.queue_redraw()
			s.position = Vector2(Hud.BAR_MARGIN + i * (SIZE + GAP), hud_bottom - GAP - SIZE)
			s.size = Vector2(SIZE, SIZE)
	if _hover and (not _hover.visible or Time.get_ticks_msec() >= _hide_at):
		_hover.hot = false
		_hover.queue_redraw()
		_hover = null
		_hide_at = INF
	_incarnate.visible = _hover != null
	if _hover:
		_incarnate.size = Vector2(maxf(SIZE + 30.0, _incarnate.min_width()), BTN_H)
		_incarnate.position = Vector2(_hover.position.x + (SIZE - _incarnate.size.x) * 0.5, _hover.position.y - 4.0 - BTN_H)
		_incarnate.position.x = maxf(4.0, _incarnate.position.x)
	if inc:
		if world:
			world.camera.set_view(inc.pos(), world.camera.px)


func _on_slot_enter(s: _Slot) -> void:
	if _hover and _hover != s:
		_hover.hot = false
		_hover.queue_redraw()
	_hover = s
	_hide_at = INF
	s.hot = true
	s.queue_redraw()


func _portrait(key: String) -> Texture2D:
	if Hud.PORTRAITS_EXTRA.has(key):
		return load(Hud.PORTRAITS_EXTRA[key])
	return load(PORTRAITS % key) if ResourceLoader.exists(PORTRAITS % key) else null


class _Slot extends Control:
	var unit: Unit
	var key := ""
	var texture: Texture2D
	var hot := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("#0b100e"))
		if texture:
			draw_texture_rect(texture, r.grow(-2.0), false, Color(1.25, 1.2, 1.05) if hot else Color(0.78, 0.78, 0.78))
		if hot:
			for i in 4:
				HudStyle.ring(self, r.grow(1.0 + i), 1.0, Color(HudStyle.GOLD_LIGHT, 0.5 - i * 0.12))
			HudStyle.ring(self, r, 2.0, HudStyle.GOLD_LIGHT)
		else:
			HudStyle.ring(self, r, 1.0, HudStyle.GOLD)


class _TextButton extends BaseButton:
	var text := ""

	func _init(t: String) -> void:
		text = t
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func min_width() -> float:
		return HudStyle.text_width(text, 13) + 24.0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var hover := is_hovered()
		var pressed := PressFx.down(self)
		PressFx.begin(self, r, pressed)
		draw_rect(r, Color("#2a2414") if hover else Color("#14170f"))
		HudStyle.ring(self, r, 1.0, HudStyle.GOLD_LIGHT if hover else HudStyle.GOLD)
		var f := HudStyle.font()
		var w := HudStyle.text_width(text, 13)
		var y := (size.y + f.get_ascent(13) - f.get_descent(13)) * 0.5
		PressFx.finish(self, r, pressed)
		if pressed:
			draw_set_transform(Vector2(0.0, PressFx.DEPTH))
		draw_string(f, Vector2((size.x - w) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, HudStyle.IVORY)
		draw_set_transform(Vector2.ZERO)
