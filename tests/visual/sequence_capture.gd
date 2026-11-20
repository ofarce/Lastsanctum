extends Node
## Fonds en jeu pour la planche de la séquence d'ouverture (planches/sequence-ouverture-v2.html).
## godot --path . res://tests/visual/sequence_capture.tscn -- --shot=N
const OUT := "res://tests/visual/out/sequence/"
const MAIN = preload("res://main/main.tscn")
const SIZE := Vector2i(960, 600)
const SHOTS := [
	["ancre", Vector2(0, -157), Vector2(0, -146), 3],
	["porte", Vector2(0, -93), Vector2(0, -106), 3],
	["dehors", Vector2(0, -74), Vector2(0, -70), 3],
	["dehors_large", Vector2(0, -66), Vector2(0, -60), 2],
]
var _vp: SubViewport

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var only := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			only = int(arg.trim_prefix("--shot="))
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main = MAIN.instantiate()
	_vp.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.new_game(20261114)
	sim.paused = true
	GameState.sim_time = 30.0
	world.camera.input_enabled = false
	(main.get_node("Hud") as CanvasLayer).visible = false
	GameState.turrets.clear()  # sans les balistes de l'entrée
	var s: Array = SHOTS[only]
	var u = GameState.units[0]
	u.x = s[2].x
	u.z = s[2].y
	u.hidden = false
	world.camera.set_view(s[1], s[3])
	world.finish_painting()
	world.fog.reset_exploration()
	world.fog.refresh(world.terrain_state)
	await get_tree().create_timer(0.5).timeout
	u.hidden = true
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + s[0] + ".png"))
	var pts := {}
	var named := {"core": Vector3(0, 0, -154), "gate": Vector3(0, 0, -96), "gate_l": Vector3(-7, 0, -96), "gate_r": Vector3(7, 0, -96), "tunnel": Vector3(0, 0, -80), "path": Vector3(0, 0, -60), "spot": Vector3(s[2].x, 0, s[2].y), "l": Vector3(-20, 0, -60), "r": Vector3(20, 0, -60)}
	for k in named:
		var p: Vector3 = named[k]
		var v: Vector2 = world.camera.project(p.x, p.y, p.z)
		pts[k] = [v.x, v.y]
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT + s[0] + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"px": 3, "points": pts}))
	get_tree().quit()
