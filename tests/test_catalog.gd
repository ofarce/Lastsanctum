extends "res://tests/test_case.gd"
## Étape 6 (v2) : le catalogue Godot (data/catalog.gd) est identique aux valeurs du prototype (73b410f),
## extraites par tools/baker/hud.js dans assets/baked/hud/hud_texts.json.

const TEXTS := "res://assets/baked/hud/hud_texts.json"


func _js() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(TEXTS))


func test_buildings_match_js() -> void:
	var js: Dictionary = _js()["buildings"]
	check_eq(Catalog.BUILDINGS.keys(), js.keys(), "ordre des bâtiments")
	for k: String in js:
		var a: Dictionary = Catalog.BUILDINGS[k]
		var b: Dictionary = js[k]
		for f in ["name", "key", "icon", "lore", "art"]:
			check_eq(a[f], b[f], "%s.%s" % [k, f])
		check_eq(a["cost"], _ints(b["cost"]), "%s.cost" % k)
		check_eq(a["deity"], b["deity"] if b["deity"] != null else "", "%s.deity" % k)
		check_eq(a["requires"], b["requires"] if b["requires"] != null else "", "%s.requires" % k)
		check_eq(a["time"], float(b["time"]), "%s.time" % k)
		check_eq(a["size"], int(b["size"]), "%s.size" % k)


func test_constants_match_js() -> void:
	var js := _js()
	check_eq(Catalog.RES_ORDER, Array(js["res_order"], TYPE_STRING, "", null), "RES_ORDER")
	check_eq(Catalog.RES_INFO, js["res_info"], "RES_INFO")
	check_eq(Catalog.DEITY_RES, js["deity_res"], "DEITY_RES")
	check_eq(Catalog.SUMMON_COST, int(js["summon_cost"]), "SUMMON_COST")
	check_eq(Catalog.CASERNE_COST, _ints(js["caserne_cost"]), "CASERNE_COST")
	check_eq(Catalog.CASERNE_TIME, float(js["caserne_time"]), "CASERNE_TIME")
	check_eq(Catalog.CASERNE_QUEUE, int(js["caserne_queue"]), "CASERNE_QUEUE")
	check_eq(Catalog.CASERNE_UNITS, js["caserne_units"], "CASERNE_UNITS")
	check_eq(Catalog.HERO_COST, _ints(js["hero_cost"]), "HERO_COST")
	check_eq(Simulation.ORB_TIME, float(js["orb_time"]), "ORB.time")
	check_eq(TerrainState.DIG_HITS, int(js["dig_hits"]), "DIG_HITS")
	check_eq(Catalog.HUD_LORE, js["lore"], "HUD_LORE")
	for d: Dictionary in js["deity_portals"]:
		check_eq(Catalog.DEITY_NAMES[d["id"]], d["name"], "nom de " + d["id"])
	for i in 8:
		check_eq(Catalog.xp_need(i + 1), int(js["xp_need"][i]), "xpNeed(%d)" % (i + 1))


func test_adepts_and_fight_match_js() -> void:
	var js := _js()
	for k: String in js["adept"]:
		var a: Dictionary = js["adept"][k]
		check_eq(Catalog.ADEPT[k], {"name": a["name"], "task": a["task"], "hp": int(a["hp"]), "lore": a["lore"]}, "ADEPT." + k)
	check_eq(Catalog.ADEPT.keys(), js["adept"].keys(), "ordre des adeptes")
	for k: String in js["fight"]:
		check_eq(Catalog.FIGHT[k]["dmg"], int(js["fight"][k]["dmg"]), "FIGHT.%s.dmg" % k)
		if k != "flammes":  # D15 : statut du lance-flammes réécrit (tir continu, explosion)
			check_eq(Catalog.FIGHT[k]["status"], js["fight"][k]["status"], "FIGHT.%s.status" % k)


static func _ints(d: Dictionary) -> Dictionary:
	var out := {}
	for k: String in d:
		out[k] = int(d[k])
	return out
