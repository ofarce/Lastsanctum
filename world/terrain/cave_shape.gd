class_name CaveShape
## Géométrie fixe de la carte (73b410f, Index.html : CAVE, mountainEdge, caveW/E/N/S, inCave, inTunnel,
## inPath ; galleries.js : WORLD). Fonctions pures, calculées en double précision comme le JS.

const WORLD_X0 := -464.0
const WORLD_X1 := 464.0
const WORLD_Z0 := -744.0
const WORLD_Z1 := 72.0
## Zone d'origine (carte du prototype, 464 × 408) : cœur du Temple, générée exactement comme le JS.
## Le reste de la carte (extension) est tiré avec une graine dérivée, hors de cette zone.
const START_X0 := -232.0
const START_X1 := 232.0
const START_Z0 := -336.0
const START_Z1 := 72.0
const CAVE_X0 := -56.0
const CAVE_X1 := 56.0
const CAVE_Z0 := -168.0
const CAVE_Z1 := -96.0
const CAVE_GATE := 7.0
## Centre de l'Ancre (core).
const CORE := Vector2(0.0, -154.0)
## Réserve du coffre antique : petite pièce scellée à l'est de la salle, derrière la roche (x 56–64,
## une case et demie) qu'il faut miner ; au nord de la rangée z −140 (tunnel de référence de test_dig).
## Paroi ouest droite (x = 64, raccord exact avec la case creusée), angles est arrondis. Hors des
## galeries (gallery_allowed exclut |x| < 76 près de la salle).
const VAULT_X0 := 64.0
const VAULT_X1 := 76.0
const VAULT_Z0 := -156.0
const VAULT_Z1 := -144.0
## Coffre : milieu de la face avant (au sol) ; l'Ingénieur se tient à sa droite pour l'ouvrir.
const CHEST := Vector2(70.0, -149.0)
const CHEST_SPOT := Vector2(74.0, -149.2)


static func mountain_edge(x: float) -> float:
	return -78.0 + 4.0 * sin(x * 0.13) + 3.0 * sin(x * 0.31 + 1.0)


static func cave_w(z: float) -> float:
	return -59.0 + 4.0 * sin(z * 0.17) + 2.0 * sin(z * 0.41 + 1.0)


static func cave_e(z: float) -> float:
	return 59.0 + 4.0 * sin(z * 0.19 + 2.0) + 2.0 * sin(z * 0.37 + 0.5)


static func cave_n(x: float) -> float:
	var a := absf(x)
	return CAVE_Z0 if a < 48.0 else CAVE_Z0 + pow(a - 48.0, 1.25) * 0.7 + sin(x * 0.6)


static func cave_s(x: float) -> float:
	var a := absf(x)
	if a < CAVE_GATE + 3.0:
		return CAVE_Z1
	return -93.0 + 3.0 * sin(x * 0.15) + 2.0 * sin(x * 0.37) - maxf(0.0, a - 48.0) * 0.7


## Salle de départ. Pré-test rectangulaire équivalent (la salle tient dans |x| < 66, −171 < z < −85),
## puis les mêmes comparaisons que le JS, dans le même ordre.
static func in_cave(x: float, z: float) -> bool:
	if x < -66.0 or x > 66.0 or z < -171.0 or z > -85.0:
		return false
	return z > cave_n(x) and z < cave_s(x) and x > cave_w(z) and x < cave_e(z)


## Volume de la réserve (qu'elle soit encore scellée ou non).
static func in_vault(x: float, z: float) -> bool:
	if x < VAULT_X0 or x >= VAULT_X1 or z < VAULT_Z0 or z >= VAULT_Z1:
		return false
	# Angles est arrondis (rayon 2,5), légère irrégularité de la paroi nord.
	var r := 2.5
	var cx := VAULT_X1 - r
	var dx := x - cx
	if dx > 0.0:
		var cz := clampf(z, VAULT_Z0 + r, VAULT_Z1 - r)
		if dx * dx + (z - cz) * (z - cz) > r * r:
			return false
	return z >= VAULT_Z0 + 0.6 + 0.6 * sin(x * 0.9)


static func in_tunnel(x: float, z: float) -> bool:
	return absf(x) < CAVE_GATE and z >= CAVE_Z1 - 0.5 and z < mountain_edge(x) + 0.5


static func in_path(x: float, z: float) -> bool:
	return absf(x) < 5.0 and z > mountain_edge(x) - 1.0


## Dehors (jungle) : au sud du flanc de la montagne.
static func outdoors(x: float, z: float) -> bool:
	return z >= mountain_edge(x)


## Point dans la zone d'origine.
static func in_start(x: float, z: float) -> bool:
	return x >= START_X0 and x < START_X1 and z >= START_Z0 and z < START_Z1
