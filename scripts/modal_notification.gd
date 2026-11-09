class_name ModalNotification
extends CanvasLayer

signal dismissed

var root_control: Control = null
var btn_ok: Button = null
var image_rect: TextureRect = null
var message_label: Label = null
var title_label: Label = null
var on_dismiss_callback: Callable = Callable()

var title_text: String = ""
var message_text: String = ""
var display_image: Texture2D = null
var button_label: String = "Got It"

static func create(title: String, message: String, image: Texture2D = null, btn_text: String = "Got It", on_dismiss: Callable = Callable()) -> ModalNotification:
	var modal = ModalNotification.new()
	modal.title_text = title
	modal.message_text = message
	modal.display_image = image
	modal.button_label = btn_text
	modal.on_dismiss_callback = on_dismiss
	return modal

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 45 # Highest priority overlay
	
	# Pause the tree while player reads the modal
	get_tree().paused = true
	
	_build_ui()
	
	if btn_ok:
		btn_ok.grab_focus()

func _build_ui() -> void:
	root_control = Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://dialogue.tres"):
		root_control.theme = load("res://dialogue.tres")
	add_child(root_control)
	
	# Dimmed backdrop
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.05, 0.03, 0.85)
	root_control.add_child(backdrop)
	
	# Center container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(center)
	
	# Modal Box Panel
	var panel = PanelContainer.new()
	if ResourceLoader.exists("res://dialogue.tres"):
		panel.theme = load("res://dialogue.tres")
	if ResourceLoader.exists("res://dialogue_box.tres"):
		panel.add_theme_stylebox_override("panel", load("res://dialogue_box.tres"))
	else:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1.0, 1.0, 1.0, 1.0)
		style.border_color = Color(0.39, 0.61, 0.42, 1.0)
		style.set_border_width_all(4)
		style.set_corner_radius_all(8)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		panel.add_theme_stylebox_override("panel", style)
		
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(280, 0)
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	
	# Title
	title_label = Label.new()
	title_label.text = title_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.08, 0.35, 0.15, 1.0))
	if ResourceLoader.exists("res://assets/fonts/pokemon-emerald.otf"):
		title_label.add_theme_font_override("font", load("res://assets/fonts/pokemon-emerald.otf"))
	vbox.add_child(title_label)
	
	# Image section (if provided)
	if display_image != null:
		var img_frame = PanelContainer.new()
		var frame_style = StyleBoxFlat.new()
		frame_style.bg_color = Color(0.12, 0.18, 0.14, 1.0)
		frame_style.border_color = Color(0.24, 0.65, 0.38, 1.0)
		frame_style.set_border_width_all(2)
		frame_style.set_corner_radius_all(4)
		frame_style.content_margin_left = 4
		frame_style.content_margin_right = 4
		frame_style.content_margin_top = 4
		frame_style.content_margin_bottom = 4
		img_frame.add_theme_stylebox_override("panel", frame_style)
		
		image_rect = TextureRect.new()
		image_rect.texture = display_image
		image_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image_rect.custom_minimum_size = Vector2(220, 100)
		img_frame.add_child(image_rect)
		
		# Center the frame in the vbox
		var img_center = CenterContainer.new()
		img_center.add_child(img_frame)
		vbox.add_child(img_center)
		
	# Message
	message_label = Label.new()
	message_label.text = message_text
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	message_label.custom_minimum_size = Vector2(270, 0)
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1.0))
	if ResourceLoader.exists("res://assets/fonts/pokemon-emerald.otf"):
		message_label.add_theme_font_override("font", load("res://assets/fonts/pokemon-emerald.otf"))
	vbox.add_child(message_label)
	
	# Subtle separator
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	# Action Button ("Got It")
	var btn_center = CenterContainer.new()
	btn_ok = Button.new()
	btn_ok.text = button_label
	btn_ok.custom_minimum_size = Vector2(100, 22)
	if ResourceLoader.exists("res://dialogue.tres"):
		btn_ok.theme = load("res://dialogue.tres")
	btn_ok.add_theme_font_size_override("font_size", 14)
	
	var btn_norm = StyleBoxFlat.new()
	btn_norm.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	btn_norm.border_color = Color(0.3882353, 0.60784316, 0.41568628, 1.0)
	btn_norm.set_border_width_all(2)
	btn_norm.set_corner_radius_all(4)
	btn_norm.content_margin_left = 8
	btn_norm.content_margin_right = 8
	btn_norm.content_margin_top = 2
	btn_norm.content_margin_bottom = 2
	
	var btn_focus = StyleBoxFlat.new()
	btn_focus.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	btn_focus.border_color = Color(1.0, 0.09, 0.257, 1.0)
	btn_focus.set_border_width_all(2)
	btn_focus.set_corner_radius_all(4)
	btn_focus.content_margin_left = 8
	btn_focus.content_margin_right = 8
	btn_focus.content_margin_top = 2
	btn_focus.content_margin_bottom = 2
	
	btn_ok.add_theme_stylebox_override("normal", btn_norm)
	btn_ok.add_theme_stylebox_override("hover", btn_focus)
	btn_ok.add_theme_stylebox_override("focus", btn_focus)
	btn_ok.pressed.connect(_on_btn_ok_pressed)
	btn_center.add_child(btn_ok)
	vbox.add_child(btn_center)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_btn_ok_pressed()

func _on_btn_ok_pressed() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_ui_click"):
		audio.play_ui_click()
		
	get_tree().paused = false
	dismissed.emit()
	if on_dismiss_callback.is_valid():
		on_dismiss_callback.call()
	queue_free()
