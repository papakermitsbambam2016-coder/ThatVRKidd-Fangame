extends Node3D

func _ready() -> void:
	var xr_interface := XRServer.find_interface("OpenXR")
	if xr_interface == null:
		push_error("ThatVRKidd: OpenXR interface was not found.")
		return
	if not xr_interface.is_initialized() and not xr_interface.initialize():
		push_error("ThatVRKidd: OpenXR failed to initialize.")
		return
	get_viewport().use_xr = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("ThatVRKidd: OpenXR initialized successfully.")

