extends "res://tests/fight_case.gd"
## Étape 8 (v2) : expérience (paliers 20, 32, 51…, +1 dégât et +1 défense par niveau, plancher de 15 % des
## dégâts subis), identique au prototype.


func test_xp_run_matches_js() -> void:
	var u := setup("sigil", 1)
	var gains := [10, 15, 35, 6, 10, 35, 35, 35, 15, 10]
	var want: Array = js()["xp_run"]
	for i in gains.size():
		game_sim().combat.gain_xp(u, gains[i])
		check_eq([u.level, int(u.xp)], [int(want[i][0]), int(want[i][1])], "gain %d" % (i + 1))


func test_kill_gives_xp_and_bonus() -> void:
	var u := setup("engineer", 1)
	var e := foe("brute", 1.0, -120.0, 50.0)
	game_sim().combat.barracks_strike(u, e)
	check_eq(e.hp, 0.0, "la brute est achevée (80 dégâts)")
	# L'Ingénieur ne gagne plus de niveaux (2026-11-22) : il progresse par ses mods.
	check_eq(u.level, 1, "Ingénieur : pas de niveau gagné")
	check_eq(int(u.xp), 0, "Ingénieur : pas d'XP")
	# Un adepte qui achève une brute gagne ses 35 XP : niveau 2, reste 15.
	var a := setup("sigil", 1)
	var e2 := foe("brute", 1.0, -120.0, 50.0)
	e2.hp = 1.0
	game_sim().combat.barracks_strike(a, e2)
	check_eq(a.level, 2, "35 XP : niveau 2")
	check_eq(int(a.xp), 15, "reste 15 XP")
	check_eq(Catalog.lvl_bonus(a), 0.5, "+0,5 dégât (et +1 défense)")
	check_near(Combat.after_armor(a, 0.5), 0.5 * 0.15, 1e-9, "plancher de 15 %")
