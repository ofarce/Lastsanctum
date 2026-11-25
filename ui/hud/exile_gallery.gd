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
	# Barillet des munitions de l'Arbalestrie, dans le losange doré à droite de la console (Arbalestrie modulaire).
	add_child(preload("res://ui/hud/ammo_barrel.gd").new())
	# Plus de barre d'objets (sceau, Arbalestrie, balle) sous la barre PV depuis le 2026-11-24 : demande de l'utilisateur ;
	# item_bar.gd ne sert plus qu'aux mesures et au dessin des cases.
	# Paquetage de l'Ingénieur (10 cases), en bas de l'écran.
	add_child(PackBar.new())
	# Étagère des 6 mods portés, posée sur la pointe de la barre PV (planches/console-mods-propositions.html, piste A).
	add_child(preload("res://ui/hud/mod_shelf.gd").new())


func _schedule_hide() -> void:
	_hide_at = Time.get_ticks_msec() + 150.0


## Incarné : console du bas de l'écran (inspirée d'un HUD d'action en fer sombre) : barre de PV rouge sur toute
## la largeur, cases du paquetage dessous (PackBar, enfant dessiné par-dessus), losange de
## gauche = portrait de l'Exilé, losange doré de droite = barillet des munitions (ammo_barrel.gd).
const ItemBar := preload("res://ui/hud/item_bar.gd")
const HP_H := 22.0
## Écart entre la barre PV et la rangée des cases.
const HP_GAP := 9.0
## Demi-diagonale des losanges et écart avec la rangée.
const GEM := 38.0
const GEM_GAP := 2.0
const IRON_EDGE := Color("#07080b")
const IRON_DK := Color("#1b1e25")
const IRON := Color("#2c3038")
const IRON_HI := Color("#555b68")
const IRON_LIGHT := Color("#8b92a2")
const GOLD_DK := Color("#4a3210")
const GOLD := Color("#b8893e")
const GOLD_HI := Color("#f2d38a")

var _gem_tex: Texture2D
var _gem_key := ""


## Rangée des cases du bas (le paquetage, une ou deux lignes), incarné. Sans paquetage, la console garde sa largeur.
static func row_rect(screen: Vector2) -> Rect2:
	var slot := ItemBar.SLOT
	var gap := ItemBar.GAP
	var w := PackBar.width()
	var y := screen.y - ItemBar.MARGIN - slot
	var h := slot
	if PackBar.rows() > 1:
		y -= slot + gap
		h += slot + gap
	return Rect2(roundf((screen.x - w) / 2.0), y, w, h)


static func hp_rect(screen: Vector2) -> Rect2:
	var row := row_rect(screen)
	return Rect2(row.position.x, row.position.y - HP_GAP - HP_H, row.size.x, HP_H)


## Étagère des mods (piste A « Étagère », choisie le 2026-11-24) : plaque centrée au-dessus du cadre de la barre PV,
## dont la pointe vient la soutenir ; 6 cases de SHELF_SLOT px, au pas de SHELF_STEP.
const SHELF_SLOT := 34.0
const SHELF_STEP := 40.0
const SHELF_W := 254.0
const SHELF_H := 50.0


static func shelf_rect(screen: Vector2) -> Rect2:
	var row := row_rect(screen)
	var top := hp_rect(screen).position.y - 5.0
	return Rect2(roundf(row.get_center().x - SHELF_W / 2.0), top - SHELF_H - 2.0, SHELF_W, SHELF_H)


static func shelf_slot(screen: Vector2, i: int) -> Rect2:
	var s := shelf_rect(screen)
	var w := 5.0 * SHELF_STEP + SHELF_SLOT
	return Rect2(s.position.x + roundf((SHELF_W - w) / 2.0) + i * SHELF_STEP, s.position.y + 6.0, SHELF_SLOT, SHELF_SLOT)


## Haut de la console (haut de l'étagère) : les bulles de survol des cases se posent au-dessus.
static func console_top(screen: Vector2) -> float:
	return shelf_rect(screen).position.y


## Centres des losanges : à gauche (portrait) et à droite (barillet), à mi-hauteur de la console.
static func gem_center(screen: Vector2, right: bool) -> Vector2:
	var row := row_rect(screen)
	var hp := hp_rect(screen)
	var y := roundf((hp.position.y + row.end.y) / 2.0)
	return Vector2(row.end.x + GEM_GAP + GEM if right else row.position.x - GEM_GAP - GEM, y)


func _draw() -> void:
	var inc := HudModel.hud_exile()
	if inc == null or not inc.alive() or HudModel.incarnated_panel():
		return
	var screen := get_viewport_rect().size
	var row := row_rect(screen)
	var hp := hp_rect(screen)
	# Plaque des cases, puis cadre de la barre PV (bouts biseautés, pointe au milieu), comme le modèle.
	var plate := row.grow_individual(14.0, 7.0, 14.0, 7.0)
	_iron(_chamfer(plate, 7.0), false)
	# Étagère des mods avant le cadre PV : la pointe du cadre passe devant son bord bas.
	_iron(_chamfer(shelf_rect(screen), 6.0), false)
	var frame := hp.grow_individual(10.0, 5.0, 10.0, 4.0)
	var mid := frame.get_center().x
	_iron(PackedVector2Array([
		Vector2(frame.position.x, frame.end.y), Vector2(frame.position.x + 12.0, frame.position.y),
		Vector2(mid - 16.0, frame.position.y), Vector2(mid, frame.position.y - 8.0), Vector2(mid + 16.0, frame.position.y),
		Vector2(frame.end.x - 12.0, frame.position.y), Vector2(frame.end.x, frame.end.y)]), false)
	_hp_bar(hp, inc)
	_gem_left(gem_center(screen, false), inc)
	_iron(_diamond(gem_center(screen, true), GEM), true)


## Polygone en fer 16 bits : ombre portée, contour noir, liseré clair, corps, ombre basse.
func _iron(pts: PackedVector2Array, gold: bool) -> void:
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(3, 4))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.4))
	var tones := [GOLD_DK, GOLD_HI, GOLD, GOLD_DK] if gold else [IRON_EDGE, IRON_HI, IRON, IRON_DK]
	draw_colored_polygon(pts, tones[0])
	var rim := _inset(pts, 1.0)
	draw_colored_polygon(rim, tones[1])
	var body := _inset(pts, 2.5)
	draw_colored_polygon(body, tones[2])
	# Bas du corps plus sombre : relief vu de face.
	var r := _bounds(body)
	var low := Geometry2D.intersect_polygons(body, PackedVector2Array([
		Vector2(r.position.x - 1, r.get_center().y + r.size.y * 0.2), Vector2(r.end.x + 1, r.get_center().y + r.size.y * 0.2),
		Vector2(r.end.x + 1, r.end.y + 1), Vector2(r.position.x - 1, r.end.y + 1)]))
	for poly in low:
		draw_colored_polygon(poly, tones[3])
	if gold:
		draw_colored_polygon(_inset(pts, 6.0), IRON_EDGE)


func _hp_bar(r: Rect2, inc: Unit) -> void:
	var k := clampf(inc.hp / maxf(1.0, inc.max_hp), 0.0, 1.0)
	draw_rect(r, IRON_EDGE)
	draw_rect(r.grow(-1.0), Color("#2a0c0c"))
	var fill := Rect2(r.position + Vector2(1, 1), Vector2(roundf((r.size.x - 2.0) * k), r.size.y - 2.0))
	var bands := [Color("#ff7a5c"), Color("#e8402e"), Color("#c62a20"), Color("#a41c16"), Color("#7e120e")]
	var bh := fill.size.y / bands.size()
	for i in bands.size():
		draw_rect(Rect2(fill.position.x, fill.position.y + roundf(i * bh), fill.size.x, ceilf(bh)), bands[i])
	draw_rect(Rect2(fill.position + Vector2(0, 2), Vector2(fill.size.x, 1)), Color(1, 1, 1, 0.35))
	if fill.size.x > 2.0:
		draw_rect(Rect2(fill.end.x - 2.0, fill.position.y, 2.0, fill.size.y), Color("#ffb39a"))
	var f := HudStyle.font()
	var txt := "%d / %d" % [ceili(inc.hp), roundi(inc.max_hp)]
	var size := 14
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(roundf(r.get_center().x - tw / 2.0), roundf(r.get_center().y + (f.get_ascent(size) - f.get_descent(size)) / 2.0))
	draw_string_outline(f, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color("#1a0606"))
	draw_string(f, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("#fff4e8"))


## Losange de gauche : cadre de fer, portrait de l'Exilé découpé en losange, ombre basse.
func _gem_left(c: Vector2, inc: Unit) -> void:
	var pts := _diamond(c, GEM)
	_iron(pts, false)
	draw_colored_polygon(_inset(pts, 5.0), IRON_EDGE)
	var key := HudModel.portrait_key(inc)
	if key != _gem_key:
		_gem_key = key
		_gem_tex = _portrait(key)
	var inner := _diamond(c, GEM - 7.0)
	# Fond du médaillon : bleu acier, plus clair derrière la tête.
	draw_colored_polygon(inner, Color("#18202e"))
	draw_colored_polygon(_diamond(c + Vector2(0, -4), GEM - 18.0), Color("#24304a"))
	if _gem_tex:
		var uvs := PackedVector2Array()
		var zoom := 0.8
		for p in inner:
			uvs.append(Vector2(0.5, 0.64) + (p - c) / ((GEM - 7.0) * 2.0) * zoom)
		var cols := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
		draw_polygon(inner, cols, uvs, _gem_tex)
	# Liseré clair en haut à gauche, comme une gemme taillée.
	draw_polyline(PackedVector2Array([inner[3], inner[0], inner[1]]), Color(IRON_LIGHT, 0.9), 1.0)


static func _diamond(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])


static func _chamfer(r: Rect2, k: float) -> PackedVector2Array:
	return PackedVector2Array([
		r.position + Vector2(k, 0), Vector2(r.end.x - k, r.position.y), Vector2(r.end.x, r.position.y + k),
		r.end - Vector2(0, k), r.end - Vector2(k, 0), Vector2(r.position.x + k, r.end.y),
		Vector2(r.position.x, r.end.y - k), r.position + Vector2(0, k)])


static func _inset(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := Geometry2D.offset_polygon(pts, -d, Geometry2D.JOIN_MITER)
	return out[0] if not out.is_empty() else pts


static func _bounds(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


func _process(_delta: float) -> void:
	queue_redraw()
	var inc := GameState.incarnated
	if inc and (not inc.alive() or inc.hidden or GameState.ended):
		disincarnate()
	inc = HudModel.hud_exile()
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
