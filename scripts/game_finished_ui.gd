extends Control

@onready var btn_play_again: Button = get_node_or_null("%PlayAgainButton")
@onready var btn_main_menu: Button = get_node_or_null("%MainMenuButton")
@onready var stats_label: Label = get_node_or_null("%StatsLabel")

var btn_submit_world: Button = null
var btn_leaderboard: Button = null
var status_label: Label = null

func _ready() -> void:
	# Ensure checkpoints are completely flushed upon game completion
	GameManager.flush_checkpoint()
	
	if btn_play_again:
		btn_play_again.pressed.connect(_on_play_again_pressed)
		btn_play_again.grab_focus()
	if btn_main_menu:
		btn_main_menu.pressed.connect(_on_main_menu_pressed)
		
	var btn_retry = get_node_or_null("%RetryButton")
	if btn_retry:
		btn_retry.visible = false
	var checkpoint_lbl = get_node_or_null("%CheckpointInfo")
	if checkpoint_lbl:
		checkpoint_lbl.visible = false
		
	if stats_label:
		stats_label.text = _format_stats_text()
		
	if not btn_play_again and not btn_main_menu:
		_build_fallback_victory_screen()

func _format_stats_text() -> String:
	var display_name = GameManager.current_player_name.strip_edges()
	if display_name.is_empty():
		display_name = "Anonymous"
	return "- Coder Alias: %s\n- Final Clear Time: %s\n- Glitches Squashed: %d / %d (100%%)\n- System Integrity: %d / %d Hearts" % [
		display_name,
		GameManager.format_run_time(GameManager.run_elapsed_time),
		GameManager.total_bugs_defeated,
		GameManager.total_expected_monsters,
		GameManager.player_hp,
		GameManager.max_hp
	]

func _play_click_sfx() -> void:
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_ui_click"):
		audio.play_ui_click()

func _cleanup_self() -> void:
	var lm = get_node_or_null("/root/LeaderboardManager")
	if lm and lm.sync_completed.is_connected(_on_sync_completed):
		lm.sync_completed.disconnect(_on_sync_completed)
		
	if get_parent() and get_parent().name == "DynamicVictoryScreen":
		get_parent().queue_free()
	else:
		queue_free()

func _on_submit_world_pressed() -> void:
	_play_click_sfx()
	if not btn_submit_world:
		return
	btn_submit_world.disabled = true
	if status_label:
		status_label.text = "Submitting to online leaderboard..."
		status_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3, 1.0))
		
	var lm = get_node_or_null("/root/LeaderboardManager")
	if not lm:
		if status_label:
			status_label.text = "Leaderboard service unavailable. Saved locally."
		return
		
	if not lm.sync_completed.is_connected(_on_sync_completed):
		lm.sync_completed.connect(_on_sync_completed)
		
	lm.sync_pending_records()

func _on_sync_completed(success: bool) -> void:
	var lm = get_node_or_null("/root/LeaderboardManager")
	if lm and lm.sync_completed.is_connected(_on_sync_completed):
		lm.sync_completed.disconnect(_on_sync_completed)
		
	if not is_inside_tree():
		return
		
	if success:
		var audio = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("play_checkpoint_saved"):
			audio.play_checkpoint_saved()
			
		if btn_submit_world:
			btn_submit_world.text = "Submitted to World Leaderboard"
			btn_submit_world.disabled = true
		if status_label:
			status_label.text = "Success! Verified on World Leaderboard."
			status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 1.0))
	else:
		if btn_submit_world:
			btn_submit_world.disabled = false
			btn_submit_world.text = "Retry World Submission"
		if status_label:
			status_label.text = "Offline / Connection Error. Run remains saved locally."
			status_label.add_theme_color_override("font_color", Color(0.95, 0.65, 0.25, 1.0))

func _on_leaderboard_pressed() -> void:
	_play_click_sfx()
	var lb_script = load("res://scripts/leaderboard_ui.gd")
	if lb_script:
		var lb_node = lb_script.new()
		lb_node.name = "LeaderboardModal"
		add_child(lb_node)

func _on_play_again_pressed() -> void:
	_play_click_sfx()
	print("Victory: Starting New Game (Play Again)...")
	GameManager.flush_checkpoint()
	_cleanup_self()
	GameManager.start_new_game()

func _on_main_menu_pressed() -> void:
	_play_click_sfx()
	print("Victory: Heading to Main Menu...")
	GameManager.flush_checkpoint()
	_cleanup_self()
	GameManager.go_to_main_menu()

# ==========================================
# DYNAMIC FALLBACK BUILDER
# ==========================================
func _build_fallback_victory_screen() -> void:
	if ResourceLoader.exists("res://dialogue.tres"):
		theme = load("res://dialogue.tres")
		
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.08, 0.06, 0.96) # Deep retro terminal green
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 240)
	if ResourceLoader.exists("res://dialogue.tres"):
		panel.theme = load("res://dialogue.tres")
		
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.11, 0.08, 0.98)
	panel_style.border_color = Color(0.3, 0.6, 0.38, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	
	# 1. Celebratory Heading
	var badge = Label.new()
	badge.text = "CONGRATULATIONS CODER!"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 16)
	badge.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 1.0))
	vbox.add_child(badge)
	
	var subtitle = Label.new()
	subtitle.text = "All 15 Alpha Glitches Cleansed | Localhost Restored"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.95, 0.8, 1.0))
	vbox.add_child(subtitle)
	
	var divider1 = HSeparator.new()
	vbox.add_child(divider1)
	
	# 2. Stats
	var stats = Label.new()
	stats.text = _format_stats_text()
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 16)
	stats.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	vbox.add_child(stats)
	
	var divider2 = HSeparator.new()
	vbox.add_child(divider2)
	
	# 3. World Leaderboard Submission Prompt
	var prompt_box = VBoxContainer.new()
	prompt_box.add_theme_constant_override("separation", 4)
	vbox.add_child(prompt_box)
	
	var prompt_lbl = Label.new()
	prompt_lbl.text = "World Leaderboard Submission:"
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lbl.add_theme_font_size_override("font_size", 16)
	prompt_lbl.add_theme_color_override("font_color", Color(0.65, 0.85, 0.70, 1.0))
	prompt_box.add_child(prompt_lbl)
	
	btn_submit_world = Button.new()
	btn_submit_world.text = "Submit to World Leaderboard"
	btn_submit_world.add_theme_font_size_override("font_size", 16)
	btn_submit_world.pressed.connect(_on_submit_world_pressed)
	prompt_box.add_child(btn_submit_world)
	
	status_label = Label.new()
	status_label.text = "Status: Saved to local secure records"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7, 1.0))
	prompt_box.add_child(status_label)
	
	# 4. Action Buttons
	var actions_hbox = HBoxContainer.new()
	actions_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	actions_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(actions_hbox)
	
	btn_leaderboard = Button.new()
	btn_leaderboard.text = "View Leaderboard"
	btn_leaderboard.add_theme_font_size_override("font_size", 16)
	btn_leaderboard.pressed.connect(_on_leaderboard_pressed)
	actions_hbox.add_child(btn_leaderboard)

	btn_play_again = Button.new()
	btn_play_again.text = "Play Again"
	btn_play_again.add_theme_font_size_override("font_size", 16)
	btn_play_again.pressed.connect(_on_play_again_pressed)
	actions_hbox.add_child(btn_play_again)
	
	btn_main_menu = Button.new()
	btn_main_menu.text = "Main Menu"
	btn_main_menu.add_theme_font_size_override("font_size", 16)
	btn_main_menu.pressed.connect(_on_main_menu_pressed)
	actions_hbox.add_child(btn_main_menu)
	
	btn_submit_world.grab_focus()
