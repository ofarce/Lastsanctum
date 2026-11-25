extends Node
## Porte de l'Orbite aux deux veilleuses (planches/porte-boss-veilleuses.html) : deux gardiens, un seul, aucun.
##   godot --path . res://tests/visual/porte_veilleuses_capture.tscn
const OUT := "res://tests/visual/out/porte/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport


func _shot(name: String) -> void:
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _run(sim: Simulation, seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		var eng := Capsule.engineer()
		eng.hp = eng.max_hp
		sim.tick(1.0 / 60.0)


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
	GameState.opening_stage = ""
	GameState.in_capsule = false
	var eng := Capsule.engineer()
	eng.hidden = false
	ExileGallery.incarnate(eng)
	GameState.sim_time = 30.0
	var st := sim.state()
	_run(sim, 0.1)
	var door: Array = (st.door_cells.keys() as Array).filter(func(c: Vector2i) -> bool: return st.door_cells[c] == "mb2")
	var sum := Vector2.ZERO
	for c: Vector2i in door:
		sum += Vector2(c) * 4.0 + Vector2(2.0, 2.0)
	var dp := sum / float(door.size())
	print("porte mb2 : ", door, " fermée ", st.doors_closed, " praticable ", st.walkable(dp.x, dp.y), " mur ", st.room_walls.has(door[1]))
	eng.x = dp.x
	eng.z = dp.y + 9.0
	eng.tx = eng.x
	eng.tz = eng.z
	GameState.spawn_queue = []
	var r := OrbitGate.rills(st)
	for k in r:
		print("rigole ", k, " : ", (r[k] as PackedVector2Array).size(), " points, de ", r[k][0], " à ", r[k][r[k].size() - 1])
	_run(sim, 0.6)
	sim.paused = true
	world.camera.input_enabled = false
	world.wind_scale = 0
	world.fog.refresh(st)
	world.finish_painting()
	await _shot("0_deux")
	# L'Archiprêtre tombe : sa rigole s'éteint, sa flamme meurt.
	sim.paused = false
	RoomEncounters.open_door(sim, "mb1")
	GameState.archipretre["down_at"] = GameState.sim_time
	OrbitGate.guard_fell(sim)
	print("après l'Archiprêtre : mb2 fermée ", st.doors_closed["mb2"], " · ", OrbitGate.message(st))
	_run(sim, 2.6)
	sim.paused = true
	await _shot("1_chute")
	sim.paused = false
	_run(sim, 3.0)
	sim.paused = true
	await _shot("2_un")
	# La Martyre tombe : la porte s'ouvre.
	sim.paused = false
	GameState.martyre_state = "defeated"
	GameState.martyre_down_at = GameState.sim_time
	OrbitGate.guard_fell(sim)
	print("après la Martyre : mb2 fermée ", st.doors_closed["mb2"])
	_run(sim, 2.9)
	sim.paused = true
	await _shot("3_extinction")
	sim.paused = false
	_run(sim, 1.9)
	print("ouverture : mb2 fermée ", st.doors_closed["mb2"], " · praticable ", st.walkable(dp.x, dp.y))
	sim.paused = true
	await _shot("4_levee")
	sim.paused = false
	_run(sim, 3.0)
	sim.paused = true
	await _shot("5_ouverte")
	get_tree().quit()
