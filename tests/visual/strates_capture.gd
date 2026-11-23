extends Node
## Capture des six strates (biomes 3 à 8) : à chaque frontière, un boyau creusé de part et d'autre (dessus de
## roche, parois, sol teinté par palier), puis une veine de chaque nouveau minerai. Imprime roche, coups et sceau.
const OUT := "res://tests/visual/out/strates/"
const MAIN = preload("res://main/main.tscn")
class Pin extends Node:
	var camera: Node
	var at: Vector2
	func _process(_d: float) -> void:
		camera.set_view(at, 3)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1200, 760)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var t0 := Time.get_ticks_msec()
	var main = MAIN.instantiate()
	viewport.add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	var world: World = main.get_node("World")
	sim.new_game(20261114)
	print("nouvelle partie ms ", Time.get_ticks_msec() - t0)
	sim.paused = true
	var eng: Unit = GameState.units[0]
	GameState.portal_start = -100
	GameState.mining_seal = true
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	var st := sim.state()
	world.camera.input_enabled = false
	world.wind_scale = 0
	for layer: Node in world.get_children():
		if layer is CanvasLayer and (layer as CanvasLayer).layer == 3:
			(layer as CanvasLayer).visible = false
	(main.get_node("Hud") as Hud).hide_notice()
	var pin := Pin.new()
	pin.camera = world.camera
	pin.process_priority = 1000
	add_child(pin)
	var shots: Array = []
	for k in range(1, Biomes.LIST.size() - 1):
		var front := floori(Biomes.north_z(k) / 4.0)
		var ci := -999
		for i in range(-90, 90):
			var full := true
			for a in range(-1, 5):
				for j in range(front - 6, front + 5):
					full = full and st.minable_block(i + a, j) and not st.block_types.has(Vector2i(i + a, j))
			if full:
				ci = i
				break
		if ci == -999:
			print("frontière ", k, " : pas de colonne pleine")
			continue
		for j in range(front - 4, front + 3):
			world.dig_cell(ci, j)
		for a in range(1, 4):
			world.dig_cell(ci + a, front + 1)
			world.dig_cell(ci + a, front - 3)
		var sd := st.block_definition(ci + 2, front + 2)
		var nd := st.block_definition(ci + 2, front - 5)
		print("frontière ", Biomes.LIST[k]["id"], " → ", Biomes.LIST[k + 1]["id"], " · sud ", sd["material_name"], " ", sd["resistance"], " coups, sceau « ", sd.get("seal", ""),
			" » · nord ", nd["material_name"], " ", nd["resistance"], " coups, sceau « ", nd.get("seal", ""), " »")
		shots.append(["frontiere_%d" % k, Vector2(ci * 4.0 + 8.0, front * 4.0 - 2.0)])
	for ore: String in ["silver", "tear", "amber", "orichalcum"]:
		var best := Vector2i(9999, 9999)
		for key: Vector2i in st.block_types:
			if st.block_types[key] == ore and not st.block_types.has(key + Vector2i(0, 1)) and st.minable_block(key.x, key.y + 1):
				best = key
				break
		if best.x == 9999:
			print(ore, " : aucune veine")
			continue
		for j in range(best.y + 1, best.y + 4):
			world.dig_cell(best.x, j)
			world.dig_cell(best.x + 1, j)
		print(ore, " en ", best, " · biome ", Biomes.at(best.y * 4.0)["id"])
		shots.append([ore, Vector2(best.x * 4.0 + 4.0, best.y * 4.0 + 8.0)])
	world.finish_painting()
	for s: Array in shots:
		pin.at = s[1]
		eng.x = s[1].x
		eng.z = s[1].y + 6.0
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "%s.png" % s[0]))
	print("captures ", shots.size())
	get_tree().quit()
