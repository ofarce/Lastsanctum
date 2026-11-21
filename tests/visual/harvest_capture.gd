extends Node
## Récolte lisible des esprits (sim/harvest_fx.gd, planche « Effets de récolte ») : Indra sur un bloc de roche,
## Aether sur un filon illimité, Medeina sur un bosquet ; une rafale de captures par récolte.
## godot --path . res://tests/visual/harvest_capture.tscn
const OUT := "res://tests/visual/out/harvest/"
const MAIN = preload("res://main/main.tscn")

var _vp: SubViewport
var sim: Simulation
var world: World


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	load("res://sim/simulation.gd").play_opening = false
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 800)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var main = MAIN.instantiate()
	_vp.add_child(main)
	sim = main.get_node("Simulation")
	world = main.get_node("World")
	sim.new_game(20261114)
	GameState.sim_time = 30.0
	world.camera.input_enabled = false
	(main.get_node("Hud") as CanvasLayer).visible = false
	var ts: TerrainState = world.terrain_state
	var grove: Vector2i = ts.wood_left.keys().filter(func(k: Vector2i) -> bool:
		return (Vector2(k * 4) + Vector2(4, 4)).distance_to(ts.START_GROVE_AT) < 16.0)[0]
	var gc := Vector2(grove * 4) + Vector2(4, 4)
	await _run("grove", "medeina", gc + Vector2(9, 4), [sim.grove_cell(grove)], gc)
	var lode: Vector2i = ts.lodes.keys()[0]
	var lc := Vector2(lode * 4) + Vector2(4, 4)
	if not ts.ground(lc.x, lc.y + 6):
		world.terrain_ops.reveal_galleries_near(lc.x - 6, lc.y - 6, lc.x + 6, lc.y + 6)
	await _run("lode", "aether", lc + Vector2(8, 3), [ts.dig_cell_at(lode.x + 1, lode.y + 1, lc + Vector2(8, 3))], lc)
	# Bloc de roche : la première case de roche creusable au nord d'un sol dégagé, près du bosquet de départ.
	var cell: Variant = null
	for r in range(2, 8):
		for dx in range(-r, r + 1):
			var k := Vector2i(floori(gc.x / 4.0) + dx, floori(gc.y / 4.0) + r)
			var d := ts.block_definition(k.x, k.y)
			if d.is_empty() or d["drop_item"] != "rock" or ts.grove_cells.has(k) or ts.lode_cells.has(k) or ts.dug.has(k):
				continue
			if not ts.ground(k.x * 4.0 + 2.0, k.y * 4.0 + 6.0):
				continue
			cell = ts.dig_cell_at(k.x, k.y, Vector2(k.x * 4.0 + 2.0, k.y * 4.0 + 6.0))
			if cell != null:
				break
		if cell != null:
			break
	if cell != null:
		var bc := Vector2(cell["i"] * 4.0 + 2.0, cell["j"] * 4.0 + 2.0)
		await _run("block", "indra", bc + Vector2(3, 5), [cell], bc)
	else:
		print("aucun bloc de roche trouvé")
	get_tree().quit()


func _run(tag: String, role: String, at: Vector2, cells: Array, look: Vector2) -> void:
	var u := sim.spawn("Adepte", at.x, at.y, role)
	GameState.selected = [u] as Array[Unit]
	GameState.units[0].x = look.x - 9.0
	GameState.units[0].z = look.y + 7.0
	world.camera.set_view(look, 4)
	world.finish_painting()
	world.fog.refresh(world.terrain_state)
	print(tag, " ordre ", sim.order_mining_cells(cells), " cellule ", cells[0])
	sim.paused = false
	await get_tree().create_timer(3.0).timeout
	for i in 16:
		world.camera.set_view(look, 4)
		await get_tree().create_timer(0.18).timeout
		await _shot("%s_%02d" % [tag, i])
	print(tag, " travaille ", u.working, " porte ", u.carrying, " job ", u.job)
	await get_tree().create_timer(5.0).timeout
	await _shot("%s_later" % tag)
	print(tag, " plus tard porte ", u.carrying)
	u.hp = 0.0
	u.hidden = true
	GameState.selected = [] as Array[Unit]
