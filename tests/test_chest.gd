extends "res://tests/econ_case.gd"
## Coffre antique (planches/intro-capsule-planche.html) : à côté de la capsule, visible dès le départ, éteint tant que
## l'Ancre l'est. Ouvert par l'Ingénieur, il remet l'équipement de départ et le plan « Analyse », et la réserve de la
## base (100 cases) se débloque.

const ItemStorage := preload("res://sim/item_storage.gd")


func _open(sim: Simulation) -> void:
	var t := 0.0
	while not GameState.base_inventory_unlocked and t < 60.0:
		run(sim, 0.5)
		t += 0.5


func test_chest_off_until_anchor_wakes() -> void:
	var sim := game()
	check(not Capsule.chest_active(), "Ancre éteinte : coffre éteint")
	check(sim.order_chest(engineer()), "clic consommé")
	check(engineer().job == null, "coffre éteint : l'Ingénieur n'y va pas")
	engineer().x = CaveShape.CHEST_SPOT.x
	engineer().z = CaveShape.CHEST_SPOT.y
	ExileGallery.incarnate(engineer())
	check(not Capsule.can_open_chest(), "pas d'invite sur le coffre éteint")
	sim.open_chest(engineer())
	check(not GameState.base_inventory_unlocked, "un coffre éteint ne s'ouvre pas")
	GameState.orb_active = true
	check(Capsule.can_open_chest(), "Ancre allumée : invite « E : Ouvrir le Coffre Antique »")
	ExileGallery.disincarnate()


func test_engineer_opens_chest_and_gets_starting_gear() -> void:
	var sim := game()
	GameState.orb_active = true
	check(not sim.buildable_ground(CaveShape.CHEST.x, CaveShape.CHEST.y), "coffre non constructible")
	check(not sim.state().walkable(CaveShape.CHEST.x, CaveShape.CHEST.y - 1.0), "socle infranchissable")
	check(sim.state().walkable(CaveShape.CHEST_SPOT.x, CaveShape.CHEST_SPOT.y), "place de l'Ingénieur praticable")
	var got: Array = []
	var cb := func(items: Array) -> void: got.append_array(items)
	Events.items_received.connect(cb)
	check(sim.order_chest(engineer()), "ordre donné")
	check_eq(engineer().job.get("type"), "chest", "tâche coffre")
	_open(sim)
	Events.items_received.disconnect(cb)
	check(GameState.base_inventory_unlocked, "réserve de base débloquée")
	check(not is_inf(GameState.chest_opened_at), "instant d'ouverture noté")
	check(engineer().job == null, "tâche terminée")
	check(engineer().pos().distance_to(CaveShape.CHEST_SPOT) < 0.8, "Ingénieur devant le coffre")
	check_eq(got, Simulation.CHEST_GIFT, "bannière : Arbalestrie, Combinaison, Sceau, plan")
	check_eq(engineer().equipment.get("Main droite", ""), "cannon", "Arbalestrie portée")
	check_eq(engineer().equipment.get("Torse", ""), "combinaison", "Combinaison portée")
	check(GameState.mining_seal and GameState.capsule_gift, "Sceau de minage remis")
	check(GameState.plans.has("analyse"), "plan « Analyse » appris")
	check_eq(Production.count_in(engineer().inventory, "plan_analyse"), 1, "plan « Analyse » dans le paquetage")
	check(GameState.enemies.is_empty(), "plus d'éclaireurs d'essai à l'ouverture du Coffre")
	ItemStorage.deposit("rock", engineer(), engineer().pos())
	check_eq(GameState.base_inventory, [{"item": "rock", "quantity": 1}], "objets vers la réserve")
	var asked := [0]
	var ask := func() -> void: asked[0] += 1
	Events.inventory_requested.connect(ask)
	check(sim.order_chest(engineer()) and asked[0] == 1, "coffre ouvert : inventaire demandé")
	Events.inventory_requested.disconnect(ask)
	sim.new_game(SEED)
	check(is_inf(GameState.chest_opened_at) and not GameState.base_inventory_unlocked and GameState.plans.is_empty() \
		and not GameState.capsule_gift, "nouvelle partie : tout est refermé")


func test_chest_view_frames() -> void:
	var sim := game()
	var v: ChestView = sim.world.chest_view
	check(v != null, "vue du coffre créée")
	v._process(0.0)
	check(v.visible, "visible dès le départ")
	check_eq(v._off_row, 3, "rangée « éteint » de la planche de sprites")
	check_eq(v.frame_at(3.0).y, 0, "fermé")
	GameState.chest_opened_at = 10.0
	check_eq(v.frame_at(9.9).y, 0, "fermé avant l'ouverture")
	check_eq(v.frame_at(10.6).y, 1, "ouverture")
	check_eq(v.frame_at(12.0).y, 2, "ouvert")
	check_eq(v.frame_at(10.0).x, 0, "première image de l'ouverture")
