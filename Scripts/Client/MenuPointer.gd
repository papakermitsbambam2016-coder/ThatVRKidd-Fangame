extends Node3D

@export var maximum_distance := 4.0
var beam: MeshInstance3D
var beam_mesh: CylinderMesh
var pointer_dot: MeshInstance3D
var beam_material: StandardMaterial3D
var dot_material: StandardMaterial3D

func _ready() -> void:
	beam = MeshInstance3D.new()
	beam_mesh = CylinderMesh.new()
	beam_mesh.top_radius = 0.004
	beam_mesh.bottom_radius = 0.004
	beam_material = make_glow_material(Color(0.1, 0.65, 1.0))
	beam.mesh = beam_mesh
	beam.material_override = beam_material
	beam.rotation_degrees.x = 90.0
	add_child(beam)
	pointer_dot = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.015
	sphere.height = 0.03
	dot_material = make_glow_material(Color(0.1, 0.65, 1.0))
	pointer_dot.mesh = sphere
	pointer_dot.material_override = dot_material
	add_child(pointer_dot)

func make_glow_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _physics_process(_delta: float) -> void:
	var start := global_position
	var query := PhysicsRayQueryParameters3D.create(start, start - global_basis.z * maximum_distance)
	query.collision_mask = 8
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	var distance := maximum_distance
	var hovering := false
	if not result.is_empty():
		distance = start.distance_to(result["position"])
		hovering = result["collider"].has_meta("menu_action")
	beam_mesh.height = distance
	beam.position = Vector3(0, 0, -distance * 0.5)
	pointer_dot.position = Vector3(0, 0, -distance)
	var color := Color(0.1, 1.0, 0.25) if hovering else Color(0.1, 0.65, 1.0)
	beam_material.albedo_color = color
	beam_material.emission = color
	dot_material.albedo_color = color
	dot_material.emission = color

