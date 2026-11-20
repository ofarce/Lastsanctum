extends Node
## Capture : surbrillance du Sceau de minage (incarné) sur un mur : bas de la paroi, haut de la paroi, dessus, pied.
const OUT := "res://tests/visual/out/wall_hover/"
const MAIN = preload("res://main/main.tscn")
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var main = MAIN.instantiate()
	viewport.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.new_game(20261114)
	sim.paused = true
	var eng: Unit = GameState.units[0]
	eng.hidden = false
	GameState.portal_start = -100
	GameState.mining_seal = true
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	var st := sim.state()
	var spot := Vector2.INF
	var ci := 0
	var cj := 0
	for j in range(-45, -20):
		for i in range(-15, 15):
			var p := Vector2(i * 4.0 + 2.0, j * 4.0 + 4.6)
			if st.dig_cell_at(i, j, p) != null and st.walkable(p.x, p.y) and st.minable_block(i, j - 1) and st.walkable(p.x, p.y + 4.0):
				spot = p
				ci = i
				cj = j
				break
		if spot != Vector2.INF:
			break
	eng.x = spot.x
	eng.z = spot.y + 6.0
	eng.tx = eng.x
	eng.tz = eng.z
	GameState.incarnated = eng
	GameState.selected = [eng]
	world.camera.input_enabled = false
	world.camera.set_view(spot, 3)
	world.wind_scale = 0
	world.finish_painting()
	(main.get_node("Hud") as Hud).hide_notice()
	print("cell ", ci, ",", cj, " spot ", spot)
	await get_tree().create_timer(0.6).timeout
	var input: InputController = main.get_node("Input")
	get_window().mouse_entered.emit()
	var k := 0
	for target: Vector2 in [Vector2(ci * 4 + 2, cj * 4 + 3), Vector2(ci * 4 + 2, cj * 4 - 1), Vector2(ci * 4 + 2, cj * 4 - 4), Vector2(ci * 4 + 2, cj * 4 + 4.3)]:
		var motion := InputEventMouseMotion.new()
		motion.position = world.camera.project(target.x, 0, target.y)
		motion.global_position = motion.position
		viewport.warp_mouse(motion.position)
		viewport.push_input(motion, true)
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "wall_%d.png" % k))
		print("hover ", k, " ", input._mining_hover.cell, " ptr ", motion.position)
		k += 1
	get_tree().quit()
