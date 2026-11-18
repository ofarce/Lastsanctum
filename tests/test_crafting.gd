extends "res://tests/econ_case.gd"
## Fabrication : recettes de l'Atelier, de la Forge et du Creuset des Exilés (data/recipes.gd), objets demandés
## par la caserne, équipement du Creuset porté par l'Ingénieur sans armure.

const Recipes := preload("res://data/recipes.gd")
const Storage := preload("res://sim/item_storage.gd")
const Gear := preload("res://data/gear_items.gd")


func _stock(items: Dictionary) -> void:
	# Coffre antique débloqué : la réserve est ouverte, les adeptes peuvent y aller chercher les objets.
	var sim: Simulation = _main.get_node("Simulation")
	if not sim.state().vault_open:
		sim.world.dig_cell(14, -37)
		sim.world.dig_cell(15, -37)
	GameState.base_inventory_unlocked = true
	for k: String in items:
		for i in int(items[k]):
			Storage.store(GameState.base_inventory, Storage.BASE_CAPACITY, k)


func test_recipes_match_spec() -> void:
	check_eq(Recipes.RECIPES["workshop"].size(), 10, "10 recettes à l'Atelier")
	check_eq(Recipes.RECIPES["forge"].size(), 5, "5 recettes à la Forge")
	check_eq(Recipes.RECIPES["creuset"].size(), 9, "9 recettes au Creuset")
	check_eq(Recipes.RECIPES["workshop"]["barricade"], {"wood": 10, "rock": 10}, "barricade")
	check_eq(Recipes.RECIPES["workshop"]["fishing_rod"], {"wood": 2, "iron": 1, "wood_fiber": 1}, "canne à pêche")
	check_eq(Recipes.RECIPES["creuset"]["iron_armor"], {"iron": 200}, "armure en fer")
	check(Catalog.BUILDINGS.has("creuset"), "Creuset des Exilés constructible")
	check_eq(Catalog.BUILDINGS["creuset"]["requires"], "forge", "débloqué par la Forge")
	# Chaque objet produit ou demandé a un nom lisible.
	for station: String in Recipes.RECIPES:
		for item: String in Recipes.RECIPES[station]:
			check(Recipes.name_of(item) != item, "nom de %s" % item)
			for k: String in Recipes.RECIPES[station][item]:
				check(Recipes.name_of(k) != k, "nom de l'ingrédient %s" % k)
	for item: String in Recipes.RECIPES["creuset"]:
		check(Gear.is_gear(item), "%s s'équipe" % item)


## Règle du 2026-11-17 (sim/production.gd) : la recette choisie tourne en boucle, ingrédients apportés au coffre
## bleu par les adeptes au poste, produit déposé au coffre rouge.
func test_recipe_loop_fetches_from_vault() -> void:
	var sim := game()
	var b := built("workshop", -14.0, -118.0)
	_stock({"wood": 3})
	staff(sim, b, 1)
	sim.craft(b, "arrows")
	check_eq(b.recipe, "arrows", "recette choisie")
	check_eq(Storage.count("wood"), 3, "rien n'est pris au choix de la recette")
	run(sim, 120.0)
	check_eq(Production.count_in(b.output_box, "arrows"), 3, "trois flèches au coffre rouge")
	check_eq(Storage.count("wood"), 0, "bois apporté depuis le coffre antique")
	check_eq(Storage.count("arrows"), 0, "le produit reste au coffre rouge")
	sim.craft(b, "arrows")
	check_eq(b.recipe, "", "second clic : arrêt")


func test_idle_without_staff_and_speed() -> void:
	var sim := game()
	var b := built("forge", 26.0, -112.0)
	b.recipe = "copper_ingot"
	Production.put_into(b.input_box, "copper", 20)
	run(sim, Recipes.craft_time(b.type) * 2.0)
	check_eq(Production.count_in(b.output_box, "copper_ingot"), 0, "sans adepte : à l'arrêt")
	check(Production.idle(b), "bâtiment signalé à l'arrêt")
	staff(sim, b, 1)
	run(sim, Recipes.craft_time(b.type) + 0.1)
	check_eq(Production.count_in(b.output_box, "copper_ingot"), 1, "un adepte : un lingot en 9 s")
	staff(sim, b, 2)
	run(sim, Recipes.craft_time(b.type) + 0.1)
	check_eq(Production.count_in(b.output_box, "copper_ingot"), 4, "trois adeptes : trois fois plus vite")
	check(not Simulation.can_craft(b, "torch"), "la Forge ne fait pas de torche")


func test_engineer_pack_is_a_source() -> void:
	var sim := game()
	var b := built("workshop", 26.0, -112.0)
	GameState.base_inventory_unlocked = false
	var u := engineer()
	u.unarmored = true
	Storage.store(u.inventory, u.inventory_capacity, "wood")
	staff(sim, b, 1)
	sim.craft(b, "torch")
	run(sim, 40.0)
	check_eq(Storage.count("wood"), 0, "l'adepte a pris le bois dans le sac de l'Ingénieur")
	check_eq(Production.count_in(b.output_box, "torch"), 1, "torche au coffre rouge")


func test_caserne_waits_for_items_in_blue_chest() -> void:
	var sim := game()
	var b := built("caserne", -14.0, -118.0)
	GameState.res["discipline"] = 1000.0
	sim.train_unit(b, "archer")
	check_eq(b.queue, ["archer"] as Array[String], "escouade en file (objets apportés ensuite)")
	check_near(GameState.res["discipline"], 900.0, 1e-9, "Discipline payée")
	staff(sim, b, 1)
	run(sim, Catalog.CASERNE_TIME + 1.0)
	check_eq(b.queue.size(), 1, "sans arc : l'entraînement attend")
	_stock({"bow": 1})
	run(sim, 60.0)
	check(b.queue.is_empty(), "objets apportés : escouade formée")
	check_eq(Storage.count("bow"), 0, "1 arc consommé")
	check_eq(GameState.units.filter(func(u: Unit) -> bool: return u.role == "archer").size(), 1, "un archer")


func test_creuset_gear_stats() -> void:
	var sim := game()
	var u := engineer()
	u.unarmored = true
	var base_armor := Catalog.armor(u)
	var base_dmg := Catalog.attack_damage(u)
	var pack: Array[Dictionary] = [{"item": "iron_armor", "quantity": 1}, {"item": "copper_shield", "quantity": 1},
		{"item": "iron_greatsword", "quantity": 1}, {"item": "cannon", "quantity": 1}]
	check(Gear.equip(u, pack, 0, "Torse"), "armure en fer portée")
	check(Gear.equip(u, pack, 1, "Main gauche"), "bouclier porté")
	check_eq(Catalog.armor(u), base_armor + 6 + 1, "défense de l'armure et du bouclier")
	check(Gear.equip(u, pack, 2, "Main droite"), "épée à deux mains portée")
	check(not u.equipment.has("Main gauche"), "la main gauche est libérée")
	check(pack.any(func(s: Dictionary) -> bool: return not s.is_empty() and s["item"] == "copper_shield"), "bouclier rendu au sac")
	check_eq(Catalog.attack_damage(u), 18, "dégâts élevés")
	check(base_dmg < 18, "plus fort qu'à mains nues")
	var shield_at := pack.find_custom(func(s: Dictionary) -> bool: return not s.is_empty() and s["item"] == "copper_shield")
	check(not Gear.equip(u, pack, shield_at, "Main gauche"), "pas de bouclier avec une arme à deux mains")
	# Canon : portée 12, dégâts 12, une munition de fer par tir ; sans fer, retour aux poings.
	var cannon_at := pack.find_custom(func(s: Dictionary) -> bool: return not s.is_empty() and s["item"] == "cannon")
	check(Gear.equip(u, pack, cannon_at, "Main droite"), "canon porté")
	GameState.base_inventory_unlocked = true
	check_near(Catalog.unit_reach(u), Catalog.FIGHT["engineer"]["reach"], 1e-9, "sans fer, portée de mêlée")
	_stock({"iron": 2})
	check_near(Catalog.unit_reach(u), 12.0, 1e-9, "portée 12")
	check_eq(Catalog.attack_damage(u), 12, "dégâts 12")
	var e := Enemy.make("brute", u.x + 8.0, u.z, 1.0)
	e.hp = 500.0
	e.max_hp = 500.0
	GameState.enemies.append(e)
	sim.combat.barracks_strike(u, e)
	check_eq(Storage.count("iron"), 1, "une munition de fer tirée")
	check(e.hp < 500.0, "le tir touche")
	sim.combat.barracks_strike(u, e)
	check_eq(Storage.count("iron"), 0, "dernière munition")
	check_eq(Catalog.attack_damage(u), base_dmg, "plus de fer : dégâts à mains nues")


func test_creuset_art_two_by_two() -> void:
	check_eq(int(Catalog.BUILDINGS["creuset"]["size"]), 2, "emprise 2 × 2")
	check_eq(Catalog.BUILDINGS["creuset"]["art"], "da-creuset", "dessin du Portique de coulée")
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/manifest.json"))
	var art: Dictionary = m["buildings"]["arts"]["da-creuset"]
	check_eq(float(art.get("scale", 0.0)), 1.0, "dessiné à l'échelle native")
	check_eq(int(art["anim"]["count"]), 72, "boucle de 72 images (une coulée de 6 s)")
	check(ResourceLoader.exists("res://assets/baked/hud/portraits/bld-creuset.png"), "portrait du HUD")
