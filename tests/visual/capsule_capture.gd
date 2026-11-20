extends Node
## Captures de la capsule : éteinte, trait d'énergie en course, allumée avec invite.
## godot --path . res://tests/visual/capsule_capture.tscn
const OUT := "res://tests/visual/out/capsule/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport


func _shot(name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(960, 600)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main := MAIN.instantiate()
	_vp.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.paused = true
	var eng := Capsule.engineer()
	eng.hidden = false
	eng.x = 4.0
	eng.z = -156.0
	GameState.sim_time = 30.0
	GameState.opening_stage = "day1"
	world.camera.set_view(Vector2(0, -159), 3)
	await _shot("1_eteinte")
	GameState.orb_active = true
	GameState.opening_stage = "link"
	GameState.opening_at = GameState.sim_time - Opening.LINK_LEN * 0.55
	await _shot("2_trait")
	GameState.opening_stage = "awake"
	GameState.capsule_on = true
	GameState.opening_at = GameState.sim_time - 2.0
	eng.z = -163.0
	await _shot("3_allumee")
	# Bannière 16 bits : objets reçus, puis dialogue au-dessus d'une notification.
	var hud: Hud = main.get_node("Hud")
	eng.x = 0.0
	eng.z = -163.0
	Capsule.toggle(sim)
	await _shot("4_banniere_recu")
	Capsule.toggle(sim)
	hud.dialogue.show_dialogue({"speaker": eng, "name": "Ingénieur", "compact": false, "lines": ["Ah. Elle est là. Au travail."]})
	hud.dialogue.advance()
	sim.say("L’Ancre s’éveille !", 3.0)
	await _shot("5_dialogue_et_notice")
	# Incarné : barre de vie en bas, tir vers le sud puis vers le nord.
	hud.dialogue.close()
	hud.hide_notice()
	ExileGallery.incarnate(eng)
	eng.x = 4.0
	eng.z = -158.0
	world.camera.set_view(eng.pos(), 3)
	eng.aim_dir = Vector2(0, 1)
	eng.sh_t0 = GameState.sim_time - 0.05
	await _shot("6_incarne_tir_sud")
	eng.aim_dir = Vector2(0, -1)
	eng.sh_t0 = GameState.sim_time - 0.05
	await _shot("7_incarne_tir_nord")
	get_tree().quit()
