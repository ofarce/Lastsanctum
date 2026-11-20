extends "res://tests/test_case.gd"
## Rng.hash3 optimisé (to_int32 développé sur place) : identique au bit près à la version d'origine,
## gardée ici comme référence, sur des entrées aléatoires de toutes grandeurs et des cas limites.


static func _ref_hash3(x: int, y: int, s: int) -> float:
	var h := Rng.to_int32(int(float(x) * 374761393.0 + float(y) * 668265263.0 + float(s) * 1442695041.0))
	h = h ^ ((h & 0xFFFFFFFF) >> 13)
	h = Rng.to_int32(int(float(Rng.to_int32(h)) * 1274126177.0))
	return float((h ^ ((h & 0xFFFFFFFF) >> 16)) & 0xFFFFFFFF) / Rng.TWO_32


static func _ref_vnoise(x: float, y: float, s: int) -> float:
	var xi := floori(x)
	var yi := floori(y)
	var xf := x - xi
	var yf := y - yi
	var u := xf * xf * (3.0 - 2.0 * xf)
	var v := yf * yf * (3.0 - 2.0 * yf)
	var a := _ref_hash3(xi, yi, s)
	var b := _ref_hash3(xi + 1, yi, s)
	var c := _ref_hash3(xi, yi + 1, s)
	var d := _ref_hash3(xi + 1, yi + 1, s)
	return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v


func test_hash3_identical_to_reference() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261118
	var bad := 0
	var first := ""
	var cases: Array[Vector3i] = []
	for v: int in [0, 1, -1, 2, -2, 7, 13, 255, 1023, -1024, 65535, -65536, 2147483647, -2147483648, 100000, -100000]:
		for w: int in [0, 1, -1, 17, -300, 65535]:
			cases.append(Vector3i(v, w, 0))
			cases.append(Vector3i(w, v, 9))
			cases.append(Vector3i(w, 3, v))
	for i in 200000:
		var span: int = [16, 1024, 100000, 2147483647][i % 4]
		cases.append(Vector3i(rng.randi_range(-span, span), rng.randi_range(-span, span), rng.randi_range(-span, span)))
	for c in cases:
		var a := Rng.hash3(c.x, c.y, c.z)
		var b := _ref_hash3(c.x, c.y, c.z)
		if a != b:
			bad += 1
			if first.is_empty():
				first = "%s : %.17f au lieu de %.17f" % [c, a, b]
	check(bad == 0, "hash3 identique sur %d entrées (%d écarts ; premier : %s)" % [cases.size(), bad, first])


func test_vnoise_identical_to_reference() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bad := 0
	for i in 50000:
		var x := rng.randf_range(-500.0, 500.0)
		var y := rng.randf_range(-500.0, 500.0)
		var s := rng.randi_range(0, 64)
		if Rng.vnoise(x, y, s) != _ref_vnoise(x, y, s):
			bad += 1
	check(bad == 0, "vnoise identique sur 50000 entrées (%d écarts)" % bad)


## PixelDraw.vnoise_cached (coins mémorisés) : identique à Rng.vnoise, à la première évaluation comme aux suivantes,
## y compris après vidage du cache.
func test_vnoise_cached_identical() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var bad := 0
	var n := 0
	for pass_i in 3:
		for i in 6:
			for j in 15:
				for f in 200:
					var t := f * 0.016 + pass_i * 0.5
					for xy: Vector2 in [Vector2(j * 0.55 + i * 17, t * 3.2), Vector2(j * 1.4 + i * 5, t * 6.5)]:
						n += 1
						if PixelDraw.vnoise_cached(xy.x, xy.y, 7 + i % 3) != Rng.vnoise(xy.x, xy.y, 7 + i % 3):
							bad += 1
	for i in 20000:
		var x := rng.randf_range(-3000.0, 3000.0)
		var y := rng.randf_range(-3000.0, 3000.0)
		n += 1
		if PixelDraw.vnoise_cached(x, y, 9) != Rng.vnoise(x, y, 9):
			bad += 1
	check(bad == 0, "vnoise_cached identique sur %d évaluations, cache vidé en route (%d écarts)" % [n, bad])
