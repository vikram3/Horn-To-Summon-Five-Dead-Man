extends Node

@export var warrior_scene: PackedScene
@export var enemy_scene: PackedScene
@export var enemy_spawn_interval: float = 5.0
@export var max_enemies: int = 10

var player: Node2D
var enemies_spawned: int = 0

@onready var spawn_timer: Timer = $SpawnTimer

func _ready():
	player = get_tree().get_first_node_in_group("player")
	if player:
		player.horn_blown.connect(_on_horn_blown)
	
	spawn_timer.wait_time = enemy_spawn_interval
	spawn_timer.timeout.connect(_spawn_enemy)
	spawn_timer.start()

func _on_horn_blown(position: Vector2):
	if not warrior_scene:
		return
	
	var warrior = warrior_scene.instantiate()
	warrior.global_position = position
	warrior.add_to_group("warrior")
	get_tree().root.add_child(warrior)

func _spawn_enemy():
	if get_tree().get_nodes_in_group("enemy").size() >= max_enemies:
		return
	
	if not enemy_scene or not player:
		return
	
	var spawn_offset = Vector2(randf_range(-400, 400), randf_range(-400, 400))
	var spawn_pos = player.global_position + spawn_offset
	
	var enemy = enemy_scene.instantiate()
	enemy.global_position = spawn_pos
	get_tree().root.add_child(enemy)
	
	enemies_spawned += 1
