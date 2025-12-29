extends Area2D

@export var speed: float = 400.0
@export var damage: float = 15.0
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var shooter: Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var trail: Line2D = $Trail if has_node("Trail") else null

var trail_points: Array = []
var max_trail_length: int = 10

func _ready():
	body_entered.connect(_on_body_entered)
	
	# Auto-destroy after lifetime
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	
	# Set rotation to match direction
	rotation = direction.angle()
	
	# Projectile glow effect
	sprite.modulate = Color(1.0, 0.3, 0.3)

func _physics_process(delta):
	position += direction * speed * delta
	
	# Rotate projectile for visual effect
	sprite.rotation += delta * 10.0
	
	# Trail effect
	update_trail()

func update_trail():
	if not trail:
		return
	
	trail_points.push_front(global_position)
	if trail_points.size() > max_trail_length:
		trail_points.pop_back()
	
	trail.clear_points()
	for point in trail_points:
		trail.add_point(to_local(point))

func _on_body_entered(body):
	# Don't hit the shooter
	if body == shooter:
		return
	
	# Check if target can take damage
	if body.has_method("take_damage"):
		body.take_damage(damage)
	
	# Impact effect
	impact_effect()
	
	# Destroy projectile
	queue_free()

func impact_effect():
	# Create impact particles or effect
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(2.0, 2.0), 0.1)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.1)
