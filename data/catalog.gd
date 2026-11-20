class_name Catalog
extends RefCounted
## Catalogue de jeu du prototype (73b410f) : ressources, bâtiments, adeptes, coûts.
## Chaque valeur cite sa source. tests/test_catalog.gd vérifie l'égalité avec les valeurs extraites
## du jeu d'origine (assets/baked/hud/hud_texts.json, produit par tools/baker/hud.js).

const GearItems := preload("res://data/gear_items.gd")
const ItemStorage := preload("res://sim/item_storage.gd")
const Placeables := preload("res://sim/placeables.gd")

## RES_INFO, RES_ORDER, DEITY_RES (buildings.js:9-11).
const RES_ORDER: Array[String] = ["forge", "vie", "discipline", "savoir"]
const RES_INFO := {
	"forge": {"name": "Forge", "icon": "iron"},
	"vie": {"name": "Vie", "icon": "heart"},
	"discipline": {"name": "Discipline", "icon": "shield"},
	"savoir": {"name": "Savoir", "icon": "book"},
}
const DEITY_RES := {"sigil": "savoir", "aether": "forge", "medeina": "vie", "indra": "discipline"}

## BUILDINGS (buildings.js:20-30), dans l'ordre d'origine. size : côté en cases de 4 unités.
## Tous en 2 × 2 (planche batiments-2x2 ; le prototype en avait la plupart en 3 × 3).
const BUILDINGS := {
	"sigil": {"name": "Temple de Sigil", "cost": {"savoir": 20}, "deity": "sigil", "requires": "", "art": "da-sigil", "key": "g", "icon": "rune", "time": 4.0, "size": 2,
		"lore": "Ses adeptes y prient pour le Savoir."},
	"aether": {"name": "Temple d’Aether", "cost": {"forge": 20}, "deity": "aether", "requires": "", "art": "da-aether", "key": "e", "icon": "iron", "time": 4.0, "size": 2,
		"lore": "Ses adeptes y prient pour la Forge."},
	"medeina": {"name": "Temple de Medeina", "cost": {"vie": 20}, "deity": "medeina", "requires": "", "art": "da-medeina", "key": "v", "icon": "wood", "time": 4.0, "size": 2,
		"lore": "Ses adeptes y prient pour la Vie."},
	"indra": {"name": "Temple d’Indra", "cost": {"discipline": 20}, "deity": "indra", "requires": "", "art": "da-indra", "key": "i", "icon": "sword", "time": 4.0, "size": 2,
		"lore": "Ses adeptes y prient pour la Discipline."},
	"library": {"name": "Bibliothèque", "cost": {"savoir": 50}, "deity": "", "requires": "sigil", "art": "da-library", "key": "l", "icon": "book", "time": 8.0, "size": 2,
		"lore": "Les rouleaux de Sigil y sont rassemblés."},
	"forge": {"name": "Fonderie", "cost": {"forge": 50}, "deity": "", "requires": "aether", "art": "da-forge", "key": "f", "icon": "hammer", "time": 8.0, "size": 2,
		"lore": "Le minerai d’Aether y fond en lingots de cuivre, de fer et d’or."},
	"workshop": {"name": "Atelier", "cost": {"forge": 50}, "deity": "", "requires": "aether", "art": "da-workshop", "key": "t", "icon": "repair", "time": 8.0, "size": 2,
		"lore": "Établis et outils des artisans d’Aether."},
	"bedroom": {"name": "Chambre à coucher", "cost": {"vie": 50}, "deity": "", "requires": "medeina", "art": "da-bedroom", "key": "n", "icon": "people", "time": 8.0, "size": 2,
		"lore": "Le repos que Medeina accorde aux Exilés. Elle loge 10 Exilés de plus, sans personnel ; chaque nouvelle Chambre coûte le double de la précédente."},
	"soulwell": {"name": "Puits des Âmes", "cost": {"vie": 50}, "deity": "", "requires": "medeina", "art": "da-soulwell", "key": "u", "icon": "spirit", "time": 8.0, "size": 2,
		"heal_radius": 12.0, "heal_per_second": 5.0,
		"lore": "Soigne les unités proches de 5 PV par seconde dans un rayon de 12. Medeina y rend aussi leur souffle aux défunts, avec toute leur expérience."},
	"caserne": {"name": "Caserne", "cost": {"discipline": 50}, "deity": "", "requires": "indra", "art": "da-caserne", "key": "c", "icon": "shield", "time": 8.0, "size": 2,
		"lore": "Les disciples d’Indra y forment les combattants."},
	## Écart voulu (fabrication, 2026-11-17) : absent du prototype. Id « creuset » gardé ; renommé Armurerie le 2026-11-20
	## (armes et armures à partir des lingots de la Fonderie), coût baissé de 300 à 80 pour les soldats du début.
	"creuset": {"name": "Armurerie", "cost": {"forge": 80}, "deity": "", "requires": "forge", "art": "da-creuset", "key": "k", "icon": "sword", "time": 8.0, "size": 2,
		"lore": "On y façonne, à partir des lingots de la Fonderie, les armes et armures que portent les Exilés."},
	## Écart voulu (biomes, 2026-11-20) : absent du prototype. Chaque nuit, son Oublieux ramasse le butin (sim/oublieux.gd).
	"eglise": {"name": "Église des Oublieux", "cost": {"vie": 150}, "deity": "", "requires": "soulwell", "art": "da-eglise", "key": "o", "icon": "spirit", "time": 8.0, "size": 2,
		"lore": "Chaque nuit, un Oublieux en sort ramasser ce qui est tombé, douze objets par trajet, et le rapporte à son coffre. Tué, il revient la nuit suivante."},
	## Écart voulu (biomes, 2026-11-20) : forme les trois mages cristallisés (sim/mages.gd). « research » : recherche
	## exigée en plus du bâtiment requis.
	"ecole": {"name": "École de magie cristallisée", "cost": {"vie": 300}, "deity": "", "requires": "soulwell", "research": "limbo_mastery", "art": "da-ecole", "key": "z", "icon": "spirit", "time": 8.0, "size": 2,
		"lore": "Au bord du Fleuve des Limbes, des Exilés apprennent à laisser le cristal les gagner : Guérisseuse, Chantre, Envoûteur."},
	"warehouse": {"name": "Entrepôt logistique", "cost": {"savoir": 50}, "deity": "", "requires": "sigil", "art": "da-warehouse", "key": "p", "icon": "wood", "time": 8.0, "size": 2,
		"lore": "Les adeptes de Sigil y reçoivent le bois et les minerais pour les ateliers voisins."},
	## Écart voulu (découpage de la fabrication, 2026-11-20) : absents du prototype. La Scierie refend le bois brut,
	## l'Archerie en tire arcs et flèches (dessins de planches/batiments-v4-propositions.html).
	"scierie": {"name": "Scierie", "cost": {"forge": 50}, "deity": "", "requires": "aether", "art": "da-scierie", "key": "y", "icon": "wood", "time": 8.0, "size": 2,
		"lore": "La grande scie d’Aether refend les rondins en fibre de bois, pour l’Archerie et les recettes de niveau supérieur."},
	"archerie": {"name": "Archerie", "cost": {"forge": 50}, "deity": "", "requires": "scierie", "art": "da-archerie", "key": "j", "icon": "bow", "time": 8.0, "size": 2,
		"lore": "L’étuve attendrit les lattes, le gabarit les plie : on y fait les arcs et les flèches des archers."},
}

## Personnel des bâtiments (2026-11-17, sim/production.gd) : un bâtiment non-temple ne fonctionne qu'avec au moins
## un travailleur au poste (adepte du culte indiqué, ou l'Ingénieur) ; la vitesse est proportionnelle au nombre de
## travailleurs présents. Un seul culte par bâtiment.
## Chambre et Église des Oublieux (2026-11-20) : sans personnel, elles fonctionnent seules dès qu'elles sont achevées.
const STAFF_ROLE := {"warehouse": "sigil", "library": "sigil", "forge": "aether", "workshop": "aether", "creuset": "aether", "scierie": "aether", "archerie": "aether",
	"soulwell": "medeina", "ecole": "medeina", "caserne": "indra"}
## Culte du bâtisseur des bâtiments sans personnel (le chantier reste confié à un adepte de Medeina).
const BUILD_ROLE := {"bedroom": "medeina", "eglise": "medeina"}
const STAFF_MAX := 5
## Mineurs d'un bâtiment : adeptes d'Aether qui exploitent un gisement inépuisable et rapportent des lots au dépôt.
## Ils ne comptent pas dans la vitesse ; limite distincte de celle des postes.
const MINER_ROLE := "aether"
const MINERS_MAX := 5
const MINE_BATCH := 5

## Population (2026-11-19) : POP_BASE places, +POP_PER_BEDROOM par Chambre achevée (sans personnel depuis le 2026-11-20) ; ancien texte : tenue par un adepte de
## Medeina. Un combattant de caserne occupe POP_WEIGHT places, toute autre unité une seule. Le plafond ne
## bloque que les nouvelles arrivées (invocation, entraînement, héros, résurrection).
const POP_BASE := 10
const POP_PER_BEDROOM := 10
const POP_WEIGHT := {"flammes": 2, "archer": 2, "lame": 2, "oublieux": 0, "guerisseuse": 2, "chantre": 2, "envouteur": 2}


static func pop_weight(role: String) -> int:
	return int(POP_WEIGHT.get(role, 1))


## Coût d'un nouveau bâtiment de ce type : celui du catalogue, sauf la Chambre à coucher qui double à
## chaque Chambre déjà posée (50, 100, 200…).
static func building_cost(type: String) -> Dictionary:
	var cost: Dictionary = BUILDINGS[type]["cost"]
	if type != "bedroom":
		return cost
	var n := 0
	for b: Building in GameState.buildings:
		if b.type == "bedroom":
			n += 1
	var out := {}
	for k: String in cost:
		out[k] = int(cost[k]) * (1 << mini(n, 20))
	return out


## Coût par défaut d'une recherche sans « cost » propre. Le Sceau de minage n'est plus une recherche :
## il est remis à la première entrée dans la capsule (Capsule.toggle, GameState.mining_seal).
const MINING_COST := {"forge": 10, "vie": 10, "discipline": 10, "savoir": 10}
const RESEARCH := {
	# Bibliothèque (2026-11-19) : coût propre (« cost »), sinon MINING_COST.
	"minimap": {"name": "Minicarte", "building": "library", "requires": [], "cost": {"savoir": 500}, "icon": "move",
		"desc": "La minicarte reste affichée pendant l’incarnation."},
	"firing_post": {"name": "Poste de tir", "building": "library", "requires": [], "cost": {"discipline": 500}, "icon": "flag",
		"desc": "Débloque la fabrication du poste de tir à l’Atelier."},
	"modular_crossbow": {"name": "Arbalestrie modulaire", "building": "library", "requires": [],
		"cost": {"forge": 200, "vie": 200, "discipline": 200, "savoir": 200}, "icon": "barillet",
		"desc": "Débloque cinq munitions pour l’Arbalestrie, à choisir au barillet près de la barre de vie : spirituelles, d’Indra, de Medeina, de Sigil, d’Aether."},
	# Biome 1 (2026-11-20, planches/biomes-1-2-elements.html) : payées en ressource et en bois (« items », pris au
	# stock : coffre de base puis sac de l'Ingénieur). « glyph » : objet dont l'icône sert de dessin au bouton.
	"gallery_props": {"name": "Étais de galerie", "building": "workshop", "requires": [], "cost": {"forge": 150}, "items": {"wood": 60}, "glyph": "pickaxe",
		"desc": "Les adeptes minent 25 % plus vite."},
	"sylviculture": {"name": "Sylviculture", "building": "soulwell", "requires": [], "cost": {"vie": 200}, "items": {"wood": 40}, "glyph": "wood",
		"desc": "Un bosquet pétrifié abattu repousse en trois vagues."},
	"copper_tips": {"name": "Pointes de cuivre", "building": "caserne", "requires": [], "cost": {"discipline": 300}, "items": {"copper_ingot": 10},
		"desc": "Archers : + 25 % de dégâts. Leur carquois porte des pointes de cuivre."},
	"verdigris_balm": {"name": "Baume de vert-de-gris", "building": "soulwell", "requires": [], "cost": {"vie": 400}, "items": {"copper_ingot": 10},
		"desc": "Soin du Puits des Âmes : 5 → 8 PV par seconde."},
	"copper_seal": {"name": "Sceau de cuivre", "building": "forge", "requires": [], "cost": {"forge": 300}, "items": {"copper": 20}, "glyph": "copper_ingot",
		"desc": "La roche de vert-de-gris du biome 2 se creuse (8 coups)."},
	# Biome 2 : payée en lingots de cuivre.
	"limbo_mastery": {"name": "Maîtrise du Fleuve des Limbes", "building": "soulwell", "requires": [], "cost": {"vie": 400}, "items": {"copper_ingot": 10}, "glyph": "copper_ingot",
		"desc": "Débloque l’École de magie cristallisée et le bâton à focale à l’Atelier."},
	"palisades": {"name": "Palissades", "building": "library", "requires": [], "cost": {"savoir": 250}, "items": {"wood": 80}, "glyph": "barricade",
		"desc": "Barricades : + 50 % de PV, y compris celles déjà posées. Elles portent un bardage de bois."},
	"fletching": {"name": "Empennage", "building": "caserne", "requires": [], "cost": {"discipline": 200}, "items": {"wood": 100}, "glyph": "arrows",
		"desc": "Archers : portée + 15 %. Leurs flèches portent une penne blanche."},
}
## Effets chiffrés des recherches du biome 1.
const PROPS_MINING := 1.25
const FLETCHING_REACH := 1.15
const REGROW_WAVES := 3
const COPPER_TIPS_DAMAGE := 1.25
const BALM_HEAL := 8.0
## Recettes verrouillées par une recherche : objet → recherche.
const RECIPE_RESEARCH := {"firing_post": "firing_post", "focus_staff": "limbo_mastery"}


static func research_cost(id: String) -> Dictionary:
	return RESEARCH.get(id, {}).get("cost", MINING_COST)


## Objets demandés en plus par une recherche (bois…), vide le plus souvent.
static func research_items(id: String) -> Dictionary:
	return RESEARCH.get(id, {}).get("items", {})


static func can_pay_research(id: String) -> bool:
	return can_pay(research_cost(id)) and ItemStorage.has_all(research_items(id))


## « 150 Forge + 60 Bois ».
static func research_cost_text(id: String) -> String:
	var text := cost_text(research_cost(id))
	var items := research_items(id)
	return text if items.is_empty() else text + " + " + preload("res://data/recipes.gd").cost_text(items)
const RESEARCH_TIME := 10.0
const RESEARCH_MENACE := 0
const ANCHOR_MENACE_COST := {"forge": 100, "vie": 100, "discipline": 100, "savoir": 100}
const ANCHOR_MENACE_GAIN := 50


## SUMMON_COST, CASERNE_COST, CASERNE_TIME, CASERNE_QUEUE, CASERNE_UNITS (buildings.js:36-37).
const SUMMON_COST := 10
const CASERNE_COST := {"discipline": 100}
const CASERNE_TIME := 6.0
const CASERNE_QUEUE := 5
## File d'invocation d'un temple : une seule arrivée à la fois, les suivantes attendent (2026-11-19).
const TEMPLE_QUEUE := 5
const CASERNE_UNITS := [
	{"id": "flammes", "label": "Lance-flammes", "key": "l", "icon": "flame"},
	{"id": "archer", "label": "Archer", "key": "u", "icon": "bow"},
	{"id": "lame", "label": "Épée et bouclier", "key": "e", "icon": "shield"},
]
## École de magie cristallisée : un mage par formation (150 Vie et un bâton à focale apporté au coffre bleu).
const ECOLE_COST := {"vie": 150}
const ECOLE_UNITS := [
	{"id": "guerisseuse", "label": "Guérisseuse", "key": "g", "icon": "heart"},
	{"id": "chantre", "label": "Chantre", "key": "h", "icon": "flag"},
	{"id": "envouteur", "label": "Envoûteur", "key": "j", "icon": "rune"},
]
## Bâtiments qui forment des unités : leurs unités, et le nombre de combattants que représente une formation
## (la Caserne sort une unité qui en vaut quatre, l'École un mage).
const TRAINERS := {"caserne": CASERNE_UNITS, "ecole": ECOLE_UNITS}
const TRAIN_SIZE := {"caserne": 4, "ecole": 1}
## Chiffres de départ des mages (planches/biomes-1-2-elements.html), en unités de monde (une case = 4).
## Soin : PV par seconde à l'allié le plus blessé à portée. Aura : dégâts des alliés dans le rayon (deux auras ne
## se cumulent pas). Envoûtement : armure retirée à la cible et à ses voisins (spread) pendant `time` s.
const MAGE := {
	"guerisseuse": {"rate": 6.0, "reach": 32.0, "status": "Soigne l’allié le plus blessé à portée · n’attaque pas"},
	"chantre": {"bonus": 1.2, "radius": 24.0, "status": "Aura : + 20 % de dégâts aux alliés proches · n’attaque pas"},
	"envouteur": {"armor": 3.0, "time": 5.0, "cd": 4.0, "reach": 32.0, "spread": 6.0, "status": "Envoûte : − 3 d’armure à la cible et à ses voisins · n’attaque pas"},
}


static func is_mage(role: String) -> bool:
	return MAGE.has(role)


static func train_cost(id: String) -> Dictionary:
	return ECOLE_COST if is_mage(id) else CASERNE_COST


## Objets consommés par une formation (arcs, épées, bâton à focale…).
static func train_items(id: String) -> Dictionary:
	return preload("res://data/recipes.gd").caserne_cost(id, 4)


## HERO_COST (adepts.js:158).
const HERO_COST := {"forge": 100, "vie": 100, "discipline": 100, "savoir": 100}

## DEITY_PORTALS (Index.html) : noms des dieux, dans l'ordre de la rangée nord.
## DEITY_LOOK[id].glow[3] (Index.html:295) : éclair de sortie d'un adepte au portail de son dieu.
## Écart voulu D16 (charte graphique) : Indra orange, Sigil blanc, Medeina vert, Aether bleu-violet.
const DEITY_GLOW := {"indra": Color("#ff8a2a"), "sigil": Color("#dde2ee"), "medeina": Color("#7ae070"), "aether": Color("#7a80ff")}
## Rampe du portail de chaque dieu (DA.DEITIES[id].portal, da-planches.js), du plus sombre au plus clair :
## lueurs de la méditation de l'Ingénieur.
const DEITY_RAMP := {
	"medeina": [Color("#0d3010"), Color("#1f6420"), Color("#3fa83a"), Color("#7ae070"), Color("#c8f5b0"), Color("#f4fff0")],
	"indra": [Color("#3a1404"), Color("#7a3008"), Color("#c85a10"), Color("#ff8a2a"), Color("#ffc890"), Color("#fff4e8")],
	"sigil": [Color("#3a3e4a"), Color("#6a7080"), Color("#a8b0c0"), Color("#dde2ee"), Color("#f4f6ff"), Color("#ffffff")],
	"aether": [Color("#140f40"), Color("#2c2690"), Color("#4a48d0"), Color("#7a80ff"), Color("#c0c4ff"), Color("#f0f0ff")],
}
const DEITY_NAMES :={"indra": "Indra", "sigil": "Sigil", "medeina": "Medeina", "aether": "Aether"}

## ADEPT (adepts.js:5-14).
const ADEPT := {
	"sigil": {"name": "Adepte de Sigil", "task": "pray", "hp": 90, "lore": "Sa prière au temple de Sigil nourrit le Savoir."},
	"medeina": {"name": "Adepte de Medeina", "task": "pray", "hp": 95, "lore": "Sa prière au temple de Medeina nourrit la Vie."},
	"aether": {"name": "Adepte d’Aether", "task": "pray", "hp": 100, "lore": "Sa prière au temple d’Aether nourrit la Forge."},
	"indra": {"name": "Adepte d’Indra", "task": "pray", "hp": 110, "lore": "Sa prière au temple d’Indra nourrit la Discipline."},
	"flammes": {"name": "Adepte lance-flammes", "task": "fight", "hp": 120, "lore": "Le feu de sa lance ne laisse derrière lui que des cendres."},
	"archer": {"name": "Adepte archer", "task": "fight", "hp": 85, "lore": "Sa flèche part avant que l’ennemi ne l’ait vu."},
	"lame": {"name": "Adepte d’épée et bouclier", "task": "fight", "hp": 170, "lore": "Son bouclier est un mur que la meute ne franchit pas."},
	## Ramasseur de l'Église des Oublieux (sim/oublieux.gd) : humain, ne se bat pas, ne reçoit pas d'ordres.
	## Mages cristallisés (École de magie cristallisée) : humains, ne se battent pas, reculent au contact.
	"guerisseuse": {"name": "Guérisseuse cristallisée", "task": "mage", "hp": 60, "lore": "Cinq éclats tournent derrière sa tête. Ce qu’ils touchent se referme."},
	"chantre": {"name": "Chantre cristallisé", "task": "mage", "hp": 70, "lore": "Son diapason de cristal donne le ton ; les lames alentour frappent juste."},
	"envouteur": {"name": "Envoûteur cristallisé", "task": "mage", "hp": 60, "lore": "Des fils de lumière lui pendent des doigts. Là où ils s’accrochent, le fer devient mou."},
	"oublieux": {"name": "Oublieux", "task": "glean", "hp": 60, "lore": "Il ramasse la nuit ce que les morts ont laissé. Personne ne se rappelle son nom, lui non plus."},
}

## FIGHT (adepts.js:16-25) : seek = rayon de détection, reach = portée, dmg, cd = recharge ; splash = rayon de
## brûlure (lance-flammes) ; guard = part des dégâts subis (épée et bouclier) ; melee = mêlée de l'archer après
## sa charge ; ranged = tir à distance.
## Écart voulu D13 (après 73b410f) : portée du lance-flammes ×2 (4,5 → 9, détection 9 → 18) et de l'archer ×4
## (14 → 56, détection 17 → 68). 2026-11-17 : portées encore ×2 (lance-flammes 24/36, archer 112/136).
## Écart voulu D15 : lance-flammes à portée 12, tir continu (dmg / cd par seconde, soit 20/s au niveau 1, dans
## `splash` autour de la cible), sans sillon de feu ; il explose à sa mort (FLAME_DEATH).
## 2026-11-19 : archer ramené à 20 de portée (30 au poste de tir), détection 26 ; il ne repère un ennemi que
## s'il le voit (ligne dégagée, Combat.archer_target).
const MELEE_ADEPT := {"seek": 6.0, "reach": 1.9, "dmg": 4, "cd": 1.1, "status": "En attente · petite attaque au corps à corps"}
const FIGHT := {
	"flammes": {"seek": 36.0, "reach": 24.0, "dmg": 6, "cd": 0.3, "splash": 2.2, "continuous": true, "status": "Garde l’Ancre · flammes en continu ; explose à sa mort"},
	"archer": {"seek": 26.0, "reach": 20.0, "dmg": 11, "cd": 0.95, "melee": {"reach": 2.3, "dmg": 13, "cd": 0.6}, "status": "Garde l’Ancre · arc, puis Charge du Lac au contact"},
	"lame": {"seek": 7.0, "reach": 2.2, "dmg": 16, "cd": 0.85, "guard": 0.55, "status": "Garde l’Ancre · mêlée ; moulinet d’orage toutes les 3 frappes"},
	"sigil": MELEE_ADEPT, "medeina": MELEE_ADEPT, "aether": MELEE_ADEPT, "indra": MELEE_ADEPT,
	"engineer": {"seek": 6.0, "reach": 1.9, "dmg": 5, "cd": 1.15, "ranged": false, "status": "Prêt à recevoir vos ordres · corps à corps"},
}
## Charge du Lac de l'archer (CHARGE), moulinet d'orage (MOULINET), sillon de flammes (SILLON), adepts.js.
const CHARGE := {"trigger": 5.0, "reset": 8.0, "speed": 16.0, "dmg": 22, "stun": 0.5, "max_t": 0.6}
const MOULINET := {"charges": 3, "r": 2.8, "dmg": 24}
## Explosion du lance-flammes à sa mort (D15) : dégâts fixes aux ennemis dans le rayon r.
const FLAME_DEATH := {"dmg": 45, "r": 3.0}
const SILLON := {"cd": 4.0, "len": 8.0, "w": 0.9, "dmg": 12, "wall": 2.0, "burn": 3.0, "slow": 0.6}
## Expérience gagnée en achevant un ennemi (KILL_XP).
const KILL_XP := {"creep": 10, "spitter": 15, "brute": 35, "beast": 6, "skeleton": 4, "skeleton_bubo": 6, "skeleton_bomb": 5, "scout": 12, "soldier": 22, "shield": 28, "archer": 15, "strazhar": 60, "martyre": 200, "oeil": 300, "oeil_pupille": 15}
## Menace gagnée à la mort d'un ennemi de vague, selon son type (les gardiens de pylône, errants, squelettes et
## meutes nocturnes n'en rapportent pas : Enemy.beast). Type absent : 1.
const KILL_MENACE := {"creep": 1, "scout": 2, "archer": 2, "spitter": 2, "soldier": 4, "shield": 5, "brute": 6, "strazhar": 12,
	"martyre": 0, "oeil": 0, "oeil_pupille": 0}
## Un champion ouvre les assauts dès ce seuil, même avant la vague 8.
const STRAZHAR_MENACE := 1000
## Difficulté par paliers de menace ; coefficients partagés par le combat et le HUD.
const MENACE_STEP := 100
const MENACE_WAVE := {"base": 6, "per_wave": 4, "count": 2, "composition_step": 2, "hp": 0.04, "damage": 0.02, "armor_step": 5, "champion_start": 10, "champion_step": 5}
const MENACE_PORTAL := {"interval_step": 0.35, "min_interval": 3.5, "max_cap": 16, "hp": 0.08, "damage": 0.05}


static func menace_tier(menace: int) -> int:
	return floori(float(maxi(0, menace)) / MENACE_STEP)


static func menace_stats(tier: int, portal: bool = false) -> Dictionary:
	var rules: Dictionary = MENACE_PORTAL if portal else MENACE_WAVE
	return {"hp": 1.0 + rules["hp"] * tier, "damage": 1.0 + rules["damage"] * tier,
		"armor": 0 if portal else floori(float(tier) / MENACE_WAVE["armor_step"])}


static func menace_portal_interval(tier: int) -> float:
	return maxf(MENACE_PORTAL["min_interval"], EVIL["interval"] - MENACE_PORTAL["interval_step"] * tier)


static func menace_portal_cap(tier: int) -> int:
	return mini(MENACE_PORTAL["max_cap"], EVIL["cap"] + tier)


## Allure des ennemis de vague : vitesse de marche et cadence d'animation (+30 %).
const WAVE_PACE := 1.3
## Flot nocturne (sim/night.gd) : des squelettes épars se lèvent dehors, du crépuscule à la fin de nuit (fractions
## de journée FROM → TO), toutes les EARLY s au début puis toutes les PEAK s au cœur de la nuit ; chaque palier de
## menace resserre l'intervalle de RATE (plancher MIN_GAP). Ils sortent n'importe où sur le no man's land :
## |x| ≤ X, à FLANK unités au moins du flanc de la montagne (jamais dans la grotte ni à sa porte) et à CLEAR
## unités au moins de toute unité alliée.
const NIGHT_FLOW := {"from": 0.62, "to": 0.92, "early": 7.0, "peak": 3.0, "rate": 0.15, "min_gap": 1.2,
	"x": 150.0, "flank": 25.0, "clear": 30.0,
	# Part de chaque type parmi les levées (un collier = un trio).
	"mix": {"skeleton": 0.3, "skeleton_bubo": 0.4, "skeleton_bomb": 0.3}}
## Meute nocturne d'un pylône non canalisé (sim/night.gd) : une par nuit, lancée à la fraction AT de la journée ;
## BASE chiens + PER_TIER par palier de menace (CAP au plus), statistiques des gardiens (MENACE_PORTAL).
const NIGHT_RAID := {"at": 0.7, "base": 3, "per_tier": 1, "cap": 12}

## Soldats du Credo (fiches ENNEMI · CREDO et CREDO SOUILLÉ) : vitesse ×1,15 sur celle d'ENEMY (2026-11-20, demande),
## appliquée par Enemy.make. Ceux sans arme de tir (CREDO_MELEE) accélèrent encore de CREDO_RUSH ×1,2 dès qu'ils ont
## détecté une cible vivante, pour aller au contact au plus vite (Combat).
const CREDO_KINDS := ["scout", "soldier", "archer", "creep", "spitter", "brute"]
const CREDO_MELEE := ["scout", "creep", "brute"]
const CREDO_SPEED := 1.15
const CREDO_RUSH := 1.2

## Ennemis (spawn, Index.html ; rejetons : updateEvilPortals, galleries.js).
## Portée des tireurs (archer, soldier, spitter, beast) et détection des ennemis doublées le 2026-11-20 (demande).
## Dégâts des monstres doublés le 2026-11-20 (demande), boss exceptés (gorge, martyre, oeil).
const ENEMY := {
	"creep": {"hp": 35, "speed": 3.2, "range": 1.5, "damage": 24, "cd": 1.15},
	## Squelette du flot nocturne (sim/night.gd) : frêle, sans sprite propre pour l'instant (dessiné en fanatique pâle).
	# Squelettes de la nuit (sim/skeletons.gd) : à collier (par trois), à bubons (lent), explosif (court, fragile).
	"skeleton": {"hp": 20, "speed": 3.4, "range": 1.5, "damage": 14, "cd": 1.15},
	"skeleton_bubo": {"hp": 30, "speed": 2.7, "range": 1.5, "damage": 14, "cd": 1.3},
	"skeleton_bomb": {"hp": 14, "speed": 6.0, "range": 1.5, "damage": 10, "cd": 1.0},
	"spitter": {"hp": 48, "speed": 2.0, "range": 40.0, "damage": 20, "cd": 1.15},
	"brute": {"hp": 110, "speed": 1.4, "range": 1.5, "damage": 44, "cd": 1.7},
	"beast": {"hp": 88, "speed": 8.0, "range": 32.0, "damage": 8, "cd": 1.15},
	"scout": {"hp": 45, "speed": 3.7, "range": 1.5, "damage": 24, "cd": 1.05, "armor": 1},
	"soldier": {"hp": 75, "speed": 2.1, "range": 10.0, "damage": 36, "cd": 1.3, "armor": 3},
	"shield": {"hp": 85, "speed": 1.7, "range": 1.5, "damage": 28, "cd": 1.5, "armor": 9},
	"archer": {"hp": 45, "speed": 3.4, "range": 20.0, "damage": 22, "cd": 1.4, "armor": 1},
	"strazhar": {"hp": 600, "speed": 8.4, "range": 1.7, "damage": 128.0 / 3.0, "cd": 0.85, "armor": 8},
	## Faune des Veines de vert-de-gris (biome 2, errants des galeries : sim/roamers.gd). Chiffres de la planche.
	"tick": {"hp": 40, "speed": 1.6, "range": 1.5, "damage": 10, "cd": 1.5, "armor": 4},
	## Boss de fin du biome 2 (sim/gorge.gd) : armure des anneaux ; dégâts doublés gueule ouverte.
	"gorge": {"hp": 2400, "speed": 0.0, "range": 0.0, "damage": 30, "cd": 99.0, "armor": 5},
	## Anguille des puits : immobile dans son bassin (sim/wildlife.gd), sa décharge touche tout ce qui en approche.
	"eel": {"hp": 60, "speed": 0.0, "range": 13.5, "damage": 16, "cd": 3.0},
	"bat": {"hp": 18, "speed": 7.0, "range": 1.5, "damage": 6, "cd": 1.2},
	## Premier boss (sim/martyre.gd) : jamais dans les vagues ; dégâts fixes à l'Ingénieur, impact différé.
	## Faune hostile de la jungle (sim/wildlife.gd en surcharge les valeurs).
	"croc": {"hp": 160, "speed": 3.4, "range": 1.6, "damage": 28, "cd": 1.6, "armor": 4},
	"feline": {"hp": 90, "speed": 4.3, "range": 1.4, "damage": 20, "cd": 0.9, "armor": 1},
	"martyre": {"hp": 2000, "speed": 2.2, "range": 2.4, "damage": 10, "cd": 3.0 / 1.3},
	## Boss de la frontière (sim/oeil.gd) : immobile au centre de sa salle ; racines au contact.
	"oeil": {"hp": 5600, "speed": 0.0, "range": 0.0, "damage": 10, "cd": 1.2},
	## Pupilles errantes de l'Œil (attaque « Pupilles errantes ») : volent en orbite et tirent ; cibles fragiles.
	"oeil_pupille": {"hp": 60, "speed": 0.0, "range": 0.0, "damage": 0, "cd": 99.0},
}
## Portails maléfiques (EVIL) : un rejeton toutes les 7 s, 8 au plus par portail.
const EVIL := {"interval": 7.0, "cap": 8}
## Balistes (TURRET_CONFIG, turret-game.js).
## Coups annoncés (planches/unites-maj-propositions.html, L4) : l'ennemi arme son geste pendant ce temps (s, à la
## cadence de la vague) avant que le coup ne tombe ; hors de portée à ce moment-là, la cible l'esquive.
## Portée de détection des chiens de la Bête (cases), partout : vagues, errants des galeries, meutes de pylône.
const BEAST_SIGHT := 32.0
## Les chiens ne mordent plus (2026-11-20) : ils ne font que cracher, jusqu'à leur portée (ENEMY.beast.range), et
## s'arrêtent à cette distance de leur cible quand la ligne de tir est dégagée (sinon ils s'approchent encore).
const BEAST_STANDOFF := 6.0
const ENEMY_WINDUP := {"brute": 0.4, "strazhar": 0.25}
## Marge de portée au moment où le coup tombe (unités de monde).
const ENEMY_WINDUP_SLACK := 0.8
const TURRET := {"range": 70.0, "damage": 40, "repair_time": 8.0, "cycle": 3.6, "bolt_speed": 85.0}
## Héros hors FIGHT (update, Index.html) : détection, portée, recharge.
const HERO := {
	"paladin": {"seek": 3.0, "reach": 2.2, "cd": 0.88},
	"healer": {"seek": 9.0, "reach": 8.6, "cd": 1.15},
	"shooter": {"seek": 20.0, "reach": 17.2, "cd": 0.78},
	"guard": {"seek": 10.0, "reach": 8.6, "cd": 1.15},
}
## Fiches des ennemis sélectionnés dans le HUD (écart voulu D14 : le prototype ne sélectionne pas les ennemis).
const ENEMY_INFO := {
	"tick": {"name": "Tique de filon", "kind": "FAUNE · VERT-DE-GRIS", "lore": "Collée à son filon, elle se gave de cuivre et perfore de son rostre de fer quiconque vient le lui disputer. Elle n’attaque que ce qui l’approche."},
	"gorge": {"name": "Gorge-Cuivre", "kind": "BOSS · DÉVOREUSE DE FILONS", "lore": "Un mille-pattes cuirassé long comme une galerie. Elle a mangé tous les filons de la grande salle et dort dessous. Ses anneaux arrêtent les coups ; sa gueule, non."},
	"eel": {"name": "Anguille des puits", "kind": "FAUNE · NEUTRE", "lore": "Une crête d’épines de cuivre lui sort du dos. Elle ne quitte jamais son bassin ; sa décharge frappe tout ce qui s’en approche, Exilés comme ennemis."},
	"bat": {"name": "Chauve-souris patinée", "kind": "FAUNE · VERT-DE-GRIS", "lore": "Poitrail plaqué de cuivre, ailes trouées. Elles chassent en nuées et piquent droit."},
	"skeleton": {"name": "Squelette à collier", "kind": "ENNEMI · NUIT", "lore": "Ils se lèvent par trois, enchaînés par le cou : aucun ne s’éloigne des deux autres. Frappé, il lâche des éclats d’os et de fer."},
	"skeleton_bubo": {"name": "Squelette à bubons", "kind": "ENNEMI · NUIT", "lore": "Voûté, couvert de bubons de bile. Chaque coup en fait éclater un, qui brûle tout ce qui l’entoure, sauf les siens."},
	"skeleton_bomb": {"name": "Squelette explosif", "kind": "ENNEMI · NUIT", "lore": "Une braise lui tient lieu de cœur. Abattu, il tombe à genoux, puis explose et crache dix boules de feu."},
	"scout": {"name": "Infanterie légère", "kind": "ENNEMI · CREDO", "lore": "Un éclaireur rapide, légèrement protégé, qui ouvre la marche des soldats du Credo."},
	"soldier": {"name": "Soldat du Credo", "kind": "ENNEMI · CREDO", "lore": "Casque à crête et cuirasse : l’infanterie régulière du Credo lance son pilum à courte portée."},
	"shield": {"name": "Bouclier doré", "kind": "ENNEMI · BYRSA", "lore": "Un soldat humain en armure, protégé par un grand bouclier doré. Sa défense absorbe l’essentiel des frappes légères."},
	"archer": {"name": "Archer de la Lumière", "kind": "ENNEMI · CREDO", "lore": "Un éclaireur armé d’un arc, qui décoche ses flèches de lumière à distance."},
	"strazhar": {"name": "Strazhar", "kind": "ENNEMI · CHAMPION DE BYRSA", "lore": "Champion rapide de Byrsa, dont l’équipement magique est lié aux tissus vivants de la Bête."},
	"creep": {"name": "Fanatique du Credo", "kind": "ENNEMI · CREDO SOUILLÉ", "lore": "Robe ivoire trempée d’ichor noir : il frappe au contact pour son maître caché."},
	"spitter": {"name": "Thuriféraire de Fortuna", "kind": "ENNEMI · CREDO SOUILLÉ", "lore": "Prêtre du Credo : il lance de loin un sort de lumière souillée par la Bête."},
	"brute": {"name": "Automate doré de Byrsa", "kind": "ENNEMI · CREDO SOUILLÉ", "lore": "Un automate d’or fêlé ; ses coups lourds brisent les lignes."},
	"martyre": {"name": "Martyre de Byrsa", "kind": "BOSS · CHAMPIONNE DE BYRSA", "lore": "L’armure d’un automate d’or s’est soudée à son corps. Sous son bouclier, elle n’accepte que le combat singulier."},
	"croc": {"name": "Crocodile des berges", "kind": "FAUNE · NEUTRE", "lore": "Il guette au ras de l’eau, près des ponts, et happe tout ce qui passe trop près : Exilés comme soldats du Credo."},
	"feline": {"name": "Félin de la jungle", "kind": "FAUNE · NEUTRE", "lore": "Un grand fauve tacheté qui défend son territoire dans la forêt dense. La nuit, il voit de plus loin."},
	"oeil": {"name": "Œil de la Matrice", "kind": "BOSS · GARDIEN DE LA FRONTIÈRE", "lore": "Une montagne de chair pâle, au cœur de laquelle un œil immense suit chacun de vos pas. Tant qu’il regarde, nul ne passe vers le nord."},
	"oeil_pupille": {"name": "Pupille errante", "kind": "BOSS · ŒIL DE LA MATRICE", "lore": "L’iris de l’Œil, sorti de son orbite et divisé en trois. Elle tourne autour de la salle et vise l’Ingénieur ; un coup suffit presque à la crever."},
	"beast": {"name": "Aberration du Dévoreur", "kind": "ENNEMI · CHAIR DU DÉVOREUR", "lore": "Chair pâle et gueules multiples, vomie par les galeries."},
}
## Dégâts de base des unités hors FIGHT (updateHUD, hud.js).
const BASE_DAMAGE := {"paladin": 30, "shooter": 19, "healer": 9, "guard": 12}

## HUD_LORE (hud.js).
const HUD_LORE := {
	"engineer": "Il relève les pierres pour que demeure le serment.",
	"paladin": "Son bouclier porte le poids des serments oubliés.",
	"healer": "Dans le silence de l’Ancre, il écoute les vivants.",
	"shooter": "Une seule respiration, puis le silence.",
	"guard": "La force tient dans les rangs qui ne cèdent pas.",
}

## Expérience (adepts.js) : palier du niveau suivant, bonus de dégâts et de défense.
static func xp_need(level: int) -> int:
	return roundi(20.0 * pow(1.6, level - 1))


static func lvl(u: Unit) -> int:
	return u.level if u and u.level > 0 else 1


static func armor(u: Unit) -> int:
	return int((lvl_bonus(u) + GearItems.total(u, "armor")) * u.power) + (500 if u.role == "engineer" and not u.unarmored else 0)


## Arme portée par l'Ingénieur sans armure, si elle peut frapper (une arme à munitions en demande une au stock).
static func gear_weapon(u: Unit) -> Dictionary:
	if u == null or u.role != "engineer" or not u.unarmored:
		return {}
	var w := GearItems.weapon(u)
	if not w.has("damage"):
		return {}
	if w.has("ammo") and ItemStorage.count(w["ammo"]) <= 0:
		return {}
	return w


static func attack_damage(u: Unit) -> int:
	if u.role == "engineer" and not u.unarmored:
		return 1000
	var w := gear_weapon(u)
	if not w.is_empty():
		return int(w["damage"])
	return FIGHT[u.role]["dmg"] if FIGHT.has(u.role) else BASE_DAMAGE.get(u.role, 0)


## Les adeptes d'Indra frappent deux fois plus fort.
static func damage_mult(u: Unit) -> float:
	return 2.0 if u != null and u.role == "indra" else 1.0


static func lvl_bonus(u: Unit) -> int:
	return lvl(u) - 1


## costText : « 20 Savoir + 10 Forge ».
static func cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k: String in cost:
		parts.append("%d %s" % [cost[k], RES_INFO[k]["name"]])
	return " + ".join(parts)


## shortCost : « 100+100+100+100 ».
static func short_cost(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k: String in cost:
		parts.append(str(cost[k]))
	return "+".join(parts)


static func can_pay(cost: Dictionary) -> bool:
	for k: String in cost:
		if GameState.res[k] < cost[k]:
			return false
	return true


static func pay(cost: Dictionary) -> void:
	for k: String in cost:
		GameState.res[k] -= cost[k]


static func refund(cost: Dictionary) -> void:
	for k: String in cost:
		GameState.res[k] += cost[k]


## Portée d'attaque sans bonus de poste de tir.
static func base_reach(u: Unit) -> float:
	if u.role == "engineer" and not u.unarmored:
		return 250.0
	var w := gear_weapon(u)
	# Épée du Creuset : taille à 1,5 bloc (data/gear_items.gd, melee).
	if w.has("melee"):
		return float(w["melee"])
	var reach: float = float(w["reach"]) if w.has("reach") else (Catalog.FIGHT[u.role]["reach"] if Catalog.FIGHT.has(u.role) else Catalog.HERO.get(u.role, {"reach": 8.6})["reach"])
	# Empennage (recherche de la Caserne) : les archers tirent plus loin.
	if u.role == "archer" and GameState.research_done.has("fletching"):
		reach *= FLETCHING_REACH
	return reach


## Portée d'attaque d'une unité alliée (FIGHT, sinon HERO) : partagée par le combat et le HUD.
static func unit_reach(u: Unit) -> float:
	var base := base_reach(u)
	if u.role == "engineer" and not u.unarmored:
		return base
	# Brume (core/weather.gd) : dehors, les tireurs portent moins loin ; la mêlée n'est pas touchée.
	if base > 3.0:
		base *= Weather.reach_at(u.x, u.z)
	# Poste de tir posé à côté : portée ×1,5 (sim/placeables.gd).
	return base * Placeables.reach_factor(u, base) if not GameState.placed.is_empty() else base


static func is_adept(u: Unit) -> bool:
	return u != null and ADEPT.has(u.role)


static func prays(u: Unit) -> bool:
	return u != null and DEITY_RES.has(u.role)


## Le coût de recrutement total est converti en Vie, puis multiplié par le niveau.
static func revive_cost(u: Unit) -> Dictionary:
	var initial := 0
	if DEITY_RES.has(u.role):
		initial = SUMMON_COST
	elif CASERNE_UNITS.any(func(entry: Dictionary) -> bool: return entry["id"] == u.role):
		for amount: int in CASERNE_COST.values():
			initial += amount
	else:
		for amount: int in HERO_COST.values():
			initial += amount
	return {"vie": initial * lvl(u)}
