extends Node2D

const NODULES := preload("res://assets/ardoise/world/nodules.png")
const Blocks := preload("res://data/mineable_blocks.gd")

var state: TerrainState
var cell: Vector2i
var region: Rect2
var phase: float


func setup(terrain_state: TerrainState, key: Vector2i) -> void:
	state = terrain_state
	cell = key
	position = Vector2(key * 32 + Vector2i(16, 16))
	var column := Blocks.ORES.find(state.block_types[key])
	var row := 1 if state.permanent_ores.has(key) else 0
	region = Rect2(column * 32, row * 32, 32, 32)
	phase = Rng.hash3(key.x, key.y, state.seed) * TAU
	visible = cell != TerrainState.VAULT_COPPER or state.vault_open


func _process(_delta: float) -> void:
	if state.dug.has(cell):
		queue_free()
		return
	visible = cell != TerrainState.VAULT_COPPER or state.vault_open
	if visible:
		queue_redraw()


func _draw() -> void:
	draw_texture_rect_region(NODULES, Rect2(-16, -16, 32, 32), region)
	var light := clampf((sin(GameState.sim_time * 1.65 + phase) - 0.90) * 10.0, 0.0, 1.0)
	if light > 0.0:
		var glint := Color(1, 0.96, 0.87, light * 0.85)
		draw_rect(Rect2(-5, -3, 3, 1), glint)
		draw_rect(Rect2(-4, -4, 1, 3), glint)
