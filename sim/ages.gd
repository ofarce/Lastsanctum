class_name Ages
extends RefCounted
## Âges des métaux (demande du 2026-11-22) : le travail d'un métal — bâtiments, recettes, recherches — reste masqué
## tant que son âge n'est pas ouvert. Un âge s'ouvre quand deux conditions sont réunies :
##   1. un bloc de son minerai a été extrait (GameState.collected_items, rempli par Simulation._collect_mined_item) ;
##   2. le boss qui garde ce savoir est vaincu (cuivre : la Martyre de Byrsa ; fer : Gorge-Cuivre).
## Un âge ouvert le reste (GameState.ages_open), même si l'état qui l'a ouvert change ensuite.
## L'âge de l'or n'a pas encore de boss (biome 3 en réserve) : il ne s'ouvre pas.

const AGES := {
	"copper": {"name": "Âge du cuivre", "ore": "copper", "metal": "cuivre", "boss_name": "la Martyre de Byrsa",
		"quest": "Le secret du cuivre", "mine_label": "Miner du cuivre", "boss_label": "Vaincre la Martyre de Byrsa",
		"quote": "Ce minerai résiste à nos fourneaux. La Martyre de Byrsa garde le savoir du cuivre : il faudra la vaincre.",
		"seek_quote": "Les veines vertes du Temple cachent du cuivre. Il faut d’abord en extraire.",
		"done_quote": "Le cuivre coule enfin. La Fonderie peut s’allumer."},
	"iron": {"name": "Âge du fer", "ore": "iron", "metal": "fer", "boss_name": "Gorge-Cuivre",
		"quest": "Le secret du fer", "mine_label": "Miner du fer", "boss_label": "Vaincre Gorge-Cuivre",
		"quote": "Le fer ne se laisse pas fondre. Gorge-Cuivre en a dévoré le secret : il faudra le lui reprendre.",
		"seek_quote": "Le fer affleure au nord des veines de vert-de-gris. Il faut d’abord en extraire.",
		"done_quote": "Le fer plie sous nos marteaux. L’Armurerie a de quoi forger."},
	"gold": {"name": "Âge de l’or", "ore": "gold", "metal": "or", "boss_name": "",
		"quest": "Le secret de l’or", "mine_label": "Miner de l’or", "boss_label": "",
		"quote": "", "seek_quote": "", "done_quote": ""},
}
const ORDER: Array[String] = ["copper", "iron", "gold"]

## Bâtiments, recettes et recherches attachés à un âge ; tout le reste est libre.
const BUILDING_AGE := {"forge": "copper", "creuset": "copper"}
const RECIPE_AGE := {
	"copper_ingot": "copper", "sword": "copper", "shield": "copper", "copper_armor": "copper",
	"copper_greatsword": "copper", "copper_sword": "copper", "copper_shield": "copper",
	"iron_ingot": "iron", "iron_armor": "iron", "iron_greatsword": "iron", "iron_sword": "iron", "iron_shield": "iron",
	"pickaxe": "iron", "chest": "iron", "fishing_rod": "iron",
	"gold_ingot": "gold",
}
const RESEARCH_AGE := {"copper_tips": "copper", "verdigris_balm": "copper", "copper_seal": "copper", "limbo_mastery": "copper",
	"iron_seal": "iron"}


static func is_open(age: String) -> bool:
	return age == "" or GameState.ages_open.has(age)


static func building_open(type: String) -> bool:
	return is_open(BUILDING_AGE.get(type, ""))


static func recipe_open(item: String) -> bool:
	return is_open(RECIPE_AGE.get(item, ""))


## Une recherche reste aussi masquée tant que son bâtiment l'est (sceaux de la Fonderie ajoutés avec les biomes 3 à 8).
static func research_open(id: String) -> bool:
	if not is_open(RESEARCH_AGE.get(id, "")):
		return false
	return building_open(String(Catalog.RESEARCH.get(id, {}).get("building", "")))


static func ore_found(age: String) -> bool:
	return GameState.collected_items.has(AGES[age]["ore"])


static func boss_beaten(age: String) -> bool:
	match age:
		"copper":
			return GameState.martyre_state == "defeated"
		"iron":
			return String(GameState.gorge.get("mode", "")) == "dead"
	return false


## Âge en cours de conquête : le premier fermé dont le précédent est ouvert et qui a un boss ; "" sinon.
static func pending() -> String:
	for age: String in ORDER:
		if not is_open(age):
			return age if String(AGES[age]["boss_name"]) != "" else ""
	return ""


## Ouvre les âges dont les deux conditions sont réunies, dans l'ordre (le fer attend le cuivre).
static func tick(sim: Simulation) -> void:
	for age: String in ORDER:
		if is_open(age):
			continue
		if ore_found(age) and boss_beaten(age):
			GameState.ages_open[age] = true
			sim.say("%s · %s" % [String(AGES[age]["name"]).to_upper(), unlock_text(age)], 6.0)
			Sfx.play("quete")
		return


## Premier bloc d'un minerai dont l'âge est fermé : l'Ingénieur dit ce qui manque.
static func on_first_ore(sim: Simulation, item: String) -> void:
	for age: String in ORDER:
		if AGES[age]["ore"] == item and not is_open(age) and String(AGES[age]["quote"]) != "":
			if not boss_beaten(age):
				sim.say(String(AGES[age]["quote"]), 5.0)
			return


## « Nouveau : Fonderie, Armurerie · 4 recherches · 7 recettes. »
static func unlock_text(age: String) -> String:
	var names: PackedStringArray = []
	for type: String in BUILDING_AGE:
		if BUILDING_AGE[type] == age:
			names.append(Catalog.BUILDINGS[type]["name"])
	var n_research := RESEARCH_AGE.values().count(age)
	var n_recipes := RECIPE_AGE.values().count(age)
	var parts: PackedStringArray = []
	if not names.is_empty():
		parts.append(", ".join(names))
	if n_research > 0:
		parts.append("%d recherche%s" % [n_research, "s" if n_research > 1 else ""])
	if n_recipes > 0:
		parts.append("%d recette%s" % [n_recipes, "s" if n_recipes > 1 else ""])
	return "Les Exilés savent travailler le %s. Nouveau : %s." % [AGES[age]["metal"], " · ".join(parts)]


## Objectif du panneau de quête pour l'âge en cours ({} : aucun).
static func objective() -> Dictionary:
	var age := pending()
	if age == "":
		return {}
	var A: Dictionary = AGES[age]
	var ore := ore_found(age)
	var boss := boss_beaten(age)
	var done := int(ore) + int(boss)
	return {"id": "age_" + age, "quest": A["quest"],
		"items": [{"label": A["mine_label"], "done": ore}, {"label": A["boss_label"], "done": boss}],
		"step": "%d / 2" % done,
		"quote": A["quote"] if ore else A["seek_quote"], "done_quote": A["done_quote"]}
