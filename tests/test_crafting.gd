extends "res://tests/econ_case.gd"
## Fabrication : recettes de l'Atelier, de la Scierie, de l'Archerie, de la Fonderie et de l'Armurerie (data/recipes.gd), objets demandés
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
	check_eq(Recipes.RECIPES["workshop"].size(), 8, "8 recettes à l'Atelier (fibre, arc et flèches partis)")
	check_eq(Recipes.RECIPES["scierie"].keys(), ["wood_fiber"], "la Scierie fait la fibre de bois")
	check_eq(Recipes.RECIPES["archerie"].keys(), ["bow", "arrows"], "l'Archerie fait arcs et flèches")
	check_eq(Catalog.BUILDINGS["archerie"]["requires"], "scierie", "Archerie débloquée par la Scierie")
	check_eq(Catalog.STAFF_ROLE["scierie"], "aether", "Scierie servie par Aether")
	check_eq(Recipes.RECIPES["forge"].size(), 3, "3 recettes à la Fonderie : les lingots seuls")
	check_eq(Recipes.RECIPES["creuset"].size(), 11, "11 recettes à l'Armurerie")
	check_eq(Recipes.RECIPES["workshop"]["barricade"], {"wood": 10, "rock": 10}, "barricade")
	check_eq(Recipes.RECIPES["workshop"]["fishing_rod"], {"wood": 2, "iron": 1, "wood_fiber": 1}, "canne à pêche")
	check_eq(Recipes.RECIPES["creuset"]["iron_armor"], {"iron_ingot": 40}, "armure en fer")
	for item: String in Recipes.RECIPES["forge"]:
		check(item.ends_with("_ingot"), "la Fonderie ne fait que des lingots : " + item)
	for item: String in Recipes.RECIPES["creuset"]:
		for ing: String in Recipes.RECIPES["creuset"][item]:
			check(ing.ends_with("_ingot"), "l'Armurerie ne prend que des lingots : " + item)
	check(Recipes.RECIPES["creuset"].has("sword") and Recipes.RECIPES["creuset"].has("shield"), "épée et bouclier de soldat à l'Armurerie")
	check(Catalog.BUILDINGS.has("creuset"), "Armurerie constructible")
	check_eq(Catalog.BUILDINGS["creuset"]["requires"], "forge", "débloquée par la Fonderie")
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
	var b := built("archerie", -14.0, -118.0)
	_stock({"wood": 3})
	staff(sim, b, 1)
	sim.craft(b, "arrows")
	check_eq(b.recipe, "arrows", "recette choisie")
	check_eq(Storage.count("wood"), 3, "rien n'est pris au choix de la recette")
	run(sim, 120.0)
	check_eq(Production.count_in(b.output_box, "arrows"), 3 * Recipes.output_quantity("arrows"), "trois lots de flèches au coffre rouge")
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
	check(not Simulation.can_craft(b, "torch"), "la Fonderie ne fait pas de torche")


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
	# Arbalestrie (ancien canon) : portée 12, dégâts 12, de la mana de chaque type par tir (data/ammo.gd) ;
	# sans mana, pas de tir.
	var cannon_at := pack.find_custom(func(s: Dictionary) -> bool: return not s.is_empty() and s["item"] == "cannon")
	check(Gear.equip(u, pack, cannon_at, "Main droite"), "Arbalestrie portée")
	check_near(Catalog.unit_reach(u), 12.0, 1e-9, "portée 12")
	check_eq(Catalog.attack_damage(u), 12, "dégâts 12")
	var e := Enemy.make("brute", u.x + 8.0, u.z, 1.0)
	e.hp = 500.0
	e.max_hp = 500.0
	GameState.enemies.append(e)
	give(0.0)
	sim.combat.barracks_strike(u, e)
	check_eq(e.hp, 500.0, "sans mana, pas de tir")
	var mana: float = Gear.ITEMS["cannon"]["mana"]
	give(2.0 * mana)
	sim.combat.barracks_strike(u, e)
	check_near(GameState.res["forge"], mana, 1e-9, "mana d'un tir payée")
	check(e.hp < 500.0, "le tir touche")


func test_creuset_art_two_by_two() -> void:
	check_eq(int(Catalog.BUILDINGS["creuset"]["size"]), 2, "emprise 2 × 2")
	check_eq(Catalog.BUILDINGS["creuset"]["art"], "da-creuset", "dessin du Portique de coulée")
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/manifest.json"))
	var art: Dictionary = m["buildings"]["arts"]["da-creuset"]
	check_eq(float(art.get("scale", 0.0)), 1.0, "dessiné à l'échelle native")
	check_eq(int(art["anim"]["count"]), 72, "boucle de 72 images (une coulée de 6 s)")
	check(ResourceLoader.exists("res://assets/baked/hud/portraits/bld-creuset.png"), "portrait du HUD")
