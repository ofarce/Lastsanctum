class_name SaveGame
extends RefCounted
## Sauvegarde et chargement d'une partie (un seul emplacement, user://sauvegarde.save) ; résumé lisible
## dans user://sauvegarde.cfg (jour, heure, vague) pour le menu de pause sans tout relire.
##
## Principe : on n'écrit que l'état de la partie, jamais les nœuds de rendu.
##  - GameState (sauf l'état passager du HUD et des effets), objets Unit / Enemy / Building compris :
##    graphe d'objets encodé avec des identifiants, pour garder les références croisées (sélection, cibles,
##    porteur de l'orbe, tâches qui pointent un bâtiment…) ;
##  - terrain : la graine régénère la carte, puis les cases creusées sont rejouées dans l'ordre (sol repeint,
##    parois, galeries révélées), et les champs de TerrainState sont recopiés ;
##  - brouillard exploré, caméra, hasard de la simulation, quêtes, quelques variables statiques.
## Les vues (unités, bâtiments, ennemis, balistes) se recréent seules d'après GameState.
## Pas de sauvegarde pendant l'ouverture, une cinématique, la surcharge de l'Ancre ou un combat de boss.

const FILE := "user://sauvegarde.save"
const INFO := "user://sauvegarde.cfg"
## 2 (2026-11-22) : Temple en salles. Une sauvegarde de la version 1 rejouerait ses cases creusées sur une autre carte.
## 3 (2026-11-24) : Veines en salles, même raison.
const VERSION := 3
## État passager : remis à zéro au chargement plutôt qu'enregistré.
const GS_SKIP := ["hud_mode", "hud_menu", "hud_build_type", "hud_place_item", "hud_chest", "hud_enemy", "hud_grove",
	"build_pointer", "damage_numbers", "effects", "pray_popups", "hud_building", "anchor_selected"]
## Objets régénérés par la graine.
## Le plan du Temple en salles se recalcule depuis la graine (generate_galleries) : seul l'état des portes est gardé.
const TERRAIN_SKIP := ["river", "flora", "road", "version", "temple_layout", "room_at", "room_walls", "door_cells"]
const OBJ := "§o"
const DICT := "§d"
const TYPED := "§a"
const RNG := "§r"

## Sauvegarde automatique de l'aube (Hud._autosave) : coupée par le lanceur de tests et les scènes d'essai,
## pour ne jamais écrire dans les données du joueur.
static var autosave := true

var _ids := {}
var _objs: Array = []
var _made: Array = []
var _sim: Simulation
var warnings: PackedStringArray = []


static func exists() -> bool:
	return FileAccess.file_exists(FILE)


## « Jour 3 · 14 h 20 · vague 4 », ou "" sans sauvegarde.
static func summary() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(INFO) != OK:
		return ""
	return String(cfg.get_value("partie", "resume", ""))


## Raison d'un refus de sauvegarde, ou "" si c'est possible.
static func cannot_save(sim: Simulation) -> String:
	if sim == null or sim.world == null:
		return "Sauvegarde indisponible."
	if GameState.ended:
		return "La partie est terminée."
	if Opening.cinematic() or not GameState.opening_stage in ["", "day1", "awake", "waves"]:
		return "Pas de sauvegarde pendant l’ouverture."
	if Overload.active() or GameState.orb_active:
		return "Pas de sauvegarde pendant le rallumage de l’Ancre."
	if Martyre.active() or Gorge.active() or Archipretre.active() or Eclusier.active() or Patine.active() or GameState.oeil_state == "duel":
		return "Pas de sauvegarde pendant un combat de boss."
	return ""


static func store(sim: Simulation, hud: Hud = null) -> bool:
	if cannot_save(sim) != "":
		return false
	var s := SaveGame.new()
	s._sim = sim
	var data := s._collect(hud)
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	if f == null:
		push_error("Sauvegarde : impossible d'écrire %s" % FILE)
		return false
	f.store_var(data)
	f.close()
	for w in s.warnings:
		print("Sauvegarde : " + w)
	var t := GameState.sim_time
	var cfg := ConfigFile.new()
	cfg.set_value("partie", "resume", "%s · %s · vague %d" % ["Jour %d" % DayNight.day(t), DayNight.clock(t), GameState.wave])
	cfg.set_value("partie", "date", Time.get_unix_time_from_system())
	cfg.save(INFO)
	return true


static func restore(sim: Simulation, hud: Hud = null) -> bool:
	var f := FileAccess.open(FILE, FileAccess.READ)
	if f == null:
		return false
	var data: Variant = f.get_var()
	f.close()
	if not (data is Dictionary) or int(data.get("version", 0)) != VERSION:
		push_error("Sauvegarde illisible ou d'une autre version.")
		return false
	var s := SaveGame.new()
	s._sim = sim
	s._restore(data, hud)
	return true


# ---------------------------------------------------------------- Écriture

func _collect(hud: Hud) -> Dictionary:
	var world := _sim.world
	var st := _sim.state()
	var gs := {}
	for p in _script_vars(GameState):
		if not GS_SKIP.has(p):
			gs[p] = _enc(GameState.get(p), p)
	var terrain := {}
	for p in _script_vars(st):
		if not TERRAIN_SKIP.has(p):
			terrain[p] = _enc(st.get(p), "terrain." + p)
	var data := {
		"version": VERSION,
		"seed": world.gallery_seed,
		"game": gs,
		"terrain": terrain,
		# Ordre des cases creusées (Dictionary garde l'ordre d'insertion) : rejoué au chargement.
		"dug_order": st.dug.keys(),
		"fog": world.fog.explored_data().compress(FileAccess.COMPRESSION_ZSTD),
		"fog_size": world.fog.explored_data().size(),
		"camera": [world.camera.cam, world.camera.px],
		"rng": [_sim.rng.seed, _sim.rng.state],
		"day_phase": _sim._day_phase,
		"tactics": _enc_props(_sim.combat.tactics, ["sim"]),
		"opening": [_enc(Opening._cues), _enc(Opening._fire)],
		"mages": _enc(Mages._chantres),
		"world_seen": HelpPanel.world_seen,
		"quests": _enc_props(hud.quests, []) if hud else {},
	}
	data["objects"] = _objs
	return data


static func _script_vars(o: Object) -> Array[String]:
	var out: Array[String] = []
	for p: Dictionary in o.get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.append(p["name"])
	return out


func _enc_props(o: Object, skip: Array, path := "") -> Dictionary:
	var props := {}
	if o == null:
		return props
	for p in _script_vars(o):
		if not skip.has(p):
			props[p] = _enc(o.get(p), path + "." + p)
	return props


## Dictionnaire qui tient un objet du moteur (bruit, texture…) : un cache, à reconstruire plutôt qu'à écrire.
func _is_cache(v: Variant) -> bool:
	if not (v is Dictionary):
		return false
	for x: Variant in (v as Dictionary).values():
		if x is Object and x != null and not (x is Unit or x is Building or x is Rng or x == _sim or x == _sim.state()):
			return true
	return false


func _enc(v: Variant, path := "") -> Variant:
	match typeof(v):
		TYPE_OBJECT:
			if v == null or not is_instance_valid(v):
				return null
			if v == _sim:
				return {OBJ: "sim"}
			# Marqueur « carte générée pour cet état » (pylônes, errants, sanctum, Gorge) : l'état du terrain courant.
			if v == _sim.state():
				return {OBJ: "terrain"}
			# Hasard d'un groupe errant (core/rng.gd) : un entier suffit à le reprendre où il en était.
			if v is Rng:
				return {RNG: (v as Rng)._seed}
			if not (v is Unit or v is Building):
				warnings.append("objet non enregistré : %s (%s)" % [v, path])
				return null
			var iid: int = v.get_instance_id()
			if _ids.has(iid):
				return {OBJ: _ids[iid]}
			var id := _objs.size()
			_ids[iid] = id
			_objs.append(null)
			_objs[id] = {"script": (v.get_script() as Script).resource_path, "props": _enc_props(v, [], path)}
			return {OBJ: id}
		TYPE_DICTIONARY:
			var out := {}
			for k: Variant in v:
				# Cache recalculé à la demande (bruits d'un pylône, p["zone"]) : on ne l'écrit pas.
				if _is_cache(v[k]):
					continue
				out[_enc(k, path + "{key}")] = _enc(v[k], path + "[%s]" % str(k).left(20))
			return {DICT: out}
		TYPE_ARRAY:
			var a: Array = v
			var items := []
			for i in a.size():
				items.append(_enc(a[i], path + "[%d]" % i))
			if a.is_typed():
				var scr: Variant = a.get_typed_script()
				return {TYPED: items, "t": a.get_typed_builtin(), "c": a.get_typed_class_name(),
					"s": (scr as Script).resource_path if scr is Script else ""}
			return items
		TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			warnings.append("valeur non enregistrable : %s (%s)" % [type_string(typeof(v)), path])
			return null
	return v


# ---------------------------------------------------------------- Lecture

func _restore(data: Dictionary, hud: Hud) -> void:
	var sim := _sim
	var world := sim.world
	var seed: int = data["seed"]
	# Partie neuve sur la même graine, sans ouverture : carte, décor et vues de départ.
	var opening := sim.opening
	sim.opening = false
	sim.new_game(seed)
	sim.opening = opening
	var st := sim.state()
	# Objets d'abord (deux passes : création, puis champs), pour résoudre les références croisées.
	_objs = data["objects"]
	_made.resize(_objs.size())
	for i in _objs.size():
		_made[i] = (load(_objs[i]["script"]) as GDScript).new()
	for i in _objs.size():
		_set_props(_made[i], _objs[i]["props"])
	# Terrain : brèche, cases creusées dans l'ordre, puis recopie des champs.
	var terrain: Dictionary = data["terrain"]
	if bool(terrain.get("breach_open", false)):
		world.open_breach()
	for key: Vector2i in data["dug_order"]:
		world.terrain_ops.dig_cell(key.x, key.y)
	var groves_before: Dictionary = st.wood_left.duplicate()
	_set_props(st, terrain)
	st.version += 1
	var regrown: Array[Vector2i] = []
	for origin: Vector2i in st.wood_left:
		if not groves_before.has(origin):
			regrown.append(origin)
	if not regrown.is_empty():
		world.add_groves(regrown)
	if world.terrain_ops.painter:
		world.terrain_ops.painter.terrain.flush()
	world.apply_view()
	# État de la partie.
	GameState.effects.clear()
	GameState.damage_numbers.clear()
	_set_props(GameState, data["game"])
	GameState.selected = GameState.selected.filter(func(u: Unit) -> bool: return u.alive())
	sim.rng.seed = data["rng"][0]
	sim.rng.state = data["rng"][1]
	sim._day_phase = data["day_phase"]
	_set_props(sim.combat.tactics, data["tactics"])
	Opening._cues = _dec(data["opening"][0])
	Opening._fire = _dec(data["opening"][1])
	Mages._chantres.assign(_dec(data["mages"]))
	HelpPanel.world_seen = data["world_seen"]
	if hud and not (data["quests"] as Dictionary).is_empty():
		_set_props(hud.quests, data["quests"])
	# Brouillard exploré et caméra.
	world.fog.set_explored_data((data["fog"] as PackedByteArray).decompress(int(data["fog_size"]), FileAccess.COMPRESSION_ZSTD))
	world.fog.refresh(st)
	world.camera.set_view(data["camera"][0], data["camera"][1])
	if hud:
		hud.refresh(true)


func _set_props(o: Object, props: Dictionary) -> void:
	if o == null:
		return
	for p: String in props:
		if not (p in o):
			continue
		var v: Variant = _dec(props[p])
		var cur: Variant = o.get(p)
		if cur is Array and (cur as Array).is_typed() and v is Array:
			(cur as Array).assign(v)
		elif cur is Dictionary and (cur as Dictionary).is_typed() and v is Dictionary:
			(cur as Dictionary).assign(v)
		else:
			o.set(p, v)


func _dec(v: Variant) -> Variant:
	if v is Dictionary:
		var d: Dictionary = v
		if d.has(OBJ):
			if d[OBJ] is String:
				return _sim if d[OBJ] == "sim" else _sim.state()
			return _made[int(d[OBJ])]
		if d.has(RNG):
			var r := Rng.new(0)
			r._seed = int(d[RNG])
			return r
		if d.has(DICT):
			var out := {}
			var src: Dictionary = d[DICT]
			for k: Variant in src:
				out[_dec(k)] = _dec(src[k])
			return out
		if d.has(TYPED):
			var items: Array = (d[TYPED] as Array).map(func(x: Variant) -> Variant: return _dec(x))
			var scr: Variant = load(d["s"]) if String(d["s"]) != "" else null
			return Array(items, int(d["t"]), StringName(d["c"]), scr)
		return d
	if v is Array:
		return (v as Array).map(func(x: Variant) -> Variant: return _dec(x))
	return v
