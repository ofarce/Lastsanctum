class_name DecorGen
extends RefCounted
## Décor généré hors de la zone d'origine (monde procédural, étape 4) : mêmes sprites et mêmes densités
## que le décor du baker (mesurées sur decor_placements.json), semés au hasard par chunk de CHUNK unités.
## Fonction pure de (graine, chunk) : un chunk se régénère à l'identique, indépendamment des autres.
##   - dessus de la montagne : densités du biome (Biomes.LIST[k]["decor"]), à partir de 5 u au nord du flanc ;
##   - jungle : arbres à partir de 3 u au sud du flanc, cailloux et fougères dès le flanc ;
##   - flanc : une face de falaise par colonne de 4 u, posée sur mountain_edge (comme le baker).
## Les entrées ont le format de decor_placements.json (s, x, z, d, wind, bx, bz).

const CHUNK := 32
## Densités de la jungle du baker, par 100 u² : préfixe de sprite → [densité, vent].
const JUNGLE := {
	"tree_big": [3.46, "big"], "tree_cyp": [0.89, "cyp"], "tree_palm": [0.59, "palm"], "tree_bush": [0.57, "bush"],
	"rock": [2.18, ""], "fern": [1.66, ""],
}
const TREE_GAP := 3.0
const MOUNTAIN_GAP := 5.0
## Faces basses du flanc (face_10 à face_15), comme celles du baker hors de la salle.
const FACES := ["face_10", "face_11", "face_12", "face_13", "face_14", "face_15"]

static var _variants := {}


## Sprites d'un préfixe (« rock » ne prend pas « mountain_rock », le feuillage est exclu).
static func variants(prefix: String) -> Array:
	if _variants.is_empty():
		var sprites: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/world/decor_sprites.json"))
		for id: String in sprites:
			if id.ends_with("_foliage"):
				continue
			var base := id.substr(0, id.rfind("_"))
			if not _variants.has(base):
				_variants[base] = []
			_variants[base].append(id)
		for k: String in _variants:
			_variants[k].sort()
	return _variants.get(prefix, [])


## Chunks (indices) qui touchent la carte.
static func chunk_range() -> Rect2i:
	var c0 := Vector2i(floori(CaveShape.WORLD_X0 / CHUNK), floori(CaveShape.WORLD_Z0 / CHUNK))
	var c1 := Vector2i(floori((CaveShape.WORLD_X1 - 0.001) / CHUNK), floori((CaveShape.WORLD_Z1 - 0.001) / CHUNK))
	return Rect2i(c0, c1 - c0 + Vector2i.ONE)


## Le décor généré n'empiète ni sur la zone d'origine ni sur les bords de la carte.
static func allowed(x: float, z: float) -> bool:
	return not CaveShape.in_start(x, z) and x > CaveShape.WORLD_X0 + 2.0 and x < CaveShape.WORLD_X1 - 2.0 \
		and z > CaveShape.WORLD_Z0 + 2.0 and z < CaveShape.WORLD_Z1 - 2.0


static func chunk(map_seed: int, c: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var x0 := float(c.x * CHUNK)
	var z0 := float(c.y * CHUNK)
	# Rien à poser si le chunk est entièrement dans la zone d'origine.
	if CaveShape.in_start(x0, z0) and CaveShape.in_start(x0 + CHUNK - 0.01, z0 + CHUNK - 0.01):
		return out
	var r := Rng.new(hash([map_seed, c.x, c.y, 0xdec0]))
	var area := float(CHUNK * CHUNK) / 100.0
	# Jungle.
	for prefix: String in JUNGLE:
		var spec: Array = JUNGLE[prefix]
		var gap := TREE_GAP if prefix.begins_with("tree") else 0.5
		for n in _count(r, float(spec[0]) * area):
			var x := x0 + r.next() * CHUNK
			var z := z0 + r.next() * CHUNK
			var pick := r.next()
			if not allowed(x, z) or z < CaveShape.mountain_edge(x) + gap:
				continue
			var e := _entry(prefix, pick, x, z)
			if not String(spec[1]).is_empty():
				e["wind"] = spec[1]
			out.append(e)
	# Dessus de la montagne, selon le biome (tirage sur le biome du centre du chunk pour le nombre,
	# biome du point pour l'acceptation : une couture de biome reste nette).
	var kc := Biomes.index_at(z0 + CHUNK * 0.5)
	var decor: Dictionary = Biomes.LIST[kc].get("decor", {})
	for prefix: String in decor:
		for n in _count(r, float(decor[prefix]) * area):
			var x := x0 + r.next() * CHUNK
			var z := z0 + r.next() * CHUNK
			var pick := r.next()
			if not allowed(x, z) or z > CaveShape.mountain_edge(x) - MOUNTAIN_GAP or Biomes.index_at(z) != kc:
				continue
			out.append(_entry(prefix, pick, x, z))
	# Faces du flanc : colonnes de 4 u du chunk.
	for k in CHUNK / 4:
		var x := x0 + k * 4.0
		var z := CaveShape.mountain_edge(x)
		var pick := r.next()
		if z < z0 or z >= z0 + CHUNK or not allowed(x, z) or not allowed(x + 4.0, z):
			continue
		out.append({"s": FACES[floori(pick * FACES.size())], "x": x, "z": z, "d": z, "bx": x, "bz": z})
	return out


static func _entry(prefix: String, pick: float, x: float, z: float) -> Dictionary:
	var v := variants(prefix)
	return {"s": v[floori(pick * v.size())], "x": x, "z": z, "d": z}


## Nombre d'objets pour une espérance `mean` : partie entière plus un tirage pour la fraction.
static func _count(r: Rng, mean: float) -> int:
	var n := floori(mean)
	return n + (1 if r.next() < mean - n else 0)
