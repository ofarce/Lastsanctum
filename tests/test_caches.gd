extends "res://tests/test_case.gd"
## Caches de la jungle (sim/loot.gd, place_caches) : épaves, poste abandonné, dépôts des ponts écartés.

const ItemStorage := preload("res://sim/item_storage.gd")
const SEED := 20261114


func _caches() -> Array[Dictionary]:
	var river := River.new(SEED)
	return Loot.place_caches(Road.new(SEED, river), SEED)


func test_caches_are_placed_and_deterministic() -> void:
	var a := _caches()
	var kinds := {}
	for c in a:
		kinds[c["kind"]] = int(kinds.get(c["kind"], 0)) + 1
		check(not (c["loot"] as Array).is_empty(), "cache pleine (%s)" % c["kind"])
		check(CaveShape.outdoors(c["x"], c["z"]), "cache dans la jungle")
	check_eq(kinds.get("cart", 0), 3, "trois épaves")
	check_eq(kinds.get("outpost", 0), 1, "la caisse du poste")
	check_eq(kinds.get("bridge", 0), 4, "un dépôt par pont écarté")
	var b := _caches()
	check_eq(a.size(), b.size(), "même graine, mêmes caches")
	for i in a.size():
		check_eq(a[i]["loot"], b[i]["loot"], "même butin")
	var river := River.new(SEED)
	for c in a:
		if c["kind"] == "bridge":
			check(not river.water_at(c["x"], c["z"]), "dépôt hors de l'eau")
			check(not river.far_bank(c["x"], c["z"]), "dépôt sur la rive nord")


func test_exile_on_foot_empties_a_cache() -> void:
	GameState.reset()
	GameState.caches = _caches()
	var c: Dictionary = GameState.caches[0]
	var n := (c["loot"] as Array).size()
	var u := Unit.new()
	u.role = "engineer"
	u.unarmored = true
	u.hp = 100.0
	u.max_hp = 100.0
	u.inventory_capacity = 12
	u.x = float(c["x"]) + 40.0
	u.z = float(c["z"])
	GameState.units.append(u)
	if not ItemStorage.character_available(u):
		print("     (Exilé à pied indisponible dans ce montage : fouille non vérifiée)")
		GameState.reset()
		return
	Loot.collect(u)
	check_eq((c["loot"] as Array).size(), n, "trop loin : rien n'est pris")
	u.x = float(c["x"]) + 1.0
	Loot.collect(u)
	check((c["loot"] as Array).is_empty(), "cache vidée")
	var held := 0
	for stack: Dictionary in u.inventory:
		if not stack.is_empty():
			held += int(stack["quantity"])
	check_eq(held, n, "tout le butin est dans le paquetage")
	GameState.reset()
