extends "res://tests/econ_case.gd"
## Filons illimités : 2 × 2 cases au sol comme les bosquets, un par clairière, ne s'épuisent jamais.

const Blocks := preload("res://data/mineable_blocks.gd")


func test_lodes_generated() -> void:
	var st := TerrainState.new()
	for map_seed in [0, 1, 17, SEED]:
		st.generate_galleries(map_seed)
		for item in ["copper", "iron", "gold"]:
			check(st.lodes.values().has(item), "filon de %s, graine %d" % [item, map_seed])
		check_eq(st.lode_cells.size(), st.lodes.size() * 4, "2 × 2 cases par filon")
		for o: Vector2i in st.lodes:
			var item: String = st.lodes[o]
			check(["copper", "iron", "gold"].has(item), "minerai dessiné : %s" % item)
			var c := Vector2(o * 4) + Vector2(4, 4)
			check(not st.walkable(c.x, c.y), "infranchissable")
			var band: Vector2 = st.ORE_BANDS[Blocks.ORES.find(item)]
			if CaveShape.in_start(c.x, c.y):  # paliers autour de l'Ancre : zone d'origine
				check(c.distance_to(CaveShape.CORE) > band.x - 32.0 and c.distance_to(CaveShape.CORE) < band.y + 32.0, "dans le palier du %s" % item)
			for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 1)]:
				check(st.permanent_ores.has(o + d) and st.block_types[o + d] == item, "case inépuisable")
