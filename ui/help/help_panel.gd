class_name HelpPanel
extends Control
## Codex d'aide (planche planches/aide-propositions.html) : voile sombre, panneau métallique à onglets,
## jeu en pause tant qu'il est ouvert. Ouvert par le bouton « ? » du HUD (HelpButton) ou par F1 ;
## fermé par F1, Échap ou le bouton « Fermer ». Les textes viennent de HelpData.

const FRAME := Vector2(940.0, 592.0)
const HEAD_H := 64.0
const FOOT_H := 30.0
const TABS_W := 222.0
const LINE := Color("#7c603170")
const BRASS_TOP := Color("#e2bd78")
const BRASS_BOTTOM := Color("#a87a37")
const BRASS_INK := Color("#1a140a")
const SETTINGS := "user://aide.cfg"
## Distance (unités du monde) à laquelle un pylône compte comme « vu » : la page Monde se déverrouille.
const PYLON_SEEN := 26.0

## Vrai tant que le codex est ouvert : les commandes du jeu (InputController, inventaire, barillet)
## s'effacent.
static var open := false
## Faux dans les captures : l'ouverture n'est pas retenue (le halo du joueur reste intact).
static var persist := true
## Un Pylône de Merenor a été approché pendant cette partie.
static var world_seen := false

var sim: Simulation
var world: World

var _frame := _Frame.new()
var _tabs: Array[_Tab] = []
var _close := _Tab.new()
var _page := VBoxContainer.new()
var _current := 0
var _was_paused := false
var _cam_was := true
var _scan := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	open = false
	world_seen = false
	add_child(_frame)
	for i in HelpData.TABS.size():
		var t := _Tab.new()
		t.pressed.connect(select.bind(i))
		_frame.add_child(t)
		_tabs.append(t)
	_close.text = "Fermer"
	_close.key = "Échap"
	_close.pressed.connect(close)
	_frame.add_child(_close)
	_page.clip_contents = true
	_page.add_theme_constant_override("separation", 12)
	_frame.add_child(_page)
	Events.game_reset.connect(func() -> void:
		world_seen = false
		close())


## Vrai si l'aide n'a encore jamais été ouverte sur cette machine (halo du bouton).
static func never_opened() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(SETTINGS) != OK or not cfg.get_value("aide", "ouverte", false)


func toggle() -> void:
	if open:
		close()
	else:
		show_help()


func show_help() -> void:
	if open:
		return
	open = true
	visible = true
	if sim != null:
		_was_paused = sim.paused
		sim.paused = true
	if world != null:
		_cam_was = world.camera.input_enabled
		world.camera.input_enabled = false
	if persist:
		var cfg := ConfigFile.new()
		cfg.set_value("aide", "ouverte", true)
		cfg.save(SETTINGS)
	_layout()
	select(_current)


func close() -> void:
	if not open:
		return
	open = false
	visible = false
	if sim != null:
		sim.paused = _was_paused
	if world != null:
		world.camera.input_enabled = _cam_was


## Touches du codex, appelée par Hud._input. Vrai si l'événement est consommé.
func handle_input(event: InputEvent) -> bool:
	if not (event is InputEventKey) or not event.pressed:
		return false
	var k: Key = event.key_label if event.key_label != KEY_NONE else event.keycode
	if k == KEY_F1:
		if not event.echo and (open or not Opening.cinematic()) and not PauseMenu.open:
			toggle()
		return true
	if not open:
		return false
	if k == KEY_ESCAPE:
		close()
	elif k in [KEY_DOWN, KEY_S]:
		select((_current + 1) % _tabs.size())
	elif k in [KEY_UP, KEY_Z]:
		select((_current + _tabs.size() - 1) % _tabs.size())
	return true


func _locked(i: int) -> bool:
	return HelpData.TABS[i].get("locked", false) and not world_seen


func select(i: int) -> void:
	_current = i
	for n in _tabs.size():
		var d: Dictionary = HelpData.TABS[n]
		_tabs[n].locked = _locked(n)
		_tabs[n].text = HelpData.LOCKED_NAME if _tabs[n].locked else d["name"]
		_tabs[n].icon = "rune" if _tabs[n].locked else d["icon"]
		_tabs[n].selected = n == i
		_tabs[n].queue_redraw()
	_build_page()


func _process(delta: float) -> void:
	# Découverte d'un pylône : une unité des Exilés s'en est approchée (vérifié une fois par seconde).
	if not world_seen and sim != null:
		_scan -= delta
		if _scan <= 0.0:
			_scan = 1.0
			_look_for_pylon()
	if visible:
		var s := get_viewport_rect().size
		if size != s:
			_layout()


func _look_for_pylon() -> void:
	for p: Dictionary in sim.state().portals:
		if not p.get("active", false):
			continue
		var at := Vector2(float(p["x"]), float(p["z"]))
		for u: Unit in GameState.units:
			if u.alive() and Vector2(u.x, u.z).distance_to(at) < PYLON_SEEN:
				world_seen = true
				if open:
					select(_current)
				return


func _layout() -> void:
	# Le conteneur du HUD n'a pas de taille propre : on couvre l'écran.
	var s := get_viewport_rect().size
	position = Vector2.ZERO
	size = s
	_frame.size = Vector2(minf(FRAME.x, s.x - 32.0), minf(FRAME.y, s.y - 32.0))
	_frame.position = ((s - _frame.size) / 2.0 - Vector2(0.0, 8.0)).round().max(Vector2(16.0, 16.0))
	for i in _tabs.size():
		_tabs[i].position = Vector2(10.0, HEAD_H + 12.0 + i * 51.0)
		_tabs[i].size = Vector2(TABS_W - 20.0, 46.0)
	_close.size = Vector2(HudStyle.text_width("Fermer", 13) + _Key.width("Échap") + 30.0, 32.0)
	_close.position = Vector2(_frame.size.x - 20.0 - _close.size.x, (HEAD_H - 32.0) / 2.0)
	_frame.close_x = _close.position.x
	_page.position = Vector2(TABS_W + 26.0, HEAD_H + 18.0)
	_page.size = Vector2(_frame.size.x - TABS_W - 52.0, _frame.size.y - HEAD_H - FOOT_H - 26.0)
	_frame.queue_redraw()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#050806c7"))


# ---------------------------------------------------------------- Page

func _build_page() -> void:
	for c in _page.get_children():
		_page.remove_child(c)
		c.queue_free()
	var d: Dictionary = HelpData.TABS[_current]
	if _locked(_current):
		var msg := _text(HelpData.LOCKED_TEXT, 14, Color("#8d8672"), true)
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		msg.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_page.add_child(msg)
		return
	_page.add_child(_text(d["title"], 24, HudStyle.GOLD_LIGHT))
	_page.add_child(_text(d["lore"], 13, Color("#ddcfaf"), true, HudStyle.italic()))
	for b: Dictionary in d["blocks"]:
		if b.has("keys"):
			_page.add_child(_keys_block(b["keys"]))
		elif b.has("strip"):
			_page.add_child(_strip_block(b["strip"]))
		elif b.has("cards"):
			_page.add_child(_cards_block(b["cards"]))
		elif b.has("table"):
			_page.add_child(_table_block(b["table"]))
		elif b.has("list"):
			_page.add_child(_list_block(b["list"]))


static func _text(text: String, px: int, color: Color, wrap := false, f: Font = null) -> Label:
	var l := HudStyle.label(px, color, f)
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func _box(margin: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#0c100e")
	sb.border_color = LINE
	sb.set_border_width_all(1)
	sb.set_content_margin_all(margin)
	return sb


## Rangée de jetons : touches, souris, mots (voir HelpData).
static func _tokens(tokens: Array, px := 12) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for t: String in tokens:
		var c: Control
		if t.begins_with("@"):
			var m := _Mouse.new()
			m.part = t.substr(1)
			c = m
		elif t.begins_with("~"):
			c = _text(t.substr(1), px, HudStyle.MUTED)
		else:
			var k := _Key.new()
			k.text = t
			c = k
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(c)
	return row


func _keys_block(groups: Array) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 12)
	for g: Array in groups:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)
		col.add_child(_text(String(g[0]).to_upper(), 10, HudStyle.MUTED, false, HudStyle.spaced(2)))
		var rule := ColorRect.new()
		rule.color = Color("#7c603150")
		rule.custom_minimum_size = Vector2(0, 1)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(rule)
		for r: Array in g[1]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var keys := _tokens(r[0])
			keys.custom_minimum_size = Vector2(128, 23)
			row.add_child(keys)
			var what := _text(r[1], 13, HudStyle.IVORY, true)
			what.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(what)
			col.add_child(row)
		grid.add_child(col)
	return grid


func _strip_block(strip: Array) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(9.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon := TextureRect.new()
	icon.texture = HudStyle.icon(strip[0], 20)
	icon.modulate = HudStyle.GOLD_LIGHT
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(icon)
	var title := _text(strip[1], 13, HudStyle.GOLD_LIGHT)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var tokens: Array = strip[2]
	if tokens.size() == 1 and String(tokens[0]).begins_with("~"):
		var what := _text(String(tokens[0]).substr(1), 12, HudStyle.IVORY, true)
		what.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(what)
	else:
		row.add_child(_tokens(tokens))
	panel.add_child(row)
	return panel


func _cards_block(cards: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for c: Array in cards:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _box(11.0))
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 5)
		if c[0] != "":
			var icon := TextureRect.new()
			icon.texture = HudStyle.icon(c[0], 26)
			icon.modulate = HudStyle.GOLD_LIGHT
			icon.stretch_mode = TextureRect.STRETCH_KEEP
			col.add_child(icon)
		col.add_child(_text(c[1], 15, HudStyle.GOLD_LIGHT))
		col.add_child(_text(c[2], 12, HudStyle.IVORY, true))
		panel.add_child(col)
		row.add_child(panel)
	return row


func _table_block(table: Dictionary) -> Control:
	var head: Array = table["head"]
	var grid := GridContainer.new()
	grid.columns = head.size()
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 7)
	for h: String in head:
		grid.add_child(_text(h.to_upper(), 10, HudStyle.MUTED, false, HudStyle.spaced(2)))
	for r: Array in table["rows"]:
		for i in r.size():
			var last := i == r.size() - 1
			grid.add_child(_text(r[i], 13, HudStyle.GOLD_LIGHT if i == 0 else HudStyle.IVORY, last))
	return grid


func _list_block(items: Array) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	for it: String in items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_text("▸", 13, HudStyle.GOLD))
		row.add_child(_text(it, 13, HudStyle.IVORY, true))
		col.add_child(row)
	return col


# ---------------------------------------------------------------- Éléments dessinés

## Cadre du codex : panneau métallique, en-tête, colonne d'onglets, pied.
class _Frame extends Control:
	var close_x := 0.0

	func _draw() -> void:
		HudStyle.metal_panel(self, size)
		draw_rect(Rect2(6.0, HelpPanel.HEAD_H, size.x - 12.0, 1.0), HelpPanel.LINE)
		draw_rect(Rect2(6.0, size.y - HelpPanel.FOOT_H, size.x - 12.0, 1.0), HelpPanel.LINE)
		draw_rect(Rect2(HelpPanel.TABS_W, HelpPanel.HEAD_H, 1.0, size.y - HelpPanel.HEAD_H - HelpPanel.FOOT_H), HelpPanel.LINE)
		var f := HudStyle.font()
		draw_texture(HudStyle.icon("book", 30), Vector2(20.0, 17.0), HudStyle.GOLD_LIGHT)
		draw_string(HudStyle.spaced(2), Vector2(64.0, 26.0), "CODEX DE L’EXILÉ", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, HudStyle.MUTED)
		draw_string(f, Vector2(64.0, 50.0), "Aide", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, HudStyle.GOLD_LIGHT)
		# Rappel de la pause, à gauche du bouton Fermer.
		var pause := "JEU EN PAUSE"
		var pw := HudStyle.text_width(pause, 10, HudStyle.spaced(2))
		var pr := Rect2(close_x - 14.0 - pw - 18.0, 21.0, pw + 18.0, 22.0)
		HudStyle.ring(self, pr, 1.0, Color("#e6935466"))
		draw_string(HudStyle.spaced(2), pr.position + Vector2(9.0, 15.0), pause, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#e69354"))
		# Pied : rappel des touches.
		var y := size.y - HelpPanel.FOOT_H + 5.0
		var x := 20.0
		for part: Array in [["↑", true], ["↓", true], ["changer d’onglet", false], ["F1", true], ["ou", false], ["Échap", true], ["reprendre la partie", false]]:
			if part[1]:
				_Key.paint(self, Vector2(x, y), part[0])
				x += _Key.width(part[0]) + 4.0
			else:
				draw_string(f, Vector2(x + 2.0, y + 15.0), part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HudStyle.MUTED)
				x += HudStyle.text_width(part[0], 11) + (22.0 if String(part[0]).length() > 2 else 8.0)


## Onglet, et bouton Fermer (avec `key`) : laiton plein quand il est choisi, filet au survol.
class _Tab extends Control:
	signal pressed
	var text := ""
	var icon := ""
	var key := ""
	## Cadre sombre même sans touche (lignes du menu de pause).
	var boxed := false
	var selected := false
	var locked := false
	var _hover := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func() -> void:
			_hover = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hover = false
			queue_redraw())

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			accept_event()
			pressed.emit()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var fg := HudStyle.IVORY
		var ic := HudStyle.GOLD
		if selected:
			HudStyle.linear_gradient(self, r, 180.0, [[0.0, HelpPanel.BRASS_TOP], [1.0, HelpPanel.BRASS_BOTTOM]])
			HudStyle.ring(self, r, 1.0, Color("#ffe5ac"))
			fg = HelpPanel.BRASS_INK
			ic = HelpPanel.BRASS_INK
		elif key != "" or boxed:
			draw_rect(r, Color("#0c100e"))
			HudStyle.ring(self, r, 1.0, Color("#ffe0a0") if _hover else HudStyle.GOLD)
		elif _hover and not locked:
			HudStyle.ring(self, r, 1.0, Color("#7c6031"))
		if locked and not selected:
			fg = Color("#6f6a5a")
			ic = Color("#5a5546")
		var x := 11.0
		if icon != "":
			draw_texture(HudStyle.icon(icon, 22), Vector2(x, (size.y - 22.0) / 2.0), ic)
			x += 33.0
		var f := HudStyle.italic() if locked else HudStyle.font()
		var px := 13 if key != "" or boxed else 15
		draw_string(f, Vector2(x, size.y / 2.0 + px * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, fg)
		if key != "":
			_Key.paint(self, Vector2(size.x - 9.0 - _Key.width(key), (size.y - _Key.H) / 2.0), key)


## Touche de clavier.
class _Key extends Control:
	const H := 21.0
	var text := "":
		set(v):
			text = v
			custom_minimum_size = Vector2(width(v), H)

	static func width(t: String) -> float:
		return maxf(21.0, HudStyle.text_width(t, 11) + 11.0)

	static func paint(ci: CanvasItem, at: Vector2, t: String) -> void:
		var r := Rect2(at, Vector2(width(t), H))
		HudStyle.linear_gradient(ci, r, 180.0, [[0.0, Color("#262b22")], [1.0, Color("#131712")]])
		HudStyle.ring(ci, r, 1.0, HudStyle.GOLD)
		ci.draw_rect(Rect2(r.position.x, r.end.y - 2.0, r.size.x, 2.0), HudStyle.GOLD)
		var tw := HudStyle.text_width(t, 11)
		ci.draw_string(HudStyle.font(), Vector2(r.position.x + (r.size.x - tw) / 2.0, r.position.y + 14.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HudStyle.IVORY)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		paint(self, Vector2.ZERO, text)


## Souris : bouton gauche (L), droit (R) ou molette (W) en clair.
class _Mouse extends Control:
	var part := "L"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(14, 20)

	func _draw() -> void:
		var body := StyleBoxFlat.new()
		body.bg_color = Color.TRANSPARENT
		body.border_color = HudStyle.IVORY
		body.set_border_width_all(1)
		body.set_corner_radius_all(7)
		body.anti_aliasing = true
		var lit := StyleBoxFlat.new()
		lit.bg_color = HudStyle.GOLD_LIGHT
		match part:
			"L":
				lit.corner_radius_top_left = 6
				draw_style_box(lit, Rect2(1, 1, 6, 8))
			"R":
				lit.corner_radius_top_right = 6
				draw_style_box(lit, Rect2(7, 1, 6, 8))
			_:
				lit.set_corner_radius_all(1)
				draw_style_box(lit, Rect2(5.5, 3, 3, 6))
		draw_style_box(body, Rect2(0, 0, 14, 20))
