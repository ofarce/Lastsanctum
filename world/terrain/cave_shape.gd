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


## Flanc de la montagne : z = EDGE_BASE + a1·sin(x·f1) + a2·sin(x·f2 + p2). EDGE_WAVES = (a1, f1, a2, f2),
## passés tels quels au shader d'éclairage (lighting_dark.gdshader), qui trace la même lisière.
const EDGE_BASE := -78.0
const EDGE_WAVES := Vector4(4.0, 0.13, 3.0, 0.31)
const EDGE_PHASE := 1.0


static func mountain_edge(x: float) -> float:
	return EDGE_BASE + EDGE_WAVES.x * sin(x * EDGE_WAVES.y) + EDGE_WAVES.z * sin(x * EDGE_WAVES.w + EDGE_PHASE)


static func cave_w(z: float) -> float:
	return -59.0 + 4.0 * sin(z * 0.17) + 2.0 * sin(z * 0.41 + 1.0)


static func cave_e(z: float) -> float:
	return 59.0 + 4.0 * sin(z * 0.19 + 2.0) + 2.0 * sin(z * 0.37 + 0.5)


## Paroi nord : tracé du prototype creusé de baies et d'avancées (jusqu'à ~20 unités au nord), sauf derrière
## la capsule (|x| < 9), où la paroi reste droite à CAVE_Z0.
static func cave_n(x: float) -> float:
	var a := absf(x)
	var base := CAVE_Z0 if a < 48.0 else CAVE_Z0 + pow(a - 48.0, 1.25) * 0.7 + sin(x * 0.6)
	var w := clampf((a - 9.0) / 7.0, 0.0, 1.0)
	return base + (7.0 * sin(x * 0.1 + 0.8) + 4.0 * sin(x * 0.27 + 2.3) - 5.0) * w


static func cave_s(x: float) -> float:
	var a := absf(x)
	if a < CAVE_GATE + 3.0:
		return CAVE_Z1
	return -93.0 + 3.0 * sin(x * 0.15) + 2.0 * sin(x * 0.37) - maxf(0.0, a - 48.0) * 0.7


## Salle de départ, taillée bloc par bloc : une case de 4 × 4 est entièrement creuse ou entièrement de
## roche, selon que son centre est dans le contour du prototype (_in_cave_outline). Parois droites, à
## angle droit, alignées sur la grille de minage.
## Le centre est d'abord déplacé (_wall_jitter) : parois très irrégulières, avancées et renfoncements de
## plusieurs cases, plus des accidents d'une case.
static func in_cave(x: float, z: float) -> bool:
	if x < -88.0 or x > 88.0 or z < -204.0 or z > -72.0:
		return false
	var key := Vector2i(floori(x / 4.0), floori(z / 4.0))
	var hit: Variant = _cave_cells.get(key)
	if hit == null:
		# Lissage d'une passe : une case de sol sans au moins deux voisines de sol (orthogonales) redevient de
		# la roche (pas de poche isolée ni de raccord par la seule diagonale) ; une case de roche entourée de
		# trois cases de sol est creusée (pas de pilier isolé).
		var n := 0
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if _raw_cave_cell(key + d):
				n += 1
		hit = n >= 2 if _raw_cave_cell(key) else n >= 3
		_cave_cells[key] = hit
	return hit


## Case dont le centre déplacé tombe dans le contour du prototype (avant lissage).
static func _raw_cave_cell(key: Vector2i) -> bool:
	var hit: Variant = _raw_cells.get(key)
	if hit == null:
		var c := Vector2(key.x * 4.0 + 2.0, key.y * 4.0 + 2.0)
		c += _wall_jitter(key.x, key.y) * _wall_calm(c)
		hit = _in_cave_outline(c.x, c.y)
		_raw_cells[key] = hit
	return hit


## Cases de la salle déjà évaluées (la forme est fixe, indépendante de la graine).
static var _cave_cells := {}
static var _raw_cells := {}


## Amplitudes du déplacement (unités) : ondulation lente le long des parois, accident propre à chaque case.
const WALL_WAVE := 30.0
const WALL_GRAIN := 10.0


static func _wall_jitter(i: int, j: int) -> Vector2:
	# Paroi ouest/est : déplacement en x qui varie le long de z (j) ; parois nord/sud : en z le long de x (i).
	var ox := (Rng.vnoise(j * 0.45, 3.0, 7101) - 0.5) * WALL_WAVE + (Rng.hash3(i, j, 7103) - 0.5) * WALL_GRAIN
	var oz := (Rng.vnoise(i * 0.45, 9.0, 7109) - 0.5) * WALL_WAVE + (Rng.hash3(i, j, 7111) - 0.5) * WALL_GRAIN
	return Vector2(ox, oz)


## Zones où la paroi garde son tracé (0 dedans, 1 à 6 unités et plus) : capsule contre la paroi nord, seuil
## et porte sud, roche entre la salle et la réserve du coffre, bosquet de départ, filon de cuivre ouest.
const CALM_ZONES: Array[Rect2] = [
	Rect2(-10.0, -172.0, 20.0, 16.0),
	Rect2(-14.0, -104.0, 28.0, 20.0),
	Rect2(44.0, -162.0, 26.0, 24.0),
	Rect2(38.0, -112.0, 18.0, 18.0),
	Rect2(-76.0, -162.0, 20.0, 16.0),
]


static func _wall_calm(p: Vector2) -> float:
	var d := INF
	for r: Rect2 in CALM_ZONES:
		var q := p.clamp(r.position, r.end)
		d = minf(d, q.distance_to(p))
	return clampf(d / 6.0, 0.0, 1.0)


## Contour arrondi du prototype, paroi nord irrégulière. Pré-test rectangulaire (la salle tient dans
## |x| < 66, −190 < z < −85), puis les mêmes comparaisons que le JS, dans le même ordre.
static func _in_cave_outline(x: float, z: float) -> bool:
	if x < -66.0 or x > 66.0 or z < -190.0 or z > -85.0:
		return false
	return z > cave_n(x) and z < cave_s(x) and x > cave_w(z) and x < cave_e(z)


## Contour d'origine du prototype (paroi nord droite), celui que le sol et le décor du baker dessinent :
## sert à retirer le décor baké devenu faux une fois la salle retaillée (TerrainOps.reshape_cave).
static func in_prototype_outline(x: float, z: float) -> bool:
	if x < -66.0 or x > 66.0 or z < -171.0 or z > -85.0:
		return false
	var a := absf(x)
	var n := CAVE_Z0 if a < 48.0 else CAVE_Z0 + pow(a - 48.0, 1.25) * 0.7 + sin(x * 0.6)
	return z > n and z < cave_s(x) and x > cave_w(z) and x < cave_e(z)


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


## Brèche du mur sud, soufflée par l'explosion du bouclier (sim/opening.gd) : du seuil de la salle au flanc,
## bords déchiquetés.
const BREACH_W := 15.0


static func in_breach(x: float, z: float) -> bool:
	var w := BREACH_W + 1.6 * sin(z * 0.9) + 1.1 * sin(z * 0.37 + 2.0) - maxf(0.0, -88.0 - z) * 0.55
	return absf(x) < w and z >= CAVE_Z1 - 1.0 and z < mountain_edge(x) + 0.5


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
