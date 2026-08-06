class_name MapData
extends Resource

## La carte = une donnée. La 3D n'est qu'une vue reconstruite depuis elle.

@export var meta_name := "Nouvelle Carte"
@export var meta_author := ""
@export var grid_cell_size := 2.0
@export var grid_dimensions := Vector2i(64, 64)
@export var blocks: Array[Dictionary] = []
# Champs M3 (déjà sérialisés, outillés plus tard) :
@export var player_spawns: Array[Vector3] = []
@export var enemy_spawns: Array[Vector3] = []
@export var enemy_paths: Array[Dictionary] = []
@export var units: Array[Dictionary] = []
@export var base_position := Vector3.ZERO
@export var buildable_zones: Array[Rect2] = []
