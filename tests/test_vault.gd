extends "res://tests/test_case.gd"
## Ancienne réserve du coffre antique, à l'est de la salle : depuis que le coffre est à côté de la capsule
## (2026-11-22, planches/intro-capsule-planche.html), miner sa paroi ne l'ouvre plus. Son volume reste réservé.


func _ops(state: TerrainState) -> TerrainOps:
	return TerrainOps.new(state, DecorRegistry.new())


func test_mining_the_wall_no_longer_opens_the_vault() -> void:
	var state := TerrainState.new()
	state.generate_galleries(20261114)
	var ops := _ops(state)
	check(not CaveShape.in_vault(CaveShape.CHEST.x, CaveShape.CHEST.y), "le coffre n'est plus dans la réserve")
	check(CaveShape.in_cave(CaveShape.CHEST.x, CaveShape.CHEST.y - 1.0), "le coffre est dans la salle")
	var p := Vector2(55.0, -146.0)
	check(state.dig_cell_at(14, -37, p) != null, "case de paroi creusable")
	ops.dig_cell(14, -37)
	ops.dig_cell(15, -37)
	check(not state.vault_open, "la réserve reste scellée")
	check(not state.hollow((CaveShape.VAULT_X0 + CaveShape.VAULT_X1) / 2.0, -150.0), "pas de salle creusée derrière")


func test_vault_adjacency() -> void:
	check(TerrainState.cell_touches_vault(15, -37), "case accolée à l'ouest")
	check(TerrainState.cell_touches_vault(16, -40), "case accolée au nord")
	check(not TerrainState.cell_touches_vault(15, -40), "coin seul")
	check(not TerrainState.cell_touches_vault(17, -35), "tunnel de référence (z −140) à l'écart")
	check(not TerrainState.cell_touches_vault(14, -37), "case à deux cases")
