extends RefCounted
## Fabrication : recettes de l'Atelier, de la Forge et du Creuset des Exilés (spec du 2026-11-17).
## Les ingrédients sont pris dans le stock (coffre de base, puis sac de l'Ingénieur : ItemStorage.take) au
## moment de la mise en file ; chaque objet sort après la durée propre au bâtiment et rejoint le stock (ItemStorage.deposit).
## Les objets du Creuset s'équipent sur l'Ingénieur sans armure : leurs emplacements et statistiques sont dans
## data/gear_items.gd.

const CRAFT_QUEUE := 5

## Objets fabriqués : nom affiché, couleur d'icône, effet décrit dans l'infobulle. « pending » : effet pas
## encore branché dans le jeu (pose au sol, pêche…), l'objet se fabrique et se stocke déjà.
const ITEMS := {
	# Atelier
	"torch": {"name": "Torche", "color": Color("#e0a040"), "pending": true,
		"desc": "Se pose par terre ou sur un mur ; halo de lumière de 3 cases."},
	"pickaxe": {"name": "Pioche", "color": Color("#8a8f96"), "pending": true,
		"desc": "Consommée par un adepte pour pouvoir miner."},
	"arrows": {"name": "Flèches", "color": Color("#b89a6a"),
		"desc": "Munitions des archers. Fabriquées par lots de 15."},
	"chest": {"name": "Coffre", "color": Color("#8a6038"), "pending": true,
		"desc": "Se pose par terre ; 10 emplacements de stockage."},
	"wood_fiber": {"name": "Fibre de bois", "color": Color("#c8b080"),
		"desc": "Ingrédient des recettes de niveau supérieur."},
	"firing_post": {"name": "Poste de tir", "color": Color("#7a5a38"),
		"desc": "Une unité de tir postée derrière voit sa portée doublée ; ne bloque pas les lignes de vue. Se pose sur une case (Ingénieur · Poser)."},
	"barricade": {"name": "Barricade", "color": Color("#6e6a60"),
		"desc": "Mur qui force le passage des attaquants ; ne bloque pas les lignes de vue. Se pose sur une case (Ingénieur · Poser)."},
	"fishing_rod": {"name": "Canne à pêche", "color": Color("#a08858"), "pending": true,
		"desc": "Non utilisée pour le moment."},
	"bow": {"name": "Arc", "color": Color("#9a7040"),
		"desc": "Nécessaire pour recruter un archer (un par archer)."},
	"caltrops": {"name": "Chausse-trappe", "color": Color("#5a5650"),
		"desc": "Piège posé au sol : 25 dégâts par seconde à chaque ennemi qui marche dessus. Se pose sur une case (Ingénieur · Poser)."},
	# Forge
	"sword": {"name": "Épée", "color": Color("#b8c0c8"),
		"desc": "Nécessaire pour recruter un Épée et bouclier (une par soldat)."},
	"shield": {"name": "Bouclier", "color": Color("#9aa4ae"),
		"desc": "Nécessaire pour recruter un Épée et bouclier (un par soldat)."},
	"copper_ingot": {"name": "Lingot de cuivre", "color": Color("#d4885e"),
		"desc": "Ingrédient des recettes de niveau supérieur."},
	"iron_ingot": {"name": "Lingot de fer", "color": Color("#9aa8b4"),
		"desc": "Ingrédient des recettes de niveau supérieur."},
	"gold_ingot": {"name": "Lingot d’or", "color": Color("#e8c060"),
		"desc": "Ingrédient des recettes de niveau supérieur."},
}

## Recettes par bâtiment, dans l'ordre des boutons. Les objets du Creuset sont décrits dans gear_items.gd.
const RECIPES := {
	"workshop": {
		"torch": {"wood": 1},
		"pickaxe": {"wood": 1, "iron": 1},
		"arrows": {"wood": 1},
		"chest": {"wood": 5, "iron": 1},
		"wood_fiber": {"wood": 1},
		"firing_post": {"wood": 10},
		"barricade": {"wood": 10, "rock": 10},
		"fishing_rod": {"wood": 2, "iron": 1, "wood_fiber": 1},
		"bow": {"wood": 1, "wood_fiber": 1},
		"caltrops": {"wood": 25},
	},
	"forge": {
		"sword": {"copper": 5, "iron": 5},
		"shield": {"copper": 5, "iron": 5},
		"copper_ingot": {"copper": 5},
		"iron_ingot": {"iron": 5},
		"gold_ingot": {"gold": 5},
	},
	"creuset": {
		"copper_armor": {"copper": 100},
		"iron_armor": {"iron": 200},
		"iron_greatsword": {"iron_ingot": 10},
		"iron_sword": {"iron_ingot": 5},
		"iron_shield": {"iron_ingot": 5},
		"copper_greatsword": {"copper_ingot": 5},
		"copper_sword": {"copper_ingot": 2},
		"copper_shield": {"copper_ingot": 2},
		"cannon": {"iron_ingot": 10},
	},
}

## Objets consommés par unité recrutée, sauf l'archer qui demande un arc par groupe de 4.
const CASERNE_ITEMS := {
	"archer": {"bow": 1},
	"lame": {"sword": 1, "shield": 1},
}


static func output_quantity(item: String) -> int:
	return 15 if item == "arrows" else 1


static func craft_time(building_type: String) -> float:
	return 9.0 if building_type in ["workshop", "forge"] else 3.0


static func has_station(building_type: String) -> bool:
	return RECIPES.has(building_type)


static func cost_of(item: String) -> Dictionary:
	for station: String in RECIPES:
		if RECIPES[station].has(item):
			return RECIPES[station][item]
	return {}


## Nom de tout objet du jeu : matière, objet fabriqué ou pièce d'équipement.
static func name_of(item: String) -> String:
	if ITEMS.has(item):
		return ITEMS[item]["name"]
	var blocks: Dictionary = preload("res://data/mineable_blocks.gd").ITEMS
	if blocks.has(item):
		return blocks[item]["name"]
	return preload("res://data/gear_items.gd").name_of(item)


static func desc_of(item: String) -> String:
	if ITEMS.has(item):
		return ITEMS[item]["desc"]
	return preload("res://data/gear_items.gd").ITEMS.get(item, {}).get("desc", "")


## « 5 Cuivre + 5 Fer ».
static func cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k: String in cost:
		parts.append("%d %s" % [cost[k], name_of(k)])
	return " + ".join(parts)


## Objets de caserne pour `count` unités du rôle `role` (vide si le rôle n'en demande pas).
static func caserne_cost(role: String, count: int) -> Dictionary:
	var out := {}
	var item_count := ceili(count / 4.0) if role == "archer" else count
	for k: String in CASERNE_ITEMS.get(role, {}):
		out[k] = CASERNE_ITEMS[role][k] * item_count
	return out
