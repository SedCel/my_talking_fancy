extends Control

const MAIN_SCENE := "res://scenes/MAIN.tscn"

var microphone_selector: OptionButton
var start_button: Button


func _ready() -> void:
	_build_interface()
	_load_microphones()


func _build_interface() -> void:
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 14)
	add_child(content)

	var title := Label.new()
	title.text = "Привет! Я Fancy"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	content.add_child(title)

	var instructions := Label.new()
	instructions.text = "Выбери микрофон, чтобы Fancy мог тебя слушать"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(instructions)

	microphone_selector = OptionButton.new()
	microphone_selector.custom_minimum_size.x = 320
	microphone_selector.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	microphone_selector.item_selected.connect(_on_microphone_selected)
	content.add_child(microphone_selector)

	start_button = Button.new()
	start_button.text = "Продолжить"
	start_button.custom_minimum_size.x = 320
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_button.pressed.connect(_on_start_pressed)
	content.add_child(start_button)


func _load_microphones() -> void:
	microphone_selector.clear()
	var devices := AudioServer.get_input_device_list()
	if devices.is_empty():
		devices.append("Default")

	for device in devices:
		microphone_selector.add_item(device)

	var selected_device := AudioServer.input_device
	var selected_index := devices.find(selected_device)
	if selected_index == -1:
		selected_index = 0
		AudioServer.input_device = devices[selected_index]
	microphone_selector.select(selected_index)


func _on_microphone_selected(index: int) -> void:
	AudioServer.input_device = microphone_selector.get_item_text(index)


func _on_start_pressed() -> void:
	if OS.has_feature("android"):
		OS.request_permissions()

	start_button.disabled = true
	var error := get_tree().change_scene_to_file(MAIN_SCENE)
	if error != OK:
		start_button.disabled = false
		push_error("Не удалось открыть игровую сцену: %s" % error)
