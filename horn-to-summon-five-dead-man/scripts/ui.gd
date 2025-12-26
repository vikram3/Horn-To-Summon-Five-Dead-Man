extends CanvasLayer

@onready var warrior_count_label: Label = $MarginContainer/VBoxContainer/WarriorCount
@onready var cooldown_progress: ProgressBar = $MarginContainer/VBoxContainer/CooldownBar

var player: Node2D

func _ready():
	player = get_tree().get_first_node_in_group("player")
	if player:
		player.warrior_count_changed.connect(_on_warrior_count_changed)

func _process(delta):
	if player and player.has_node("HornTimer"):
		var timer = player.get_node("HornTimer")
		if timer.time_left > 0:
			cooldown_progress.value = (1 - timer.time_left / timer.wait_time) * 100
		else:
			cooldown_progress.value = 100

func _on_warrior_count_changed(count: int):
	warrior_count_label.text = "Warriors: %d / %d" % [count, player.max_warriors]
