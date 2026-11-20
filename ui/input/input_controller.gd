class_name InputController
extends Node
## Entrées du joueur (Index.html et hud.js, 73b410f) : sélection au clic gauche, Maj+clic, cadre de
## sélection, clic sur l'Ancre ; clic droit pour réactiver, creuser ou se déplacer ; glisser droit sur la
## roche pour mettre plusieurs cases en file. Touches 1–9, Ctrl+A, Échap, Maj+R et raccourcis HUD.

const BOX_FILL := Color("#5ce8ff22")
const BOX_LINE := Color("#8ff2ff")

var world: World
var sim: Simulation

var _box_on := false
var _box_shown := false
var _box_from := Vector2.ZERO
var _box_to := Vector2.ZERO
var _box_prev: Array[Unit] = []
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
	# Du puits à la sphère soulevée : la sphère éteinte est noyée au ras du sol, éveillée elle flotte.
	var low := project(CaveShape.CORE.x, 0.2, CaveShape.CORE.y)
	var high := project(CaveShape.CORE.x, 3.0, CaveShape.CORE.y)
	return Geometry2D.get_closest_point_to_segment(p, low, high).distance_to(p) < maxf(18.0, zoom_k() * 1.4)


func _process(_delta: float) -> void:
	# Codex d'aide ouvert : jeu en pause, aucune commande.
	if HelpPanel.open:
		return
	_engineer_keys()
	if GameState.incarnated != null:
		_incarnated_attack()
		# Sceau de Minage : le mur à un bloc de l'Exilé incarné est mis en surbrillance (clic droit : le miner).
		var aim := ground(get_viewport().get_mouse_position())
		_mining_hover.cell = sim.incarnated_mining_cell(GameState.incarnated, aim)
		_mining_hover.selected_cells = _visible_mining_cells()
		_mining_hover.queue_redraw()
		return
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


## ZQSD (lettres imprimées : Z haut, Q gauche, S bas, D droite à l'écran) : déplacement direct de
## l'Exilé incarné (désincarné, ces touches déplacent la caméra). La direction écran est convertie en direction monde via la projection de la caméra.
var _eng_driving := false

func _engineer_keys() -> void:
	if GameState.ended or Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META) \
			or get_viewport().gui_get_focus_owner() is LineEdit:
		_eng_driving = false
		return
	var s := Vector2(
		float(_label_down(KEY_D)) - float(_label_down(KEY_Q)),
		float(_label_down(KEY_S)) - float(_label_down(KEY_Z)))
	var eng: Unit = GameState.incarnated
	if eng != null:
		# Incarnation : les flèches pilotent aussi l'Exilé (elles ne déplacent plus la caméra).
		s += Vector2(float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT)),
			float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP)))
		s = s.clamp(Vector2(-1, -1), Vector2(1, 1))
	if eng == null:
		# Désincarné : ZQSD déplacent la caméra (WorldCamera), plus l'Ingénieur.
		_eng_driving = false
		return
	if s == Vector2.ZERO:
		if _eng_driving:
			eng.tx = eng.x
			eng.tz = eng.z
			_eng_driving = false
		return
	var c := get_viewport().get_visible_rect().size * 0.5
	var dir := ground(c + s.normalized() * 100.0) - ground(c)
	if dir.length() < 0.001:
		return
	if not _eng_driving:
		sim.cancel_work(eng)
	_eng_driving = true
	var t := eng.pos() + dir.normalized() * 1.5
	eng.tx = t.x
	eng.tz = t.y
	eng.stance = "attack"
	eng.force_move = true


## Clic droit commencé sur un bâtiment (incarnation) : ouvre ses options, sans tirer tant qu'il est maintenu.
var _rc_building := false


func _incarnated_pick(p: Vector2) -> void:
	var inc := GameState.incarnated
	var near: Unit = null
	var best := INF
	for u in GameState.units:
		if u == inc or not u.alive() or u.hidden:
			continue
		var d := project(u.x, 1.0, u.z).distance_to(p)
		if d < best:
			best = d
			near = u
	GameState.hud_enemy = null
	GameState.hud_menu = ""
	GameState.hud_mode = ""
	if near and best < maxf(18.0, 1.3 * zoom_k()):
		GameState.hud_building = null
		GameState.selected = [near]
		return
	var b := hit_building(ground(p))
	if b:
		GameState.selected = []
		GameState.hud_building = b
		return
	if HudModel.incarnated_panel():
		_close_incarnated_panel()


## Le point visé désigne la case : dessous, ou case de mur retenue au survol comme hors incarnation.
func _clicks_cell(point: Vector2, cell: Dictionary) -> bool:
	var key := Vector2i(cell["i"], cell["j"])
	if Vector2i((point / 4.0).floor()) == key:
		return true
	var hovered: Variant = world.terrain_state.diggable_cell(point)
	return hovered != null and Vector2i(hovered["i"], hovered["j"]) == key


## Incarnation : alliés sélectionnés au clic gauche (adeptes, unités militaires), hors Exilé incarné.
func _incarnated_allies() -> Array[Unit]:
	var out: Array[Unit] = []
	for u: Unit in GameState.selected:
		if u != GameState.incarnated and u.alive() and not u.hidden and not u.is_enemy():
			out.append(u)
	return out


func _close_incarnated_panel() -> void:
	GameState.hud_building = null
	GameState.hud_mode = ""
	GameState.hud_menu = ""
	if GameState.incarnated:
		GameState.selected = [GameState.incarnated]


## Incarnation : clic droit maintenu = tir vers le curseur si une arme est équipée (cadence de l'arme).
func _incarnated_attack() -> void:
	if GameState.ended or _rc_building or not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) \
			or get_viewport().gui_get_hovered_control() != null:
		return
	sim.combat.aimed_attack(GameState.incarnated, ground(get_viewport().get_mouse_position()))


static func _label_down(k: Key) -> bool:
	return Input.is_key_label_pressed(k) or Input.is_key_pressed(k)


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
	if Opening.cinematic() or HelpPanel.open:
		return
	# Capsule : E entre (désincarne) ou sort (réincarne).
	if event is InputEventKey and event.pressed and not event.echo and not event.ctrl_pressed \
			and not (get_viewport().gui_get_focus_owner() is LineEdit):
		var key: Key = event.key_label if event.key_label != KEY_NONE else event.keycode
		# Pylône de Merenor au contact : E lance (ou arrête) la bénédiction ; sinon la capsule.
		if key == KEY_E and (Pylons.toggle_bless(sim) or Capsule.toggle(sim)):
			get_viewport().set_input_as_handled()
			return
		# F3 : contrôle des hitboxes des ennemis (WorldOverlay._draw_hitboxes).
		if key == KEY_F3:
			WorldOverlay.show_hitboxes = not WorldOverlay.show_hitboxes
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _pointer_inside and get_viewport().gui_get_hovered_control() == null and not _box_on:
			# Pylône de Merenor sous le pointeur (son dessin, obélisque compris) : avant le minage, car l'obélisque
			# se dessine par-dessus la roche au nord du socle.
			var py := hit_pylon(event.position)
			if not py.is_empty() and sim.channel_pylon(py):
				get_viewport().set_input_as_handled()
				return
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
	# Cinématique de la séquence d'ouverture, ou codex d'aide ouvert : aucune commande.
	if Opening.cinematic() or HelpPanel.open:
		return
	# Incarnation (mode action pur) : ni sélection, ni ordres, ni raccourcis ; seule la capsule désincarne.
	if GameState.incarnated != null:
		if event is InputEventMouseMotion:
			GameState.build_pointer = ground(event.position)
		# Clic droit sur un bâtiment : ouvre ses options (adeptes, recherches…) sans tirer ; ailleurs, referme.
		# Construction ou pose armée (menu en bas à gauche) : clic gauche place, clic droit annule.
		if event is InputEventMouseButton and event.pressed and GameState.hud_mode in ["build", "place"]:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if GameState.hud_mode == "build":
					sim.place_building(ground(event.position))
				else:
					sim.place_item(ground(event.position))
				return
			if event.button_index == MOUSE_BUTTON_RIGHT:
				_rc_building = true
				GameState.hud_mode = ""
				return
		if event is InputEventMouseButton and event.pressed:
			GameState.hud_chest = {}
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
			var wall: Variant = sim.incarnated_mining_cell(GameState.incarnated, ground(event.position)) if event.pressed else null
			var allies := _incarnated_allies()
			var box := hit_production_chest(event.position) if event.pressed else {}
			if not box.is_empty():
				# Coffre bleu ou rouge d'un bâtiment sous le pointeur : halo de sélection, et il s'ouvre au lieu de tirer.
				_rc_building = true
				GameState.hud_chest = box
				sim.open_production_chest_incarnated(GameState.incarnated, box["building"], box["kind"])
			elif event.pressed and hit_chest(event.position):
				# Coffre antique : s'ouvre (réserve de la base) au lieu de tirer.
				_rc_building = true
				GameState.hud_chest = {"kind": "vault"}
				sim.open_chest_incarnated(GameState.incarnated)
			elif event.pressed and not allies.is_empty():
				# Allié sélectionné (clic gauche) : le clic droit l'envoie (poste de tir, bâtiment, sol) au lieu de tirer.
				_rc_building = true
				var gp := ground(event.position)
				var P := preload("res://sim/placeables.gd")
				var post := P.firing_post_at(gp)
				if post.is_empty():
					post = P.firing_post_at(gp + Vector2(0.0, 4.0))
				var target := hit_building(gp)
				if not post.is_empty():
					P.order_post(sim, post)
				elif target != null and (sim.order_pray(target) or sim.order_staff(target)):
					# Bâtiment sous le clic : l'adepte y prie (temple) ou y prend un poste, comme désincarné.
					pass
				else:
					sim.issue_move(gp)
			elif event.pressed and HudModel.selected_building() and HudModel.selected_building().produces_units() \
					and hit_building(ground(event.position)) in [null, HudModel.selected_building()]:
				# Bâtiment producteur sélectionné : le clic droit au sol pose son point de ralliement au lieu de tirer ;
				# sur le bâtiment lui-même, il l'annule.
				_rc_building = true
				_set_rally(HudModel.selected_building(), ground(event.position))
			elif wall != null and _clicks_cell(ground(event.position), wall):
				# Mur en surbrillance sous le pointeur : le miner au lieu de tirer.
				_rc_building = true
				sim.incarnated_dig(GameState.incarnated, wall)
			elif event.pressed:
				var b := hit_building(ground(event.position))
				_rc_building = b != null
				if b:
					GameState.hud_building = b
					GameState.hud_enemy = null
					GameState.hud_menu = ""
					GameState.selected = []
				elif HudModel.incarnated_panel():
					_close_incarnated_panel()
			else:
				_rc_building = false
		# Clic gauche : sélectionne un bâtiment, un adepte ou une unité militaire (options dans le bandeau).
		# Maintenu et glissé : rectangle de sélection des alliés (hors Exilé incarné), comme désincarné.
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Maj + glissé : ajoute aux alliés déjà sélectionnés avant l'appui (le clic court les remplace).
				_box_prev = _incarnated_allies()
				_incarnated_pick(event.position)
				_box_begin(event.position)
			elif _box_on:
				var shown := _box_shown
				_box_end()
				if shown:
					_incarnated_box_select(event.shift_pressed)
		elif event is InputEventMouseMotion and _box_on:
			_box_drag(event)
		if event is InputEventKey and event.pressed and not event.echo:
			var k: Key = event.key_label if event.key_label != KEY_NONE else event.keycode
			var menu := GameState.incarnated.role == "engineer" and not HudModel.incarnated_panel() and not GameState.ended
			if k == KEY_ESCAPE and menu and not (GameState.hud_mode.is_empty() and GameState.hud_menu.is_empty()):
				GameState.hud_mode = ""
				GameState.hud_menu = ""
			elif menu and not event.shift_pressed and (not GameState.hud_menu.is_empty() or k == KEY_B or k == KEY_P):
				# Menu de construction / pose : B, P, puis la touche du bâtiment ou de l'objet.
				hud_key(key_char(k))
			elif k == KEY_ESCAPE and HudModel.incarnated_panel():
				_close_incarnated_panel()
			# Échap ne désincarne plus (2026-11-19) : seule la capsule (touche E) le fait.
			elif k == KEY_R and event.shift_pressed:
				sim.new_game()
		return
	if event is InputEventMouseMotion:
		# templePointer : point du sol sous le pointeur, pour l'aperçu de construction.
		GameState.build_pointer = ground(event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_left_click(event.position, event.shift_pressed)
			if GameState.hud_mode.is_empty():
				_box_begin(event.position)
		elif _box_on:
			var shown := _box_shown
			_box_end()
			if shown:
				_box_select(event.shift_pressed)
	elif event is InputEventMouseMotion and _box_on:
		_box_drag(event)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		if not world.camera.consume_drag():
			_right_click(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event)


## Clic gauche (pointerdown, Index.html).
func _left_click(p: Vector2, shift: bool) -> void:
	GameState.hud_chest = {}
	if GameState.hud_mode.is_empty():
		GameState.hud_building = null
	if GameState.hud_mode == "build":
		sim.place_building(ground(p))
		return
	if GameState.hud_mode == "place":
		sim.place_item(ground(p))
		return
	if GameState.hud_mode == "move":
		sim.issue_move(ground(p))
		return
	if hit_orb(p):
		Sfx.play("ui_selection")
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
		Sfx.play("ui_selection")
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
		Sfx.play("ui_selection")
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
		# Un clic n'importe où sur sa silhouette le désigne (Enemy.body_rect).
		var r := e.body_rect()
		var a := project(r.position.x, 0.0, r.position.y)
		var b := project(r.end.x, 0.0, r.end.y)
		# Silhouettes superposées : la plus au sud (dessinée devant) l'emporte.
		if Rect2(a, b - a).has_point(p):
			d = -1.0 - e.z * 1e-4
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


## Rectangle de sélection : appui gauche (pas encore visible), glissé (visible au-delà de 6 px), relâché.
func _box_begin(p: Vector2) -> void:
	_box_on = true
	_box_shown = false
	_box_from = p
	_box_to = p


func _box_drag(event: InputEventMouseMotion) -> void:
	if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_box_on = false
		_box_shown = false
	else:
		_box_to = event.position
		var s := (_box_to - _box_from).abs()
		_box_shown = _box_shown or not (s.x < 6.0 and s.y < 6.0)
	_box.queue_redraw()


func _box_end() -> void:
	_box_on = false
	_box_shown = false
	_box.queue_redraw()


## Unités vivantes et visibles dont le point projeté tombe dans le rectangle tracé.
func _units_in_box() -> Array[Unit]:
	var r := Rect2(_box_from, Vector2.ZERO).expand(_box_to)
	var inside: Array[Unit] = []
	for u in GameState.units:
		if u.alive() and not u.hidden:
			var p := project(u.x, 1.0, u.z)
			if p.x >= r.position.x and p.x <= r.end.x and p.y >= r.position.y and p.y <= r.end.y:
				inside.append(u)
	return inside


## Incarnation : le rectangle sélectionne les alliés (adeptes, unités militaires), jamais l'Exilé incarné.
## Rien dedans : la sélection du clic court (à l'appui) reste.
func _incarnated_box_select(shift: bool) -> void:
	var inside: Array[Unit] = []
	for u: Unit in _units_in_box():
		if u != GameState.incarnated and not u.is_enemy():
			inside.append(u)
	if inside.is_empty():
		return
	inside = Simulation.expand_squads(inside)
	inside.assign(inside.filter(func(u: Unit) -> bool: return u != GameState.incarnated))
	var base: Array[Unit] = []
	if shift:
		base.assign(_box_prev.filter(func(u: Unit) -> bool: return u.alive() and not u.hidden))
	GameState.selected = _union(base, inside)
	_show_selection()


func _box_select(shift: bool) -> void:
	var inside := _units_in_box()
	if not inside.is_empty():
		inside = Simulation.expand_squads(inside)
		GameState.selected = _union(GameState.selected, inside) if shift else inside
		_show_selection()


## Pose le point de ralliement du bâtiment ; un clic sur le bâtiment lui-même l'annule.
func _set_rally(b: Building, point: Vector2) -> void:
	if hit_building(point) == b:
		b.rally_point = null
	elif sim.state().walkable(point.x, point.y):
		b.rally_point = point


## Clic droit sans glisser (contextmenu, Index.html).
func _right_click(p: Vector2) -> void:
	if GameState.ended:
		return
	GameState.hud_chest = {}
	if GameState.hud_mode == "build" or GameState.hud_mode == "place":
		GameState.hud_mode = ""
		return
	var selected := HudModel.selected_building()
	if selected and selected.produces_units():
		_set_rally(selected, ground(p))
		return
	var eng := sim.builder()
	if eng and hit_orb(p):
		if GameState.orb_active:
			sim.set_job(eng, {"type": "anchor_pray"})
		else:
			sim.order_orb(eng)
		return
	var box := hit_production_chest(p)
	if not box.is_empty():
		GameState.hud_chest = box
		if eng and preload("res://sim/item_storage.gd").character_available(eng):
			sim.set_job(eng, {"type": "collect", "building": box["building"], "open_box": box["kind"]})
			return
	if hit_chest(p) and sim.order_chest(eng):
		GameState.hud_chest = {"kind": "vault"}
		return
	var turret: Variant = hit_turret(p)
	if turret != null:
		sim.combat.order_turret(turret)
		return
	if _mining_cell(ground(p)) != null and sim.order_adepts(ground(p)):
		return
	# Poste de tir sous le clic : la sélection se place entre les rondins.
	# Le créneau de rondins dépasse au-dessus de sa case : un clic sur le haut du dessin tombe sur la case au
	# nord, on regarde donc aussi la case juste au sud.
	var post := preload("res://sim/placeables.gd").firing_post_at(ground(p))
	if post.is_empty():
		post = preload("res://sim/placeables.gd").firing_post_at(ground(p) + Vector2(0.0, 4.0))
	if not post.is_empty() and not GameState.selected.is_empty() and world.fog.visible_at(Vector2(post["x"], post["z"])):
		preload("res://sim/placeables.gd").order_post(sim, post)
		return
	# Pylône de Merenor sous le clic : les esprits sélectionnés vont le canaliser.
	var py := hit_pylon(p)
	if not py.is_empty() and sim.channel_pylon(py):
		return
	if sim.order_pray(hit_building(ground(p))):
		return
	# Bâtiment servi par des adeptes : l'unité sélectionnée y prend un poste.
	if sim.order_staff(hit_building(ground(p))):
		return
	# Hors incarnation, le clic droit ne donne jamais d'ordre d'attaque : simple déplacement.
	sim.issue_move(ground(p))


## Coffre antique sous le pointeur (silhouette de 40 × 44 pixels natifs au-dessus de sa face avant).
## Pylône de Merenor éveillé et visible dont le dessin (socle et obélisque) est sous le point écran, ou vide.
func hit_pylon(p: Vector2) -> Dictionary:
	if GameState.ended or not GameState.hud_mode.is_empty():
		return {}
	var m := PylonView.meta()
	var k := float(world.camera.px)
	for py: Dictionary in world.terrain_state.portals:
		if not py["active"] or not world.fog.visible_at(Vector2(py["x"], py["z"])):
			continue
		var origin := project(py["x"], 0.0, py["z"])
		var r := Rect2(origin - Vector2(float(m["ax"]), float(m["ay"])) * k, Vector2(float(m["frame_w"]), float(m["frame_h"])) * k)
		if r.has_point(p):
			return py
	return Pylons.at(world.terrain_state, ground(p)) if world.fog.visible_at(ground(p)) else {}


## Coffre de production (bleu « in », grenat « out ») sous le point écran : {"building", "kind"}, ou vide.
func hit_production_chest(p: Vector2) -> Dictionary:
	if GameState.ended or not GameState.hud_mode.is_empty():
		return {}
	var k := float(world.camera.px)
	for b: Building in GameState.buildings:
		if not b.complete or not Production.has_chests(b) or not Production.staffed(b) \
				or not world.fog.visible_at(Vector2(b.x, b.z)):
			continue
		for kind: String in Production.chest_kinds(b):
			var pos := Production.chest_pos(b, kind)
			var origin := project(pos.x, 0.0, pos.y)
			if Rect2(origin - Vector2(13, 27) * k, Vector2(26, 30) * k).has_point(p):
				return {"building": b, "kind": kind}
	return {}


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
	Sfx.play("ui_selection")
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
