class_name Loot
extends RefCounted
## Butin des ennemis et rareté des objets (biomes, 2026-11-20 ; planches/biomes-1-2-elements.html).
## Le butin reste sur le corps : un corps qui en porte se fouille pendant CORPSE_DAYS jours, puis disparaît avec
## lui ; un corps vide s'efface comme avant (EnemyArt.CORPSE_LIFETIME). De jour, seul l'Exilé à pied (sans armure,
## avec son paquetage) fouille en marchant dessus ; la nuit, l'Oublieux de l'Église s'en charge (sim/oublieux.gd).
## Les tirages n'utilisent pas le générateur de la simulation : les vagues restent identiques à graine égale.

const ItemStorage := preload("res://sim/item_storage.gd")
const Gear := preload("res://data/gear_items.gd")

const CORPSE_DAYS := 2.0
## Corps porteurs de butin gardés au plus ; au-delà les plus anciens disparaissent.
const MAX_LOOT_CORPSES := 240
## Fondu d'un corps qu'on vient de vider (s).
const EMPTY_FADE := 1.0

## Rareté voulue par l'utilisateur : blanc normal, vert peu commun, jaune rare, orange épique, violet unique,
## bleu cyan mythique. Teintes décalées de la charte (jaune citron, orange plus rouge qu'Indra, violet lilas).
const RARITY_ORDER: Array[String] = ["normal", "uncommon", "rare", "epic", "unique", "mythic"]
const RARITY := {
	"normal": {"name": "Normal", "color": Color("#e4e2da")},
	"uncommon": {"name": "Peu commun", "color": Color("#6fcf5a")},
	"rare": {"name": "Rare", "color": Color("#f2e14a")},
	"epic": {"name": "Épique", "color": Color("#f07a28")},
	"unique": {"name": "Unique", "color": Color("#b47af0")},
	"mythic": {"name": "Mythique", "color": Color("#5fd8e8")},
}

## Butins courants, sans usage pour l'instant : ils se ramassent et se stockent.
const ITEMS := {
	"ichor": {"name": "Ichor", "color": Color("#8a1f2c"), "desc": "Sang noir de la Bête, encore tiède. Sans usage pour le moment."},
	"acid_gland": {"name": "Glande acide", "color": Color("#9ac83a"), "desc": "Poche à venin d’un cracheur. Sans usage pour le moment."},
	"volt_organ": {"name": "Organe voltaïque", "color": Color("#6a9aff"), "desc": "Arraché à une anguille des puits, encore chargé. Sans usage pour le moment (prévu pour le piège à arc)."},
	"guano": {"name": "Guano", "color": Color("#c8c2ac"), "desc": "Fiente de chauve-souris patinée. Sans usage pour le moment."},
	"ration": {"name": "Ration", "color": Color("#c8a676"), "desc": "Pain de route d’un soldat de Laetan. Sans usage pour le moment."},
}

## Par type d'ennemi : tirages indépendants. « item » ou « pick » (un au hasard), « chance », « n » (quantité, ou [min, max]).
## Chiffres proposés, à régler. Brute : une pièce commune une fois sur quatre ; Strazhar : toujours une pièce peu
## commune, une rare une fois sur dix (retours du 2026-11-20 : pas d'insignes).
const TABLE := {
	"creep": [{"item": "ichor", "chance": 0.15}],
	"beast": [{"item": "ichor", "chance": 0.15}],
	"spitter": [{"item": "acid_gland", "chance": 0.25}],
	"scout": [{"item": "ration", "chance": 0.2}],
	"soldier": [{"item": "ration", "chance": 0.2}],
	"archer": [{"item": "arrows", "chance": 0.3, "n": 5}],
	"shield": [{"item": "ration", "chance": 0.2}, {"item": "copper_shield", "chance": 0.08}],
	"brute": [{"pick": ["gear_gloves", "gear_boots", "gear_hood"], "chance": 0.25}],
	# Biome 2 : la tique rend toujours le cuivre qu'elle a mangé (2 à 4), la chauve-souris parfois du guano.
	"tick": [{"item": "copper", "chance": 1.0, "n": [2, 4]}],
	"bat": [{"item": "guano", "chance": 0.2}],
	"eel": [{"item": "volt_organ", "chance": 0.4}],
	# Plus de fer dans le Temple (2026-11-20) : le champion porte du cuivre, mais ses pièces sont les seules
	# peu communes et rares du biome.
	"strazhar": [{"item": "copper_greatsword", "chance": 1.0}, {"item": "copper_armor", "chance": 0.1}],
	# Boss du Temple : leur module d'exo, toujours.
	"martyre": [{"item": "module_veil", "chance": 1.0}],
	"oeil": [{"item": "module_iris", "chance": 1.0}],
	"gorge": [{"item": "module_drill", "chance": 1.0}, {"item": "copper", "chance": 1.0, "n": [8, 12]}],
}


static func lifetime() -> float:
	return CORPSE_DAYS * DayNight.LENGTH


static func rarity_of(item: String) -> String:
	return String(Gear.ITEMS.get(item, ITEMS.get(item, {})).get("rarity", "normal"))


static func rarity_name(item: String) -> String:
	return RARITY[rarity_of(item)]["name"]


static func rarity_color(item: String) -> Color:
	return RARITY[rarity_of(item)]["color"]


## Rareté la plus haute d'un lot d'objets (trait de lumière au-dessus d'un corps).
static func best_rarity(items: Array) -> String:
	var best := 0
	for item: String in items:
		best = maxi(best, RARITY_ORDER.find(rarity_of(item)))
	return RARITY_ORDER[best]


## Nom du porteur (demande du 2026-11-20) : chaque arme ou armure prise à un ennemi garde le nom de celui qui la
## portait, tiré à sa mort dans la liste de son espèce : puniques pour la garde de Byrsa, sobriquets pour les
## brutes, slaves pour les Strazhars. Il s'affiche sous le titre de l'objet et le suit partout.
const NAMES := {
	"garde": [["Hannon", "Bomilcar", "Maharbal", "Himilcon", "Adherbal", "Giscon", "Magon", "Carthalon", "Bodashtart", "Abdmelqart", "Élissa", "Sophonisbe"],
		["de la Porte Basse", "de la Troisième Cohorte", "fils de Giscon", "du Quartier des Teinturiers", "le Jeune", "des Remparts", "de la Garde de l’Aube"]],
	"brute": [["Gorm", "Brakka", "Thurn", "Oddo", "Varg", "Hulda", "Drogo"],
		["le Fendeur", "Dos-de-Mur", "Trois-Dents", "la Masse", "Brise-Porte", "le Sourd"]],
	"strazhar": [["Dragomir", "Radovan", "Vuk", "Borislav", "Zoran", "Milorad", "Stanimir"],
		["Gardien du Seuil", "le Veilleur", "de la Garde Noire", "Croc-de-Fer", "l’Insomniaque"]],
}
const NAME_FAMILY := {"brute": "brute", "strazhar": "strazhar"}


static func bearer_name(kind: String, r: RandomNumberGenerator) -> String:
	var lists: Array = NAMES[NAME_FAMILY.get(kind, "garde")]
	return "%s %s" % [lists[0][r.randi() % (lists[0] as Array).size()], lists[1][r.randi() % (lists[1] as Array).size()]]


## Porteur à inscrire sur `item` pris sur le corps `e` : seulement les armes et armures.
static func owner_of(e: Enemy, item: String) -> String:
	return e.bearer if Gear.is_gear(item) and Gear.slot_of(item) != Gear.MODULE else ""


## Tire les lignes d'une table (TABLE, CACHES) : liste d'objets.
static func roll_rows(rows: Array, r: RandomNumberGenerator) -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in rows:
		if r.randf() >= float(row["chance"]):
			continue
		var item: String = row["item"] if row.has("item") else row["pick"][r.randi() % (row["pick"] as Array).size()]
		var count: Variant = row.get("n", 1)
		if count is Array:
			count = r.randi_range(int(count[0]), int(count[1]))
		for i in int(count):
			out.append(item)
	return out


## Tire le butin d'un ennemi qui vient de tomber.
static func roll(e: Enemy) -> void:
	var rows: Array = TABLE.get(e.kind, [])
	if rows.is_empty():
		return
	var r := RandomNumberGenerator.new()
	r.seed = hash([e.kind, snappedf(e.x, 0.01), snappedf(e.z, 0.01), snappedf(GameState.sim_time, 0.001), GameState.menace])
	for item in roll_rows(rows, r):
		e.loot.append(item)
		if Gear.is_gear(item) and Gear.slot_of(item) != Gear.MODULE and e.bearer == "":
			e.bearer = bearer_name(e.kind, r)


## Caches de la jungle (2026-11-20) : épaves de chariots, caisse du poste abandonné et dépôts du Credo au
## bout des ponts écartés (RoadProps, clé « cache »). L'Exilé à pied les fouille en marchant dessus, comme
## un corps ; une cache vidée reste du décor. Chiffres proposés, à régler : les ponts lointains paient mieux.
const CACHES := {
	"cart": [{"item": "ration", "chance": 1.0, "n": [1, 2]}, {"item": "arrows", "chance": 0.6, "n": 5}, {"item": "copper", "chance": 0.5, "n": [2, 4]}],
	"outpost": [{"item": "ration", "chance": 1.0, "n": 2}, {"item": "arrows", "chance": 1.0, "n": 5},
		{"pick": ["gear_gloves", "gear_boots", "gear_hood"], "chance": 1.0}],
	"bridge": [{"item": "copper", "chance": 1.0, "n": [6, 10]}, {"pick": ["gear_gloves", "gear_boots", "gear_hood"], "chance": 0.6},
		{"item": "copper_shield", "chance": 0.25}],
}


## Caches d'une partie (fonction de la graine) : {x, z, kind, loot}.
static func place_caches(road: Road, map_seed: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if road == null:
		return out
	var n := 0
	for p: Dictionary in RoadProps.place(road, map_seed):
		if not p.has("cache"):
			continue
		var r := RandomNumberGenerator.new()
		r.seed = hash([map_seed, n, "cache"])
		n += 1
		var loot := roll_rows(CACHES[p["cache"]], r)
		if not loot.is_empty():
			out.append({"x": float(p["x"]), "z": float(p["z"]), "kind": String(p["cache"]), "loot": loot})
	return out


## Durée pendant laquelle ce corps reste au sol.
static func corpse_life(e: Enemy) -> float:
	return EnemyArt.CORPSE_LIFETIME if e.loot.is_empty() else lifetime()


## Retire les corps arrivés à terme, puis les plus anciens au-delà des plafonds (les vides d'abord).
static func prune() -> void:
	var now := GameState.sim_time
	var kept: Array[Enemy] = []
	var empty := 0
	var full := 0
	for e: Enemy in GameState.enemy_corpses:
		if now - e.died_at < corpse_life(e):
			kept.append(e)
			if e.loot.is_empty():
				empty += 1
			else:
				full += 1
	if empty > EnemyArt.MAX_CORPSES or full > MAX_LOOT_CORPSES:
		var out: Array[Enemy] = []
		for e: Enemy in kept:
			if e.loot.is_empty() and empty > EnemyArt.MAX_CORPSES:
				empty -= 1
			elif not e.loot.is_empty() and full > MAX_LOOT_CORPSES:
				full -= 1
			else:
				out.append(e)
		kept = out
	GameState.enemy_corpses = kept


static func any_lootable() -> bool:
	for e: Enemy in GameState.enemy_corpses:
		if not e.loot.is_empty():
			return true
	return false


## Prend jusqu'à `room` objets sur le corps : [{item, owner}]. Vidé, le corps s'efface en EMPTY_FADE s.
static func take(e: Enemy, room: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	while room > 0 and not e.loot.is_empty():
		var item: String = e.loot.pop_front()
		out.append({"item": item, "owner": owner_of(e, item)})
		room -= 1
	if e.loot.is_empty() and not out.is_empty():
		e.died_at = minf(e.died_at, GameState.sim_time - (EnemyArt.CORPSE_LIFETIME - EMPTY_FADE))
	return out


## Usage des butins courants (planches/biomes-2-3-4-propositions.html).
## Ration : l'Exilé à pied en mange une dès qu'il lui manque RATION_HEAL PV, au plus une toutes les RATION_GAP s.
const RATION_HEAL := 20.0
const RATION_GAP := 6.0
## Voile de la Martyre : délai avant qu'il se reforme (s).
const VEIL_TIME := 20.0


static func eat(u: Unit) -> void:
	if u.hidden or not ItemStorage.character_available(u) or u.hp > u.max_hp - RATION_HEAL \
			or GameState.sim_time - u.ate_at < RATION_GAP:
		return
	for i in u.inventory.size():
		var stack := u.inventory[i]
		if stack.is_empty() or stack["item"] != "ration":
			continue
		stack["quantity"] -= 1
		if stack["quantity"] <= 0:
			u.inventory[i] = {}
		u.hp = minf(u.max_hp, u.hp + RATION_HEAL)
		u.healed_at = GameState.sim_time
		u.ate_at = GameState.sim_time
		Sfx.at("soin", u.x, u.z)
		return


## Guano (engrais) : un bosquet abattu repousse tout de suite, pour un guano pris au stock. Vrai si un bosquet a repoussé.
static func fertilize(sim: Simulation) -> bool:
	var st := sim.state()
	if st == null or st.felled_groves.is_empty() or ItemStorage.count("guano") <= 0:
		return false
	var before := st.wood_left.size()
	var saved: Dictionary = st.felled_groves.duplicate()
	# Un seul bosquet par guano : le plus ancien.
	var oldest: Vector2i = saved.keys()[0]
	for o: Vector2i in saved:
		if int(saved[o]) < int(saved[oldest]):
			oldest = o
	st.felled_groves = {oldest: -1000}
	sim.regrow_groves()
	var grown := st.wood_left.size() > before
	saved.erase(oldest)
	if not grown:
		saved[oldest] = st.felled_groves.get(oldest, 0) if st.felled_groves.has(oldest) else 0
		saved[oldest] = int(saved[oldest]) if int(saved[oldest]) > -1000 else GameState.wave
	st.felled_groves = saved
	if grown:
		ItemStorage.take({"guano": 1})
	return grown


## Voile de la Martyre : vrai si le coup est absorbé (le voile se reformera dans VEIL_TIME s).
static func veil_absorbs(u: Unit) -> bool:
	if u.is_enemy() or GameState.sim_time < u.veil_ready_at or not Gear.has_module(u, "veil"):
		return false
	u.veil_ready_at = GameState.sim_time + VEIL_TIME
	u.veil_hit_at = GameState.sim_time
	return true


## Vrai si un Exilé vivant porte l'Iris de la Matrice (ennemis visibles sur la minicarte à travers la roche).
static func iris_worn() -> bool:
	for u: Unit in GameState.units:
		if u.alive() and Gear.has_module(u, "iris"):
			return true
	return false


const CACHE_REACH := 1.2


## L'Exilé à pied fouille les corps sur lesquels il marche (même condition que le ramassage au sol).
static func collect(u: Unit) -> void:
	if u.hidden or not ItemStorage.character_available(u):
		return
	var p := u.pos()
	var r2 := ItemStorage.PICKUP_RADIUS * ItemStorage.PICKUP_RADIUS
	for e: Enemy in GameState.enemy_corpses:
		if e.loot.is_empty() or p.distance_squared_to(e.pos()) > r2:
			continue
		var got := 0
		while not e.loot.is_empty() and ItemStorage.store(u.inventory, u.inventory_capacity, e.loot[0], owner_of(e, e.loot[0])):
			e.loot.pop_front()
			got += 1
		if got > 0:
			Sfx.at("coffre", e.x, e.z)
		if e.loot.is_empty():
			e.died_at = minf(e.died_at, GameState.sim_time - (EnemyArt.CORPSE_LIFETIME - EMPTY_FADE))
	# Caches de la jungle : même geste, rayon un peu plus large (on ne marche pas sur un chariot).
	var cr2 := (ItemStorage.PICKUP_RADIUS + CACHE_REACH) * (ItemStorage.PICKUP_RADIUS + CACHE_REACH)
	for c: Dictionary in GameState.caches:
		var loot: Array = c["loot"]
		if loot.is_empty() or p.distance_squared_to(Vector2(c["x"], c["z"])) > cr2:
			continue
		var got := 0
		while not loot.is_empty() and ItemStorage.store(u.inventory, u.inventory_capacity, loot[0], ""):
			loot.pop_front()
			got += 1
		if got > 0:
			Sfx.at("coffre", c["x"], c["z"])
