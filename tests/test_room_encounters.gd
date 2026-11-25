extends "res://tests/test_case.gd"
## Rencontres de salle (sim/rooms.gd) : une par salle de combat sans pylône du Temple, composition du bon niveau,
## palier de plus dans C, chemins protégés, salle nettoyée puis repeuplée au bout de 3 nuits (2 dans C).

static var _st: TerrainState


func _state() -> TerrainState:
	if _st == null:
		_st = TerrainState.new()
		_st.generate_galleries(20261114)
	return _st


func test_one_encounter_per_combat_room() -> void:
	var st := _state()
	var dens := RoomEncounters.dens(st)
	# Tous les plans en salles (Temple, puis Veines de vert-de-gris depuis le 2026-11-24).
	var rooms: Array = []
	for lay: Dictionary in st.room_layouts():
		rooms.append_array(lay["rooms"])
	# Depuis le 2026-11-22 : combats sans pylône, salles de ressources (gardées) et secrètes ont leur rencontre.
	var guarded := rooms.filter(func(r: Dictionary) -> bool: return RoomEncounters.encounter_tier(r) != "")
	check_eq(dens.size(), guarded.size(), "une rencontre par salle gardée")
	check(dens.size() > rooms.filter(func(r: Dictionary) -> bool: return r["kind"] == "combat" and not r["pylon"]).size(), "plus que les seuls combats")
	for d in dens:
		var room: Dictionary = st.room_by_id(d["room"])
		var biome := int(room.get("biome", 0))
		check_eq(st.temple_room(d["x"], d["z"]).get("id", -1), d["room"], "salle %d : tanière au centre" % d["room"])
		check_eq(d["tier"], RoomEncounters.encounter_tier(room), "niveau de la salle")
		check(_doubled(d["tier"], d["kinds"], biome), "composition du niveau %s, levée deux fois" % d["tier"])
		var bonus: Dictionary = st.room_layouts()[biome]["threat_bonus"]
		var expected := int(Biomes.LIST[biome]["threat"]) + int(bonus.get(room["quarter"], 0))
		check_eq(d["threat"], expected, "menace de la salle %d (%s)" % [d["room"], room["quarter"]])


func test_no_plain_dens_in_the_temple() -> void:
	var st := _state()
	var fz := TerrainState.frontier_z() + TerrainState.FRONTIER_HALF
	var plain := Roamers.dens(st, st.seed).filter(func(d: Dictionary) -> bool: return d["z"] > fz)
	check_eq(plain.size(), 0, "plus d'errants ordinaires au Temple : les salles ont leurs rencontres")


func test_draw_is_deterministic_and_varies() -> void:
	var a := RoomEncounters.draw(7, 3, 0, "M")
	check_eq(a, RoomEncounters.draw(7, 3, 0, "M"), "même tirage")
	var seen := {}
	for repop in 12:
		seen[str(RoomEncounters.draw(7, 3, repop, "M"))] = true
	check(seen.size() > 1, "les repeuplements changent la composition")


func test_protected_paths() -> void:
	var st := _state()
	var rooms: Array = st.temple_layout["rooms"]
	var prot := RoomEncounters.protected_rooms(st)
	for r: Dictionary in rooms:
		if r["kind"] == "resource":
			check(prot.has(r["id"]), "salle de ressources %d protégée" % r["id"])
		if r["kind"] == "secret":
			check(not prot.has(r["id"]), "salle secrète %d hors chemin" % r["id"])
	check(prot.keys().any(func(id: int) -> bool: return rooms[id]["portal"]), "chaque chemin finit à un portail")
	# Un pylône canalisé devient un portail : l'ensemble protégé peut changer, jamais au détriment des ressources.
	for p: Dictionary in st.portals:
		if not st.temple_room(p["x"], p["z"]).is_empty():
			p["channeled"] = true
	var with_pylons := RoomEncounters.protected_rooms(st)
	for r: Dictionary in rooms:
		if r["kind"] == "resource":
			check(with_pylons.has(r["id"]), "ressource %d toujours protégée" % r["id"])
	for p: Dictionary in st.portals:
		p["channeled"] = false


func test_cleared_room_repopulates_after_nights() -> void:
	var st := _state()
	var prot := RoomEncounters.protected_rooms(st)
	var dens := RoomEncounters.dens(st)
	var free := dens.filter(func(d: Dictionary) -> bool: return not prot.has(d["room"]))
	check(not free.is_empty(), "au moins une salle hors chemin protégé")
	for d: Dictionary in free:
		var nights := RoomEncounters.REPOP_NIGHTS_C if d["quarter"] == "C" else RoomEncounters.REPOP_NIGHTS
		d["members"] = []
		check(not RoomEncounters.after_clear(st, d, 10), "nettoyée le jour 10")
		check_eq(d["cleared_day"], 10, "jour du nettoyage noté")
		check(not RoomEncounters.after_clear(st, d, 10 + nights - 1), "pas encore repeuplée")
		check(RoomEncounters.after_clear(st, d, 10 + nights), "repeuplée après %d nuits" % nights)
		check(not d.has("members") and not d.has("cleared_day"), "redevenue dormante")
		check_eq(d["repop"], 1, "un repeuplement")
		check(_doubled(d["tier"], d["kinds"], int(d.get("biome", 0))), "nouveau tirage du même niveau")
	var guarded := dens.filter(func(d: Dictionary) -> bool: return prot.has(d["room"]))
	for d: Dictionary in guarded:
		d["members"] = []
		RoomEncounters.after_clear(st, d, 0)
		check(not RoomEncounters.after_clear(st, d, 99), "salle %d sur un chemin protégé : jamais repeuplée" % d["room"])


## Composition de COMPOSITIONS[tier] levée deux fois (RoomEncounters.draw, 2026-11-22).
static func _doubled(tier: String, kinds: Array, biome := 0) -> bool:
	for one: Array in (RoomEncounters.COMPOSITIONS_VEINES if biome == 1 else RoomEncounters.COMPOSITIONS)[tier]:
		if one + one == kinds:
			return true
	return false
