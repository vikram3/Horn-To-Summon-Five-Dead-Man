extends CharacterBody2D

@export var speed: float = 150.0
@export var chase_range: float = 300.0
@export var attack_range: float = 200.0
@export var melee_range: float = 40.0
@export var projectile_damage: float = 15.0
@export var melee_damage: float = 20.0
@export var attack_cooldown: float = 1.5
@export var max_health: float = 80.0
@export var projectile_scene: PackedScene

var health: float
var target: Node2D
var can_attack: bool = true
var is_ranged_attack: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_timer: Timer = $AttackTimer
@onready var projectile_spawn: Marker2D = $ProjectileSpawn

func _ready():
	health = max_health
	add_to_group("enemy")
	attack_timer.wait_time = attack_cooldown
	attack_timer.timeout.connect(_on_attack_ready)
	
	# Enemy color tint
	#sprite.modulate = Color(1.0, 0.5, 0.5)
	
	# Create projectile spawn if it doesn't exist
	if not has_node("ProjectileSpawn"):
		projectile_spawn = Marker2D.new()
		projectile_spawn.name = "ProjectileSpawn"
		projectile_spawn.position = Vector2(20, 0)
		add_child(projectile_spawn)

func _physics_process(delta):
	find_target()
	
	if not target or not is_instance_valid(target):
		velocity = Vector2.ZERO
		sprite.rotation = lerp(sprite.rotation, 0.0, delta * 8.0)
		move_and_slide()
		return
	
	var dist = global_position.distance_to(target.global_position)
	
	# Determine attack type based on distance
	if dist <= melee_range:
		is_ranged_attack = false
		if can_attack:
			velocity = Vector2.ZERO
			melee_attack()
	elif dist <= attack_range and can_attack:
		velocity = Vector2.ZERO
		is_ranged_attack = true
		shoot_projectile()
	elif dist <= chase_range:
		var direction = global_position.direction_to(target.global_position)
		velocity = direction * speed
		sprite.flip_h = direction.x < 0
		# Running animation
		sprite.rotation = lerp(sprite.rotation, sin(Time.get_ticks_msec() * 0.01) * 0.1, delta * 10.0)
	else:
		velocity = Vector2.ZERO
		sprite.rotation = lerp(sprite.rotation, 0.0, delta * 8.0)
	
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

func shoot_projectile():
	can_attack = false
	attack_timer.start()
	
	# Shooting animation - recoil back
	var shoot_dir = -1 if sprite.flip_h else 1
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "rotation", shoot_dir * -0.4, 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.1)
	tween.chain().tween_property(sprite, "rotation", shoot_dir * 0.2, 0.15).set_trans(Tween.TRANS_BOUNCE)
	tween.parallel().tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.15)
	tween.chain().tween_property(sprite, "rotation", 0.0, 0.2)
	tween.parallel().tween_property(sprite, "scale", Vector2.ONE, 0.2)
	
	# Spawn projectile
	if projectile_scene:
		var projectile = projectile_scene.instantiate()
		get_tree().root.add_child(projectile)
		projectile.global_position = projectile_spawn.global_position
		
		var direction = global_position.direction_to(target.global_position)
		projectile.direction = direction
		projectile.damage = projectile_damage
		projectile.shooter = self
	
	if has_node("ShootSound"):
		$ShootSound.play()

func melee_attack():
	can_attack = false
	attack_timer.start()
	
	if target and target.has_method("take_damage"):
		target.take_damage(melee_damage)
	
	# Melee animation - lunge forward
	var attack_dir = 1 if not sprite.flip_h else -1
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "rotation", attack_dir * 0.5, 0.15)
	tween.tween_property(sprite, "scale", Vector2(1.3, 0.8), 0.15)
	tween.chain().tween_property(sprite, "rotation", 0.0, 0.2)
	tween.parallel().tween_property(sprite, "scale", Vector2.ONE, 0.2)
	
	if has_node("AttackSound"):
		$AttackSound.play()

func _on_attack_ready():
	can_attack = true

func take_damage(amount: float):
	health -= amount
	
	# Hit animation - shake and flash
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.08)
	tween.tween_property(sprite, "rotation", 0.3, 0.08)
	tween.tween_property(sprite, "position:x", sprite.position.x + 5, 0.08)
	#tween.chain().tween_property(sprite, "modulate", Color(1.0, 0.5, 0.5), 0.08)
	tween.parallel().tween_property(sprite, "rotation", -0.1, 0.08)
	tween.parallel().tween_property(sprite, "position:x", sprite.position.x, 0.08)
	tween.chain().tween_property(sprite, "rotation", 0.0, 0.15)
	
	if health <= 0:
		die()

func die():
	# Notify UI about kill
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("add_score"):
		ui.add_score(10)  # Award 10 points per kill
	
	# Death animation - dramatic fall
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "rotation", PI * 1.2, 0.6)
	tween.tween_property(sprite, "modulate", Color(0.3, 0.1, 0.1, 0.0), 0.6)
	tween.tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.6)
	
	await tween.finished
	queue_free()
