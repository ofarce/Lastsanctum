class_name TerrainState
extends RefCounted
## État du terrain dynamique (73b410f) : galeries cachées (galleries.js), cases creusées et coups en
## cours (adepts.js : DUG, DIG_HITS_DONE), praticabilité (Index.html : walkable, pushOutOfRock).
## Aucune donnée graphique ici : la peinture et le décor sont gérés par TerrainOps.

const GAL_W := int(CaveShape.WORLD_X1 - CaveShape.WORLD_X0)
const GAL_H := int(CaveShape.WORLD_Z1 - CaveShape.WORLD_Z0)
## Coups de pioche par case (DIG_HITS) et durée d'un coup (HIT_TIME, en secondes de travail).
const Blocks := preload("res://data/mineable_blocks.gd")
const DIG_HITS: int = Blocks.TYPES["rock"]["resistance"]
const HIT_TIME := 1.0
## Vitesse de l'Ingénieur : cases déblayées par seconde (ENGINEER_DIG) ; un piton d'ancrage par coup.
const ENGINEER_DIG := 3.0
## Portée du lance-pitons de l'Ingénieur : au plus une case (4 unités) entre lui et la case visée.
const DIG_REACH := 4.0
## Sceau de minage de l'Exilé incarné : portée d'activation, un bloc et demi (6 unités) du bord de la case.
const INCARNATED_DIG_REACH := 6.0

# ----- Galeries (masque à 1 unité : 0 = roche, 1 = galerie ; open = déjà découverte) -----
var mask := PackedByteArray()
var open := PackedByteArray()
var count := 0
var found := 0
var seed := 0
## Portails maléfiques : {id, x, z, active, next}.
var portals: Array[Dictionary] = []

# ----- Cases creusées (clé Vector2i(i, j), case de 4×4 unités) -----
var dug := {}
## Les cellules sans entrée sont en roche ; un type inconnu n'est pas minable.
var block_types: Dictionary = {}
## Gisements qui restent en place après chaque cycle de récolte.
var permanent_ores := {}
## Bosquets pétrifiés posés au sol, 2 × 2 cases infranchissables : case d'origine (haut gauche) → bois
## restant, entamé par tout mineur sauf un adepte de Medeina.
var wood_left := {}
## Chacune des 4 cases d'un bosquet → sa case d'origine.
var grove_cells := {}
## Salle de la Gorge-Cuivre (sim/gorge.gd) : centre d'un disque de GORGE_ROOM unités élargi sur une galerie de la
## moitié nord du biome 2 ; null si aucun emplacement (ou en parité JS).
var gorge_room: Variant = null
const GORGE_ROOM := 24.0
## Bosquets abattus : case d'origine → numéro de la vague où ils sont tombés (Sylviculture : ils repoussent).
var felled_groves := {}
## Filons illimités posés au sol (2 × 2 cases infranchissables, calqués sur les bosquets) : case d'origine
## (haut gauche) → minerai. Ils ne s'épuisent jamais.
var lodes := {}
## Chacune des 4 cases d'un filon → sa case d'origine.
var lode_cells := {}
## Socles des Pylônes de Merenor (sim/pylons.gd) : 2 × 2 cases infranchissables → id du pylône.
var pylon_cells := {}
## Salle creusée autour de chaque pylône (rayon, unités) pour la meute et la nappe.
const PYLON_CHAMBER := 15.0
## Frontière entre le Temple et le biome 2 (sim/oeil.gd) : bande de roche impossible à creuser, de
## 2 × FRONTIER_HALF unités, le long de la limite nord du Temple. Seule la salle de l'Œil de la Matrice la perce :
## au nord de la salle, un couloir traverse la bande, fermé par une porte de chair (eye_gate) jusqu'à la mort
## du boss. Hors parité JS (groves).
const FRONTIER_HALF := 6.0
## Salle de l'Œil : ellipse à bord irrégulier (demi-axes, unités), adossée à la bande, au nord de la zone d'origine.
const EYE_ROOM_RX := 58.0
const EYE_ROOM_RZ := 26.0
## Demi-largeur du couloir nord (3 cases) et longueur au-delà de la bande sans galerie du biome 2 à rejoindre.
const EYE_GATE_HALF := 6.0
const EYE_CORRIDOR := 16.0
var frontier := false
## Cases de la porte de chair → vrai (infranchissables tant que eye_gate_closed).
var eye_gate := {}
var eye_gate_closed := false
## Couloir nord : de la salle (z le plus au sud) jusqu'à eye_corridor_north, |x| ≤ EYE_GATE_HALF (puis coude).
var eye_corridor_north := 0.0
## Cases fermées par une barricade (sim/placeables.gd) → vrai : infranchissables, ne masquent pas la vue.
var walls := {}
## Emprises infranchissables précises (unités de monde), en plus des cases : socles de l'Ancre et de la capsule.
var solids: Array[Rect2] = []
## Mur sud soufflé (CaveShape.in_breach devient creux).
var breach_open := false
## Bosquet de la salle de départ (bas à droite) et clairières semées dans les galeries.
const START_GROVE_AT := Vector2(46.0, -104.0)
const GALLERY_GROVES := 6
const CLEARING_RADIUS := 10.0
## Écart voulu avec le prototype : clairières et bosquets. Les tests de parité JS le désactivent.
var groves := true
const VAULT_COPPER := Vector2i(16, -37)
const ORE_BANDS := [Vector2(55, 85), Vector2(90, 125), Vector2(135, 175), Vector2(185, 260)]
const VEIN_COUNTS := [16, 10, 6, 3]
## Filons illimités au sol par palier (cuivre, fer, quartz, or) ; le quartz garde ses gisements en paroi.
const LODE_COUNTS := [3, 2, 0, 1]
## Minerais que porte le Temple (décision du 2026-11-20) : les veines et filons des autres paliers de la zone
## d'origine ne sont plus posés (leurs tirages et leurs clairières restent, pour ne rien déplacer d'autre).
## La parité JS (groves = false) garde les quatre.
const TEMPLE_ORES: Array[String] = ["copper"]
var dig_hits := {}
## Instant (sim_time) du dernier piton tiré sur chaque case en cours : rendu des pitons plantés.
var dig_hit_at := {}

## Réserve du coffre antique (CaveShape.in_vault) découverte : elle devient creuse et praticable.
var vault_open := false

## Rivière de la jungle (world/terrain/river.gd) ; null pour la parité JS (groves = false).
var river: River = null
## Petite végétation de la jungle (world/flora/flora.gd) ; null pour la parité JS.
var flora: Flora = null
## Chemins de la jungle (world/terrain/road.gd), décor seulement ; null pour la parité JS.
var road: Road = null

## Incrémenté à chaque changement de praticabilité (WALK.version) : invalide les chemins en cache.
var version := 0


func _init() -> void:
	mask.resize(GAL_W * GAL_H)
	open.resize(GAL_W * GAL_H)


# ---------------------------------------------------------------- Praticabilité

static func gal_idx(x: float, z: float) -> int:
	var i := floori(x - CaveShape.WORLD_X0)
	var j := floori(z - CaveShape.WORLD_Z0)
	if i < 0 or j < 0 or i >= GAL_W or j >= GAL_H:
		return -1
	return j * GAL_W + i


func is_gallery(x: float, z: float) -> bool:
	var k := gal_idx(x, z)
	return k >= 0 and mask[k] == 1


func is_gallery_open(x: float, z: float) -> bool:
	if found == 0:
		return false
	var k := gal_idx(x, z)
	return k >= 0 and open[k] == 1


func is_dug(x: float, z: float) -> bool:
	return not dug.is_empty() and dug.has(Vector2i(floori(x / 4.0), floori(z / 4.0)))


## Appelée des milliers de fois par tick (lignes de vue du Pathfinder) : mêmes tests, dans le même ordre, que
## ground, grove_at, lode_at, water_at, River.blocks, walls, _in_solid, pylon_at et la porte de l'Œil, mais la
## case n'est calculée qu'une fois et les tests de cases sont écrits sur place.
func walkable(x: float, z: float) -> bool:
	if not ground(x, z):
		return false
	var c := Vector2i(floori(x / 4.0), floori(z / 4.0))
	if not grove_cells.is_empty() and grove_cells.has(c):
		return false
	if not lode_cells.is_empty() and lode_cells.has(c):
		return false
	if not water_cells.is_empty() and water_cells.has(c):
		return false
	# River.blocks ne répond vrai que dans la bande de la rivière (MID_Z ± 20).
	if river != null and z >= River.MID_Z - 20.0 and z <= River.MID_Z + 20.0 and river.blocks(x, z):
		return false
	if not walls.is_empty() and walls.has(c):
		return false
	if not solids.is_empty() and _in_solid(x, z):
		return false
	if not pylon_cells.is_empty() and pylon_cells.has(c):
		return false
	return not (eye_gate_closed and eye_gate.has(c))


# ---------------------------------------------------------------- Frontière et salle de l'Œil

## Limite nord du Temple (premier biome).
static func frontier_z() -> float:
	return Biomes.north_z(0)


## Centre de la salle de l'Œil : son bord nord entame la bande, son bord sud reste au nord de la zone d'origine.
static func eye_room_center() -> Vector2:
	return Vector2(0.0, frontier_z() + FRONTIER_HALF + EYE_ROOM_RZ - 4.0)


## Bord irrégulier de la salle : facteur d'échelle de l'ellipse selon l'angle.
static func eye_room_scale(a: float) -> float:
	return 1.0 + 0.05 * sin(3.0 * a + 0.7) + 0.035 * sin(7.0 * a + 2.0)


## (x, z) est dans la salle de l'Œil (grow : marge en unités, négative pour rester loin des parois).
static func in_eye_room(x: float, z: float, grow := 0.0) -> bool:
	var c := eye_room_center()
	var dx := x - c.x
	var dz := z - c.y
	var k := eye_room_scale(atan2(dz / EYE_ROOM_RZ, dx / EYE_ROOM_RX))
	var rx := EYE_ROOM_RX * k + grow
	var rz := EYE_ROOM_RZ * k + grow
	return rx > 0.0 and rz > 0.0 and (dx * dx) / (rx * rx) + (dz * dz) / (rz * rz) <= 1.0


func _in_eye_corridor(x: float, z: float) -> bool:
	return absf(x) <= EYE_GATE_HALF and z >= eye_corridor_north and z <= eye_room_center().y


## La case (i, j) est de la roche de frontière : impossible à creuser.
func frontier_cell(i: int, j: int) -> bool:
	if not frontier:
		return false
	var fz := frontier_z()
	var z0 := j * 4.0
	if z0 + 4.0 <= fz - FRONTIER_HALF or z0 >= fz + FRONTIER_HALF:
		return false
	return not in_eye_room(i * 4.0 + 2.0, z0 + 2.0, 2.0) and not _in_eye_corridor(i * 4.0 + 2.0, z0 + 2.0)


## Bande vidée de ses galeries, salle creusée, couloir nord vers la galerie du biome 2 la plus proche (arrêté à
## PASSAGE_GAP unités d'elle, comme les passages), porte de chair au milieu de la bande ; clairières, filons et
## bassins tombés dans la salle ou la bande retirés.
func _carve_frontier() -> void:
	frontier = true
	eye_gate.clear()
	var fz := frontier_z()
	var c := eye_room_center()
	for j in range(floori(fz - FRONTIER_HALF - CaveShape.WORLD_Z0), ceili(fz + FRONTIER_HALF - CaveShape.WORLD_Z0)):
		for i in GAL_W:
			mask[j * GAL_W + i] = 0
	for z in range(floori(c.y - EYE_ROOM_RZ * 1.1), ceili(c.y + EYE_ROOM_RZ * 1.1) + 1):
		for x in range(floori(c.x - EYE_ROOM_RX * 1.1), ceili(c.x + EYE_ROOM_RX * 1.1) + 1):
			if in_eye_room(x + 0.5, z + 0.5):
				mask[gal_idx(x, z)] = 1
	# Galerie du biome 2 la plus proche au nord de la bande.
	var top := fz - FRONTIER_HALF
	var target: Variant = null
	var d := 4.0
	while d < 90.0 and target == null:
		for o in range(0, 64, 4):
			for s: float in ([1.0] if o == 0 else [1.0, -1.0]):
				var q := Vector2(c.x + o * s, top - d)
				if is_gallery(q.x, q.y):
					target = q
					break
			if target != null:
				break
		d += 2.0
	# Le couloir s'arrête à PASSAGE_GAP unités de cette galerie : la salle et le biome 2 restent deux réseaux
	# (découvrir la salle n'éveille pas les pylônes du nord) ; il reste une ou deux cases à creuser.
	var side := Vector2.ZERO
	if target == null:
		eye_corridor_north = top - EYE_CORRIDOR
	elif absf(target.x) <= EYE_GATE_HALF + 4.0:
		eye_corridor_north = minf(top - 4.0, target.y + PASSAGE_GAP + MIN_HALF_WIDTH)
	else:
		eye_corridor_north = minf(top - 4.0, target.y)
		side = Vector2(target.x - signf(target.x) * (PASSAGE_GAP + MIN_HALF_WIDTH), eye_corridor_north + MIN_HALF_WIDTH)
	for z in range(floori(eye_corridor_north), ceili(c.y)):
		for x in range(floori(-EYE_GATE_HALF), ceili(EYE_GATE_HALF)):
			mask[gal_idx(x, z)] = 1
	if side != Vector2.ZERO and absf(side.x) > EYE_GATE_HALF:
		_carve_axis_segment(Vector2(signf(side.x) * EYE_GATE_HALF, side.y), side)
	# Porte : une rangée de cases au milieu de la bande, sur toute la largeur du couloir.
	var gj := floori(fz / 4.0)
	for gi in range(floori(-EYE_GATE_HALF / 4.0), ceili(EYE_GATE_HALF / 4.0)):
		eye_gate[Vector2i(gi, gj)] = true
	eye_gate_closed = true
	var out := func(p: Vector2, r: float) -> bool:
		return in_eye_room(p.x, p.y, r) or absf(p.y - fz) < FRONTIER_HALF + r
	_clearings.assign(_clearings.filter(func(p: Vector2) -> bool: return not out.call(p, CLEARING_RADIUS)))
	_lode_spots = _lode_spots.filter(func(s: Array) -> bool: return not out.call(Vector2((s[0] as Vector2i) * 4) + Vector2(4, 4), 6.0))
	for k: Vector2i in water_cells.keys():
		if out.call(Vector2(k * 4) + Vector2(2, 2), 4.0):
			water_cells.erase(k)
	pools.assign(pools.filter(func(p: Dictionary) -> bool: return not out.call(p["center"], POOL_RADIUS)))


func _in_solid(x: float, z: float) -> bool:
	for r in solids:
		if r.has_point(Vector2(x, z)):
			return true
	return false


## Un bosquet pétrifié occupe ce point.
func grove_at(x: float, z: float) -> bool:
	return not grove_cells.is_empty() and grove_cells.has(Vector2i(floori(x / 4.0), floori(z / 4.0)))


## Socle d'un Pylône de Merenor.
func pylon_at(x: float, z: float) -> bool:
	return not pylon_cells.is_empty() and pylon_cells.has(Vector2i(floori(x / 4.0), floori(z / 4.0)))


## Fosse d'un bassin souterrain (le haut-fond reste praticable).
func water_at(x: float, z: float) -> bool:
	return not water_cells.is_empty() and water_cells.has(Vector2i(floori(x / 4.0), floori(z / 4.0)))


## Un filon illimité occupe ce point.
func lode_at(x: float, z: float) -> bool:
	return not lode_cells.is_empty() and lode_cells.has(Vector2i(floori(x / 4.0), floori(z / 4.0)))


## Sol découvert (salle, galerie, case creusée…), bosquets compris : ce que peignent le sol et le brouillard.
func ground(x: float, z: float) -> bool:
	return CaveShape.outdoors(x, z) or CaveShape.in_cave(x, z) or CaveShape.in_tunnel(x, z) \
		or is_dug(x, z) or is_gallery_open(x, z) or (vault_open and CaveShape.in_vault(x, z)) \
		or (breach_open and CaveShape.in_breach(x, z))


## Creux de la montagne (hol, galleries.js : paintRegion) : galerie ouverte, case creusée, salle, couloir.
func hollow(x: float, z: float) -> bool:
	return is_gallery_open(x, z) or is_dug(x, z) or CaveShape.in_cave(x, z) or CaveShape.in_tunnel(x, z) \
		or (vault_open and CaveShape.in_vault(x, z)) or (breach_open and CaveShape.in_breach(x, z))


## intoCave (Index.html) : rapproche un point de la salle, pas à pas.
func into_cave(p: Vector2) -> Vector2:
	var q := Vector2(clampf(p.x, -64.0, 64.0), clampf(p.y, CaveShape.CAVE_Z0 + 0.35, -88.0))
	for i in 80:
		if CaveShape.in_cave(q.x, q.y):
			break
		var d := Vector2(-q.x, -130.0 - q.y)
		var l := d.length()
		if l == 0.0:
			l = 1.0
		q += d / l * 0.4
	return q


## pushOutOfRock (Index.html) : sol praticable le plus proche (quelques unités), sinon salle, couloir ou dehors.
func push_out_of_rock(p: Vector2) -> Vector2:
	if walkable(p.x, p.y):
		return p
	var r := 0.3
	while r <= 4.2:
		var a := 0.0
		while a < 6.28:
			var x := p.x + cos(a) * r
			var z := p.y + sin(a) * r
			if walkable(x, z):
				return Vector2(x, z)
			a += 0.45
		r += 0.3
	var m := 0.35
	var candidates: Array[Vector2] = [
		into_cave(p),
		Vector2(clampf(p.x, -CaveShape.CAVE_GATE + m, CaveShape.CAVE_GATE - m), clampf(p.y, CaveShape.CAVE_Z1 - 0.4, CaveShape.mountain_edge(0.0))),
		Vector2(p.x, CaveShape.mountain_edge(p.x) + 0.05)]
	var best := candidates[0]
	var bd := 1e9
	for q in candidates:
		var nd := q.distance_to(p)
		if nd < bd:
			bd = nd
			best = q
	return best


## resetBlocks (adepts.js) : aucune case creusée, aucun coup en cours.
func reset_digging() -> void:
	dug.clear()
	breach_open = false
	walls.clear()
	block_types.clear()
	permanent_ores.clear()
	wood_left.clear()
	grove_cells.clear()
	felled_groves.clear()
	lodes.clear()
	lode_cells.clear()
	dig_hits.clear()
	dig_hit_at.clear()
	vault_open = false
	walls.clear()
	version += 1


# ---------------------------------------------------------------- Galeries (generateGalleries)

## Largeur et hauteur de la zone d'origine (tirages au sort identiques au prototype).
const START_W := int(CaveShape.START_X1 - CaveShape.START_X0)
const START_H := int(CaveShape.START_Z1 - CaveShape.START_Z0)
## Galeries de l'extension : marge laissée autour de la zone d'origine (les réseaux ne s'y raccordent pas).
const EXT_MARGIN := 10.0
## Réglages des vers de la zone d'origine (prototype) ; l'extension lit ceux de son biome (data/biomes.gd).
const START_WORM := {"room": 0.05, "branch": 0.025}
## Passages vers la zone d'origine : la galerie s'arrête à PASSAGE_GAP unités d'une galerie d'origine.
const PASSAGE_GAP := 6.0
const PASSAGE_SEARCH := 140.0
## Demi-largeur minimale d'une galerie ou d'un passage (hors parité JS) : au moins 2 blocs (8 u) de large.
## Le ver ne s'avance que si son disque tient entier dans la zone permise (pas de galerie rognée en lame).
const MIN_HALF_WIDTH := 4.3

## Vers en cours : extension (vrai) ou zone d'origine.
var _ext := false


## Zone d'origine : bornes et règles du prototype (generateGalleries).
static func gallery_allowed(x: float, z: float) -> bool:
	if x < CaveShape.START_X0 + 10.0 or x > CaveShape.START_X1 - 10.0 or z < CaveShape.START_Z0 + 10.0 \
			or z > CaveShape.mountain_edge(x) - 12.0:
		return false
	if x > -76.0 and x < 76.0 and z > CaveShape.CAVE_Z0 - 28.0:
		return false
	return true


## Extension : toute la carte hors de la zone d'origine (et de sa marge).
static func ext_allowed(x: float, z: float) -> bool:
	if x < CaveShape.WORLD_X0 + 10.0 or x > CaveShape.WORLD_X1 - 10.0 or z < CaveShape.WORLD_Z0 + 10.0 \
			or z > CaveShape.mountain_edge(x) - 12.0:
		return false
	return not (x > CaveShape.START_X0 - EXT_MARGIN and x < CaveShape.START_X1 + EXT_MARGIN and z > CaveShape.START_Z0 - EXT_MARGIN)


func _allowed(x: float, z: float) -> bool:
	return ext_allowed(x, z) if _ext else gallery_allowed(x, z)


func generate_galleries(new_seed: int) -> void:
	seed = new_seed
	var r := Rng.new(new_seed)
	frontier = false
	eye_gate.clear()
	eye_gate_closed = false
	# Vidés dès le début : les clairières et les filons les consultent (_grove_fits) avant que les pylônes de
	# cette carte soient posés ; ceux de la carte précédente déplaçaient filons et bassins d'une instance réutilisée.
	pylon_cells.clear()
	theme_rooms.clear()
	mask.fill(0)
	open.fill(0)
	found = 0
	version += 1
	var n := 12 + floori(r.next() * 5.0)
	for g in n:
		var x := 0.0
		var z := 0.0
		for t in 200:
			x = CaveShape.START_X0 + 14.0 + r.next() * (START_W - 28)
			z = CaveShape.START_Z0 + 14.0 + r.next() * (START_H - 28)
			if gallery_allowed(x, z):
				break
		var direction := floori(r.next() * 4.0)
		var steps := 34 + floori(r.next() * 46.0)
		var radius := 2.1 + r.next() * 1.4
		_worm(r, x, z, direction, steps, radius, START_WORM)
	# Extension (hors parité JS) : mêmes vers, tirés avec une graine dérivée sur le reste de la carte.
	if groves:
		_generate_extension(Rng.new(new_seed ^ 0xe7e7))
	_clearings.clear()
	river = River.new(new_seed) if groves else null
	road = Road.new(new_seed, river) if groves else null
	flora = Flora.new(new_seed, river, road) if groves else null
	if groves:
		_carve_clearings(Rng.new(new_seed ^ 0x5eed))
		_carve_lode_clearings(Rng.new(new_seed ^ 0x10de))
		_carve_pools(Rng.new(new_seed ^ 0x9001))
		_carve_extension_features(new_seed)
		_carve_gorge_room(Rng.new(new_seed ^ 0x60c6))
		_carve_passages()
		_carve_frontier()
	else:
		pools.clear()
		water_cells.clear()
		gorge_room = null
	_label_networks()
	pylon_cells.clear()
	theme_rooms.clear()
	if groves:
		_place_pylons()
		_carve_theme_rooms(Rng.new(new_seed ^ 0x5a2c))
	_generate_ores()


## Galeries de l'extension, bande de biome par bande de biome (une graine par biome : changer les réglages
## d'un biome ne déplace rien ailleurs).
func _generate_extension(r: Rng) -> void:
	var base := floori(r.next() * 1e9)
	_ext = true
	for k in Biomes.LIST.size():
		var b: Dictionary = Biomes.LIST[k]
		var rb := Rng.new(base ^ (k * 7919 + 1))
		var n := floori(_ext_area(k) / 100000.0 * float(b["worms"]) * (0.85 + rb.next() * 0.3))
		var steps: Array = b["steps"]
		var radius: Array = b["radius"]
		for g in n:
			var p: Variant = _ext_spot(rb, k, 14.0)
			if p == null:
				continue
			var direction := floori(rb.next() * 4.0)
			var st := int(steps[0]) + floori(rb.next() * float(int(steps[1]) - int(steps[0])))
			var rad := float(radius[0]) + rb.next() * (float(radius[1]) - float(radius[0]))
			_worm(rb, p.x, p.y, direction, st, rad, {})
	_ext = false


## Surface (u²) de l'extension dans la bande du biome k, estimée sur une grille de 8 unités.
func _ext_area(k: int) -> float:
	var n := 0
	var z := CaveShape.WORLD_Z0 + 4.0
	while z < CaveShape.WORLD_Z1:
		if Biomes.index_at(z) == k:
			var x := CaveShape.WORLD_X0 + 4.0
			while x < CaveShape.WORLD_X1:
				if ext_allowed(x, z):
					n += 1
				x += 8.0
		z += 8.0
	return n * 64.0


## Point tiré au hasard dans la bande du biome k (extension, à `margin` des bords de la carte) ; null après 400 essais.
func _ext_spot(r: Rng, k: int, margin: float) -> Variant:
	var z0 := maxf(CaveShape.WORLD_Z0 + margin, Biomes.north_z(k))
	var z1 := minf(CaveShape.WORLD_Z1 - margin, Biomes.south_z(k))
	for t in 400:
		var x := CaveShape.WORLD_X0 + margin + r.next() * (GAL_W - 2.0 * margin)
		var z := z0 + r.next() * (z1 - z0)
		if ext_allowed(x, z) and Biomes.index_at(z) == k:
			return Vector2(x, z)
	return null


## Clairières à bosquet, clairières de filon et bassins de l'extension, selon les densités de chaque biome.
## Mêmes règles d'espacement que dans la zone d'origine (les listes sont partagées).
func _carve_extension_features(map_seed: int) -> void:
	_ext = true
	var vault := Vector2((CaveShape.VAULT_X0 + CaveShape.VAULT_X1) / 2.0, (CaveShape.VAULT_Z0 + CaveShape.VAULT_Z1) / 2.0)
	for k in Biomes.LIST.size():
		var b: Dictionary = Biomes.LIST[k]
		var r := Rng.new(map_seed ^ (0xb10e + k * 104729))
		var per := _ext_area(k) / 100000.0
		var near := func(p: Vector2, d: float) -> bool:
			return _clearings.any(func(c: Vector2) -> bool: return c.distance_to(p) < d) \
				or _lode_spots.any(func(s: Array) -> bool: return Vector2((s[0] as Vector2i) * 4).distance_to(p) < d)
		# Clairières à bosquet.
		var want := roundi(per * float(b["clearings"]))
		var got := 0
		for t in want * 400:
			if got >= want:
				break
			var p: Variant = _ext_spot(r, k, 20.0)
			if p == null or not is_gallery(p.x, p.y) or p.y > CaveShape.mountain_edge(p.x) - 24.0 or near.call(p, 40.0):
				continue
			_stamp(p.x, p.y, CLEARING_RADIUS)
			_clearings.append(p)
			got += 1
		# Clairières de filon : minerai selon la profondeur dans la bande (le quartz reste en paroi).
		want = roundi(per * float(b["lodes"]))
		got = 0
		for t in want * 400:
			if got >= want:
				break
			var p: Variant = _ext_spot(r, k, 20.0)
			if p == null or not is_gallery(p.x, p.y) or p.y > CaveShape.mountain_edge(p.x) - 24.0 or near.call(p, 32.0):
				continue
			var items := Biomes.ores_at(k, Biomes.depth(k, p.y)).filter(func(o: String) -> bool: return LODE_COUNTS[Blocks.ORES.find(o)] > 0)
			if items.is_empty():
				continue
			var tier := Blocks.ORES.find(items[floori(r.next() * items.size())])
			_stamp(p.x, p.y, CLEARING_RADIUS)
			var center := Vector2i(floori(p.x / 4.0) - 1, floori(p.y / 4.0) - 1)
			for o: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1)]:
				if _grove_fits(center + o) and not _lode_spots.any(func(s: Array) -> bool: return (s[0] as Vector2i).distance_to(center + o) < 4.0):
					_lode_spots.append([center + o, tier])
					got += 1
					break
		# Bassins.
		want = roundi(per * float(b["pools"]))
		got = 0
		for t in want * 400:
			if got >= want:
				break
			var p: Variant = _ext_spot(r, k, 24.0)
			if p == null or not is_gallery(p.x, p.y) or p.y > CaveShape.mountain_edge(p.x) - 26.0 or p.distance_to(vault) < 34.0:
				continue
			if near.call(p, 36.0) or pools.any(func(o: Dictionary) -> bool: return (o["center"] as Vector2).distance_to(p) < 90.0):
				continue
			_add_pool(r, p)
			got += 1
	_ext = false


## Passages : depuis l'ouest, l'est et le nord, une galerie de l'extension est prolongée vers la galerie
## d'origine la plus proche du bord, et s'arrête à PASSAGE_GAP unités : une ou deux cases à creuser.
func _carve_passages() -> void:
	for side: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
		var target: Variant = _edge_gallery(side)
		if target == null:
			continue
		var t: Vector2 = target
		# Première galerie de l'extension rencontrée en partant du bord, vers l'extérieur.
		var edge := Vector2(CaveShape.START_X0 if side.x < 0 else CaveShape.START_X1, t.y) if side.x != 0.0 else Vector2(t.x, CaveShape.START_Z0)
		var from: Variant = null
		var d := EXT_MARGIN
		while d < PASSAGE_SEARCH:
			var q := edge + side * d
			for o in [0.0, 4.0, -4.0, 8.0, -8.0, 12.0, -12.0, 16.0, -16.0, 20.0, -20.0, 24.0, -24.0, 28.0, -28.0, 32.0, -32.0]:
				var c: Vector2 = q + Vector2(-side.y, side.x) * o
				if ext_allowed(c.x, c.y) and is_gallery(c.x, c.y):
					from = c
					break
			if from != null:
				break
			d += 2.0
		if from == null:
			continue
		# Le bord du passage (rayon MIN_HALF_WIDTH) s'arrête à PASSAGE_GAP unités de la galerie d'origine.
		var stop := t + side * (PASSAGE_GAP + MIN_HALF_WIDTH)
		var start: Vector2 = from
		var bend := Vector2(start.x, stop.y) if side.x != 0.0 else Vector2(stop.x, start.y)
		_carve_axis_segment(start, bend)
		_carve_axis_segment(bend, stop)


## Segment horizontal ou vertical, échantillonné jusqu'à son extrémité.
func _carve_axis_segment(start: Vector2, stop: Vector2) -> void:
	var length := start.distance_to(stop)
	var steps := maxi(1, ceili(length / 1.5))
	for i in steps + 1:
		var point := start.lerp(stop, float(i) / steps)
		_stamp_free(point.x, point.y, MIN_HALF_WIDTH)



## Galerie de la zone d'origine la plus proche du bord `side` (hors salle et réserve).
func _edge_gallery(side: Vector2) -> Variant:
	var best: Variant = null
	var bs := -INF
	var z := CaveShape.START_Z0
	while z < CaveShape.START_Z1:
		var x := CaveShape.START_X0
		while x < CaveShape.START_X1:
			if is_gallery(x + 0.5, z + 0.5) and gallery_allowed(x + 0.5, z + 0.5):
				var sc := x * side.x if side.x != 0.0 else -z
				if sc > bs:
					bs = sc
					best = Vector2(x + 0.5, z + 0.5)
			x += 2.0
		z += 2.0
	return best


## _stamp sans règle de zone : bornes de la carte, flanc de la montagne et abords de la salle seulement.
func _stamp_free(cx: float, cz: float, r: float) -> void:
	for z in range(floori(cz - r), floori(cz + r) + 1):
		for x in range(floori(cx - r), floori(cx + r) + 1):
			var dx := x + 0.5 - cx
			var dz := z + 0.5 - cz
			if dx * dx + dz * dz > r * r:
				continue
			if x < CaveShape.WORLD_X0 + 10.0 or x > CaveShape.WORLD_X1 - 10.0 or z < CaveShape.WORLD_Z0 + 10.0 \
					or z + 0.5 > CaveShape.mountain_edge(x + 0.5) - 12.0 or (x > -76.0 and x < 76.0 and z > CaveShape.CAVE_Z0 - 28.0):
				continue
			var k := gal_idx(x, z)
			if k >= 0:
				mask[k] = 1


func _generate_ores() -> void:
	block_types.clear()
	permanent_ores.clear()
	wood_left.clear()
	grove_cells.clear()
	felled_groves.clear()
	lodes.clear()
	lode_cells.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# Une paire de cellules adjacentes par filon. La marge protège toute la salle initiale.
	var candidates: Array = [[], [], [], []]
	for j in range(-81, -21):
		for i in range(-55, 55, 2):
			var key := Vector2i(i, j)
			var center := Vector2(key * 4) + Vector2(2, 2)
			if center.x > -70 and center.x < 82 and center.y > -176 and center.y < -82:
				continue
			if absf(center.x) < 58 and center.y < CaveShape.CAVE_Z0 + 6:
				continue
			if center.y + 3 >= minf(CaveShape.mountain_edge(center.x), CaveShape.mountain_edge(center.x + 4)) - 8:
				continue
			var distance := center.distance_to(CaveShape.CORE)
			var next_distance := (center + Vector2(4, 0)).distance_to(CaveShape.CORE)
			for tier in ORE_BANDS.size():
				var band: Vector2 = ORE_BANDS[tier]
				if minf(distance, next_distance) >= band.x and maxf(distance, next_distance) <= band.y and _solid_pair(key):
					candidates[tier].append(key)
					break
	for tier in candidates.size():
		var pool: Array = candidates[tier]
		for n in mini(VEIN_COUNTS[tier], pool.size()):
			var index := rng.randi_range(n, pool.size() - 1)
			var key: Vector2i = pool[index]
			pool[index] = pool[n]
			var item: String = Blocks.ORES[tier]
			if groves and not TEMPLE_ORES.has(item):
				continue
			block_types[key] = item
			block_types[key + Vector2i.RIGHT] = item
			if n % 3 == 0 and LODE_COUNTS[tier] == 0:
				permanent_ores[key] = true
	if groves:
		_generate_extension_veins(rng)
	# Le premier filon affleure juste après la paroi ouest, en terrain sans galerie.
	block_types[Vector2i(-17, -39)] = "copper"
	if groves:
		_generate_lodes()
		_generate_groves()


## Minerai en paroi de l'extension : paires de cases pleines, minerai selon la profondeur dans la bande.
## Une paire de quartz sur trois est inépuisable (le quartz n'a pas de filon au sol).
func _generate_extension_veins(rng: RandomNumberGenerator) -> void:
	for k in Biomes.LIST.size():
		var want := roundi(_ext_area(k) / 100000.0 * float(Biomes.LIST[k]["veins"]))
		var r := Rng.new(rng.randi() ^ (k * 31337))
		var got := 0
		for t in want * 60:
			if got >= want:
				break
			var p: Variant = _ext_spot(r, k, 16.0)
			if p == null or p.y > CaveShape.mountain_edge(p.x) - 20.0:
				continue
			var key := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
			if block_types.has(key) or block_types.has(key + Vector2i.RIGHT) or not _solid_pair(key) \
					or not ext_allowed(key.x * 4.0 + 8.0, key.y * 4.0 + 2.0) or frontier_cell(key.x, key.y) or frontier_cell(key.x + 1, key.y):
				continue
			var items := Biomes.ores_at(k, Biomes.depth(k, p.y))
			if items.is_empty():
				continue
			var item: String = items[floori(r.next() * items.size())]
			block_types[key] = item
			block_types[key + Vector2i.RIGHT] = item
			if item == "quartz" and got % 3 == 0:
				permanent_ores[key] = true
			got += 1


## Les 4 cases (origine + 1 en i et j) et leur pourtour sont du sol libre : le bosquet ne ferme aucun passage.
func _grove_fits(origin: Vector2i) -> bool:
	for dj in range(-1, 3):
		for di in range(-1, 3):
			var key := origin + Vector2i(di, dj)
			if block_types.has(key) or grove_cells.has(key) or lode_cells.has(key) or pylon_cells.has(key):
				return false
			var x := key.x * 4.0
			var z := key.y * 4.0
			# Les 4 cases du bosquet entièrement libres ; le pourtour, au moins en son centre.
			var inner := di >= 0 and di <= 1 and dj >= 0 and dj <= 1
			var probes: Array = [Vector2(x + 0.5, z + 0.5), Vector2(x + 3.5, z + 0.5), Vector2(x + 0.5, z + 3.5), Vector2(x + 3.5, z + 3.5)] if inner else [Vector2(x + 2.0, z + 2.0)]
			for p: Vector2 in probes:
				if not (CaveShape.in_cave(p.x, p.y) or is_gallery(p.x, p.y)) or CaveShape.in_vault(p.x, p.y):
					return false
	return true


func _plant_grove(origin: Vector2i) -> void:
	wood_left[origin] = Blocks.WOOD_YIELD
	for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		grove_cells[origin + o] = origin
		block_types[origin + o] = Blocks.WOOD
		permanent_ores[origin + o] = true


## Salle de la Gorge-Cuivre : un point de galerie de la moitié nord du dernier biome, loin des bassins, élargi en disque.
func _carve_gorge_room(r: Rng) -> void:
	gorge_room = null
	var k := Biomes.LIST.size() - 1
	if k < 1:
		return
	for t in 400:
		var p: Variant = _ext_spot(r, k, GORGE_ROOM + 16.0)
		if p == null or Biomes.depth(k, p.y) < 0.45 or not is_gallery(p.x, p.y):
			continue
		if pools.any(func(o: Dictionary) -> bool: return (o["center"] as Vector2).distance_to(p) < GORGE_ROOM + POOL_RADIUS + 12.0):
			continue
		var was := _ext
		_ext = true
		_stamp(p.x, p.y, GORGE_ROOM)
		_ext = was
		gorge_room = p
		return


## Sylviculture : replante les bosquets abattus depuis `waves` vagues dont les quatre cases sont libres
## (`blocked` : test d'occupation d'une case par une unité, un bâtiment ou une défense). Renvoie les origines replantées.
func regrow_groves(wave: int, waves: int, blocked: Callable) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for origin: Vector2i in felled_groves.keys():
		if wave - int(felled_groves[origin]) < waves:
			continue
		var free := true
		for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var key := origin + o
			if block_types.has(key) or grove_cells.has(key) or lode_cells.has(key) or walls.has(key) or blocked.call(key):
				free = false
		if not free:
			continue
		_plant_grove(origin)
		felled_groves.erase(origin)
		out.append(origin)
	if not out.is_empty():
		version += 1
	return out


func _plant_lode(origin: Vector2i, item: String) -> void:
	lodes[origin] = item
	for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		lode_cells[origin + o] = origin
		block_types[origin + o] = item
		permanent_ores[origin + o] = true


## Un filon au cœur de chaque clairière de filon (emplacement déjà validé au creusement).
func _generate_lodes() -> void:
	for spot: Array in _lode_spots:
		var o: Vector2i = spot[0]
		if [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)].any(func(d: Vector2i) -> bool: return pylon_cells.has(o + d)):
			continue
		if groves and not TEMPLE_ORES.has(Blocks.ORES[spot[1]]):
			continue
		_plant_lode(o, Blocks.ORES[spot[1]])


## Clairières des filons : dans les galeries, à la distance du cœur propre à chaque palier de minerai.
func _carve_lode_clearings(r: Rng) -> void:
	_lode_spots.clear()
	# _grove_fits lit ces tables : celles de la carte précédente ne doivent pas gêner.
	block_types.clear()
	grove_cells.clear()
	lode_cells.clear()
	for tier in LODE_COUNTS.size():
		var band: Vector2 = ORE_BANDS[tier]
		var placed := 0
		var tries := 0
		while placed < LODE_COUNTS[tier] and tries < 6000:
			tries += 1
			var x := CaveShape.START_X0 + 20.0 + r.next() * (START_W - 40)
			var z := CaveShape.START_Z0 + 20.0 + r.next() * (START_H - 40)
			var d := Vector2(x, z).distance_to(CaveShape.CORE)
			# Palier trop étroit pour les galeries de cette carte : on élargit après 3000 essais.
			var slack := -6.0 if tries < 3000 else 24.0
			if d < band.x - slack or d > band.y + slack:
				continue
			if not is_gallery(x, z) or not gallery_allowed(x, z) or z > CaveShape.mountain_edge(x) - 24.0:
				continue
			var p := Vector2(x, z)
			# Loin de la réserve scellée du coffre antique : la clairière ne doit pas l'ouvrir.
			if p.distance_to(Vector2((CaveShape.VAULT_X0 + CaveShape.VAULT_X1) / 2.0, (CaveShape.VAULT_Z0 + CaveShape.VAULT_Z1) / 2.0)) < 30.0:
				continue
			if _clearings.any(func(c: Vector2) -> bool: return c.distance_to(p) < 32.0) \
					or _lode_spots.any(func(s: Array) -> bool: return Vector2((s[0] as Vector2i) * 4).distance_to(p) < 32.0):
				continue
			_stamp(x, z, CLEARING_RADIUS)
			var center := Vector2i(floori(x / 4.0) - 1, floori(z / 4.0) - 1)
			for o: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1)]:
				if _grove_fits(center + o) and not _lode_spots.any(func(s: Array) -> bool: return (s[0] as Vector2i).distance_to(center + o) < 4.0):
					_lode_spots.append([center + o, tier])
					placed += 1
					break


var _lode_spots: Array = []


# ---------------------------------------------------------------- Bassins souterrains
## Planche ambiances-montagne-detail.html, piste 01 : rares (POOL_COUNT par carte), chacun dans une
## clairière propre, loin des bosquets et des filons. Contour organique : métaballes × bruit.
const POOL_COUNT := 4
const POOL_RADIUS := 11.0
## Seuils du champ : berge mouillée, eau (contour), fosse infranchissable.
const POOL_WET := 0.55
const POOL_EDGE := 1.0
const POOL_DEEP := 2.0
## [{center: Vector2, balls: Array[Vector4](x, z, rx, rz), seed: int}]
var pools: Array[Dictionary] = []
## Cases (4 × 4) de fosse : infranchissables.
var water_cells := {}


## Champ du bassin au point (x, z) : > POOL_EDGE dans l'eau.
static func pool_field(pool: Dictionary, x: float, z: float) -> float:
	var f := 0.0
	for b: Vector4 in pool["balls"]:
		var dx := (x - b.x) / b.z
		var dz := (z - b.y) / b.w
		f += 1.0 / (dx * dx + dz * dz + 0.05)
	return f * (0.82 + 0.36 * Rng.vnoise(x / 0.9, z / 0.6, pool["seed"]))


func pool_at(x: float, z: float) -> Dictionary:
	for p in pools:
		if (p["center"] as Vector2).distance_to(Vector2(x, z)) < POOL_RADIUS + 2.0:
			return p
	return {}


func _carve_pools(r: Rng) -> void:
	pools.clear()
	water_cells.clear()
	var vault := Vector2((CaveShape.VAULT_X0 + CaveShape.VAULT_X1) / 2.0, (CaveShape.VAULT_Z0 + CaveShape.VAULT_Z1) / 2.0)
	var tries := 0
	while pools.size() < POOL_COUNT and tries < 6000:
		tries += 1
		var x := CaveShape.START_X0 + 24.0 + r.next() * (START_W - 48)
		var z := CaveShape.START_Z0 + 24.0 + r.next() * (START_H - 48)
		var p := Vector2(x, z)
		if not is_gallery(x, z) or not gallery_allowed(x, z) or z > CaveShape.mountain_edge(x) - 26.0:
			continue
		if p.distance_to(vault) < 34.0 or p.distance_to(CaveShape.CORE) < 70.0:
			continue
		if _clearings.any(func(c: Vector2) -> bool: return c.distance_to(p) < 36.0) \
				or _lode_spots.any(func(s: Array) -> bool: return Vector2((s[0] as Vector2i) * 4).distance_to(p) < 36.0) \
				or pools.any(func(o: Dictionary) -> bool: return (o["center"] as Vector2).distance_to(p) < 90.0):
			continue
		_add_pool(r, p)


func _add_pool(r: Rng, p: Vector2) -> void:
	var x := p.x
	var z := p.y
	_stamp(x, z, POOL_RADIUS)
	var balls: Array[Vector4] = [Vector4(x, z, 3.6 + r.next(), 1.9 + r.next() * 0.5)]
	for i in 2 + floori(r.next() * 3.0):
		var a := r.next() * TAU
		var d := 2.5 + r.next() * 2.5
		balls.append(Vector4(x + cos(a) * d, z + sin(a) * d * 0.6, 1.6 + r.next() * 1.4, 1.0 + r.next() * 0.7))
	var pool := {"center": p, "balls": balls, "seed": floori(r.next() * 100000.0)}
	pools.append(pool)
	for cj in range(floori((z - POOL_RADIUS) / 4.0), floori((z + POOL_RADIUS) / 4.0) + 1):
		for ci in range(floori((x - POOL_RADIUS) / 4.0), floori((x + POOL_RADIUS) / 4.0) + 1):
			if pool_field(pool, ci * 4.0 + 2.0, cj * 4.0 + 2.0) > POOL_DEEP:
				water_cells[Vector2i(ci, cj)] = true


## Abat le bosquet : ses cases redeviennent du sol libre.
func fell_grove(origin: Vector2i) -> void:
	wood_left.erase(origin)
	for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		grove_cells.erase(origin + o)
		block_types.erase(origin + o)
		permanent_ores.erase(origin + o)
		dig_hits.erase(origin + o)
		dig_hit_at.erase(origin + o)
	version += 1


## Clairières des galeries : élargit le masque autour de points tirés au hasard (avant l'étiquetage des réseaux).
func _carve_clearings(r: Rng) -> void:
	_clearings.clear()
	var tries := 0
	while _clearings.size() < GALLERY_GROVES and tries < 4000:
		tries += 1
		var x := CaveShape.START_X0 + 20.0 + r.next() * (START_W - 40)
		var z := CaveShape.START_Z0 + 20.0 + r.next() * (START_H - 40)
		if not is_gallery(x, z) or not gallery_allowed(x, z) or z > CaveShape.mountain_edge(x) - 24.0:
			continue
		if _clearings.any(func(c: Vector2) -> bool: return c.distance_to(Vector2(x, z)) < 40.0):
			continue
		_stamp(x, z, CLEARING_RADIUS)
		_clearings.append(Vector2(x, z))


var _clearings: Array[Vector2] = []


func _generate_groves() -> void:
	# Salle de départ : l'emplacement libre le plus proche du coin bas-droit.
	var best := Vector2i.ZERO
	var bd := INF
	for j in range(-40, -22):
		for i in range(0, 14):
			var origin := Vector2i(i, j)
			var d := (Vector2(origin * 4) + Vector2(4, 4)).distance_to(START_GROVE_AT)
			if d < bd and _grove_fits(origin):
				bd = d
				best = origin
	if bd < INF:
		_plant_grove(best)
	# Un bosquet au cœur de chaque clairière creusée dans les galeries.
	for c in _clearings:
		var center := Vector2i(floori(c.x / 4.0) - 1, floori(c.y / 4.0) - 1)
		for o: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1)]:
			if _grove_fits(center + o):
				_plant_grove(center + o)
				break


func _solid_pair(key: Vector2i) -> bool:
	for dz in 4:
		for dx in 8:
			if is_gallery(key.x * 4 + dx + 0.5, key.y * 4 + dz + 0.5):
				return false
	return true


func _stamp(cx: float, cz: float, r: float) -> void:
	var z := floori(cz - r)
	while z <= cz + r:
		var x := floori(cx - r)
		while x <= cx + r:
			var dx := x + 0.5 - cx
			var dz := z + 0.5 - cz
			if not (dx * dx + dz * dz > r * r or not _allowed(x + 0.5, z + 0.5)):
				var k := gal_idx(x, z)
				if k >= 0:
					mask[k] = 1
			x += 1
		z += 1


## `p` : réglages {room, branch} ; vide = ceux du biome sous le ver, à chaque pas.
const TUNNEL_DIRECTIONS := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]


## Le disque de demi-largeur minimale centré en (x, z) tient dans la zone permise (8 points du pourtour).
func _fits_wide(x: float, z: float) -> bool:
	var d := MIN_HALF_WIDTH - 0.5
	var e := d * 0.7071
	return _allowed(x + d, z) and _allowed(x - d, z) and _allowed(x, z + d) and _allowed(x, z - d) \
		and _allowed(x + e, z + e) and _allowed(x - e, z + e) and _allowed(x + e, z - e) and _allowed(x - e, z - e)


func _worm(r: Rng, x: float, z: float, direction: int, steps: int, radius: float, p: Dictionary) -> void:
	for s in steps:
		var cfg: Dictionary = p if not p.is_empty() else Biomes.at(z)
		var rr := radius * (0.8 + r.next() * 0.45)
		_stamp(x, z, maxf(rr, MIN_HALF_WIDTH) if groves else rr)
		if r.next() < float(cfg["room"]):  # salle plus large
			var sx := x + (r.next() - 0.5) * 3.0
			var sz := z + (r.next() - 0.5) * 3.0
			var rs := radius * (1.9 + r.next() * 0.9)
			_stamp(sx, sz, maxf(rs, MIN_HALF_WIDTH * 1.8) if groves else rs)
		if r.next() < float(cfg["branch"]) and steps > 20:  # embranchement
			var turn := 1 if r.next() < 0.5 else -1
			var branch := posmod(direction + turn, 4)
			_worm(r, x, z, branch, floori(steps * 0.45), radius * 0.85, p)
		# Des tronçons droits séparés par des virages à angle droit.
		if r.next() < 0.08:
			direction = posmod(direction + (1 if r.next() < 0.5 else -1), 4)
		var delta: Vector2 = TUNNEL_DIRECTIONS[direction] * 1.7
		var nx := x + delta.x
		var nz := z + delta.y
		# Hors parité JS, le disque minimal doit tenir dans la zone (sauf pour sortir d'un départ trop au bord).
		var fits := _allowed(nx, nz) and (not groves or _fits_wide(nx, nz) or not _fits_wide(x, z))
		if not fits:
			direction = posmod(direction + (1 if r.next() < 0.5 else -1), 4)
			continue
		x = nx
		z = nz


## Composantes connexes (une galerie = un réseau) et choix d'un portail maléfique par réseau,
## de préférence adossé à une paroi nord, devant un espace dégagé.
func _label_networks() -> void:
	var comp := PackedInt32Array()
	comp.resize(mask.size())
	count = 0
	for k0 in mask.size():
		if mask[k0] == 0 or comp[k0] != 0:
			continue
		count += 1
		var stack: Array[int] = [k0]
		while not stack.is_empty():
			var k: int = stack.pop_back()
			if k < 0 or k >= mask.size() or mask[k] == 0 or comp[k] != 0:
				continue
			comp[k] = count
			var i := k % GAL_W
			if i > 0:
				stack.append(k - 1)
			if i < GAL_W - 1:
				stack.append(k + 1)
			stack.append(k - GAL_W)
			stack.append(k + GAL_W)
	var best := {}
	var m := mask
	for k in m.size():
		var id := comp[k]
		if id == 0:
			continue
		var i := k % GAL_W
		var j := (k - i) / GAL_W
		# Pas de pylône dans la salle de l'Œil ni dans son couloir.
		if frontier and (in_eye_room(i + CaveShape.WORLD_X0 + 0.5, j + CaveShape.WORLD_Z0 + 0.5, PYLON_CHAMBER + 4.0) \
				or _in_eye_corridor(i + CaveShape.WORLD_X0 + 0.5, j + CaveShape.WORLD_Z0 + 0.5)):
			continue
		var sc := 0
		for b in 6:
			var jb := j + b
			if jb >= GAL_H:
				break
			var row := jb * GAL_W
			for a in range(maxi(-3, -i), mini(4, GAL_W - i)):
				sc += m[row + i + a]
		if not _m(i, j - 1) and not _m(i - 1, j - 1) and not _m(i + 1, j - 1):
			sc += 100
		if not best.has(id) or sc > best[id]["sc"]:
			best[id] = {"sc": sc, "x": i + CaveShape.WORLD_X0 + 0.5, "z": j + CaveShape.WORLD_Z0 + 0.5}
	portals.clear()
	var ids := best.keys()
	ids.sort()
	# Réseaux de la zone d'origine d'abord (ordre du prototype), puis ceux de l'extension.
	var inner := ids.filter(func(id: int) -> bool: return CaveShape.in_start(best[id]["x"], best[id]["z"]))
	ids = inner + ids.filter(func(id: int) -> bool: return not inner.has(id))
	for n in ids.size():
		var pz: float = best[ids[n]]["z"]
		portals.append({"id": n, "x": best[ids[n]]["x"], "z": pz, "active": false, "next": 0.0, "threat": int(Biomes.at(pz)["threat"])})


## Pylônes de Merenor à la place des portails maléfiques : centre sur un coin de case, un peu au sud de la
## paroi choisie par _label_networks, salle creusée autour, socle de 2 × 2 cases. Hors parité JS (groves).
func _place_pylons() -> void:
	var was := _ext
	for p: Dictionary in portals:
		_ext = not CaveShape.in_start(float(p["x"]), float(p["z"]))
		var base := Vector2(roundf(float(p["x"]) / 4.0) * 4.0, roundf((float(p["z"]) + 7.0) / 4.0) * 4.0)
		var c := base
		# Au plus près du portail d'origine, une place où la salle entière est permise (loin de la salle de
		# départ, des bords de la carte et du flanc de la montagne).
		var found := false
		for r in range(0, 40, 4):
			for k in (1 if r == 0 else 8):
				var q := base + (Vector2.from_angle(k * TAU / 8.0) * r).snapped(Vector2(4, 4))
				if _chamber_fits(q):
					c = q
					found = true
					break
			if found:
				break
		# Jamais à cheval sur la frontière : la salle du pylône y ouvrirait un passage.
		if frontier and absf(c.y - frontier_z()) < FRONTIER_HALF + PYLON_CHAMBER:
			var s := 1.0 if c.y >= frontier_z() else -1.0
			c.y = snappedf(frontier_z() + s * (FRONTIER_HALF + PYLON_CHAMBER + 4.0), 4.0)
		_stamp(c.x, c.y, PYLON_CHAMBER)
		p["x"] = c.x
		p["z"] = c.y
		p["threat"] = int(Biomes.at(c.y)["threat"])
		var ci := floori(c.x / 4.0)
		var cj := floori(c.y / 4.0)
		for o: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
			pylon_cells[Vector2i(ci, cj) + o] = int(p["id"])
	_ext = was


func _chamber_fits(c: Vector2) -> bool:
	if not _allowed(c.x, c.y):
		return false
	if frontier and (in_eye_room(c.x, c.y, PYLON_CHAMBER + 4.0) or absf(c.y - frontier_z()) < FRONTIER_HALF + PYLON_CHAMBER):
		return false
	for k in 16:
		var q := c + Vector2.from_angle(k * TAU / 16.0) * PYLON_CHAMBER
		if not _allowed(q.x, q.y):
			return false
	return true


# ---------------------------------------------------------------- Salles à thème
## Salles à thème du Temple (planche sanctum-decor-propositions.html, sim/sanctum.gd) : pièces rectangulaires
## taillées sur la grille de minage, à cheval sur une galerie existante, loin des pylônes, clairières, filons et
## bassins. 5 × 3 cases (20 × 12 u) ; la citerne en fait 7 × 5, avec un bassin infranchissable autour d'un îlot.
## Hors parité JS (groves). [{kind, x, z (centre), half: Vector2i (demi-emprise en cases)}]
const THEME_KINDS := ["crypt", "library", "armory", "oratory", "cistern"]
const THEME_ROOMS := 15
const THEME_GAP := 64.0
var theme_rooms: Array[Dictionary] = []


func _carve_theme_rooms(r: Rng) -> void:
	var was := _ext
	var vault := Vector2((CaveShape.VAULT_X0 + CaveShape.VAULT_X1) / 2.0, (CaveShape.VAULT_Z0 + CaveShape.VAULT_Z1) / 2.0)
	var z_north := maxf(CaveShape.WORLD_Z0 + 24.0, frontier_z() + FRONTIER_HALF + 20.0)
	var tries := 0
	while theme_rooms.size() < THEME_ROOMS and tries < 12000:
		tries += 1
		var kind: String = THEME_KINDS[theme_rooms.size() % THEME_KINDS.size()]
		var half := Vector2i(3, 2) if kind == "cistern" else Vector2i(2, 1)
		var ci := floori((CaveShape.WORLD_X0 + 28.0 + r.next() * (GAL_W - 56)) / 4.0)
		var cj := floori((z_north + r.next() * (-112.0 - z_north)) / 4.0)
		var c := Vector2(ci * 4.0 + 2.0, cj * 4.0 + 2.0)
		if not is_gallery(c.x, c.y) or c.y > CaveShape.mountain_edge(c.x) - 30.0:
			continue
		_ext = not CaveShape.in_start(c.x, c.y)
		var ext := Vector2(half.x * 4.0 + 6.0, half.y * 4.0 + 6.0)
		var fits := true
		for o: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(0, -1), Vector2(0, 1)]:
			if not _allowed(c.x + o.x * ext.x, c.y + o.y * ext.y):
				fits = false
		if not fits or in_eye_room(c.x, c.y, 26.0) or c.distance_to(vault) < 44.0 or c.distance_to(CaveShape.CORE) < 80.0:
			continue
		if theme_rooms.any(func(o: Dictionary) -> bool: return Vector2(o["x"], o["z"]).distance_to(c) < THEME_GAP) \
				or portals.any(func(p: Dictionary) -> bool: return Vector2(p["x"], p["z"]).distance_to(c) < PYLON_CHAMBER + 22.0) \
				or _clearings.any(func(p: Vector2) -> bool: return p.distance_to(c) < 34.0) \
				or _lode_spots.any(func(s: Array) -> bool: return Vector2((s[0] as Vector2i) * 4).distance_to(c) < 34.0) \
				or pools.any(func(p: Dictionary) -> bool: return (p["center"] as Vector2).distance_to(c) < 36.0):
			continue
		for dj in range(-half.y, half.y + 1):
			for di in range(-half.x, half.x + 1):
				for uz in 4:
					for ux in 4:
						var k := gal_idx((ci + di) * 4.0 + ux, (cj + dj) * 4.0 + uz)
						if k >= 0:
							mask[k] = 1
		if kind == "cistern":
			for dj in range(-1, 2):
				for di in range(-2, 3):
					if di != 0 or dj < 0:
						water_cells[Vector2i(ci + di, cj + dj)] = true
		theme_rooms.append({"kind": kind, "x": c.x, "z": c.y, "half": half})
	_ext = was


func _m(i: int, j: int) -> bool:
	return i >= 0 and j >= 0 and i < GAL_W and j < GAL_H and mask[j * GAL_W + i] == 1


## Empreinte SHA-1 du masque (comparée aux valeurs du prototype dans les tests).
## Calculée sur la zone d'origine seule, dans la disposition du prototype (464 × 408).
func mask_sha1() -> String:
	return _sha1(start_window(mask))


func open_sha1() -> String:
	return _sha1(start_window(open))


static func start_window(bytes: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	var i0 := int(CaveShape.START_X0 - CaveShape.WORLD_X0)
	for j in range(int(CaveShape.START_Z0 - CaveShape.WORLD_Z0), int(CaveShape.START_Z1 - CaveShape.WORLD_Z0)):
		out.append_array(bytes.slice(j * GAL_W + i0, j * GAL_W + i0 + START_W))
	return out


static func _sha1(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA1)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


# ---------------------------------------------------------------- Cases à creuser (adepts.js)

## digCellAt : case de roche visée, accessible depuis un sol praticable voisin ; null sinon.
## Renvoie {i, j, at: Vector2} où `at` est la position de travail de l'Ingénieur.
func block_definition(i: int, j: int) -> Dictionary:
	var key := Vector2i(i, j)
	if block_types.has(key):
		return Blocks.TYPES.get(block_types[key], {})
	# Roche nue : celle du biome de la case (plus dure au nord du Temple). La parité JS reste en roche simple.
	return Blocks.TYPES.get(String(Biomes.at(j * 4.0 + 2.0).get("rock", "rock")) if groves else "rock", {})


## Recherche qui manque pour entamer cette case ("" si elle se creuse) : le sceau de sa roche.
func seal_needed(i: int, j: int) -> String:
	var seal := String(block_definition(i, j).get("seal", ""))
	return "" if seal == "" or GameState.research_done.has(seal) else seal


func dig_cell_at(i: int, j: int, p: Vector2) -> Variant:
	if not minable_block(i, j):
		return null
	var x := i * 4.0
	var z := j * 4.0
	var at: Variant = null
	var best := 1e9
	for t: float in [0.3, 1.0, 2.0, 3.0, 3.7]:
		for q: Vector2 in [Vector2(x - 0.6, z + t), Vector2(x + 4.6, z + t), Vector2(x + t, z - 0.6), Vector2(x + t, z + 4.6)]:
			if not walkable(q.x, q.y):
				continue
			var d := q.distance_to(p)
			if d < best:
				best = d
				at = q
	return {"i": i, "j": j, "at": at} if at != null else null


## Relief dessiné d'une roche (vue 3/4) : la paroi face5 (32 × 49 px, ancrée à 45 px) d'une case dont le sud est
## du sol monte de FACE_RISE au-dessus de son bord sud et déborde de FACE_DROP dessous ; une roche isolée (sol au
## nord) porte en plus son chapeau (World._attach_rock_cap, 32 px) au-dessus de la paroi. Le reste de la roche
## est peint à son emprise au sol. Unités de monde, axe z.
const FACE_RISE := 45.0 / 8.0
const FACE_DROP := 4.0 / 8.0


## Roche (pas de creux) au centre de la case (i, j).
func rock_cell(i: int, j: int) -> bool:
	return not ground(i * 4.0 + 2.0, j * 4.0 + 2.0)


## La case de roche (i, j) montre une paroi : sol juste au sud.
func faced_cell(i: int, j: int) -> bool:
	return rock_cell(i, j) and ground(i * 4.0 + 2.0, j * 4.0 + 6.0)


## Étendue verticale dessinée (z haut, z bas, ramenés au sol) de la case de roche (i, j) : paroi (et chapeau
## d'une roche isolée), ou emprise au sol moins le pied de la paroi voisine au sud qui la recouvre.
func drawn_span(i: int, j: int) -> Vector2:
	var south := (j + 1) * 4.0
	if faced_cell(i, j):
		var top := south - FACE_RISE - (4.0 if ground(i * 4.0 + 2.0, j * 4.0 - 2.0) else 0.0)
		return Vector2(top, south + FACE_DROP)
	return Vector2(south - 4.0, south - (FACE_RISE - 4.0 if faced_cell(i, j + 1) else 0.0))


## Case de roche dessinée sous le point `p` (sol sous le pointeur) : la paroi (ou le chapeau) la plus au sud qui
## le couvre, dessinée devant, sinon la roche peinte sous lui ; null sur du sol nu.
func visual_block(p: Vector2) -> Variant:
	var i := floori(p.x / 4.0)
	var j0 := floori(p.y / 4.0)
	for j: int in [j0 + 2, j0 + 1, j0, j0 - 1]:
		if not faced_cell(i, j):
			continue
		var span := drawn_span(i, j)
		if p.y >= span.x and p.y <= span.y:
			return Vector2i(i, j)
	if rock_cell(i, j0):
		return Vector2i(i, j0)
	return null


## Case minable désignée par le dessin sous `p` (visual_block), avec son point de travail ; null si elle est
## enfouie (aucun côté dégagé) ou ne se mine pas.
func pointed_cell(p: Vector2) -> Variant:
	var key: Variant = visual_block(p)
	if key == null:
		return null
	return dig_cell_at(key.x, key.y, p)


## Bloc (i, j) qu'on pourrait miner, même encore enfoui (aucun côté dégagé) : il le deviendra une fois un voisin
## creusé. dig_cell_at y ajoute un point de travail praticable.
func minable_block(i: int, j: int) -> bool:
	if block_definition(i, j).is_empty() or frontier_cell(i, j):
		return false
	var key := Vector2i(i, j)
	if key == VAULT_COPPER and permanent_ores.has(key) and not vault_open:
		return false
	if dug.has(key) or (not permanent_ores.has(key) and cell_clear(i, j)):
		return false
	var x := i * 4.0
	var z := j * 4.0
	return not (x < CaveShape.WORLD_X0 + 8.0 or x + 4.0 > CaveShape.WORLD_X1 - 8.0 or z < CaveShape.WORLD_Z0 + 8.0)


## Case (i, j) entièrement dégagée : centre, coins et les 16 sous-cases praticables (plus rien à miner).
func cell_clear(i: int, j: int) -> bool:
	var x := i * 4.0
	var z := j * 4.0
	return walkable(x + 2.0, z + 2.0) and walkable(x + 0.5, z + 0.5) and walkable(x + 3.5, z + 3.5) \
		and not _has_rock_sliver(x, z)


## Reste de roche dans la case 4 × 4 d'origine (x, z) : une des 16 sous-cases d'une unité (résolution du
## masque des galeries) n'est pas du sol. Les 3 points de dig_cell_at laissent sinon passer un pilier fin,
## infranchissable mais impossible à miner.
func _has_rock_sliver(x: float, z: float) -> bool:
	for a in 4:
		for b in 4:
			if not ground(x + a + 0.5, z + b + 0.5):
				return true
	return false


## diggableCell : case la plus pertinente autour d'un point de roche cliqué.
func diggable_cell(p: Vector2) -> Variant:
	var target := Vector2i((p / 4.0).floor())
	if permanent_ores.has(target):
		return dig_cell_at(target.x, target.y, p)
	if walkable(p.x, p.y):
		return null
	var i0 := floori(p.x / 4.0)
	var j0 := floori(p.y / 4.0)
	var best: Variant = null
	var bd := 1e9
	for di in range(-1, 2):
		for dj in range(-1, 2):
			var c: Variant = dig_cell_at(i0 + di, j0 + dj, p)
			if c == null:
				continue
			var d := (100.0 if di != 0 or dj != 0 else 0.0) + (c["at"] as Vector2).distance_to(p)
			if d < bd:
				bd = d
				best = c
	return best


## nextDig : case de roche voisine (4 directions) la plus proche de l'Ingénieur, ou null.
func next_dig_cell(cell: Dictionary, from: Vector2) -> Variant:
	var best: Variant = null
	var bd := 1e9
	for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Variant = dig_cell_at(cell["i"] + o.x, cell["j"] + o.y, from)
		if n == null:
			continue
		var d := (n["at"] as Vector2).distance_to(from)
		if d < bd:
			bd = d
			best = n
	return best


## La case (i, j), une fois creusée, touche la réserve : recouvrement ou bord commun (pas un simple coin).
static func cell_touches_vault(i: int, j: int) -> bool:
	var ox := minf(i * 4.0 + 4.0, CaveShape.VAULT_X1) - maxf(i * 4.0, CaveShape.VAULT_X0)
	var oz := minf(j * 4.0 + 4.0, CaveShape.VAULT_Z1) - maxf(j * 4.0, CaveShape.VAULT_Z0)
	return (ox > 0.0 and oz >= 0.0) or (oz > 0.0 and ox >= 0.0)


## Point de la case (i, j) le plus proche de p.
static func cell_nearest(i: int, j: int, p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, i * 4.0, i * 4.0 + 4.0), clampf(p.y, j * 4.0, j * 4.0 + 4.0))


## Le lance-pitons atteint la case (i, j) depuis p : face à l'un de ses côtés (dans le prolongement de la
## case, jamais en diagonale par un coin), au plus DIG_REACH unités du bord, et un passage dégagé (sol
## praticable) entre l'Ingénieur et la case : on ne tire pas à travers la roche, et la case creusée reste
## reliée au sol où il se tient.
func in_dig_reach(i: int, j: int, p: Vector2, reach := DIG_REACH) -> bool:
	var x := i * 4.0
	var z := j * 4.0
	var facing_x := p.x >= x + 0.3 and p.x <= x + 3.7
	var facing_z := p.y >= z + 0.3 and p.y <= z + 3.7
	if facing_x == facing_z:
		return false
	var q := cell_nearest(i, j, p)
	var d := p.distance_to(q)
	if d > reach:
		return false
	var n := ceili(d / 0.4)
	for k in range(1, n):
		var s := p.lerp(q, float(k) / n)
		if s.distance_to(q) < 0.3:
			break
		if not walkable(s.x, s.y):
			return false
	return true
