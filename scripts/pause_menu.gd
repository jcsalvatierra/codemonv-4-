extends CanvasLayer

signal paused_state_changed(is_paused: bool)

# Control references
var root_panel: Control = null
var main_pause_container: Control = null
var confirm_dialog: Control = null
var confirm_title_lbl: Label = null
var confirm_msg_lbl: Label = null
var confirm_action_btn: Button = null

# Sliders and value labels
var slider_master: HSlider = null
var slider_music: HSlider = null
var slider_sfx: HSlider = null
var lbl_master: Label = null
var lbl_music: Label = null
var lbl_sfx: Label = null

# Buttons
var btn_resume: Button = null
var btn_controls: Button = null
var btn_main_menu: Button = null
var btn_quit: Button = null
var btn_confirm_cancel: Button = null

var is_paused: bool = false
var pending_action: String = "" # "quit" or "main_menu"

func _ready() -> void:
	# Persistent pause overlay
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 35 # Render above HUD, dialogue, and terminal
	_build_pause_ui()
	hide()

func _unhandled_input(event: InputEvent) -> void:
	# Toggle pause via Escape or P
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_P)):
		if is_paused:
			if confirm_dialog and confirm_dialog.visible:
				_close_confirm_dialog()
			else:
				resume_game()
			get_viewport().set_input_as_handled()
		else:
			if _can_pause():
				open_pause()
				get_viewport().set_input_as_handled()

func _can_pause() -> bool:
	if GameManager.current_state == GameManager.GameState.MAIN_MENU:
		return false
	if GameManager.current_state == GameManager.GameState.GAME_OVER:
		return false
	if GameManager.current_state == GameManager.GameState.VICTORY:
		return false
	return true

func open_pause() -> void:
	if is_paused:
		return
		
	is_paused = true
	get_tree().paused = true
	
	_sync_slider_values()
	_close_confirm_dialog()
	main_pause_container.show()
	show()
	
	if btn_resume:
		btn_resume.grab_focus()
		
	_play_click_sfx()
	paused_state_changed.emit(true)
	print("GAME PAUSED")

func resume_game() -> void:
	if not is_paused:
		return
		
	is_paused = false
	_close_confirm_dialog()
	hide()
	get_tree().paused = false
	
	_play_click_sfx()
	paused_state_changed.emit(false)
	print("GAME RESUMED")

func _sync_slider_values() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		if slider_master and audio.has_method("get_master_volume"):
			slider_master.value = audio.get_master_volume()
			_update_slider_label(lbl_master, "Master", slider_master.value)
		if slider_music and audio.has_method("get_music_volume"):
			slider_music.value = audio.get_music_volume()
			_update_slider_label(lbl_music, "Music", slider_music.value)
		if slider_sfx and audio.has_method("get_sfx_volume"):
			slider_sfx.value = audio.get_sfx_volume()
			_update_slider_label(lbl_sfx, "SFX", slider_sfx.value)

func _update_slider_label(lbl: Label, title: String, val: float) -> void:
	if lbl:
		lbl.text = "%s: %d%%" % [title, round(val * 100)]

func _play_click_sfx() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_ui_click"):
		audio.play_ui_click()

# ==========================================
# SLIDER HANDLERS
# ==========================================
func _on_master_value_changed(val: float) -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("set_master_volume"):
		audio.set_master_volume(val)
	_update_slider_label(lbl_master, "Master", val)

func _on_music_value_changed(val: float) -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("set_music_volume"):
		audio.set_music_volume(val)
	_update_slider_label(lbl_music, "Music", val)

func _on_sfx_value_changed(val: float) -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("set_sfx_volume"):
		audio.set_sfx_volume(val)
	_update_slider_label(lbl_sfx, "SFX", val)

func _on_sfx_drag_ended(value_changed: bool) -> void:
	if value_changed:
		_play_click_sfx()

# ==========================================
# BUTTON HANDLERS & CONFIRMATION DIALOG
# ==========================================
func _on_resume_pressed() -> void:
	resume_game()

func _on_controls_pressed() -> void:
	_play_click_sfx()
	GameManager.show_controls_popup()

func _on_main_menu_pressed() -> void:
	_play_click_sfx()
	pending_action = "main_menu"
	_show_confirm_dialog(
		"RETURN TO MAIN MENU",
		"Are you sure you want to return to Main Menu?\nIf you quit now, any unsaved session progress will reset.",
		"Return to Menu"
	)

func _on_quit_pressed() -> void:
	_play_click_sfx()
	pending_action = "quit"
	_show_confirm_dialog(
		"QUIT GAME",
		"Are you sure you want to quit the game?\nIf you quit, your progress will reset.",
		"Quit Game"
	)

func _show_confirm_dialog(title: String, message: String, action_btn_text: String) -> void:
	if confirm_title_lbl:
		confirm_title_lbl.text = title
	if confirm_msg_lbl:
		confirm_msg_lbl.text = message
	if confirm_action_btn:
		confirm_action_btn.text = action_btn_text
		
	confirm_dialog.show()
	if btn_confirm_cancel:
		btn_confirm_cancel.grab_focus()

func _close_confirm_dialog() -> void:
	if confirm_dialog:
		confirm_dialog.hide()
	pending_action = ""
	if is_paused and btn_resume:
		btn_resume.grab_focus()

func _on_confirm_action_pressed() -> void:
	_play_click_sfx()
	if pending_action == "quit":
		print("Quitting Game via Pause Menu (Progress Reset)")
		get_tree().paused = false
		is_paused = false
		get_tree().quit()
	elif pending_action == "main_menu":
		print("Returning to Main Menu via Pause Menu (Progress Reset)")
		get_tree().paused = false
		is_paused = false
		hide()
		GameManager.go_to_main_menu()

# ==========================================
# PROGRAMMATIC UI BUILDER
# ==========================================
func _build_pause_ui() -> void:
	root_panel = Control.new()
	root_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://dialogue.tres"):
		root_panel.theme = load("res://dialogue.tres")
	add_child(root_panel)
	
	# Dimmed backdrop
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.04, 0.08, 0.06, 0.88)
	root_panel.add_child(backdrop)
	
	# ------------------------------------------
	# MAIN PAUSE CONTAINER
	# ------------------------------------------
	main_pause_container = CenterContainer.new()
	main_pause_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_panel.add_child(main_pause_container)
	
	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.13, 0.10, 0.96)
	panel_style.border_color = Color(0.24, 0.65, 0.40, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", panel_style)
	main_pause_container.add_child(panel)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.custom_minimum_size = Vector2(360, 0)
	main_vbox.add_theme_constant_override("separation", 6)
	panel.add_child(main_vbox)
	
	# Title & Subtitle Header
	var title = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55, 1.0))
	main_vbox.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "System Configuration"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.85, 0.75, 1.0))
	main_vbox.add_child(subtitle)
	
	var sep1 = HSeparator.new()
	main_vbox.add_child(sep1)
	
	# Two-Column Body: Left = Audio Sliders, Right = Action Buttons
	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	main_vbox.add_child(columns)
	
	# --- Left Column: Audio Controls ---
	var audio_vbox = VBoxContainer.new()
	audio_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_vbox.add_theme_constant_override("separation", 4)
	columns.add_child(audio_vbox)
	
	# Master Volume
	lbl_master = Label.new()
	lbl_master.text = "Master: 100%"
	lbl_master.add_theme_font_size_override("font_size", 16)
	audio_vbox.add_child(lbl_master)
	
	slider_master = HSlider.new()
	slider_master.min_value = 0.0
	slider_master.max_value = 1.0
	slider_master.step = 0.02
	slider_master.value = 1.0
	slider_master.value_changed.connect(_on_master_value_changed)
	audio_vbox.add_child(slider_master)
	
	# Music Volume
	lbl_music = Label.new()
	lbl_music.text = "Music: 100%"
	lbl_music.add_theme_font_size_override("font_size", 16)
	audio_vbox.add_child(lbl_music)
	
	slider_music = HSlider.new()
	slider_music.min_value = 0.0
	slider_music.max_value = 1.0
	slider_music.step = 0.02
	slider_music.value = 1.0
	slider_music.value_changed.connect(_on_music_value_changed)
	audio_vbox.add_child(slider_music)
	
	# SFX Volume
	lbl_sfx = Label.new()
	lbl_sfx.text = "SFX: 100%"
	lbl_sfx.add_theme_font_size_override("font_size", 16)
	audio_vbox.add_child(lbl_sfx)
	
	slider_sfx = HSlider.new()
	slider_sfx.min_value = 0.0
	slider_sfx.max_value = 1.0
	slider_sfx.step = 0.02
	slider_sfx.value = 1.0
	slider_sfx.value_changed.connect(_on_sfx_value_changed)
	slider_sfx.drag_ended.connect(_on_sfx_drag_ended)
	audio_vbox.add_child(slider_sfx)
	
	# --- Right Column: Action Buttons ---
	var actions_vbox = VBoxContainer.new()
	actions_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_vbox.add_theme_constant_override("separation", 6)
	columns.add_child(actions_vbox)
	
	btn_resume = Button.new()
	btn_resume.text = "Resume Game"
	btn_resume.custom_minimum_size = Vector2(0, 26)
	btn_resume.add_theme_font_size_override("font_size", 16)
	btn_resume.pressed.connect(_on_resume_pressed)
	actions_vbox.add_child(btn_resume)
	
	btn_controls = Button.new()
	btn_controls.text = "View Controls"
	btn_controls.custom_minimum_size = Vector2(0, 26)
	btn_controls.add_theme_font_size_override("font_size", 16)
	btn_controls.pressed.connect(_on_controls_pressed)
	actions_vbox.add_child(btn_controls)
	
	btn_main_menu = Button.new()
	btn_main_menu.text = "Return to Menu"
	btn_main_menu.custom_minimum_size = Vector2(0, 26)
	btn_main_menu.add_theme_font_size_override("font_size", 16)
	btn_main_menu.pressed.connect(_on_main_menu_pressed)
	actions_vbox.add_child(btn_main_menu)
	
	# Quit Game at the bottom of the actions column!
	btn_quit = Button.new()
	btn_quit.text = "Quit Game"
	btn_quit.custom_minimum_size = Vector2(0, 26)
	btn_quit.add_theme_font_size_override("font_size", 16)
	btn_quit.pressed.connect(_on_quit_pressed)
	actions_vbox.add_child(btn_quit)
	
	# ------------------------------------------
	# CONFIRMATION DIALOG (Popup)
	# ------------------------------------------
	confirm_dialog = Control.new()
	confirm_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_panel.add_child(confirm_dialog)
	
	var confirm_dim = ColorRect.new()
	confirm_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_dim.color = Color(0.02, 0.04, 0.03, 0.75)
	confirm_dialog.add_child(confirm_dim)
	
	var confirm_center = CenterContainer.new()
	confirm_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_dialog.add_child(confirm_center)
	
	var confirm_panel = PanelContainer.new()
	var confirm_style = StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.14, 0.06, 0.06, 0.98)
	confirm_style.border_color = Color(0.9, 0.25, 0.25, 1.0)
	confirm_style.set_border_width_all(2)
	confirm_style.set_corner_radius_all(6)
	confirm_style.content_margin_left = 18
	confirm_style.content_margin_right = 18
	confirm_style.content_margin_top = 14
	confirm_style.content_margin_bottom = 14
	confirm_panel.add_theme_stylebox_override("panel", confirm_style)
	confirm_center.add_child(confirm_panel)
	
	var confirm_vbox = VBoxContainer.new()
	confirm_vbox.custom_minimum_size = Vector2(280, 0)
	confirm_vbox.add_theme_constant_override("separation", 8)
	confirm_panel.add_child(confirm_vbox)
	
	confirm_title_lbl = Label.new()
	confirm_title_lbl.text = "QUIT GAME"
	confirm_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_title_lbl.add_theme_font_size_override("font_size", 16)
	confirm_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1.0))
	confirm_vbox.add_child(confirm_title_lbl)
	
	confirm_msg_lbl = Label.new()
	confirm_msg_lbl.text = "Are you sure you want to quit?\nIf you quit, your progress will reset."
	confirm_msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_msg_lbl.add_theme_font_size_override("font_size", 16)
	confirm_msg_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.85, 1.0))
	confirm_vbox.add_child(confirm_msg_lbl)
	
	var sep3 = HSeparator.new()
	confirm_vbox.add_child(sep3)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 10)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_vbox.add_child(btn_hbox)
	
	btn_confirm_cancel = Button.new()
	btn_confirm_cancel.text = "Cancel"
	btn_confirm_cancel.custom_minimum_size = Vector2(95, 28)
	btn_confirm_cancel.add_theme_font_size_override("font_size", 16)
	btn_confirm_cancel.pressed.connect(_close_confirm_dialog)
	btn_hbox.add_child(btn_confirm_cancel)
	
	confirm_action_btn = Button.new()
	confirm_action_btn.text = "Quit Game"
	confirm_action_btn.custom_minimum_size = Vector2(105, 28)
	confirm_action_btn.add_theme_font_size_override("font_size", 16)
	confirm_action_btn.pressed.connect(_on_confirm_action_pressed)
	btn_hbox.add_child(confirm_action_btn)
	
	confirm_dialog.hide()
