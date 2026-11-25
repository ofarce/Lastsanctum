class_name Biomes
## Bandes de biomes de la montagne, empilées vers le nord (z décroissant) à partir du flanc sud.
## Chaque biome a une hauteur fixe ; le dernier s'étend jusqu'au bord nord de la carte (et au-delà quand
## le monde deviendra infini). Fonctions pures : un biome ne dépend que de z.

## Puissance des monstres par biome (demande du 2026-11-25) : dégâts et vitesse des projectiles +5 % par biome au-delà
## du Temple (Temple ×1, Salles oubliées ×1,05, …). Lue à la position du monstre à sa création (Enemy.make,
## Wildlife) et du projectile à son départ (EnemyShots._add, balles des boss).
const POWER_STEP := 0.05
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
		# 2026-11-20 : le Temple ne porte plus que du cuivre (et son bois) ; fer, quartz et or viennent des biomes suivants.
		"ores": {"copper": [0.0, 0.4]},
		"decor": {"mountain_rock": 1.37}},
	# Salles oubliées (ex-Veines de vert-de-gris, renommées le 2026-11-25 ; strate validée le 2026-11-20) : le cuivre partout et en majorité, le quartz en
	# second, des traces de fer dans le cinquième nord, pas d'or. Plus de bassins (les anguilles y vivront).
	# « rock » : type de la roche nue de la bande (data/mineable_blocks.gd). Un troisième nombre dans une plage
	# de minerai est son poids au tirage (1 par défaut).
	{"id": "biome2", "name": "Salles oubliées", "height": 336.0, "tier": 1, "threat": 2, "rock": "rock2",
		"worms": 9.0, "steps": [40, 90], "radius": [1.6, 2.6], "room": 0.03, "branch": 0.035,
		"clearings": 1.5, "pools": 1.6, "lodes": 2.5, "veins": 14.0,
		"ores": {"copper": [0.0, 1.0, 3], "quartz": [0.0, 1.0], "iron": [0.8, 1.0]},
		"decor": {"mountain_rock": 1.0}},
	# Six strates avant Byrsa (planches/biomes-3-8-propositions.html, validée le 2026-11-22). Socle seulement :
	# bande, roche scellée, minerai ; leurs mécaniques, bestiaires et boss viennent par lots.
	# Roches : 12, 14, 16, 18, 20 puis 24 coups (data/mineable_blocks.gd), chacune derrière son sceau.
	{"id": "forges", "name": "Les Forges mortes", "height": 256.0, "tier": 2, "threat": 3, "rock": "rock3",
		"worms": 9.0, "steps": [40, 90], "radius": [1.7, 2.8], "room": 0.04, "branch": 0.035,
		"clearings": 1.2, "pools": 0.0, "lodes": 2.5, "veins": 14.0,
		"ores": {"iron": [0.0, 1.0, 3], "copper": [0.0, 0.3]},
		"decor": {"mountain_rock": 1.0}},
	{"id": "galeries", "name": "Les Galeries muettes", "height": 256.0, "tier": 3, "threat": 4, "rock": "rock4",
		"worms": 10.0, "steps": [50, 110], "radius": [1.6, 2.4], "room": 0.02, "branch": 0.05,
		"clearings": 0.8, "pools": 0.8, "lodes": 2.0, "veins": 14.0,
		"ores": {"silver": [0.0, 1.0, 3], "iron": [0.0, 0.3]},
		"decor": {"mountain_rock": 1.0}},
	{"id": "limbes", "name": "Les Rives des Limbes", "height": 256.0, "tier": 4, "threat": 5, "rock": "rock5",
		"worms": 8.0, "steps": [40, 90], "radius": [1.8, 3.0], "room": 0.05, "branch": 0.03,
		"clearings": 1.2, "pools": 2.0, "lodes": 1.5, "veins": 12.0,
		"ores": {"tear": [0.0, 1.0, 3], "quartz": [0.0, 1.0], "silver": [0.0, 0.3]},
		"decor": {"mountain_rock": 1.0}},
	{"id": "ventre", "name": "Le Ventre de la Bête", "height": 256.0, "tier": 5, "threat": 6, "rock": "rock6",
		"worms": 9.0, "steps": [40, 90], "radius": [1.8, 3.0], "room": 0.06, "branch": 0.04,
		"clearings": 1.0, "pools": 0.0, "lodes": 2.0, "veins": 14.0,
		"ores": {"amber": [0.0, 1.0, 3]},
		"decor": {"mountain_rock": 1.0}},
	{"id": "tyr", "name": "La Tyr enfouie", "height": 256.0, "tier": 6, "threat": 7, "rock": "rock7",
		"worms": 8.0, "steps": [50, 100], "radius": [1.8, 2.8], "room": 0.07, "branch": 0.04,
		"clearings": 1.0, "pools": 0.4, "lodes": 2.0, "veins": 10.0,
		"ores": {"orichalcum": [0.0, 1.0, 3], "quartz": [0.0, 1.0]},
		"decor": {"mountain_rock": 1.0}},
	{"id": "cryptes", "name": "Les Cryptes de l’Aube", "height": 0.0, "tier": 7, "threat": 8, "rock": "rock8",
		"worms": 9.0, "steps": [40, 90], "radius": [1.7, 2.6], "room": 0.06, "branch": 0.04,
		"clearings": 0.8, "pools": 0.0, "lodes": 1.5, "veins": 12.0,
		"ores": {"gold": [0.0, 1.0, 3], "quartz": [0.0, 1.0, 2]},
		"decor": {"mountain_rock": 1.0}},
]

## Roche nue de chaque palier (Biomes.rock_tier) : 0 ardoise du Temple, 1 vert-de-gris, puis une par strate.
const ROCKS: Array[String] = ["rock", "rock2", "rock3", "rock4", "rock5", "rock6", "rock7", "rock8"]


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


## Multiplicateur de dégâts et de vitesse des projectiles des monstres à la profondeur z.
static func power_at(z: float) -> float:
	return 1.0 + POWER_STEP * index_at(z)


static func at(z: float) -> Dictionary:
	return LIST[index_at(z)]


## Palier de la roche nue à la profondeur z : 0 ardoise du Temple, 1 roche de vert-de-gris (« rock2 »), etc.
## Il choisit la texture du dessus, la paroi et les teintes de bord (une roche par sceau de minage).
static func rock_tier(z: float) -> int:
	return maxi(0, ROCKS.find(String(at(z).get("rock", "rock"))))


## Suffixe des textures d'un palier (floor, rock, dug) : "" pour le Temple, puis "2" … "8".
static func tile_suffix(tier: int) -> String:
	return "" if tier <= 0 else str(tier + 1)


## Suffixe des sprites d'un palier (parois, décor) : "" pour le Temple, puis "_r2" … "_r8".
static func sprite_suffix(tier: int) -> String:
	return "" if tier <= 0 else "_r%d" % (tier + 1)


## Index du biome d'identifiant `id` (-1 s'il n'existe pas).
static func index_of(id: String) -> int:
	for k in LIST.size():
		if LIST[k]["id"] == id:
			return k
	return -1


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
			for n in (int(r[2]) if r.size() > 2 else 1):
				out.append(item)
	return out


## Paliers de menace (Catalog.menace_tier) ajoutés aux rejetons d'un portail de niveau `threat`.
static func threat_tiers(threat: int) -> int:
	return maxi(0, threat - 1) * THREAT_STEP
