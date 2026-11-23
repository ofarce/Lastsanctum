extends RefCounted
## Fabrication : recettes de l'Atelier, de la Scierie, de l'Archerie, de la Fonderie et de l'Armurerie (spec du 2026-11-17).
## Scierie (fibre de bois) et Archerie (arc, flèches) prises à l'Atelier le 2026-11-20.
## Planche (Scierie) et Établi d'exo (mods fabriqués sur plan) ajoutés le 2026-11-22 (planches/intro-capsule-planche.html).
## Découpage du 2026-11-20 : la Fonderie (id « forge ») ne fait que des lingots ; l'Armurerie (id « creuset »)
## fait toutes les armes et armures, uniquement à partir de lingots.
## Les ingrédients sont pris dans le stock (coffre de base, puis sac de l'Ingénieur : ItemStorage.take) au
## moment de la mise en file ; chaque objet sort après la durée propre au bâtiment et rejoint le stock (ItemStorage.deposit).
## Les objets de l'Armurerie s'équipent sur l'Ingénieur sans armure : leurs emplacements et statistiques sont dans
## data/gear_items.gd.

const CRAFT_QUEUE := 5

## Objets fabriqués : nom affiché, couleur d'icône, effet décrit dans l'infobulle. « pending » : effet pas
## encore branché dans le jeu (pose au sol…), l'objet se fabrique et se stocke déjà. « disabled » : bouton grisé,
## fabrication refusée tant que l'objet ne sert à rien (2026-11-22).
const ITEMS := {
	# Atelier
	"torch": {"name": "Torche", "color": Color("#e0a040"), "pending": true,
		"desc": "Se pose par terre ou sur un mur ; halo de lumière de 3 cases."},
	"pickaxe": {"name": "Pioche", "color": Color("#8a8f96"), "disabled": true,
		"desc": "Consommée par un adepte pour pouvoir miner."},
	"chest": {"name": "Coffre", "color": Color("#8a6038"), "disabled": true,
		"desc": "Se pose par terre ; 10 emplacements de stockage."},
	"firing_post": {"name": "Poste de tir", "color": Color("#7a5a38"),
		"desc": "Une unité de tir postée derrière voit sa portée augmentée de moitié ; ne bloque pas les lignes de vue. Se pose sur une case (Ingénieur · Poser)."},
	"barricade": {"name": "Barricade", "color": Color("#6e6a60"),
		"desc": "Mur qui force le passage des attaquants ; ne bloque pas les lignes de vue. Se pose sur une case (Ingénieur · Poser)."},
	"fishing_rod": {"name": "Canne à pêche", "color": Color("#a08858"), "disabled": true,
		"desc": "Non utilisée pour le moment."},
	"caltrops": {"name": "Chausse-trappe", "color": Color("#5a5650"),
		"desc": "Piège posé au sol : 25 dégâts par seconde à chaque ennemi qui marche dessus. Se pose sur une case (Ingénieur · Poser)."},
	"focus_staff": {"name": "Bâton à focale", "color": Color("#b8e8d8"),
		"desc": "Nécessaire pour former un mage cristallisé (un par mage)."},
	# Scierie
	"wood_fiber": {"name": "Fibre de bois", "color": Color("#c8b080"),
		"desc": "Ingrédient des recettes de niveau supérieur."},
	# Plans de mods (2026-11-22) : objets du paquetage ; la recette est apprise à leur réception (GameState.plans).
	# Depuis le 2026-11-22, boss, ennemis et caches lâchent le plan de chaque mod, plus le mod (sim/loot.gd).
	"plan_analyse": {"name": "Plan de mod « Analyse »", "color": Color("#1f9fb8"),
		"desc": "Plan tyrien d’un module d’exo. Recette apprise : Analyse, à l’Établi d’exo (50 fibres de bois, 50 planches, 5 ichor)."},
	"plan_veil": {"name": "Plan de mod « Voile de la Martyre »", "color": Color("#1f9fb8"),
		"desc": "Plan tyrien d’un module d’exo. Recette apprise : Voile de la Martyre, à l’Établi d’exo (50 fibres de bois, 50 planches, 10 ichor)."},
	"plan_drill": {"name": "Plan de mod « Foreuse de Gorge-Cuivre »", "color": Color("#1f9fb8"),
		"desc": "Plan tyrien d’un module d’exo. Recette apprise : Foreuse de Gorge-Cuivre, à l’Établi d’exo (100 fibres de bois, 100 planches, 40 ichor, 20 lingots de cuivre)."},
	"plan_iris": {"name": "Plan de mod « Iris de la Matrice »", "color": Color("#1f9fb8"),
		"desc": "Plan tyrien d’un module d’exo. Recette apprise : Iris de la Matrice, à l’Établi d’exo (60 fibres de bois, 60 planches, 15 ichor, 5 lingots de cuivre)."},
	"plan_scale": {"name": "Plan de mod « Écaille d’esquive »", "color": Color("#1f9fb8"),
		"desc": "Plan tyrien d’un module d’exo. Recette apprise : Écaille d’esquive, à l’Établi d’exo (60 fibres de bois, 60 planches, 15 ichor, 5 lingots de cuivre)."},
	"plan_ember": {"name": "Plan de mod « Cœur de braise »", "color": Color("#1f9fb8"),
		"desc": "Plan tyrien d’un module d’exo. Recette apprise : Cœur de braise, à l’Établi d’exo (80 fibres de bois, 80 planches, 25 ichor, 10 lingots de cuivre)."},
	"plan_magnet": {"name": "Plan de mod « Aimant d’ichor »", "color": Color("#1f9fb8"),
		"desc": "Plan tyrien d’un module d’exo. Recette apprise : Aimant d’ichor, à l’Établi d’exo (50 fibres de bois, 50 planches, 10 ichor)."},
	"plan_lens": {"name": "Plan de mod « Lentille de souffle »", "color": Color("#1f9fb8"),
		"desc": "Plan tyrien d’un module d’exo. Recette apprise : Lentille de souffle, à l’Établi d’exo (60 fibres de bois, 60 planches, 15 ichor, 5 lingots de cuivre)."},
	"plan_barrel": {"name": "Plan de mod « Barillet double »", "color": Color("#1f9fb8"),
		"desc": "Plan tyrien d’un module d’exo. Recette apprise : Barillet double, à l’Établi d’exo (80 fibres de bois, 80 planches, 25 ichor, 10 lingots de cuivre)."},
	"plan_frost": {"name": "Plan de mod « Culasse froide »", "color": Color("#1f9fb8"),
		"desc": "Plan tyrien d’un module d’exo. Recette apprise : Culasse froide, à l’Établi d’exo (50 fibres de bois, 50 planches, 10 ichor)."},
	"plan_seal": {"name": "Plan de mod « Sceau sensible »", "color": Color("#1f9fb8"),
		"desc": "Plan tyrien d’un module d’exo. Recette apprise : Sceau sensible, à l’Établi d’exo (50 fibres de bois, 50 planches, 10 ichor)."},
	"plan_wisp": {"name": "Plan de mod « Lanterne de Medeina »", "color": Color("#1f9fb8"),
		"desc": "Plan tyrien d’un module d’exo. Recette apprise : Lanterne de Medeina, à l’Établi d’exo (60 fibres de bois, 60 planches, 15 ichor, 5 lingots de cuivre)."},
	"plan_anchor": {"name": "Plan de mod « Ancre de rappel »", "color": Color("#1f9fb8"),
		"desc": "Plan tyrien d’un module d’exo. Recette apprise : Ancre de rappel, à l’Établi d’exo (80 fibres de bois, 80 planches, 25 ichor, 10 lingots de cuivre)."},
	"plan_chant": {"name": "Plan de mod « Voix du Chantre »", "color": Color("#1f9fb8"),
		"desc": "Plan tyrien d’un module d’exo. Recette apprise : Voix du Chantre, à l’Établi d’exo (60 fibres de bois, 60 planches, 15 ichor, 5 lingots de cuivre)."},
	"plan_sack": {"name": "Plan de mod « Sac sans fond »", "color": Color("#1f9fb8"),
		"desc": "Plan tyrien d’un module d’exo. Recette apprise : Sac sans fond, à l’Établi d’exo (80 fibres de bois, 80 planches, 25 ichor, 10 lingots de cuivre)."},
	"plan_echo": {"name": "Plan de mod « Écho du pylône »", "color": Color("#1f9fb8"),
		"desc": "Plan tyrien d’un module d’exo. Recette apprise : Écho du pylône, à l’Établi d’exo (60 fibres de bois, 60 planches, 15 ichor, 5 lingots de cuivre)."},
	"plank": {"name": "Planche", "color": Color("#b08a5a"),
		"desc": "Bois refendu et dressé. Ingrédient des mods de l’Établi d’exo."},
	# Archerie
	"bow": {"name": "Arc", "color": Color("#9a7040"),
		"desc": "Nécessaire pour recruter un archer (un par archer)."},
	"arrows": {"name": "Flèches", "color": Color("#b89a6a"),
		"desc": "Munitions des archers. Fabriquées par lots de 15."},
	# Armurerie
	"sword": {"name": "Épée", "color": Color("#b8c0c8"),
		"desc": "Nécessaire pour recruter un Épée et bouclier (une par soldat)."},
	"shield": {"name": "Bouclier", "color": Color("#9aa4ae"),
		"desc": "Nécessaire pour recruter un Épée et bouclier (un par soldat)."},
	# Fonderie
	"copper_ingot": {"name": "Lingot de cuivre", "color": Color("#d4885e"),
		"desc": "Ingrédient des recettes de niveau supérieur."},
	"iron_ingot": {"name": "Lingot de fer", "color": Color("#9aa8b4"),
		"desc": "Ingrédient des recettes de niveau supérieur."},
	"gold_ingot": {"name": "Lingot d’or", "color": Color("#e8c060"),
		"desc": "Ingrédient des recettes de niveau supérieur."},
	# Strates des biomes 4 et 7 (2026-11-22) : lingots demandés par leurs recherches.
	"silver_ingot": {"name": "Lingot d’argent", "color": Color("#c4ccd8"),
		"desc": "Argent des Galeries muettes, fondu. Ingrédient des sceaux et des armes contre les morts."},
	"orichalcum_ingot": {"name": "Lingot d’orichalque", "color": Color("#e09a78"),
		"desc": "Orichalque de la Tyr enfouie, fondu. Ingrédient du Sceau d’or et des machines tyriennes."},
}

## Recettes par bâtiment, dans l'ordre des boutons. Les pièces d'équipement de l'Armurerie sont décrites dans gear_items.gd.
const RECIPES := {
	"workshop": {
		"torch": {"wood": 1},
		"pickaxe": {"wood": 1, "iron": 1},
		"chest": {"wood": 5, "iron": 1},
		"firing_post": {"wood": 10},
		"barricade": {"wood": 10, "rock": 10},
		"fishing_rod": {"wood": 2, "iron": 1, "wood_fiber": 1},
		"caltrops": {"wood": 25},
		"focus_staff": {"wood": 2, "quartz": 2},
	},
	"scierie": {
		"wood_fiber": {"wood": 1},
		"plank": {"wood": 2},
	},
	# Mods de l'Exilé fabriqués sur plan (PLANS) : la recette reste masquée tant que le plan n'est pas appris.
	"etabli": {
		"module_veil": {"wood_fiber": 50, "plank": 50, "ichor": 10},
		"module_drill": {"wood_fiber": 100, "plank": 100, "ichor": 40, "copper_ingot": 20},
		"module_iris": {"wood_fiber": 60, "plank": 60, "ichor": 15, "copper_ingot": 5},
		"module_scale": {"wood_fiber": 60, "plank": 60, "ichor": 15, "copper_ingot": 5},
		"module_ember": {"wood_fiber": 80, "plank": 80, "ichor": 25, "copper_ingot": 10},
		"module_magnet": {"wood_fiber": 50, "plank": 50, "ichor": 10},
		"module_lens": {"wood_fiber": 60, "plank": 60, "ichor": 15, "copper_ingot": 5},
		"module_barrel": {"wood_fiber": 80, "plank": 80, "ichor": 25, "copper_ingot": 10},
		"module_frost": {"wood_fiber": 50, "plank": 50, "ichor": 10},
		"module_seal": {"wood_fiber": 50, "plank": 50, "ichor": 10},
		"module_wisp": {"wood_fiber": 60, "plank": 60, "ichor": 15, "copper_ingot": 5},
		"module_anchor": {"wood_fiber": 80, "plank": 80, "ichor": 25, "copper_ingot": 10},
		"module_chant": {"wood_fiber": 60, "plank": 60, "ichor": 15, "copper_ingot": 5},
		"module_sack": {"wood_fiber": 80, "plank": 80, "ichor": 25, "copper_ingot": 10},
		"module_echo": {"wood_fiber": 60, "plank": 60, "ichor": 15, "copper_ingot": 5},
		"module_analyse": {"wood_fiber": 50, "plank": 50, "ichor": 5},
	},
	"archerie": {
		"bow": {"wood": 1, "wood_fiber": 1},
		"arrows": {"wood": 1},
	},
	"forge": {
		"copper_ingot": {"copper": 5},
		"iron_ingot": {"iron": 5},
		"gold_ingot": {"gold": 5},
		"silver_ingot": {"silver": 5},
		"orichalcum_ingot": {"orichalcum": 5},
	},
	"creuset": {
		"sword": {"copper_ingot": 2},
		"shield": {"copper_ingot": 2},
		"copper_armor": {"copper_ingot": 20},
		"iron_armor": {"iron_ingot": 40},
		"iron_greatsword": {"iron_ingot": 10},
		"iron_sword": {"iron_ingot": 5},
		"iron_shield": {"iron_ingot": 5},
		"copper_greatsword": {"copper_ingot": 5},
		"copper_sword": {"copper_ingot": 2},
		"copper_shield": {"copper_ingot": 2},
	},
}

## Objets consommés par unité recrutée, sauf l'archer qui demande un arc par groupe de 4.
const CASERNE_ITEMS := {
	"archer": {"bow": 1},
	"lame": {"sword": 1, "shield": 1},
	"guerisseuse": {"focus_staff": 1},
	"chantre": {"focus_staff": 1},
	"envouteur": {"focus_staff": 1},
}
## Rôles dont l'objet se compte par formation et non par combattant (un arc pour quatre archers, un bâton par mage).
const PER_TRAINING := ["archer", "guerisseuse", "chantre", "envouteur"]


## Recette grisée : visible mais refusée (ITEMS « disabled »).
static func disabled(item: String) -> bool:
	return bool(ITEMS.get(item, {}).get("disabled", false))


static func output_quantity(item: String) -> int:
	return 5 if item == "arrows" else 1


static func craft_time(building_type: String) -> float:
	if building_type == "etabli":
		return 30.0
	return 9.0 if building_type in ["workshop", "forge", "scierie", "archerie"] else 3.0


## Recettes sur plan : objet -> plan à connaître (GameState.plans). Le plan « analyse » vient du Coffre Antique,
## les autres du butin (sim/loot.gd). Coûts par rareté du mod, proposés le 2026-11-22, à régler.
const PLANS := {"module_veil": "veil", "module_drill": "drill", "module_iris": "iris", "module_scale": "scale", "module_ember": "ember", "module_magnet": "magnet", "module_lens": "lens", "module_barrel": "barrel", "module_frost": "frost", "module_seal": "seal", "module_wisp": "wisp", "module_anchor": "anchor", "module_chant": "chant", "module_sack": "sack", "module_echo": "echo", "module_analyse": "analyse"}
## Objet plan -> mod qu'il apprend à fabriquer.
const PLAN_ITEMS := {"plan_veil": "module_veil", "plan_drill": "module_drill", "plan_iris": "module_iris", "plan_scale": "module_scale", "plan_ember": "module_ember", "plan_magnet": "module_magnet", "plan_lens": "module_lens", "plan_barrel": "module_barrel", "plan_frost": "module_frost", "plan_seal": "module_seal", "plan_wisp": "module_wisp", "plan_anchor": "module_anchor", "plan_chant": "module_chant", "plan_sack": "module_sack", "plan_echo": "module_echo", "plan_analyse": "module_analyse"}


## Apprend la recette du plan `item` (ramassé, rapporté par l'Oublieux) ; vrai si elle était nouvelle.
static func learn(item: String) -> bool:
	if not PLAN_ITEMS.has(item):
		return false
	var plan: String = PLANS[PLAN_ITEMS[item]]
	if GameState.plans.has(plan):
		return false
	GameState.plans.append(plan)
	return true


## La recette est connue : elle ne demande pas de plan, ou son plan est appris.
static func plan_known(item: String) -> bool:
	return not PLANS.has(item) or GameState.plans.has(PLANS[item])


## Mod sur plan déjà fabriqué : il ne se refait pas.
static func once_done(item: String) -> bool:
	return PLANS.has(item) and GameState.mods_crafted.has(item)


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
	if Loot.ITEMS.has(item):
		return Loot.ITEMS[item]["name"]
	return preload("res://data/gear_items.gd").name_of(item)


static func desc_of(item: String) -> String:
	if ITEMS.has(item):
		return ITEMS[item]["desc"]
	if Loot.ITEMS.has(item):
		return Loot.ITEMS[item]["desc"]
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
	var item_count := ceili(count / 4.0) if role in PER_TRAINING else count
	for k: String in CASERNE_ITEMS.get(role, {}):
		out[k] = CASERNE_ITEMS[role][k] * item_count
	return out
