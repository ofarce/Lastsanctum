extends "res://tests/test_case.gd"
## Étape 2 : générateurs, bruit et vent identiques au prototype (fixtures du baker).

const Fixtures := preload("res://tests/fixtures.gd")
# Tolérance 1e-12 : le JSON de Godot n'arrondit pas toujours au dernier bit les nombres à 17 chiffres.


func test_lcg_sequences() -> void:
	var f := Fixtures.load_json("rng")
	for seed: String in f["rng"]:
		var r := Rng.new(int(seed))
		for expected: float in f["rng"][seed]:
			check_near(r.next(), expected, 1e-12, "rng(%s)" % seed)
	var lcg := Rng.new(19653)
	for expected: float in f["lcg_19653"]:
		check_near(lcg.next(), expected, 1e-12, "seeded() 19653")


func test_hash_and_vnoise() -> void:
	var f := Fixtures.load_json("noise")
	check_eq(f["samples"].size(), 50, "échantillons")
	for s: Dictionary in f["samples"]:
		var x: float = s["x"]
		var y: float = s["y"]
		check_near(Rng.hash3(floori(x), floori(y), int(s["seed"])), s["hash"], 1e-12, "hash(%s, %s, %s)" % [floori(x), floori(y), s["seed"]])
		check_near(Rng.vnoise(x, y, int(s["seed"])), s["vnoise"], 1e-12, "vnoise(%s, %s)" % [x, y])


func test_wind() -> void:
	var f := Fixtures.load_json("wind")
	check_eq(f["samples"].size(), 50, "échantillons")
	for s: Dictionary in f["samples"]:
		check_near(Wind.at(s["x"], s["z"], s["t"]), s["v"], 1e-6, "windAt(%s, %s, %s)" % [s["x"], s["z"], s["t"]])
