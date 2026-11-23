extends "res://tests/econ_case.gd"


func test_hover_requires_seal_selected_visible_engineer_and_valid_rock() -> void:
	var sim := game()
	sim.world.dig_cell(15, -35)
	engineer().x = 62.0
	engineer().z = -138.0
	sim.world.fog.refresh(sim.state())
	var input: InputController = sim.get_node("../Input")
	input.world.camera.set_view(Vector2(66, -138), 2)
	var pointer := input.project(66, 0, -138)
	GameState.selected = [engineer()]
	check(input.mining_hover_cell(pointer) == null, "sceau nécessaire même avec armure")
	GameState.mining_seal = true
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
	sim.world.dig_cell(15, -35)
	engineer().x = 62.0
	engineer().z = -138.0
	sim.world.fog.refresh(sim.state())
	var input: InputController = sim.get_node("../Input")
	input.world.camera.set_view(Vector2(66, -138), 2)
	GameState.selected = [engineer()]
	GameState.mining_seal = true
	var pointer := input.project(66, 0, -138)
	check(input.mining_hover_cell(pointer) != null, "survol initial")
	input.world.camera.set_view(Vector2(0, -138), 2)
	check(input.mining_hover_cell(pointer) == null, "caméra déplacée sans mouvement souris")
	input.world.camera.set_view(Vector2(66, -138), 2)
	input.world.dig_cell(16, -35)
	check(input.mining_hover_cell(pointer) == null, "case minée : plus de surbrillance")
	sim.new_game(SEED)
	check(input.mining_hover_cell(pointer) == null, "nouvelle partie : survol désactivé")


## Case de roche rognée par une galerie (centre creux, roche peinte sur une partie de son emprise) : le
## pointeur posé sur sa roche la désigne (avant, seul le centre comptait et elle restait impossible à viser).
func test_partial_rock_cell_is_pointable() -> void:
	var sim := game()
	var st := sim.state()
	var found: Variant = null
	for j in range(-100, -30):
		for i in range(-60, 60):
			if found != null:
				break
			if st.rock_cell(i, j) or not st.minable_block(i, j) or st.faced_cell(i, j - 1) or st.faced_cell(i, j + 1):
				continue
			for a in 4:
				for b in 4:
					var p := Vector2(i * 4.0 + a + 0.5, j * 4.0 + b + 0.5)
					if found == null and not st.ground(p.x, p.y) and st.dig_cell_at(i, j, p) != null:
						found = {"key": Vector2i(i, j), "p": p}
	check(found != null, "une case rognée minable existe dans le Temple")
	if found == null:
		return
	var cell: Variant = st.pointed_cell(found["p"])
	check(cell != null, "roche rognée désignable")
	if cell != null:
		check_eq(Vector2i(cell["i"], cell["j"]), found["key"], "c'est bien la case rognée qui est visée")
