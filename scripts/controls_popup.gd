extends CanvasLayer

signal controls_closed

var root_control: Control = null
var btn_ok: Button = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40 # Renders on top of gameplay HUD and Pause Menu (35)
	
	# Pause the world while player reads the controls
	get_tree().paused = true
	
	_build_ui()
	
	# Focus the confirm button so Space/Enter immediately works
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
	backdrop.color = Color(0.03, 0.06, 0.04, 0.85)
	root_control.add_child(backdrop)
	
	# Center container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(center)
	
	# Retro Cyber Panel
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.13, 0.10, 0.96)
	style.border_color = Color(0.24, 0.75, 0.45, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(310, 0)
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "GAME CONTROLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55, 1.0))
	vbox.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "Basic Operation Protocol"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.85, 0.75, 1.0))
	vbox.add_child(subtitle)
	
	var sep1 = HSeparator.new()
	vbox.add_child(sep1)
	
	# Controls grid
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(grid)
	
	# Row 1: Movement
	var lbl_move_key = Label.new()
	lbl_move_key.text = "WASD or Arrow Keys"
	lbl_move_key.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4, 1.0))
	lbl_move_key.add_theme_font_size_override("font_size", 16)
	grid.add_child(lbl_move_key)
	
	var lbl_move_desc = Label.new()
	lbl_move_desc.text = "Move Character"
	lbl_move_desc.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	lbl_move_desc.add_theme_font_size_override("font_size", 16)
	grid.add_child(lbl_move_desc)
	
	# Row 2: Interaction
	var lbl_interact_key = Label.new()
	lbl_interact_key.text = "Space / Enter"
	lbl_interact_key.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4, 1.0))
	lbl_interact_key.add_theme_font_size_override("font_size", 16)
	grid.add_child(lbl_interact_key)
	
	var lbl_interact_desc = Label.new()
	lbl_interact_desc.text = "Interact / Talk"
	lbl_interact_desc.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	lbl_interact_desc.add_theme_font_size_override("font_size", 16)
	grid.add_child(lbl_interact_desc)
	
	# Row 3: Quests
	var lbl_quest_key = Label.new()
	lbl_quest_key.text = "Tab / Q"
	lbl_quest_key.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 1.0))
	lbl_quest_key.add_theme_font_size_override("font_size", 16)
	grid.add_child(lbl_quest_key)
	
	var lbl_quest_desc = Label.new()
	lbl_quest_desc.text = "Quest Log"
	lbl_quest_desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	lbl_quest_desc.add_theme_font_size_override("font_size", 16)
	grid.add_child(lbl_quest_desc)
	
	# Row 4: Pause
	var lbl_pause_key = Label.new()
	lbl_pause_key.text = "Esc / P"
	lbl_pause_key.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 1.0))
	lbl_pause_key.add_theme_font_size_override("font_size", 16)
	grid.add_child(lbl_pause_key)
	
	var lbl_pause_desc = Label.new()
	lbl_pause_desc.text = "Pause & Audio"
	lbl_pause_desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	lbl_pause_desc.add_theme_font_size_override("font_size", 16)
	grid.add_child(lbl_pause_desc)
	
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)
	
	# Continue Button
	btn_ok = Button.new()
	btn_ok.text = "Got It! [Press Space / Enter]"
	btn_ok.custom_minimum_size = Vector2(0, 30)
	btn_ok.add_theme_font_size_override("font_size", 16)
	btn_ok.pressed.connect(_dismiss)
	vbox.add_child(btn_ok)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_dismiss()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE:
			_dismiss()
			get_viewport().set_input_as_handled()

func _dismiss() -> void:
	# Check if pause menu is currently open
	var pause_menu = GameManager.pause_menu_instance if ("pause_menu_instance" in GameManager and GameManager.pause_menu_instance != null and is_instance_valid(GameManager.pause_menu_instance)) else null
	var was_pause_menu_open = pause_menu != null and pause_menu.is_paused
	
	if was_pause_menu_open:
		# Preserve paused state for the pause menu
		get_tree().paused = true
		if pause_menu.btn_controls and is_instance_valid(pause_menu.btn_controls):
			pause_menu.btn_controls.grab_focus()
	else:
		# Unpause world
		get_tree().paused = false
	
	# Play click SFX
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_ui_click"):
		audio.play_ui_click()
		
	controls_closed.emit()
	
	if root_control:
		var tween = create_tween()
		tween.tween_property(root_control, "modulate:a", 0.0, 0.15)
		tween.tween_callback(queue_free)
	else:
		queue_free()
