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


## Objets de caserne (arcs, flèches, épées, boucliers) pour `squads` escouades de chaque type, au coffre.
func stock_caserne_items(squads: int) -> void:
	var Storage := preload("res://sim/item_storage.gd")
	GameState.base_inventory_unlocked = true
	for role: String in ["archer", "lame"]:
		var cost: Dictionary = preload("res://data/recipes.gd").caserne_cost(role, 4 * squads)
		for k: String in cost:
			for i in int(cost[k]):
				Storage.store(GameState.base_inventory, Storage.BASE_CAPACITY, k)


## Caserne prête (règle du 2026-11-17) : un adepte d'Indra au poste et les objets de `squads` escouades d'archers et
## d'Épée et bouclier déjà au coffre bleu.
func ready_caserne(sim: Simulation, b: Building, squads: int) -> void:
	staff(sim, b, 1)
	for role: String in ["archer", "lame"]:
		var cost: Dictionary = preload("res://data/recipes.gd").caserne_cost(role, 4 * squads)
		for k: String in cost:
			Production.put_into(b.input_box, k, int(cost[k]))


## Bâtiment achevé posé directement (sans chantier).
func built(type: String, x: float, z: float) -> Building:
	var b := Building.create(GameState.buildings.size(), type, x, z)
	b.complete = true
	b.progress = Catalog.BUILDINGS[type]["time"]
	b.finished_at = -10.0
	GameState.buildings.append(b)
	return b


## Bâtiment servi (sim/production.gd) : `n` adeptes de son culte déjà à leur poste.
func staff(sim: Simulation, b: Building, n := 1) -> Array[Unit]:
	var out: Array[Unit] = []
	for i in n:
		var u := sim.spawn("Adepte", b.x, b.z, Production.staff_role(b))
		u.job = {"type": "staff", "building": b, "post": "worker", "step": "post"}
		out.append(u)
	for u: Unit in out:
		var p := Production.post_spot(b, Production.members(b, "worker").find(u))
		u.x = p.x
		u.z = p.y
		u.tx = p.x
		u.tz = p.y
		u.working = true
	return out
