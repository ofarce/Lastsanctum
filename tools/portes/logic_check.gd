extends Node
## Contrôle des portes qui gardent (sim/cave_doors.gd) : un soldat lâché dans le tunnel nord bute contre la porte,
## la frappe, l'enfonce, puis entre ; la porte se relève à l'aube. Un allié l'ouvre en approchant.
##   godot --headless --path . res://tools/portes/logic_check.tscn
const MAIN = preload("res://main/main.tscn")
var _fails := 0


func _check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "ÉCHEC ") + what)
	if not ok:
		_fails += 1


func _ready() -> void:
	var main = MAIN.instantiate()
	add_child(main)
	var sim: Simulation = main.get_node("Simulation")
	sim.new_game(20261114)
	GameState.opening_stage = ""
	GameState.in_capsule = false
	GameState.portal_start = -100
	GameState.orb_active = true
	GameState.orb_finished_at = -20
	GameState.sim_time = 30.0
	for i in 6:
		sim.tick(1.0 / 60.0)
	var st := sim.state()
	_check(CaveDoors.active(st), "portes actives sur le Temple en salles")
	for m: Dictionary in CaveDoors.MOUTHS:
		var mid: Vector2 = ((m["a"] as Vector2) + (m["b"] as Vector2)) * 0.5
		var o: Vector2 = m["out"]
		_check(st.is_gallery(mid.x + o.x * 2.0, mid.y + o.y * 2.0) and st.ground(mid.x - o.x * 2.0, mid.y - o.y * 2.0), "bouche %s : tunnel dehors, sol dedans" % m["id"])
	# Les alliés loin : porte fermée.
	for u: Unit in GameState.units:
		u.x = 0.0
		u.z = -140.0
		u.tx = u.x
		u.tz = u.z
	var e := Enemy.make("soldier", -22.0, -200.0, 0.0)
	GameState.enemies.append(e)
	var crossed := false
	var hp0 := float(GameState.cave_doors[0]["hp"])
	for i in 60 * 40:
		sim.tick(1.0 / 60.0)
		if not GameState.cave_doors[0]["broken"] and e.z > -184.0 + 0.01:
			crossed = true
		if GameState.cave_doors[0]["broken"]:
			break
	_check(not crossed, "le soldat ne franchit pas la porte fermée")
	_check(float(GameState.cave_doors[0]["hp"]) < hp0, "il la frappe (%.0f → %.0f PV)" % [hp0, float(GameState.cave_doors[0]["hp"])])
	_check(GameState.cave_doors[0]["broken"], "elle finit enfoncée")
	for i in 60 * 6:
		sim.tick(1.0 / 60.0)
	_check(e.hp <= 0.0 or e.z > -180.0, "porte enfoncée : il entre (z = %.1f)" % e.z)
	GameState.enemies.erase(e)
	# Aube : relevée.
	CaveDoors._rise(sim)
	_check(not GameState.cave_doors[0]["broken"] and float(GameState.cave_doors[0]["hp"]) == float(GameState.cave_doors[0]["max_hp"]), "relevée à l'aube, PV pleins")
	# Archer dans le tunnel, allié dans la grotte hors de portée d'ouverture : aucune flèche ne passe la porte.
	var eng := Capsule.engineer()
	eng.hidden = false
	eng.x = -22.0
	eng.z = -175.0
	eng.tx = eng.x
	eng.tz = eng.z
	eng.stance = "hold"
	var hp_eng := eng.hp
	var hp_door := float(GameState.cave_doors[0]["hp"])
	var ar := Enemy.make("archer", -22.0, -196.0, 0.0)
	GameState.enemies.append(ar)
	for i in 60 * 8:
		eng.x = -22.0
		eng.z = -175.0
		sim.tick(1.0 / 60.0)
	_check(float(GameState.cave_doors[0]["open"]) < 0.05, "porte restée fermée pendant le duel")
	_check(eng.hp >= hp_eng - 0.01, "l'archer ne touche pas l'allié à travers la porte (%.0f → %.0f PV)" % [hp_eng, eng.hp])
	_check(float(GameState.cave_doors[0]["hp"]) < hp_door, "l'archer s'approche et frappe la porte (%.0f → %.0f PV)" % [hp_door, float(GameState.cave_doors[0]["hp"])])
	_check(Simulation.Placeables != null and not sim.combat.clear_shot(Vector2(-22, -196), Vector2(-22, -175)), "clear_shot coupé par la porte fermée")
	GameState.enemies.erase(ar)
	eng.x = -22.0
	eng.z = -181.0
	eng.tx = eng.x
	eng.tz = eng.z
	for i in 60:
		sim.tick(1.0 / 60.0)
	_check(float(GameState.cave_doors[0]["open"]) > 0.95, "un allié tout près l'ouvre (%.2f)" % float(GameState.cave_doors[0]["open"]))
	print("ruines : %d" % CaveDoors.ruins(st).size())
	for r: Dictionary in CaveDoors.ruins(st):
		print("  ", r["quarter"], " ", r["mid"], " vers ", r["into"])
	print("ÉCHECS : %d" % _fails)
	get_tree().quit()
