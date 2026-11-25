extends RefCounted
## Pièces d'équipement de l'Ingénieur sans armure (tenue « Le Tyrien ») : nom, emplacement de la fiche
## d'inventaire et calque dessiné (TyrienArt). Les pièces « gear_* » n'ont que leur apparence ; celles du
## Creuset des Exilés (data/recipes.gd) portent des statistiques : armor (défense), damage (dégâts de base),
## reach (portée, arme à distance), two_hands (occupe aussi la main gauche), ammo (munition prise dans le stock
## à chaque tir), melee (portée de la taille, en unités de monde : 4 par bloc), cd (recharge en secondes), anim (animation
## d'attaque du Tyrien : slash1, slash2, shoot). rarity (sim/loot.gd, « normal » par défaut) : les pièces de fer
## sont peu communes, l'armure de fer rare ; de même l'épée à deux mains et l'armure de cuivre (butin du Strazhar).

const ItemStorage := preload("res://sim/item_storage.gd")

const RIGHT := "Main droite"
## Emplacements de module de la fiche d'inventaire : tout objet d'emplacement « Module » va dans n'importe lequel.
## L'Exilé (rôle « engineer ») n'équipe plus que des mods (2026-11-21) : l'Arbalestrie et la Combinaison lui sont
## remises d'office par la capsule (sim/capsule.gd) et n'ont pas de case ; épées, armures et boucliers restent pour les adeptes.
const MODULE := "Module"
## Cases du paquetage de l'Exilé ; le Sac sans fond (mod « sack ») en ajoute autant.
const PACK := 10
const MODULE_SLOTS: Array[String] = ["Module 1", "Module 2", "Module 3", "Module 4", "Module 5", "Module 6"]
const LEFT := "Main gauche"

const ITEMS := {
	"gear_helm": {"name": "Casque de fer", "slot": "Tête", "piece": "helm"},
	"gear_hood": {"name": "Capuche de toile", "slot": "Tête", "piece": "hood"},
	"gear_circlet": {"name": "Bandeau tyrien", "slot": "Tête", "piece": "circlet"},
	"gear_lens": {"name": "Monocle-capteur", "slot": "Capteur oculaire", "piece": "lens"},
	"gear_iron": {"name": "Plastron de fer", "slot": "Torse", "piece": "iron"},
	"gear_mail": {"name": "Cotte de mailles", "slot": "Torse", "piece": "mail"},
	"gear_leather": {"name": "Cuirasse de cuir", "slot": "Torse", "piece": "leather"},
	"gear_gauntlets": {"name": "Gantelets de fer", "slot": "Gants", "piece": "gauntlets"},
	"gear_gloves": {"name": "Gants de cuir", "slot": "Gants", "piece": "gloves"},
	"gear_greaves": {"name": "Grèves de fer", "slot": "Bottes", "piece": "greaves"},
	"gear_boots": {"name": "Bottes de cuir", "slot": "Bottes", "piece": "boots"},
	"gear_cape": {"name": "Cape", "slot": "Dos", "piece": "cape"},
	"gear_pack": {"name": "Sac de toile", "slot": "Dos", "piece": "pack"},
	"gear_hammer": {"name": "Marteau de forge", "slot": "Main droite", "piece": "hammer"},
	"gear_blade": {"name": "Lame courte", "slot": "Main droite", "piece": "blade"},
	"gear_shield": {"name": "Bouclier rond", "slot": "Main gauche", "piece": "shield"},
	"gear_lantern": {"name": "Lanterne à quartz", "slot": "Main gauche", "piece": "lantern"},
	# Creuset des Exilés.
	"copper_armor": {"rarity": "rare", "name": "Armure en cuivre", "slot": "Torse", "piece": "copperarmor", "armor": 3, "desc": "Défense faible."},
	"iron_armor": {"rarity": "rare", "name": "Armure en fer", "slot": "Torse", "piece": "ironarmor", "armor": 6, "desc": "Défense moyenne."},
	"iron_greatsword": {"rarity": "uncommon", "name": "Épée à deux mains en fer", "slot": "Main droite", "piece": "irongreat", "melee": 6.0, "cd": 0.89, "anim": "slash2", "damage": 18, "two_hands": true,
		"desc": "Occupe les deux mains, dégâts élevés. Taille à 1,5 bloc."},
	"iron_sword": {"rarity": "uncommon", "name": "Épée à une main en fer", "slot": "Main droite", "piece": "ironsword", "melee": 6.0, "cd": 0.67, "anim": "slash1", "damage": 10,
		"desc": "Occupe une seule main, dégâts moyens. Taille à 1,5 bloc."},
	"iron_shield": {"rarity": "uncommon", "name": "Bouclier en fer", "slot": "Main gauche", "piece": "ironshield", "armor": 2,
		"desc": "Occupe une seule main, défense faible."},
	"copper_greatsword": {"rarity": "uncommon", "name": "Épée à deux mains en cuivre", "slot": "Main droite", "piece": "coppergreat", "melee": 6.0, "cd": 0.89, "anim": "slash2", "damage": 14, "two_hands": true,
		"desc": "Occupe les deux mains, dégâts élevés. Taille à 1,5 bloc."},
	"copper_sword": {"name": "Épée à une main en cuivre", "slot": "Main droite", "piece": "coppersword", "melee": 6.0, "cd": 0.67, "anim": "slash1", "damage": 7,
		"desc": "Occupe une seule main, dégâts faibles. Taille à 1,5 bloc."},
	"copper_shield": {"name": "Bouclier en cuivre", "slot": "Main gauche", "piece": "coppershield", "armor": 1,
		"desc": "Occupe une seule main, défense très faible."},
	"cannon": {"name": "Arbalestrie", "slot": "Main droite", "piece": "cannon", "damage": 12, "reach": 12.0, "cd": 0.25, "anim": "shoot", "mana": 0.5,
		"desc": "Balles spirituelles : 6 par seconde, sans coût en mana ; elles filent jusqu’au premier obstacle. Dégâts 12."},
	# Mods (modules d'exo) : fabriqués à l'Établi d'exo d'après leur plan (lâché par boss, ennemis et caches : data/
	# recipes.gd PLANS, sim/loot.gd), seuls objets que l'Exilé équipe (6 cases MODULE_SLOTS). Chacun est
	# dessiné sur l'Ingénieur (entities/unit/veil_fx.gd, iris_fx.gd, mining_seal_fx.gd) ; effet dans le champ « module »
	# (sim/loot.gd, Combat.damage, Minimap). Icône : ui/inventory/item_icon.gd (MOD_ORDER). Infobulle (ui/inventory/
	# item_tooltip.gd) : family, stats (lignes chiffrées), worn (ce qu'on voit porté), from (boss d'origine).
	# Raretés choisies le 2026-11-21 (planches/mods-icones-propositions.html).
	"module_veil": {"name": "Voile de la Martyre", "slot": "Module", "rarity": "uncommon", "module": "veil",
		"family": "Défense", "from": "plan : la Martyre · Établi d’exo", "stats": [["Absorbe", "1 coup entier"], ["Recharge", "20 s"]],
		"worn": "un pendentif d’améthyste qui rayonne et un liseré violet autour de la silhouette ; il éclate quand le coup est absorbé.",
		"desc": "Module d’exo. Un voile absorbe entièrement un coup, puis se reforme en 20 s."},
	"module_drill": {"name": "Foreuse de Gorge-Cuivre", "slot": "Module", "rarity": "unique", "module": "drill",
		"family": "Exploration", "from": "plan : Gorge-Cuivre · Établi d’exo", "stats": [["Vitesse de minage", "×2"], ["Billes du Sceau", "3 → 5"]],
		"worn": "les cinq billes cuivre et argent du Sceau, qui se mettent en mèche quand il creuse.",
		"desc": "Module d’exo. L’Exilé creuse la roche deux fois plus vite."},
	"module_iris": {"name": "Iris de la Matrice", "slot": "Module", "rarity": "rare", "module": "iris",
		"family": "Exploration", "from": "plan : dépôts des ponts · Établi d’exo", "stats": [["Révèle", "ennemis derrière la roche"], ["Ping", "2 s minimum"]],
		"worn": "un orbe à pupille carmin au-dessus de l’épaule ; il lance des arcs de sonar vers chaque ennemi repéré.",
		"desc": "Module d’exo. Les ennemis apparaissent sur la minicarte à travers la roche."},
	# Les douze mods du 2026-11-21 (règles : sim/mods.gd ; butin : sim/loot.gd, TABLE et CACHES).
	"module_scale": {"name": "Écaille d’esquive", "slot": "Module", "rarity": "rare", "module": "scale",
		"family": "Attaque", "from": "plan : brutes, Strazhar · Établi d’exo", "stats": [["Frôlement", "tir passé à 0,6 de la touche"], ["Coup suivant", "+50 % de dégâts"]],
		"worn": "une écaille d’acier sur l’épaule avant ; elle s’allume en cyan quand elle est chargée.",
		"desc": "Module d’exo. Après un tir ennemi frôlé de justesse, la prochaine attaque fait +50 % de dégâts."},
	"module_ember": {"name": "Cœur de braise", "slot": "Module", "rarity": "epic", "module": "ember",
		"family": "Attaque", "from": "plan : brutes, Strazhar · Établi d’exo", "stats": [["Seuil", "30 % des PV"], ["Cadence", "+25 % pendant 6 s"], ["Recharge", "60 s"]],
		"worn": "un cœur de braise incrusté dans la poitrine ; il flambe quand l’effet se déclenche.",
		"desc": "Module d’exo. Sous 30 % de PV, cadence +25 % pendant 6 s (une fois par minute)."},
	"module_magnet": {"name": "Aimant d’ichor", "slot": "Module", "rarity": "uncommon", "module": "magnet",
		"family": "Défense", "from": "plan : brutes, chariots, l’Œil de la Matrice · Établi d’exo", "stats": [["Soin par ennemi abattu", "3 % des PV max"]],
		"worn": "un aimant en fer à cheval à la ceinture ; une goutte d’ichor file vers lui à chaque ennemi abattu.",
		"desc": "Module d’exo. Chaque ennemi abattu par l’Exilé lui rend 3 % de ses PV max."},
	"module_lens": {"name": "Lentille de souffle", "slot": "Module", "rarity": "rare", "module": "lens",
		"family": "Tir", "from": "plan : Strazhar, dépôts des ponts · Établi d’exo", "stats": [["Perforation", "+1 ennemi"]],
		"worn": "une lentille de verre vert d’eau vissée à la bouche de l’Arbalestrie.",
		"desc": "Module d’exo. Les balles de l’Arbalestrie traversent un ennemi de plus."},
	"module_frost": {"name": "Culasse froide", "slot": "Module", "rarity": "uncommon", "module": "frost",
		"family": "Tir", "from": "plan : dépôts des ponts, chariots · Établi d’exo", "stats": [["Recharge", "−30 %"], ["Durée", "3 s après un changement de munition"]],
		"worn": "la culasse de l’Arbalestrie couverte de givre ; petite fumée froide au changement de munition.",
		"desc": "Module d’exo. La recharge est 30 % plus courte pendant 3 s après un changement de munition."},
	"module_seal": {"name": "Sceau sensible", "slot": "Module", "rarity": "uncommon", "module": "seal",
		"family": "Exploration", "from": "plan : poste abandonné, chariots · Établi d’exo", "stats": [["Portée", "12 cases"], ["Filons", "cuivre, fer, quartz, or"]],
		"worn": "un prisme d’argent au centre de l’orbite du Sceau, qui pulse vers le filon le plus proche.",
		"desc": "Module d’exo. Les filons de minerai à moins de 12 cases brillent à travers la roche."},
	"module_wisp": {"name": "Lanterne de Medeina", "slot": "Module", "rarity": "rare", "module": "wisp",
		"family": "Exploration", "from": "plan : poste abandonné · Établi d’exo", "stats": [["Vision", "+3 cases (5 → 8)"]],
		"worn": "le feu follet vert de Medeina, qui flotte derrière la tête et laisse une traîne.",
		"desc": "Module d’exo. Un feu follet suit l’Exilé et repousse le brouillard plus loin autour de lui."},
	"module_anchor": {"name": "Ancre de rappel", "slot": "Module", "rarity": "epic", "module": "anchor",
		"family": "Mobilité", "from": "plan : dépôts des ponts · Établi d’exo", "stats": [["Rappel", "touche G, hors combat"], ["Recharge", "3 min"]],
		"worn": "une petite sphère enchaînée à la hanche, comme l’Ancre en réduction.",
		"desc": "Module d’exo. Un retour à la capsule toutes les 3 minutes, hors combat."},
	"module_chant": {"name": "Voix du Chantre", "slot": "Module", "rarity": "rare", "module": "chant",
		"family": "Colonie", "from": "plan : poste abandonné · Établi d’exo", "stats": [["Rayon", "8 cases"], ["Travail", "+20 % (chantiers, ateliers, minage)"]],
		"worn": "un diapason d’or dans le dos ; des ondes dorées passent sur les adeptes proches.",
		"desc": "Module d’exo. Les adeptes et les bâtiments à moins de 8 cases travaillent 20 % plus vite."},
	"module_sack": {"name": "Sac sans fond", "slot": "Module", "rarity": "epic", "module": "sack",
		"family": "Colonie", "from": "plan : poste abandonné · Établi d’exo", "stats": [["Paquetage", "+10 cases"], ["Fouille des corps", "3 fois plus loin"]],
		"worn": "un sac de toile à la ceinture, dont l’ouverture montre un tourbillon violet.",
		"desc": "Module d’exo. Le paquetage gagne une rangée ; le butin des corps se ramasse en passant."},
	"module_echo": {"name": "Écho du pylône", "slot": "Module", "rarity": "rare", "module": "echo",
		"family": "Défense", "from": "plan : dépôts des ponts · Établi d’exo", "stats": [["Préavis", "15 s"], ["Annonce", "assauts et meutes nocturnes"]],
		"worn": "un éclat de pylône en pendentif dorsal, qui bourdonne et luit avant une vague.",
		"desc": "Module d’exo. Les assauts et les meutes nocturnes s’annoncent 15 s avant leur départ."},
	# Premier mod fabriqué (2026-11-22, planches/intro-capsule-planche.html) : plan remis par le Coffre Antique, fabriqué
	# à l'Établi d'exo. Effet : barres de PV des ennemis à l'écran (entities/enemy/enemy_view.gd, Mods.analysis).
	"module_analyse": {"name": "Analyse", "slot": "Module", "rarity": "normal", "module": "analyse",
		"family": "Attaque", "from": "plan du Coffre Antique, Établi d’exo", "stats": [["Révèle", "PV des ennemis à l’écran"]],
		"worn": "une visière-lentille cyan devant l’œil, qui balaie les ennemis en vue.",
		"desc": "Module d’exo. Chaque ennemi visible à l’écran affiche sa barre de PV."},
	# Butin de la Martyre de la Patine (2026-11-25, planches/mini-boss-temple-veines-propositions.html, M1). Effet :
	# sim/mods.gd (patine_*), mines dessinées par world/miniboss2/patine_fx.gd.
	"module_patine": {"name": "Mines de patine", "slot": "Module", "rarity": "rare", "module": "patine",
		"family": "Tir", "from": "plan : la Martyre de la Patine · Établi d’exo", "stats": [["Tir manqué", "mine verte 3 s"], ["Éclat", "dégâts du tir, au contact d’un ennemi"]],
		"worn": "le canon de l’Arbalestrie qui verdit quand une mine éclate.",
		"desc": "Module d’exo. Un tir qui ne touche rien laisse une mine verte 3 s, qui éclate au contact d’un ennemi."},
	"combinaison": {"name": "Combinaison", "slot": "Torse", "piece": "combinaison", "armor": 1,
		"desc": "Combinaison d’Exilé remise par le Coffre Antique. Défense très faible."},
}


static func is_gear(item: String) -> bool:
	return ITEMS.has(item)


static func slot_of(item: String) -> String:
	return ITEMS.get(item, {}).get("slot", "")


static func name_of(item: String) -> String:
	return ITEMS.get(item, {}).get("name", item)


## Somme d'une statistique (armor…) sur les pièces portées par `u`.
static func total(u: Unit, stat: String) -> int:
	var n := 0
	if u == null:
		return n
	for slot: String in u.equipment:
		n += int(ITEMS.get(u.equipment[slot], {}).get(stat, 0))
	return n


## Vrai si `u` porte un module d'exo d'effet `effect` (« veil », « iris »…).
static func has_module(u: Unit, effect: String) -> bool:
	if u == null:
		return false
	for slot: String in MODULE_SLOTS:
		if String(ITEMS.get(u.equipment.get(slot, ""), {}).get("module", "")) == effect:
			return true
	return false


## Vrai si `u` n'équipe que des mods : l'Exilé, seul à avoir une fiche d'inventaire.
static func mods_only(u: Unit) -> bool:
	return u != null and u.role == "engineer"


## Arme de la main droite (dictionnaire de ITEMS), ou vide.
static func weapon(u: Unit) -> Dictionary:
	if u == null:
		return {}
	return ITEMS.get(u.equipment.get(RIGHT, ""), {})


static func two_handed(u: Unit) -> bool:
	return bool(weapon(u).get("two_hands", false))


## Emplacement → calque dessiné, pour les objets portés par `u`.
static func pieces(u: Unit) -> Dictionary:
	var out := {}
	for slot: String in u.equipment:
		var item: String = u.equipment[slot]
		if ITEMS.has(item) and ITEMS[item].has("piece"):
			out[slot] = ITEMS[item]["piece"]
	return out


## Équipe la pile `from` de `source` dans l'emplacement `slot` de `u`. L'objet déjà porté revient dans la case vidée
## (ou dans une case libre). Refuse un objet qui ne va pas dans cet emplacement.
static func equip(u: Unit, source: Array[Dictionary], from: int, slot: String) -> bool:
	if u == null or from < 0 or from >= source.size() or source[from].is_empty():
		return false
	var item: String = source[from]["item"]
	if slot_of(item) != slot and not (slot_of(item) == MODULE and MODULE_SLOTS.has(slot)):
		return false
	if mods_only(u) and not MODULE_SLOTS.has(slot):
		return false
	# Une arme à deux mains libère la main gauche ; on ne tient rien de la main gauche avec elle.
	if slot == LEFT and two_handed(u):
		return false
	if slot == RIGHT and ITEMS[item].get("two_hands", false) and u.equipment.has(LEFT):
		if not _store(source, u.equipment[LEFT], 1 << 30, String(u.equipment_owner.get(LEFT, ""))):
			return false
		u.equipment.erase(LEFT)
		u.equipment_owner.erase(LEFT)
	var previous: String = u.equipment.get(slot, "")
	var previous_owner := String(u.equipment_owner.get(slot, ""))
	if previous != "" and _sack_holds(u, previous):
		return false
	var owner := String(source[from].get("owner", ""))
	source[from]["quantity"] -= 1
	if source[from]["quantity"] <= 0:
		source[from] = {}
	u.equipment[slot] = item
	if owner == "":
		u.equipment_owner.erase(slot)
	else:
		u.equipment_owner[slot] = owner
	if previous != "":
		if source[from].is_empty():
			source[from] = ItemStorage.stack_of(previous, previous_owner)
		else:
			_store(source, previous, 1 << 30, previous_owner)
	sync_pack(u)
	return true


## Retire l'objet porté dans `slot` vers la case `to` de `target` (vide ou même objet), ou vers une case libre si to < 0.
static func unequip(u: Unit, slot: String, target: Array[Dictionary], to: int, capacity: int) -> bool:
	var item: String = u.equipment.get(slot, "")
	if item == "":
		return false
	var owner := String(u.equipment_owner.get(slot, ""))
	if _sack_holds(u, item):
		return false
	if String(ITEMS.get(item, {}).get("module", "")) == "sack" and target == u.inventory:
		capacity = mini(capacity, PACK)
	if to >= 0:
		if to >= capacity:
			return false
		while target.size() <= to:
			target.append({})
		if target[to].is_empty():
			target[to] = ItemStorage.stack_of(item, owner)
		elif ItemStorage.same_kind(target[to], item, owner):
			target[to]["quantity"] += 1
		else:
			return false
	elif not _store(target, item, capacity, owner):
		return false
	u.equipment.erase(slot)
	u.equipment_owner.erase(slot)
	sync_pack(u)
	return true


## Vrai si retirer `item` (le Sac sans fond) laisserait des objets dans la rangée qu'il ajoute.
static func _sack_holds(u: Unit, item: String) -> bool:
	if String(ITEMS.get(item, {}).get("module", "")) != "sack":
		return false
	for i in range(PACK, u.inventory.size()):
		if not u.inventory[i].is_empty():
			return true
	return false


## Taille du paquetage de l'Exilé selon le Sac sans fond.
static func sync_pack(u: Unit) -> void:
	if u != null and u.role == "engineer":
		u.inventory_capacity = PACK * (2 if has_module(u, "sack") else 1)


static func _store(items: Array[Dictionary], item: String, capacity: int = 1 << 30, owner := "") -> bool:
	for i in items.size():
		if items[i].is_empty():
			items[i] = ItemStorage.stack_of(item, owner)
			return true
	if items.size() < capacity:
		items.append(ItemStorage.stack_of(item, owner))
		return true
	return false
