class_name Production
extends RefCounted
## Bâtiments servis par des adeptes (règles validées le 2026-11-17).
##  - Un bâtiment non-temple de Catalog.STAFF_ROLE ne fonctionne qu'avec au moins un travailleur au poste : adepte
##    de son culte, ou l'Ingénieur. Jusqu'à STAFF_MAX travailleurs ; vitesse proportionnelle à leur nombre.
##  - Réseau des coffres (2026-11-20) : coffres bleus, rouges et coffre antique forment un seul stockage infini
##    (GameState.base_inventory). Fabrication (Atelier, Forge, Creuset) : la recette choisie est fabriquée en
##    boucle, ingrédients pris dans le réseau, produit déposé dans le réseau. Plus de trajets d'approvisionnement.
##  - Mineurs (adeptes d'Aether, MINERS_MAX, hors vitesse) : exploitent un gisement inépuisable et rapportent des
##    lots de MINE_BATCH au coffre le plus proche du réseau (coffre antique ou coffre d'un bâtiment).
## Tâche d'une unité : {"type": "staff", "building", "post": "worker" | "miner", "step": "post" | "fetch" |
## "return" | "mine" | "deliver", "fetch": {item, qty, src}, "cell", "mined"}. Le bâtiment ne garde aucune
## référence aux unités : son personnel se lit dans les tâches.

const ItemStorage := preload("res://sim/item_storage.gd")
const Recipes := preload("res://data/recipes.gd")
const HarvestFx := preload("res://sim/harvest_fx.gd")

## Distance d'arrivée à un point de travail, à un coffre.
const REACH := 0.7
## Cases des coffres bleu et rouge : ceux du réseau, sans limite (piles de 9 999).
const BOX_CAPACITY := ItemStorage.BASE_CAPACITY
## Ingrédients demandés d'avance, en nombre de fabrications.
const STOCK_TARGET := 2
const WAREHOUSE_TARGET := 5
const CARRY_CAPACITY := 5

var sim: Simulation


func _init(simulation: Simulation) -> void:
	sim = simulation


# ---------------------------------------------------------------- Lecture (HUD, rendu, tests)

static func staff_role(b: Building) -> String:
	return Catalog.STAFF_ROLE.get(b.type, "") if b else ""


static func staffed(b: Building) -> bool:
	return b != null and Catalog.STAFF_ROLE.has(b.type)


## Bâtiment producteur d'objets : il a ses deux coffres.
static func has_chests(b: Building) -> bool:
	return b != null and (Recipes.has_station(b.type) or b.type in ["caserne", "ecole", "warehouse", "eglise"])


static func chest_kinds(b: Building) -> Array:
	return ["out"] if b.type in ["warehouse", "eglise"] else ["in", "out"]


static func is_member(u: Unit, b: Building, post := "") -> bool:
	var j: Variant = u.job
	return j != null and j.get("type") == "staff" and j.get("building") == b and (post == "" or j.get("post") == post)


## Personnel affecté au bâtiment (« worker » ou « miner »), par identifiant croissant (places stables).
static func members(b: Building, post: String) -> Array[Unit]:
	var out: Array[Unit] = []
	for u: Unit in GameState.units:
		if u.alive() and not u.hidden and is_member(u, b, post):
			out.append(u)
	out.sort_custom(func(a: Unit, c: Unit) -> bool: return a.id < c.id)
	return out


## Travailleurs présents au poste : ce sont eux qui font tourner le bâtiment.
static func at_post(b: Building) -> int:
	var n := 0
	for u: Unit in members(b, "worker"):
		if u.working and u.job.get("step") == "post":
			n += 1
	return n


## Facteur de vitesse du bâtiment (0 : à l'arrêt).
static func speed(b: Building) -> float:
	return float(at_post(b)) if staffed(b) else 1.0


static func idle(b: Building) -> bool:
	if b != null and b.type == "warehouse":
		return b.complete and not source_open(b)
	return staffed(b) and b.complete and at_post(b) == 0


## Coffre bleu (« in ») à gauche devant le bâtiment, rouge (« out ») à droite.
static func chest_pos(b: Building, kind: String) -> Vector2:
	var h := b.half()
	return Vector2(b.x + (-1.0 if kind == "in" else 1.0) * (h - 1.2), b.z + h + 0.8)


## Places des travailleurs entre les deux coffres : trois devant, deux en retrait (unités de monde).
const POSTS: Array[Vector2] = [Vector2(-1.6, 1.6), Vector2(1.6, 1.6), Vector2(0.0, 1.6), Vector2(-0.8, 3.0), Vector2(0.8, 3.0)]


## Place du i-ème travailleur, entre les deux coffres.
static func post_spot(b: Building, i: int) -> Vector2:
	var o: Vector2 = POSTS[posmod(i, POSTS.size())]
	return Vector2(b.x + o.x, b.z + b.half() + o.y)


static func count_in(items: Array, item: String) -> int:
	var n := 0
	for stack: Dictionary in items:
		if not stack.is_empty() and stack["item"] == item:
			n += int(stack["quantity"])
	return n


static func has_items(items: Array, cost: Dictionary) -> bool:
	for k: String in cost:
		if count_in(items, k) < int(cost[k]):
			return false
	return true


## Retire jusqu'à `n` exemplaires de `item` ; renvoie le nombre retiré.
static func take_from(items: Array, item: String, n: int) -> int:
	var got := 0
	for i in items.size():
		var stack: Dictionary = items[i]
		if got >= n or stack.is_empty() or stack["item"] != item:
			continue
		var k := mini(n - got, int(stack["quantity"]))
		stack["quantity"] -= k
		got += k
		if stack["quantity"] <= 0:
			items[i] = {}
	return got


## Range `n` exemplaires ; renvoie le nombre qui n'a pas trouvé de place.
static func put_into(items: Array[Dictionary], item: String, n: int) -> int:
	for i in n:
		if not ItemStorage.store(items, BOX_CAPACITY, item):
			return n - i
	return 0


## Ingrédients que le bâtiment veut avoir dans son coffre bleu.
static func needs(b: Building) -> Dictionary:
	var out := {}
	if b.type == "warehouse":
		for item: String in b.requested_items:
			if ItemStorage.has_room(b.output_box, BOX_CAPACITY, item):
				out[item] = WAREHOUSE_TARGET
	elif Recipes.has_station(b.type) and b.recipe != "":
		var cost: Dictionary = Recipes.RECIPES[b.type].get(b.recipe, {})
		for k: String in cost:
			out[k] = int(cost[k]) * STOCK_TARGET
	elif Catalog.TRAINERS.has(b.type):
		for id: String in b.queue.slice(0, 2):
			var cost := Recipes.caserne_cost(id, 4)
			for k: String in cost:
				out[k] = int(out.get(k, 0)) + int(cost[k])
	return out


## Ingrédients en route vers ce bâtiment (adeptes partis les chercher ou qui les rapportent).
static func in_transit(b: Building, item: String) -> int:
	var n := 0
	for u: Unit in members(b, "worker"):
		var step: String = u.job.get("step", "")
		if step == "fetch" and u.job["fetch"]["item"] == item:
			n += int(u.job["fetch"]["qty"])
		elif step == "return" and u.carrying.get("item") == item:
			n += int(u.carrying["quantity"])
	return n


# ---------------------------------------------------------------- Sources des transports

static func src_items(src: Dictionary) -> Array:
	match src.get("kind"):
		"building":
			return (src["building"] as Building).output_box
		"vault":
			return GameState.base_inventory
		"engineer":
			return (src["unit"] as Unit).inventory
	return []


static func src_pos(src: Dictionary) -> Vector2:
	match src.get("kind"):
		"building":
			return chest_pos(src["building"], "out") + Vector2(0.0, 1.0)
		"vault":
			return CaveShape.CHEST_SPOT
		"engineer":
			return (src["unit"] as Unit).pos()
	return Vector2.ZERO


static func src_valid(src: Dictionary) -> bool:
	match src.get("kind"):
		"building":
			return GameState.buildings.has(src["building"]) and source_open(src["building"])
		"vault":
			return ItemStorage.network_open()
		"engineer":
			return ItemStorage.character_available(src["unit"])
	return false


static func _same_src(a: Dictionary, c: Dictionary) -> bool:
	return a.get("kind") == c.get("kind") and a.get("building") == c.get("building") and a.get("unit") == c.get("unit")


## Exemplaires déjà promis à des adeptes en route vers cette source.
static func reserved(src: Dictionary, item: String) -> int:
	var n := 0
	for u: Unit in GameState.units:
		var j: Variant = u.job
		if u.alive() and j != null and j.get("type") == "staff" and j.get("step") == "fetch" \
				and j["fetch"]["item"] == item and _same_src(j["fetch"]["src"], src):
			n += int(j["fetch"]["qty"])
	return n


static func source_open(b: Building) -> bool:
	return b.complete and (b.type != "warehouse" or not members(b, "worker").is_empty())


static func supply_sources(b: Building) -> Array[Dictionary]:
	var cands: Array[Dictionary] = []
	for c: Building in GameState.buildings:
		if c != b and source_open(c) and has_chests(c):
			cands.append({"kind": "building", "building": c})
	if GameState.base_inventory_unlocked:
		cands.append({"kind": "vault"})
	for u: Unit in GameState.units:
		if ItemStorage.character_available(u):
			cands.append({"kind": "engineer", "unit": u})
	return cands


static func find_source(b: Building, item: String, carrier: Unit = null) -> Dictionary:
	var best := {}
	var best_d := INF
	var from := carrier.pos() if carrier != null else chest_pos(b, "in")
	for src: Dictionary in supply_sources(b):
		var available := count_in(src_items(src), item) - reserved(src, item)
		if b.type == "warehouse" and src["kind"] == "building":
			var source: Building = src["building"]
			if source.type == "warehouse" and source.requested_items.has(item):
				available -= WAREHOUSE_TARGET
		if available <= 0:
			continue
		var d := from.distance_to(src_pos(src))
		if d < best_d:
			best_d = d
			src["available"] = available
			best = src
	return best


# ---------------------------------------------------------------- Mise à jour

## Une image : objets perdus par les porteurs sans tâche, puis chaque bâtiment servi.
func update(dt: float) -> void:
	for u: Unit in GameState.units:
		if not u.carrying.is_empty() and (not u.alive() or u.job == null or u.job.get("type") not in ["dig", "staff"]):
			_drop(u)
	for b: Building in GameState.buildings:
		if not b.complete or not staffed(b):
			continue
		if Recipes.has_station(b.type):
			_craft(b, dt)
		elif Catalog.TRAINERS.has(b.type):
			_train(b, dt)


static func craft_workers(b: Building) -> int:
	var cost: Dictionary = Recipes.RECIPES.get(b.type, {}).get(b.recipe, {})
	if cost.is_empty() or not has_items(b.input_box, cost):
		return 0
	# Le réseau des coffres n'a pas de limite : le produit trouve toujours sa place.
	return at_post(b)


func _craft(b: Building, dt: float) -> void:
	if b.recipe == "" or not Recipes.RECIPES[b.type].has(b.recipe):
		b.craft = 0.0
		return
	var n := craft_workers(b)
	if n == 0:
		return
	var cost: Dictionary = Recipes.RECIPES[b.type][b.recipe]
	b.craft += dt * n * Mods.work_mult(Vector2(b.x, b.z))
	if b.craft < Recipes.craft_time(b.type):
		return
	b.craft = 0.0
	for k: String in cost:
		take_from(b.input_box, k, int(cost[k]))
	put_into(b.output_box, b.recipe, Recipes.output_quantity(b.recipe))
	b.chest_out_at = GameState.sim_time
	# Un mod ne se fabrique qu'une fois : la recette s'arrête et reste fermée.
	if Recipes.PLANS.has(b.recipe):
		GameState.mods_crafted.append(b.recipe)
		sim.say("%s · %s fabriqué" % [b.def()["name"], Recipes.name_of(b.recipe)], 2.0)
		b.recipe = ""
	Sfx.at("forge", b.x, b.z)


func _train(b: Building, dt: float) -> void:
	if b.queue.is_empty():
		b.train = 0.0
		return
	var items := Recipes.caserne_cost(b.queue[0], 4)
	var n := at_post(b)
	if n == 0 or not has_items(b.input_box, items):
		return
	b.train += dt * n * Mods.work_mult(Vector2(b.x, b.z))
	if b.train < Catalog.CASERNE_TIME:
		return
	b.train = 0.0
	for k: String in items:
		take_from(b.input_box, k, int(items[k]))
	sim.spawn_trained(b, b.queue.pop_front())


## Tâche « staff » d'une unité, appelée par Simulation.update_adepts.
func update_unit(u: Unit, dt: float) -> void:
	var j: Dictionary = u.job
	var b: Building = j["building"]
	if not GameState.buildings.has(b) or not b.complete:
		u.job = null
		return
	match String(j.get("step", "post")):
		"post":
			var i := members(b, "worker").find(u)
			if _go(u, post_spot(b, maxi(0, i))):
				u.working = true
		"fetch":
			var f: Dictionary = j["fetch"]
			if not src_valid(f["src"]) or (b.type == "warehouse" and not b.requested_items.has(f["item"])):
				j.erase("fetch")
				j["step"] = "post"
				return
			if not _go(u, src_pos(f["src"]), 1.2):
				return
			var got := take_from(src_items(f["src"]), f["item"], mini(CARRY_CAPACITY, int(f["qty"])))
			j.erase("fetch")
			if got == 0:
				j["step"] = "post"
				return
			if f["src"]["kind"] == "building":
				(f["src"]["building"] as Building).chest_out_at = GameState.sim_time
			u.carrying = {"item": f["item"], "quantity": got}
			j["step"] = "return"
		"deliver":
			if deliver_harvest(u):
				j["mined"] = 0
				j["step"] = "mine"
				if j.get("exhausted", false):
					u.job = null
		"return":
			var box := "out" if b.type == "warehouse" else "in"
			if not _go(u, chest_pos(b, box) + Vector2(0.0, 1.0)):
				return
			_deliver(u, b)
			j["step"] = "post"
		"mine":
			_mine(u, j, dt)


## Le lot est déposé au coffre du réseau le plus proche : coffre antique (ouvert) ou coffre d'un bâtiment achevé.
func deliver_harvest(u: Unit) -> bool:
	var item: String = u.carrying["item"]
	var target := Vector2.INF
	var distance := INF
	var at: Building = null
	if GameState.base_inventory_unlocked:
		target = CaveShape.CHEST_SPOT
		distance = u.pos().distance_squared_to(target)
	for b: Building in GameState.buildings:
		if not b.complete or not has_chests(b):
			continue
		var spot := chest_pos(b, chest_kinds(b)[0]) + Vector2(0.0, 1.0)
		var d := u.pos().distance_squared_to(spot)
		if d < distance:
			at = b
			target = spot
			distance = d
	if target != Vector2.INF and not _go(u, target):
		return false
	for i in int(u.carrying["quantity"]):
		ItemStorage.deposit(item, null, u.pos())
	u.carrying = {}
	if at:
		at.chest_in_at = GameState.sim_time
		Sfx.at("coffre", at.x, at.z)
	return true


func _go(u: Unit, p: Vector2, reach := REACH) -> bool:
	u.tx = p.x
	u.tz = p.y
	return Combat.hyp(u.x - p.x, u.z - p.y) < reach


func _deliver(u: Unit, b: Building) -> void:
	if u.carrying.is_empty():
		return
	var item: String = u.carrying["item"]
	if b.type == "warehouse":
		var excess := put_into(b.output_box, item, u.carrying["quantity"])
		u.carrying["quantity"] = excess
		_drop(u)
		b.chest_out_at = GameState.sim_time
		return
	var left := put_into(b.input_box, item, int(u.carrying["quantity"]))
	u.carrying = {}
	Sfx.at("coffre", b.x, b.z)
	for i in left:
		ItemStorage.deposit(item, null, chest_pos(b, "in"))
	b.chest_in_at = GameState.sim_time
	if u.job != null:
		u.job["mined"] = 0


## Une cargaison interrompue tombe à la position du porteur.
func _drop(u: Unit) -> void:
	var item: String = u.carrying["item"]
	for i in int(u.carrying["quantity"]):
		GameState.ground_items.append({"item": item, "position": u.pos()})
	u.carrying = {}


func _mine(u: Unit, j: Dictionary, dt: float) -> void:
	var c: Dictionary = j["cell"]
	var key := Vector2i(c["i"], c["j"])
	var st := sim.state()
	var block := st.block_definition(key.x, key.y)
	if block.is_empty() or not st.permanent_ores.has(key):
		j["exhausted"] = true
		j["step"] = "deliver" if not u.carrying.is_empty() else "post"
		if u.carrying.is_empty():
			u.job = null
		return
	if not _go(u, c["at"]):
		return
	var item: String = block["drop_item"]
	u.working = true
	Sfx.at("minage", u.x, u.z)  # coups de pioche espacés par MIN_GAP
	var interval := Simulation.adept_mining_seconds(u)
	var before := float(j.get("work", 0.0))
	j["work"] = before + dt * Mods.work_mult(u.pos())
	var hit := HarvestFx.work(u, st, key, item, before, j["work"], interval)
	while j["work"] >= interval:
		j["work"] -= interval
		j["mined"] = int(j.get("mined", 0)) + 1
		u.carrying = {"item": item, "quantity": j["mined"]}
		GameState.effects.append({"type": "mining_gain", "miner": u, "item": item, "age": 0.0, "duration": 1.0, "from": hit})
		c["at"] = sim.next_lode_spot(key, c["at"])
		if j["mined"] >= Catalog.MINE_BATCH:
			j["step"] = "deliver"
			return
		# Filon illimité : il change de poste autour du filon avant le coup suivant.
		if not _go(u, c["at"]):
			j["work"] = 0.0
			return


# ---------------------------------------------------------------- Ordres

## Clic droit sur un bâtiment servi : les unités sélectionnées du bon culte (et l'Ingénieur) y prennent un poste.
func assign(b: Building) -> bool:
	if b == null or not b.complete or not staffed(b):
		return false
	var role := staff_role(b)
	var handled := false
	var refused := false
	var full := false
	for u: Unit in GameState.selected:
		if not u.alive() or u.hidden:
			continue
		if u.role != role and (u.role != "engineer" or b.type == "warehouse"):
			refused = refused or Catalog.is_adept(u) or u.role == "engineer"
			continue
		handled = true
		if is_member(u, b, "worker"):
			continue
		if members(b, "worker").size() >= Catalog.STAFF_MAX:
			full = true
			continue
		sim.set_job(u, {"type": "staff", "building": b, "post": "worker", "step": "post"})
	var name: String = b.def()["name"]
	if full:
		sim.say("%s : les %d postes sont occupés." % [name, Catalog.STAFF_MAX], 2.0)
	elif handled:
		sim.say("%s · %d / %d au poste." % [name, members(b, "worker").size(), Catalog.STAFF_MAX], 2.0)
	elif refused:
		sim.say("%s n’accepte que les adeptes de %s." % [name, Catalog.DEITY_NAMES[role]], 2.5)
		return true
	return handled


## Clic droit sur un gisement inépuisable avec un adepte d'Aether affecté à un bâtiment : il en devient mineur.
func try_miner(u: Unit, cells: Array) -> bool:
	if u.role != Catalog.MINER_ROLE or u.job == null or u.job.get("type") != "staff" or cells.is_empty():
		return false
	var c: Dictionary = cells[0]
	if not sim.state().permanent_ores.has(Vector2i(c["i"], c["j"])):
		return false
	var b: Building = u.job["building"]
	if not has_chests(b) or b.type in ["warehouse", "eglise"]:
		return false
	if not is_member(u, b, "miner") and members(b, "miner").size() >= Catalog.MINERS_MAX:
		sim.say("%s : déjà %d mineurs." % [b.def()["name"], Catalog.MINERS_MAX], 2.0)
		return true
	if sim.node_full(c, u):
		sim.say("Déjà %d adeptes sur ce gisement." % Catalog.NODE_ADEPTS_MAX, 2.0)
		return true
	sim.set_job(u, {"type": "staff", "building": b, "post": "miner", "step": "mine", "cell": c.duplicate(), "mined": 0})
	sim.say("L’adepte mine pour le %s et rapportera des lots de %d." % [b.def()["name"], Catalog.MINE_BATCH], 2.0)
	return true


## Recette fabriquée en boucle ; la même recette une seconde fois l'arrête.
func select_recipe(b: Building, item: String) -> void:
	if b == null or not b.complete or not Recipes.RECIPES.get(b.type, {}).has(item):
		return
	if b.recipe != item and (not Ages.recipe_open(item) or Recipes.disabled(item)):
		return
	if b.recipe != item and Recipes.once_done(item):
		sim.say("%s : déjà fabriqué." % Recipes.name_of(item), 2.0)
		return
	if b.recipe != item and not Simulation.recipe_unlocked(item):
		sim.say("%s : recherche « %s » requise (%s)." % [Recipes.name_of(item), Catalog.RESEARCH[Catalog.RECIPE_RESEARCH[item]]["name"], Catalog.BUILDINGS[Catalog.RESEARCH[Catalog.RECIPE_RESEARCH[item]]["building"]]["name"]], 2.5)
		return
	b.recipe = "" if b.recipe == item else item
	b.craft = 0.0
	sim.say("%s · %s" % [b.def()["name"], ("fabrique en boucle : " + Recipes.name_of(item)) if b.recipe != "" else "fabrication arrêtée"], 2.0)


## Ancien « Vider le coffre rouge » : le coffre rouge fait partie du réseau, il n'y a plus rien à rapporter.
func order_collect(_b: Building) -> bool:
	return false


## Tâche « collect » de l'Ingénieur.
func update_collect(u: Unit) -> void:
	var b: Building = u.job["building"]
	if not GameState.buildings.has(b):
		u.job = null
		return
	var kind: String = u.job.get("open_box", "out")
	if not _go(u, chest_pos(b, kind) + Vector2(0.0, 1.0), 1.2):
		return
	if u.job.has("open_box"):
		u.job = null
		if kind == "in":
			b.chest_in_at = GameState.sim_time
		else:
			b.chest_out_at = GameState.sim_time
		Events.production_chest_requested.emit(b, kind, u)
		return
	u.job = null
