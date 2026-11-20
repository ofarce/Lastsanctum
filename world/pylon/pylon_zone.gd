class_name PylonZone
extends Sprite2D
## Nappe de corruption d'un Pylône de Merenor, au sol sous les objets triés (shaders/pylon_corruption.gdshader).
## Bruit local cuit dans la texture (un échantillon par demi-unité), lobes et flaques de Pylons.zone, masque
## du sol découvert par case, recalculé quand le terrain change. Même forme que Pylons.edge (dégâts).

const SHADER := preload("res://shaders/pylon_corruption.gdshader")
## Échantillons du bruit local par unité de monde.
const LOC_RES := 2

var state: TerrainState
var pylon: Dictionary
var _mat := ShaderMaterial.new()
var _version := -1
var _cells := 0


func setup(terrain_state: TerrainState, p: Dictionary) -> void:
	state = terrain_state
	pylon = p
	name = "PylonZone_%d" % int(p["id"])
	var ext := Pylons.EXTENT
	var n := int(ext * 2.0 * LOC_RES)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var x0 := float(p["x"]) - ext
	var z0 := float(p["z"]) - ext
	for j in n:
		for i in n:
			var v := Pylons.local_noise(p, x0 + (i + 0.5) / LOC_RES, z0 + (j + 0.5) / LOC_RES) + 0.5
			img.set_pixel(i, j, Color(v, 0, 0, 1))
	texture = ImageTexture.create_from_image(img)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	centered = false
	scale = Vector2.ONE * (8.0 / LOC_RES)
	position = Proj.nat(x0, 0.0, z0)
	var Z := Pylons.zone(p)
	var table: PackedFloat32Array = Z["table"]
	var lob := Image.create(table.size(), 1, false, Image.FORMAT_RF)
	for k in table.size():
		lob.set_pixel(k, 0, Color(table[k] / 32.0, 0, 0))
	var sats := PackedVector4Array()
	for s: Vector3 in Z["sats"]:
		sats.append(Vector4(s.x, s.y, s.z, 0.0))
	_mat.shader = SHADER
	_mat.set_shader_parameter("size", ext * 16.0)
	_mat.set_shader_parameter("extent", ext)
	_mat.set_shader_parameter("origin_px", position)
	_mat.set_shader_parameter("lobes", ImageTexture.create_from_image(lob))
	_mat.set_shader_parameter("sats", sats)
	material = _mat
	_cells = int(ext * 2.0 / 4.0)
	_update_mask()


## Sol découvert, case par case (la nappe ne monte pas sur la roche).
func _update_mask() -> void:
	_version = state.version
	var img := Image.create(_cells, _cells, false, Image.FORMAT_L8)
	var x0 := float(pylon["x"]) - Pylons.EXTENT
	var z0 := float(pylon["z"]) - Pylons.EXTENT
	for j in _cells:
		for i in _cells:
			var on := state.ground(x0 + i * 4.0 + 2.0, z0 + j * 4.0 + 2.0)
			img.set_pixel(i, j, Color.WHITE if on else Color.BLACK)
	_mat.set_shader_parameter("ground_mask", ImageTexture.create_from_image(img))


func _process(_delta: float) -> void:
	var cover := float(pylon.get("cover", 1.0))
	visible = bool(pylon.get("active", false)) and cover > 0.0
	if not visible:
		return
	if state.version != _version:
		_update_mask()
	_mat.set_shader_parameter("cover", cover)
