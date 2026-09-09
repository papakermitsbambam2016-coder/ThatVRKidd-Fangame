extends Node3D

func _ready() -> void:
	create_box(Vector3(0, 1.5, -8), Vector3(12, 3, 0.5), Color(0.34, 0.17, 0.08))
	create_box(Vector3(-6, 1.5, -2), Vector3(0.5, 3, 12), Color(0.34, 0.17, 0.08))
	create_box(Vector3(6, 1.5, -2), Vector3(0.5, 3, 12), Color(0.34, 0.17, 0.08))
	for location in [Vector3(-3, 1.0, -3), Vector3(3, 1.5, -5), Vector3(0, 2.1, -7)]:
		create_box(location, Vector3(2.4, 0.25, 2.4), Color(0.45, 0.25, 0.1))
	for location in [Vector3(-4, 1.5, -6), Vector3(4, 1.5, -2), Vector3(0, 1.5, -4)]:
		create_tree(location)

func create_tree(location: Vector3) -> void:
	create_box(location, Vector3(0.65, 3.0, 0.65), Color(0.3, 0.14, 0.05))
	create_box(location + Vector3(0, 2.0, 0), Vector3(2.2, 1.2, 2.2), Color(0.08, 0.38, 0.12))

func create_box(location: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = location
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	visual.material_override = material
	body.add_child(visual)
	add_child(body)

