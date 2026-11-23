class_name IdleButton
extends Control
## Oisifs (mode commandant) : adeptes de culte sans tâche, bâtiments à l'arrêt faute de personnel au poste.
## Pastille métallique au-dessus du bandeau de commandement, à droite ; masquée quand il n'y a rien.
## Clic : sélectionne le suivant (adeptes d'abord, puis bâtiments) et y centre la caméra.
## Maj + clic : sélectionne tous les adeptes oisifs.

const H := 34.0
## Un adepte qui vient de finir une tâche n'est compté oisif qu'après ce délai (il repart souvent seul).
const SETTLE := 2.0

var world: World
var adepts: Array[Unit] = []
var buildings: Array[Building] = []
var _since := {}
var _next := 0
var _hover := false
var _text := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Clic : sélectionner le suivant · Maj + clic : tous les adeptes oisifs"
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())
	Events.game_reset.connect(func() -> void:
		_since.clear()
		_next = 0)


## Adepte de culte (tâche « pray ») vivant, visible, sans tâche, ni chantier ni orbe, arrivé où on l'a envoyé.
static func idle_adept(u: Unit) -> bool:
	if not u.alive() or u.hidden or u.job != null or u.build_job != null or u.orb_job:
		return false
	if String(Catalog.ADEPT.get(u.role, {}).get("task", "")) != "pray":
		return false
	return Vector2(u.tx, u.tz).distance_to(u.pos()) < 0.6


func update() -> void:
	var now := GameState.sim_time
	adepts.clear()
	for u: Unit in GameState.units:
		if idle_adept(u):
			if not _since.has(u):
				_since[u] = now
			if now - float(_since[u]) >= SETTLE:
				adepts.append(u)
		else:
			_since.erase(u)
	buildings.clear()
	for b: Building in GameState.buildings:
		if Production.idle(b):
			buildings.append(b)
	var parts: Array[String] = []
	if not adepts.is_empty():
		parts.append("%d adepte%s oisif%s" % [adepts.size(), "s" if adepts.size() > 1 else "", "s" if adepts.size() > 1 else ""])
	if not buildings.is_empty():
		parts.append("%d bâtiment%s à l’arrêt" % [buildings.size(), "s" if buildings.size() > 1 else ""])
	var text := " · ".join(parts)
	if text != _text:
		_text = text
		size = Vector2(16.0 + 18.0 + 8.0 + HudStyle.text_width(text, 14) + 14.0, H)
		queue_redraw()
	visible = not text.is_empty()


func _gui_input(event: InputEvent) -> void:
	PressFx.track(self, event)
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	if event.shift_pressed and not adepts.is_empty():
		GameState.selected.assign(adepts)
		_select_common()
		world.camera.set_view(adepts[0].pos(), world.camera.px)
		return
	var n := adepts.size() + buildings.size()
	if n == 0:
		return
	_next %= n
	if _next < adepts.size():
		var u := adepts[_next]
		GameState.selected.assign([u])
		_select_common()
		world.camera.set_view(u.pos(), world.camera.px)
	else:
		var b := buildings[_next - adepts.size()]
		GameState.selected = []
		_select_common()
		GameState.hud_building = b
		world.camera.set_view(Vector2(b.x, b.z), world.camera.px)
	_next += 1


func _select_common() -> void:
	Sfx.play("ui_selection")
	GameState.hud_enemy = null
	GameState.anchor_selected = false
	GameState.hud_mode = ""
	GameState.hud_menu = ""
	GameState.hud_building = null
	GameState.hud_grove = null


func _draw() -> void:
	if _text.is_empty():
		return
	var r := Rect2(Vector2.ZERO, size)
	var pressed := PressFx.down(self)
	PressFx.begin(self, r, pressed)
	HudStyle.metal_panel(self, size)
	if _hover:
		HudStyle.ring(self, r.grow(-2.0), 1.0, Color("#ffe0a0"))
	draw_texture(HudStyle.icon("people", 18), Vector2(16.0, (H - 18.0) / 2.0), Color("#e9c784"))
	draw_string(HudStyle.font(), Vector2(42.0, H / 2.0 + 5.0), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, HudStyle.IVORY)
	PressFx.finish(self, r, pressed)
