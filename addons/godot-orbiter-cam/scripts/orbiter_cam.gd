@tool

extends Node3D


class_name OrbiterCam


# Affects "current" property of the Camera.
@export var _current_camera := false


# _orbit_speed affects how quickly the camera reaches the target orientation.
# Lower value result in taking longer to orbit, while higher values result in a faster response.
# Set value to 1 to make rotation instantaneous.
# A value of 0 will make the camera frozen, regardless of target orientation.
# Use set_orbit_speed and get_orbit_speed to modify and read the value of this variable, respectively.
@export var _orbit_speed := 0.1 # (float, 0, 1)

# _zoom_speed affects how quickly the camera reaches the target zoom.
# Note that in this case, zoom does not mean FOV change, but move cam closer to orbit center.
# Lower value result in taking longer to zoom, while higher values result in a faster response.
# Set value to 1 to make zoom instantaneous.
# A value of 0 will make the zoom frozen, regardless of target orientation.
# Use set_zoom_speed and get_zoom_speed to modify and read the value of this variable, respectively.
@export var _zoom_speed := 0.05 # (float, 0, 1)

# Initial camera zoom.
@export var _initial_zoom := 0.0 # (float, 0, 50)

# To set initial camera orientation, rotate OrbiterCam by hand.

# Zoom bounds
# Viewing zoom bounds is only for editor.
@export var _view_zoom_bounds := false
@export var _zoom_limit_close := 1.0 # (float, 0, 1000)
@export var _zoom_limit_far := 10.0 # (float, 0, 1000)

# Orbit pitch bounds in degrees
@export var _pitch_limit_min := -90.0 # (float, -90, 90)
@export var _pitch_limit_max := 90.0 # (float, -90, 90)

# Enable this if the object you are tracking is physics-related, or is moved during the physics process.
# Disable if the object is not physics-related, or is only moved during the process function.
@export var _is_physics_camera := true

# Whether to check for camera collision
@export var _do_camera_collision := false
# Margin adds a slight difference between collision point and camera to prevent some clipping. 0 doesn't clip too bad,
# but if there are lots of angled walls, it may be beneficial to increase the margin.
@export var _collision_margin := 0.0 # (float, 0, 10)
# If cam collides with areas
@export var _collide_with_areas := false
# If cam collides with bodies
@export var _collide_with_bodies := false

# Whether to use the builtin support for mouse input.
@export var _use_direct_input := false

# If using direct input, whether or not to hide the mouse
# Setting to true sets mouse to MOUSE_MODE_CAPTURED
# Setting to false sets mouse to MOUSE_MODE_VISIBLE.
# If you desire to use a different mouse mode, ignore setting it through this class.
# This export var is only here to make it easy to control in one place, if you won't be doing
# any advanced stuff.
@export var _capture_mouse := false

# If using builtin support for mouse input, this is the factor by which the input is multiplied.
# Use getters and setters to modify or get value.
@export var _mouse_multiplier := 1.0 # (float, 0, 3)
@export var _mousewheel_multiplier := 1.0 # (float, 0, 4)



# _target_rotation is the target orbit in degrees.
# Use set_target_rotation and get_target_rotation.
# Or, check direct input box to enable automatically using mouse for rotation.
var _target_rotation: Vector3 = rotation_degrees

# _target_zoom is the target zoom. Higher values indicate further away from orbit center, aka "zoomed out".
# Use set_target_zoom and get_target_zoom.
# Or, check direct input box to enable automatically using mousewheel for zoom.
@onready var _target_zoom: float = _initial_zoom


@onready var _cam := $Camera3D
@onready var _cam_area := $Camera3D/Area3D
@onready var _raycast := $RayCast3D





func _ready():
	# These setters are vital to use instead of manually editing vars.
	# They modify other values in other nodes, etc.
	set_initial_zoom(_initial_zoom)
	set_collide_with_areas(_collide_with_areas)
	set_collide_with_bodies(_collide_with_bodies)
	set_current_camera(_current_camera)
	set_capture_mouse(_capture_mouse)



func _editor_process(delta):
	# onready vars can be iffy in tools.
	var cam = $Camera3D
	var zoom_min = $ZoomMinDebug
	var zoom_max = $ZoomMaxDebug
	
	cam.position.z = _initial_zoom
	
	zoom_min.visible = _view_zoom_bounds
	zoom_max.visible = _view_zoom_bounds
	zoom_min.position.z = _zoom_limit_close
	zoom_max.position.z = _zoom_limit_far


func _process(delta):
	if Engine.is_editor_hint():
		_editor_process(delta)
		return
	
	if _is_physics_camera:
		return 
		
	_clamp_targets()
	_move_camera()
	_handle_collision()
	

func _clamp_targets() -> void:
	_target_rotation.x = clamp(_target_rotation.x, _pitch_limit_min, _pitch_limit_max)
	_target_zoom = clamp(_target_zoom, _zoom_limit_close, _zoom_limit_far)


func _move_camera():
	rotation_degrees = rotation_degrees.lerp(_target_rotation, _orbit_speed)
	# zoom
	var target_translation = _cam.position
	target_translation.z = _target_zoom
	_cam.position = _cam.position.lerp(target_translation, _zoom_speed)


func _physics_process(delta):
	if Engine.is_editor_hint():
		return
	
	if not _is_physics_camera:
		return
	
	_clamp_targets()
	_move_camera()
	_handle_collision()
		

func _handle_collision() -> void:
	if not _do_camera_collision:
		return
	
	_raycast.target_position = Vector3(0, 0, _target_zoom)
	# Raycast doesn't need to be enabled to force an update.
	_raycast.force_raycast_update()
		
	# Raycast is now updated to current. Check for collision, and if exists, move camera closer to get rid of collision.
	# If a collision forces the camera to be closer than normally allowed, it will come no closer than allowed,
	# even if colliding.
	if not _raycast.is_colliding():
		return
		
	var global_collision_point: Vector3 = _raycast.get_collision_point()
	var local_collision_point: Vector3 = global_collision_point - global_transform.origin	# Sort of... this is a hacky solution. I wasn't able to get a definitive local position, due to not dealing with rotation and scaling.
	
	# Despite the hacky solution, the lenght between the collision point and this origin is correct regardless of rotation. Scaling might mess things up...
	var collided_zoom = max(local_collision_point.length() - _collision_margin, _zoom_limit_close)
	
	_cam.position.z = collided_zoom


func _unhandled_input(event):
	if not _use_direct_input:
		return
		
	if event is InputEventMouseMotion:
		_target_rotation.y += -event.relative.x * 0.05 * _mouse_multiplier
		_target_rotation.x += -event.relative.y * 0.05 * _mouse_multiplier
		
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			add_to_target_zoom(-1 * _mousewheel_multiplier)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			add_to_target_zoom(1 * _mousewheel_multiplier)
		




# Getters and setters
func set_orbit_speed(speed: float) -> void:
	_orbit_speed = speed
func get_orbit_speed() -> float:
	return _orbit_speed
func set_zoom_speed(speed: float) -> void:
	_zoom_speed = speed
func get_zoom_speed() -> float:
	return _zoom_speed
func set_initial_zoom(zoom: float) -> void:
	_initial_zoom = zoom
	_cam.position.z = _initial_zoom
	_target_zoom = _initial_zoom
func get_initial_zoom() -> float:
	return _initial_zoom
func set_zoom_limits(close: float, far: float) -> void:
	_zoom_limit_close = close
	_zoom_limit_far = far
func get_zoom_limits() -> Vector2:
	return Vector2(_zoom_limit_close, _zoom_limit_far)
func set_pitch_limits(_min, _max) -> void:
	_pitch_limit_min = _min
	_pitch_limit_max = _max
func get_pitch_limits() -> Vector2:
	return Vector2(_pitch_limit_min, _pitch_limit_max)
func set_do_camera_collision(do_collision: bool) -> void:
	_do_camera_collision = do_collision
func get_do_camera_collision() -> bool:
	return _do_camera_collision
func set_use_direct_input(use_di: bool) -> void:
	_use_direct_input = use_di
func get_use_direct_input() -> bool:
	return _use_direct_input
func set_mouse_multiplier(factor: float) -> void:
	_mouse_multiplier = factor
func get_mouse_multiplier() -> float:
	return _mouse_multiplier
func set_mousewheel_multiplier(factor: float) -> void:
	_mousewheel_multiplier = factor
func get_mousewheel_multiplier() -> float:
	return _mousewheel_multiplier
func set_target_rotation(target: Vector3) -> void:
	_target_rotation = target
func get_target_rotation() -> Vector3:
	return _target_rotation
func set_target_zoom(target: float) -> void:
	_target_zoom = target
func get_target_zoom() -> float:
	return _target_zoom
func set_current_camera(is_current: bool) -> void:
	_current_camera = is_current
	_cam.current = _current_camera
func get_current_camera() -> bool:
	return _current_camera
func set_collision_margin(margin: float) -> void:
	_collision_margin = margin
func get_collision_margin() -> float:
	return _collision_margin
func set_collide_with_bodies(do_collision: bool) -> void:
	_collide_with_bodies = do_collision
	_raycast.collide_with_bodies = _collide_with_bodies
func get_collide_with_bodies() -> bool:
	return _collide_with_bodies
func set_collide_with_areas(do_collision: bool) -> void:
	_collide_with_areas = do_collision
	_raycast.collide_with_areas = _collide_with_areas
func get_collide_with_areas() -> bool:
	return _collide_with_areas
func set_is_physics_camera(is_physcam: bool) -> void:
	_is_physics_camera = is_physcam
func get_is_phyiscs_camera() -> bool:
	return _is_physics_camera
func set_capture_mouse(capture_mouse: bool) -> void:
	_capture_mouse = capture_mouse
	if Engine.is_editor_hint():
		return
	if capture_mouse:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
func get_capture_mouse() -> bool:
	return _capture_mouse

func add_to_target_rotation(yaw: float, pitch: float) -> void:
	_target_rotation.y += -yaw * 0.001
	_target_rotation.x += -pitch * 0.001
func add_to_target_zoom(amount: float) -> void:
	_target_zoom += amount
	
