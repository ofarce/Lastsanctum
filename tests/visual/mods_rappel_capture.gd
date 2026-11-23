extends Node
## Ancre de rappel : touche G envoyée à l'Exilé incarné (retour à la capsule), puis G pendant la recharge.
## godot --path . res://tests/visual/mods_rappel_capture.tscn
const MAIN = preload("res://main/main.tscn")


func _key_g(ctrl: Node) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_G
	ev.pressed = true
	ctrl._unhandled_input(ev)


func _ready() -> void:
	var main := MAIN.instantiate()
	add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	sim.paused = true
	GameState.opening_stage = ""
	var eng := Capsule.engineer()
	eng.hidden = false
	GameState.in_capsule = false
	eng.x = -8.0
	eng.z = -150.0
	eng.equipment["Module 1"] = "module_anchor"
	ExileGallery.incarnate(eng)
	GameState.sim_time = 500.0
	GameState.incarnated_hurt_at = -INF
	var ctrl: Node = null
	for n in main.find_children("*", "", true, false):
		if n is InputController:
			ctrl = n
	var before := eng.pos()
	_key_g(ctrl)
	print("incarné ", GameState.incarnated == eng, " · parti de ", before, " · arrivé ", eng.pos(), " · capsule ", Capsule.EXIT,
		" · rappel ok ", eng.pos().distance_to(Capsule.EXIT) < 0.01)
	GameState.sim_time += 10.0
	_key_g(ctrl)
	print("recharge : ", GameState.banner_text if "banner_text" in GameState else "(bannière)")
	get_tree().quit()
