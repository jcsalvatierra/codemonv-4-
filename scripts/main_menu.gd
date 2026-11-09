extends Control

@onready var btn_start: Button = get_node_or_null("%StartButton")
@onready var btn_continue: Button = get_node_or_null("%ContinueButton")
@onready var btn_dev: Button = get_node_or_null("%DevModeButton")
@onready var btn_quit: Button = get_node_or_null("%QuitButton")
var btn_profile: Button = null
var btn_leaderboard: Button = null
var btn_how_to_play: Button = null
@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var flash_overlay: ColorRect = get_node_or_null("FlashOverlay")
@onready var menu_box: VBoxContainer = get_node_or_null("CenterContainer/MenuBox")

var is_transitioning: bool = false
var name_modal_instance: CanvasLayer = null
var profile_modal_instance: CanvasLayer = null
var how_to_play_modal_instance: CanvasLayer = null
var prologue_modal_instance: CanvasLayer = null
var prologue_is_typing: bool = false
var prologue_finish_typing_cb: Callable = Callable()
var prologue_close_cb: Callable = Callable()

func _input(event: InputEvent) -> void:
	if prologue_modal_instance and is_instance_valid(prologue_modal_instance):
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
				get_viewport().set_input_as_handled()
				if prologue_is_typing:
					if prologue_finish_typing_cb.is_valid():
						prologue_finish_typing_cb.call()
				else:
					if prologue_close_cb.is_valid():
						prologue_close_cb.call()
			elif event.keycode == KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				if prologue_is_typing:
					if prologue_finish_typing_cb.is_valid():
						prologue_finish_typing_cb.call()
				else:
					if prologue_close_cb.is_valid():
						prologue_close_cb.call()

func _ready() -> void:
	_setup_profile_button()
	_setup_leaderboard_button()
	_setup_how_to_play_button()
	
	# If manually designed in scene, wire buttons
	if btn_start:
		btn_start.pressed.connect(_on_start_pressed)
	if btn_continue:
		btn_continue.pressed.connect(_on_continue_pressed)
		btn_continue.visible = GameManager.has_checkpoint
		btn_continue.disabled = not GameManager.has_checkpoint
	if btn_dev:
		btn_dev.pressed.connect(_on_dev_toggle_pressed)
		_update_dev_button_text()
	if btn_quit:
		btn_quit.pressed.connect(_on_quit_pressed)
		
	# Wire hover & focus SFX for buttons
	for btn in [btn_start, btn_continue, btn_profile, btn_dev, btn_leaderboard, btn_how_to_play, btn_quit]:
		if btn:
			btn.mouse_entered.connect(_on_button_hovered)
			btn.focus_entered.connect(_on_button_hovered)
		
	# Connect to dev mode signal
	GameManager.dev_mode_toggled.connect(_on_dev_mode_changed)
	
	# Apply sleek compact styling to menu box and buttons
	_apply_compact_menu_styling()
	get_viewport().size_changed.connect(_adjust_menu_layout)
	call_deferred("_adjust_menu_layout")
	
	# If no buttons were placed in scene, build fallback UI
	if not btn_start and not btn_continue:
		_build_fallback_menu()
		
	# Setup intro & idle animation loop
	_setup_animations()
		
	# Play Main Menu BGM
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_bgm_main_menu"):
		audio.play_bgm_main_menu()

func _setup_profile_button() -> void:
	if menu_box and not btn_profile:
		btn_profile = Button.new()
		btn_profile.name = "ProfileButton"
		if ResourceLoader.exists("res://dialogue.tres"):
			btn_profile.theme = load("res://dialogue.tres")
		btn_profile.add_theme_font_size_override("font_size", 16)
		_update_profile_button_text()
		btn_profile.pressed.connect(_on_profile_pressed)
		btn_profile.mouse_entered.connect(_on_button_hovered)
		btn_profile.focus_entered.connect(_on_button_hovered)
		
		# If intro animation is running, start hidden until menu drops
		if anim_player and anim_player.is_playing() and anim_player.current_animation == "intro":
			btn_profile.modulate = Color(1, 1, 1, 0)
			
		# Place right after ContinueButton or StartButton
		if btn_continue:
			menu_box.add_child(btn_profile)
			menu_box.move_child(btn_profile, btn_continue.get_index() + 1)
		elif btn_start:
			menu_box.add_child(btn_profile)
			menu_box.move_child(btn_profile, btn_start.get_index() + 1)
		else:
			menu_box.add_child(btn_profile)

func _update_profile_button_text() -> void:
	if btn_profile:
		if GameManager.has_set_profile and not GameManager.current_player_name.is_empty():
			btn_profile.text = "Profile: [" + GameManager.current_player_name + "]"
		else:
			btn_profile.text = "Create Profile"

func _setup_leaderboard_button() -> void:
	if menu_box and not btn_leaderboard:
		btn_leaderboard = Button.new()
		btn_leaderboard.name = "LeaderboardButton"
		btn_leaderboard.text = "Leaderboard"
		if ResourceLoader.exists("res://dialogue.tres"):
			btn_leaderboard.theme = load("res://dialogue.tres")
		btn_leaderboard.add_theme_font_size_override("font_size", 16)
		btn_leaderboard.pressed.connect(_on_leaderboard_pressed)
		btn_leaderboard.mouse_entered.connect(_on_button_hovered)
		btn_leaderboard.focus_entered.connect(_on_button_hovered)
		
		# If intro animation is running, start hidden until menu drops
		if anim_player and anim_player.is_playing() and anim_player.current_animation == "intro":
			btn_leaderboard.modulate = Color(1, 1, 1, 0)
			
		if btn_quit:
			menu_box.add_child(btn_leaderboard)
			menu_box.move_child(btn_leaderboard, btn_quit.get_index())
		else:
			menu_box.add_child(btn_leaderboard)

func _setup_how_to_play_button() -> void:
	if menu_box and not btn_how_to_play:
		btn_how_to_play = Button.new()
		btn_how_to_play.name = "HowToPlayButton"
		btn_how_to_play.text = "How to Play & About"
		if ResourceLoader.exists("res://dialogue.tres"):
			btn_how_to_play.theme = load("res://dialogue.tres")
		btn_how_to_play.add_theme_font_size_override("font_size", 16)
		btn_how_to_play.pressed.connect(_on_how_to_play_pressed)
		btn_how_to_play.mouse_entered.connect(_on_button_hovered)
		btn_how_to_play.focus_entered.connect(_on_button_hovered)
		
		# If intro animation is running, start hidden until menu drops
		if anim_player and anim_player.is_playing() and anim_player.current_animation == "intro":
			btn_how_to_play.modulate = Color(1, 1, 1, 0)
			
		if btn_quit:
			menu_box.add_child(btn_how_to_play)
			menu_box.move_child(btn_how_to_play, btn_quit.get_index())
		else:
			menu_box.add_child(btn_how_to_play)

func _setup_animations() -> void:
	if anim_player:
		if not anim_player.animation_finished.is_connected(_on_animation_finished):
			anim_player.animation_finished.connect(_on_animation_finished)
		if not anim_player.is_playing():
			anim_player.play("intro")
		# Give focus to the menu right when the title & buttons drop at 4.0s
		get_tree().create_timer(4.0).timeout.connect(func():
			if not is_transitioning:
				if btn_profile:
					var tw = create_tween()
					tw.tween_property(btn_profile, "modulate", Color(1, 1, 1, 1), 0.3)
				if btn_leaderboard:
					var tw2 = create_tween()
					tw2.tween_property(btn_leaderboard, "modulate", Color(1, 1, 1, 1), 0.3)
				if btn_how_to_play:
					var tw3 = create_tween()
					tw3.tween_property(btn_how_to_play, "modulate", Color(1, 1, 1, 1), 0.3)
				_adjust_menu_layout()
				_set_initial_focus()
		)
	else:
		_adjust_menu_layout()
		_set_initial_focus()

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"intro":
		if anim_player and anim_player.has_animation("idle_loop"):
			anim_player.play("idle_loop")
		for btn in [btn_start, btn_continue, btn_profile, btn_dev, btn_leaderboard, btn_how_to_play, btn_quit]:
			if btn:
				btn.modulate = Color(1, 1, 1, 1)
		_adjust_menu_layout()
		_set_initial_focus()

func _unhandled_input(event: InputEvent) -> void:
	# Allow player to skip intro on key/button press or click
	if anim_player and anim_player.current_animation == "intro":
		if event.is_pressed() and not event.is_echo():
			_skip_intro()

func _skip_intro() -> void:
	if anim_player and anim_player.has_animation("idle_loop"):
		anim_player.play("idle_loop")
	if flash_overlay:
		flash_overlay.color = Color(0, 0, 0, 0)
	if menu_box:
		menu_box.modulate = Color(1, 1, 1, 1)
	var logo = get_node_or_null("CenterContainer/MenuBox/Logo")
	if logo:
		logo.scale = Vector2(0.22, 0.22)
		logo.self_modulate = Color(1, 1, 1, 1)
	for btn in [btn_start, btn_continue, btn_profile, btn_dev, btn_leaderboard, btn_how_to_play, btn_quit]:
		if btn:
			btn.modulate = Color(1, 1, 1, 1)
	_adjust_menu_layout()
	_set_initial_focus()

func _apply_compact_menu_styling() -> void:
	if not menu_box:
		return
	
	# Compact spacing between menu items
	menu_box.add_theme_constant_override("separation", 3)
	
	# Sleek retro styleboxes for compact buttons matching Pokemon Emerald theme
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	style_normal.border_color = Color(0.3882353, 0.60784316, 0.41568628, 1.0)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(4)
	style_normal.content_margin_left = 10
	style_normal.content_margin_right = 10
	style_normal.content_margin_top = 2
	style_normal.content_margin_bottom = 2
	
	var style_focus = StyleBoxFlat.new()
	style_focus.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	style_focus.border_color = Color(1.0, 0.09, 0.257, 1.0)
	style_focus.set_border_width_all(2)
	style_focus.set_corner_radius_all(4)
	style_focus.content_margin_left = 10
	style_focus.content_margin_right = 10
	style_focus.content_margin_top = 2
	style_focus.content_margin_bottom = 2
	
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.858, 0.954, 0.865, 1.0)
	style_pressed.border_color = Color(0.3882353, 0.60784316, 0.41568628, 1.0)
	style_pressed.set_border_width_all(2)
	style_pressed.set_corner_radius_all(4)
	style_pressed.content_margin_left = 10
	style_pressed.content_margin_right = 10
	style_pressed.content_margin_top = 2
	style_pressed.content_margin_bottom = 2
	
	var all_buttons = [btn_start, btn_continue, btn_profile, btn_leaderboard, btn_how_to_play, btn_dev, btn_quit]
	for btn in all_buttons:
		if btn:
			btn.custom_minimum_size = Vector2(144, 22)
			btn.add_theme_font_size_override("font_size", 14)
			btn.add_theme_stylebox_override("normal", style_normal)
			btn.add_theme_stylebox_override("hover", style_focus)
			btn.add_theme_stylebox_override("focus", style_focus)
			btn.add_theme_stylebox_override("pressed", style_pressed)
			btn.add_theme_stylebox_override("disabled", style_normal)
			btn.add_theme_color_override("font_color", Color(0, 0, 0, 1))
			btn.add_theme_color_override("font_focus_color", Color(0, 0, 0, 1))
			btn.add_theme_color_override("font_hover_color", Color(0, 0, 0, 1))
			btn.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 1))
			
	_adjust_menu_layout()

func _adjust_menu_layout() -> void:
	if not menu_box:
		return
		
	var spacer = menu_box.get_node_or_null("Spacer")
	if spacer:
		spacer.custom_minimum_size = Vector2(0, 48)
		
	var logo: Sprite2D = menu_box.get_node_or_null("Logo")
	if logo and is_instance_valid(logo):
		logo.scale = Vector2(0.22, 0.22)
		var center_x = (menu_box.size.x * 0.5) if menu_box.size.x > 0 else 72.0
		logo.position.x = center_x
		logo.position.y = 7.0
		
		# Out-of-bounds safety clamp: Ensure the top of the logo is at least 14px below the top of the screen
		var tex_h = 380.0
		if logo.texture:
			tex_h = float(logo.texture.get_height())
		var half_h = tex_h * logo.scale.y * 0.5
		var top_screen_y = logo.global_position.y - half_h
		if top_screen_y < 14.0:
			var push_down = 14.0 - top_screen_y
			logo.position.y += push_down

func _set_initial_focus() -> void:
	if btn_continue and btn_continue.visible and not btn_continue.disabled:
		btn_continue.grab_focus()
	elif btn_start:
		btn_start.grab_focus()

func _update_dev_button_text() -> void:
	if btn_dev:
		btn_dev.text = "Dev Mode: [ON]" if GameManager.dev_mode else "Dev Mode: [OFF]"

func _play_click_sfx() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_ui_click"):
		audio.play_ui_click()

func _on_button_hovered() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_battle_choice_hover"):
		audio.play_battle_choice_hover()

func _on_dev_mode_changed(_is_on: bool) -> void:
	_update_dev_button_text()

func _on_start_pressed() -> void:
	if is_transitioning:
		return
	_play_click_sfx()
	if not GameManager.has_set_profile or GameManager.current_player_name.is_empty():
		_show_name_input_modal()
	else:
		_show_prologue_story(func():
			_start_game_transition()
		)

func _show_name_input_modal(is_continue: bool = false) -> void:
	if name_modal_instance and is_instance_valid(name_modal_instance):
		return
		
	name_modal_instance = CanvasLayer.new()
	name_modal_instance.layer = 38
	
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(PRESET_FULL_RECT)
	backdrop.color = Color(0.04, 0.07, 0.05, 0.85)
	name_modal_instance.add_child(backdrop)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	name_modal_instance.add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 150)
	if ResourceLoader.exists("res://dialogue.tres"):
		panel.theme = load("res://dialogue.tres")
		
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.12, 0.09, 0.98)
	panel_style.border_color = Color(0.3, 0.6, 0.38, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "CREATE CODER PROFILE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 1.0))
	vbox.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "Enter your alias to begin:"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.85, 0.8, 1.0))
	vbox.add_child(subtitle)
	
	var line_edit = LineEdit.new()
	line_edit.text = ""
	line_edit.placeholder_text = "Enter Coder Alias"
	line_edit.max_length = 16
	line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_edit.add_theme_font_size_override("font_size", 16)
	vbox.add_child(line_edit)
	
	var warn_lbl = Label.new()
	warn_lbl.text = ""
	warn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn_lbl.add_theme_font_size_override("font_size", 16)
	warn_lbl.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35, 1.0))
	vbox.add_child(warn_lbl)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_hbox)
	
	var btn_confirm = Button.new()
	btn_confirm.text = "Create & Continue" if is_continue else "Create & Start"
	btn_confirm.add_theme_font_size_override("font_size", 16)
	btn_hbox.add_child(btn_confirm)
	
	var btn_cancel = Button.new()
	btn_cancel.text = "Cancel"
	btn_cancel.add_theme_font_size_override("font_size", 16)
	btn_hbox.add_child(btn_cancel)
	
	var on_submit = func():
		_play_click_sfx()
		var chosen_name = line_edit.text.strip_edges()
		if chosen_name.is_empty():
			warn_lbl.text = "Please enter an alias."
			line_edit.grab_focus()
			return
		GameManager.save_profile_data(chosen_name)
		_update_profile_button_text()
		name_modal_instance.queue_free()
		name_modal_instance = null
		if is_continue:
			if not GameManager.has_checkpoint:
				print("Main Menu: No checkpoint saved, starting new game instead...")
				_show_prologue_story(func():
					_start_game_transition()
				)
				return
			is_transitioning = true
			print("Main Menu: Continuing from checkpoint as ", GameManager.current_player_name, "...")
			if flash_overlay:
				var tween = create_tween()
				tween.tween_property(flash_overlay, "color", Color(0, 0, 0, 1), 0.35)
				tween.tween_callback(func():
					GameManager.respawn_at_checkpoint()
				)
			else:
				GameManager.respawn_at_checkpoint()
		else:
			_show_prologue_story(func():
				_start_game_transition()
			)
		
	btn_confirm.pressed.connect(on_submit)
	line_edit.text_submitted.connect(func(_text): on_submit.call())
	
	btn_cancel.pressed.connect(func():
		_play_click_sfx()
		name_modal_instance.queue_free()
		name_modal_instance = null
		if is_continue and btn_continue:
			btn_continue.grab_focus()
		elif btn_start:
			btn_start.grab_focus()
	)
	
	add_child(name_modal_instance)
	line_edit.grab_focus()

func _on_profile_pressed() -> void:
	_play_click_sfx()
	_show_profile_modal()

func _show_profile_modal() -> void:
	if profile_modal_instance and is_instance_valid(profile_modal_instance):
		return
		
	profile_modal_instance = CanvasLayer.new()
	profile_modal_instance.layer = 39
	
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(PRESET_FULL_RECT)
	backdrop.color = Color(0.04, 0.07, 0.05, 0.90)
	profile_modal_instance.add_child(backdrop)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	profile_modal_instance.add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 180)
	if ResourceLoader.exists("res://dialogue.tres"):
		panel.theme = load("res://dialogue.tres")
		
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.12, 0.09, 0.98)
	panel_style.border_color = Color(0.3, 0.6, 0.38, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "CODER PROFILES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 1.0))
	vbox.add_child(title)
	
	var active_name = GameManager.current_player_name if not GameManager.current_player_name.is_empty() else "None"
	var active_lbl = Label.new()
	active_lbl.text = "Active Coder: [" + active_name + "]"
	active_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_lbl.add_theme_font_size_override("font_size", 16)
	active_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	vbox.add_child(active_lbl)
	
	var edit_label = Label.new()
	if GameManager.saved_profiles.is_empty():
		edit_label.text = "Create New Coder Alias:"
	else:
		edit_label.text = "Enter Alias or Select Below:"
	edit_label.add_theme_font_size_override("font_size", 16)
	edit_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7, 1.0))
	vbox.add_child(edit_label)
	
	var line_edit = LineEdit.new()
	line_edit.text = GameManager.current_player_name
	line_edit.placeholder_text = "Enter Coder Alias"
	line_edit.max_length = 16
	line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_edit.add_theme_font_size_override("font_size", 16)
	vbox.add_child(line_edit)
	
	# Saved Profiles Quick Pick List
	if GameManager.saved_profiles.size() > 0:
		var profile_scroll = ScrollContainer.new()
		profile_scroll.custom_minimum_size = Vector2(0, 36)
		profile_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		profile_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		vbox.add_child(profile_scroll)
		
		var profile_hbox = HBoxContainer.new()
		profile_hbox.add_theme_constant_override("separation", 6)
		profile_scroll.add_child(profile_hbox)
		
		for p_name in GameManager.saved_profiles:
			var p_btn = Button.new()
			p_btn.text = p_name
			p_btn.add_theme_font_size_override("font_size", 16)
			if p_name == GameManager.current_player_name:
				p_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 1.0))
			p_btn.pressed.connect(func():
				_play_click_sfx()
				line_edit.text = p_name
			)
			profile_hbox.add_child(p_btn)
			
	var warn_lbl = Label.new()
	warn_lbl.text = ""
	warn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn_lbl.add_theme_font_size_override("font_size", 16)
	warn_lbl.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35, 1.0))
	vbox.add_child(warn_lbl)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_hbox)
	
	var btn_save = Button.new()
	btn_save.text = "Save Profile" if GameManager.saved_profiles.is_empty() else "Switch / Save"
	btn_save.add_theme_font_size_override("font_size", 16)
	btn_hbox.add_child(btn_save)
	
	var btn_cancel = Button.new()
	btn_cancel.text = "Close"
	btn_cancel.add_theme_font_size_override("font_size", 16)
	btn_hbox.add_child(btn_cancel)
	
	var on_save = func():
		_play_click_sfx()
		var chosen = line_edit.text.strip_edges()
		if chosen.is_empty():
			warn_lbl.text = "Please enter an alias."
			line_edit.grab_focus()
			return
		GameManager.save_profile_data(chosen)
		_update_profile_button_text()
		profile_modal_instance.queue_free()
		profile_modal_instance = null
		if btn_profile:
			btn_profile.grab_focus()
			
	btn_save.pressed.connect(on_save)
	line_edit.text_submitted.connect(func(_text): on_save.call())
	
	btn_cancel.pressed.connect(func():
		_play_click_sfx()
		profile_modal_instance.queue_free()
		profile_modal_instance = null
		if btn_profile:
			btn_profile.grab_focus()
	)
	
	add_child(profile_modal_instance)
	line_edit.grab_focus()
	line_edit.select_all()

func _start_game_transition() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	print("Main Menu: Starting New Game as ", GameManager.current_player_name, "...")
	
	if flash_overlay:
		var tween = create_tween()
		tween.tween_property(flash_overlay, "color", Color(0, 0, 0, 1), 0.35)
		tween.tween_callback(func():
			GameManager.start_new_game()
		)
	else:
		GameManager.start_new_game()

func _show_prologue_story(on_complete: Callable) -> void:
	if prologue_modal_instance != null and is_instance_valid(prologue_modal_instance):
		return
		
	prologue_modal_instance = CanvasLayer.new()
	prologue_modal_instance.layer = 45
	
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://dialogue.tres"):
		root.theme = load("res://dialogue.tres")
	prologue_modal_instance.add_child(root)
	
	# Full-screen dark retro background
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.04, 0.03, 0.96)
	root.add_child(backdrop)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 240)
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.04, 0.07, 0.05, 0.98)
	p_style.border_color = Color(0.24, 0.75, 0.45, 1.0) # Classic terminal green
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(6)
	p_style.content_margin_left = 12
	p_style.content_margin_right = 12
	p_style.content_margin_top = 10
	p_style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", p_style)
	center.add_child(panel)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	panel.add_child(main_vbox)
	
	# Header title
	var title = Label.new()
	title.text = "LOCALHOST TOWN: INCIDENT REPORT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55, 1.0))
	if ResourceLoader.exists("res://assets/fonts/pokemon-emerald.otf"):
		title.add_theme_font_override("font", load("res://assets/fonts/pokemon-emerald.otf"))
	main_vbox.add_child(title)
	
	var hsep = HSeparator.new()
	var sep_style = StyleBoxLine.new()
	sep_style.color = Color(0.2, 0.5, 0.3, 0.7)
	sep_style.thickness = 1
	hsep.add_theme_stylebox_override("separator", sep_style)
	main_vbox.add_child(hsep)
	
	# RichTextLabel story body
	var rich_label = RichTextLabel.new()
	rich_label.bbcode_enabled = true
	rich_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rich_label.custom_minimum_size = Vector2(416, 145)
	rich_label.add_theme_font_size_override("normal_font_size", 14)
	rich_label.add_theme_font_size_override("bold_font_size", 14)
	if ResourceLoader.exists("res://assets/fonts/pokemon-emerald.otf"):
		var font_res = load("res://assets/fonts/pokemon-emerald.otf")
		rich_label.add_theme_font_override("normal_font", font_res)
		rich_label.add_theme_font_override("bold_font", font_res)
	
	var story_bbcode = "[color=#c8f7d5]Sa gitna ng digital realm, mapayapang namumuhay ang mga programmer sa bayan ng [color=#ffffff][b]Localhost Town[/b][/color], isang maayos na komunidad kung saan bawat code ay nagko-compile nang walang error.[/color]\n\n[color=#c8f7d5]Ngunit isang araw, isang matinding [color=#ff7675][b]logic error[/b][/color] ang yumanig sa central server ng Main Lab. Dahil sa system crash na ito, nakawala mula sa containment ang mga [color=#ff5252][b]Alpha Glitches[/b][/color]! Mabilis silang kumalat sa damuhan at lansangan, sinisira ang mga linya ng code at nagbabantang i-corrupt ang buong memory ng bayan.[/color]\n\n[color=#c8f7d5]Nananawagan ngayon sina [color=#ffffff][b]Team Leader[/b][/color] at [color=#ffffff][b]Pedro[/b][/color]. Dumating ka bilang isang [color=#55efc4][b]Programmer[/b][/color] upang i-debug ang mga bug gamit ang [color=#ffeaa7][b]Python, C, at C++[/b][/color], at iligtas ang Localhost Town bago magka-fatal crash ang buong sistema![/color]"
	
	rich_label.text = story_bbcode
	rich_label.visible_characters = 0
	main_vbox.add_child(rich_label)
	
	# Action buttons row
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 12)
	main_vbox.add_child(btn_row)
	
	var btn_skip = Button.new()
	btn_skip.text = "Laktawan [ESC]"
	btn_skip.add_theme_font_size_override("font_size", 14)
	btn_skip.mouse_entered.connect(_on_button_hovered)
	btn_row.add_child(btn_skip)
	
	var btn_continue = Button.new()
	btn_continue.text = "Magpatuloy [Space]"
	btn_continue.add_theme_font_size_override("font_size", 14)
	btn_continue.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 1.0))
	btn_continue.modulate.a = 0.4
	btn_continue.mouse_entered.connect(_on_button_hovered)
	btn_row.add_child(btn_continue)
	
	add_child(prologue_modal_instance)
	
	var plain_length = rich_label.get_parsed_text().length()
	if plain_length <= 0:
		plain_length = story_bbcode.length()
	
	prologue_is_typing = true
	var type_tween: Tween = create_tween()
	
	# Typewriter speed: ~45 characters per second
	var duration = float(plain_length) / 45.0
	type_tween.tween_property(rich_label, "visible_characters", plain_length, duration)
	
	var finish_typing = func():
		if not prologue_is_typing:
			return
		prologue_is_typing = false
		if type_tween and type_tween.is_valid():
			type_tween.kill()
		if is_instance_valid(rich_label):
			rich_label.visible_characters = -1
		if is_instance_valid(btn_continue):
			btn_continue.modulate.a = 1.0
			btn_continue.grab_focus()
			var glow_tw = create_tween().set_loops()
			glow_tw.tween_property(btn_continue, "modulate", Color(1.3, 1.3, 1.0, 1.0), 0.5)
			glow_tw.tween_property(btn_continue, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5)
			
	type_tween.tween_callback(finish_typing)
	
	var close_and_start = func():
		_play_click_sfx()
		prologue_is_typing = false
		prologue_finish_typing_cb = Callable()
		prologue_close_cb = Callable()
		if type_tween and type_tween.is_valid():
			type_tween.kill()
		if prologue_modal_instance and is_instance_valid(prologue_modal_instance):
			prologue_modal_instance.queue_free()
			prologue_modal_instance = null
		on_complete.call()
		
	prologue_finish_typing_cb = finish_typing
	prologue_close_cb = close_and_start
	
	btn_skip.pressed.connect(func():
		if prologue_is_typing:
			finish_typing.call()
		else:
			close_and_start.call()
	)
	
	btn_continue.pressed.connect(func():
		if prologue_is_typing:
			finish_typing.call()
		else:
			close_and_start.call()
	)

func _on_leaderboard_pressed() -> void:
	_play_click_sfx()
	var lb_script = load("res://scripts/leaderboard_ui.gd")
	if lb_script:
		var lb_node = lb_script.new()
		lb_node.name = "LeaderboardModal"
		add_child(lb_node)

func _on_how_to_play_pressed() -> void:
	_play_click_sfx()
	if how_to_play_modal_instance != null and is_instance_valid(how_to_play_modal_instance):
		return
		
	how_to_play_modal_instance = CanvasLayer.new()
	how_to_play_modal_instance.layer = 42
	
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://dialogue.tres"):
		root.theme = load("res://dialogue.tres")
	how_to_play_modal_instance.add_child(root)
	
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.04, 0.03, 0.88)
	root.add_child(backdrop)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(430, 230)
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.06, 0.10, 0.08, 0.98)
	p_style.border_color = Color(0.24, 0.75, 0.45, 1.0)
	p_style.set_border_width_all(2)
	p_style.set_corner_radius_all(6)
	p_style.content_margin_left = 10
	p_style.content_margin_right = 10
	p_style.content_margin_top = 8
	p_style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", p_style)
	center.add_child(panel)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	panel.add_child(main_vbox)
	
	var title = Label.new()
	title.text = "CODEMON: SYSTEM GUIDE & ABOUT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55, 1.0))
	main_vbox.add_child(title)
	
	main_vbox.add_child(HSeparator.new())
	
	# Two-column container
	var columns_hbox = HBoxContainer.new()
	columns_hbox.add_theme_constant_override("separation", 10)
	columns_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(columns_hbox)
	
	# Column 1: HOW TO PLAY
	var col1 = VBoxContainer.new()
	col1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col1.add_theme_constant_override("separation", 3)
	columns_hbox.add_child(col1)
	
	var col1_title = Label.new()
	col1_title.text = "[ HOW TO PLAY ]"
	col1_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col1_title.add_theme_font_size_override("font_size", 16)
	col1_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35, 1.0))
	col1.add_child(col1_title)
	
	var col1_text = RichTextLabel.new()
	col1_text.bbcode_enabled = true
	col1_text.fit_content = true
	col1_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col1_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col1_text.text = "[color=#a3e635]• Movement:[/color] WASD / Arrow Keys\n[color=#a3e635]• Interact:[/color] Space / Enter\n[color=#a3e635]• Quest Log:[/color] Tab / Q to view goals\n[color=#a3e635]• Glitches:[/color] Roam the tall grass\n[color=#a3e635]• Debug Battle:[/color] Answer programming questions correctly to squash bugs!\n[color=#a3e635]• Items:[/color] Search grass for lost parts"
	if ResourceLoader.exists("res://assets/fonts/pokemon-emerald.otf"):
		col1_text.add_theme_font_override("normal_font", load("res://assets/fonts/pokemon-emerald.otf"))
	col1_text.add_theme_font_size_override("normal_font_size", 14)
	col1.add_child(col1_text)
	
	# Vertical separator between columns
	columns_hbox.add_child(VSeparator.new())
	
	# Column 2: ABOUT
	var col2 = VBoxContainer.new()
	col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col2.add_theme_constant_override("separation", 3)
	columns_hbox.add_child(col2)
	
	var col2_title = Label.new()
	col2_title.text = "[ ABOUT CODEMON ]"
	col2_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col2_title.add_theme_font_size_override("font_size", 16)
	col2_title.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0, 1.0))
	col2.add_child(col2_title)
	
	var col2_text = RichTextLabel.new()
	col2_text.bbcode_enabled = true
	col2_text.fit_content = true
	col2_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col2_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col2_text.text = "[color=#38bdf8]• Premise:[/color] Rogue Alpha Glitches have escaped into Localhost. Restore code integrity!\n[color=#38bdf8]• Languages:[/color] Python, C, & C++ challenges.\n[color=#38bdf8]• Features:[/color] Quests, dev checkpoints, & online speedrun leaderboard!\n[color=#38bdf8]• Version:[/color] v1.0.0 Alpha Edition"
	if ResourceLoader.exists("res://assets/fonts/pokemon-emerald.otf"):
		col2_text.add_theme_font_override("normal_font", load("res://assets/fonts/pokemon-emerald.otf"))
	col2_text.add_theme_font_size_override("normal_font_size", 14)
	col2.add_child(col2_text)
	
	main_vbox.add_child(HSeparator.new())
	
	# Close button
	var btn_close_center = CenterContainer.new()
	var btn_close = Button.new()
	btn_close.text = "Got It"
	btn_close.custom_minimum_size = Vector2(100, 24)
	btn_close.add_theme_font_size_override("font_size", 16)
	if ResourceLoader.exists("res://dialogue.tres"):
		btn_close.theme = load("res://dialogue.tres")
		
	var on_close = func():
		_play_click_sfx()
		how_to_play_modal_instance.queue_free()
		how_to_play_modal_instance = null
		if btn_how_to_play:
			btn_how_to_play.grab_focus()
			
	btn_close.pressed.connect(on_close)
	btn_close_center.add_child(btn_close)
	main_vbox.add_child(btn_close_center)
	
	add_child(how_to_play_modal_instance)
	btn_close.grab_focus()

func _on_continue_pressed() -> void:
	if is_transitioning:
		return
	if not GameManager.has_checkpoint:
		print("Main Menu: No checkpoint available to continue from.")
		return
	_play_click_sfx()
	if not GameManager.has_set_profile or GameManager.current_player_name.strip_edges().is_empty():
		_show_name_input_modal(true)
		return
		
	is_transitioning = true
	print("Main Menu: Continuing from checkpoint as ", GameManager.current_player_name, "...")
	if flash_overlay:
		var tween = create_tween()
		tween.tween_property(flash_overlay, "color", Color(0, 0, 0, 1), 0.35)
		tween.tween_callback(func():
			GameManager.respawn_at_checkpoint()
		)
	else:
		GameManager.respawn_at_checkpoint()

func _on_dev_toggle_pressed() -> void:
	_play_click_sfx()
	GameManager.toggle_dev_mode()

func _on_quit_pressed() -> void:
	_play_click_sfx()
	print("Main Menu: Quitting...")
	get_tree().quit()

# ==========================================
# DYNAMIC FALLBACK BUILDER (If scene has no nodes)
# ==========================================
func _build_fallback_menu() -> void:
	if ResourceLoader.exists("res://dialogue.tres"):
		theme = load("res://dialogue.tres")
		
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.12, 0.1, 1.0) # Dark retro teal
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(220, 180)
	vbox.add_theme_constant_override("separation", 8)
	center.add_child(vbox)
	
	var title = Label.new()
	title.text = "CODEMON"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5, 1.0))
	vbox.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "The Bug Containment Protocol"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	vbox.add_child(subtitle)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	btn_start = Button.new()
	btn_start.text = "Start New Game"
	btn_start.pressed.connect(_on_start_pressed)
	vbox.add_child(btn_start)
	
	btn_continue = Button.new()
	btn_continue.text = "Continue from Checkpoint"
	btn_continue.visible = GameManager.has_checkpoint
	btn_continue.disabled = not GameManager.has_checkpoint
	btn_continue.pressed.connect(_on_continue_pressed)
	vbox.add_child(btn_continue)
	
	btn_profile = Button.new()
	_update_profile_button_text()
	btn_profile.pressed.connect(_on_profile_pressed)
	vbox.add_child(btn_profile)
	
	btn_dev = Button.new()
	_update_dev_button_text()
	btn_dev.pressed.connect(_on_dev_toggle_pressed)
	vbox.add_child(btn_dev)
	
	btn_leaderboard = Button.new()
	btn_leaderboard.text = "Leaderboard"
	btn_leaderboard.pressed.connect(_on_leaderboard_pressed)
	vbox.add_child(btn_leaderboard)
	
	btn_how_to_play = Button.new()
	btn_how_to_play.text = "How to Play & About"
	btn_how_to_play.pressed.connect(_on_how_to_play_pressed)
	vbox.add_child(btn_how_to_play)
	
	btn_quit = Button.new()
	btn_quit.text = "Quit"
	btn_quit.pressed.connect(_on_quit_pressed)
	vbox.add_child(btn_quit)
	
	_set_initial_focus()
