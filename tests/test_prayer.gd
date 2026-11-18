extends "res://tests/econ_case.gd"
## Étape 7 (v2) : invocation d'adepte au temple (10 de la ressource du dieu, portail divin actif 3,5 s) et prière
## (+1 par seconde et par adepte, popup « +5 » toutes les 5 s), comme dans buildings.js et adepts.js (73b410f).


func test_summon_adept() -> void:
	var sim := game()
	var t := built("sigil", -26.0, -118.0)
	GameState.res["savoir"] = 10.0
	sim.summon_adept(t)
	check_near(GameState.res["savoir"], 0.0, 1e-9, "10 Savoir payés")
	var a: Unit = GameState.units[-1]
	check_eq(a.role, "sigil", "esprit de Sigil")
	check_eq(a.max_hp, 90.0, "PV d'un esprit de Sigil")
	check_eq(Vector2(a.x, a.z), Simulation.arrival_spot(t), "naît au pied de l'autel")
	check(a.hidden and a.job == null, "caché pendant l'arrivée")
	sim.tick(DT)
	check(not GameState.deity_active.get("sigil", false), "le portail divin ne s'ouvre plus")
	run(sim, Simulation.ARRIVAL - 0.5)
	check(a.hidden, "encore en arrivée avant 10 s")
	run(sim, 0.6)
	check(not a.hidden and a.arrival_end == 0.0, "arrivée finie après 10 s")
	check(a.job != null and a.job["type"] == "pray" and a.job["temple"] == t, "part prier")
	sim.summon_adept(t)
	check_eq(GameState.units.size(), 2, "Solde insuffisant : invocation refusée")


func test_prayer_income_and_popups() -> void:
	var sim := game()
	var t := built("sigil", -26.0, -118.0)
	var adepts: Array[Unit] = []
	for i in 3:
		var a := sim.spawn("Adepte de Sigil", -26.0, -105.0, "sigil")
		sim.send_to_pray(a, t)
		adepts.append(a)
	run(sim, 4.0)
	for a in adepts:
		check(a.working, "en prière : %s" % a.pos())
	var s0: float = GameState.res["savoir"]
	run(sim, 2.0)
	check_near(GameState.res["savoir"] - s0, 6.0, 0.06, "3 adeptes : +3 Savoir par seconde")
	check(not GameState.pray_popups.is_empty(), "popup « +5 » (cumul de prière du temple ≥ 5 s)")
	check_eq(GameState.pray_popups[0]["res"], "savoir", "ressource du popup")
	# prayerSpot : rangées de 5, à 2 unités d'écart, devant le temple.
	check_eq(sim.prayer_spot(adepts[1], t), Vector2(-26.0 - 4.0 + 2.0, -118.0 + t.half() + 1.0), "place du 2e adepte")


func test_prayer_only_at_own_temple() -> void:
	var sim := game()
	built("sigil", -26.0, -118.0)
	var a := sim.spawn("Adepte de Medeina", -20.0, -110.0, "medeina")
	check(not sim.send_to_pray(a), "aucun temple de Medeina")
	GameState.selected = [a]
	sim.pray_selected()
	check(a.job == null, "pas de prière")


func test_prayer_stops_when_temple_removed() -> void:
	var sim := game()
	var t := built("sigil", -26.0, -118.0)
	var a := sim.spawn("Adepte de Sigil", -26.0, -105.0, "sigil")
	sim.send_to_pray(a, t)
	GameState.buildings.erase(t)
	sim.tick(DT)
	check(a.job == null, "temple disparu : tâche annulée")


## Clic droit sur un temple, Ingénieur sélectionné : méditation en lévitation, +5 par seconde entière après l'assise.
func test_engineer_meditates_at_temple() -> void:
	var sim := game()
	var t := built("medeina", -26.0, -118.0)
	var e := engineer()
	GameState.selected = [e]
	check(sim.order_pray(t), "ordre de prière accepté")
	check(e.job != null and e.job["type"] == "pray" and e.job["temple"] == t, "part méditer au temple")
	var spot := sim.prayer_spot(e, t)
	e.x = spot.x
	e.z = spot.y
	sim.tick(DT)
	check(e.working and e.job.has("since"), "médite dès l'arrivée")
	check_eq(Simulation.resource_rates()["vie"], 5, "+5 Vie par seconde")
	var v0: float = GameState.res["vie"]
	run(sim, Simulation.MEDITATE_SETTLE - 0.1)
	check_near(GameState.res["vie"], v0 + (Simulation.MEDITATE_SETTLE - 0.1) * (1.0 if GameState.orb_active else 0.0), 0.2, "rien pendant l'assise")
	var v1: float = GameState.res["vie"]
	run(sim, 3.2)
	check_eq(e.job["ticks"], 3, "trois gains en 3 s")
	check_near(GameState.res["vie"] - v1, 15.0 + 3.2 * (1.0 if GameState.orb_active else 0.0), 0.2, "+15 Vie en trois gains")
	check(GameState.pray_popups.size() >= 1, "popup « +5 » au dernier gain")
	check_eq(GameState.pray_popups[-1]["amount"], 5, "popup de 5")
	check_eq(GameState.pray_popups[-1]["res"], "vie", "ressource du dieu du temple")


func test_engineer_right_click_ignores_unfinished_temple() -> void:
	var sim := game()
	var t := built("sigil", -26.0, -118.0)
	t.complete = false
	GameState.selected = [engineer()]
	check(not sim.order_pray(t), "temple en chantier : pas de prière")
	var lib := built("library", 10.0, -118.0)
	check(not sim.order_pray(lib), "bâtiment sans dieu : pas de prière")
