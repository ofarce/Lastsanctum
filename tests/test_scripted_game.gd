extends "res://tests/fight_case.gd"
## Étape 8 (v2) : partie scriptée accélérée de plusieurs assauts, sans erreur, avec un journal d'événements
## identique sur 2 exécutions (graine fixée). Pas de simulation de 0,045 s (le plus long admis par le jeu).
## Les règles ont changé depuis le prototype (plus de balistes, un assaut par jour, Ancre à 1 PV, Ingénieur
## qui n'attaque que sur ordre) : la défense est ici une garde de héros endurcis, l'Ancre est renforcée et
## l'attente entre deux assauts est sautée, pour ne garder que le déroulé des combats.

const STEP := Simulation.MAX_DT
const STEPS := 6000
const WAVES := 2


func _play() -> PackedStringArray:
	var sim := game()
	sim.combat.log_events = true
	sim.combat.events.clear()
	var u := engineer()
	u.x = -5.0
	u.z = -150.0
	u.tx = u.x
	u.tz = u.z
	sim.order_orb(u)
	GameState.core_hp = 1e6
	var guards: Array[Unit] = []
	for spot: Array in [["paladin", -3.0], ["paladin", 3.0], ["shooter", -6.0], ["shooter", 0.0], ["shooter", 6.0]]:
		var a := sim.spawn("Garde", spot[1], -100.0, spot[0])
		a.hp = 1e5
		a.max_hp = a.hp
		guards.append(a)
	for i in STEPS:
		sim.tick(STEP)
		_sortie(guards)
		# Assaut repoussé : on saute la nuit jusqu'à la veille du suivant.
		if GameState.next_wave > GameState.sim_time + 1.0 and GameState.orb_active:
			GameState.sim_time = GameState.next_wave - 0.5
		if GameState.wave > WAVES or GameState.ended:
			break
	var log := sim.combat.events.duplicate()
	sim.combat.log_events = false
	return log


## Les tireurs ennemis portent plus loin que la garde ne voit (Thuriféraire : 40, Tireur : détection 20) : un
## assaillant qui s'arrête hors de vue tiendrait l'assaut ouvert sans fin. La garde marche donc sur l'assaillant le
## plus proche tant qu'il est hors de sa détection, puis tient sa place (comme un joueur qui fait une sortie).
func _sortie(guards: Array[Unit]) -> void:
	for g in guards:
		if not g.alive():
			continue
		var best: Enemy = null
		var bd := INF
		for e: Enemy in GameState.enemies:
			if e.hp <= 0.0 or e.beast or e.neutral:
				continue
			var d := Combat.hyp(e.x - g.x, e.z - g.z)
			if d < bd:
				bd = d
				best = e
		if best != null and bd > float(Catalog.HERO[g.role]["seek"]) * 0.8:
			g.tx = best.x
			g.tz = best.z
		else:
			g.tx = g.x
			g.tz = g.z


func test_scripted_waves_deterministic() -> void:
	var a := _play()
	var waves := Array(a).filter(func(l: String) -> bool: return l.contains("vague"))
	check(waves.size() >= WAVES, "au moins %d vagues (%d) ; fin : %s" % [WAVES, waves.size(), GameState.ended])
	var kills := Array(a).filter(func(l: String) -> bool: return l.contains("abattu")).size()
	var expected := 0
	for w in range(1, WAVES + 1):
		expected += int(Catalog.MENACE_WAVE["base"]) + w * int(Catalog.MENACE_WAVE["per_wave"])
	check(kills >= expected, "les %d vagues abattues (%d ennemis sur %d)" % [WAVES, kills, expected])
	check(not GameState.ended, "le sanctuaire tient")
	var b := _play()
	check_eq(b, a, "2e exécution identique")
	print("     (partie scriptée : %d événements, %s)" % [a.size(), a[a.size() - 1] if a.size() else "—"])
