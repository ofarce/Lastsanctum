extends Node
## Capture : roche du Temple et roche de vert-de-gris de part et d'autre de la frontière des biomes (texture par
## palier, parois, sol teinté), et cadre de minage rouge sur la roche scellée (Sceau de cuivre manquant).
const OUT := "res://tests/visual/out/roches/"
const MAIN = preload("res://main/main.tscn")
class Pin extends Node:
	var camera: Node
	var at: Vector2
	func _process(_d: float) -> void:
		camera.set_view(at, 3)


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
	var front := floori(Biomes.north_z(0) / 4.0)  # première rangée du Temple ; front − 1 est en vert-de-gris
	# Colonne de roche pleine sur 5 × 10 cases autour de la frontière.
	var ci := 0
	for i in range(-60, 60):
		var full := true
		for a in range(-1, 5):
			for j in range(front - 6, front + 5):
				full = full and st.minable_block(i + a, j) and not st.block_types.has(Vector2i(i + a, j))
		if full:
			ci = i
			break
	for j in range(front - 4, front + 3):
		world.dig_cell(ci, j)
	for a in range(1, 4):
		world.dig_cell(ci + a, front + 1)
		world.dig_cell(ci + a, front - 3)
	eng.x = ci * 4.0 + 2.0
	eng.z = (front - 1) * 4.0 + 2.0
	eng.tx = eng.x
	eng.tz = eng.z
	GameState.selected = [eng]
	world.camera.input_enabled = false
	world.camera.set_view(Vector2(ci * 4.0 + 8.0, front * 4.0 - 2.0), 3)
	world.wind_scale = 0
	world.finish_painting()
	# Voile du brouillard masqué : la capture montre aussi la roche hors de vue.
	for layer: Node in world.get_children():
		if layer is CanvasLayer and (layer as CanvasLayer).layer == 3:
			(layer as CanvasLayer).visible = false
	(main.get_node("Hud") as Hud).hide_notice()
	print("colonne ", ci, " frontière rangée ", front, " · sceau requis nord « ", st.seal_needed(ci, front - 5), " » sud « ", st.seal_needed(ci + 2, front), " »")
	await get_tree().create_timer(0.8).timeout
	# Une séquence d'ouverture déplace encore la caméra : un nœud traité en dernier la recale à chaque image.
	var pin := Pin.new()
	pin.camera = world.camera
	pin.at = Vector2(ci * 4.0 + 8.0, front * 4.0 - 2.0)
	pin.process_priority = 1000
	add_child(pin)
	await get_tree().create_timer(0.5).timeout
	var input: InputController = main.get_node("Input")
	get_window().mouse_entered.emit()
	var k := 0
	# Paroi scellée au fond du boyau, puis paroi du Temple au-dessus de la branche sud.
	var north := Vector2(ci * 4 + 2, (front - 5) * 4 + 3)
	for j in range(front - 1, front - 7, -1):
		for i in range(ci - 6, ci + 8):
			var p := Vector2(i * 4 + 2, j * 4 + 3)
			if north.y > (front - 5) * 4 and st.seal_needed(i, j) != "" and st.faced_cell(i, j) and world.fog.visible_at(p) \
					and input.mining_hover_cell(world.camera.project(p.x, 0, p.y)) != null:
				north = p
				north.y -= 100.0
	north.y += 100.0
	for target: Vector2 in [north, Vector2(ci * 4 + 10, front * 4 + 3)]:
		world.camera.set_view(Vector2(ci * 4.0 + 8.0, front * 4.0 - 2.0), 3)
		await get_tree().process_frame
		var motion := InputEventMouseMotion.new()
		motion.position = world.camera.project(target.x, 0, target.y)
		motion.global_position = motion.position
		viewport.warp_mouse(motion.position)
		viewport.push_input(motion, true)
		await get_tree().create_timer(0.3).timeout
		print("caméra ", world.camera.cam, " exilé ", eng.pos(), " visible ", world.fog.visible_at(target))
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "roches_%d.png" % k))
		print("survol ", k, " ", input._mining_hover.cell)
		k += 1
	# Clic droit sur la roche scellée : aucune tâche de minage.
	var sealed: Variant = st.dig_cell_at(ci, front - 5, eng.pos())
	if sealed != null:
		sim.set_job(eng, {"type": "dig", "cells": [sealed], "index": 0, "cell": sealed, "at": sealed["at"]})
	print("tâche après ordre sur roche scellée : ", eng.job)
	get_tree().quit()
