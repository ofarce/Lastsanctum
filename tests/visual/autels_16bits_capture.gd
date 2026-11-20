extends Node
## Capture des quatre autels 16 bits (tools/autels-16bits) dans la salle :
## rangée du haut au repos (personne ne prie), rangée du bas en prière (un adepte du culte en prière).
## godot --path . res://tests/visual/autels_16bits_capture.tscn
const OUT := "res://tests/visual/out/autels_16bits/"
const MAIN = preload("res://main/main.tscn")
const GODS := ["aether", "indra", "medeina", "sigil"]

var _vp: SubViewport
var _world: World


func _process(_d: float) -> void:
	if _world:
		_world.camera.set_view(Vector2(-2, -109), 4)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(1500, 900)
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
	eng.x = -30.0
	eng.z = -100.0
	eng.tx = eng.x
	eng.tz = eng.z
	GameState.portal_start = -100
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	GameState.sim_time = 31.7
	for row in 2:
		for k in GODS.size():
			var b := Building.create(row * 10 + k, GODS[k], -20.0 + k * 12.0, -118.0 + row * 14.0)
			b.complete = true
			b.finished_at = -10.0
			GameState.buildings.append(b)
			if row == 1:
				var u := sim.spawn("Adepte", b.x, b.z + b.half() + 1.0, GODS[k])
				u.job = {"type": "pray", "temple": b}
				u.tx = u.x
				u.tz = u.z
				u.working = true
	world.camera.input_enabled = false
	_world = world
	world.wind_scale = 0
	world.finish_painting()
	(main.get_node("Hud") as Hud).hide_notice()
	await get_tree().create_timer(1.4).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "salle.png"))
	get_tree().quit()
