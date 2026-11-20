class_name River
extends RefCounted
## Rivière de la jungle : elle traverse la carte d'ouest en est entre la lisière de la montagne et l'arrivée
## des vagues (z ≈ 62). Au sud (z plus grand) : zone tampon où arrivent les ennemis, non constructible ;
## au nord : zone de combat où le joueur pose bâtiments, unités et pièges.
## Fonction pure de la graine. Seuls des ponts de pierre anciens la franchissent ; l'eau est infranchissable.
##
## Crues (sorts futurs) : `flood` élargit l'eau de `flood` unités au-delà des berges. La zone inondée
## (flooded) reste praticable : elle servira aux ralentissements et aux dégâts ; le rendu lit `flood`
## (RiverView.set_flood). Les ponts restent hors d'eau.

## Ligne médiane moyenne, amplitude des méandres, demi-largeur moyenne (unités).
const MID_Z := 34.0
const MEANDER := 4.5
const HALF_W := 4.2
## Demi-largeur praticable d'un tablier (alignée sur les cases de 4 u : deux cases de pièges) et parapets.
const DECK_HALF := 4.0
const PARAPET := 0.8
## Le tablier déborde sur chaque berge.
const DECK_OVERHANG := 1.6
## Berge sableuse dessinée autour de l'eau (unités), sans effet sur la praticabilité.
const BANK := 1.6
## Mares (2026-11-20) : la rivière s'élargit par endroits, loin des ponts ; les plus larges portent un
## banc de sable au milieu (îlot bas, hors d'eau, inaccessible à pied). Élargissement maximal d'une mare.
const POOL_MAX := 5.0
const POOL_COUNT := 5
const POOL_CLEAR := 34.0

var seed := 0
var _p: Array[float] = []
## Ponts : {x (centre, multiple de 4), z0, z1 (étendue du tablier)}.
var bridges: Array[Dictionary] = []
## Mares : {x, r (demi-longueur), add (élargissement au centre)}.
var pools: Array[Dictionary] = []
## Bancs de sable : {x, z, a (demi-longueur), b (demi-largeur)}.
var bars: Array[Dictionary] = []
## Phases des petites ondulations des berges.
var _w: Array[float] = []
## Crue en cours (unités au-delà des berges), 0 au repos.
var flood := 0.0


func _init(map_seed: int) -> void:
	seed = map_seed
	var r := Rng.new(map_seed ^ 0x51e7)
	for k in 6:
		_p.append(r.next() * TAU)
	# Pont du chemin (x = 0), puis deux de chaque côté, l'un proche, l'autre loin.
	var xs: Array[float] = [0.0]
	for side: float in [-1.0, 1.0]:
		xs.append(side * (100.0 + r.next() * 60.0))
		xs.append(side * (270.0 + r.next() * 110.0))
	# Variété (autre générateur : les ponts restent où ils étaient) : ondulations des berges, mares, bancs.
	var v := Rng.new(map_seed ^ 0x9a7e)
	for k in 3:
		_w.append(v.next() * TAU)
	for k in POOL_COUNT * 6:
		if pools.size() >= POOL_COUNT:
			break
		var px := lerpf(CaveShape.WORLD_X0 + 40.0, CaveShape.WORLD_X1 - 40.0, v.next())
		var pr := 13.0 + v.next() * 10.0
		var add := 2.5 + v.next() * (POOL_MAX - 2.5)
		var ok := true
		for bx0 in xs:
			if absf(px - bx0) < POOL_CLEAR + pr:
				ok = false
		for p in pools:
			if absf(px - float(p["x"])) < pr + float(p["r"]) + 20.0:
				ok = false
		if ok:
			pools.append({"x": px, "r": pr, "add": add})
	for p in pools:
		if float(p["add"]) >= 3.6:
			var bx: float = p["x"]
			bars.append({"x": bx, "z": center(bx) + (v.next() - 0.5) * 2.0, "a": 3.0 + v.next() * 2.0, "b": 1.1 + v.next() * 0.5})
	for bx0 in xs:
		var bx := roundf(bx0 / 4.0) * 4.0
		var z0 := INF
		var z1 := -INF
		var x := bx - DECK_HALF - PARAPET
		while x <= bx + DECK_HALF + PARAPET:
			z0 = minf(z0, center(x) - half_width(x))
			z1 = maxf(z1, center(x) + half_width(x))
			x += 0.5
		bridges.append({"x": bx, "z0": z0 - DECK_OVERHANG, "z1": z1 + DECK_OVERHANG})
	bridges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["x"] < b["x"])


## Ligne médiane de la rivière en x.
func center(x: float) -> float:
	var c := MID_Z + MEANDER * (0.6 * sin(x * 0.011 + _p[0]) + 0.3 * sin(x * 0.029 + _p[1]) + 0.1 * sin(x * 0.083 + _p[2]))
	# Petites ondulations : les berges ne filent plus au cordeau.
	if not _w.is_empty():
		c += 0.5 * sin(x * 0.21 + _w[0]) + 0.25 * sin(x * 0.47 + _w[1])
	return c


## Demi-largeur de l'eau en x (≈ 2,3 à 5,9 u, jusqu'à POOL_MAX de plus au cœur d'une mare).
func half_width(x: float) -> float:
	var hw := HALF_W + 1.1 * sin(x * 0.017 + _p[3]) + 0.5 * sin(x * 0.061 + _p[4])
	if not _w.is_empty():
		hw += 0.3 * sin(x * 0.33 + _w[2])
	for p in pools:
		var t := absf(x - float(p["x"])) / float(p["r"])
		if t < 1.0:
			hw += float(p["add"]) * (1.0 - t * t) * (1.0 - t * t)
	return hw


## Distance signée à la berge (négative dans l'eau). Un banc de sable est une berge au milieu de l'eau.
func bank_distance(x: float, z: float) -> float:
	var d := absf(z - center(x)) - half_width(x)
	if d < 0.0:
		for b in bars:
			var dx := (x - float(b["x"])) / float(b["a"])
			if dx > -3.0 and dx < 3.0:
				var dz := (z - float(b["z"])) / float(b["b"])
				# Haut-fond autour du banc, en ellipse (pas de bord droit dans les paliers de profondeur).
				var q := sqrt(dx * dx + dz * dz)
				if q < 3.0:
					d = maxf(d, (1.0 - q) * float(b["b"]))
	return d


## Bornes en z de tout ce qui est dessiné (eau, berges, ponts).
func z_range() -> Vector2:
	var reach := MEANDER + 0.75 + HALF_W + 1.9 + POOL_MAX + BANK + DECK_OVERHANG + 1.0
	return Vector2(MID_Z - reach, MID_Z + reach)


func water_at(x: float, z: float) -> bool:
	return bank_distance(x, z) < 0.0


## Pont dont l'emprise (parapets compris) contient x, ou {}.
func bridge_near(x: float) -> Dictionary:
	for b in bridges:
		if absf(x - float(b["x"])) < DECK_HALF + PARAPET:
			return b
	return {}


## Tablier praticable.
func on_deck(x: float, z: float) -> bool:
	for b in bridges:
		if x >= float(b["x"]) - DECK_HALF and x < float(b["x"]) + DECK_HALF and z >= float(b["z0"]) and z < float(b["z1"]):
			return true
	return false


## Parapet (bordure du pont, infranchissable).
func on_parapet(x: float, z: float) -> bool:
	for b in bridges:
		var dx := absf(x - float(b["x"]))
		if dx >= DECK_HALF and dx < DECK_HALF + PARAPET and z >= float(b["z0"]) and z < float(b["z1"]):
			return true
	return false


## Infranchissable : l'eau hors tablier, et les parapets.
func blocks(x: float, z: float) -> bool:
	if z < MID_Z - 20.0 or z > MID_Z + 20.0:
		return false
	if on_parapet(x, z):
		return true
	return water_at(x, z) and not on_deck(x, z)


## Rive des ennemis (sud de l'eau, côté arrivée des vagues), hors ponts.
func far_bank(x: float, z: float) -> bool:
	return z > center(x) + half_width(x)


## Sol à garder libre de décor : eau, berge et ponts.
func clear_of_decor(x: float, z: float) -> bool:
	if bank_distance(x, z) < BANK + 0.6:
		return true
	var b := bridge_near(x)
	return not b.is_empty() and z >= float(b["z0"]) - 6.0 and z < float(b["z1"]) + 6.0


## Zone inondée par une crue (hors eau courante et hors tablier) : praticable, effets des sorts futurs.
func flooded(x: float, z: float) -> bool:
	if flood <= 0.0:
		return false
	var d := bank_distance(x, z)
	return d >= 0.0 and d < flood and not on_deck(x, z)
