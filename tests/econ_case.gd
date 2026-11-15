extends "res://tests/test_case.gd"
## Base des tests de l'économie (étape 7) : partie partagée, graine des galeries de référence, simulation
## pas à pas. Chaque test repart d'une nouvelle partie avec l'Ingénieur déjà sorti du portail.

const DT := 1.0 / 60.0
const SEED := 20261114

static var _main: Node


func game() -> Simulation:
	if _main == null:
		_main = load("res://main/main.tscn").instantiate()
		(Engine.get_main_loop() as SceneTree).root.add_child(_main)
	var sim: Simulation = _main.get_node("Simulation")
	sim.paused = true
	sim.new_game(SEED)
	var u: Unit = GameState.units[0]
	u.hidden = false
	GameState.portal_start = -100.0
	u.x = -13.0
	u.z = -130.0
	u.tx = u.x
	u.tz = u.z
	return sim


func engineer() -> Unit:
	return GameState.units[0]


func run(sim: Simulation, seconds: float) -> void:
	for i in roundi(seconds / DT):
		sim.tick(DT)


func give(amount: float) -> void:
	for k in Catalog.RES_ORDER:
		GameState.res[k] = amount


## Bâtiment achevé posé directement (sans chantier).
func built(type: String, x: float, z: float) -> Building:
	var b := Building.create(GameState.buildings.size(), type, x, z)
	b.complete = true
	b.progress = Catalog.BUILDINGS[type]["time"]
	b.finished_at = -10.0
	GameState.buildings.append(b)
	return b
