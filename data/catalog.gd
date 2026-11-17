class_name Catalog
extends RefCounted
## Catalogue de jeu du prototype (73b410f) : ressources, bâtiments, adeptes, coûts.
## Chaque valeur cite sa source. tests/test_catalog.gd vérifie l'égalité avec les valeurs extraites
## du jeu d'origine (assets/baked/hud/hud_texts.json, produit par tools/baker/hud.js).

const GearItems := preload("res://data/gear_items.gd")
const ItemStorage := preload("res://sim/item_storage.gd")

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
	"forge": {"name": "Forge", "cost": {"forge": 50}, "deity": "", "requires": "aether", "art": "da-forge", "key": "f", "icon": "hammer", "time": 8.0, "size": 2,
		"lore": "L’enclume d’Aether y résonne."},
	"workshop": {"name": "Atelier", "cost": {"forge": 50}, "deity": "", "requires": "aether", "art": "da-workshop", "key": "t", "icon": "repair", "time": 8.0, "size": 2,
		"lore": "Établis et outils des artisans d’Aether."},
	"bedroom": {"name": "Chambre à coucher", "cost": {"vie": 50}, "deity": "", "requires": "medeina", "art": "da-bedroom", "key": "n", "icon": "people", "time": 8.0, "size": 2,
		"lore": "Le repos que Medeina accorde aux Exilés."},
	"soulwell": {"name": "Puits des Âmes", "cost": {"vie": 50}, "deity": "", "requires": "medeina", "art": "da-soulwell", "key": "u", "icon": "spirit", "time": 8.0, "size": 2,
		"heal_radius": 12.0, "heal_per_second": 5.0,
		"lore": "Soigne les unités proches de 5 PV par seconde dans un rayon de 12. Medeina y rend aussi leur souffle aux défunts, avec toute leur expérience."},
	"caserne": {"name": "Caserne", "cost": {"discipline": 50}, "deity": "", "requires": "indra", "art": "da-caserne", "key": "c", "icon": "shield", "time": 8.0, "size": 2,
		"lore": "Les disciples d’Indra y forment les combattants."},
	## Écart voulu (fabrication, 2026-11-17) : absent du prototype ; dessin de la Forge en attendant le sien.
	"creuset": {"name": "Creuset des Exilés", "cost": {"forge": 300}, "deity": "", "requires": "forge", "art": "da-creuset", "key": "k", "icon": "sword", "time": 8.0, "size": 2,
		"lore": "On y coule les armes et armures que portent les Exilés."},
	"warehouse": {"name": "Entrepôt logistique", "cost": {"savoir": 50}, "deity": "", "requires": "sigil", "art": "da-library", "key": "p", "icon": "wood", "time": 8.0, "size": 2,
		"lore": "Les adeptes de Sigil y reçoivent le bois et les minerais pour les ateliers voisins."},
}

## Personnel des bâtiments (2026-11-17, sim/production.gd) : un bâtiment non-temple ne fonctionne qu'avec au moins
## un travailleur au poste (adepte du culte indiqué, ou l'Ingénieur) ; la vitesse est proportionnelle au nombre de
## travailleurs présents. Un seul culte par bâtiment.
const STAFF_ROLE := {"warehouse": "sigil", "library": "sigil", "forge": "aether", "workshop": "aether", "creuset": "aether",
	"bedroom": "medeina", "soulwell": "medeina", "caserne": "indra"}
const STAFF_MAX := 5
## Mineurs d'un bâtiment : adeptes d'Aether qui exploitent un gisement inépuisable et rapportent des lots au dépôt.
## Ils ne comptent pas dans la vitesse ; limite distincte de celle des postes.
const MINER_ROLE := "aether"
const MINERS_MAX := 5
const MINE_BATCH := 5

## Recherches uniques du sceau de minage, partagées entre tous les bâtiments.
const MINING_COST := {"forge": 10, "vie": 10, "discipline": 10, "savoir": 10}
const RESEARCH := {
	"mining_concept": {"name": "Concept - Sceau de Minage", "building": "library", "requires": []},
	"mining_spark": {"name": "Etincelle - Sceau de Minage", "building": "soulwell", "requires": []},
	"mining_power": {"name": "Puissance - Sceau de Minage", "building": "caserne", "requires": []},
	"mining_artifact": {"name": "Artefact - Sceau de Minage", "building": "forge", "requires": ["mining_concept", "mining_spark", "mining_power"]},
}
const RESEARCH_TIME := 10.0
const RESEARCH_MENACE := 20
const ANCHOR_MENACE_COST := {"forge": 100, "vie": 100, "discipline": 100, "savoir": 100}
const ANCHOR_MENACE_GAIN := 50


## SUMMON_COST, CASERNE_COST, CASERNE_TIME, CASERNE_QUEUE, CASERNE_UNITS (buildings.js:36-37).
const SUMMON_COST := 10
const CASERNE_COST := {"discipline": 100}
const CASERNE_TIME := 6.0
const CASERNE_QUEUE := 5
const CASERNE_UNITS := [
	{"id": "flammes", "label": "Lance-flammes", "key": "l", "icon": "flame"},
	{"id": "archer", "label": "Archer", "key": "u", "icon": "bow"},
	{"id": "lame", "label": "Épée et bouclier", "key": "e", "icon": "shield"},
]
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
}

## FIGHT (adepts.js:16-25) : seek = rayon de détection, reach = portée, dmg, cd = recharge ; splash = rayon de
## brûlure (lance-flammes) ; guard = part des dégâts subis (épée et bouclier) ; melee = mêlée de l'archer après
## sa charge ; ranged = tir à distance.
## Écart voulu D13 (après 73b410f) : portée du lance-flammes ×2 (4,5 → 9, détection 9 → 18) et de l'archer ×4
## (14 → 56, détection 17 → 68).
## Écart voulu D15 : lance-flammes à portée 12, tir continu (dmg / cd par seconde, soit 20/s au niveau 1, dans
## `splash` autour de la cible), sans sillon de feu ; il explose à sa mort (FLAME_DEATH).
const MELEE_ADEPT := {"seek": 6.0, "reach": 1.9, "dmg": 4, "cd": 1.1, "status": "En attente · petite attaque au corps à corps"}
const FIGHT := {
	"flammes": {"seek": 18.0, "reach": 12.0, "dmg": 6, "cd": 0.3, "splash": 2.2, "continuous": true, "status": "Garde l’Ancre · flammes en continu ; explose à sa mort"},
	"archer": {"seek": 68.0, "reach": 56.0, "dmg": 11, "cd": 0.95, "melee": {"reach": 2.3, "dmg": 13, "cd": 0.6}, "status": "Garde l’Ancre · arc, puis Charge du Lac au contact"},
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
const KILL_XP := {"creep": 10, "spitter": 15, "brute": 35, "beast": 6, "scout": 12, "soldier": 22, "shield": 28, "archer": 15, "strazhar": 60}
## Un champion ouvre les assauts dès ce seuil, même avant la vague 8.
const STRAZHAR_MENACE := 1000
## Difficulté par paliers de menace ; coefficients partagés par le combat et le HUD.
const MENACE_STEP := 100
const MENACE_WAVE := {"count": 2, "composition_step": 2, "hp": 0.04, "damage": 0.02, "armor_step": 5, "champion_start": 10, "champion_step": 5}
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


## Ennemis (spawn, Index.html ; rejetons : updateEvilPortals, galleries.js).
const ENEMY := {
	"creep": {"hp": 35, "speed": 2.7, "range": 1.5, "damage": 6, "cd": 1.15},
	"spitter": {"hp": 48, "speed": 2.0, "range": 9.0, "damage": 5, "cd": 1.15},
	"brute": {"hp": 110, "speed": 1.4, "range": 1.5, "damage": 12, "cd": 1.7},
	"beast": {"hp": 22, "speed": 2.6, "range": 1.5, "damage": 4, "cd": 1.15},
	"scout": {"hp": 45, "speed": 3.1, "range": 1.5, "damage": 6, "cd": 1.05, "armor": 1},
	"soldier": {"hp": 75, "speed": 2.1, "range": 1.5, "damage": 9, "cd": 1.3, "armor": 3},
	"shield": {"hp": 85, "speed": 1.7, "range": 1.5, "damage": 8, "cd": 1.5, "armor": 9},
	"archer": {"hp": 45, "speed": 2.8, "range": 10.0, "damage": 6, "cd": 1.4, "armor": 1},
	"strazhar": {"hp": 600, "speed": 8.4, "range": 1.7, "damage": 64.0 / 3.0, "cd": 0.85, "armor": 8},
}
## Portails maléfiques (EVIL) : un rejeton toutes les 7 s, 8 au plus par portail.
const EVIL := {"interval": 7.0, "cap": 8}
## Balistes (TURRET_CONFIG, turret-game.js).
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
	"scout": {"name": "Infanterie légère", "kind": "ENNEMI · CREDO", "lore": "Un éclaireur rapide, légèrement protégé, qui ouvre la marche des soldats du Credo."},
	"soldier": {"name": "Soldat du Credo", "kind": "ENNEMI · CREDO", "lore": "Casque, cuirasse et épée : l’infanterie régulière du Credo avance sans hésiter."},
	"shield": {"name": "Bouclier doré", "kind": "ENNEMI · BYRSA", "lore": "Un soldat humain en armure, protégé par un grand bouclier doré. Sa défense absorbe l’essentiel des frappes légères."},
	"archer": {"name": "Archer de la Lumière", "kind": "ENNEMI · CREDO", "lore": "Un éclaireur armé d’un arc, qui décoche ses flèches de lumière à distance."},
	"strazhar": {"name": "Strazhar", "kind": "ENNEMI · CHAMPION DE BYRSA", "lore": "Champion rapide de Byrsa, dont l’équipement magique est lié aux tissus vivants de la Bête."},
	"creep": {"name": "Fanatique du Credo", "kind": "ENNEMI · CREDO SOUILLÉ", "lore": "Robe ivoire trempée d’ichor noir : il frappe au contact pour son maître caché."},
	"spitter": {"name": "Thuriféraire de Fortuna", "kind": "ENNEMI · CREDO SOUILLÉ", "lore": "Il projette de loin une lumière souillée par la Bête."},
	"brute": {"name": "Automate doré de Byrsa", "kind": "ENNEMI · CREDO SOUILLÉ", "lore": "Un automate d’or fêlé ; ses coups lourds brisent les lignes."},
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
	return lvl_bonus(u) + (500 if u.role == "engineer" and not u.unarmored else 0) + GearItems.total(u, "armor")


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


## Portée d'attaque d'une unité alliée (FIGHT, sinon HERO) : partagée par le combat et le HUD.
static func unit_reach(u: Unit) -> float:
	if u.role == "engineer" and not u.unarmored:
		return 250.0
	var w := gear_weapon(u)
	if w.has("reach"):
		return float(w["reach"])
	return Catalog.FIGHT[u.role]["reach"] if Catalog.FIGHT.has(u.role) else Catalog.HERO.get(u.role, {"reach": 8.6})["reach"]


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
