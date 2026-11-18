extends "res://tests/test_case.gd"
## Petite végétation de la jungle (world/flora/flora.gd) : génération par zones, piétinement, feu,
## repousse en trois vagues, rien sur l'eau, les ponts ni le chemin.

const SEED := 20261114


func _flora() -> Flora:
	return Flora.new(SEED, River.new(SEED))


func test_generation_is_varied_and_deterministic() -> void:
	var t0 := Time.get_ticks_usec()
	var f := _flora()
	print("     (%d plantes en %d ms)" % [f.plants.size(), (Time.get_ticks_usec() - t0) / 1000])
	var kinds := {}
	for p in f.plants:
		kinds[p["k"]] = kinds.get(p["k"], 0) + 1
	for k: String in ["bush", "thorn", "grass", "reed", "flowers", "moss", "stump", "log"]:
		check(kinds.get(k, 0) > 0, "au moins un « %s »" % k)
	check(f.plants.size() > 3000, "jungle fournie (%d plantes)" % f.plants.size())
	var g := _flora()
	check_eq(g.plants.size(), f.plants.size(), "même graine, même végétation")
	var zones := {}
	var x := -400.0
	while x < 400.0:
		var z := -60.0
		while z < 70.0:
			zones[f.zone_at(x, z)] = true
			z += 6.0
		x += 6.0
	check_eq(zones.size(), 5, "les cinq sous-zones existent")


func test_nothing_on_water_bridges_or_path() -> void:
	var f := _flora()
	var ok := true
	for p in f.plants:
		var x: float = p["x"]
		var z: float = p["z"]
		if f.river.water_at(x, z) or f.river.on_deck(x, z) or (absf(x) < 5.0 and z > -70.0) or z < CaveShape.mountain_edge(x):
			ok = false
	check(ok, "ni dans l'eau, ni sur un pont, ni sur le chemin, ni sur la montagne")
	var reeds := 0
	for p in f.plants:
		if p["k"] == "reed" and f.river.bank_distance(p["x"], p["z"]) < 2.0:
			reeds += 1
	check(reeds > 100, "roseaux le long des berges (%d)" % reeds)


func test_trample_burn_and_regrow() -> void:
	var f := _flora()
	var target := {}
	for p in f.plants:
		if p["k"] == "grass":
			target = p
			break
	var x: float = target["x"]
	var z: float = target["z"]
	for i in 64:
		f.trample(x, z, 0.05)
	check_eq(target["s"], 1, "3,2 s de passage : deux stades perdus")
	f.take_dirty()
	f.burn(x, z, 3.0)
	check(target["s"] == 0 and target["b"], "brûlée")
	check(not f.take_dirty().is_empty(), "changements signalés au rendu")
	f.regrow()
	check_eq(target["s"], 1, "une vague : pousse")
	f.regrow()
	f.regrow()
	check_eq(target["s"], 3, "trois vagues : repoussée")
	f.regrow()
	check_eq(target["s"], 3, "pas au-delà")


func test_building_clears_plants() -> void:
	var f := _flora()
	var p: Dictionary = f.plants[0]
	f.clear_rect(p["x"] - 1.0, p["z"] - 1.0, p["x"] + 1.0, p["z"] + 1.0)
	check_eq(p["k"], "gone", "retirée sous un bâtiment")
	f.regrow()
	check_eq(p["k"], "gone", "ne repousse pas sous un bâtiment")


func test_art_for_every_stage() -> void:
	for k: String in ["bush", "thorn", "grass", "reed", "flowers", "moss", "stump", "log"]:
		for s in 4:
			var t := FloraArt.texture(k, 1, s, s == 0)
			check(t != null and t.get_width() > 1, "sprite %s stade %d" % [k, s])
