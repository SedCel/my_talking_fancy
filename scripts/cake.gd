extends Area2D

signal drag_released

var is_dragging := false
var has_been_released := false


func begin_drag() -> void:
	is_dragging = true
	has_been_released = false


func end_drag() -> void:
	if not is_dragging:
		return
	is_dragging = false
	has_been_released = true
	drag_released.emit()


func _process(_delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position()


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed and _mouse_is_over_cake():
		begin_drag()
		get_viewport().set_input_as_handled()
	elif not event.pressed and is_dragging:
		end_drag()
		get_viewport().set_input_as_handled()


func _mouse_is_over_cake() -> bool:
	var texture_size: Vector2 = $Sprite2D.texture.get_size()
	var local_mouse := to_local(get_global_mouse_position())
	return Rect2(-texture_size / 2.0, texture_size).has_point(local_mouse)
