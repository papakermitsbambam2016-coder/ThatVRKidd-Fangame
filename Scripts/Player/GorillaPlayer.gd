extends CharacterBody3D

@export_category("Locomotion")
@export var push_strength: float = 1.0
@export var maximum_speed: float = 7.0
@export var jump_multiplier: float = 1.15
@export var gravity: float = 18.0
@export var hand_collision_radius: float = 0.09

@export_category("References")
@export var xr_origin: XROrigin3D
@export var headset: XRCamera3D
@export var left_controller: XRController3D
@export var right_controller: XRController3D

var previous_left_position: Vector3
var previous_right_position: Vector3
var left_was_touching: bool = false
var right_was_touching: bool = false
var movement_samples: Array[Vector3] = []


func _ready() -> void:
	if xr_origin == null:
		xr_origin = $XROrigin3D

	if headset == null:
		headset = $XROrigin3D/XRCamera3D

	if left_controller == null:
		left_controller = $XROrigin3D/LeftController

	if right_controller == null:
		right_controller = $XROrigin3D/RightController

	previous_left_position = left_controller.global_position
	previous_right_position = right_controller.global_position


func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return

	var left_position := left_controller.global_position
	var right_position := right_controller.global_position

	var left_result := check_hand_movement(
		previous_left_position,
		left_position
	)

	var right_result := check_hand_movement(
		previous_right_position,
		right_position
	)

	var body_push := Vector3.ZERO
	var touching_hands := 0

	if not left_result.is_empty():
		body_push += calculate_push(left_result, left_position)
		touching_hands += 1
		left_was_touching = true
	else:
		left_was_touching = false

	if not right_result.is_empty():
		body_push += calculate_push(right_result, right_position)
		touching_hands += 1
		right_was_touching = true
	else:
		right_was_touching = false

	if touching_hands > 0:
		body_push /= float(touching_hands)
		body_push *= push_strength

		velocity += body_push / delta
		save_movement_sample(velocity)
	else:
		velocity.y -= gravity * delta

	velocity = velocity.limit_length(maximum_speed)

	move_and_slide()

	previous_left_position = left_controller.global_position
	previous_right_position = right_controller.global_position

	update_body_collider()


func check_hand_movement(
		from_position: Vector3,
		to_position: Vector3
	) -> Dictionary:

	var direction := to_position - from_position

	if direction.length_squared() < 0.000001:
		return {}

	var query := PhysicsRayQueryParameters3D.create(
		from_position,
		to_position
	)

	query.collision_mask = 1
	query.exclude = [get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false

	return get_world_3d().direct_space_state.intersect_ray(query)


func calculate_push(
		hit: Dictionary,
		current_hand_position: Vector3
	) -> Vector3:

	var hit_position: Vector3 = hit["position"]
	var hit_normal: Vector3 = hit["normal"]

	var penetration := current_hand_position - hit_position
	var push := -penetration

	# Prevent the hand from pulling the player into a surface.
	if push.dot(hit_normal) < 0.0:
		push = push.slide(hit_normal)

	return push


func save_movement_sample(sample: Vector3) -> void:
	movement_samples.push_back(sample)

	while movement_samples.size() > 5:
		movement_samples.pop_front()


func get_average_movement() -> Vector3:
	if movement_samples.is_empty():
		return Vector3.ZERO

	var average := Vector3.ZERO

	for sample in movement_samples:
		average += sample

	return average / float(movement_samples.size())


func update_body_collider() -> void:
	if headset == null:
		return

	var local_head_position := to_local(headset.global_position)

	# Follow the headset horizontally while keeping the collider upright.
	$BodyCollider.position.x = local_head_position.x
	$BodyCollider.position.z = local_head_position.z

	var body_height := clamp(local_head_position.y, 0.8, 2.2)
	$BodyCollider.position.y = body_height * 0.5

	var capsule := $BodyCollider.shape as CapsuleShape3D

	if capsule != null:
		capsule.height = body_height
