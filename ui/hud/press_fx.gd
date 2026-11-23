class_name PressFx
## Bouton enfoncé, comme une vraie touche : tant que le clic gauche est tenu dessus, la face descend de DEPTH px
## dans son logement (bande sombre découverte en haut), s'assombrit et prend une ombre intérieure sur son bord
## haut ; elle remonte au relâché.
## Boutons BaseButton : état lu dans get_draw_mode(). Contrôles à clic maison (_gui_input) : track() au clic.

const DEPTH := 2.0
const SOCKET := Color("#050706")


## Vrai tant que le bouton est tenu enfoncé (pointeur dessus pour un BaseButton, comme dans Godot).
static func down(c: Control) -> bool:
	if c is BaseButton:
		var b := c as BaseButton
		return not b.disabled and b.get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED]
	# Bouton masqué ou rebâti avant le relâché : le bouton gauche n'est plus tenu, la face est remontée.
	return c.has_meta(&"press_down") and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


## Décalage vertical de la face (0 au repos).
static func dy(c: Control) -> float:
	return DEPTH if down(c) else 0.0


## Contrôle à clic maison : à appeler depuis _gui_input. `key` distingue plusieurs boutons dessinés par un même
## contrôle (ZoomButtons) ; il est rendu par pressed_key().
static func track(c: Control, event: InputEvent, key: Variant = true) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var was: Variant = pressed_key(c)
		var now: Variant = key if event.pressed else null
		if typeof(now) != typeof(was) or now != was:
			if typeof(now) == TYPE_NIL:
				c.remove_meta(&"press_down")
			else:
				c.set_meta(&"press_down", now)
			c.queue_redraw()


## Clé du bouton tenu enfoncé (celle passée à track()), null au repos.
static func pressed_key(c: Control) -> Variant:
	return c.get_meta(&"press_down") if c.has_meta(&"press_down") else null


## Début du dessin d'un bouton enfoncé : logement sombre sous la face, puis décalage de tout ce qui suit.
## Rien au repos. Le dessin doit ensuite appeler finish().
static func begin(ci: CanvasItem, r: Rect2, pressed: bool) -> void:
	if not pressed:
		return
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, DEPTH)), SOCKET)
	ci.draw_set_transform(Vector2(0.0, DEPTH))


## Fin du dessin d'un bouton enfoncé : voile sombre et ombre intérieure en haut et à gauche, puis repère rétabli.
static func finish(ci: CanvasItem, r: Rect2, pressed: bool) -> void:
	if not pressed:
		return
	shade(ci, r)
	ci.draw_set_transform(Vector2.ZERO)


static func shade(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, Color(0, 0, 0, 0.2))
	var a := [0.5, 0.3, 0.14]
	for i in a.size():
		ci.draw_rect(Rect2(r.position + Vector2(0, i), Vector2(r.size.x, 1)), Color(0, 0, 0, a[i]))
		ci.draw_rect(Rect2(r.position + Vector2(i, 0), Vector2(1, r.size.y)), Color(0, 0, 0, a[i] * 0.6))
