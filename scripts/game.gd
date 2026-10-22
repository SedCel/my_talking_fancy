extends Control

const CAKE_SCENE := preload("res://objects/cake.tscn")
const CAKE_TEXTURE := preload("res://sprites/Cake.png")

var dragged_cake: Area2D
var fancy: CharacterBody2D
var background_sprite: Sprite2D
var background_base_size := Vector2.ZERO
var background_base_scale := Vector2.ONE
var background_file_dialog: FileDialog
var image_error_dialog: AcceptDialog
var food_menu_panel: PanelContainer
var show_menu_button: Button


func _ready() -> void:
	fancy = get_node("Fancy") as CharacterBody2D
	background_sprite = get_node("BackGround") as Sprite2D
	background_base_size = background_sprite.texture.get_size()
	background_base_scale = background_sprite.scale
	_setup_background_picker()
	_build_food_menu()


func _setup_background_picker() -> void:
	background_file_dialog = FileDialog.new()
	background_file_dialog.title = "Выбери изображение для фона"
	background_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	background_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	background_file_dialog.add_filter("*.png", "PNG images")
	background_file_dialog.add_filter("*.jpg,*.jpeg", "JPEG images")
	background_file_dialog.add_filter("*.webp", "WebP images")
	background_file_dialog.add_filter("*.bmp", "BMP images")
	background_file_dialog.add_filter("*.tga", "TGA images")
	background_file_dialog.file_selected.connect(_on_background_file_selected)
	add_child(background_file_dialog)

	image_error_dialog = AcceptDialog.new()
	image_error_dialog.title = "Не удалось загрузить фон"
	add_child(image_error_dialog)


func _build_food_menu() -> void:
	food_menu_panel = PanelContainer.new()
	food_menu_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	food_menu_panel.position = Vector2(20, -250)
	food_menu_panel.custom_minimum_size = Vector2(400, 240)
	add_child(food_menu_panel)

	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 8)
	food_menu_panel.add_child(menu)

	var menu_header := HBoxContainer.new()
	menu_header.add_theme_constant_override("separation", 8)
	menu.add_child(menu_header)

	var menu_title := Label.new()
	menu_title.text = "Меню"
	menu_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_header.add_child(menu_title)

	var hide_menu_button := Button.new()
	hide_menu_button.text = "Свернуть"
	hide_menu_button.pressed.connect(_on_hide_menu_pressed)
	menu_header.add_child(hide_menu_button)

	var food_menu := HBoxContainer.new()
	food_menu.add_theme_constant_override("separation", 8)
	menu.add_child(food_menu)
	var cake_icon := TextureRect.new()
	cake_icon.texture = CAKE_TEXTURE
	cake_icon.custom_minimum_size = Vector2(48, 48)
	cake_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cake_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cake_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	food_menu.add_child(cake_icon)

	var food_button := Button.new()
	food_button.text = "Зажми и перетащи"
	food_button.custom_minimum_size = Vector2(200, 60)
	food_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	food_button.focus_mode = Control.FOCUS_NONE
	food_button.button_down.connect(_on_food_button_down)
	food_button.button_up.connect(_on_food_button_up)
	food_menu.add_child(food_button)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	menu.add_child(actions)

	var yes_no_toggle := CheckButton.new()
	yes_no_toggle.text = "Режим да/нет"
	yes_no_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes_no_toggle.toggled.connect(_on_yes_no_mode_toggled)
	actions.add_child(yes_no_toggle)

	var background_button := Button.new()
	background_button.text = "Выбрать задний фон"
	background_button.custom_minimum_size = Vector2(0, 40)
	background_button.pressed.connect(_on_background_button_pressed)
	menu.add_child(background_button)

	show_menu_button = Button.new()
	show_menu_button.text = "Показать меню"
	show_menu_button.custom_minimum_size = Vector2(170, 44)
	show_menu_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	show_menu_button.position = Vector2(20, -55)
	show_menu_button.pressed.connect(_on_show_menu_pressed)
	show_menu_button.hide()
	add_child(show_menu_button)


func _on_hide_menu_pressed() -> void:
	food_menu_panel.hide()
	show_menu_button.show()


func _on_show_menu_pressed() -> void:
	show_menu_button.hide()
	food_menu_panel.show()


func _on_background_button_pressed() -> void:
	background_file_dialog.popup_centered(Vector2i(800, 600))


func _on_background_file_selected(path: String) -> void:
	var image := Image.new()
	var error := image.load(path)
	if error != OK or image.is_empty():
		image_error_dialog.dialog_text = "Не удалось открыть изображение:\n%s" % path
		image_error_dialog.popup_centered()
		push_error("Не удалось загрузить изображение фона '%s' (код %d)." % [path, error])
		return

	background_sprite.texture = ImageTexture.create_from_image(image)
	var new_image_size := Vector2(image.get_width(), image.get_height())
	var target_size := background_base_size * background_base_scale
	var cover_scale := maxf(
		target_size.x / new_image_size.x,
		target_size.y / new_image_size.y
	)
	background_sprite.scale = Vector2.ONE * cover_scale


func _on_yes_no_mode_toggled(enabled: bool) -> void:
	fancy.call("set_yes_no_mode", enabled)


func _on_food_button_down() -> void:
	dragged_cake = CAKE_SCENE.instantiate() as Area2D
	add_child(dragged_cake)
	dragged_cake.scale = Vector2(0.25, 0.25)
	dragged_cake.global_position = get_global_mouse_position()
	dragged_cake.call("begin_drag")


func _on_food_button_up() -> void:
	if is_instance_valid(dragged_cake):
		dragged_cake.call("end_drag")
	dragged_cake = null
