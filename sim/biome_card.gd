class_name BiomeCard
extends RefCounted
## Carton d'entrée de biome (demande du 2026-11-25) : le nom du biome au milieu de l'écran, dans le style du carton
## « Jour 1 » de l'ouverture (ui/cinema/cinema_layer.gd), chaque fois que l'Exilé (incarné, sinon l'Ingénieur) entre
## dans un biome depuis un autre ou depuis la base. Valable pour tous les biomes.
##
## Où commence un biome : dans la bande de son plan en salles (Temple, Salles oubliées) ; pour les biomes sans plan,
## au nord de la frontière du précédent. La base, la jungle et le sanctum ne comptent dans aucun biome (-1).

## Durée du carton (secondes de jeu) : fondu d'entrée, tenue, fondu de sortie.
const DUR := 3.4
const FADE := 0.5


## Biome où se tient `p` (index de Biomes.LIST), -1 hors biome.
static func biome_at(st: TerrainState, p: Vector2) -> int:
	var c := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
	for k in 2:
		var lay: Dictionary = st.temple_layout if k == 0 else st.veines_layout
		if not lay.is_empty() and (lay["band"] as Rect2i).has_point(c):
			return k
	if p.y < Biomes.north_z(1):
		return Biomes.index_at(p.y)
	if p.y < TerrainState.frontier_z() and st.veines_layout.is_empty():
		return 1
	return -1


static func tick(sim: Simulation) -> void:
	var st := sim.state()
	if st == null or GameState.ended or Opening.cinematic():
		return
	var u: Unit = GameState.incarnated if GameState.incarnated != null else Capsule.engineer()
	if u == null or not u.alive() or u.hidden:
		return
	var b := biome_at(st, u.pos())
	if b == GameState.biome_last:
		return
	GameState.biome_last = b
	if b >= 0:
		GameState.biome_card = {"name": String(Biomes.LIST[b]["name"]), "at": GameState.sim_time}


## Carton à afficher : [texte, opacité] ou [].
static func card() -> Array:
	var c: Dictionary = GameState.biome_card
	if c.is_empty():
		return []
	var t := GameState.sim_time - float(c["at"])
	if t < 0.0 or t > DUR:
		return []
	var a := clampf(minf(t / FADE, (DUR - t) / FADE), 0.0, 1.0)
	return [c["name"], a] if a > 0.0 else []
