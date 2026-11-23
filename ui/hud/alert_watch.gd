class_name AlertWatch
extends Node
## Alertes situées (Events.map_alert), relevées en comparant l'état d'une image à l'autre : rien dans la
## simulation n'a besoin de les émettre.
##  - un allié tombe (Exilé, adepte, soldat) : toujours ;
##  - un allié encaisse un coup hors de l'écran : au plus une alerte par zone toutes les ZONE_COOLDOWN s ;
##  - une barricade est frappée hors de l'écran, l'Ancre perd de l'intégrité.
## Les alertes se regroupent : au plus une toutes les GLOBAL_GAP s (sauf une mort, qui passe toujours).

const ZONE := 48.0
const ZONE_COOLDOWN := 25.0
const GLOBAL_GAP := 4.0
const CORE_COOLDOWN := 20.0

var world: World
var _hp := {}
var _alive := {}
var _barricades := {}
var _core := -1.0
var _zones := {}
var _last := -INF
var _core_at := -INF


func _ready() -> void:
	Events.game_reset.connect(reset)


func reset() -> void:
	_hp.clear()
	_alive.clear()
	_barricades.clear()
	_core = -1.0
	_zones.clear()
	_last = -INF
	_core_at = -INF


func _process(_delta: float) -> void:
	if world == null or GameState.ended or Opening.cinematic() or GameState.opening_stage != "":
		# Pendant l'ouverture, on se contente de suivre l'état (pas d'alerte à la sortie de cinématique).
		_snapshot()
		return
	var now := GameState.sim_time
	for u: Unit in GameState.units:
		var was_alive: bool = _alive.get(u, u.alive())
		var hp_before: float = _hp.get(u, u.hp)
		if was_alive and not u.alive() and not u.hidden:
			_emit(_death_text(u), u.pos(), true)
		elif u.alive() and u.hp < hp_before - 0.01 and not u.hidden and not _praying(u) and not _on_screen(u.pos()) and _zone_free(u.pos(), now):
			_emit(_hit_text(u), u.pos(), false)
	for o: Dictionary in GameState.placed:
		if not o.has("hp"):
			continue
		var before: float = _barricades.get(o["cell"], o["hp"])
		var p := Vector2(float(o["x"]), float(o["z"]))
		if float(o["hp"]) < before - 0.01 and not _on_screen(p) and _zone_free(p, now):
			_emit("Une barricade est attaquée !", p, false)
	if _core >= 0.0 and GameState.core_hp < _core - 0.001 and now - _core_at >= CORE_COOLDOWN:
		_core_at = now
		_emit("L’Ancre est attaquée !", CaveShape.CORE, true)
	_snapshot()


func _snapshot() -> void:
	_hp.clear()
	_alive.clear()
	for u: Unit in GameState.units:
		_hp[u] = u.hp
		_alive[u] = u.alive()
	_barricades.clear()
	for o: Dictionary in GameState.placed:
		if o.has("hp"):
			_barricades[o["cell"]] = float(o["hp"])
	_core = GameState.core_hp


func _emit(text: String, p: Vector2, force: bool) -> void:
	var now := GameState.sim_time
	if not force and now - _last < GLOBAL_GAP:
		return
	_last = now
	Events.map_alert.emit(text, p.x, p.y)


func _zone_free(p: Vector2, now: float) -> bool:
	var key := Vector2i(floori(p.x / ZONE), floori(p.y / ZONE))
	if now - float(_zones.get(key, -INF)) < ZONE_COOLDOWN:
		return false
	_zones[key] = now
	return true


func _on_screen(p: Vector2) -> bool:
	var s := world.camera.project(p.x, 0.0, p.y)
	return world.get_viewport().get_visible_rect().grow(-40.0).has_point(s)


## Prière à l'Ancre : l'Ingénieur y laisse de la vie, ce n'est pas une attaque.
static func _praying(u: Unit) -> bool:
	return u.job is Dictionary and String((u.job as Dictionary).get("type", "")) == "anchor_pray"


## Libellés sans accord (Guérisseuse, Chantre, adeptes…) : « Perte : … », « … sous attaque ! ».
static func _death_text(u: Unit) -> String:
	if u.role == "engineer":
		return "L’Ingénieur est à terre !"
	return "Perte : %s." % u.name


static func _hit_text(u: Unit) -> String:
	if u.role == "engineer":
		return "L’Ingénieur est attaqué !"
	return "%s sous attaque !" % u.name
