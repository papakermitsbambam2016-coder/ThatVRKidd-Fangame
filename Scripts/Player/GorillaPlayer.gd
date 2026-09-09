extends CharacterBody3D

@export var push_strength := 1.0
@export var maximum_speed := 7.0
@export var gravity := 18.0
@export var fly_speed := 8.0

@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var headset: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var left_controller: XRController3D = $XROrigin3D/LeftController
@onready var right_controller: XRController3D = $XROrigin3D/RightController

var long_arms_enabled := false
var arm_multiplier := 1.0
var fly_enabled := false
var platforms_enabled := false
var previous_left_position := Vector3.ZERO
var previous_right_position := Vector3.ZERO
var left_platform: StaticBody3D
var right_platform: StaticBody3D

func _ready() -> void:
	previous_left_position = get_virtual_hand_position(left_controller)
	previous_right_position = get_virtual_hand_position(right_controller)

func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	update_body_collider()
	update_platforms()
	if fly_enabled:
		update_flying(delta)
	else:
		update_arm_locomotion(delta)
	move_and_slide()
	previous_left_position = get_virtual_hand_position(left_controller)
	previous_right_position = get_virtual_hand_position(right_controller)

func update_arm_locomotion(delta: float) -> void:
	var left_position := get_virtual_hand_position(left_controller)
	var right_position := get_virtual_hand_position(right_controller)
	var left_hit := check_hand_movement(previous_left_position, left_position)
	var right_hit := check_hand_movement(previous_right_position, right_position)
	var total_push := Vector3.ZERO
	var touching_hands := 0
	if not left_hit.is_empty():
		total_push += calculate_push(left_hit, left_position)
		touching_hands += 1
	if not right_hit.is_empty():
		total_push += calculate_push(right_hit, right_position)
		touching_hands += 1
	if touching_hands > 0:
		total_push = total_push / float(touching_hands) * push_strength
		velocity += total_push / delta
	else:
		velocity.y -= gravity * delta
	velocity = velocity.limit_length(maximum_speed)

func update_flying(delta: float) -> void:
	if right_controller.is_button_pressed("primary_click"):
		var target := -right_controller.global_basis.z * fly_speed
		velocity = velocity.lerp(target, min(10.0 * delta, 1.0))
	else:
		velocity.y -= gravity * 0.25 * delta
		velocity = velocity.lerp(Vector3.ZERO, min(2.0 * delta, 1.0))
	velocity = velocity.limit_length(fly_speed)

func get_virtual_hand_position(controller: XRController3D) -> Vector3:
	var real_position := controller.global_position
	if not long_arms_enabled:
		return real_position
	return headset.global_position + (real_position - headset.global_position) * arm_multiplier

func check_hand_movement(from_position: Vector3, to_position: Vector3) -> Dictionary:
	if from_position.distance_squared_to(to_position) < 0.000001:
		return {}
	var query := PhysicsRayQueryParameters3D.create(from_position, to_position)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(query)

func calculate_push(hit: Dictionary, current_hand_position: Vector3) -> Vector3:
	var hit_position: Vector3 = hit["position"]
	return -(current_hand_position - hit_position)

func update_body_collider() -> void:
	var body_collider: CollisionShape3D = $BodyCollider
	var capsule := body_collider.shape as CapsuleShape3D
	if capsule == null:
		return
	var local_head := to_local(headset.global_position)
	var player_height := clamp(local_head.y, 0.8, 2.4)
	capsule.height = player_height
	body_collider.position = Vector3(local_head.x, player_height * 0.5, local_head.z)

func set_client_settings(long_arms: bool, new_arm_multiplier: float, fly: bool, platforms: bool) -> void:
	long_arms_enabled = long_arms
	arm_multiplier = clamp(new_arm_multiplier, 1.0, 3.0)
	fly_enabled = fly
	platforms_enabled = platforms
	if not platforms_enabled:
		remove_platforms()
	previous_left_position = get_virtual_hand_position(left_controller)
	previous_right_position = get_virtual_hand_position(right_controller)

func update_platforms() -> void:
	if not platforms_enabled:
		remove_platforms()
		return
	left_platform = update_one_platform(left_platform, left_controller, Color(0.1, 0.45, 1.0))
	right_platform = update_one_platform(right_platform, right_controller, Color(1.0, 0.18, 0.12))

func update_one_platform(platform: StaticBody3D, controller: XRController3D, color: Color) -> StaticBody3D:
	if controller.is_button_pressed("grip_click"):
		if not is_instance_valid(platform):
			platform = create_platform(color)
		platform.global_position = get_virtual_hand_position(controller) + Vector3(0, -0.08, 0)
		return platform
	if is_instance_valid(platform):
		platform.queue_free()
	return null

func create_platform(color: Color) -> StaticBody3D:
	var platform := StaticBody3D.new()
	platform.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.45, 0.08, 0.45)
	collision.shape = shape
	platform.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	visual.material_override = material
	platform.add_child(visual)
	get_tree().current_scene.add_child(platform)
	return platform

func remove_platforms() -> void:
	if is_instance_valid(left_platform):
		left_platform.queue_free()
	if is_instance_valid(right_platform):
		right_platform.queue_free()
	left_platform = null
	right_platform = null

