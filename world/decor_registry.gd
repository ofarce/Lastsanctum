class_name DecorRegistry
extends RefCounted
## Liste des objets du décor, dans le même rôle que PW.objs du prototype : chaque entrée garde les
## données d'origine (x, z, d, bx, bz, s, wind, light, orb, portal, dportal, deity_fx, evil…) et,
## en jeu, le nœud qui la dessine. Le creusement et la révélation des galeries en retirent et en
## ajoutent (adepts.js : digCell ; galleries.js : revealGallery).
##
## Index spatial par case de 4×4 unités : les retraits ne parcourent que les cases concernées.

## Crée le nœud d'une entrée ajoutée en cours de partie : func(entry) -> Node. Facultatif (tests).
var builder: Callable
var _entries := {}  # id -> entrée (ordre d'insertion conservé)
var _buckets := {}  # Vector2i(case) -> Array[int] (ids)
var _next_id := 0
## Incrémenté à chaque ajout ou retrait (caches dérivés : sources de lumière du décor).
var version := 0


func size() -> int:
	return _entries.size()


func entries() -> Array:
	return _entries.values()


static func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / 4.0), floori(z / 4.0))


## L'entrée est encore dans le registre (pas retirée par un creusement ou une révélation).
func has(entry: Dictionary) -> bool:
	return entry.has("_id") and _entries.has(entry["_id"])


## Ajoute une entrée telle quelle (le nœud éventuel est déjà dans entry["node"]).
func add_raw(entry: Dictionary) -> void:
	version += 1
	var id := _next_id
	_next_id += 1
	entry["_id"] = id
	_entries[id] = entry
	var c := cell_of(entry["x"], entry["z"])
	if not _buckets.has(c):
		_buckets[c] = []
	_buckets[c].append(id)


## Ajoute une entrée créée en cours de partie, avec son nœud si un constructeur est défini.
func add(entry: Dictionary) -> void:
	if builder.is_valid():
		entry["node"] = builder.call(entry)
	add_raw(entry)


## Retire les entrées situées dans [x0, x1] × [z0, z1] (en unités de monde) pour lesquelles
## `predicate(entry)` est vrai, et libère leurs nœuds. Renvoie le nombre d'entrées retirées.
func remove_in_rect(x0: float, z0: float, x1: float, z1: float, predicate: Callable) -> int:
	var c0 := cell_of(x0, z0)
	var c1 := cell_of(x1, z1)
	var removed := 0
	version += 1
	for ci in range(c0.x, c1.x + 1):
		for cj in range(c0.y, c1.y + 1):
			var key := Vector2i(ci, cj)
			if not _buckets.has(key):
				continue
			var ids: Array = _buckets[key]
			var kept := []
			for id: int in ids:
				var e: Dictionary = _entries[id]
				if predicate.call(e):
					removed += 1
					_entries.erase(id)
					var node: Node = e.get("node")
					if node and is_instance_valid(node):
						node.queue_free()
				else:
					kept.append(id)
			_buckets[key] = kept
	return removed


## Objets jamais retirés par le creusement : portails, orbe, effets divins, portails maléfiques.
static func is_fixed(e: Dictionary) -> bool:
	return e.has("portal") or e.has("dportal") or e.get("orb", false) or e.has("deity_fx") or e.has("evil")
