extends Control
## Barillet des munitions de l'Arbalestrie (planches/arbalestrie-modulaire-planche.html, HUD · C, validé le
## 2026-11-19) : une case ronde à gauche de la barre PV de l'Exilé incarné montre la munition active ; un clic
## l'ouvre en éventail de cinq cases au-dessus, un clic sur une case la choisit et referme. Survol : bulle
## 16 bits nom · effet (les munitions ne coûtent plus de mana). La molette (sans Ctrl) fait défiler les
## munitions tant que le barillet est affiché ; Ctrl + molette garde le zoom de la caméra.

const Ammo := preload("res://data/ammo.gd")
const R_MAIN := 19.0
const R_SLOT := 17.0
const FAN_R := 60.0
## Pixel des balles dessinées dans les cases (pixels natifs du monde, agrandis).
const ICON_PX := 3.0

var _open := false
var _hover := -1
var _drawer := EffectsDrawer.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_drawer.ci = self
	_drawer.px = ICON_PX


static func available() -> bool:
	var u := HudModel.hud_exile()
	return u != null and u.alive() and not GameState.ended and Ammo.unlocked() \
		and Catalog.gear_weapon(u).has("mana") and not HudModel.incarnated_panel()


## Centre de la case principale : dans le losange doré à droite de la console (ExileGallery.gem_center).
func _center() -> Vector2:
	return ExileGallery.gem_center(get_viewport_rect().size, true)


func _slot_center(i: int) -> Vector2:
	var a := deg_to_rad(-175.0 + i * 30.0)
	return _center() + Vector2(cos(a), sin(a)) * FAN_R


## Case sous `p` : −2 = case principale, 0…4 = case de l'éventail ouvert, −1 = rien.
func _pick(p: Vector2) -> int:
	if not available():
		return -1
	if p.distance_to(_center()) <= R_MAIN:
		return -2
	if _open:
		for i in Ammo.ORDER.size():
			if p.distance_to(_slot_center(i)) <= R_SLOT:
				return i
	return -1


func _has_point(p: Vector2) -> bool:
	return _pick(p) != -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _pick(event.position)
		if h != _hover:
			_hover = h
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var h := _pick(event.position)
		if h == -2:
			_open = not _open
		elif h >= 0:
			Ammo.select(Ammo.ORDER[h])
			_open = false
		accept_event()
		queue_redraw()


func _input(event: InputEvent) -> void:
	if HelpPanel.open or not available() or not (event is InputEventMouseButton) or not event.pressed:
		return
	# Clic ailleurs : l'éventail se referme (le clic poursuit son chemin).
	if _open and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] and _pick(event.position) == -1:
		_open = false
		queue_redraw()
	# Molette : munition précédente / suivante, sauf au-dessus d'un autre élément du HUD ou avec Ctrl (zoom).
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and not event.ctrl_pressed:
		var over := get_viewport().gui_get_hovered_control()
		if over != null and over != self:
			return
		Ammo.cycle(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		get_viewport().set_input_as_handled()
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != -1:
		_hover = -1
		queue_redraw()


func _process(_delta: float) -> void:
	if not available() and (_open or _hover != -1):
		_open = false
		_hover = -1
	queue_redraw()


func _draw() -> void:
	if not available():
		return
	var cur := Ammo.current()
	_disc(_center(), R_MAIN, true, true, _hover == -2)
	_icon(_center(), cur)
	if not _open:
		return
	for i in Ammo.ORDER.size():
		var id: String = Ammo.ORDER[i]
		_disc(_slot_center(i), R_SLOT, id == cur, true, _hover == i)
		_icon(_slot_center(i), id)
	if _hover >= 0:
		_tip(Ammo.ORDER[_hover])


## Case ronde 16 bits : contour sombre, liseré blanc, fond bleu en bandes ; active = lueur cyan intérieure.
func _disc(c: Vector2, r: float, active: bool, ok: bool, hover: bool) -> void:
	draw_circle(c + Vector2(3, 4), r, Color(0, 0, 0, 0.35))
	draw_circle(c, r, SnesBanner.EDGE)
	draw_circle(c, r - 1.0, SnesBanner.RIM if ok else SnesBanner.RIM_LO)
	draw_circle(c, r - 3.0, SnesBanner.RIM_LO)
	var bands := 8
	for i in bands:
		var t := float(i) / (bands - 1)
		draw_circle(c + Vector2(0, -t * 2.0), (r - 4.0) * (1.0 - t * 0.55), SnesBanner.DEEP.lerp(SnesBanner.SKY, t))
	if active:
		draw_arc(c, r - 4.0, 0.0, TAU, 40, Color("#5ce8ff"), 2.0, true)
		draw_arc(c, r - 6.5, 0.0, TAU, 40, Color(0.36, 0.91, 1.0, 0.35), 3.0, true)
	if hover:
		draw_arc(c, r - 1.0, 0.0, TAU, 40, Color.WHITE, 2.0, true)


## La balle elle-même, dessinée comme en vol (EffectsDrawer), en pixels de ICON_PX.
func _icon(c: Vector2, id: String) -> void:
	var n := (c / ICON_PX).floor()
	match id:
		"spirit": _drawer._ball_spirit(n.x, n.y, 0.04, 11)
		"indra": _drawer._ball_indra(n.x + 1, n.y, Vector2.RIGHT, 0.04, 11)
		"medeina": _drawer._ball_medeina(n.x, n.y, Vector2.RIGHT, 0.04)
		"sigil":
			_drawer._ball_sigil(n.x, n.y - 2, Vector2.RIGHT, 0.0)
			_drawer._ball_sigil(n.x, n.y + 2, Vector2.RIGHT, 0.0)
		"aether": _drawer._ball_aether(n.x, n.y, Vector2.RIGHT, 0.04)


## Bulle 16 bits au-dessus de l'éventail : nom · effet.
func _tip(id: String) -> void:
	var A: Dictionary = Ammo.AMMO[id]
	var f := HudStyle.font()
	var txt := "%s · %s" % [A["name"], A["desc"]]
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 24.0
	var r := Rect2(Vector2(_center().x - 30.0, _center().y - FAN_R - R_SLOT - 41.0), Vector2(w, 29.0))
	r.position.x = clampf(r.position.x, 8.0, get_viewport_rect().size.x - 8.0 - w)
	SnesBanner.paint(self, r)
	var y := r.position.y + 19.0
	draw_string(f, Vector2(r.position.x + 13.0, y + 1.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, SnesBanner.SHADOW)
	draw_string(f, Vector2(r.position.x + 12.0, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
