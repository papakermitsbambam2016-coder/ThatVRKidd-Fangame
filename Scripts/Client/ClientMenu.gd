extends Node3D

enum Page { MAIN, SETTINGS }

@onready var player: CharacterBody3D = get_node("../../..")
@onready var right_controller: XRController3D = get_node("../../RightController")
var current_page := Page.MAIN
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
	create_panel()
	show_main_page()

func _physics_process(_delta: float) -> void:
	var pressed := right_controller.is_button_pressed("trigger_click")
	if pressed and not trigger_was_pressed:
		press_pointed_button()
	trigger_was_pressed = pressed

func create_panel() -> void:
	var background := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.48, 0.68, 0.025)
	background.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.025, 0.03, 0.05, 0.96)
	background.material_override = material
	add_child(background)
	title_label = make_label(Vector3(0, 0.275, 0.025), 52, 0.0018)
	title_label.modulate = Color(0.15, 0.7, 1.0)
	status_label = make_label(Vector3(0, -0.29, 0.025), 34, 0.0011)

func make_label(at: Vector3, size: int, pixels: float) -> Label3D:
	var label := Label3D.new()
	label.position = at
	label.font_size = size
	label.pixel_size = pixels
	label.outline_size = 6
	add_child(label)
	return label

func show_main_page() -> void:
	current_page = Page.MAIN
	clear_buttons()
	title_label.text = "ThatVRKidd Client"
	status_label.text = "Main Menu"
	create_button("SETTINGS", "settings", 0.19, false)
	create_button("LONG ARMS", "long_arms", 0.105, long_arms_enabled)
	create_button("MOSA SPEED", "mosa", 0.02, mosa_enabled)
	create_button("SPEED BOOST", "speed", -0.065, speed_boost_enabled)
	create_button("FLY", "fly", -0.15, fly_enabled)
	create_button("PLATFORMS", "platforms", -0.235, platforms_enabled)

func show_settings_page() -> void:
	current_page = Page.SETTINGS
	clear_buttons()
	title_label.text = "SETTINGS"
	status_label.text = "Scale %.1f | Arms %.1f" % [world_scale, arm_multiplier]
	create_button("EXIT TO MAIN MENU", "main_menu", 0.19, false)
	create_button("WORLD SCALE +", "world_scale_up", 0.105, false)
	create_button("WORLD SCALE -", "world_scale_down", 0.02, false)
	create_button("ARM LENGTH +", "arm_length_up", -0.065, false)
	create_button("ARM LENGTH -", "arm_length_down", -0.15, false)
	create_button("RESET SETTINGS", "reset", -0.235, false)

func create_button(text: String, action: String, y: float, enabled: bool) -> void:
	var button := Area3D.new()
	button.position = Vector3(0, y, 0.035)
	button.collision_layer = 8
	button.set_meta("menu_action", action)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.4, 0.065, 0.035)
	collision.shape = shape
	button.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.4, 0.065, 0.03)
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.08, 0.75, 0.3) if enabled else Color(0.14, 0.16, 0.2)
	visual.material_override = material
	button.add_child(visual)
	var label := Label3D.new()
	label.position.z = 0.021
	label.pixel_size = 0.0012
	label.font_size = 40
	label.outline_size = 5
	label.text = text
	button.add_child(label)
	add_child(button)
	buttons.append(button)

func clear_buttons() -> void:
	for button in buttons:
		button.queue_free()
	buttons.clear()

func press_pointed_button() -> void:
	var start := right_controller.global_position
	var query := PhysicsRayQueryParameters3D.create(start, start - right_controller.global_basis.z * 4.0)
	query.collision_mask = 8
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty() and result["collider"].has_meta("menu_action"):
		run_action(str(result["collider"].get_meta("menu_action")))

func run_action(action: String) -> void:
	match action:
		"settings": show_settings_page()
		"main_menu": show_main_page()
		"long_arms":
			long_arms_enabled = not long_arms_enabled
			apply_player_settings()
			show_main_page()
		"mosa":
			mosa_enabled = not mosa_enabled
			apply_player_settings()
			show_main_page()
		"speed":
			speed_boost_enabled = not speed_boost_enabled
			apply_player_settings()
			show_main_page()
		"fly":
			fly_enabled = not fly_enabled
			apply_player_settings()
			show_main_page()
		"platforms":
			platforms_enabled = not platforms_enabled
			apply_player_settings()
			show_main_page()
		"world_scale_up":
			world_scale = min(world_scale + 0.1, 2.0)
			apply_player_settings()
			show_settings_page()
		"world_scale_down":
			world_scale = max(world_scale - 0.1, 0.5)
			apply_player_settings()
			show_settings_page()
		"arm_length_up":
			arm_multiplier = min(arm_multiplier + 0.1, 3.0)
			apply_player_settings()
			show_settings_page()
		"arm_length_down":
			arm_multiplier = max(arm_multiplier - 0.1, 1.0)
			apply_player_settings()
			show_settings_page()
		"reset":
			world_scale = 1.0
			arm_multiplier = 1.0
			long_arms_enabled = false
			mosa_enabled = false
			speed_boost_enabled = false
			fly_enabled = false
			platforms_enabled = false
			apply_player_settings()
			show_settings_page()

func apply_player_settings() -> void:
	var new_push := 1.0
	var new_speed := 7.0
	if mosa_enabled:
		new_push = 1.15
		new_speed = 8.5
	if speed_boost_enabled:
		new_push = 1.4
		new_speed = 12.0
	player.set("push_strength", new_push)
	player.set("maximum_speed", new_speed)
	player.call("set_client_settings", long_arms_enabled, arm_multiplier, fly_enabled, platforms_enabled)
	xr_origin_scale()

func xr_origin_scale() -> void:
	var origin: XROrigin3D = player.get_node("XROrigin3D")
	origin.scale = Vector3.ONE * world_scale

