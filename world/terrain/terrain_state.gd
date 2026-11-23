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
## Minerais qui ont des filons au sol dans l’extension (filons.png n’a que cuivre, fer et or ; les autres restent en paroi).
const LODE_ORES: Array[String] = ["copper", "iron", "gold"]
## Minerais que porte le Temple (décision du 2026-11-20) : les veines et filons des autres paliers de la zone
## d'origine ne sont plus posés (leurs tirages et leurs clairières restent, pour ne rien déplacer d'autre).
## La parité JS (groves = false) garde les quatre.
const TEMPLE_ORES: Array[String] = ["copper"]
var dig_hits := {}
## Instant (sim_time) du dernier piton tiré sur chaque case en cours : rendu des pitons plantés.
var dig_hit_at := {}

## Réserve du coffre antique (CaveShape.in_vault) découverte : elle devient creuse et praticable.
var vault_open := false

# ----- Biomes en salles (world/terrain/room_layout.gd, planches/biomes-salles-structure.html, 2026-11-22) -----
## Hors parité JS (groves) : le Temple n'a plus de vers, mais ~40 salles taillées d'après RoomLayout.build_temple.
## Plan du Temple (résultat de RoomLayout) ; vide en parité JS.
var temple_layout := {}
## Case (Vector2i) → id de la salle du plan qui la couvre (salles taillées et grotte, pas les couloirs).
var room_at := {}
## Murs de quartier : cases impossibles à creuser (comme la roche de frontière).
var room_walls := {}
## Portes entre quartiers : case → clef (« mb1 », « mb2 ») ; doors_closed[clef] vrai = infranchissable.
## Ouvertes tant que les mini-boss ne sont pas dans leur arène (choix du 2026-11-22).
var door_cells := {}
var doors_closed := {}
var _any_door_closed := false
## Palier de menace des pylônes du Temple, par quartier (C : un palier de plus, comme ses salles).
const TEMPLE_PYLON_TIER := {"A": 1, "B": 2, "C": 3}

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
	if _any_door_closed and door_cells.has(c) and doors_closed.get(door_cells[c], false):
		return false
	return not (eye_gate_closed and eye_gate.has(c))


## Ferme ou ouvre la porte de quartier `key` (« mb1 », « mb2 ») ; les chemins en cache sont invalidés.
func set_door_closed(key: String, closed: bool) -> void:
	doors_closed[key] = closed
	_any_door_closed = doors_closed.values().has(true)
	version += 1


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
## Rivière, chemins et flore déjà construits pour une graine (jungle(), 2026-11-22) : generate_galleries les
## reprend au lieu de les refaire. Ils ne dépendent que de la graine.
var prebuilt := {}


## Rivière, chemins et flore de la graine, construits à part : World les fait au début du chargement pour
## lancer tout de suite le calcul de leurs images sur des fils de travail.
static func jungle(new_seed: int) -> Dictionary:
	var river := River.new(new_seed)
	var road := Road.new(new_seed, river)
	return {"seed": new_seed, "river": river, "road": road, "flora": Flora.new(new_seed, river, road)}
## Roche laissée pleine de chaque côté d'une frontière de strate (au-delà du biome 2).
const BAND_GAP := 10.0
var _zmin := -INF
var _zmax := INF
## Réglages des vers de la zone d'origine (prototype) ; l'extension lit ceux de son biome (data/biomes.gd).
const START_WORM := {"room": 0.05, "branch": 0.025}
## Passages vers la zone d'origine : la galerie s'arrête à PASSAGE_GAP unités d'une galerie d'origine.
const PASSAGE_GAP := 6.0
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
	return (ext_allowed(x, z) and z >= _zmin and z <= _zmax) if _ext else gallery_allowed(x, z)


## Bornes en z des galeries tracées pour la bande k (2026-11-22, six strates) : de la roche pleine sépare
## chaque strate de la suivante, pour qu'aucune galerie ne contourne un sceau. Temple et Veines gardent leur
## ancienne borne nord (bord de carte d'alors, z −734) : leur carte ne change pas avec les strates.
func _band_limits(k: int) -> void:
	var lim := band_range(k)
	_zmin = lim.x
	_zmax = lim.y


static func band_range(k: int) -> Vector2:
	if k <= 1:
		return Vector2(Biomes.north_z(1) + BAND_GAP if Biomes.LIST.size() > 2 else -INF, INF)
	var n := Biomes.north_z(k)
	return Vector2((CaveShape.WORLD_Z0 if n == -INF else n) + BAND_GAP, Biomes.south_z(k) - BAND_GAP)


func generate_galleries(new_seed: int) -> void:
	seed = new_seed
	var r := Rng.new(new_seed)
	_band_limits(0)
	frontier = false
	eye_gate.clear()
	eye_gate_closed = false
	# Vidés dès le début : les clairières et les filons les consultent (_grove_fits) avant que les pylônes de
	# cette carte soient posés ; ceux de la carte précédente déplaçaient filons et bassins d'une instance réutilisée.
	pylon_cells.clear()
	theme_rooms.clear()
	temple_layout = {}
	room_at.clear()
	room_walls.clear()
	door_cells.clear()
	doors_closed.clear()
	_any_door_closed = false
	mask.fill(0)
	open.fill(0)
	found = 0
	version += 1
	var n := 12 + floori(r.next() * 5.0)
	# Biomes en salles : hors parité JS, plus de vers dans la zone d'origine ; le Temple est taillé en salles.
	for g in (0 if groves else n):
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
		_carve_temple_rooms(new_seed)
	_clearings.clear()
	if groves and int(prebuilt.get("seed", -1)) == new_seed:
		river = prebuilt["river"]
		road = prebuilt["road"]
		flora = prebuilt["flora"]
	else:
		river = River.new(new_seed) if groves else null
		road = Road.new(new_seed, river) if groves else null
		flora = Flora.new(new_seed, river, road) if groves else null
	prebuilt = {}
	if groves:
		# Temple en salles : bosquets, filons et bassin vont dans ses salles (_furnish_temple_rooms), plus dans les
		# galeries de la zone d'origine.
		_lode_spots.clear()
		block_types.clear()
		grove_cells.clear()
		lode_cells.clear()
		pools.clear()
		water_cells.clear()
		_carve_extension_features(new_seed)
		_furnish_temple_rooms(Rng.new(new_seed ^ 0x5a11))
		_carve_gorge_room(Rng.new(new_seed ^ 0x60c6))
		# Galeries reliées (2026-11-22) : plus de passages arrêtés à une ou deux cases, _connect_networks
		# rattache tout à la grotte de départ (et les Veines au couloir de l'Œil).
		_carve_frontier()
	else:
		pools.clear()
		water_cells.clear()
		gorge_room = null
	_label_networks()
	pylon_cells.clear()
	theme_rooms.clear()
	link_cells.clear()
	path_d = PackedInt32Array()
	raid_first_day = 0
	if groves:
		_connect_networks()
		_place_pylons()
		_place_temple_theme_rooms(Rng.new(new_seed ^ 0x5a2c))
		_compute_path_d()
		_seal_closed_doors()
	_generate_ores()


## Galeries de l'extension, bande de biome par bande de biome (une graine par biome : changer les réglages
## d'un biome ne déplace rien ailleurs).
func _generate_extension(r: Rng) -> void:
	var base := floori(r.next() * 1e9)
	_ext = true
	for k in Biomes.LIST.size():
		# Le Temple est taillé en salles (_carve_temple_rooms) : pas de vers.
		if k == 0:
			continue
		_band_limits(k)
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
	_band_limits(0)


## Surface (u²) de l'extension dans la bande du biome k, estimée sur une grille de 8 unités.
func _ext_area(k: int) -> float:
	var n := 0
	var lim := band_range(k)
	var z := CaveShape.WORLD_Z0 + 4.0
	while z < CaveShape.WORLD_Z1:
		if Biomes.index_at(z) == k and z >= lim.x and z <= lim.y:
			var x := CaveShape.WORLD_X0 + 4.0
			while x < CaveShape.WORLD_X1:
				if ext_allowed(x, z):
					n += 1
				x += 8.0
		z += 8.0
	return n * 64.0


## Point tiré au hasard dans la bande du biome k (extension, à `margin` des bords de la carte) ; null après 400 essais.
func _ext_spot(r: Rng, k: int, margin: float) -> Variant:
	# Le Temple garde son tirage d'avant les strates ; au-delà, la marge s'applique aussi aux frontières de bande.
	var z0 := maxf(CaveShape.WORLD_Z0 + margin, Biomes.north_z(k)) if k == 0 else maxf(CaveShape.WORLD_Z0, Biomes.north_z(k)) + margin
	var z1 := minf(CaveShape.WORLD_Z1 - margin, Biomes.south_z(k)) if k <= 1 else Biomes.south_z(k) - margin
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
		# Le Temple meuble ses salles de ressources à part (_furnish_temple_rooms).
		if k == 0:
			continue
		_band_limits(k)
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
			var items := Biomes.ores_at(k, Biomes.depth(k, p.y)).filter(func(o: String) -> bool: return LODE_ORES.has(o))
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
	_band_limits(0)


## Segment horizontal ou vertical, échantillonné jusqu'à son extrémité.
func _carve_axis_segment(start: Vector2, stop: Vector2) -> void:
	var length := start.distance_to(stop)
	var steps := maxi(1, ceili(length / 1.5))
	for i in steps + 1:
		var point := start.lerp(stop, float(i) / steps)
		_stamp_free(point.x, point.y, MIN_HALF_WIDTH)



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
			# Aucun minerai dans un mur de quartier : il serait impossible à extraire.
			if room_walls.has(key) or room_walls.has(key + Vector2i.RIGHT):
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
		_generate_jungle_groves()
		_generate_jungle_stone()


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
					or not ext_allowed(key.x * 4.0 + 8.0, key.y * 4.0 + 2.0) or frontier_cell(key.x, key.y) or frontier_cell(key.x + 1, key.y) \
					or room_walls.has(key) or room_walls.has(key + Vector2i.RIGHT):
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


## Salle de la Gorge-Cuivre : un point de galerie de la moitié nord du biome 2, loin des bassins, élargi en disque.
func _carve_gorge_room(r: Rng) -> void:
	gorge_room = null
	var k := Biomes.index_of("biome2")
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


## Bosquets de la jungle (2026-11-22) : deux de part et d'autre de la porte de la caverne, puis une poignée
## semée dans la jungle, des deux côtés de la rivière. Jamais sur l'eau, la berge, un pont, le chemin ou la route.
const JUNGLE_DOOR_GROVES: Array[Vector2] = [Vector2(-18.0, -68.0), Vector2(18.0, -68.0)]
const JUNGLE_GROVES := 14


func _jungle_grove_fits(origin: Vector2i) -> bool:
	for dj in range(-1, 3):
		for di in range(-1, 3):
			var key := origin + Vector2i(di, dj)
			if block_types.has(key) or grove_cells.has(key) or lode_cells.has(key) or pylon_cells.has(key) or water_cells.has(key):
				return false
			for p: Vector2 in [Vector2(key.x * 4.0 + 0.5, key.y * 4.0 + 0.5), Vector2(key.x * 4.0 + 3.5, key.y * 4.0 + 3.5),
					Vector2(key.x * 4.0 + 3.5, key.y * 4.0 + 0.5), Vector2(key.x * 4.0 + 0.5, key.y * 4.0 + 3.5)]:
				if not CaveShape.outdoors(p.x, p.y - 2.0) or p.y > CaveShape.WORLD_Z1 - 6.0 or absf(p.x) > CaveShape.WORLD_X1 - 8.0:
					return false
				if CaveShape.in_path(p.x, p.y) or (river != null and river.clear_of_decor(p.x, p.y)):
					return false
				if road != null and road.on_road(p.x, p.y, 2.0):
					return false
	return true


func _generate_jungle_groves() -> void:
	# Près de la porte : l'emplacement libre le plus proche de chaque point visé.
	for want: Vector2 in JUNGLE_DOOR_GROVES:
		var best := Vector2i.ZERO
		var bd := INF
		var c := Vector2i(floori(want.x / 4.0), floori(want.y / 4.0))
		for dj in range(-4, 5):
			for di in range(-4, 5):
				var origin := c + Vector2i(di, dj)
				var d := (Vector2(origin * 4) + Vector2(4, 4)).distance_to(want)
				if d < bd and _jungle_grove_fits(origin):
					bd = d
					best = origin
		if bd < INF:
			_plant_grove(best)
	# Ailleurs dans la jungle, espacés d'au moins 40 unités.
	var r := Rng.new(seed ^ 0x6b05)
	var placed: Array[Vector2] = []
	placed.append_array(JUNGLE_DOOR_GROVES)
	for t in JUNGLE_GROVES * 60:
		if placed.size() >= JUNGLE_GROVES + JUNGLE_DOOR_GROVES.size():
			break
		var x := CaveShape.WORLD_X0 + 12.0 + r.next() * (CaveShape.WORLD_X1 - CaveShape.WORLD_X0 - 24.0)
		var z := CaveShape.mountain_edge(x) + 6.0 + r.next() * (CaveShape.WORLD_Z1 - CaveShape.mountain_edge(x) - 14.0)
		var p := Vector2(x, z)
		if placed.any(func(q: Vector2) -> bool: return q.distance_to(p) < 40.0):
			continue
		var origin := Vector2i(floori(x / 4.0), floori(z / 4.0))
		if _jungle_grove_fits(origin):
			_plant_grove(origin)
			placed.append(p)


## Filons de pierre illimités de la jungle (2026-11-22) : près de l'entrée, mais plus à l'écart que le chemin et
## que les deux bosquets de la porte (points visés à ±34 en x).
const JUNGLE_STONE_LODES: Array[Vector2] = [Vector2(-36.0, -62.0), Vector2(36.0, -58.0)]


func _generate_jungle_stone() -> void:
	for want: Vector2 in JUNGLE_STONE_LODES:
		var best := Vector2i.ZERO
		var bd := INF
		var c := Vector2i(floori(want.x / 4.0), floori(want.y / 4.0))
		for dj in range(-4, 5):
			for di in range(-4, 5):
				var origin := c + Vector2i(di, dj)
				var d := (Vector2(origin * 4) + Vector2(4, 4)).distance_to(want)
				if d < bd and _jungle_grove_fits(origin):
					bd = d
					best = origin
		if bd < INF:
			_plant_lode(best, "rock")


func _solid_pair(key: Vector2i) -> bool:
	for dz in 4:
		for dx in 8:
			if is_gallery(key.x * 4 + dx + 0.5, key.y * 4 + dz + 0.5):
				return false
	return true


func _stamp(cx: float, cz: float, r: float) -> void:
	# Disque entier dans la zone permise : plus de test par case (même résultat, bien plus rapide).
	var clear := _clear_box(cx - r - 1.0, cz - r - 1.0, cx + r + 1.0, cz + r + 1.0)
	var r2 := r * r
	var z := floori(cz - r)
	while z <= cz + r:
		var x := floori(cx - r)
		var dz := z + 0.5 - cz
		var j := z - int(CaveShape.WORLD_Z0)
		while x <= cx + r:
			var dx := x + 0.5 - cx
			if dx * dx + dz * dz <= r2 and (clear or _allowed(x + 0.5, z + 0.5)):
				var i := x - int(CaveShape.WORLD_X0)
				if i >= 0 and j >= 0 and i < GAL_W and j < GAL_H:
					mask[j * GAL_W + i] = 1
			x += 1
		z += 1


## Tout le rectangle [x0, x1] × [z0, z1] est permis pour l'extension (bande en cours comprise) : vrai
## seulement si chaque point l'est (bords de carte, flanc, zone d'origine, bornes de bande) ; faux sinon,
## ou hors extension (la zone d'origine garde son test point par point).
func _clear_box(x0: float, z0: float, x1: float, z1: float) -> bool:
	if not _ext:
		return false
	if x0 < CaveShape.WORLD_X0 + 10.0 or x1 > CaveShape.WORLD_X1 - 10.0 or z0 < CaveShape.WORLD_Z0 + 10.0:
		return false
	if z0 < _zmin or z1 > _zmax:
		return false
	# Flanc : mountain_edge ≥ EDGE_BASE − 7 (deux sinus d'amplitudes 4 et 3).
	if z1 > CaveShape.EDGE_BASE - CaveShape.EDGE_WAVES.x - CaveShape.EDGE_WAVES.z - 12.0:
		return false
	return x1 <= CaveShape.START_X0 - EXT_MARGIN or x0 >= CaveShape.START_X1 + EXT_MARGIN or z1 <= CaveShape.START_Z0 - EXT_MARGIN


## `p` : réglages {room, branch} ; vide = ceux du biome sous le ver, à chaque pas.
const TUNNEL_DIRECTIONS := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]


## Le disque de demi-largeur minimale centré en (x, z) tient dans la zone permise (8 points du pourtour).
func _fits_wide(x: float, z: float) -> bool:
	var d := MIN_HALF_WIDTH - 0.5
	var e := d * 0.7071
	if _clear_box(x - d, z - d, x + d, z + d):
		return true
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
	var m := mask
	var size := m.size()
	# Temple et Veines d'abord (2026-11-22) : leurs réseaux gardent les numéros d'avant les strates, qui
	# viennent ensuite (aucun réseau ne franchit la roche pleine entre deux bandes, voir _band_limits).
	var split := 0 if Biomes.LIST.size() <= 2 else clampi(gal_idx(CaveShape.WORLD_X0, Biomes.north_z(1)), 0, size)
	var stack := PackedInt32Array()
	for pass_n in 2:
		var from := split if pass_n == 0 else 0
		var to := size if pass_n == 0 else split
		var k0 := m.find(1, from)
		while k0 >= 0 and k0 < to:
			if comp[k0] != 0:
				k0 = m.find(1, k0 + 1)
				continue
			count += 1
			comp[k0] = count
			stack.append(k0)
			while not stack.is_empty():
				var k := stack[stack.size() - 1]
				stack.resize(stack.size() - 1)
				var i := k % GAL_W
				if i > 0 and m[k - 1] != 0 and comp[k - 1] == 0:
					comp[k - 1] = count
					stack.append(k - 1)
				if i < GAL_W - 1 and m[k + 1] != 0 and comp[k + 1] == 0:
					comp[k + 1] = count
					stack.append(k + 1)
				if k >= GAL_W and m[k - GAL_W] != 0 and comp[k - GAL_W] == 0:
					comp[k - GAL_W] = count
					stack.append(k - GAL_W)
				if k + GAL_W < size and m[k + GAL_W] != 0 and comp[k + GAL_W] == 0:
					comp[k + GAL_W] = count
					stack.append(k + GAL_W)
			k0 = m.find(1, k0 + 1)
	# Somme du masque sur 7 colonnes (i − 3 … i + 3, coupée aux bords) : la note d'une case lit 6 rangées.
	var hsum := PackedInt32Array()
	hsum.resize(size)
	for j in GAL_H:
		var row := j * GAL_W
		var acc := 0
		for a in mini(3, GAL_W):
			acc += m[row + a]
		for i in GAL_W:
			if i + 3 < GAL_W:
				acc += m[row + i + 3]
			if i - 4 >= 0:
				acc -= m[row + i - 4]
			hsum[row + i] = acc
	# Salle de l'Œil et son couloir : rangées où le test peut être vrai (borne prudente), pour ne pas le
	# calculer sur toute la carte.
	var eye_lo := INF
	var eye_hi := -INF
	if frontier:
		var ec := eye_room_center()
		var kmax := 0.0
		for t in 3600:
			kmax = maxf(kmax, eye_room_scale(t / 3600.0 * TAU - PI))
		var rz := EYE_ROOM_RZ * kmax * 1.05 + PYLON_CHAMBER + 5.0
		eye_lo = minf(eye_corridor_north, ec.y - rz) - 1.0
		eye_hi = ec.y + rz + 1.0
	var best_sc := PackedInt32Array()
	best_sc.resize(count + 1)
	best_sc.fill(-1)
	var best_k := PackedInt32Array()
	best_k.resize(count + 1)
	var k := -1
	while true:
		k = m.find(1, k + 1)
		if k < 0:
			break
		var id := comp[k]
		var i := k % GAL_W
		var j := (k - i) / GAL_W
		# Pas de pylône dans la salle de l'Œil ni dans son couloir.
		var cz := j + CaveShape.WORLD_Z0 + 0.5
		if cz >= eye_lo and cz <= eye_hi and (in_eye_room(i + CaveShape.WORLD_X0 + 0.5, cz, PYLON_CHAMBER + 4.0) \
				or _in_eye_corridor(i + CaveShape.WORLD_X0 + 0.5, cz)):
			continue
		var sc := 0
		for bb in mini(6, GAL_H - j):
			sc += hsum[k + bb * GAL_W]
		var up := k - GAL_W
		if not (j > 0 and (m[up] == 1 or (i > 0 and m[up - 1] == 1) or (i < GAL_W - 1 and m[up + 1] == 1))):
			sc += 100
		if sc > best_sc[id]:
			best_sc[id] = sc
			best_k[id] = k
	var best := {}
	for id in range(1, count + 1):
		if best_sc[id] >= 0:
			var bi := best_k[id] % GAL_W
			@warning_ignore("integer_division")
			var bj := best_k[id] / GAL_W
			best[id] = {"sc": best_sc[id], "x": bi + CaveShape.WORLD_X0 + 0.5, "z": bj + CaveShape.WORLD_Z0 + 0.5}
	portals.clear()
	var ids := best.keys()
	ids.sort()
	# Réseaux de la zone d'origine d'abord (ordre du prototype), puis ceux de l'extension.
	var inner := ids.filter(func(id: int) -> bool: return CaveShape.in_start(best[id]["x"], best[id]["z"]))
	ids = inner + ids.filter(func(id: int) -> bool: return not inner.has(id))
	for n in ids.size():
		var pz: float = best[ids[n]]["z"]
		portals.append({"id": n, "x": best[ids[n]]["x"], "z": pz, "active": false, "next": 0.0, "threat": int(Biomes.at(pz)["threat"])})


# ---------------------------------------------------------------- Galeries reliées (2026-11-22)
## planches/galeries-reliees-propositions.html, variante C : toutes les galeries forment un réseau par biome,
## ouvert sur la grotte de départ. Le Temple part de la grotte, les Veines du couloir de l'Œil (la porte de l'Œil
## reste le seul passage entre les deux). Le minage sert à récolter et à s'agrandir, plus à trouver les galeries.
## Travail sur la grille des cases de 4 u ; hors parité JS (groves).

## Grille des cases : CW × CH, la case (0, 0) est la case de monde (CI0, CJ0) = (WORLD_X0 / 4, −744 / 4).
## Elle ne couvre que le Temple et les Veines (bord nord de la carte d'avant les six strates, 2026-11-22) : les
## strates ne sont pas raccordées à la grotte, on y entre en creusant leur roche scellée.
const CW := 232
const CH := 204
const CI0 := -116
const CJ0 := -186
const K_ROCK := 0
const K_OPEN := 1
const K_BASE := 2
const K_WALL := 3
## Roche qu'aucun raccord ne traverse (bords, flanc, abords du coffre) mais qu'une salle peut entamer.
const K_HARD := 4
## Raccord de plus de LINK_LONG cases : une salle élargie toutes les LINK_ROOM_EVERY cases.
const LINK_LONG := 12
const LINK_ROOM_EVERY := 14
## Boucles : au plus LOOPS percées par biome, à travers 1 à LOOP_GAP cases de roche en ligne droite, entre deux
## galeries dont les distances de chemin diffèrent d'au moins LOOP_GAIN cases, à LOOP_SPACING u l'une de l'autre.
const LOOPS := 3
const LOOP_GAP := 3
const LOOP_GAIN := 40
const LOOP_SPACING := 60.0
## Anneaux de chemin depuis l'Ancre (cases) : 120, 200 et 360 u. Écart minimal entre deux pylônes (cases, 88 u).
const RINGS := [30, 50, 90]
const PYLON_SPACING := 22.0
## Variante C : [biome, borne basse, borne haute, nombre, forme, palier]. Bornes en cases de chemin (les Veines
## comptent depuis la porte de l'Œil ; HALF = moitié de la profondeur des Veines, NO_LIMIT = sans borne).
## Forme : "dead" cul-de-sac, "cross" carrefour. Le palier devient la menace du pylône (p["threat"]).
const HALF := -2
const NO_LIMIT := 1 << 30
const PYLON_QUOTAS := [
	[0, 30, 50, 2, "dead", 1],
	[0, 50, 90, 3, "cross", 2],
	[0, 90, NO_LIMIT, 3, "cross", 3],
	[1, 6, HALF, 4, "cross", 4],
	[1, HALF, NO_LIMIT, 4, "dead", 5],
]

## Distance de chemin depuis l'Ancre, en cases (4-voisins, à travers la porte de l'Œil) ; -1 hors réseau.
## Index ci + cj × CW sur la grille des cases.
var path_d := PackedInt32Array()
## Cases creusées par les raccords et les boucles (aucune tanière n'y est posée).
var link_cells := {}
## Premier jour où les pylônes ont lâché leurs meutes (front des meutes, sim/night.gd).
var raid_first_day := 0
var _kind := PackedByteArray()
var _static := PackedByteArray()
var _bandk := PackedByteArray()
var _comp := PackedInt32Array()


static func _cell_center(k: int) -> Vector2:
	@warning_ignore("integer_division")
	return Vector2((k % CW + CI0) * 4.0 + 2.0, (k / CW + CJ0) * 4.0 + 2.0)


static func _cell_index(p: Vector2) -> int:
	var ci := floori(p.x / 4.0) - CI0
	var cj := floori(p.y / 4.0) - CJ0
	if ci < 0 or cj < 0 or ci >= CW or cj >= CH:
		return -1
	return cj * CW + ci


## Distance de chemin (unités) de l'Ancre au point (x, z) ; -1 hors réseau.
func path_at(x: float, z: float) -> float:
	var k := _cell_index(Vector2(x, z))
	if k < 0 or path_d.is_empty() or path_d[k] < 0:
		return -1.0
	return path_d[k] * 4.0


## Nature de chaque case (roche traversable par un raccord, galerie, grotte, infranchissable) et biome. Tout ce qui
## ne dépend pas du masque est calculé une fois par carte (`full`) ; ensuite seules les galeries sont relues.
func _classify(full := false) -> void:
	var n := CW * CH
	if full or _static.size() != n:
		_static.resize(n)
		_bandk.resize(n)
		var fz := frontier_z()
		for k in n:
			var c := _cell_center(k)
			var v := K_ROCK
			if CaveShape.outdoors(c.x, c.y):
				v = K_WALL
			elif CaveShape.in_cave(c.x, c.y) or CaveShape.in_tunnel(c.x, c.y):
				v = K_BASE
			elif frontier_cell(floori(c.x / 4.0), floori(c.y / 4.0)):
				v = K_WALL
			elif not temple_layout.is_empty() and c.y > fz + FRONTIER_HALF:
				# Temple en salles : ses salles sont déjà reliées par leurs couloirs ; aucun raccord ni boucle n'y
				# perce la roche (les salles secrètes restent derrière leur fissure, les murs de quartier entiers).
				# K_HARD : la roche y est infranchissable pour les raccords, les salles et couloirs restent ouverts.
				v = K_HARD
			elif not _link_rock(c):
				v = K_HARD
			_static[k] = v
			_bandk[k] = 1 if frontier and c.y < fz else 0
	_kind.resize(n)
	for k in n:
		var v := _static[k]
		if v == K_BASE or v == K_WALL:
			_kind[k] = v
			continue
		var c := _cell_center(k)
		_kind[k] = K_OPEN if is_gallery(c.x, c.y) else (K_ROCK if v == K_ROCK else K_WALL)


## Roche qu'un raccord peut traverser : loin des bords de la carte et du flanc, à l'écart de la réserve du coffre,
## jamais au sud de la grotte (le flanc au-dessus de la jungle reste plein).
func _link_rock(c: Vector2) -> bool:
	# Bord nord : celui de la grille des raccords (Temple et Veines, z −744), pas celui de la carte (2026-11-22).
	if c.x < CaveShape.WORLD_X0 + 14.0 or c.x > CaveShape.WORLD_X1 - 14.0 or c.y < CJ0 * 4.0 + 14.0:
		return false
	if c.y > CaveShape.mountain_edge(c.x) - 14.0:
		return false
	if c.x > CaveShape.VAULT_X0 - 8.0 and c.x < CaveShape.VAULT_X1 + 8.0 and c.y > CaveShape.VAULT_Z0 - 8.0 and c.y < CaveShape.VAULT_Z1 + 8.0:
		return false
	return not (absf(c.x) < 92.0 and c.y > CaveShape.CAVE_Z1 - 8.0)


## Composantes connexes des cases ouvertes (galerie ou grotte).
func _label_cells() -> void:
	var n := CW * CH
	_comp.resize(n)
	_comp.fill(0)
	var id := 0
	var stack := PackedInt32Array()
	for k0 in n:
		if _comp[k0] != 0 or (_kind[k0] != K_OPEN and _kind[k0] != K_BASE):
			continue
		id += 1
		_comp[k0] = id
		stack.append(k0)
		while not stack.is_empty():
			var k := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			var i := k % CW
			for s in 4:
				var nb := _step(k, i, s)
				if nb >= 0 and _comp[nb] == 0 and (_kind[nb] == K_OPEN or _kind[nb] == K_BASE):
					_comp[nb] = id
					stack.append(nb)


## Voisine s (0 ouest, 1 est, 2 nord, 3 sud) de la case k de colonne i ; -1 hors grille.
static func _step(k: int, i: int, s: int) -> int:
	match s:
		0:
			return k - 1 if i > 0 else -1
		1:
			return k + 1 if i < CW - 1 else -1
		2:
			return k - CW if k >= CW else -1
	return k + CW if k + CW < CW * CH else -1


## Case ouverte du couloir de l'Œil juste au nord de la frontière (départ des Veines) ; -1 sans frontière.
func _gate_cell() -> int:
	if not frontier:
		return -1
	var fz := frontier_z()
	var best := -1
	for k in CW * CH:
		var c := _cell_center(k)
		if _kind[k] == K_OPEN and absf(c.x) <= 8.0 and c.y < fz and c.y > fz - 16.0:
			if best < 0 or c.y > _cell_center(best).y:
				best = k
	return best


## Relie tous les réseaux par les plus courts boyaux : une seule expansion dans la roche depuis tous les réseaux à
## la fois (chaque case de roche revient au réseau le plus proche), les fronts qui se touchent donnent les raccords
## possibles, puis arbre couvrant minimal (Kruskal). Les fronts ne passent jamais la frontière : le Temple se relie
## à la grotte, les Veines au couloir de l'Œil (même réseau que la salle de l'Œil). Puis quelques boucles.
func _connect_networks() -> void:
	_classify(true)
	_label_cells()
	var n := CW * CH
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(-1)
	var owner := PackedInt32Array()
	owner.resize(n)
	var par := PackedInt32Array()
	par.resize(n)
	var q := PackedInt32Array()
	var ids := 0
	for k in n:
		if _comp[k] != 0:
			dist[k] = 0
			owner[k] = _comp[k]
			par[k] = -1
			q.append(k)
			ids = maxi(ids, _comp[k])
	# Meilleur raccord par paire de réseaux : clé a × (ids + 1) + b → [longueur, case de a, case de b].
	var best := {}
	var h := 0
	while h < q.size():
		var k := q[h]
		h += 1
		var i := k % CW
		for s in 4:
			var nb := _step(k, i, s)
			if nb < 0 or _bandk[nb] != _bandk[k]:
				continue
			if dist[nb] >= 0:
				var a := owner[k]
				var b := owner[nb]
				if a != b:
					var key := mini(a, b) * (ids + 1) + maxi(a, b)
					var length := dist[k] + dist[nb]
					if not best.has(key) or length < int(best[key][0]):
						best[key] = [length, k, nb] if a < b else [length, nb, k]
				continue
			if _kind[nb] != K_ROCK:
				continue
			dist[nb] = dist[k] + 1
			owner[nb] = owner[k]
			par[nb] = k
			q.append(nb)
	var edges: Array = best.keys()
	edges.sort_custom(func(x: int, y: int) -> bool: return int(best[x][0]) < int(best[y][0]))
	var root := PackedInt32Array()
	root.resize(ids + 1)
	for c in ids + 1:
		root[c] = c
	for key: int in edges:
		var e: Array = best[key]
		var ra := _find(root, owner[int(e[1])])
		var rb := _find(root, owner[int(e[2])])
		if ra == rb:
			continue
		root[ra] = rb
		_carve_link(int(e[1]), int(e[2]), dist, par, int(e[0]))
	_carve_loops()


static func _find(root: PackedInt32Array, c: int) -> int:
	while root[c] != c:
		root[c] = root[root[c]]
		c = root[c]
	return c


## Creuse le raccord entre les cases a et b (voisines, chacune au bout du front de son réseau) : les deux
## remontées jusqu'aux réseaux, 2 blocs de large, une salle élargie de loin en loin sur les longs raccords.
func _carve_link(a: int, b: int, dist: PackedInt32Array, par: PackedInt32Array, length: int) -> void:
	var cells: Array[int] = []
	for start: int in [a, b]:
		var p := start
		while p >= 0 and dist[p] > 0:
			cells.append(p)
			p = par[p]
		var tail := start if cells.is_empty() else cells[cells.size() - 1]
		if p >= 0:
			_stamp_link((_cell_center(tail) + _cell_center(p)) / 2.0, MIN_HALF_WIDTH)
	_stamp_link((_cell_center(a) + _cell_center(b)) / 2.0, MIN_HALF_WIDTH)
	var long := length > LINK_LONG
	for m in cells.size():
		var k: int = cells[m]
		var cc := _cell_center(k)
		_stamp_link(cc, MIN_HALF_WIDTH)
		@warning_ignore("integer_division")
		if long and m % LINK_ROOM_EVERY == LINK_ROOM_EVERY / 2:
			_stamp_link(cc, MIN_HALF_WIDTH * 1.8)
		_kind[k] = K_OPEN
		link_cells[Vector2i(floori(cc.x / 4.0), floori(cc.y / 4.0))] = true


## Disque de galerie d'un raccord : partout dans la montagne sauf la grotte, la réserve du coffre et la frontière
## (le couloir et la salle de l'Œil exceptés).
func _stamp_link(c: Vector2, r: float) -> void:
	var fz := frontier_z()
	for z in range(floori(c.y - r), floori(c.y + r) + 1):
		for x in range(floori(c.x - r), floori(c.x + r) + 1):
			var px := x + 0.5
			var pz := z + 0.5
			if (px - c.x) * (px - c.x) + (pz - c.y) * (pz - c.y) > r * r:
				continue
			if px < CaveShape.WORLD_X0 + 10.0 or px > CaveShape.WORLD_X1 - 10.0 or pz < CJ0 * 4.0 + 10.0 \
					or pz > CaveShape.mountain_edge(px) - 12.0:
				continue
			if CaveShape.in_cave(px, pz) or CaveShape.in_vault(px, pz):
				continue
			if frontier and absf(pz - fz) < FRONTIER_HALF and not in_eye_room(px, pz) and not _in_eye_corridor(px, pz):
				continue
			var k := gal_idx(x, z)
			if k >= 0:
				mask[k] = 1


## Percées entre deux galeries proches à vol d'oiseau mais loin en chemin : plus d'une route vers la base.
func _carve_loops() -> void:
	_compute_path_d()
	var n := CW * CH
	var cand: Array = []
	for k in n:
		if _kind[k] != K_OPEN or path_d[k] < 0:
			continue
		var i := k % CW
		for s: int in [1, 3]:
			var m := k
			var mi := i
			for g in range(1, LOOP_GAP + 2):
				m = _step(m, mi, s)
				if m < 0:
					break
				mi = m % CW
				if _kind[m] == K_ROCK:
					continue
				if _kind[m] == K_OPEN and g > 1 and path_d[m] >= 0 and _bandk[m] == _bandk[k] \
						and absi(path_d[m] - path_d[k]) >= LOOP_GAIN:
					cand.append([absi(path_d[m] - path_d[k]), k, s, g])
				break
	cand.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var done: Array[Vector2] = []
	var per := [0, 0]
	for e: Array in cand:
		var k: int = e[1]
		var band := int(_bandk[k])
		var at := _cell_center(k)
		if per[band] >= LOOPS or done.any(func(o: Vector2) -> bool: return o.distance_to(at) < LOOP_SPACING):
			continue
		var m := k
		for g in range(1, int(e[3])):
			m = _step(m, m % CW, int(e[2]))
			var cc := _cell_center(m)
			_stamp_link(cc, MIN_HALF_WIDTH)
			_kind[m] = K_OPEN
			link_cells[Vector2i(floori(cc.x / 4.0), floori(cc.y / 4.0))] = true
		done.append(at)
		per[band] += 1


## Distances de chemin depuis l'Ancre sur les cases ouvertes (relues sur le masque : salles des pylônes et salles
## à thème comprises). La porte de l'Œil compte comme ouverte.
func _compute_path_d() -> void:
	_classify()
	var n := CW * CH
	path_d.resize(n)
	path_d.fill(-1)
	var core := _cell_index(CaveShape.CORE)
	var q := PackedInt32Array([core])
	path_d[core] = 0
	var h := 0
	while h < q.size():
		var k := q[h]
		h += 1
		var i := k % CW
		for s in 4:
			var nb := _step(k, i, s)
			if nb < 0 or path_d[nb] >= 0 or (_kind[nb] != K_OPEN and _kind[nb] != K_BASE):
				continue
			path_d[nb] = path_d[k] + 1
			q.append(nb)


## Pylônes de Merenor par anneaux de chemin (PYLON_QUOTAS) au lieu d'un par réseau : dans chaque anneau, la place
## de la bonne forme la plus éloignée des pylônes déjà posés (au moins PYLON_SPACING cases), sinon une galerie
## ordinaire. Centre sur un coin de case, salle de rayon PYLON_CHAMBER, socle de 2 × 2 cases.
func _place_pylons() -> void:
	_compute_path_d()
	portals.clear()
	var n := CW * CH
	var gate := 0
	var g := _gate_cell()
	if g >= 0 and path_d[g] >= 0:
		gate = path_d[g]
	var deep := 0
	for k in n:
		if path_d[k] >= 0 and _bandk[k] == 1:
			deep = maxi(deep, path_d[k] - gate)
	var half := maxi(12, roundi(deep / 2.0))
	var chosen: Array[Vector2] = [CaveShape.CORE / 4.0]
	var was := _ext
	_cross_cache.clear()
	# Places possibles, par biome (la salle d'un pylône ne change pas les zones permises : calculées une fois).
	var spots: Array = [[], []]
	for k in n:
		if _kind[k] == K_OPEN and path_d[k] >= 0 and _pylon_spot(k):
			(spots[_bandk[k]] as Array).append(k)
	# Temple en salles : un pylône au centre de la salle de combat désignée de chaque quartier (RoomLayout).
	if not temple_layout.is_empty():
		for room: Dictionary in temple_layout["rooms"]:
			if not room["pylon"]:
				continue
			var rr: Rect2i = room["rect"]
			var cc := rr.position + rr.size / 2
			var k := _cell_index(Vector2((cc.x - 1) * 4.0 + 2.0, (cc.y - 1) * 4.0 + 2.0))
			chosen.append(_cell_center(k) / 4.0)
			_add_pylon(k, TEMPLE_PYLON_TIER[room["quarter"]])
	for Q: Array in PYLON_QUOTAS:
		var band: int = Q[0]
		if band == 1 and not frontier:
			continue
		if band == 0 and not temple_layout.is_empty():
			continue
		var lo: int = half if Q[1] == HALF else Q[1]
		var hi: int = half if Q[2] == HALF else Q[2]
		var off := gate if band == 1 else 0
		var typed: Array[int] = []
		var any: Array[int] = []
		for k: int in spots[band]:
			var d := path_d[k] - off
			if d < lo or d >= hi:
				continue
			any.append(k)
			if (_dead_end(k) if Q[4] == "dead" else _crossing(k) >= 2):
				typed.append(k)
		for m in int(Q[3]):
			var best := _pick_spot(typed, chosen, Q[4] == "dead", off)
			if best < 0:
				best = _pick_spot(any, chosen, Q[4] == "dead", off)
			if best < 0:
				break
			chosen.append(_cell_center(best) / 4.0)
			_add_pylon(best, int(Q[5]))
	_ext = was


## La salle d'un pylône posé sur la case k tient : zone permise, loin de la frontière, de la salle de l'Œil, de
## la salle de la Gorge-Cuivre et des bassins ; pas sur un raccord.
func _pylon_spot(k: int) -> bool:
	var c := _pylon_center(k)
	if link_cells.has(Vector2i(floori(c.x / 4.0) - 1, floori(c.y / 4.0) - 1)):
		return false
	_ext = not CaveShape.in_start(c.x, c.y)
	if not _chamber_fits(c):
		return false
	if gorge_room != null and (gorge_room as Vector2).distance_to(c) < GORGE_ROOM + PYLON_CHAMBER + 8.0:
		return false
	return not pools.any(func(o: Dictionary) -> bool: return (o["center"] as Vector2).distance_to(c) < POOL_RADIUS + PYLON_CHAMBER + 4.0)


## Coin sud-est de la case k : centre du socle (cases k, k + 1, k + CW, k + CW + 1).
static func _pylon_center(k: int) -> Vector2:
	return _cell_center(k) + Vector2(2.0, 2.0)


## Cul-de-sac : aucune case à 5 cases ou moins n'est plus loin en chemin.
func _dead_end(k: int) -> bool:
	var d := path_d[k]
	var i := k % CW
	@warning_ignore("integer_division")
	var j := k / CW
	for b in range(-5, 6):
		for a in range(-5, 6):
			if i + a < 0 or i + a >= CW or j + b < 0 or j + b >= CH:
				continue
			if path_d[k + b * CW + a] > d:
				return false
	return true


## Carrefour : nombre de branches qui s'éloignent de l'Ancre sur le pourtour d'un carré de rayon 6 (0 si aucune
## branche ne revient vers elle).
func _crossing(k: int) -> int:
	if _cross_cache.has(k):
		return _cross_cache[k]
	var v := _crossing_runs(k)
	_cross_cache[k] = v
	return v


var _cross_cache := {}


func _crossing_runs(k: int) -> int:
	const R := 6
	var d := path_d[k]
	var i := k % CW
	@warning_ignore("integer_division")
	var j := k / CW
	if i < R or j < R or i >= CW - R or j >= CH - R:
		return 0
	var ring: Array[Vector2i] = []
	for a in range(-R, R):
		ring.append(Vector2i(a, -R))
	for b in range(-R, R):
		ring.append(Vector2i(R, b))
	for a in range(R, -R, -1):
		ring.append(Vector2i(a, R))
	for b in range(R, -R, -1):
		ring.append(Vector2i(-R, b))
	var runs := 0
	var prev := false
	var first := false
	var inward := false
	for r in ring.size():
		var m := path_d[k + ring[r].y * CW + ring[r].x]
		var o := m > d + 3
		if m >= 0 and m < d - 3:
			inward = true
		if r == 0:
			first = o
		if o and not prev:
			runs += 1
		prev = o
	if prev and first and runs > 1:
		runs -= 1
	return runs if inward else 0


## Place la plus éloignée des pylônes déjà posés (écart PYLON_SPACING au moins) ; à écart égal, le cul-de-sac le
## plus profond ou le carrefour le plus ramifié. -1 si aucune.
func _pick_spot(list: Array[int], chosen: Array[Vector2], dead: bool, off: int) -> int:
	var best := -1
	var bs := -1.0
	for k in list:
		var at := _cell_center(k) / 4.0
		var md := INF
		for o in chosen:
			md = minf(md, o.distance_to(at))
		if md < PYLON_SPACING:
			continue
		var quality := float(path_d[k] - off) / 40.0 if dead else float(_crossing(k))
		var s := minf(md, 40.0) * 10.0 + quality
		if s > bs:
			bs = s
			best = k
	return best


func _add_pylon(k: int, tier: int) -> void:
	var c := _pylon_center(k)
	_ext = not CaveShape.in_start(c.x, c.y)
	_stamp(c.x, c.y, PYLON_CHAMBER)
	var id := portals.size()
	portals.append({"id": id, "x": c.x, "z": c.y, "active": false, "next": 0.0, "threat": tier, "ring": tier, "path": path_d[k] * 4.0})
	var ci := floori(c.x / 4.0)
	var cj := floori(c.y / 4.0)
	for o: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
		pylon_cells[Vector2i(ci, cj) + o] = id


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


# ---------------------------------------------------------------- Temple en salles

## Taille le plan du Temple (RoomLayout.build_temple) : salles (sauf la grotte et la salle de l'Œil, déjà là),
## couloirs et salles secrètes (la fissure, elle, reste à creuser). Note les murs de quartier et les portes.
func _carve_temple_rooms(map_seed: int) -> void:
	temple_layout = RoomLayout.build_temple(map_seed ^ 0x7e3b)
	# Les vers des Veines n'ont pas de borne sud (band_range(1)) et descendent parfois sous la frontière : au
	# Temple, seul le plan creuse. La salle de l'Œil et son couloir sont taillés plus tard (_carve_frontier).
	for j in range(maxi(0, ceili(frontier_z() + FRONTIER_HALF - CaveShape.WORLD_Z0)), GAL_H):
		for i in GAL_W:
			mask[j * GAL_W + i] = 0
	var open_case := func(c: Vector2i) -> void:
		for uz in 4:
			for ux in 4:
				var k := gal_idx(c.x * 4.0 + ux, c.y * 4.0 + uz)
				if k >= 0:
					mask[k] = 1
	var pillars: Array[Vector2i] = []
	for room: Dictionary in temple_layout["rooms"]:
		var rr: Rect2i = room["rect"]
		for j in range(rr.position.y, rr.end.y):
			for i in range(rr.position.x, rr.end.x):
				room_at[Vector2i(i, j)] = room["id"]
				# Salles de (mini-)boss : une colonne de pierre à chaque angle, à une case du mur (2026-11-22).
				if room["kind"] in ["miniboss", "boss"] and rr.size.x >= 6 and rr.size.y >= 6 \
						and (i == rr.position.x + 1 or i == rr.end.x - 2) and (j == rr.position.y + 1 or j == rr.end.y - 2):
					pillars.append(Vector2i(i, j))
					continue
				if not room["fixed"]:
					open_case.call(Vector2i(i, j))
	for l: Dictionary in temple_layout["links"]:
		if l["kind"] != "corridor":
			continue
		for c in RoomLayout.corridor_cells(l["path"]):
			# Le couloir ne mord ni la réserve du coffre ni l'intérieur de la grotte (il y débouche).
			var p := Vector2(c.x * 4.0 + 2.0, c.y * 4.0 + 2.0)
			if CaveShape.in_vault(p.x, p.y) or CaveShape.in_cave(p.x, p.y):
				continue
			open_case.call(c)
	room_walls = (temple_layout["walls"] as Dictionary).duplicate()
	for c: Vector2i in pillars:
		room_walls[c] = true
	# Fermées jusqu'à la chute de leur mini-boss : mb1 (vers B) l'Archiprêtre aux racines (sim/archipretre.gd), mb2
	# (route du boss) la Martyre de Byrsa (sim/martyre.gd).
	for key: String in temple_layout["doors"]:
		doors_closed[key] = true
		for c: Vector2i in temple_layout["doors"][key]:
			door_cells[c] = key
	_any_door_closed = doors_closed.values().has(true)


## Une porte fermée est de la roche scellée : ses cases redeviennent pleines et impossibles à creuser (on voit un
## mur) ; RoomEncounters.open_door les creuse à l'ouverture. Appelée en fin de génération, après les chemins depuis
## l'Ancre : pylônes, tanières et meutes des Veines se placent comme si la porte était ouverte.
func _seal_closed_doors() -> void:
	for c: Vector2i in door_cells:
		if not doors_closed.get(door_cells[c], false):
			continue
		room_walls[c] = true
		for uz in 4:
			for ux in 4:
				var k := gal_idx(c.x * 4.0 + ux, c.y * 4.0 + uz)
				if k >= 0:
					mask[k] = 0


## Salle du plan du Temple sous (x, z), ou {} (couloir, roche, autre biome, parité JS).
func temple_room(x: float, z: float) -> Dictionary:
	if temple_layout.is_empty():
		return {}
	var id: Variant = room_at.get(Vector2i(floori(x / 4.0), floori(z / 4.0)))
	return {} if id == null else temple_layout["rooms"][id]


## Salle sûre (antichambre du boss) : rien n'y apparaît, et les errants n'y visent ni n'y poursuivent personne.
func safe_at(x: float, z: float) -> bool:
	if temple_layout.is_empty():
		return false
	return temple_room(x, z).get("role", "") == "antechamber"


## Une tanière d'errants peut-elle être posée en (x, z) ? Pas dans le Temple en salles : ses salles de combat ont
## leurs rencontres (sim/rooms.gd) ; ailleurs, partout où Roamers le permet.
func den_allowed(_x: float, z: float) -> bool:
	return temple_layout.is_empty() or z <= frontier_z() + FRONTIER_HALF


## Salles de ressources du Temple : un filon de cuivre à gauche, un bosquet à droite ; un bassin dans la source de C.
func _furnish_temple_rooms(r: Rng) -> void:
	var copper := Blocks.ORES.find("copper")
	for room: Dictionary in temple_layout["rooms"]:
		var rr: Rect2i = room["rect"]
		var mid := rr.position.y + rr.size.y / 2
		if room["kind"] == "resource":
			var lode := Vector2i(rr.position.x + rr.size.x / 3 - 1, mid - 1)
			for o: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
				if _grove_fits(lode + o):
					_lode_spots.append([lode + o, copper])
					break
			_clearings.append(Vector2((rr.position.x + rr.size.x * 2 / 3) * 4.0 + 2.0, mid * 4.0 + 2.0))
		elif room["role"] == "spring":
			_add_pool(r, Vector2(rr.get_center()) * 4.0)


## Salles à thème du Temple (sim/sanctum.gd) : les 15 habituelles, posées au centre de salles du plan (choix du
## 2026-11-22 : réparties partout) — secrètes, calmes (sauf la source et son bassin) et combats sans pylône.
func _place_temple_theme_rooms(r: Rng) -> void:
	if temple_layout.is_empty():
		return
	var candidates: Array = (temple_layout["rooms"] as Array).filter(func(o: Dictionary) -> bool:
		return not o["fixed"] and not o["pylon"] and (o["kind"] == "secret" or o["kind"] == "combat" or (o["kind"] == "calm" and o["role"] != "spring")))
	# Mélange déterministe (Fisher-Yates sur le générateur de la carte), secrètes en tête : leurs trésors
	# (crypte, bibliothèque, salle d'armes) y sont les mieux cachés.
	for i in range(candidates.size() - 1, 0, -1):
		var j := floori(r.next() * (i + 1))
		var t: Variant = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = t
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["kind"] == "secret" and b["kind"] != "secret")
	var used := {}
	for n in THEME_ROOMS:
		var kind: String = THEME_KINDS[n % THEME_KINDS.size()]
		var half := Vector2i(3, 2) if kind == "cistern" else Vector2i(2, 1)
		for room: Dictionary in candidates:
			var rr: Rect2i = room["rect"]
			if used.has(room["id"]) or rr.size.x < half.x * 2 + 3 or rr.size.y < half.y * 2 + 3:
				continue
			used[room["id"]] = true
			var ci := rr.position.x + rr.size.x / 2
			var cj := rr.position.y + rr.size.y / 2
			if kind == "cistern":
				for dj in range(-1, 2):
					for di in range(-2, 3):
						if di != 0 or dj < 0:
							water_cells[Vector2i(ci + di, cj + dj)] = true
			theme_rooms.append({"kind": kind, "x": ci * 4.0 + 2.0, "z": cj * 4.0 + 2.0, "half": half})
			break


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
## le couvre, dessinée devant, sinon la roche peinte sous lui ; null sur du sol nu. Une case à centre creux
## (galerie tracée à l'unité qui la rogne) garde de la roche peinte sur une partie de son emprise : le
## pointeur posé sur cette roche la désigne aussi (2026-11-22 : un tiers des roches du Temple restaient
## sinon impossibles à viser).
func visual_block(p: Vector2) -> Variant:
	var i := floori(p.x / 4.0)
	var j0 := floori(p.y / 4.0)
	for j: int in [j0 + 2, j0 + 1, j0, j0 - 1]:
		if not faced_cell(i, j):
			continue
		var span := drawn_span(i, j)
		if p.y >= span.x and p.y <= span.y:
			return Vector2i(i, j)
	if rock_cell(i, j0) or not ground(p.x, p.y):
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
	# Murs de quartier (biomes en salles) : impossibles à creuser, comme la frontière.
	if not room_walls.is_empty() and room_walls.has(Vector2i(i, j)):
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
