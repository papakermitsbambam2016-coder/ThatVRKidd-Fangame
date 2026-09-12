extends CharacterBody3D

@export var push_strength := 1.0
@export var maximum_speed := 7.0
@export var gravity := 18.0
@export var fly_speed := 8.0
@export var joystick_speed := 4.5
@export var grapple_acceleration := 20.0

@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var headset: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var left_controller: XRController3D = $XROrigin3D/LeftController
@onready var right_controller: XRController3D = $XROrigin3D/RightController

var long_arms_enabled := false
var arm_multiplier := 1.0
var fly_enabled := false
var platforms_enabled := false
var joystick_walk_enabled := false
var moon_gravity_enabled := false
var grapple_enabled := false
var rgb_trails_enabled := false
var tag_gun_enabled := false
var frozen := false
var freeze_position := Vector3.ZERO
var grapple_point := Vector3.ZERO
var grapple_active := false
var previous_left_position := Vector3.ZERO
var previous_right_position := Vector3.ZERO
var left_platform: StaticBody3D
var right_platform: StaticBody3D
var left_trail: GPUParticles3D
var right_trail: GPUParticles3D
var tag_pointer: MeshInstance3D
var sound_player: AudioStreamPlayer

func _ready() -> void:
	previous_left_position = get_virtual_hand_position(left_controller)
	previous_right_position = get_virtual_hand_position(right_controller)
	create_rgb_trails()
	create_tag_pointer()
	create_sound_player()

func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	if frozen:
		global_position = freeze_position
		velocity = Vector3.ZERO
		return
	update_body_collider()
	update_platforms()
	update_rgb_trails()
	update_tag_gun()
	update_grapple(delta)
	if fly_enabled:
		update_flying(delta)
	else:
		update_arm_locomotion(delta)
	if joystick_walk_enabled:
		update_joystick_walk()
	move_and_slide()
	previous_left_position = get_virtual_hand_position(left_controller)
	previous_right_position = get_virtual_hand_position(right_controller)

func update_arm_locomotion(delta: float) -> void:
	var left_position: Vector3 = get_virtual_hand_position(left_controller)
	var right_position: Vector3 = get_virtual_hand_position(right_controller)
	var left_hit: Dictionary = check_hand_movement(previous_left_position, left_position)
	var right_hit: Dictionary = check_hand_movement(previous_right_position, right_position)
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
		velocity.y -= get_active_gravity() * delta
	velocity = velocity.limit_length(maximum_speed)

func update_flying(delta: float) -> void:
	if right_controller.is_button_pressed("primary_click"):
		var target: Vector3 = -right_controller.global_basis.z * fly_speed
		velocity = velocity.lerp(target, minf(10.0 * delta, 1.0))
	else:
		velocity.y -= get_active_gravity() * 0.25 * delta
		velocity = velocity.lerp(Vector3.ZERO, minf(2.0 * delta, 1.0))
	velocity = velocity.limit_length(fly_speed)

func get_virtual_hand_position(controller: XRController3D) -> Vector3:
	var real_position: Vector3 = controller.global_position
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
	var capsule: CapsuleShape3D = body_collider.shape as CapsuleShape3D
	if capsule == null:
		return
	var local_head: Vector3 = to_local(headset.global_position)
	var player_height: float = clampf(local_head.y, 0.8, 2.4)
	capsule.height = player_height
	body_collider.position = Vector3(local_head.x, player_height * 0.5, local_head.z)

func set_client_settings(long_arms: bool, new_arm_multiplier: float, fly: bool, platforms: bool) -> void:
	long_arms_enabled = long_arms
	arm_multiplier = clampf(new_arm_multiplier, 1.0, 3.0)
	fly_enabled = fly
	platforms_enabled = platforms
	if not platforms_enabled:
		remove_platforms()
	previous_left_position = get_virtual_hand_position(left_controller)
	previous_right_position = get_virtual_hand_position(right_controller)

func set_extra_settings(joystick: bool, moon_gravity: bool, grapple: bool, rgb_trails: bool, tag_gun: bool) -> void:
	joystick_walk_enabled = joystick
	moon_gravity_enabled = moon_gravity
	grapple_enabled = grapple
	rgb_trails_enabled = rgb_trails
	tag_gun_enabled = tag_gun
	if not grapple_enabled:
		grapple_active = false

func get_active_gravity() -> float:
	return 4.5 if moon_gravity_enabled else gravity

func update_joystick_walk() -> void:
	var stick := right_controller.get_vector2("primary")
	if stick.length() < 0.15:
		return
	var forward := -headset.global_basis.z
	var right := headset.global_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	var move := (forward * -stick.y + right * stick.x) * joystick_speed
	velocity.x = move.x
	velocity.z = move.z

func update_grapple(delta: float) -> void:
	if not grapple_enabled:
		return
	var pressed := right_controller.is_button_pressed("ax_button")
	if pressed and not grapple_active:
		var start := right_controller.global_position
		var query := PhysicsRayQueryParameters3D.create(start, start - right_controller.global_basis.z * 30.0)
		query.collision_mask = 1
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			grapple_point = hit["position"]
			grapple_active = true
	if not pressed:
		grapple_active = false
	if grapple_active:
		velocity += global_position.direction_to(grapple_point) * grapple_acceleration * delta
		velocity = velocity.limit_length(maximum_speed * 1.5)

func create_rgb_trails() -> void:
	left_trail = make_trail(left_controller)
	right_trail = make_trail(right_controller)

func make_trail(parent: Node3D) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = 48
	particles.lifetime = 0.45
	particles.local_coords = false
	var process := ParticleProcessMaterial.new()
	process.gravity = Vector3.ZERO
	process.initial_velocity_min = 0.05
	process.initial_velocity_max = 0.2
	particles.process_material = process
	var mesh := SphereMesh.new()
	mesh.radius = 0.018
	mesh.height = 0.036
	particles.draw_pass_1 = mesh
	particles.emitting = false
	parent.add_child(particles)
	return particles

func update_rgb_trails() -> void:
	var hue := fmod(Time.get_ticks_msec() / 2500.0, 1.0)
	var color := Color.from_hsv(hue, 0.9, 1.0)
	for trail in [left_trail, right_trail]:
		trail.emitting = rgb_trails_enabled
		trail.modulate = color

func create_tag_pointer() -> void:
	tag_pointer = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	tag_pointer.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.65, 1.0)
	material.emission_enabled = true
	material.emission = material.albedo_color
	tag_pointer.material_override = material
	tag_pointer.visible = false
	get_tree().current_scene.call_deferred("add_child", tag_pointer)

func update_tag_gun() -> void:
	if not tag_gun_enabled or not right_controller.is_button_pressed("grip_click"):
		tag_pointer.visible = false
		return
	var start := right_controller.global_position
	var query := PhysicsRayQueryParameters3D.create(start, start - right_controller.global_basis.z * 40.0)
	query.collision_mask = 1 | 4
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	tag_pointer.visible = not hit.is_empty()
	if hit.is_empty():
		return
	tag_pointer.global_position = hit["position"]
	if right_controller.is_button_pressed("trigger_click"):
		var target: Node = hit["collider"]
		while target != null and not target.is_in_group("tag_targets"):
			target = target.get_parent()
		if target != null and target.has_method("receive_tag"):
			target.call("receive_tag", get_multiplayer_authority())

func toggle_frozen() -> void:
	frozen = not frozen
	if frozen:
		freeze_position = global_position

func create_sound_player() -> void:
	sound_player = AudioStreamPlayer.new()
	add_child(sound_player)

func play_soundboard_tone() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.25
	sound_player.stream = stream
	sound_player.play()
	var playback := sound_player.get_stream_playback() as AudioStreamGeneratorPlayback
	for i in range(4410):
		var sample := sin(TAU * 440.0 * float(i) / 22050.0) * 0.22
		playback.push_frame(Vector2(sample, sample))

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
