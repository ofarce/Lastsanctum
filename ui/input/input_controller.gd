class_name InputController
extends Node
## Entrées du joueur (Index.html et hud.js, 73b410f) : sélection au clic gauche, Maj+clic, cadre de
## sélection, clic sur l'Ancre ; clic droit pour réactiver, creuser ou se déplacer ; glisser droit sur la
## roche pour mettre plusieurs cases en file. Touches 1–9, Ctrl+A, Échap, Maj+R et raccourcis HUD.

const BOX_FILL := Color("#ead08c22")
const BOX_LINE := Color("#f8df93")

var world: World
var sim: Simulation

var _box_on := false
var _box_shown := false
var _box_from := Vector2.ZERO
var _box_to := Vector2.ZERO
var _layer := CanvasLayer.new()
var _box := _SelectBox.new()
var _mining_hover := preload("res://ui/input/mining_hover.gd").new()
var _pointer_inside := true
var _mining_drag_on := false
var _mining_drag_cells: Array[Dictionary] = []
var _mining_drag_keys: Dictionary = {}
var _mining_drag_last := Vector2.ZERO


func _ready() -> void:
	world = get_node("../World") as World
	sim = get_node("../Simulation") as Simulation
	_layer.layer = 2
	add_child(_layer)
	_box.controller = self
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_box)
	_mining_hover.world = world
	_layer.add_child(_mining_hover)
	get_window().mouse_entered.connect(func() -> void: _pointer_inside = true)
	get_window().mouse_exited.connect(func() -> void: _pointer_inside = false)


func zoom_k() -> float:
	return 8.0 * world.camera.px / 0.86


func project(x: float, y: float, z: float) -> Vector2:
	return world.camera.project(x, y, z)


func ground(p: Vector2) -> Vector2:
	return world.camera.ground_from_screen(p)


func hit_orb(p: Vector2) -> bool:
	var y := 3.0 + sin(GameState.sim_time * 1.7) * 0.2 if GameState.orb_active else 2.6
	var o := project(CaveShape.CORE.x, y, CaveShape.CORE.y)
	return o.distance_to(p) < maxf(18.0, zoom_k() * 1.15)


func _process(_delta: float) -> void:
	var pointer := get_viewport().get_mouse_position()
	var blocked := not _pointer_inside or get_viewport().gui_get_hovered_control() != null or _box_on 		or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	_mining_hover.cell = mining_hover_cell(pointer, blocked)
	_mining_hover.selected_cells = _visible_mining_cells()
	_mining_hover.queue_redraw()
	var orb: Sprite2D = world.special("orb")
	if not is_instance_valid(orb):
		return
	var hovered := (not GameState.orb_active
		and GameState.hud_mode.is_empty()
		and get_viewport().gui_get_hovered_control() == null
		and hit_orb(get_viewport().get_mouse_position()))
	(orb.material as ShaderMaterial).set_shader_parameter("hovered", hovered)


func _visible_mining_cells() -> Array[Dictionary]:
	var cells := _mining_drag_cells.duplicate()
	var seen: Dictionary = _mining_drag_keys.duplicate()
	for u: Unit in GameState.units:
		if u.job == null or u.job.get("type") != "dig" or Catalog.is_adept(u):
			continue
		var queue: Array = u.job.get("cells", [u.job.get("cell")])
		for i in queue.size():
			var cell: Dictionary = queue[i]
			var key := Vector2i(cell["i"], cell["j"])
			if not seen.has(key):
				seen[key] = true
				cells.append(cell)
	return cells


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _pointer_inside and get_viewport().gui_get_hovered_control() == null and not _box_on:
			var first: Variant = mining_hover_cell(event.position)
			if first != null:
				_mining_drag_on = true
				_mining_drag_cells.clear()
				_mining_drag_keys.clear()
				_mining_drag_last = event.position
				_add_mining_cell(first)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _mining_drag_on and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		_collect_mining_segment(_mining_drag_last, event.position)
		_mining_drag_last = event.position
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed and _mining_drag_on:
		_collect_mining_segment(_mining_drag_last, event.position)
		_mining_drag_on = false
		if not _mining_drag_cells.is_empty():
			sim.order_mining_cells(_mining_drag_cells)
		_mining_drag_cells.clear()
		_mining_drag_keys.clear()
		get_viewport().set_input_as_handled()


func _collect_mining_segment(from: Vector2, to: Vector2) -> void:
	var steps := maxi(1, ceili(from.distance_to(to) / 8.0))
	for i in range(1, steps + 1):
		var pointer := from.lerp(to, float(i) / steps)
		if get_viewport().gui_get_hovered_control() != null:
			continue
		var cell: Variant = mining_hover_cell(pointer)
		if cell != null:
			_add_mining_cell(cell)


func _add_mining_cell(cell: Dictionary) -> void:
	var key := Vector2i(cell["i"], cell["j"])
	if _mining_drag_keys.has(key):
		return
	_mining_drag_keys[key] = true
	_mining_drag_cells.append(cell.duplicate())


## Même résolution de cible que le clic droit, recalculée même si seule la caméra bouge.
func mining_hover_cell(pointer: Vector2, ui_blocked := false) -> Variant:
	if ui_blocked or GameState.ended or not GameState.hud_mode.is_empty() 			or not get_viewport().get_visible_rect().has_point(pointer):
		return null
	for u: Unit in GameState.selected:
		if u.alive() and not u.hidden and (Catalog.is_adept(u) or (u.role == "engineer" and GameState.research_done.has("mining_artifact"))):
			return _mining_cell(ground(pointer))
	return null


func _mining_cell(point: Vector2) -> Variant:
	if not world.fog.visible_at(point):
		return null
	var target: Variant = world.terrain_state.diggable_cell(point)
	if target != null and world.fog.visible_at(Vector2(target["i"] * 4 + 2, target["j"] * 4 + 2)):
		return target
	return null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# templePointer : point du sol sous le pointeur, pour l'aperçu de construction.
		GameState.build_pointer = ground(event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_left_click(event.position, event.shift_pressed)
			if GameState.hud_mode.is_empty():
				_box_on = true
				_box_shown = false
				_box_from = event.position
				_box_to = event.position
		elif _box_on:
			_box_on = false
			if _box_shown:
				_box_select(event.shift_pressed)
			_box_shown = false
			_box.queue_redraw()
	elif event is InputEventMouseMotion and _box_on:
		if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_box_on = false
			_box_shown = false
		else:
			_box_to = event.position
			var s := (_box_to - _box_from).abs()
			_box_shown = _box_shown or not (s.x < 6.0 and s.y < 6.0)
		_box.queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		if not world.camera.consume_drag():
			_right_click(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event)


## Clic gauche (pointerdown, Index.html).
func _left_click(p: Vector2, shift: bool) -> void:
	if GameState.hud_mode.is_empty():
		GameState.hud_building = null
	if GameState.hud_mode == "build":
		sim.place_building(ground(p))
		return
	if GameState.hud_mode == "move":
		sim.issue_move(ground(p))
		return
	if hit_orb(p):
		GameState.selected = []
		GameState.hud_enemy = null
		GameState.anchor_selected = true
		GameState.hud_mode = ""
		GameState.hud_menu = ""
		return
	var near: Unit = null
	var best := INF
	for u in GameState.units:
		if not u.alive() or u.hidden:
			continue
		var d := project(u.x, 1.0, u.z).distance_to(p)
		if d < best:
			best = d
			near = u
	if near and best < maxf(18.0, 1.3 * zoom_k()):
		var group: Array[Unit] = [near]
		if near.squad:
			group.assign(GameState.units.filter(func(o: Unit) -> bool: return o.squad == near.squad and o.alive()))
		GameState.selected = _union(GameState.selected, group) if shift else group
		_show_selection()
		return
	# Écart voulu D14 : un ennemi sous le pointeur (même tolérance que les alliés) s'affiche dans le HUD.
	var foe := pick_enemy(p)
	if foe:
		GameState.selected = []
		GameState.anchor_selected = false
		GameState.hud_mode = ""
		GameState.hud_menu = ""
		GameState.hud_building = null
		GameState.hud_enemy = foe
		return
	var b := hit_building(ground(p))
	GameState.hud_enemy = null
	if b:
		GameState.selected = []
		GameState.anchor_selected = false
		GameState.hud_menu = ""
		GameState.hud_building = b
	else:
		GameState.selected = []
		GameState.anchor_selected = false
		GameState.hud_mode = ""


## Ennemi vivant et visible le plus proche du point, à moins de max(18, 1,3·Z) pixels ; sinon null.
func pick_enemy(p: Vector2) -> Enemy:
	var near: Enemy = null
	var best := INF
	for e: Enemy in GameState.enemies:
		if not e.alive() or e.hidden or not world.fog.visible_at(e.pos()):
			continue
		var d := project(e.x, 1.0, e.z).distance_to(p)
		if d < best:
			best = d
			near = e
	return near if near and best < maxf(18.0, 1.3 * zoom_k()) else null


## hitBuilding (buildings.js) : le bâtiment le plus au sud dont l'emprise (et la façade) contient le point.
func hit_building(p: Vector2) -> Building:
	var list := GameState.buildings.duplicate()
	list.sort_custom(func(a: Building, b: Building) -> bool: return a.z > b.z)
	for b: Building in list:
		if not world.fog.visible_at(Vector2(b.x, b.z)):
			continue
		var h := b.half()
		if absf(b.x - p.x) < h and p.y > b.z - h - h * 1.1 and p.y < b.z + h:
			return b
	return null


func _box_select(shift: bool) -> void:
	var r := Rect2(_box_from, Vector2.ZERO).expand(_box_to)
	var inside: Array[Unit] = []
	for u in GameState.units:
		if u.alive() and not u.hidden:
			var p := project(u.x, 1.0, u.z)
			if p.x >= r.position.x and p.x <= r.end.x and p.y >= r.position.y and p.y <= r.end.y:
				inside.append(u)
	if not inside.is_empty():
		inside = Simulation.expand_squads(inside)
		GameState.selected = _union(GameState.selected, inside) if shift else inside
		_show_selection()


## Clic droit sans glisser (contextmenu, Index.html).
func _right_click(p: Vector2) -> void:
	if GameState.ended:
		return
	if GameState.hud_mode == "build":
		GameState.hud_mode = ""
		return
	var selected := HudModel.selected_building()
	if selected and selected.produces_units():
		var point := ground(p)
		if sim.state().walkable(point.x, point.y):
			selected.rally_point = point
		return
	var eng := sim.builder()
	if eng and hit_orb(p):
		if GameState.orb_active:
			sim.set_job(eng, {"type": "anchor_pray"})
		else:
			sim.order_orb(eng)
		return
	if eng and preload("res://sim/item_storage.gd").character_available(eng):
		for b: Building in GameState.buildings:
			if not b.complete or not Production.has_chests(b):
				continue
			for kind: String in Production.chest_kinds(b):
				var pos := Production.chest_pos(b, kind)
				var origin := project(pos.x, 0.0, pos.y)
				var k := float(world.camera.px)
				if Rect2(origin - Vector2(13, 27) * k, Vector2(26, 30) * k).has_point(p) and world.fog.visible_at(Vector2(b.x, b.z)):
					sim.set_job(eng, {"type": "collect", "building": b, "open_box": kind})
					return
	if hit_chest(p) and sim.order_chest(eng):
		return
	var turret: Variant = hit_turret(p)
	if turret != null:
		sim.combat.order_turret(turret)
		return
	if _mining_cell(ground(p)) != null and sim.order_adepts(ground(p)):
		return
	if sim.order_pray(hit_building(ground(p))):
		return
	# Bâtiment servi par des adeptes : l'unité sélectionnée y prend un poste.
	if sim.order_staff(hit_building(ground(p))):
		return
	# Ennemi proche du clic (moins de max(20, 1,2·Z) pixels) : ordre d'attaque, sinon déplacement.
	var nearest: Enemy = null
	var best := INF
	for e: Enemy in GameState.enemies:
		if not e.alive() or e.hidden or not world.fog.visible_at(e.pos()):
			continue
		var d := project(e.x, 1.0, e.z).distance_to(p)
		if d < best:
			best = d
			nearest = e
	if nearest and best < maxf(20.0, 1.2 * zoom_k()):
		sim.issue_move(nearest.pos(), true)
		sim.say("Ordre : attaquer la cible.", 1.0)
	else:
		sim.issue_move(ground(p))


## Coffre antique sous le pointeur (silhouette de 40 × 44 pixels natifs au-dessus de sa face avant).
func hit_chest(p: Vector2) -> bool:
	if not sim.state().vault_open:
		return false
	var k := float(world.camera.px)
	var q := project(CaveShape.CHEST.x, 0.0, CaveShape.CHEST.y)
	return absf(p.x - q.x) < 20.0 * k and p.y > q.y - 40.0 * k and p.y < q.y + 4.0 * k


## hitTurret : baliste sous le pointeur (silhouette de 88 × 124 pixels natifs autour de la base).
func hit_turret(p: Vector2) -> Variant:
	var list := GameState.turrets.duplicate()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return b["x"] + b["z"] < a["x"] + a["z"])
	var k := float(world.camera.px)
	for b: Dictionary in list:
		if not world.fog.visible_at(Vector2(b["x"], b["z"])):
			continue
		var q := project(b["x"], 0.0, b["z"])
		if absf(p.x - q.x) < 44.0 * k and p.y > q.y - 100.0 * k and p.y < q.y + 24.0 * k:
			return b
	return null


func _key(e: InputEventKey) -> void:
	# Lettre imprimée sur la touche (ev.key : AZERTY comme QWERTY) ; les événements synthétiques (MCP,
	# Input.parse_input_event sans key_label) retombent sur keycode.
	var k := e.key_label if e.key_label != KEY_NONE else e.keycode
	if k == KEY_R and e.shift_pressed:
		sim.new_game()
		return
	if k == KEY_ESCAPE:
		GameState.hud_mode = ""
		GameState.hud_menu = ""
		return
	if not GameState.ended and hud_key(key_char(k)):
		return
	if k >= KEY_1 and k <= KEY_9:
		_select_index(k - KEY_1, e.shift_pressed)
	elif k == KEY_A and (e.ctrl_pressed or e.meta_pressed):
		# Décision D2 : Ctrl+A (Cmd+A sur macOS) sélectionne tout ; A seule ne sert plus qu'à la caméra.
		GameState.selected.assign(GameState.units.filter(func(u: Unit) -> bool: return u.alive() and not u.hidden))
		_show_selection()


## ev.key.toLowerCase() du prototype pour les touches utilisées par le panneau d'actions.
static func key_char(k: Key) -> String:
	if k >= KEY_A and k <= KEY_Z:
		return char(k).to_lower()
	if k >= KEY_0 and k <= KEY_9:
		return char(k)
	if k == KEY_SPACE:
		return " "
	return ""


## hudKey : raccourci d'une action visible du panneau ; vrai si la touche lui appartient.
func hud_key(k: String) -> bool:
	if k.is_empty():
		return false
	for a in HudModel.panel_actions(sim):
		if a["key"] == k:
			if not a["disabled"]:
				(a["run"] as Callable).call()
			return true
	return false


func _select_index(i: int, add: bool) -> void:
	var heroes := GameState.units.filter(func(u: Unit) -> bool: return u.squad == 0)
	var group: Array = [heroes[i]] if i < heroes.size() else GameState.units.filter(func(u: Unit) -> bool: return u.squad == i - heroes.size() + 1)
	var alive: Array[Unit] = []
	for u: Unit in group:
		if u and u.alive():
			alive.append(u)
	if alive.is_empty():
		return
	GameState.selected = _union(GameState.selected, alive) if add else alive
	_show_selection()


func _show_selection() -> void:
	GameState.hud_enemy = null
	GameState.anchor_selected = false
	GameState.hud_mode = ""
	GameState.hud_menu = ""
	GameState.hud_building = null


static func _union(a: Array[Unit], b: Array) -> Array[Unit]:
	var out: Array[Unit] = a.duplicate()
	for u: Unit in b:
		if not out.has(u):
			out.append(u)
	return out


class _SelectBox extends Control:
	var controller: InputController

	func _draw() -> void:
		if controller._box_on and controller._box_shown:
			var r := Rect2(controller._box_from, Vector2.ZERO).expand(controller._box_to)
			draw_rect(r, BOX_FILL)
			draw_rect(r, BOX_LINE, false, 1.0)
