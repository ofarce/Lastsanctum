extends "res://tests/test_case.gd"
## Plans de mods (2026-11-22) : le butin ne donne plus de mod, seulement son plan ; ramassé, le plan apprend la
## recette du mod, fabriqué ensuite à l'Établi d'exo (data/recipes.gd PLANS, sim/loot.gd).

const Recipes := preload("res://data/recipes.gd")
const Gear := preload("res://data/gear_items.gd")


func _mods() -> Array[String]:
	var out: Array[String] = []
	for item: String in Gear.ITEMS:
		if Gear.ITEMS[item].has("module"):
			out.append(item)
	return out


func test_every_mod_has_a_plan_and_a_recipe() -> void:
	for mod in _mods():
		var plan := "plan_" + String(Gear.ITEMS[mod]["module"])
		check(Recipes.ITEMS.has(plan), "objet plan pour " + mod)
		check_eq(Recipes.PLAN_ITEMS.get(plan, ""), mod, "le plan apprend " + mod)
		check(Recipes.PLANS.has(mod), "recette sur plan : " + mod)
		check(Recipes.RECIPES["etabli"].has(mod), "fabriqué à l'Établi d'exo : " + mod)
		check_eq(Loot.rarity_of(plan), Loot.rarity_of(mod), "le plan a la rareté du mod : " + mod)


func test_loot_drops_plans_never_mods() -> void:
	for table: Dictionary in [Loot.TABLE, Loot.CACHES, Loot.FLAWLESS]:
		for kind: String in table:
			for row: Dictionary in table[kind]:
				var items: Array = [row["item"]] if row.has("item") else row["pick"]
				for item: String in items:
					check(not Gear.ITEMS.get(item, {}).has("module"), "%s lâche un mod au lieu de son plan : %s" % [kind, item])
	check_eq(Loot.TABLE["martyre"][0]["item"], "plan_veil", "la Martyre lâche le plan du Voile")
	check_eq(Loot.TABLE["gorge"][0]["item"], "plan_drill", "Gorge-Cuivre lâche le plan de la Foreuse")


func test_picking_a_plan_learns_the_recipe() -> void:
	var saved := GameState.plans.duplicate()
	GameState.plans.clear()
	check(not Recipes.plan_known("module_lens"), "recette masquée avant le plan")
	Loot.picked("plan_lens")
	check(Recipes.plan_known("module_lens"), "plan ramassé : recette apprise")
	check(not Recipes.learn("plan_lens"), "un second plan n'apprend rien de neuf")
	# Barillet double retiré du jeu : une autre recette sur plan sert de témoin.
	check(not Recipes.plan_known("module_frost"), "les autres recettes restent masquées")
	GameState.plans.assign(saved)
