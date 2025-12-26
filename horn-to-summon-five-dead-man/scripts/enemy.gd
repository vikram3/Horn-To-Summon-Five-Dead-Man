extends CharacterBody2D

@export var speed: float = 150.0
@export var chase_range: float = 300.0
@export var attack_range: float = 40.0
@export var attack_damage: float = 15.0
@export var attack_cooldown: float = 1.5
@export var max_health: float = 80.0

var health: float
var target: Node2D
var can_attack: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_timer: Timer = $AttackTimer

func _ready():
	health = max_health
	add_to_group("enemy")
	attack_timer.wait_time = attack_cooldown
	attack_timer.timeout.connect(_on_attack_ready)

func _physics_process(delta):
	find_target()
	
	if not target or not is_instance_valid(target):
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	var dist = global_position.distance_to(target.global_position)
	
	if dist <= attack_range and can_attack:
		velocity = Vector2.ZERO
		attack_target()
	elif dist <= chase_range:
		var direction = global_position.direction_to(target.global_position)
		velocity = direction * speed
		sprite.flip_h = direction.x < 0
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()

func find_target():
	if target and is_instance_valid(target):
		return
	
	var player = get_tree().get_first_node_in_group("player")
	var warriors = get_tree().get_nodes_in_group("warrior")
	
	var closest_dist = INF
	var closest_target = null
	
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_target = player
	
	for warrior in warriors:
		if is_instance_valid(warrior):
			var dist = global_position.distance_to(warrior.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest_target = warrior
	
	target = closest_target

func attack_target():
	can_attack = false
	attack_timer.start()
	
	if target and target.has_method("take_damage"):
		target.take_damage(attack_damage)
	
	$AnimationPlayer.play("attack") if has_node("AnimationPlayer") else null

func _on_attack_ready():
	can_attack = true

func take_damage(amount: float):
	health -= amount
	$AnimationPlayer.play("hit") if has_node("AnimationPlayer") else null
	
	if health <= 0:
		die()

func die():
	$AnimationPlayer.play("death") if has_node("AnimationPlayer") else null
	await get_tree().create_timer(0.5).timeout
	queue_free()
