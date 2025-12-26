extends CharacterBody2D

@export var speed: float = 300.0
@export var horn_cooldown: float = 5.0
@export var max_warriors: int = 5

var can_summon: bool = true
var active_warriors: int = 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var summon_marker: Marker2D = $SummonMarker
@onready var horn_timer: Timer = $HornTimer

signal horn_blown(position: Vector2)
signal warrior_count_changed(count: int)

func _ready():
	horn_timer.wait_time = horn_cooldown
	horn_timer.timeout.connect(_on_horn_cooldown_complete)

func _physics_process(delta):
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * speed
	
	if velocity.length() > 0:
		sprite.flip_h = velocity.x < 0
	
	move_and_slide()

func _input(event):
	if event.is_action_pressed("summon_horn") and can_summon and active_warriors < max_warriors:
		blow_horn()

func blow_horn():
	can_summon = false
	horn_timer.start()
	
	var summon_pos = summon_marker.global_position
	horn_blown.emit(summon_pos)
	
	active_warriors += 1
	warrior_count_changed.emit(active_warriors)
	
	# Visual/Audio feedback
	$AnimationPlayer.play("horn_blow") if has_node("AnimationPlayer") else null
	$HornSound.play() if has_node("HornSound") else null

func _on_horn_cooldown_complete():
	can_summon = true

func on_warrior_died():
	active_warriors = max(0, active_warriors - 1)
	warrior_count_changed.emit(active_warriors)
