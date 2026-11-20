extends "res://tests/econ_case.gd"
## Défenses de l'Atelier posées au sol (sim/placeables.gd) : poste de tir, barricade, chausse-trappe.

const P := preload("res://sim/placeables.gd")
const Storage := preload("res://sim/item_storage.gd")

## Case dégagée de la salle de départ, près de l'Ancre.
const SPOT := Vector2(18.0, -130.0)


func _stock(item: String, n := 1) -> void:
	GameState.base_inventory_unlocked = true
	for i in n:
		Storage.store(GameState.base_inventory, Storage.BASE_CAPACITY, item)


## Brouillard : l'Ingénieur sort du portail et se tient à deux cases au sud de SPOT.
func _reveal(sim: Simulation) -> void:
	var u := engineer()
	u.hidden = false
	u.x = SPOT.x
	u.z = SPOT.y + 8.0
	sim.world.fog.refresh(sim.state())


func test_place_consumes_stock() -> void:
	var sim := game()
	_reveal(sim)
	check(P.refusal(sim, "caltrops", SPOT) != "", "rien en stock : refusé")
	_stock("caltrops", 2)
	check_eq(P.refusal(sim, "caltrops", SPOT), "", "case dégagée et repérée")
	sim.arm_place("caltrops")
	sim.place_item(SPOT)
	check_eq(GameState.placed.size(), 1, "chausse-trappe posée")
	check_eq(Storage.count("caltrops"), 1, "un objet consommé")
	check_eq(GameState.hud_mode, "place", "mode pose gardé tant qu'il en reste")
	check_eq(GameState.placed[0]["x"], P.center(P.cell_of(SPOT)).x, "centrée sur la case")
	sim.place_item(SPOT)
	check_eq(GameState.placed.size(), 1, "case déjà occupée")
	sim.place_item(SPOT + Vector2(4.0, 0.0))
	check_eq(GameState.placed.size(), 2, "case voisine")
	check_eq(GameState.hud_mode, "", "stock épuisé : sortie du mode pose")


func test_barricade_blocks_walk() -> void:
	var sim := game()
	_reveal(sim)
	_stock("barricade")
	var mid := P.center(P.cell_of(SPOT))
	check(sim.state().walkable(mid.x, mid.y), "praticable avant")
	var v := sim.state().version
	check(P.place(sim, "barricade", SPOT), "barricade posée")
	check(not sim.state().walkable(mid.x, mid.y), "infranchissable après")
	check(sim.state().version > v, "chemins à recalculer")
	var path: Variant = sim.world.pathfinder.find_path(mid + Vector2(-6.0, 0.0), mid + Vector2(6.0, 0.0))
	check(path != null, "un détour existe")
	for q: Vector2 in path:
		check(P.cell_of(q) != P.cell_of(SPOT), "le chemin évite la barricade")
	sim.new_game(1)
	check(sim.state().walkable(mid.x, mid.y), "nouvelle partie : barricade retirée")


func test_barricade_refused_on_unit() -> void:
	var sim := game()
	_reveal(sim)
	_stock("barricade")
	var u := engineer()
	u.hidden = false
	u.x = P.center(P.cell_of(SPOT)).x
	u.z = P.center(P.cell_of(SPOT)).y
	check(P.refusal(sim, "barricade", SPOT) != "", "pas sur une unité")


func test_caltrops_damage() -> void:
	var sim := game()
	_reveal(sim)
	_stock("caltrops")
	P.place(sim, "caltrops", SPOT)
	var mid := P.center(P.cell_of(SPOT))
	var e := Enemy.make("brute", mid.x, mid.y, 1.0)
	e.hp = 500.0
	e.max_hp = 500.0
	e.armor = 0.0
	var away := Enemy.make("brute", mid.x + 8.0, mid.y, 1.0)
	away.hp = 500.0
	GameState.enemies.append_array([e, away])
	for i in 60:
		P.tick(sim, 1.0 / 60.0)
	check_near(e.hp, 500.0 - P.CALTROPS_DPS, 1e-3, "25 dégâts en une seconde")
	check_near(away.hp, 500.0, 1e-9, "hors de la case : intact")


func test_firing_post_extends_reach() -> void:
	var sim := game()
	_reveal(sim)
	_stock("firing_post")
	var archer := sim.spawn("Archer", SPOT.x, SPOT.y + 1.0, "archer")
	var lame := sim.spawn("Lame", SPOT.x, SPOT.y - 1.0, "lame")
	var base := Catalog.unit_reach(archer)
	var melee := Catalog.unit_reach(lame)
	check(P.place(sim, "firing_post", SPOT), "poste posé")
	check_near(Catalog.unit_reach(archer), base * 1.5, 1e-9, "archer posté : portée augmentée de moitié")
	check_near(Catalog.unit_reach(lame), melee, 1e-9, "corps à corps : inchangé")
	archer.x += 10.0
	check_near(Catalog.unit_reach(archer), base, 1e-9, "loin du poste : portée normale")


func test_order_post_moves_selection_onto_post() -> void:
	var sim := game()
	_reveal(sim)
	_stock("firing_post")
	check(P.place(sim, "firing_post", SPOT), "poste posé")
	var a := sim.spawn("Archer", SPOT.x + 12.0, SPOT.y, "archer")
	var b := sim.spawn("Archer", SPOT.x - 12.0, SPOT.y, "archer")
	check(not P.posted(a), "loin : pas de bonus")
	GameState.selected = [a, b]
	var post := P.firing_post_at(SPOT)
	check(not post.is_empty(), "poste trouvé sous le clic")
	P.order_post(sim, post)
	for u: Unit in [a, b]:
		check(Vector2(u.tx, u.tz).distance_to(Vector2(post["x"], post["z"])) < P.POST_RADIUS, "destination dans le poste")
		check_eq(u.stance, "hold", "tient la position")
	a.x = a.tx
	a.z = a.tz
	check(P.posted(a), "posté : bonus actif")


func test_engineer_place_menu() -> void:
	var sim := game()
	_stock("barricade", 3)
	GameState.selected = [engineer()]
	var ids := HudModel.panel_actions(sim).map(func(a: Dictionary) -> String: return a["id"])
	check(ids.has("menu-place"), "Poser dans les ordres de l'Ingénieur")
	GameState.hud_menu = "place"
	var A := HudModel.panel_actions(sim)
	var place := A.filter(func(a: Dictionary) -> bool: return a["id"].begins_with("place-"))
	check_eq(place.size(), 3, "trois défenses")
	var barr: Dictionary = place.filter(func(a: Dictionary) -> bool: return a["id"] == "place-barricade")[0]
	check(not barr["disabled"], "barricades en stock")
	check(place.filter(func(a: Dictionary) -> bool: return a["id"] == "place-caltrops")[0]["disabled"], "aucune chausse-trappe")
	barr["run"].call()
	check_eq(GameState.hud_mode, "place", "mode pose armé")
	check_eq(GameState.hud_place_item, "barricade", "objet choisi")
