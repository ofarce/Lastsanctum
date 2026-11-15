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
const CULT_OF := {"sigil": "sigil", "library": "sigil", "aether": "aether", "forge": "aether", "workshop": "aether",
	"medeina": "medeina", "bedroom": "medeina", "soulwell": "medeina", "indra": "indra", "caserne": "indra"}
const PORTAL := Vector2(0.0, -167.7)
const DEITY_X := {"indra": -41.0, "sigil": -24.0, "medeina": 24.0, "aether": 41.0}
const ORB_TIME := 8.0

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


static func flick(t: float, i: float, a: float = 0.06) -> float:
	return 1.0 + sin(t * 9.0 + i * 1.7) * a + sin(t * 23.0 + i) * a * 0.5


## collectLights (lighting.js) pour les éléments migrés ; les unités, bâtiments, tourelles et explosions
## arrivent par `providers` aux étapes suivantes.
func collect() -> Array[Dictionary]:
	var t := GameState.sim_time
	var L: Array[Dictionary] = []
	for p in providers:
		L.append_array(p.call())
	var core := CaveShape.CORE
	if GameState.orb_active:
		L.append({"x": core.x, "z": core.y, "r": 10.0 * flick(t, 1.0, 0.04), "rgb": ANCRE, "glow": 0.22})
	else:
		L.append({"x": core.x, "z": core.y, "r": 4.0 + GameState.orb_progress / ORB_TIME * 5.0, "rgb": ANCRE, "glow": 0.08})
	L.append({"x": PORTAL.x, "z": PORTAL.y, "r": 9.0, "rgb": FROST, "glow": 0.18})
	for p in world.terrain_state.portals:
		if p["active"]:
			L.append({"x": p["x"], "z": p["z"] + 1.0, "r": 8.0 * flick(t, p["id"] + 3, 0.08), "rgb": EVIL, "glow": 0.22})
	for id: String in DEITY_X:
		var x: float = DEITY_X[id]
		L.append({"x": x, "z": PORTAL.y + 1.0, "r": 5.5 * flick(t, x), "rgb": CULT[id], "glow": 0.16})
	# Grappes de quartz du décor (style ardoise) : liste recalculée seulement quand le décor change.
	if _decor_version != world.decor.version:
		_decor_version = world.decor.version
		_decor_lights.clear()
		for e: Dictionary in world.decor.entries():
			if e.get("light", false):
				_decor_lights.append({"x": e["x"], "z": e["z"], "r": 4.5, "rgb": ArtStyle.QUARTZ_LIGHT, "glow": 0.14})
	L.append_array(_decor_lights)
	return L


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
		var p := Proj.project(l["x"], 0.0, l["z"], world.camera.cam, px, screen)
		var pr: float = l["r"] * s
		if not (p.x > -pr and p.x < screen.x + pr and p.y > -pr and p.y < screen.y + pr):
			continue
		if dark.size() >= MAX_LIGHTS:
			break
		dark.append(Vector4(p.x / 4.0, p.y / 4.0, pr / 4.0, 0.0))
		var c: Color = l["rgb"]
		var w: float = l["glow"]
		_glows.append([p, pr * 0.8, Color(c.r * w, c.g * w, c.b * w, 1.0)])
	_dark_mat.set_shader_parameter("qsize", qsize)
	_dark_mat.set_shader_parameter("lights", dark)
	_dark_mat.set_shader_parameter("light_count", dark.size())
	_up_mat.set_shader_parameter("screen_size", screen)
	_up_mat.set_shader_parameter("qsize", qsize)
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
