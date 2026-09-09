extends CharacterBody3D

@export_category("Locomotion")
@export var push_strength := 1.0
@export var maximum_speed := 7.0
@export var gravity := 18.0
@export var fly_speed := 8.0

@export_category("References")
@export var xr_origin: XROrigin3D
@export var headset: XRCamera3D
@export var left_controller: XRController3D
@export var right_controller: XRController3D

var long_arms_enabled := false
var arm_multiplier := 1.0
var fly_enabled := false
var platforms_enabled := false

var previous_left_position := Vector3.ZERO
var previous_right_position := Vector3.ZERO

var left_platform: StaticBody3D
var right_platform: StaticBody3D


func _ready() -> void:
	xr_origin = $XROrigin3D
	headset = $XROrigin3D/XRCamera3D
	left_controller = $XROrigin3D/LeftController
	right_controller = $XROrigin3D/RightController

	previous_left_position = get_virtual_hand_position(
		left_controller
	)

	previous_right_position = get_virtual_hand_position(
		right_controller
	)


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

	previous_left_position = get_virtual_hand_position(
		left_controller
	)

	previous_right_position = get_virtual_hand_position(
		right_controller
	)


func update_arm_locomotion(delta: float) -> void:
	var left_position := get_virtual_hand_position(
		left_controller
	)

	var right_position := get_virtual_hand_position(
		right_controller
	)

	var left_hit := check_hand_movement(
		previous_left_position,
		left_position
	)

	var right_hit := check_hand_movement(
		previous_right_position,
		right_position
	)

	var total_push := Vector3.ZERO
	var touching_hands := 0

	if not left_hit.is_empty():
		total_push += calculate_push(
			left_hit,
			left_position
		)

		touching_hands += 1

	if not right_hit.is_empty():
		total_push += calculate_push(
			right_hit,
			right_position
		)

		touching_hands += 1

	if touching_hands > 0:
		total_push /= float(touching_hands)
		total_push *= push_strength

		velocity += total_push / delta
	else:
		velocity.y -= gravity * delta

	velocity = velocity.limit_length(maximum_speed)


func update_flying(delta: float) -> void:
	var fly_button := right_controller.is_button_pressed(
		"primary_click"
	)

	if fly_button:
		var fly_direction := -right_controller.global_basis.z
		var target_velocity := fly_direction * fly_speed

		velocity = velocity.lerp(
			target_velocity,
			min(10.0 * delta, 1.0)
		)
	else:
		velocity.y -= gravity * 0.25 * delta
		velocity = velocity.lerp(
			Vector3.ZERO,
			min(2.0 * delta, 1.0)
		)

	velocity = velocity.limit_length(fly_speed)


func get_virtual_hand_position(
	controller: XRController3D
) -> Vector3:

	var real_position := controller.global_position

	if not long_arms_enabled:
		return real_position

	var head_position := headset.global_position
	var hand_offset := real_position - head_position

	return head_position + hand_offset * arm_multiplier


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

	return get_world_3d().direct_space_state.intersect_ray(
		query
	)


func calculate_push(
	hit: Dictionary,
	current_hand_position: Vector3
) -> Vector3:

	var hit_position: Vector3 = hit["position"]
	var movement_after_hit := current_hand_position - hit_position

	return -movement_after_hit


func update_body_collider() -> void:
	var body_collider := $BodyCollider
	var capsule := body_collider.shape as CapsuleShape3D

	if capsule == null:
		return

	var local_head_position := to_local(
		headset.global_position
	)

	var player_height := clamp(
		local_head_position.y,
		0.8,
		2.4
	)

	capsule.height = player_height
	body_collider.position = Vector3(
		local_head_position.x,
		player_height * 0.5,
		local_head_position.z
	)


func set_client_settings(
	new_long_arms_enabled: bool,
	new_arm_multiplier: float,
	new_fly_enabled: bool,
	new_platforms_enabled: bool
) -> void:

	long_arms_enabled = new_long_arms_enabled
	arm_multiplier = clamp(
		new_arm_multiplier,
		1.0,
		3.0
	)

	fly_enabled = new_fly_enabled
	platforms_enabled = new_platforms_enabled

	if not platforms_enabled:
		remove_platforms()

	previous_left_position = get_virtual_hand_position(
		left_controller
	)

	previous_right_position = get_virtual_hand_position(
		right_controller
	)

	update_hand_visuals()


func update_hand_visuals() -> void:
	var left_mesh := left_controller.get_node_or_null(
		"HandMesh"
	)

	var right_mesh := right_controller.get_node_or_null(
		"HandMesh"
	)

	var visual_multiplier := 1.0

	if long_arms_enabled:
		visual_multiplier = arm_multiplier

	if left_mesh != null:
		left_mesh.scale = Vector3.ONE * visual_multiplier

	if right_mesh != null:
		right_mesh.scale = Vector3.ONE * visual_multiplier


func update_platforms() -> void:
	if not platforms_enabled:
		remove_platforms()
		return

	var left_grip := left_controller.is_button_pressed(
		"grip_click"
	)

	var right_grip := right_controller.is_button_pressed(
		"grip_click"
	)

	if left_grip:
		if left_platform == null:
			left_platform = create_platform(
				Color(0.1, 0.45, 1.0)
			)

		left_platform.global_position = (
			get_virtual_hand_position(left_controller)
			+ Vector3(0, -0.08, 0)
		)
	else:
		remove_left_platform()

	if right_grip:
		if right_platform == null:
			right_platform = create_platform(
				Color(1.0, 0.18, 0.12)
			)

		right_platform.global_position = (
			get_virtual_hand_position(right_controller)
			+ Vector3(0, -0.08, 0)
		)
	else:
		remove_right_platform()


func create_platform(color: Color) -> StaticBody3D:
	var platform := StaticBody3D.new()
	platform.collision_layer = 1
	platform.collision_mask = 1

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.45, 0.08, 0.45)
	collision.shape = shape
	platform.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.45, 0.08, 0.45)
	mesh_instance.mesh = mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.15
	material.roughness = 0.55
	mesh_instance.material_override = material

	platform.add_child(mesh_instance)
	get_tree().current_scene.add_child(platform)

	return platform


func remove_platforms() -> void:
	remove_left_platform()
	remove_right_platform()


func remove_left_platform() -> void:
	if is_instance_valid(left_platform):
		left_platform.queue_free()

	left_platform = null


func remove_right_platform() -> void:
	if is_instance_valid(right_platform):
		right_platform.queue_free()

	right_platform = null
