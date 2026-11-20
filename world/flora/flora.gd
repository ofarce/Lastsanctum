class_name Flora
extends RefCounted
## Petite végétation de la jungle (au sud du flanc) : buissons, fourrés épineux, hautes herbes, roseaux,
## fleurs, mousse, souches et troncs couchés. Fonction pure de la graine pour la génération ; l'état
## (stade de pousse, usure) évolue en partie.
##
## Sous-zones (zone_at) : marais au bord de la rivière, clairière fleurie, forêt dense, coin rocheux,
## jungle ordinaire. Elles règlent les densités ici et l'éclaircissement des arbres (thin_tree).
##
## Destruction : le piétinement (unités et ennemis qui passent) use les plantes basses, le feu les brûle ;
## une plante perd un stade à la fois (3 pleine, 2 jeune, 1 pousse, 0 couchée / brûlée). Elle regagne un
## stade à chaque nouvelle vague (regrow) : il faut trois vagues pour repousser entièrement.

const CHUNK := 32
const CELL := 4.0
enum Zone { JUNGLE, MARSH, CLEARING, DENSE, ROCKY }
## Plantes destructibles (les autres sont du décor fixe : souches, troncs, mousse).
const DESTRUCTIBLE := ["bush", "thorn", "grass", "reed", "flowers"]
## Plantes posées à plat (couche du sol, sans tri).
const FLAT := ["flowers", "moss"]
## Densités de base par 100 u² et multiplicateurs par zone [jungle, marais, clairière, dense, rocheux].
const DENSITY := {
	"bush": [1.6, [1.0, 0.6, 0.5, 2.2, 0.6]],
	"thorn": [0.15, [1.0, 0.3, 0.2, 2.5, 1.2]],
	"grass": [3.8, [1.0, 1.6, 1.3, 0.6, 0.7]],
	"flowers": [1.8, [1.0, 0.6, 3.0, 0.3, 0.5]],
	"moss": [0.8, [0.8, 1.8, 0.3, 1.6, 3.0]],
	"stump": [0.12, [1.0, 0.5, 0.8, 1.5, 0.8]],
	"log": [0.08, [1.0, 0.5, 0.4, 2.0, 0.6]],
}
## Roseaux : touffes par unité de berge.
const REEDS_PER_UNIT := 0.32
## Rayon d'usure par type (unités) et secondes de passage pour perdre un stade.
const TRAMPLE_R := {"grass": 0.7, "flowers": 0.6, "bush": 0.9, "reed": 0.7, "thorn": 0.9}
const WEAR := 1.6

var seed := 0
var river: River
var road: Road
## Plantes : {id, k (type), x, z, v (variante), s (stade), w (usure), b (brûlée)}.
var plants: Array[Dictionary] = []
## Case de 4 u → indices dans plants.
var _cells := {}
## Chunk de 32 u → indices dans plants.
var chunks := {}
## Indices changés depuis le dernier take_dirty() (rendu).
var _dirty: Array[int] = []


func _init(map_seed: int, r: River, rd: Road = null) -> void:
	seed = map_seed
	river = r
	road = rd
	var cr := DecorGen.chunk_range()
	for cz in range(cr.position.y, cr.end.y):
		for cx in range(cr.position.x, cr.end.x):
			_gen_chunk(Vector2i(cx, cz))


## Sous-zone d'un point de la jungle.
func zone_at(x: float, z: float) -> Zone:
	if river and river.bank_distance(x, z) < 6.0:
		return Zone.MARSH
	var n := Rng.vnoise(x / 46.0, z / 46.0, seed ^ 0xf10a)
	if n > 0.72:
		return Zone.CLEARING
	if n < 0.28:
		return Zone.DENSE
	if Rng.vnoise(x / 30.0, z / 30.0, seed ^ 0x40c4) > 0.8:
		return Zone.ROCKY
	return Zone.JUNGLE


## Poids continus des sous-zones en un point, pour le sol teinté (GroundZones) : r marais, g clairière,
## b forêt dense, a coin rocheux. Mêmes bruits et mêmes seuils que zone_at, adoucis sur quelques unités.
func zone_weights(x: float, z: float) -> Color:
	var marsh := 0.0
	if river:
		marsh = 1.0 - smoothstep(3.5, 9.0, river.bank_distance(x, z))
	var n := Rng.vnoise(x / 46.0, z / 46.0, seed ^ 0xf10a)
	var clearing := smoothstep(0.66, 0.80, n)
	var dense := 1.0 - smoothstep(0.20, 0.34, n)
	var rocky := smoothstep(0.74, 0.88, Rng.vnoise(x / 30.0, z / 30.0, seed ^ 0x40c4)) * (1.0 - clearing) * (1.0 - dense)
	var dry := 1.0 - marsh
	return Color(marsh, clearing * dry, dense * dry, rocky * dry)


## Faut-il retirer cet arbre du décor ? La jungle devient une prairie un peu boisée : les arbres ne
## restent guère qu'en bosquets (bruit GROVE), rares ailleurs, presque absents des clairières et des chemins.
const GROVE := 0.6
func thin_tree(x: float, z: float) -> bool:
	if not CaveShape.outdoors(x, z):
		return false
	if road != null and road.on_road(x, z, 2.5):
		return true
	var zone := zone_at(x, z)
	var h := Rng.hash3(floori(x * 4.0), floori(z * 4.0), seed ^ 0x7ee5)
	var g := Rng.vnoise(x / 26.0, z / 26.0, seed ^ 0x9906)
	var keep := 0.85 if g > GROVE else 0.1
	if zone == Zone.CLEARING:
		keep *= 0.3
	elif zone == Zone.DENSE:
		keep = minf(1.0, keep * 1.6)
	elif zone == Zone.MARSH:
		keep *= 0.6
	return h >= keep


## Sol libre pour une plante : jungle, hors chemin, hors lit, berge et ponts.
func _free(x: float, z: float) -> bool:
	if z < CaveShape.mountain_edge(x) + 2.0:
		return false
	if x < CaveShape.WORLD_X0 + 2.0 or x > CaveShape.WORLD_X1 - 2.0 or z > CaveShape.WORLD_Z1 - 2.0:
		return false
	if road != null and road.on_road(x, z, 0.6):
		return false
	if road == null and absf(x) < 6.0:
		return false
	return river == null or not river.clear_of_decor(x, z)


func _gen_chunk(c: Vector2i) -> void:
	var x0 := float(c.x * CHUNK)
	var z0 := float(c.y * CHUNK)
	if z0 + CHUNK < CaveShape.mountain_edge(x0) - 10.0 and z0 + CHUNK < -90.0:
		return
	var r := Rng.new(hash([seed, c.x, c.y, 0xf1]))
	var area := float(CHUNK * CHUNK) / 100.0
	for k: String in DENSITY:
		var spec: Array = DENSITY[k]
		var mean := float(spec[0]) * area * 2.2
		for n in DecorGen._count(r, mean):
			var x := x0 + r.next() * CHUNK
			var z := z0 + r.next() * CHUNK
			var v := floori(r.next() * 4.0)
			var keep := r.next()
			if not _free(x, z):
				continue
			# Tirage à 2,2 fois la densité de base, accepté selon la zone (multiplicateur / 2,2).
			if keep * 2.2 > float(spec[1][zone_at(x, z)]):
				continue
			_add(k, x, z, v)
	# Roseaux le long de la berge (les deux rives), dans ce chunk.
	if river:
		for side: float in [-1.0, 1.0]:
			var x := x0
			while x < x0 + CHUNK:
				x += 1.0 / REEDS_PER_UNIT * (0.5 + r.next())
				var off := 0.15 + r.next() * 1.4
				var z := river.center(x) + side * (river.half_width(x) + off)
				var v := floori(r.next() * 4.0)
				if z < z0 or z >= z0 + CHUNK or x >= x0 + CHUNK or not river.bridge_near(x).is_empty():
					continue
				if not DecorGen.allowed(x, z) and not CaveShape.in_start(x, z):
					continue
				_add("reed", x, z, v)


func _add(k: String, x: float, z: float, v: int) -> void:
	var id := plants.size()
	plants.append({"id": id, "k": k, "x": x, "z": z, "v": v, "s": 3, "w": 0.0, "b": false})
	var cell := Vector2i(floori(x / CELL), floori(z / CELL))
	if not _cells.has(cell):
		_cells[cell] = []
	_cells[cell].append(id)
	var ch := Vector2i(floori(x / CHUNK), floori(z / CHUNK))
	if not chunks.has(ch):
		chunks[ch] = []
	chunks[ch].append(id)


## Plantes dont le pied est à moins de r de (x, z).
func near(x: float, z: float, r: float) -> Array[int]:
	var out: Array[int] = []
	var c0 := Vector2i(floori((x - r) / CELL), floori((z - r) / CELL))
	var c1 := Vector2i(floori((x + r) / CELL), floori((z + r) / CELL))
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			for id: int in _cells.get(Vector2i(cx, cz), []):
				var p := plants[id]
				if (p["x"] - x) * (p["x"] - x) + (p["z"] - z) * (p["z"] - z) < r * r:
					out.append(id)
	return out


## Usure au passage d'un corps en (x, z) pendant dt.
func trample(x: float, z: float, dt: float) -> void:
	if z < CaveShape.mountain_edge(x):
		return
	for id in near(x, z, 1.0):
		var p := plants[id]
		if p["s"] == 0 or not TRAMPLE_R.has(p["k"]):
			continue
		var r: float = TRAMPLE_R[p["k"]]
		if (p["x"] - x) * (p["x"] - x) + (p["z"] - z) * (p["z"] - z) >= r * r:
			continue
		p["w"] += dt
		if p["w"] >= WEAR:
			p["w"] = 0.0
			p["s"] -= 1
			_dirty.append(id)


## Feu, explosion : toutes les plantes destructibles du disque tombent au stade 0.
func burn(x: float, z: float, r: float) -> int:
	var n := 0
	for id in near(x, z, r):
		var p := plants[id]
		if not DESTRUCTIBLE.has(p["k"]) or (p["s"] == 0 and p["b"]):
			continue
		p["s"] = 0
		p["w"] = 0.0
		p["b"] = true
		_dirty.append(id)
		n += 1
	return n


## Plantes sous l'emprise d'un bâtiment : retirées pour de bon.
func clear_rect(x0: float, z0: float, x1: float, z1: float) -> void:
	var r := maxf(x1 - x0, z1 - z0)
	for id in near((x0 + x1) * 0.5, (z0 + z1) * 0.5, r):
		var p := plants[id]
		if p["x"] >= x0 and p["x"] < x1 and p["z"] >= z0 and p["z"] < z1 and p["k"] != "gone":
			p["k"] = "gone"
			_dirty.append(id)


## Une vague de plus : chaque plante abîmée regagne un stade.
func regrow() -> void:
	for p in plants:
		if p["s"] < 3 and p["k"] != "gone":
			p["s"] += 1
			p["w"] = 0.0
			p["b"] = false
			_dirty.append(p["id"])


func take_dirty() -> Array[int]:
	var d := _dirty
	_dirty = []
	return d


## Nombre de plantes destructibles abîmées (tests, mesures).
func damaged() -> int:
	var n := 0
	for p in plants:
		if p["s"] < 3 and DESTRUCTIBLE.has(p["k"]):
			n += 1
	return n
