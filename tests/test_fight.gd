extends "res://tests/fight_case.gd"
## Étape 8 (v2) : table FIGHT et frappes (barracksStrike, moulinet, sillon, Charge du Lac) identiques au
## prototype (73b410f). Référence : assets/baked/hud/combat.json (tools/baker/hud.js).


## Écart voulu D13 : portées relevées après 73b410f (lance-flammes ×2, archer ×4), le reste reste identique.
const D13 := {"flammes": {"seek": 18.0, "reach": 9.0}, "archer": {"seek": 68.0, "reach": 56.0}}


func test_fight_table_matches_js() -> void:
	var F: Dictionary = js()["fight"]
	for role: String in F:
		var want: Dictionary = F[role].duplicate()
		want.merge(D13.get(role, {}), true)
		var got: Dictionary = Catalog.FIGHT[role]
		for k: String in want:
			if want[k] is Dictionary:
				for kk: String in want[k]:
					check_near(float(got[k][kk]), float(want[k][kk]), 1e-9, "FIGHT.%s.%s.%s" % [role, k, kk])
			elif want[k] is String or want[k] is bool:
				check_eq(got[k], want[k], "FIGHT.%s.%s" % [role, k])
			else:
				check_near(float(got[k]), float(want[k]), 1e-9, "FIGHT.%s.%s" % [role, k])
	for pair: Array in [["charge", Catalog.CHARGE, {"maxT": "max_t"}], ["moulinet", Catalog.MOULINET, {}], ["sillon", Catalog.SILLON, {}], ["kill_xp", Catalog.KILL_XP, {}],
			["turret", Catalog.TURRET, {"repairTime": "repair_time", "boltSpeed": "bolt_speed"}], ["evil", Catalog.EVIL, {}]]:
		var want: Dictionary = js()[pair[0]]
		for k: String in want:
			var gk: String = pair[2].get(k, k)
			check_near(float(pair[1][gk]), float(want[k]), 1e-9, "%s.%s" % [pair[0], k])
	check_eq(Combat.VOLLEY, js()["volley"].map(func(v: float) -> float: return v), "VOLLEY")


func test_after_armor_matches_js() -> void:
	for row: Array in js()["after_armor"]:
		var u := Unit.new()
		u.level = int(row[0])
		check_near(Combat.after_armor(u, row[1]), row[2], 1e-9, "afterArmor(niveau %d, %s)" % [row[0], row[1]])


func test_strikes_match_js() -> void:
	for sc: Dictionary in js()["strikes"]:
		var u := setup(sc["role"], int(sc["level"]))
		foe("brute", 1.0, -120.0, 400.0)
		foe("creep", 2.0, -121.0, 400.0)
		foe("creep", 1.5, -119.0, 400.0)
		foe("spitter", 6.0, -120.0, 400.0)
		var i := 0
		for want: Dictionary in sc["strikes"]:
			game_sim().combat.barracks_strike(u, GameState.enemies[0])
			_same(snap(u), want, "%s niv. %d, frappe %d" % [sc["role"], sc["level"], i + 1])
			GameState.sim_time += 1.0
			i += 1


func test_archer_charge_matches_js() -> void:
	var u := setup("archer", 1)
	var e := foe("creep", 4.0, -120.0, 200.0)
	var i := 0
	for want: Dictionary in js()["charge_run"]:
		u.attack -= 0.05
		game_sim().combat.archer_tick(u, e, 0.05)
		GameState.sim_time += 0.05
		_same(snap(u), want, "charge, pas %d" % i)
		i += 1
