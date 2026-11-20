class_name GorgeMarks
extends Node2D
## Annonces de Gorge-Cuivre (cercles de la Percée et de la Pluie, ligne du sillon, blocs qui tombent) au-dessus des
## sprites : enfant du monde juste après le tri en profondeur, comme OeilFxAir (bilan « Visibilité des balles »,
## 2026-11-20). Repère : pixels natifs du monde. Dessin : GorgeView.draw_marks.

var world: World


func _process(_delta: float) -> void:
	var r := Gorge.run()
	visible = Gorge.boss() != null and (not (r.get("marks", []) as Array).is_empty() or r.has("furrow"))
	if visible:
		queue_redraw()


func _draw() -> void:
	GorgeView.draw_marks(self, world, Gorge.run(), GameState.sim_time)
