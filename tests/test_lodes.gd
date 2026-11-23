extends "res://tests/econ_case.gd"
## Filons illimités : 2 × 2 cases au sol comme les bosquets, un par clairière, ne s'épuisent jamais.

const Blocks := preload("res://data/mineable_blocks.gd")


func test_lodes_generated() -> void:
	var st := TerrainState.new()
	for map_seed in [0, 1, 17, SEED]:
		st.generate_galleries(map_seed)
		# Temple (biome 1) : cuivre seul ; le fer et l'or n'ont de filons que plus au nord.
		check(st.lodes.values().has("copper"), "filon de cuivre, graine %d" % map_seed)
		# Filons de pierre illimités de la jungle (2026-11-22, JUNGLE_STONE_LODES) : à part, hors minerais.
		var stone := st.lodes.keys().filter(func(o: Vector2i) -> bool: return st.lodes[o] == "rock")
		check_eq(stone.size(), TerrainState.JUNGLE_STONE_LODES.size(), "filons de pierre de la jungle, graine %d" % map_seed)
		for o: Vector2i in stone:
			st.lodes.erase(o)
		for o: Vector2i in st.lodes:
			if CaveShape.in_start(o.x * 4.0 + 4.0, o.y * 4.0 + 4.0):
				check_eq(st.lodes[o], "copper", "filon de la zone d'origine, graine %d" % map_seed)
		check_eq(st.lode_cells.size(), (st.lodes.size() + stone.size()) * 4, "2 × 2 cases par filon")
		for o: Vector2i in st.lodes:
			var item: String = st.lodes[o]
			check(["copper", "iron", "gold"].has(item), "minerai dessiné : %s" % item)
			var c := Vector2(o * 4) + Vector2(4, 4)
			check(not st.walkable(c.x, c.y), "infranchissable")
			var band: Vector2 = st.ORE_BANDS[Blocks.ORES.find(item)]
			# Paliers autour de l'Ancre : zone d'origine, hors salles de ressources du Temple (posées par salle).
			if CaveShape.in_start(c.x, c.y) and st.temple_room(c.x, c.y).is_empty():
				check(c.distance_to(CaveShape.CORE) > band.x - 32.0 and c.distance_to(CaveShape.CORE) < band.y + 32.0, "dans le palier du %s" % item)
			for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 1)]:
				check(st.permanent_ores.has(o + d) and st.block_types[o + d] == item, "case inépuisable")
