extends Node3D

@export var maximum_distance := 4.0
@export var menu_collision_mask := 8

var beam: MeshInstance3D
var beam_mesh: CylinderMesh
var beam_material: StandardMaterial3D

var pointer_dot: MeshInstance3D
var dot_material: StandardMaterial3D


func _ready() -> void:
	create_beam()
	create_pointer_dot()


func _physics_process(_delta: float) -> void:
	update_pointer()


func create_beam() -> void:
	beam = MeshInstance3D.new()
	beam.name = "Beam"

	beam_mesh = CylinderMesh.new()
	beam_mesh.top_radius = 0.004
	beam_mesh.bottom_radius = 0.004
	beam_mesh.height = maximum_distance

	beam_material = StandardMaterial3D.new()
	beam_material.albedo_color = Color(0.1, 0.65, 1.0)
	beam_material.emission_enabled = true
	beam_material.emission = Color(0.05, 0.35, 1.0)
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	beam.mesh = beam_mesh
	beam.material_override = beam_material
	beam.rotation_degrees = Vector3(90, 0, 0)

	add_child(beam)


func create_pointer_dot() -> void:
	pointer_dot = MeshInstance3D.new()
	pointer_dot.name = "PointerDot"

	var sphere := SphereMesh.new()
	sphere.radius = 0.015
	sphere.height = 0.03

	dot_material = StandardMaterial3D.new()
	dot_material.albedo_color = Color(0.1, 0.65, 1.0)
	dot_material.emission_enabled = true
	dot_material.emission = Color(0.05, 0.35, 1.0)
	dot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	pointer_dot.mesh = sphere
	pointer_dot.material_override = dot_material

	add_child(pointer_dot)


func update_pointer() -> void:
	var ray_start := global_position
	var ray_direction := -global_basis.z
	var ray_end := ray_start + ray_direction * maximum_distance

	var query := PhysicsRayQueryParameters3D.create(
		ray_start,
		ray_end
	)

	query.collision_mask = menu_collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result := get_world_3d().direct_space_state.intersect_ray(
		query
	)

	var pointer_distance := maximum_distance
	var pointed_at_button := false

	if not result.is_empty():
		var hit_position: Vector3 = result["position"]
		pointer_distance = ray_start.distance_to(hit_position)

		var collider: Object = result["collider"]
		pointed_at_button = collider.has_meta("menu_action")

	update_beam_length(pointer_distance)
	update_pointer_color(pointed_at_button)


func update_beam_length(new_length: float) -> void:
	new_length = clamp(
		new_length,
		0.02,
		maximum_distance
	)

	beam_mesh.height = new_length
	beam.position = Vector3(0, 0, -new_length * 0.5)
	pointer_dot.position = Vector3(0, 0, -new_length)


func update_pointer_color(pointed_at_button: bool) -> void:
	if pointed_at_button:
		beam_material.albedo_color = Color(0.1, 1.0, 0.25)
		beam_material.emission = Color(0.05, 0.8, 0.15)

		dot_material.albedo_color = Color(0.1, 1.0, 0.25)
		dot_material.emission = Color(0.05, 0.8, 0.15)
	else:
		beam_material.albedo_color = Color(0.1, 0.65, 1.0)
		beam_material.emission = Color(0.05, 0.35, 1.0)

		dot_material.albedo_color = Color(0.1, 0.65, 1.0)
		dot_material.emission = Color(0.05, 0.35, 1.0)
