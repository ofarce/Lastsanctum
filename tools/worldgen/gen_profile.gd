extends Node
## Profil de TerrainState.generate_galleries, étape par étape (même suite d'appels) :
## godot --headless --path . res://tools/worldgen/gen_profile.tscn
var _t := 0
var st: TerrainState
func lap(name: String) -> void:
	var now := Time.get_ticks_usec()
	var j0 := int(-744.0 - CaveShape.WORLD_Z0)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(st.mask.slice(j0 * TerrainState.GAL_W))
	print("%-28s %7.1f ms  %s" % [name, (now - _t) / 1000.0, ctx.finish().hex_encode().left(12)])
	_t = Time.get_ticks_usec()

func _ready() -> void:
	st = TerrainState.new()
	var new_seed := 20261114
	var t0 := Time.get_ticks_usec()
	_t = t0
	st.seed = new_seed
	var r := Rng.new(new_seed)
	st._band_limits(0)
	st.frontier = false
	st.eye_gate.clear()
	st.pylon_cells.clear()
	st.theme_rooms.clear()
	st.mask.fill(0)
	st.open.fill(0)
	lap("vidage")
	var n := 12 + floori(r.next() * 5.0)
	for g in n:
		var x := 0.0
		var z := 0.0
		for t in 200:
			x = CaveShape.START_X0 + 14.0 + r.next() * (TerrainState.START_W - 28)
			z = CaveShape.START_Z0 + 14.0 + r.next() * (TerrainState.START_H - 28)
			if TerrainState.gallery_allowed(x, z):
				break
		var direction := floori(r.next() * 4.0)
		var steps := 34 + floori(r.next() * 46.0)
		var radius := 2.1 + r.next() * 1.4
		st._worm(r, x, z, direction, steps, radius, TerrainState.START_WORM)
	lap("vers d'origine")
	var r2 := Rng.new(new_seed ^ 0xe7e7)
	var base := floori(r2.next() * 1e9)
	st._ext = true
	for k in Biomes.LIST.size():
		st._band_limits(k)
		var bb: Dictionary = Biomes.LIST[k]
		var rb := Rng.new(base ^ (k * 7919 + 1))
		var area := st._ext_area(k)
		var nn := floori(area / 100000.0 * float(bb["worms"]) * (0.85 + rb.next() * 0.3))
		print("bande ", k, " aire ", area, " vers ", nn, " zmin ", st._zmin, " zmax ", st._zmax)
		var steps: Array = bb["steps"]
		var radius: Array = bb["radius"]
		for g in nn:
			var p: Variant = st._ext_spot(rb, k, 14.0)
			if g < 2:
				print("  point ", p)
			if p == null:
				continue
			var direction := floori(rb.next() * 4.0)
			var stp := int(steps[0]) + floori(rb.next() * float(int(steps[1]) - int(steps[0])))
			var rad := float(radius[0]) + rb.next() * (float(radius[1]) - float(radius[0]))
			st._worm(rb, p.x, p.y, direction, stp, rad, {})
		lap("bande %d" % k)
	st._ext = false
	st._band_limits(0)
	st._clearings.clear()
	st.river = River.new(new_seed)
	st.road = Road.new(new_seed, st.river)
	st.flora = Flora.new(new_seed, st.river, st.road)
	lap("rivière, route, flore")
	st._carve_clearings(Rng.new(new_seed ^ 0x5eed))
	lap("clairières")
	st._carve_lode_clearings(Rng.new(new_seed ^ 0x10de))
	lap("clairières de filon")
	st._carve_pools(Rng.new(new_seed ^ 0x9001))
	lap("bassins")
	st._carve_extension_features(new_seed)
	lap("traits de l'extension")
	st._carve_gorge_room(Rng.new(new_seed ^ 0x60c6))
	st._carve_frontier()
	lap("gorge + frontière")
	st._label_networks()
	lap("réseaux")
	st.pylon_cells.clear()
	st.theme_rooms.clear()
	st.link_cells.clear()
	st.path_d = PackedInt32Array()
	st._connect_networks()
	lap("raccords")
	st._place_pylons()
	lap("pylônes")
	st._carve_theme_rooms(Rng.new(new_seed ^ 0x5a2c))
	lap("salles à thème")
	st._compute_path_d()
	lap("distances de chemin")
	st._generate_ores()
	lap("minerais")
	print("total %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	get_tree().quit()
