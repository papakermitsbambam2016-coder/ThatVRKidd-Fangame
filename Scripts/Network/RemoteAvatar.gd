extends Node3D

var peer_id := ""
var head: MeshInstance3D
var left_hand: MeshInstance3D
var right_hand: MeshInstance3D

func _ready() -> void:
	add_to_group("tag_targets")
	head = make_part(0.14, Color(0.2, 0.85, 1.0))
	left_hand = make_part(0.09, Color(0.2, 0.55, 1.0))
	right_hand = make_part(0.09, Color(1.0, 0.3, 0.25))

func make_part(radius: float, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	part.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	part.material_override = material
	var hit_area := Area3D.new()
	hit_area.collision_layer = 4
	hit_area.collision_mask = 0
	var hit_shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = radius * 1.35
	hit_shape.shape = sphere_shape
	hit_area.add_child(hit_shape)
	part.add_child(hit_area)
	add_child(part)
	return part

func apply_network_pose(data: Dictionary) -> void:
	if head == null:
		return
	apply_part(head, data.get("head", []))
	apply_part(left_hand, data.get("left", []))
	apply_part(right_hand, data.get("right", []))

func apply_part(part: Node3D, packed: Array) -> void:
	if packed.size() != 7:
		return
	var target_position := Vector3(float(packed[0]), float(packed[1]), float(packed[2]))
	var target_rotation := Quaternion(float(packed[3]), float(packed[4]), float(packed[5]), float(packed[6]))
	part.global_position = part.global_position.lerp(target_position, 0.45)
	var current_rotation := part.global_basis.get_rotation_quaternion()
	part.global_basis = Basis(current_rotation.slerp(target_rotation, 0.45))

func receive_tag(_tagger_id: int) -> void:
	var network := get_tree().current_scene.get_node_or_null("NetworkManager")
	if network != null:
		network.call("send_tag", peer_id)
