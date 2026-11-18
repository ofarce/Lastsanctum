class_name Biomes
## Bandes de biomes de la montagne, empilées vers le nord (z décroissant) à partir du flanc sud.
## Chaque biome a une hauteur fixe ; le dernier s'étend jusqu'au bord nord de la carte (et au-delà quand
## le monde deviendra infini). Fonctions pures : un biome ne dépend que de z.

## Paliers de menace ajoutés aux portails par niveau de menace de biome au-delà du premier.
const THREAT_STEP := 2

## Altitude 0 : flanc de la montagne au-dessus de la jungle (CaveShape.mountain_edge ≈ −78).
const BASE_Z := -78.0

## Du sud au nord. `height` en unités de monde ; 0 = jusqu'au bout de la carte.
## Réglages de génération (extension seulement : la zone d'origine garde ceux du prototype) :
##   worms      vers de galerie par 100 000 u² ;  steps / radius : plages [min, max] par ver
##   room       chance par pas d'une salle plus large ;  branch : chance d'embranchement
##   clearings  clairières à bosquet par 100 000 u² ;  pools : bassins par 100 000 u²
##   lodes      filons illimités par 100 000 u² ;  veins : paires de minerai en paroi par 100 000 u²
##   ores       minerai → plage [début, fin] de profondeur relative dans la bande (0 = sud, 1 = nord)
##   threat     niveau de menace inscrit sur les portails de la bande
##   decor      objets posés sur le dessus de la montagne, par 100 u² (préfixe de sprite → densité)
const LIST: Array[Dictionary] = [
	{"id": "temple", "name": "Temple", "height": 330.0, "tier": 0, "threat": 1,
		"worms": 7.5, "steps": [34, 80], "radius": [2.1, 3.5], "room": 0.05, "branch": 0.025,
		"clearings": 2.5, "pools": 1.2, "lodes": 2.0, "veins": 12.0,
		"ores": {"copper": [0.0, 0.4], "iron": [0.25, 0.7], "quartz": [0.5, 0.9], "gold": [0.75, 1.0]},
		"decor": {"mountain_rock": 1.37}},
	# Provisoire : le Temple en plus dur, en attendant le vrai contenu (planche à valider).
	{"id": "biome2", "name": "Biome 2", "height": 0.0, "tier": 1, "threat": 2,
		"worms": 9.0, "steps": [40, 90], "radius": [1.6, 2.6], "room": 0.03, "branch": 0.035,
		"clearings": 1.5, "pools": 0.8, "lodes": 2.5, "veins": 14.0,
		"ores": {"iron": [0.0, 0.3], "quartz": [0.0, 1.0], "gold": [0.0, 1.0]},
		"decor": {"mountain_rock": 1.0}},
]


## Index du biome à la profondeur z (la jungle et la base comptent dans le premier).
static func index_at(z: float) -> int:
	var top := BASE_Z
	for k in LIST.size():
		var h: float = LIST[k]["height"]
		if h <= 0.0:
			return k
		top -= h
		if z >= top:
			return k
	return LIST.size() - 1


static func at(z: float) -> Dictionary:
	return LIST[index_at(z)]


## Bord nord (z minimal, exclu) du biome k ; -INF pour le dernier.
static func north_z(k: int) -> float:
	var top := BASE_Z
	for n in k + 1:
		var h: float = LIST[n]["height"]
		if h <= 0.0:
			return -INF
		top -= h
	return top


## Bord sud du biome k (le premier n'a pas de limite au sud).
static func south_z(k: int) -> float:
	return INF if k == 0 else north_z(k - 1)


## Profondeur relative de z dans la bande k (0 au sud, 1 au nord ; le dernier biome s'arrête au bord nord).
static func depth(k: int, z: float) -> float:
	var s := minf(south_z(k), BASE_Z)
	var n := north_z(k)
	if n == -INF:
		n = CaveShape.WORLD_Z0
	return clampf((s - z) / maxf(1.0, s - n), 0.0, 1.0)


## Minerais possibles à la profondeur relative f du biome k.
static func ores_at(k: int, f: float) -> Array[String]:
	var out: Array[String] = []
	var table: Dictionary = LIST[k]["ores"]
	for item: String in table:
		var r: Array = table[item]
		if f >= r[0] and f <= r[1]:
			out.append(item)
	return out


## Paliers de menace (Catalog.menace_tier) ajoutés aux rejetons d'un portail de niveau `threat`.
static func threat_tiers(threat: int) -> int:
	return maxi(0, threat - 1) * THREAT_STEP
