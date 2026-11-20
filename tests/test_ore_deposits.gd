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
			# Paliers autour de l'Ancre : zone d'origine seulement (l'extension suit les biomes, test_biomes).
			if not CaveShape.in_start(key.x * 4.0, key.y * 4.0):
				continue
			var tier := st.Blocks.ORES.find(st.block_types[key])
			counts[tier] += 1
			var center := Vector2(key * 4) + Vector2(2, 2)
			var distance := center.distance_to(CaveShape.CORE)
			var band: Vector2 = st.ORE_BANDS[tier]
			check(distance >= band.x and distance <= band.y, "distance du minerai")
			# Intérieur de la case (ses bords touchent les cases voisines, qui peuvent être du sol de la salle).
			for dx in 4:
				for dz in 4:
					check(not CaveShape.in_cave(key.x * 4 + dx + 0.5, key.y * 4 + dz + 0.5), "salle initiale vide")
		# Le Temple (biome 1) ne porte que du cuivre : fer, quartz et or viennent des biomes suivants.
		check(counts[0] > 0 and counts[1] + counts[2] + counts[3] == 0, "cuivre seul dans le Temple, graine %d : %s" % [map_seed, counts])


func test_repeated_vault_mining_and_solid_ore_drop() -> void:
	var sim := game()
	var st := sim.state()
	# Gisement inépuisable : une case d'un filon au sol (le cuivre garanti de la réserve n'existe plus).
	var key: Vector2i = st.lodes.keys()[0]
	# Sa clairière est dans une galerie pas encore découverte : on les ouvre toutes.
	st.open = st.mask.duplicate()
	st.found = st.count
	st.version += 1
	var center := Vector2(key * 4) + Vector2(2, 2)
	var cell: Variant = st.diggable_cell(center)
	check(cell != null, "filon accessible")
	var u := engineer()
	GameState.selected = [u] as Array[Unit]
	GameState.base_inventory_unlocked = true
	u.x = cell["at"].x
	u.z = cell["at"].y
	check(sim.order_adepts(center), "clic sur le gisement découvert")
	sim.update_adepts(2.0)
	# L'Ingénieur donne ENGINEER_DIG × DIG_HITS coups par seconde ; une récolte par `resistance` coups.
	var harvests := int(2.0 * TerrainState.ENGINEER_DIG * TerrainState.DIG_HITS / float(st.block_definition(key.x, key.y)["resistance"]))
	check_eq(GameState.base_inventory, [{"item": "copper", "quantity": harvests}], "récoltes en deux secondes")
	sim.world.dig_cell(key.x, key.y)
	check(not st.dug.has(key) and u.job != null, "gisement intact et travail continu")
	var west := Vector2i(-17, -39)
	sim.world.dig_cell(west.x + 1, west.y)
	u.x = -63.4
	u.z = -154
	check(sim.order_adepts(Vector2(-66, -154)), "clic sur le bloc de cuivre")
	sim.update_adepts(1.0)
	check(st.dug.has(west), "bloc de cuivre détruit")
	check_eq(GameState.base_inventory[0]["quantity"], harvests + 1, "un cuivre pour le bloc")



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
	for i in 16:
		sim.update_adepts(1.0)
	for u: Unit in GameState.selected:
		check_eq(u.carrying.get("quantity"), 5, "lot de cinq minerais")
		u.x = CaveShape.CHEST_SPOT.x
		u.z = CaveShape.CHEST_SPOT.y
	sim.update_adepts(0.0)
	check_eq(Production.count_in(GameState.base_inventory, "copper"), 10, "les deux lots arrivent au coffre")
	check(not sim.state().dug.has(key) and not sim.state().dig_hits.has(key), "bloc intact")
