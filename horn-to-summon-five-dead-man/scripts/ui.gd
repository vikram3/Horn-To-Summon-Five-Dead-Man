extends CanvasLayer

@onready var warrior_count_label: Label = $MarginContainer/VBoxContainer/WarriorCount
@onready var cooldown_progress: ProgressBar = $MarginContainer/VBoxContainer/CooldownBar
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var score_label: Label = $MarginContainer/VBoxContainer/Score

var player: Node2D
var score: int = 0

func _ready():
	player = get_tree().get_first_node_in_group("player")
	if player:
		player.warrior_count_changed.connect(_on_warrior_count_changed)
		player.health_changed.connect(_on_health_changed)
	
	# Initial health bar setup
	if health_bar:
		health_bar.max_value = 100
		health_bar.value = 100

func _process(delta):
	if player and player.has_node("HornTimer"):
		var timer = player.get_node("HornTimer")
		if timer.time_left > 0:
			cooldown_progress.value = (1 - timer.time_left / timer.wait_time) * 100
			cooldown_progress.modulate = Color(1.0, 0.5, 0.5)
		else:
			cooldown_progress.value = 100
			cooldown_progress.modulate = Color(0.5, 1.0, 0.5)

func _on_warrior_count_changed(count: int):
	warrior_count_label.text = "Warriors: %d / %d" % [count, player.max_warriors]
	
	# Flash animation
	var tween = create_tween()
	tween.tween_property(warrior_count_label, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(warrior_count_label, "scale", Vector2.ONE, 0.1)

func _on_health_changed(health: float, max_health: float):
	if not health_bar:
		return
	
	var percentage = (health / max_health) * 100.0
	
	# Animate health bar
	var tween = create_tween()
	tween.tween_property(health_bar, "value", percentage, 0.2)
	
	# Change color based on health
	if percentage > 60:
		health_bar.modulate = Color(0.5, 1.0, 0.5)
	elif percentage > 30:
		health_bar.modulate = Color(1.0, 1.0, 0.5)
	else:
		health_bar.modulate = Color(1.0, 0.5, 0.5)

func add_score(points: int):
	score += points
	if score_label:
		score_label.text = "Score: %d" % score
		
		# Score pop animation
		var tween = create_tween()
		tween.tween_property(score_label, "scale", Vector2(1.3, 1.3), 0.1)
		tween.tween_property(score_label, "scale", Vector2.ONE, 0.1)
