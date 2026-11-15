class_name Rng
## Générateurs pseudo-aléatoires identiques au prototype (assets/decor.js, Index.html:73).
## Les opérations reproduisent l'arithmétique JS : entiers 32 bits et produits en double.

const TWO_32 := 4294967296.0

var _seed: int


func _init(seed: int) -> void:
	_seed = seed & 0xFFFFFFFF


## rng(seed)() du JS : générateur congruentiel linéaire 1664525 / 1013904223.
func next() -> float:
	_seed = (1664525 * _seed + 1013904223) & 0xFFFFFFFF
	return _seed / TWO_32


## Conversion ToInt32 du JS (|0).
static func to_int32(v: int) -> int:
	v &= 0xFFFFFFFF
	return v - 0x100000000 if v >= 0x80000000 else v


## hash(x, y, s) du JS. Le produit par 1274126177 dépasse 2^53 : il est calculé en double,
## comme en JS, avant la conversion 32 bits.
static func hash3(x: int, y: int, s: int) -> float:
	var h := to_int32(int(float(x) * 374761393.0 + float(y) * 668265263.0 + float(s) * 1442695041.0))
	h = h ^ ((h & 0xFFFFFFFF) >> 13)
	h = to_int32(int(float(to_int32(h)) * 1274126177.0))
	return float((h ^ ((h & 0xFFFFFFFF) >> 16)) & 0xFFFFFFFF) / TWO_32


## vnoise(x, y, s) du JS : bruit de valeur lissé.
static func vnoise(x: float, y: float, s: int) -> float:
	var xi := floori(x)
	var yi := floori(y)
	var xf := x - xi
	var yf := y - yi
	var u := xf * xf * (3.0 - 2.0 * xf)
	var v := yf * yf * (3.0 - 2.0 * yf)
	var a := hash3(xi, yi, s)
	var b := hash3(xi + 1, yi, s)
	var c := hash3(xi, yi + 1, s)
	var d := hash3(xi + 1, yi + 1, s)
	return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v
