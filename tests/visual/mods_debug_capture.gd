extends Node
## Bouton de debug « Donner les 15 mods » : menu DEBUG déplié, puis paquetage après le clic.
## godot --path . res://tests/visual/mods_debug_capture.tscn  →  tests/visual/out/mods_debug/
const OUT := "res://tests/visual/out/mods_debug/"
const MAIN = preload("res://main/main.tscn")
var _vp: SubViewport


func _shot(name: String) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main := MAIN.instantiate()
	_vp.add_child(main)
	main.get_node("Simulation").paused = true
	GameState.opening_stage = ""
	var eng := Capsule.engineer()
	eng.hidden = false
	var hud: Node = null
	for n in main.find_children("*", "", true, false):
		if n.has_method("_give_mods"):
			hud = n
	hud._set_debug_open(true)
	await _shot("menu")
	var b: Button = hud.find_child("ModsGive", true, false)
	b.pressed.emit()
	var packed := eng.inventory.filter(func(s: Dictionary) -> bool: return not s.is_empty()).size()
	var net := GameState.base_inventory.filter(func(s: Dictionary) -> bool: return not s.is_empty() and String(s["item"]).begins_with("module_")).size()
	print("paquetage ", packed, " · réseau ", net)
	hud._set_debug_open(false)
	await _shot("paquetage")
	get_tree().quit()
