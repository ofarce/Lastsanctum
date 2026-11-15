extends "res://tests/econ_case.gd"


func test_hover_requires_seal_selected_visible_engineer_and_valid_rock() -> void:
	var sim := game()
	var input: InputController = sim.get_node("../Input")
	input.world.camera.set_view(Vector2(66, -138), 2)
	var pointer := input.project(66, 0, -138)
	GameState.selected = [engineer()]
	check(input.mining_hover_cell(pointer) == null, "sceau nécessaire même avec armure")
	GameState.research_done["mining_artifact"] = true
	var cell: Variant = input.mining_hover_cell(pointer)
	check(cell != null, "case survolée détectée")
	if cell == null:
		return
	check_eq(Vector2i(cell["i"], cell["j"]), Vector2i(16, -35), "case réellement ciblée")
	check(input.mining_hover_cell(input.project(50, 0, -138)) == null, "sol non minable")
	check(input.mining_hover_cell(pointer, true) == null, "UI et glissement bloquent le survol")
	check(input.mining_hover_cell(Vector2(-1, -1)) == null, "hors écran")
	GameState.hud_mode = "build"
	check(input.mining_hover_cell(pointer) == null, "mode construction")
	GameState.hud_mode = ""
	engineer().hidden = true
	check(input.mining_hover_cell(pointer) == null, "ingénieur caché")
	engineer().hidden = false
	engineer().hp = 0
	check(input.mining_hover_cell(pointer) == null, "ingénieur mort")
	engineer().hp = 140
	GameState.selected.clear()
	check(input.mining_hover_cell(pointer) == null, "sans sélection")


func test_hover_updates_after_mining_camera_change_and_reset() -> void:
	var sim := game()
	var input: InputController = sim.get_node("../Input")
	input.world.camera.set_view(Vector2(66, -138), 2)
	GameState.selected = [engineer()]
	GameState.research_done["mining_artifact"] = true
	var pointer := input.project(66, 0, -138)
	check(input.mining_hover_cell(pointer) != null, "survol initial")
	input.world.camera.set_view(Vector2(0, -138), 2)
	check(input.mining_hover_cell(pointer) == null, "caméra déplacée sans mouvement souris")
	input.world.camera.set_view(Vector2(66, -138), 2)
	input.world.dig_cell(16, -35)
	check(input.mining_hover_cell(pointer) == null, "case minée : plus de surbrillance")
	sim.new_game(SEED)
	check(input.mining_hover_cell(pointer) == null, "nouvelle partie : survol désactivé")
