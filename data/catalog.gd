class_name Catalog
extends RefCounted
## Catalogue de jeu du prototype (73b410f) : ressources, bâtiments, adeptes, coûts.
## Chaque valeur cite sa source. tests/test_catalog.gd vérifie l'égalité avec les valeurs extraites
## du jeu d'origine (assets/baked/hud/hud_texts.json, produit par tools/baker/hud.js).

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
const BUILDINGS := {
	"sigil": {"name": "Temple de Sigil", "cost": {"savoir": 20}, "deity": "sigil", "requires": "", "art": "da-sigil", "key": "g", "icon": "rune", "time": 4.0, "size": 3,
		"lore": "Ses adeptes y prient pour le Savoir."},
	"aether": {"name": "Temple d’Aether", "cost": {"forge": 20}, "deity": "aether", "requires": "", "art": "da-aether", "key": "e", "icon": "iron", "time": 4.0, "size": 3,
		"lore": "Ses adeptes y prient pour la Forge."},
	"medeina": {"name": "Temple de Medeina", "cost": {"vie": 20}, "deity": "medeina", "requires": "", "art": "da-medeina", "key": "v", "icon": "wood", "time": 4.0, "size": 3,
		"lore": "Ses adeptes y prient pour la Vie."},
	"indra": {"name": "Temple d’Indra", "cost": {"discipline": 20}, "deity": "indra", "requires": "", "art": "da-indra", "key": "i", "icon": "sword", "time": 4.0, "size": 3,
		"lore": "Ses adeptes y prient pour la Discipline."},
	"library": {"name": "Bibliothèque", "cost": {"savoir": 200}, "deity": "", "requires": "sigil", "art": "library", "key": "l", "icon": "book", "time": 8.0, "size": 3,
		"lore": "Les rouleaux de Sigil y sont rassemblés."},
	"forge": {"name": "Forge", "cost": {"forge": 200}, "deity": "", "requires": "aether", "art": "forge", "key": "f", "icon": "hammer", "time": 8.0, "size": 3,
		"lore": "L’enclume d’Aether y résonne."},
	"workshop": {"name": "Atelier", "cost": {"forge": 200}, "deity": "", "requires": "aether", "art": "workshop", "key": "t", "icon": "repair", "time": 8.0, "size": 3,
		"lore": "Établis et outils des artisans d’Aether."},
	"bedroom": {"name": "Chambre à coucher", "cost": {"vie": 200}, "deity": "", "requires": "medeina", "art": "bedroom", "key": "n", "icon": "people", "time": 8.0, "size": 2,
		"lore": "Le repos que Medeina accorde aux Exilés."},
	"soulwell": {"name": "Puits des Âmes", "cost": {"vie": 200}, "deity": "", "requires": "medeina", "art": "soulwell", "key": "u", "icon": "spirit", "time": 8.0, "size": 2,
		"lore": "Medeina y rend leur souffle aux défunts, avec toute leur expérience."},
	"caserne": {"name": "Caserne", "cost": {"discipline": 200}, "deity": "", "requires": "indra", "art": "caserne", "key": "c", "icon": "shield", "time": 8.0, "size": 3,
		"lore": "Les disciples d’Indra y forment les combattants."},
}

## SUMMON_COST, CASERNE_COST, CASERNE_TIME, CASERNE_QUEUE, REVIVE_COST, CASERNE_UNITS (buildings.js:36-37).
const SUMMON_COST := 50
const CASERNE_COST := {"discipline": 100}
const CASERNE_TIME := 6.0
const CASERNE_QUEUE := 5
const REVIVE_COST := {"vie": 200}
const CASERNE_UNITS := [
	{"id": "flammes", "label": "Lance-flammes", "key": "l", "icon": "flame"},
	{"id": "archer", "label": "Archer", "key": "u", "icon": "bow"},
	{"id": "lame", "label": "Épée et bouclier", "key": "e", "icon": "shield"},
]
## HERO_COST (adepts.js:158).
const HERO_COST := {"forge": 100, "vie": 100, "discipline": 100, "savoir": 100}

## DEITY_PORTALS (Index.html) : noms des dieux, dans l'ordre de la rangée nord.
## DEITY_LOOK[id].glow[3] (Index.html:295) : éclair de sortie d'un adepte au portail de son dieu.
## Écart voulu D15 (charte graphique) : Indra orange, Sigil blanc, Medeina vert, Aether bleu-violet.
const DEITY_GLOW := {"indra": Color("#ff8a2a"), "sigil": Color("#dde2ee"), "medeina": Color("#7ae070"), "aether": Color("#7a80ff")}
const DEITY_NAMES := {"indra": "Indra", "sigil": "Sigil", "medeina": "Medeina", "aether": "Aether"}

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
const MELEE_ADEPT := {"seek": 6.0, "reach": 1.9, "dmg": 4, "cd": 1.1, "status": "En attente · petite attaque au corps à corps"}
const FIGHT := {
	"flammes": {"seek": 18.0, "reach": 9.0, "dmg": 6, "cd": 0.3, "splash": 2.2, "status": "Garde l’Ancre · flammes ; sillon de feu toutes les 4 s"},
	"archer": {"seek": 68.0, "reach": 56.0, "dmg": 11, "cd": 0.95, "melee": {"reach": 2.3, "dmg": 13, "cd": 0.6}, "status": "Garde l’Ancre · arc, puis Charge du Lac au contact"},
	"lame": {"seek": 7.0, "reach": 2.2, "dmg": 16, "cd": 0.85, "guard": 0.55, "status": "Garde l’Ancre · mêlée ; moulinet d’orage toutes les 3 frappes"},
	"sigil": MELEE_ADEPT, "medeina": MELEE_ADEPT, "aether": MELEE_ADEPT, "indra": MELEE_ADEPT,
	"engineer": {"seek": 86.0, "reach": 86.0, "dmg": 80, "cd": 1.15, "ranged": true, "status": "Prêt à recevoir vos ordres"},
}
## Charge du Lac de l'archer (CHARGE), moulinet d'orage (MOULINET), sillon de flammes (SILLON), adepts.js.
const CHARGE := {"trigger": 5.0, "reset": 8.0, "speed": 16.0, "dmg": 22, "stun": 0.5, "max_t": 0.6}
const MOULINET := {"charges": 3, "r": 2.8, "dmg": 24}
const SILLON := {"cd": 4.0, "len": 8.0, "w": 0.9, "dmg": 12, "wall": 2.0, "burn": 3.0, "slow": 0.6}
## Expérience gagnée en achevant un ennemi (KILL_XP).
const KILL_XP := {"creep": 10, "spitter": 15, "brute": 35, "beast": 6}
## Ennemis (spawn, Index.html ; rejetons : updateEvilPortals, galleries.js).
const ENEMY := {
	"creep": {"hp": 35, "speed": 2.7, "range": 1.5, "damage": 6, "cd": 1.15},
	"spitter": {"hp": 48, "speed": 2.0, "range": 9.0, "damage": 5, "cd": 1.15},
	"brute": {"hp": 110, "speed": 1.4, "range": 1.5, "damage": 12, "cd": 1.7},
	"beast": {"hp": 22, "speed": 2.6, "range": 1.5, "damage": 4, "cd": 1.15},
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
	"creep": {"name": "Fanatique du Credo", "kind": "ENNEMI · CREDO SOUILLÉ", "lore": "Robe ivoire trempée d’ichor noir : il frappe au contact pour son maître caché."},
	"spitter": {"name": "Thuriféraire souillé", "kind": "ENNEMI · CREDO SOUILLÉ", "lore": "Il projette de loin une lumière souillée par la Bête."},
	"brute": {"name": "Automate de Byrsa", "kind": "ENNEMI · CREDO SOUILLÉ", "lore": "Un automate d’or fêlé ; ses coups lourds brisent les lignes."},
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
	return Catalog.FIGHT[u.role]["reach"] if Catalog.FIGHT.has(u.role) else Catalog.HERO.get(u.role, {"reach": 8.6})["reach"]


static func is_adept(u: Unit) -> bool:
	return u != null and ADEPT.has(u.role)


static func prays(u: Unit) -> bool:
	return u != null and DEITY_RES.has(u.role)
