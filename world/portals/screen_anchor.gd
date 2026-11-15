class_name ScreenAnchor
extends Node2D
## Point du monde aligné sur la grille native de l'ÉCRAN, comme natP(x, 0, z) du prototype :
## round(nat + décalage caméra). Utilisé pour les portails, dessinés avec une transformation
## (cisaillement, échelle) que le shader d'alignement ne peut pas traiter.
## Placé sous un emplacement (slot) du décor ; World appelle place() à chaque changement de vue.

var world_xz := Vector2.ZERO


## `native_offset` : décalage caméra en pixels natifs (Proj.camera_offset).
func place(native_offset: Vector2) -> void:
	var n := Proj.nat(world_xz.x, 0.0, world_xz.y) + native_offset
	var snapped := Vector2(floorf(n.x + 0.5), floorf(n.y + 0.5)) - native_offset
	var parent_pos := (get_parent() as Node2D).position if get_parent() is Node2D else Vector2.ZERO
	position = snapped - parent_pos
