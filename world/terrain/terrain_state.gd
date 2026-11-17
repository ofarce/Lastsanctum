class_name TerrainState
extends RefCounted
## État du terrain dynamique (73b410f) : galeries cachées (galleries.js), cases creusées et coups en
## cours (adepts.js : DUG, DIG_HITS_DONE), praticabilité (Index.html : walkable, pushOutOfRock).
## Aucune donnée graphique ici : la peinture et le décor sont gérés par TerrainOps.

const GAL_W := 464  # WORLD.x1 − WORLD.x0
const GAL_H := 408  # WORLD.z1 − WORLD.z0
## Coups de pioche par case (DIG_HITS) et durée d'un coup (HIT_TIME, en secondes de travail).
const Blocks := preload("res://data/mineable_blocks.gd")
const DIG_HITS: int = Blocks.TYPES["rock"]["resistance"]
const HIT_TIME := 1.0
## Vitesse de l'Ingénieur : cases déblayées par seconde (ENGINEER_DIG) ; un piton d'ancrage par coup.
const ENGINEER_DIG := 1.0
## Portée du lance-pitons de l'Ingénieur : au plus une case (4 unités) entre lui et la case visée.
const DIG_REACH := 4.0

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
## Bosquet de la salle de départ (bas à droite) et clairières semées dans les galeries.
const START_GROVE_AT := Vector2(46.0, -104.0)
const GALLERY_GROVES := 6
const CLEARING_RADIUS := 10.0
## Écart voulu avec le prototype : clairières et bosquets. Les tests de parité JS le désactivent.
var groves := true
const VAULT_COPPER := Vector2i(16, -37)
const ORE_BANDS := [Vector2(55, 85), Vector2(90, 125), Vector2(135, 175), Vector2(185, 260)]
const VEIN_COUNTS := [16, 10, 6, 3]
var dig_hits := {}
## Instant (sim_time) du dernier piton tiré sur chaque case en cours : rendu des pitons plantés.
var dig_hit_at := {}

## Réserve du coffre antique (CaveShape.in_vault) découverte : elle devient creuse et praticable.
var vault_open := false

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


func walkable(x: float, z: float) -> bool:
	return ground(x, z) and not grove_at(x, z)


## Un bosquet pétrifié occupe ce point.
func grove_at(x: float, z: float) -> bool:
	return not grove_cells.is_empty() and grove_cells.has(Vector2i(floori(x / 4.0), floori(z / 4.0)))


## Sol découvert (salle, galerie, case creusée…), bosquets compris : ce que peignent le sol et le brouillard.
func ground(x: float, z: float) -> bool:
	return CaveShape.outdoors(x, z) or CaveShape.in_cave(x, z) or CaveShape.in_tunnel(x, z) \
		or is_dug(x, z) or is_gallery_open(x, z) or (vault_open and CaveShape.in_vault(x, z))


## Creux de la montagne (hol, galleries.js : paintRegion) : galerie ouverte, case creusée, salle, couloir.
func hollow(x: float, z: float) -> bool:
	return is_gallery_open(x, z) or is_dug(x, z) or CaveShape.in_cave(x, z) or CaveShape.in_tunnel(x, z) \
		or (vault_open and CaveShape.in_vault(x, z))


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
	block_types.clear()
	permanent_ores.clear()
	wood_left.clear()
	grove_cells.clear()
	dig_hits.clear()
	dig_hit_at.clear()
	vault_open = false
	version += 1


# ---------------------------------------------------------------- Galeries (generateGalleries)

static func gallery_allowed(x: float, z: float) -> bool:
	if x < CaveShape.WORLD_X0 + 10.0 or x > CaveShape.WORLD_X1 - 10.0 or z < CaveShape.WORLD_Z0 + 10.0 \
			or z > CaveShape.mountain_edge(x) - 12.0:
		return false
	if x > -76.0 and x < 76.0 and z > CaveShape.CAVE_Z0 - 16.0:
		return false
	return true


func generate_galleries(new_seed: int) -> void:
	seed = new_seed
	var r := Rng.new(new_seed)
	mask.fill(0)
	open.fill(0)
	found = 0
	version += 1
	var n := 12 + floori(r.next() * 5.0)
	for g in n:
		var x := 0.0
		var z := 0.0
		for t in 200:
			x = CaveShape.WORLD_X0 + 14.0 + r.next() * (GAL_W - 28)
			z = CaveShape.WORLD_Z0 + 14.0 + r.next() * (GAL_H - 28)
			if gallery_allowed(x, z):
				break
		var a := r.next() * PI * 2.0
		var steps := 34 + floori(r.next() * 46.0)
		var radius := 2.1 + r.next() * 1.4
		_worm(r, x, z, a, steps, radius)
	_clearings.clear()
	if groves:
		_carve_clearings(Rng.new(new_seed ^ 0x5eed))
	_label_networks()
	_generate_ores()


func _generate_ores() -> void:
	block_types.clear()
	permanent_ores.clear()
	wood_left.clear()
	grove_cells.clear()
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
			block_types[key] = item
			block_types[key + Vector2i.RIGHT] = item
			if n % 3 == 0:
				permanent_ores[key] = true
	# Le premier filon affleure juste après la paroi ouest, en terrain sans galerie.
	block_types[Vector2i(-17, -39)] = "copper"
	block_types[VAULT_COPPER] = "copper"
	permanent_ores[VAULT_COPPER] = true
	if groves:
		_generate_groves()


## Les 4 cases (origine + 1 en i et j) et leur pourtour sont du sol libre : le bosquet ne ferme aucun passage.
func _grove_fits(origin: Vector2i) -> bool:
	for dj in range(-1, 3):
		for di in range(-1, 3):
			var key := origin + Vector2i(di, dj)
			if block_types.has(key) or grove_cells.has(key):
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
		var x := CaveShape.WORLD_X0 + 20.0 + r.next() * (GAL_W - 40)
		var z := CaveShape.WORLD_Z0 + 20.0 + r.next() * (GAL_H - 40)
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
			if not (dx * dx + dz * dz > r * r or not gallery_allowed(x + 0.5, z + 0.5)):
				var k := gal_idx(x, z)
				if k >= 0:
					mask[k] = 1
			x += 1
		z += 1


func _worm(r: Rng, x: float, z: float, a: float, steps: int, radius: float) -> void:
	for s in steps:
		_stamp(x, z, radius * (0.8 + r.next() * 0.45))
		if r.next() < 0.05:  # salle plus large
			var sx := x + (r.next() - 0.5) * 3.0
			var sz := z + (r.next() - 0.5) * 3.0
			_stamp(sx, sz, radius * (1.9 + r.next() * 0.9))
		if r.next() < 0.025 and steps > 20:  # embranchement
			var sign := 1.0 if r.next() < 0.5 else -1.0
			var branch := a + sign * (1.0 + r.next() * 0.8)
			_worm(r, x, z, branch, floori(steps * 0.45), radius * 0.85)
		a += (r.next() - 0.5) * 0.75
		var nx := x + cos(a) * 1.7
		var nz := z + sin(a) * 1.7
		if not gallery_allowed(nx, nz):
			a += PI * (0.5 + r.next() * 0.5)
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
	for n in ids.size():
		portals.append({"id": n, "x": best[ids[n]]["x"], "z": best[ids[n]]["z"], "active": false, "next": 0.0})


func _m(i: int, j: int) -> bool:
	return i >= 0 and j >= 0 and i < GAL_W and j < GAL_H and mask[j * GAL_W + i] == 1


## Empreinte SHA-1 du masque (comparée aux valeurs du prototype dans les tests).
func mask_sha1() -> String:
	return _sha1(mask)


func open_sha1() -> String:
	return _sha1(open)


static func _sha1(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA1)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


# ---------------------------------------------------------------- Cases à creuser (adepts.js)

## digCellAt : case de roche visée, accessible depuis un sol praticable voisin ; null sinon.
## Renvoie {i, j, at: Vector2} où `at` est la position de travail de l'Ingénieur.
func block_definition(i: int, j: int) -> Dictionary:
	return Blocks.TYPES.get(block_types.get(Vector2i(i, j), "rock"), {})


func dig_cell_at(i: int, j: int, p: Vector2) -> Variant:
	if block_definition(i, j).is_empty():
		return null
	var x := i * 4.0
	var z := j * 4.0
	var key := Vector2i(i, j)
	if key == VAULT_COPPER and permanent_ores.has(key) and not vault_open:
		return null
	if dug.has(key) or (not permanent_ores.has(key) and walkable(x + 2.0, z + 2.0) and walkable(x + 0.5, z + 0.5) and walkable(x + 3.5, z + 3.5)):
		return null
	if x < CaveShape.WORLD_X0 + 8.0 or x + 4.0 > CaveShape.WORLD_X1 - 8.0 or z < CaveShape.WORLD_Z0 + 8.0 \
			or (absf(x + 2.0) < 52.0 and z < CaveShape.CAVE_Z0 + 1.0):
		return null
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
func in_dig_reach(i: int, j: int, p: Vector2) -> bool:
	var x := i * 4.0
	var z := j * 4.0
	var facing_x := p.x >= x + 0.3 and p.x <= x + 3.7
	var facing_z := p.y >= z + 0.3 and p.y <= z + 3.7
	if facing_x == facing_z:
		return false
	var q := cell_nearest(i, j, p)
	var d := p.distance_to(q)
	if d > DIG_REACH:
		return false
	var n := ceili(d / 0.4)
	for k in range(1, n):
		var s := p.lerp(q, float(k) / n)
		if s.distance_to(q) < 0.3:
			break
		if not walkable(s.x, s.y):
			return false
	return true
