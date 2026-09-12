extends Node

signal status_changed(message: String)

@export var server_url := "ws://127.0.0.1:8080"
@export var default_room := "THATVRKIDD"
@export var player_path: NodePath = NodePath("../Player")

var socket := WebSocketPeer.new()
var connected := false
var room_code := ""
var local_id := ""
var remote_players: Dictionary = {}
var send_accumulator := 0.0

func _process(delta: float) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		if connected:
			connected = false
			clear_remote_players()
			status_changed.emit("Disconnected")
		return
	socket.poll()
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	if not connected:
		connected = true
		status_changed.emit("Server connected")
	while socket.get_available_packet_count() > 0:
		handle_packet(socket.get_packet().get_string_from_utf8())
	send_accumulator += delta
	if send_accumulator >= 0.05 and room_code != "":
		send_accumulator = 0.0
		send_local_pose()

func connect_public_room() -> void:
	connect_to_room(default_room)

func connect_to_room(code: String) -> void:
	room_code = sanitize_room(code)
	if room_code == "":
		room_code = default_room
	var error := socket.connect_to_url(server_url)
	if error != OK:
		status_changed.emit("Connection failed: %s" % error_string(error))
		return
	status_changed.emit("Connecting to %s" % room_code)

func disconnect_room() -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify({"type": "leave"}))
		socket.close(1000, "Menu disconnect")
	connected = false
	room_code = ""
	clear_remote_players()
	status_changed.emit("Disconnected")

func sanitize_room(code: String) -> String:
	var result := ""
	for character in code.to_upper():
		if character in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789":
			result += character
	return result.left(12)

func handle_packet(text: String) -> void:
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	match str(data.get("type", "")):
		"welcome":
			local_id = str(data.get("id", ""))
			socket.send_text(JSON.stringify({"type": "join", "room": room_code}))
			status_changed.emit("Joined room %s" % room_code)
		"pose":
			var peer_id := str(data.get("id", ""))
			if peer_id != "" and peer_id != local_id:
				update_remote_pose(peer_id, data)
		"left":
			remove_remote_player(str(data.get("id", "")))
		"tag":
			var target_id := str(data.get("target", ""))
			if target_id == local_id:
				get_node(player_path).call("toggle_frozen")

func send_local_pose() -> void:
	var player: Node3D = get_node(player_path)
	var origin: Node3D = player.get_node("XROrigin3D")
	var head: Node3D = origin.get_node("XRCamera3D")
	var left: Node3D = origin.get_node("LeftController")
	var right: Node3D = origin.get_node("RightController")
	var packet := {
		"type": "pose",
		"body": vector_to_array(player.global_position),
		"head": transform_to_array(head.global_transform),
		"left": transform_to_array(left.global_transform),
		"right": transform_to_array(right.global_transform)
	}
	socket.send_text(JSON.stringify(packet))

func send_tag(target_id: String) -> void:
	if connected and target_id != "":
		socket.send_text(JSON.stringify({"type": "tag", "target": target_id}))

func update_remote_pose(peer_id: String, data: Dictionary) -> void:
	var avatar: Node3D = remote_players.get(peer_id)
	if not is_instance_valid(avatar):
		avatar = create_remote_avatar(peer_id)
		remote_players[peer_id] = avatar
	avatar.call("apply_network_pose", data)

func create_remote_avatar(peer_id: String) -> Node3D:
	var avatar := preload("res://Scripts/Network/RemoteAvatar.gd").new()
	avatar.peer_id = peer_id
	get_tree().current_scene.add_child(avatar)
	return avatar

func remove_remote_player(peer_id: String) -> void:
	var avatar: Node = remote_players.get(peer_id)
	if is_instance_valid(avatar):
		avatar.queue_free()
	remote_players.erase(peer_id)

func clear_remote_players() -> void:
	for peer_id in remote_players.keys():
		remove_remote_player(peer_id)

func vector_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func transform_to_array(value: Transform3D) -> Array:
	var rotation := value.basis.get_rotation_quaternion()
	return [value.origin.x, value.origin.y, value.origin.z, rotation.x, rotation.y, rotation.z, rotation.w]
