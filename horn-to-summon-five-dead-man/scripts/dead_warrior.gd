extends CharacterBody2D

enum State { IDLE, FOLLOW, ATTACK, DEAD }

@export var speed: float = 250.0
@export var follow_distance: float = 150.0
@export var attack_range: float = 50.0
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
@onready var detection_area: Area2D = $DetectionArea

func _ready():
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	attack_timer.wait_time = attack_cooldown
	attack_timer.timeout.connect(_on_attack_cooldown_complete)
	
	detection_area.body_entered.connect(_on_enemy_detected)
	detection_area.body_exited.connect(_on_enemy_lost)

func _physics_process(delta):
	match current_state:
		State.IDLE:
			_state_idle()
		State.FOLLOW:
			_state_follow()
		State.ATTACK:
			_state_attack()
		State.DEAD:
			return
	
	move_and_slide()

func _state_idle():
	if not player:
		return
	
	var dist_to_player = global_position.distance_to(player.global_position)
	if dist_to_player > follow_distance:
		current_state = State.FOLLOW

func _state_follow():
	if not player:
		return
	
	if target_enemy and is_instance_valid(target_enemy):
		current_state = State.ATTACK
		return
	
	var dist_to_player = global_position.distance_to(player.global_position)
	if dist_to_player <= follow_distance:
		current_state = State.IDLE
		velocity = Vector2.ZERO
	else:
		var direction = global_position.direction_to(player.global_position)
		velocity = direction * speed
		sprite.flip_h = direction.x < 0

func _state_attack():
	if not target_enemy or not is_instance_valid(target_enemy):
		target_enemy = null
		current_state = State.FOLLOW
		return
	
	var dist = global_position.distance_to(target_enemy.global_position)
	if dist > attack_range * 2:
		target_enemy = null
		current_state = State.FOLLOW
		return
	
	if dist > attack_range:
		var direction = global_position.direction_to(target_enemy.global_position)
		velocity = direction * speed
		sprite.flip_h = direction.x < 0
	else:
		velocity = Vector2.ZERO
		if can_attack:
			perform_attack()

func perform_attack():
	can_attack = false
	attack_timer.start()
	
	if target_enemy and target_enemy.has_method("take_damage"):
		target_enemy.take_damage(attack_damage)
	
	$AnimationPlayer.play("attack") if has_node("AnimationPlayer") else null
	$AttackSound.play() if has_node("AttackSound") else null

func _on_attack_cooldown_complete():
	can_attack = true

func _on_enemy_detected(body):
	if body.is_in_group("enemy") and not target_enemy:
		target_enemy = body
		current_state = State.ATTACK

func _on_enemy_lost(body):
	if body == target_enemy:
		target_enemy = null

func take_damage(amount: float):
	health -= amount
	$AnimationPlayer.play("hit") if has_node("AnimationPlayer") else null
	
	if health <= 0:
		die()

func die():
	current_state = State.DEAD
	if player and player.has_method("on_warrior_died"):
		player.on_warrior_died()
	
	$AnimationPlayer.play("death") if has_node("AnimationPlayer") else null
	await get_tree().create_timer(0.5).timeout
	queue_free()
