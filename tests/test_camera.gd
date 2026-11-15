extends "res://tests/test_case.gd"
## Étape 2 (v2) : comportement de la caméra (73b410f : frame, PAN, wheel, clampCam).


func _camera() -> WorldCamera:
	var cam := WorldCamera.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(cam)
	cam.set_view(WorldCamera.START, 2)
	return cam


func _mouse_button(button: MouseButton, pressed: bool, pos: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = pos
	return e


func _motion(pos: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.button_mask = MOUSE_BUTTON_MASK_RIGHT
	return e


func test_limits_and_zoom_range() -> void:
	var cam := _camera()
	cam.set_view(Vector2(500, -500), 9)
	check_eq(cam.cam, Vector2(202, -316), "limites de la caméra")
	check_eq(cam.px, 6, "zoom maximal")
	cam.set_view(Vector2(-500, 500), 0)
	check_eq(cam.cam, Vector2(-202, 44), "limites opposées")
	check_eq(cam.px, 1, "zoom minimal")
	cam.free()


func test_wheel_changes_px_by_one() -> void:
	var cam := _camera()
	cam._unhandled_input(_mouse_button(MOUSE_BUTTON_WHEEL_UP, true, Vector2.ZERO))
	check_eq(cam.px, 3, "molette vers le haut")
	cam._unhandled_input(_mouse_button(MOUSE_BUTTON_WHEEL_DOWN, true, Vector2.ZERO))
	cam._unhandled_input(_mouse_button(MOUSE_BUTTON_WHEEL_DOWN, true, Vector2.ZERO))
	check_eq(cam.px, 1, "molette vers le bas")
	cam.free()


func test_right_drag_threshold_and_direction() -> void:
	var cam := _camera()
	cam._unhandled_input(_mouse_button(MOUSE_BUTTON_RIGHT, true, Vector2(100, 100)))
	cam._unhandled_input(_motion(Vector2(103, 102)))
	check_eq(cam.cam, WorldCamera.START, "moins de 5 px : pas de déplacement")
	check_eq(cam.consume_drag(), false, "clic droit simple : reste un ordre")
	cam._unhandled_input(_mouse_button(MOUSE_BUTTON_RIGHT, true, Vector2(100, 100)))
	# Vue 3/4 : 16 px écran vers la droite à PX = 2 font 1 unité, la carte suit la souris (Δx = −1).
	cam._unhandled_input(_motion(Vector2(116, 100)))
	check_near(cam.cam.x, WorldCamera.START.x - 1.0, 1e-4, "Δx")
	check_near(cam.cam.y, WorldCamera.START.y, 1e-4, "Δz")
	cam._unhandled_input(_motion(Vector2(116, 132)))
	check_near(cam.cam.y, WorldCamera.START.y - 2.0, 1e-4, "Δz vers le bas")
	check_eq(cam.consume_drag(), true, "glisser détecté")
	check_eq(cam.consume_drag(), false, "indicateur remis à zéro")
	cam._unhandled_input(_mouse_button(MOUSE_BUTTON_RIGHT, false, Vector2(116, 132)))
	cam.free()


func test_keyboard_speed_is_10_units_per_second_with_dt_cap() -> void:
	var cam := _camera()
	Input.action_press("cam_right")
	cam._process(0.02)
	check_near(cam.cam.x, 0.2, 1e-5, "10 u/s")
	cam._process(0.5)
	check_near(cam.cam.x, 0.2 + 0.45, 1e-5, "pas plafonné à 0,045 s")
	Input.action_release("cam_right")
	Input.action_press("cam_up")
	cam._process(0.02)
	check_near(cam.cam.y, WorldCamera.START.y - 0.2, 1e-5, "Z/W/haut : z diminue")
	Input.action_release("cam_up")
	cam.free()
