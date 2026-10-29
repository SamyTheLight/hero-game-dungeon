extends CharacterBody2D

const ARRIVAL_DISTANCE: float = 0.1

## Movement speed in pixels per second.
@export_range(1.0, 1000.0, 1.0) var move_speed: float = 300.0
## Time in seconds before a click starts following the mouse.
@export_range(0.05, 1.0, 0.01) var hold_threshold: float = 0.2

var _target_position: Vector2
var _is_moving: bool = false
var _is_mouse_pressed: bool = false
var _mouse_press_time_msec: int = 0


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	# Handle releases even when the pointer is over a UI control.
	if not event.pressed and _is_mouse_pressed:
		_end_mouse_press()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return

	_is_mouse_pressed = true
	_mouse_press_time_msec = Time.get_ticks_msec()
	_target_position = get_global_mouse_position()
	_is_moving = true
	get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_update_mouse_hold()
	if _is_moving:
		_move_toward_target(delta)


func _update_mouse_hold() -> void:
	if not _is_mouse_pressed:
		return

	# Recover if the mouse release event was missed.
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_end_mouse_press()
	elif _is_mouse_held():
		_target_position = get_global_mouse_position()
		_is_moving = true


func _move_toward_target(delta: float) -> void:
	var offset_to_target := _target_position - global_position
	var distance_to_target := offset_to_target.length()
	if distance_to_target < ARRIVAL_DISTANCE:
		_stop_moving()
		return

	velocity = offset_to_target.normalized() * move_speed
	# Shorten the final step so movement never overshoots the destination.
	var motion := (velocity * delta).limit_length(distance_to_target)
	var collision := move_and_collide(motion)
	if collision != null or global_position.distance_to(_target_position) < ARRIVAL_DISTANCE:
		_stop_moving()


func _is_mouse_held() -> bool:
	var elapsed_msec := Time.get_ticks_msec() - _mouse_press_time_msec
	return elapsed_msec >= hold_threshold * 1000.0


func _end_mouse_press() -> void:
	# Short clicks keep their destination; releasing a held click stops movement.
	if _is_mouse_held():
		_stop_moving()
	_is_mouse_pressed = false


func _stop_moving() -> void:
	_is_moving = false
	velocity = Vector2.ZERO
