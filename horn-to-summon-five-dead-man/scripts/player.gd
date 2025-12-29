extends CharacterBody2D

@export var speed: float = 300.0
@export var horn_cooldown: float = 5.0
@export var max_warriors: int = 5
@export var max_health: float = 100.0
@export var dodge_speed: float = 500.0
@export var dodge_duration: float = 0.2

var can_summon: bool = true
var active_warriors: int = 0
var health: float
var is_dodging: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var summon_marker: Marker2D = $SummonMarker
@onready var horn_timer: Timer = $HornTimer
@onready var hit_particles: CPUParticles2D = $HitParticles if has_node("HitParticles") else null

signal horn_blown(position: Vector2)
signal warrior_count_changed(count: int)
signal health_changed(health: float, max_health: float)

func _ready():
	health = max_health
	add_to_group("player")
	horn_timer.wait_time = horn_cooldown
	horn_timer.timeout.connect(_on_horn_cooldown_complete)
	sprite.modulate = Color.WHITE

func _physics_process(delta):
	if is_dodging:
		move_and_slide()
		return
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * speed
	
	if velocity.length() > 0:
		sprite.flip_h = velocity.x < 0
		# Slight tilt when moving
		sprite.rotation = lerp(sprite.rotation, velocity.x * 0.05, delta * 5.0)
	else:
		sprite.rotation = lerp(sprite.rotation, 0.0, delta * 8.0)
	
	move_and_slide()

func _input(event):
	if event.is_action_pressed("summon_horn") and can_summon and active_warriors < max_warriors:
		blow_horn()
	
	if event.is_action_pressed("ui_accept") and not is_dodging:
		dodge()

func blow_horn():
	can_summon = false
	horn_timer.start()
	
	var summon_pos = summon_marker.global_position
	horn_blown.emit(summon_pos)
	
	active_warriors += 1
	warrior_count_changed.emit(active_warriors)
	
	# Horn animation
	animate_horn_blow()
	if has_node("HornSound"):
		$HornSound.play()

func animate_horn_blow():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "rotation", -0.3, 0.1)
	tween.tween_property(sprite, "scale", Vector2(1.2, 0.9), 0.1)
	tween.chain().tween_property(sprite, "rotation", 0.0, 0.2)
	tween.parallel().tween_property(sprite, "scale", Vector2.ONE, 0.2)

func dodge():
	is_dodging = true
	var dodge_dir = velocity.normalized()
	if dodge_dir == Vector2.ZERO:
		dodge_dir = Vector2.RIGHT if not sprite.flip_h else Vector2.LEFT
	
	velocity = dodge_dir * dodge_speed
	
	# Dodge animation
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.5, dodge_duration * 0.5)
	tween.tween_property(sprite, "modulate:a", 1.0, dodge_duration * 0.5)
	
	await get_tree().create_timer(dodge_duration).timeout
	is_dodging = false

func _on_horn_cooldown_complete():
	can_summon = true

func on_warrior_died():
	active_warriors = max(0, active_warriors - 1)
	warrior_count_changed.emit(active_warriors)

func take_damage(amount: float):
	if is_dodging:
		return
	
	health -= amount
	health_changed.emit(health, max_health)
	
	# Hit animation
	animate_hit()
	
	if hit_particles:
		hit_particles.emitting = true
	
	if health <= 0:
		die()

func animate_hit():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "rotation", 0.4, 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.1)
	tween.chain().tween_property(sprite, "modulate", Color.WHITE, 0.1)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.1)
	tween.parallel().tween_property(sprite, "scale", Vector2.ONE, 0.1)

func die():
	# Death animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "rotation", PI * 2, 0.5)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_property(sprite, "scale", Vector2.ZERO, 0.5)
	
	await tween.finished
	get_tree().reload_current_scene()
