extends CharacterBody2D

@export var speed: float = 300.0
@export var horn_cooldown: float = 5.0
@export var max_warriors: int = 5
@export var max_health: float = 100.0
@export var dodge_speed: float = 500.0
@export var dodge_duration: float = 0.2
@export var bob_height: float = 3.0
@export var bob_speed: float = 12.0

var can_summon: bool = true
var active_warriors: int = 0
var health: float
var is_dodging: bool = false
var bob_time: float = 0.0
var original_position: Vector2

@onready var sprite: Sprite2D = $Sprite2D
@onready var horn_sprite: Sprite2D = $Sprite2D/HornSprite 
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
	original_position = sprite.position
	
	# Hide horn initially
	if horn_sprite:
		horn_sprite.scale = Vector2.ZERO
		horn_sprite.modulate.a = 0.0

func _physics_process(delta):
	if is_dodging:
		move_and_slide()
		return
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * speed
	
	if velocity.length() > 0:
		sprite.flip_h = velocity.x < 0
		
		# Walking bob animation
		bob_time += delta * bob_speed
		var bob_offset = sin(bob_time) * bob_height
		sprite.position.y = original_position.y + bob_offset
		
		# Slight horizontal squash and stretch for walking feel
		var squash = 1.0 + sin(bob_time * 2) * 0.05
		sprite.scale = Vector2(1.0 / squash, squash)
	else:
		# Reset to idle
		bob_time = 0.0
		sprite.position.y = lerp(sprite.position.y, original_position.y, delta * 10.0)
		sprite.scale = lerp(sprite.scale, Vector2.ONE, delta * 10.0)
	
	# Remove rotation, keep sprite upright
	sprite.rotation = 0.0
	
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
	# Player lift animation
	var player_tween = create_tween()
	player_tween.set_parallel(true)
	player_tween.tween_property(sprite, "position:y", original_position.y - 10, 0.15)
	player_tween.tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.15)
	player_tween.chain().tween_property(sprite, "position:y", original_position.y, 0.25)
	player_tween.parallel().tween_property(sprite, "scale", Vector2.ONE, 0.25)
	
	# Horn zoom animation based on player direction
	if horn_sprite:
		horn_sprite.scale = Vector2.ZERO
		horn_sprite.modulate.a = 0.0
		
		# Determine direction: if facing left, zoom left (negative X), if right, zoom right (positive X)
		var zoom_direction = -1.0 if sprite.flip_h else 1.0
		
		var horn_tween = create_tween()
		horn_tween.set_parallel(true)
		
		# Horn zooms horizontally in the direction player is facing
		horn_tween.tween_property(horn_sprite, "scale:x", 1.5 * zoom_direction, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		horn_tween.tween_property(horn_sprite, "scale:y", 1.5, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		horn_tween.tween_property(horn_sprite, "modulate:a", 1.0, 0.1)
		
		# Hold for a moment
		horn_tween.chain().tween_property(horn_sprite, "scale:x", 1.3 * zoom_direction, 0.15)
		horn_tween.parallel().tween_property(horn_sprite, "scale:y", 1.3, 0.15)
		
		# Horn disappears
		horn_tween.chain().tween_property(horn_sprite, "scale", Vector2.ZERO, 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		horn_tween.parallel().tween_property(horn_sprite, "modulate:a", 0.0, 0.15)

func dodge():
	is_dodging = true
	var dodge_dir = velocity.normalized()
	if dodge_dir == Vector2.ZERO:
		dodge_dir = Vector2.RIGHT if not sprite.flip_h else Vector2.LEFT
	
	velocity = dodge_dir * dodge_speed
	
	# Dodge animation - quick dash with trail effect
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.5, dodge_duration * 0.3)
	tween.tween_property(sprite, "scale", Vector2(1.3, 0.8), dodge_duration * 0.3)
	
	tween.chain().tween_property(sprite, "modulate:a", 1.0, dodge_duration * 0.7)
	tween.parallel().tween_property(sprite, "scale", Vector2.ONE, dodge_duration * 0.7)
	
	await get_tree().create_timer(dodge_duration).timeout
	is_dodging = false
	sprite.position = original_position

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
	
	# Flash red and knockback feel
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "position:x", sprite.position.x + (5 if sprite.flip_h else -5), 0.1)
	tween.tween_property(sprite, "scale", Vector2(1.2, 0.8), 0.1)
	
	tween.chain().tween_property(sprite, "modulate", Color.WHITE, 0.2)
	tween.parallel().tween_property(sprite, "position:x", original_position.x, 0.2)
	tween.parallel().tween_property(sprite, "scale", Vector2.ONE, 0.2)

func die():
	# Death animation - fall down
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.8)
	tween.tween_property(sprite, "scale", Vector2(1.5, 0.2), 0.8)
	tween.tween_property(sprite, "position:y", sprite.position.y + 20, 0.8)
	
	await tween.finished
	get_tree().reload_current_scene()
