extends CharacterBody2D

enum State { IDLE, FOLLOW, ATTACK, DEAD }

@export var speed: float = 250.0
@export var follow_distance: float = 150.0
@export var attack_range: float = 50.0
@export var detection_range: float = 300.0
@export var attack_damage: float = 25.0
@export var attack_cooldown: float = 1.0
@export var max_health: float = 100.0

var current_state: State = State.IDLE
var player: Node2D
var target_enemy: Node2D
var health: float
var can_attack: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_timer: Timer = $AttackTimer

func _ready():
	health = max_health
	add_to_group("warrior")
	player = get_tree().get_first_node_in_group("player")
	attack_timer.wait_time = attack_cooldown
	attack_timer.timeout.connect(_on_attack_cooldown_complete)
	
	# Spawn animation
	sprite.scale = Vector2.ZERO
	sprite.modulate = Color(0.5, 0.8, 1.0)
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _physics_process(delta):
	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.FOLLOW:
			_state_follow(delta)
		State.ATTACK:
			_state_attack(delta)
		State.DEAD:
			return
	
	move_and_slide()

func _state_idle(delta):
	sprite.rotation = lerp(sprite.rotation, 0.0, delta * 8.0)
	
	# Always look for enemies
	find_nearest_enemy()
	
	if not player:
		return
	
	var dist_to_player = global_position.distance_to(player.global_position)
	if dist_to_player > follow_distance:
		current_state = State.FOLLOW

func _state_follow(delta):
	# Always look for enemies while following
	find_nearest_enemy()
	
	if target_enemy and is_instance_valid(target_enemy):
		current_state = State.ATTACK
		return
	
	if not player:
		return
	
	var dist_to_player = global_position.distance_to(player.global_position)
	if dist_to_player <= follow_distance:
		current_state = State.IDLE
		velocity = Vector2.ZERO
	else:
		var direction = global_position.direction_to(player.global_position)
		velocity = direction * speed
		sprite.flip_h = direction.x < 0
		# Running tilt
		sprite.rotation = lerp(sprite.rotation, direction.x * 0.1, delta * 5.0)

func _state_attack(delta):
	if not target_enemy or not is_instance_valid(target_enemy):
		target_enemy = null
		current_state = State.FOLLOW
		return
	
	var dist = global_position.distance_to(target_enemy.global_position)
	
	# If enemy too far, go back to following
	if dist > detection_range:
		target_enemy = null
		current_state = State.FOLLOW
		return
	
	# Chase enemy if not in attack range
	if dist > attack_range:
		var direction = global_position.direction_to(target_enemy.global_position)
		velocity = direction * speed
		sprite.flip_h = direction.x < 0
		sprite.rotation = lerp(sprite.rotation, 0.0, delta * 8.0)
	else:
		# In range, stop and attack
		velocity = Vector2.ZERO
		if can_attack:
			perform_attack()

func find_nearest_enemy():
	var enemies = get_tree().get_nodes_in_group("enemy")
	
	var closest_dist = detection_range
	var closest_enemy = null
	
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = global_position.distance_to(enemy.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest_enemy = enemy
	
	# Only switch target if we found a closer one or don't have a target
	if closest_enemy and (not target_enemy or closest_dist < global_position.distance_to(target_enemy.global_position)):
		target_enemy = closest_enemy
		if current_state != State.ATTACK:
			current_state = State.ATTACK

func perform_attack():
	can_attack = false
	attack_timer.start()
	
	if target_enemy and is_instance_valid(target_enemy) and target_enemy.has_method("take_damage"):
		target_enemy.take_damage(attack_damage)
	
	# Attack animation - swing down
	var attack_dir = 1 if not sprite.flip_h else -1
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "rotation", attack_dir * 0.6, 0.15).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sprite, "scale", Vector2(1.2, 0.9), 0.15)
	tween.chain().tween_property(sprite, "rotation", attack_dir * -0.2, 0.15).set_trans(Tween.TRANS_BOUNCE)
	tween.parallel().tween_property(sprite, "scale", Vector2.ONE, 0.15)
	tween.chain().tween_property(sprite, "rotation", 0.0, 0.2)
	
	if has_node("AttackSound"):
		$AttackSound.play()

func _on_attack_cooldown_complete():
	can_attack = true

func take_damage(amount: float):
	health -= amount
	
	# Hit animation - recoil back
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "rotation", -0.3, 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.85, 1.15), 0.1)
	tween.chain().tween_property(sprite, "modulate", Color(0.5, 0.8, 1.0), 0.1)
	tween.parallel().tween_property(sprite, "rotation", 0.0, 0.2)
	tween.parallel().tween_property(sprite, "scale", Vector2.ONE, 0.2)
	
	if health <= 0:
		die()

func die():
	current_state = State.DEAD
	if player and player.has_method("on_warrior_died"):
		player.on_warrior_died()
	
	# Death animation - fall and fade
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "rotation", PI * 1.5, 0.5)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_property(sprite, "scale", Vector2(1.5, 0.5), 0.5)
	
	await tween.finished
	queue_free()
