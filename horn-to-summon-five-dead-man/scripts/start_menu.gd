extends Control

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var background: TextureRect = $Background

var title_bob_time: float = 0.0

func _ready():
	# Connect button signals
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Fade in animation
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	
	# Title bounce animation
	title_label.scale = Vector2.ZERO
	var title_tween = create_tween()
	title_tween.tween_property(title_label, "scale", Vector2.ONE, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

func _process(delta):
	# Animate title with gentle floating motion
	title_bob_time += delta
	var bob_offset = sin(title_bob_time * 2.0) * 5.0
	title_label.position.y = title_label.position.y - (title_label.position.y - bob_offset) * delta * 2.0

func _on_start_pressed():
	# Button press animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_property(start_button, "scale", Vector2(1.2, 1.2), 0.15)
	
	await tween.finished
	
	# Change to main game scene
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_quit_pressed():
	# Button press animation
	var tween = create_tween()
	tween.tween_property(quit_button, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(quit_button, "scale", Vector2.ONE, 0.1)
	
	await tween.finished
	
	# Quit game
	get_tree().quit()
