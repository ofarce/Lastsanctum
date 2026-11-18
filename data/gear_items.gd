extends RefCounted
## Pièces d'équipement de l'Ingénieur sans armure (tenue « Le Tyrien ») : nom, emplacement de la fiche
## d'inventaire et calque dessiné (TyrienArt). Les pièces « gear_* » n'ont que leur apparence ; celles du
## Creuset des Exilés (data/recipes.gd) portent des statistiques : armor (défense), damage (dégâts de base),
## reach (portée, arme à distance), two_hands (occupe aussi la main gauche), ammo (munition prise dans le stock
## à chaque tir), melee (portée de la taille, en unités de monde : 4 par bloc), cd (recharge en secondes), anim (animation
## d'attaque du Tyrien : slash1, slash2, shoot).

const RIGHT := "Main droite"
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
	"copper_armor": {"name": "Armure en cuivre", "slot": "Torse", "piece": "copperarmor", "armor": 3, "desc": "Défense faible."},
	"iron_armor": {"name": "Armure en fer", "slot": "Torse", "piece": "ironarmor", "armor": 6, "desc": "Défense moyenne."},
	"iron_greatsword": {"name": "Épée à deux mains en fer", "slot": "Main droite", "piece": "irongreat", "melee": 6.0, "cd": 0.89, "anim": "slash2", "damage": 18, "two_hands": true,
		"desc": "Occupe les deux mains, dégâts élevés. Taille à 1,5 bloc."},
	"iron_sword": {"name": "Épée à une main en fer", "slot": "Main droite", "piece": "ironsword", "melee": 6.0, "cd": 0.67, "anim": "slash1", "damage": 10,
		"desc": "Occupe une seule main, dégâts moyens. Taille à 1,5 bloc."},
	"iron_shield": {"name": "Bouclier en fer", "slot": "Main gauche", "piece": "ironshield", "armor": 2,
		"desc": "Occupe une seule main, défense faible."},
	"copper_greatsword": {"name": "Épée à deux mains en cuivre", "slot": "Main droite", "piece": "coppergreat", "melee": 6.0, "cd": 0.89, "anim": "slash2", "damage": 14, "two_hands": true,
		"desc": "Occupe les deux mains, dégâts élevés. Taille à 1,5 bloc."},
	"copper_sword": {"name": "Épée à une main en cuivre", "slot": "Main droite", "piece": "coppersword", "melee": 6.0, "cd": 0.67, "anim": "slash1", "damage": 7,
		"desc": "Occupe une seule main, dégâts faibles. Taille à 1,5 bloc."},
	"copper_shield": {"name": "Bouclier en cuivre", "slot": "Main gauche", "piece": "coppershield", "armor": 1,
		"desc": "Occupe une seule main, défense très faible."},
	"cannon": {"name": "Canon à projection", "slot": "Main droite", "piece": "cannon", "damage": 12, "reach": 12.0, "cd": 0.5, "anim": "shoot", "ammo": "iron",
		"desc": "Tire 2 balles de fer par seconde, qui filent jusqu’au premier obstacle. Dégâts 12."},
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
		if ITEMS.has(item):
			out[slot] = ITEMS[item]["piece"]
	return out


## Équipe la pile `from` de `source` dans l'emplacement `slot` de `u`. L'objet déjà porté revient dans la case vidée
## (ou dans une case libre). Refuse un objet qui ne va pas dans cet emplacement.
static func equip(u: Unit, source: Array[Dictionary], from: int, slot: String) -> bool:
	if u == null or from < 0 or from >= source.size() or source[from].is_empty():
		return false
	var item: String = source[from]["item"]
	if slot_of(item) != slot:
		return false
	# Une arme à deux mains libère la main gauche ; on ne tient rien de la main gauche avec elle.
	if slot == LEFT and two_handed(u):
		return false
	if slot == RIGHT and ITEMS[item].get("two_hands", false) and u.equipment.has(LEFT):
		if not _store(source, u.equipment[LEFT]):
			return false
		u.equipment.erase(LEFT)
	var previous: String = u.equipment.get(slot, "")
	source[from]["quantity"] -= 1
	if source[from]["quantity"] <= 0:
		source[from] = {}
	u.equipment[slot] = item
	if previous != "":
		if source[from].is_empty():
			source[from] = {"item": previous, "quantity": 1}
		else:
			_store(source, previous)
	return true


## Retire l'objet porté dans `slot` vers la case `to` de `target` (vide ou même objet), ou vers une case libre si to < 0.
static func unequip(u: Unit, slot: String, target: Array[Dictionary], to: int, capacity: int) -> bool:
	var item: String = u.equipment.get(slot, "")
	if item == "":
		return false
	if to >= 0:
		if to >= capacity:
			return false
		while target.size() <= to:
			target.append({})
		if target[to].is_empty():
			target[to] = {"item": item, "quantity": 1}
		elif target[to]["item"] == item:
			target[to]["quantity"] += 1
		else:
			return false
	elif not _store(target, item, capacity):
		return false
	u.equipment.erase(slot)
	return true


static func _store(items: Array[Dictionary], item: String, capacity: int = 1 << 30) -> bool:
	for i in items.size():
		if items[i].is_empty():
			items[i] = {"item": item, "quantity": 1}
			return true
	if items.size() < capacity:
		items.append({"item": item, "quantity": 1})
		return true
	return false
