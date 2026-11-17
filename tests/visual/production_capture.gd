extends Node
## Capture des bâtiments servis par des adeptes : Forge à l'arrêt (silhouette en pointillé du poste vide), puis
## Forge en marche (adeptes au poste, porteur avec sa caisse, coffre bleu qui s'ouvre, coffre rouge ouvert).
## godot --path . res://tests/visual/production_capture.tscn
const OUT := "res://tests/visual/out/production/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport


func _shot(name: String) -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(1200, 800)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main = MAIN.instantiate()
	_vp.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.new_game(20261114)
	sim.paused = true
	var eng: Unit = GameState.units[0]
	eng.hidden = false
	eng.x = 0.0
	eng.z = -130.0
	eng.tx = eng.x
	eng.tz = eng.z
	GameState.portal_start = -100
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	GameState.sim_time = 30.0
	var b := Building.create(0, "forge", 26.0, -112.0)
	b.complete = true
	b.finished_at = -10.0
	GameState.buildings.append(b)
	world.camera.input_enabled = false
	world.camera.set_view(Vector2(26, -106), 4)
	world.wind_scale = 0
	world.finish_painting()
	(main.get_node("Hud") as Hud).hide_notice()
	await _shot("1_arret")
	b.recipe = "copper_ingot"
	var crew: Array[Unit] = []
	for i in 3:
		var u := sim.spawn("Adepte d’Aether", b.x, b.z, "aether")
		u.job = {"type": "staff", "building": b, "post": "worker", "step": "post"}
		crew.append(u)
	for k in crew.size():
		var p := Production.post_spot(b, k)
		crew[k].x = p.x
		crew[k].z = p.y
		crew[k].tx = p.x
		crew[k].tz = p.y
		crew[k].working = true
	var porter := crew[2]
	porter.job["step"] = "return"
	porter.carrying = {"item": "copper", "quantity": 5}
	porter.x = Production.chest_pos(b, "in").x - 2.5
	porter.z = Production.chest_pos(b, "in").y + 2.0
	Production.put_into(b.output_box, "copper_ingot", 3)
	b.chest_in_at = GameState.sim_time - 0.3
	b.chest_out_at = GameState.sim_time - 0.3
	(main.get_node("Hud") as Hud).hide_notice()
	await _shot("2_marche")
	get_tree().quit()
