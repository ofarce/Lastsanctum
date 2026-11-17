extends "res://tests/econ_case.gd"


func test_generation_bands_and_safe_start() -> void:
	var st := TerrainState.new()
	for map_seed in [0, 1, 17, 12345, SEED, 4294967295]:
		st.generate_galleries(map_seed)
		var counts := [0, 0, 0, 0]
		for key: Vector2i in st.block_types:
			# Bosquets et filons illimités au sol : couverts par test_wood et test_lodes.
			if st.block_types[key] == st.Blocks.WOOD or st.lode_cells.has(key):
				continue
			var tier := st.Blocks.ORES.find(st.block_types[key])
			counts[tier] += 1
			var center := Vector2(key * 4) + Vector2(2, 2)
			var distance := center.distance_to(CaveShape.CORE)
			var band: Vector2 = st.ORE_BANDS[tier]
			check(distance >= band.x and distance <= band.y, "distance du minerai")
			for dx in 5:
				for dz in 5:
					check(not CaveShape.in_cave(key.x * 4 + dx, key.y * 4 + dz), "salle initiale vide")
		check(counts[0] > counts[1] and counts[1] > counts[2] and counts[2] > counts[3] and counts[3] > 0, "abondance par graine %d : %s" % [map_seed, counts])
		check_eq(st.block_types.get(st.VAULT_COPPER), "copper", "cuivre garanti")


func test_repeated_vault_mining_and_solid_ore_drop() -> void:
	var sim := game()
	var st := sim.state()
	var key := st.VAULT_COPPER
	var center := Vector2(key * 4) + Vector2(2, 2)
	check(st.diggable_cell(center) == null, "gisement scellé")
	sim.world.dig_cell(14, -37)
	sim.world.dig_cell(15, -37)
	var u := engineer()
	GameState.selected = [u] as Array[Unit]
	GameState.base_inventory_unlocked = true
	u.x = center.x + 2.6
	u.z = center.y
	check(sim.order_adepts(center), "clic sur le gisement découvert")
	sim.update_adepts(2.0)
	check_eq(GameState.base_inventory, [{"item": "copper", "quantity": 2}], "deux récoltes")
	sim.world.dig_cell(key.x, key.y)
	check(not st.dug.has(key) and u.job != null, "gisement intact et travail continu")
	var west := Vector2i(-17, -39)
	sim.world.dig_cell(west.x + 1, west.y)
	u.x = -63.4
	u.z = -154
	check(sim.order_adepts(Vector2(-66, -154)), "clic sur le bloc de cuivre")
	sim.update_adepts(1.0)
	check(st.dug.has(west), "bloc de cuivre détruit")
	check_eq(GameState.base_inventory[0]["quantity"], 3, "un cuivre pour le bloc")



func test_adepts_harvest_solid_copper_at_their_own_rate() -> void:
	var sim := game()
	var key := Vector2i(-17, -39)
	sim.world.dig_cell(key.x + 1, key.y)
	GameState.selected.clear()
	for role in ["indra", "aether"]:
		var u := Unit.new()
		u.role = role
		u.hp = 100.0
		GameState.units.append(u)
		GameState.selected.append(u)
	GameState.base_inventory_unlocked = true
	check(sim.order_adepts(Vector2(-66, -154)), "ordre collectif sur le cuivre")
	for u: Unit in GameState.selected:
		u.x = u.job["at"].x
		u.z = u.job["at"].y
	sim.update_adepts(1.5)
	check(GameState.base_inventory.is_empty(), "aucune récolte anticipée")
	sim.update_adepts(0.5)
	var aether: Unit = GameState.selected[1]
	check_eq(aether.carrying.get("item"), "copper", "Aether récolte à deux secondes")
	check(GameState.base_inventory.is_empty(), "le cuivre est en route")
	sim.update_adepts(2.0)
	check_eq(GameState.selected[0].carrying.get("item"), "copper", "Indra récolte à quatre secondes")
	for u: Unit in GameState.selected:
		u.x = CaveShape.CHEST_SPOT.x
		u.z = CaveShape.CHEST_SPOT.y
	sim.update_adepts(0.0)
	check_eq(Production.count_in(GameState.base_inventory, "copper"), 2, "les deux récoltes arrivent au coffre")
	check(not sim.state().dug.has(key) and not sim.state().dig_hits.has(key), "bloc intact")
