extends "res://tests/test_case.gd"
## Minerais « Nodules affleurants » : le minerai se voit sur le dessus de la case (OreView, nodules.png)
## et sur son flanc, calque OreFace posé par World sur la paroi face5 qui apparaît quand on creuse au sud.

const SEED := 20261114
const Blocks := preload("res://data/mineable_blocks.gd")


func _world() -> Array:
	var main := shared_main()
	var sim: Simulation = main.get_node("Simulation")
	sim.paused = true
	sim.new_game(SEED)
	return [main, main.get_node("World")]


## Paroi face5 posée en haut de la case creusée `below` (null si aucune).
func _face_at(world: World, below: Vector2i) -> Node:
	for e: Dictionary in world.decor.entries():
		if String(e.get("s", "")).begins_with("face5_") and e.has("node") \
				and floori(e["bx"] / 4.0) == below.x and floori(e["bz"] / 4.0) == below.y:
			return (e["node"] as Node).get_child(0)
	return null


func _solid(ts: TerrainState, k: Vector2i) -> bool:
	return not ts.walkable(k.x * 4 + 2.0, k.y * 4 + 2.0) and not ts.is_gallery(k.x * 4 + 2.0, k.y * 4 + 2.0)


func test_ore_flank_appears_and_leaves_with_the_cell() -> void:
	var got := _world()
	var main: Node = got[0]
	var world: World = got[1]
	var ts := world.terrain_state
	var ore := Vector2i(999, 999)
	for k: Vector2i in ts.block_types:
		var below := k + Vector2i.DOWN
		if Blocks.ORES.has(ts.block_types[k]) and not ts.permanent_ores.has(k) and _solid(ts, k) \
				and _solid(ts, below) and not ts.block_types.has(below) and k != TerrainState.VAULT_COPPER:
			ore = k
			break
	check(ore != Vector2i(999, 999), "un filon avec de la roche pleine au sud")
	var below := ore + Vector2i.DOWN
	world.dig_cell(below.x, below.y)
	var face := _face_at(world, below)
	check(face != null, "une paroi apparaît au-dessus de la case creusée")
	check(face.has_node("OreFace"), "la paroi d'un filon montre le minerai")
	var layer := face.get_node("OreFace") as Sprite2D
	var column := Blocks.ORES.find(ts.block_types[ore])
	check_eq(layer.region_rect, Rect2(column * 32, 0, 32, 49), "colonne du minerai, ligne filon")
	check_eq(layer.offset, (face as Sprite2D).offset, "calque calé sur la paroi")
	world.dig_cell(ore.x, ore.y)
	check(_face_at(world, below) == null, "creuser le filon retire sa paroi et son calque")


func test_plain_rock_flank_has_no_ore() -> void:
	var got := _world()
	var main: Node = got[0]
	var world: World = got[1]
	var ts := world.terrain_state
	var rock := Vector2i(999, 999)
	for j in range(-60, -30):
		for i in range(-40, -18):
			var k := Vector2i(i, j)
			if _solid(ts, k) and _solid(ts, k + Vector2i.DOWN) and not ts.block_types.has(k) \
					and not ts.block_types.has(k + Vector2i.DOWN):
				rock = k
				break
		if rock != Vector2i(999, 999):
			break
	check(rock != Vector2i(999, 999), "une case de roche simple")
	world.dig_cell(rock.x, rock.y + 1)
	var face := _face_at(world, rock + Vector2i.DOWN)
	check(face != null and not face.has_node("OreFace"), "paroi de roche simple sans minerai")


func test_ore_atlas_layout() -> void:
	var top: Texture2D = load("res://assets/ardoise/world/nodules.png")
	var faces: Texture2D = load("res://assets/ardoise/world/ore_faces.png")
	check_eq(top.get_size(), Vector2(128, 96), "dessus : 4 minerais × filon, gisement, icône")
	check_eq(faces.get_size(), Vector2(128, 98), "flancs : 4 minerais × filon, gisement")
