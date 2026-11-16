extends "res://tests/test_case.gd"
## Réserve du coffre antique : pièce scellée à l'est de la salle, ouverte en minant la paroi.


func _ops(state: TerrainState) -> TerrainOps:
	return TerrainOps.new(state, DecorRegistry.new())


func test_vault_sealed_until_wall_mined() -> void:
	var state := TerrainState.new()
	state.generate_galleries(20261114)
	var ops := _ops(state)
	var chest := CaveShape.CHEST
	check(CaveShape.in_vault(chest.x, chest.y), "coffre dans la réserve")
	check(CaveShape.in_vault(CaveShape.CHEST_SPOT.x, CaveShape.CHEST_SPOT.y), "point de l'Ingénieur dans la réserve")
	check(not state.walkable(chest.x, chest.y), "réserve scellée au départ")
	check(not state.hollow(chest.x, chest.y), "réserve invisible au départ")
	# Aucune galerie ne la recoupe, et la salle ne la touche pas : il faut miner.
	for z in range(int(CaveShape.VAULT_Z0), int(CaveShape.VAULT_Z1)):
		check(not state.is_gallery(CaveShape.VAULT_X0 - 0.5, z + 0.5) and not CaveShape.in_cave(CaveShape.VAULT_X0 - 3.5, z + 0.5), "paroi de roche z=%d" % z)
	# Case de bord de salle (mi-roche), creusable depuis la salle.
	var p := Vector2(56.0, -145.0)
	check(state.walkable(p.x, p.y), "Ingénieur dans la salle")
	check(state.dig_cell_at(14, -37, p) != null, "case de paroi creusable")
	ops.dig_cell(14, -37)
	check(not state.vault_open, "encore scellée après la première case")
	check(state.dig_cell_at(15, -37, Vector2(59.0, -146.0)) != null, "case de roche suivante creusable")
	ops.dig_cell(15, -37)
	check(state.vault_open, "ouverte en touchant la réserve")
	check(state.walkable(chest.x, chest.y) and state.walkable(CaveShape.CHEST_SPOT.x, CaveShape.CHEST_SPOT.y), "réserve praticable")
	check(state.walkable(63.9, -146.0) and state.walkable(64.1, -146.0), "passage sans arête de roche")
	check(not state.walkable(CaveShape.VAULT_X1 - 0.1, CaveShape.VAULT_Z0 + 0.1), "angle arrondi")
	check(not state.walkable(CaveShape.VAULT_X1 + 0.5, chest.y), "paroi est")
	state.reset_digging()
	check(not state.vault_open and not state.walkable(chest.x, chest.y), "nouvelle partie : scellée")


func test_vault_adjacency() -> void:
	check(TerrainState.cell_touches_vault(15, -37), "case accolée à l'ouest")
	check(TerrainState.cell_touches_vault(16, -40), "case accolée au nord")
	check(not TerrainState.cell_touches_vault(15, -40), "coin seul")
	check(not TerrainState.cell_touches_vault(17, -35), "tunnel de référence (z −140) à l'écart")
	check(not TerrainState.cell_touches_vault(14, -37), "case à deux cases")


func test_vault_reachable_from_cave() -> void:
	var state := TerrainState.new()
	state.generate_galleries(20261114)
	var ops := _ops(state)
	ops.dig_cell(14, -37)
	ops.dig_cell(15, -37)
	var pf := Pathfinder.new(state)
	# [] = ligne droite dégagée ; null = aucun chemin.
	check(pf.find_path(Vector2(40.0, -140.0), CaveShape.CHEST_SPOT) != null, "chemin de la salle au coffre")
	check(pf.find_path(Vector2(-30.0, -110.0), CaveShape.CHEST_SPOT) != null, "chemin depuis l'entrée de la salle")
	var sealed := TerrainState.new()
	sealed.generate_galleries(20261114)
	check(Pathfinder.new(sealed).find_path(Vector2(40.0, -140.0), CaveShape.CHEST_SPOT + Vector2(0, -3)) == null \
		or not sealed.walkable(CaveShape.CHEST_SPOT.x, CaveShape.CHEST_SPOT.y), "scellée : inaccessible")
