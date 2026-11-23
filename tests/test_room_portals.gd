extends "res://tests/test_case.gd"
## Boucle de 30 minutes (planches/biomes-salles-structure.html) : portails fixes des salles dans le réseau de
## PortalNet, antichambre sûre (TerrainState.safe_at).

static var _st: TerrainState


func _state() -> TerrainState:
	if _st == null:
		_st = TerrainState.new()
		_st.generate_galleries(20261114)
		# Comme en jeu : toutes les galeries sont découvertes dès le départ.
		_st.open = _st.mask.duplicate()
		_st.found = 1
	return _st


func _room(role: String) -> Dictionary:
	for r: Dictionary in _state().temple_layout["rooms"]:
		if r["role"] == role:
			return r
	return {}


func test_portal_rooms_of_the_plan() -> void:
	var roles := (_state().temple_layout["rooms"] as Array).filter(func(r: Dictionary) -> bool: return r["portal"]).map(func(r: Dictionary) -> String: return r["role"])
	roles.sort()
	check_eq(roles, ["antechamber", "hub", "mb1", "mb2", "threshold"], "cinq portails fixes : hub, antichambre, deux arènes, C")


func test_lit_rooms_join_the_network() -> void:
	var st := _state()
	var saved := GameState.room_portals.duplicate()
	GameState.room_portals = {}
	var linked := st.portals.filter(func(p: Dictionary) -> bool: return PortalNet.linked(p)).size()
	check_eq(PortalNet.nodes(st).size(), 0 if linked == 0 else linked + 1, "aucune salle allumée : réseau des seuls pylônes")
	var hub := _room("hub")
	var ante := _room("antechamber")
	GameState.room_portals[hub["id"]] = true
	GameState.room_portals[ante["id"]] = true
	var nodes := PortalNet.nodes(st)
	check_eq(nodes.size(), linked + 3, "l'Ancre et deux portails de salle")
	check_eq(int(nodes[0]["id"]), PortalNet.ANCHOR_ID, "l'Ancre en tête")
	var names := nodes.map(func(n: Dictionary) -> String: return n["name"])
	check(names.has("Hub · L’Orbite") and names.has("Antichambre · L’Orbite"), "noms des portails de salle : %s" % [names])
	for n: Dictionary in nodes:
		if int(n["id"]) >= PortalNet.ROOM_ID0:
			var at: Vector2 = n["pos"]
			check_eq(st.temple_room(at.x, at.y).get("id", -1), int(n["id"]) - PortalNet.ROOM_ID0, "seuil dans sa salle")
			check(st.walkable(at.x, at.y), "seuil praticable")
			check(bool(n["open"]), "portail de salle ouvert")
	GameState.room_portals = saved


func test_antechamber_is_safe() -> void:
	var st := _state()
	var ante: Rect2i = _room("antechamber")["rect"]
	var hub: Rect2i = _room("hub")["rect"]
	check(st.safe_at(ante.get_center().x * 4.0 + 2.0, ante.get_center().y * 4.0 + 2.0), "antichambre sûre")
	check(not st.safe_at(hub.get_center().x * 4.0 + 2.0, hub.get_center().y * 4.0 + 2.0), "le hub ne l'est pas")
	# Aucune rencontre, tanière ou pylône dans l'antichambre.
	for d: Dictionary in RoomEncounters.dens(st):
		check(not st.safe_at(d["x"], d["z"]), "pas de rencontre dans l'antichambre")
	for p: Dictionary in st.portals:
		check(not st.safe_at(p["x"], p["z"]), "pas de pylône dans l'antichambre")
