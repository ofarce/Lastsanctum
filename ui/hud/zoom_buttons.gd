extends Control
## Boutons « + » et « − » au-dessus de la minicarte : zoom de la caméra, un cran par clic (comme la molette),
## entre WorldCamera.PX_MIN et PX_MAX. Un bouton en butée est grisé.

const BTN := 28.0
const GAP := 4.0
const WIDTH := BTN * 2.0 + GAP

var world: World
var _hover := 0


func _ready() -> void:
	size = Vector2(WIDTH, BTN)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


## Bouton sous `p` : +1 (zoom avant), −1 (zoom arrière), 0 = aucun.
func _pick(p: Vector2) -> int:
	if p.y < 0.0 or p.y > BTN:
		return 0
	if p.x >= 0.0 and p.x <= BTN:
		return 1
	if p.x >= BTN + GAP and p.x <= WIDTH:
		return -1
	return 0


func _has_point(p: Vector2) -> bool:
	return _pick(p) != 0


func _can(step: int) -> bool:
	if world == null:
		return false
	var px := world.camera.px + step
	return px >= WorldCamera.PX_MIN and px <= WorldCamera.PX_MAX


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var step := _pick(event.position)
		PressFx.track(self, event, step if step != 0 and _can(step) else null)
	if event is InputEventMouseMotion:
		_hover = _pick(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var step := _pick(event.position)
		if step != 0 and _can(step):
			world.camera.set_view(world.camera.cam, world.camera.px + step)
		accept_event()
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = 0
		queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	for step: int in [1, -1]:
		var r := Rect2(0.0 if step == 1 else BTN + GAP, 0.0, BTN, BTN)
		var ok := _can(step)
		draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.35))
		# Enfoncé (PressFx) : la face descend sur son ombre portée.
		var pressed: bool = PressFx.down(self) and PressFx.pressed_key(self) is int and PressFx.pressed_key(self) == step
		if pressed:
			draw_set_transform(Vector2(1, PressFx.DEPTH))
		draw_rect(r, SnesBanner.EDGE)
		draw_rect(r.grow(-1.0), SnesBanner.RIM if ok else SnesBanner.RIM_LO)
		draw_rect(r.grow(-3.0), SnesBanner.DEEP.lerp(SnesBanner.SKY, 0.6 if ok and _hover == step else 0.25))
		var ink := SnesBanner.INK if ok else SnesBanner.RIM_LO
		var c := r.get_center()
		draw_rect(Rect2(c.x - 6.0, c.y - 1.5, 12.0, 3.0), ink)
		if step == 1:
			draw_rect(Rect2(c.x - 1.5, c.y - 6.0, 3.0, 12.0), ink)
		if pressed:
			PressFx.shade(self, r)
			draw_set_transform(Vector2.ZERO)
