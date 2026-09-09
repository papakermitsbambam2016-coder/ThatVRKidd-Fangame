extends Node3D

enum Page {
	MAIN,
	SETTINGS
}

@export var right_controller: XRController3D
@export var player: CharacterBody3D

var current_page: Page = Page.MAIN
var trigger_was_pressed := false
var buttons: Array[Area3D] = []

var long_arms_enabled := false
var mosa_enabled := false
var speed_boost_enabled := false
var fly_enabled := false
var platforms_enabled := false

var world_scale := 1.0
var arm_multiplier := 1.0

var title_label: Label3D
var status_label: Label3D


func _ready() -> void:
	if player == null:
		player = get_node("../../..")

	if right_controller == null:
		right_controller = get_node("../../RightController")

	create_panel()
	show_main_page()


func _physics_process(_delta: float) -> void:
	if right_controller == null:
		return

	var trigger_pressed := right_controller.is_button_pressed(
		"trigger_click"
	)

	if trigger_pressed and not trigger_was_pressed:
		press_pointed_button()

	trigger_was_pressed = trigger_pressed


func create_panel() -> void:
	var background := MeshInstance3D.new()
	background.name = "Background"

	var background_mesh := BoxMesh.new()
	background_mesh.size = Vector3(0.48, 0.68, 0.025)
	background.mesh = background_mesh

	var background_material := StandardMaterial3D.new()
	background_material.albedo_color = Color(
		0.025,
		0.03,
		0.05,
		0.96
	)
	background_material.roughness = 0.8

	background.material_override = background_material
	add_child(background)

	title_label = Label3D.new()
	title_label.name = "Title"
	title_label.position = Vector3(0, 0.275, 0.025)
	title_label.pixel_size = 0.0018
	title_label.font_size = 52
	title_label.modulate = Color(0.15, 0.7, 1.0)
	title_label.outline_size = 8
	title_label.text = "ThatVRKidd Client"
	add_child(title_label)

	status_label = Label3D.new()
	status_label.name = "Status"
	status_label.position = Vector3(0, -0.29, 0.025)
	status_label.pixel_size = 0.0011
	status_label.font_size = 34
	status_label.modulate = Color.WHITE
	status_label.outline_size = 6
	status_label.text = "Main Menu"
	add_child(status_label)


func show_main_page() -> void:
	current_page = Page.MAIN
	clear_buttons()

	title_label.text = "ThatVRKidd Client"
	status_label.text = "Main Menu"

	create_button(
		"SETTINGS",
		"settings",
		0.19,
		false
	)

	create_button(
		"LONG ARMS",
		"long_arms",
		0.105,
		long_arms_enabled
	)

	create_button(
		"MOSA SPEED",
		"mosa",
		0.02,
		mosa_enabled
	)

	create_button(
		"SPEED BOOST",
		"speed",
		-0.065,
		speed_boost_enabled
	)

	create_button(
		"FLY",
		"fly",
		-0.15,
		fly_enabled
	)

	create_button(
		"PLATFORMS",
		"platforms",
		-0.235,
		platforms_enabled
	)


func show_settings_page() -> void:
	current_page = Page.SETTINGS
	clear_buttons()

	title_label.text = "SETTINGS"
	status_label.text = get_settings_status()

	create_button(
		"EXIT TO MAIN MENU",
		"main_menu",
		0.19,
		false
	)

	create_button(
		"WORLD SCALE +",
		"world_scale_up",
		0.105,
		false
	)

	create_button(
		"WORLD SCALE -",
		"world_scale_down",
		0.02,
		false
	)

	create_button(
		"ARM LENGTH +",
		"arm_length_up",
		-0.065,
		false
	)

	create_button(
		"ARM LENGTH -",
		"arm_length_down",
		-0.15,
		false
	)

	create_button(
		"RESET SETTINGS",
		"reset",
		-0.235,
		false
	)


func create_button(
	button_text: String,
	action: String,
	y_position: float,
	enabled: bool
) -> void:

	var button := Area3D.new()
	button.name = action
	button.position = Vector3(0, y_position, 0.035)
	button.collision_layer = 8
	button.collision_mask = 0

	button.set_meta("menu_action", action)
	button.set_meta("button_text", button_text)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()

	shape.size = Vector3(0.4, 0.065, 0.035)
	collision.shape = shape

	button.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()

	mesh.size = Vector3(0.4, 0.065, 0.03)
	mesh_instance.mesh = mesh

	var material := StandardMaterial3D.new()

	if enabled:
		material.albedo_color = Color(0.08, 0.75, 0.3)
	else:
		material.albedo_color = Color(0.14, 0.16, 0.2)

	material.roughness = 0.75
	mesh_instance.material_override = material

	button.add_child(mesh_instance)

	var label := Label3D.new()
	label.position = Vector3(0, 0, 0.021)
	label.pixel_size = 0.0012
	label.font_size = 40
	label.text = button_text
	label.modulate = Color.WHITE
	label.outline_size = 5

	button.add_child(label)
	add_child(button)

	buttons.append(button)


func clear_buttons() -> void:
	for button in buttons:
		button.queue_free()

	buttons.clear()


func press_pointed_button() -> void:
	var ray_start := right_controller.global_position
	var ray_direction := -right_controller.global_basis.z
	var ray_end := ray_start + ray_direction * 4.0

	var query := PhysicsRayQueryParameters3D.create(
		ray_start,
		ray_end
	)

	query.collision_mask = 8
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result := get_world_3d().direct_space_state.intersect_ray(
		query
	)

	if result.is_empty():
		return

	var collider: Object = result["collider"]

	if collider.has_meta("menu_action"):
		var action := str(
			collider.get_meta("menu_action")
		)

		run_action(action)


func run_action(action: String) -> void:
	match action:
		"settings":
			show_settings_page()

		"main_menu":
			show_main_page()

		"long_arms":
			long_arms_enabled = not long_arms_enabled
			send_settings_to_player()
			show_main_page()

		"mosa":
			mosa_enabled = not mosa_enabled
			apply_movement_settings()
			show_main_page()

		"speed":
			speed_boost_enabled = not speed_boost_enabled
			apply_movement_settings()
			show_main_page()

		"fly":
			fly_enabled = not fly_enabled
			send_settings_to_player()
			show_main_page()

		"platforms":
			platforms_enabled = not platforms_enabled
			send_settings_to_player()
			show_main_page()

		"world_scale_up":
			world_scale = min(
				world_scale + 0.1,
				2.0
			)

			apply_scale_settings()
			show_settings_page()

		"world_scale_down":
			world_scale = max(
				world_scale - 0.1,
				0.5
			)

			apply_scale_settings()
			show_settings_page()

		"arm_length_up":
			arm_multiplier = min(
				arm_multiplier + 0.1,
				3.0
			)

			send_settings_to_player()
			show_settings_page()

		"arm_length_down":
			arm_multiplier = max(
				arm_multiplier - 0.1,
				1.0
			)

			send_settings_to_player()
			show_settings_page()

		"reset":
			reset_all_settings()
			show_settings_page()


func apply_movement_settings() -> void:
	var new_push_strength := 1.0
	var new_maximum_speed := 7.0

	if mosa_enabled:
		new_push_strength = 1.15
		new_maximum_speed = 8.5

	if speed_boost_enabled:
		new_push_strength = 1.4
		new_maximum_speed = 12.0

	player.set(
		"push_strength",
		new_push_strength
	)

	player.set(
		"maximum_speed",
		new_maximum_speed
	)

	send_settings_to_player()


func apply_scale_settings() -> void:
	var origin := player.get_node_or_null(
		"XROrigin3D"
	)

	if origin is XROrigin3D:
		origin.scale = Vector3.ONE * world_scale

	send_settings_to_player()


func send_settings_to_player() -> void:
	if player.has_method("set_client_settings"):
		player.call(
			"set_client_settings",
			long_arms_enabled,
			arm_multiplier,
			fly_enabled,
			platforms_enabled
		)


func reset_all_settings() -> void:
	world_scale = 1.0
	arm_multiplier = 1.0

	long_arms_enabled = false
	mosa_enabled = false
	speed_boost_enabled = false
	fly_enabled = false
	platforms_enabled = false

	player.set("push_strength", 1.0)
	player.set("maximum_speed", 7.0)

	apply_scale_settings()
	send_settings_to_player()


func get_settings_status() -> String:
	return (
		"Scale: "
		+ str(snapped(world_scale, 0.1))
		+ " | Arms: "
		+ str(snapped(arm_multiplier, 0.1))
	)


func set_menu_visible(menu_visible: bool) -> void:
	visible = menu_visible

	for button in buttons:
		button.monitoring = menu_visible
		button.monitorable = menu_visible
