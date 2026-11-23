class_name Lighting
extends Node2D
## Éclairage d'ambiance (lighting.js, 73b410f) : obscurité générale creusée autour des sources (calque
## superposé), vignette, et lueurs colorées additives. Enfant de World, après le décor : les lueurs sont
## dessinées après les personnages et le décor, avant les effets, comme dans le prototype.
## Les sources sont recalculées à chaque image (collectLights) ; d'autres systèmes peuvent en ajouter
## par `providers` (callables qui renvoient des sources {x, z, r, rgb: Color, glow}).

const DARK_SHADER := preload("res://shaders/lighting_dark.gdshader")
const UPSCALE_SHADER := preload("res://shaders/lighting_upscale.gdshader")
const GLOW_SHADER := preload("res://shaders/lighting_glow.gdshader")
const MAX_LIGHTS := 128
const WARM := Color8(255, 176, 92)
const FORGE := Color8(255, 128, 48)
const ARCANE := Color8(184, 132, 255)
const FROST := Color8(110, 200, 230)
const EVIL := Color8(255, 70, 40)
## Écart voulu D16 (charte graphique) : une couleur par culte, l'Ancre pourpre.
const ANCRE := Color8(154, 58, 184)
const CULT := {"medeina": Color8(122, 224, 112), "indra": Color8(255, 138, 42), "sigil": Color8(228, 234, 246), "aether": Color8(122, 128, 255)}
const CULT_OF := {"sigil": "sigil", "warehouse": "sigil", "library": "sigil", "aether": "aether", "forge": "aether", "workshop": "aether", "creuset": "aether", "scierie": "aether", "archerie": "aether", "etabli": "aether",
	"medeina": "medeina", "bedroom": "medeina", "soulwell": "medeina", "eglise": "medeina", "ecole": "medeina", "indra": "indra", "caserne": "indra"}
const PORTAL := Vector2(0.0, -167.7)
const ORB_TIME := 8.0
const FIREFLY := Color8(196, 255, 120)
const MAX_FIREFLIES := 24

var enabled := true
var providers: Array[Callable] = []
var world: World
var _glow_mat := ShaderMaterial.new()
var _dark_mat := ShaderMaterial.new()
var _up_mat := ShaderMaterial.new()
var _layer := CanvasLayer.new()
## Calque d'obscurité au quart de la résolution (comme le canvas LIGHTING.c du prototype).
var _quarter := SubViewport.new()
var _quarter_rect := ColorRect.new()
## Agrandissement à l'écran.
var _dark := ColorRect.new()
var _white: ImageTexture
var _glows: Array = []
var _decor_lights: Array[Dictionary] = []
var _decor_version := -1


func _ready() -> void:
	_glow_mat.shader = GLOW_SHADER
	material = _glow_mat
	_dark_mat.shader = DARK_SHADER
	_up_mat.shader = UPSCALE_SHADER
	_quarter.transparent_bg = true
	_quarter.disable_3d = true
	_quarter.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_quarter.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	# Taille fixée dès la création (une cible de rendu de taille nulle est refusée par WebGL).
	_quarter.size = Vector2i((get_viewport_rect().size / 4.0).ceil()).max(Vector2i.ONE)
	_quarter_rect.size = Vector2(_quarter.size)
	add_child(_quarter)
	_quarter_rect.material = _dark_mat
	_quarter.add_child(_quarter_rect)
	_layer.layer = 1
	add_child(_layer)
	_dark.material = _up_mat
	_up_mat.set_shader_parameter("quarter", _quarter.get_texture())
	_dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_dark)
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_white = ImageTexture.create_from_image(img)


## Lueur d'une boule de feu : rayon en cases et teinte.
const FIREBALL_R := 5.5
## Rouge braise depuis la piste 4·B de la planche « Visibilité des balles » (avant : orange 255, 150, 60).
const FIREBALL := Color8(255, 86, 92)


static func flick(t: float, i: float, a: float = 0.06) -> float:
	return 1.0 + sin(t * 9.0 + i * 1.7) * a + sin(t * 23.0 + i) * a * 0.5


## collectLights (lighting.js) pour les éléments migrés ; les unités, bâtiments, tourelles et explosions
## arrivent par `providers` aux étapes suivantes.
func collect() -> Array[Dictionary]:
	var t := GameState.sim_time
	var L: Array[Dictionary] = []
	for p in providers:
		L.append_array(p.call())
	for torch in world.fog.road_torches:
		L.append({"x": torch.x, "z": torch.y, "r": 16.0 * flick(t, torch.y, 0.04), "rgb": WARM, "glow": 0.16})
	var core := CaveShape.CORE
	if GameState.orb_active:
		L.append({"x": core.x, "z": core.y, "r": 10.0 * flick(t, 1.0, 0.04), "rgb": ANCRE, "glow": 0.22})
	else:
		L.append({"x": core.x, "z": core.y, "r": 4.0 + GameState.orb_progress / ORB_TIME * 5.0, "rgb": ANCRE, "glow": 0.08})
	# Capsule (à la place du portail) : lumière froide une fois alimentée par l'Ancre.
	if Capsule.powered():
		L.append({"x": PORTAL.x, "z": PORTAL.y, "r": 9.0, "rgb": FROST, "glow": 0.18})
	# Pylônes de Merenor : lueur rouge de la nappe et de la pointe, blanche une fois canalisés.
	for p in world.terrain_state.portals:
		if p["active"]:
			var cover := float(p.get("cover", 1.0))
			var rgb := EVIL.lerp(Color8(235, 232, 222), 1.0 - cover)
			L.append({"x": p["x"], "z": p["z"] - 1.0, "r": 9.0 * flick(t, p["id"] + 3, 0.08), "rgb": rgb, "glow": 0.1})
			if cover > 0.0:
				L.append({"x": p["x"], "z": p["z"] + 2.0, "r": 13.0 * cover, "rgb": EVIL, "glow": 0.06 * cover})
	# Œil de la Matrice : lueur carmin de l'œil, plus vive quand il s'ouvre, et la salle qui en rougeoie.
	if OeilMatrice.active():
		var eye := TerrainState.eye_room_center()
		var open: float = OeilMatrice.run().get("open", 0.0)
		L.append({"x": eye.x, "z": eye.y - 6.0, "r": (14.0 + 8.0 * open) * flick(t, 77.0, 0.06), "rgb": EVIL, "glow": 0.1 + 0.12 * open})
		for dx: float in [-34.0, 34.0]:
			L.append({"x": eye.x + dx, "z": eye.y, "r": 12.0, "rgb": EVIL, "glow": 0.05})
	# Porte de chair de la frontière, tant qu'elle est fermée.
	var ts := world.terrain_state
	if ts.frontier and ts.eye_gate_closed and ts.is_gallery_open(0.0, TerrainState.eye_room_center().y):
		L.append({"x": 0.0, "z": TerrainState.frontier_z() + 3.0, "r": 9.0 * flick(t, 91.0, 0.08), "rgb": EVIL, "glow": 0.08})
	# Grappes de quartz du décor (style ardoise) : liste recalculée seulement quand le décor change.
	if _decor_version != world.decor.version:
		_decor_version = world.decor.version
		_decor_lights.clear()
		for e: Dictionary in world.decor.entries():
			if e.get("light", false):
				_decor_lights.append({"x": e["x"], "z": e["z"], "r": 4.5, "rgb": ArtStyle.QUARTZ_LIGHT, "glow": 0.14})
	L.append_array(_decor_lights)
	# Boules de feu des chiens de la Bête et des squelettes (sim/enemy_shots.gd) : petite lueur rouge qui vacille.
	for s: Dictionary in GameState.enemy_shots:
		if s["kind"] == "fire" and s.get("lit", true):
			L.append({"x": s["x"], "z": s["z"], "r": FIREBALL_R * flick(t, float(s["seed"] % 97), 0.12), "rgb": FIREBALL, "glow": 0.2})
	# Tirs de l'Arbalestrie : éclair de la couleur de la munition à la bouche du canon (fort pour Indra).
	for e: Dictionary in GameState.effects:
		if e["type"] != "xbow_fire":
			continue
		var strong: bool = e["ammo"] == "indra"
		var hold := 0.2 if strong else 0.12
		var age := float(e["age"])
		if age >= 0.0 and age < hold:
			L.append({"x": float(e["x"]) + 2.4 * float(e["face"]), "z": e["z"], "r": 8.0 if strong else 5.0,
				"rgb": CULT.get(e["ammo"], FROST), "glow": (0.3 if strong else 0.14) * (1.0 - age / hold)})
	L.append_array(fireflies(t))
	L.append_array(moonlit(t))
	return L


## La nuit, dehors : chaque ennemi vivant se détache un peu de l'ombre (sans lueur), pour rester lisible
## hors des halos. Ajoutés en dernier : ce sont les premiers écartés si les sources débordent.
const MOONLIT_R := 3.4
const MOONLIT_DIG := 0.42
func moonlit(t: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n := DayNight.night(t)
	if n < 0.2:
		return out
	for e: Enemy in GameState.enemies:
		if e.hp > 0.0 and CaveShape.outdoors(e.x, e.z):
			out.append({"x": e.x, "z": e.z - 0.6, "r": MOONLIT_R, "rgb": Color.BLACK, "glow": 0.0, "dig": MOONLIT_DIG * n})
	return out


## Lucioles de la jungle, la nuit : petites lueurs vertes qui dérivent près de la caméra.
func fireflies(t: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var n := DayNight.night(t) * (1.0 - Weather.rain())
	if n < 0.3:
		return out
	var cam: Vector2 = world.camera.cam
	var cell := 12.0
	var cx := floori(cam.x / cell)
	var cz := floori(cam.y / cell)
	for i in range(cx - 4, cx + 5):
		for j in range(cz - 3, cz + 4):
			var h := Rng.hash3(i, j, 0xf1ef)
			if h > 0.45 * n:
				continue
			var ph := Rng.hash3(i, j, 0x77) * TAU
			var x := (i + 0.5) * cell + sin(t * 0.4 + ph) * 4.0 + sin(t * 1.1 + ph * 2.0) * 1.2
			var z := (j + 0.5) * cell + cos(t * 0.33 + ph) * 3.0
			if z < CaveShape.mountain_edge(x) + 2.0:
				continue
			var blink := 0.5 + 0.5 * sin(t * 2.3 + ph * 3.0)
			if blink < 0.25:
				continue
			out.append({"x": x, "z": z, "r": 1.1 * blink * n, "rgb": FIREFLY, "glow": 0.5})
			if out.size() >= MAX_FIREFLIES:
				return out
	return out


func _process(_delta: float) -> void:
	_dark.visible = enabled
	visible = enabled
	_quarter.render_target_update_mode = SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
	if not enabled or world == null:
		return
	var screen := get_viewport_rect().size
	var qsize := (screen / 4.0).ceil()
	if Vector2(_quarter.size) != qsize:
		_quarter.size = Vector2i(qsize)
		_quarter_rect.size = qsize
	var px := world.camera.px
	var s := 8.0 * px
	var dark := PackedVector4Array()
	_glows.clear()
	for l in collect():
		if not world.fog.visible_at(Vector2(l["x"], l["z"])):
			continue
		var p := Proj.project(l["x"], 0.0, l["z"], world.camera.cam, px, screen)
		var pr: float = l["r"] * s
		if not (p.x > -pr and p.x < screen.x + pr and p.y > -pr and p.y < screen.y + pr):
			continue
		if dark.size() >= MAX_LIGHTS:
			break
		dark.append(Vector4(p.x / 4.0, p.y / 4.0, pr / 4.0, float(l.get("dig", 1.0))))
		var c: Color = l["rgb"]
		var w: float = l["glow"]
		if w > 0.0:
			_glows.append([p, pr * 0.8, Color(c.r * w, c.g * w, c.b * w, 1.0)])
	_dark_mat.set_shader_parameter("qsize", qsize)
	var sky := DayNight.sky(GameState.sim_time)
	var gloom := Weather.gloom()
	sky = Color(lerpf(sky.r, Weather.GREY.r, gloom * 3.0), lerpf(sky.g, Weather.GREY.g, gloom * 3.0), lerpf(sky.b, Weather.GREY.b, gloom * 3.0), minf(0.8, sky.a + gloom))
	_dark_mat.set_shader_parameter("sky", sky)
	_dark_mat.set_shader_parameter("edge_base", CaveShape.EDGE_BASE)
	_dark_mat.set_shader_parameter("edge_waves", CaveShape.EDGE_WAVES)
	_dark_mat.set_shader_parameter("edge_phase", CaveShape.EDGE_PHASE)
	# Ombres de nuages : légères par beau temps, marquées sous un ciel couvert ; aucune la nuit ni sous la pluie.
	var day := 1.0 - DayNight.night(GameState.sim_time)
	_dark_mat.set_shader_parameter("clouds", day * (1.0 - Weather.rain()) * clampf(0.3 + gloom * 5.0, 0.0, 1.0))
	_dark_mat.set_shader_parameter("cloud_time", GameState.sim_time)
	_dark_mat.set_shader_parameter("cam", world.camera.cam)
	_dark_mat.set_shader_parameter("px", float(px))
	_dark_mat.set_shader_parameter("screen", screen)
	_dark_mat.set_shader_parameter("lights", dark)
	_dark_mat.set_shader_parameter("light_count", dark.size())
	_up_mat.set_shader_parameter("screen_size", screen)
	_up_mat.set_shader_parameter("qsize", qsize)
	# Trame des paliers : ancrée au monde, point de trame = un pixel natif.
	for m: ShaderMaterial in [_up_mat, _glow_mat]:
		m.set_shader_parameter("px", float(px))
		m.set_shader_parameter("origin", world.position)
	queue_redraw()


## Une lueur par source : carré circonscrit au disque de rayon 0,8·r (pixels d'écran → pixels natifs).
func _draw() -> void:
	if not enabled or world == null:
		return
	var px := float(world.camera.px)
	for g: Array in _glows:
		var c: Vector2 = g[0] / px - world.native_offset
		var r: float = g[1] / px
		draw_texture_rect(_white, Rect2(c - Vector2(r, r), Vector2(2.0 * r, 2.0 * r)), false, g[2])
