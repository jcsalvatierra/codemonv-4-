extends Control

@export_group("Lab Objective Modal")
@export var lab_image: Texture2D = null

@export_group("Merchant Objective Modal")
@export var merchant_image: Texture2D = null

@onready var total_defeated_label: Label = get_node_or_null("%AlphaGlitchDefeated")

# Node references if configured in the scene
@onready var quest_panel: Control = get_node_or_null("%QuestContainer")
@onready var quest_title_lbl: Label = get_node_or_null("%QuestTitle")
@onready var quest_objectives_lbl: Label = get_node_or_null("%QuestObjectives")
@onready var quest_status_lbl: Label = get_node_or_null("%QuestStatus")
@onready var quest_toggle_lbl: Label = get_node_or_null("%QuestToggleLabel")

# Dynamic programmatically-created Quest UI container (fallback if scene nodes are not placed)
var auto_quest_container: PanelContainer = null
var auto_title_label: Label = null
var auto_objectives_label: Label = null
var auto_status_label: Label = null
var auto_toggle_label: Label = null
@onready var notification_label: Label = get_node_or_null("%NotificationLabel")

var is_quest_ui_maximized: bool = false
var notif_tween: Tween = null
@onready var quest_hotkey_badge: Label = get_node_or_null("%QuestHotkeyBadge")

# Minimized Quest HUD Attention Indicator System
var quest_panel_style: StyleBoxFlat = null
var default_border_color: Color = Color(0.3882353, 0.60784316, 0.41568628, 1.0)
var glow_border_color: Color = Color(0.96, 0.18, 0.22, 1.0) # Vibrant radiant red glow
var border_glow_tween: Tween = null
var is_quest_alert_active: bool = false
var has_initialized_quest_state: bool = false

var last_known_story_title: String = ""
var last_known_story_detail: String = ""
var last_known_quest_id: String = ""
var last_known_quest_name: String = ""
var last_known_kills: int = -1
var last_known_items: int = -1
var last_known_ready_to_turn_in: bool = false

func _ready() -> void:
	# Ensure the notification label is hidden and transparent on load so it never gets stuck
	if notification_label:
		notification_label.hide()
		notification_label.modulate.a = 0.0
		
	# If manual nodes are missing, construct a crisp, retro-themed HUD panel dynamically
	if not quest_panel:
		_build_dynamic_quest_ui()
	else:
		_setup_scene_quest_toggle_label()
		
	# Sync lab and merchant images with GameManager
	if lab_image != null:
		GameManager.lab_image = lab_image
	elif GameManager.lab_image != null:
		lab_image = GameManager.lab_image
		
	if merchant_image != null:
		GameManager.merchant_image = merchant_image
	elif GameManager.merchant_image != null:
		merchant_image = GameManager.merchant_image
		
	_setup_quest_panel_style()
		
	# Connect to QuestManager and GameManager updates
	QuestManager.quest_updated.connect(update_quest_ui)
	QuestManager.quest_updated.connect(check_glitches_cleared_modal)
	GameManager.event_completed.connect(_on_story_event_completed)
	GameManager.checkpoint_saved.connect(_on_checkpoint_saved)
	
	update_quest_ui()
	check_glitches_cleared_modal()
	
	# If we just respawned / restored from a checkpoint, show a clean restore notification that fades away
	if GameManager.checkpoint_just_restored:
		GameManager.checkpoint_just_restored = false
		show_notification("💾 Checkpoint Restored: " + GameManager.checkpoint_name)
		
	# Dev Mode Jump Dropdown
	_setup_dev_jump_dropdown()

func _on_story_event_completed(_event_id: String) -> void:
	update_quest_ui()

func _setup_dev_jump_dropdown() -> void:
	var dropdown = get_node_or_null("../DevCanvasLayer/DevJumpDropdown")
	if not dropdown: return
	
	dropdown.clear()
	dropdown.add_item("Dev: Jump To...")
	dropdown.set_item_disabled(0, true)
	
	for i in range(GameManager.dev_config.checkpoints.size()):
		var cp = GameManager.dev_config.checkpoints[i]
		dropdown.add_item(cp.display_name)
		dropdown.set_item_metadata(dropdown.item_count - 1, cp.checkpoint_id)
		
	# Select the placeholder item
	dropdown.selected = 0
		
	dropdown.item_selected.connect(_on_dev_jump_selected)
	dropdown.visible = GameManager.dev_mode
	GameManager.dev_mode_toggled.connect(func(is_on): dropdown.visible = is_on)

func _on_dev_jump_selected(index: int) -> void:
	if index > 0:
		var dd = get_node_or_null("../DevCanvasLayer/DevJumpDropdown")
		if dd and dd is OptionButton:
			var cp_id = dd.get_item_metadata(index)
			GameManager.jump_to_dev_checkpoint(cp_id)
			dd.selected = 0

func _process(_delta: float) -> void:
	if total_defeated_label:
		total_defeated_label.text = "%d" % GameManager.total_bugs_defeated


func _input(event: InputEvent) -> void:
	# Allow player to toggle quest UI minimize/maximize with TAB or Q
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB or event.keycode == KEY_Q:
			var audio = get_node_or_null("/root/AudioManager")
			if audio and audio.has_method("play_ui_click"):
				audio.play_ui_click()
			toggle_quest_ui()
		elif event.keycode == KEY_L:
			# If current objective is Go to the Lab, show the lab picture modal!
			if GameManager.completed_events.has("met_npc_1") and not GameManager.completed_events.has("met_leader"):
				GameManager.show_lab_objective_modal(true)
		elif event.keycode == KEY_M:
			# If current objective is Find the Merchant, show the merchant picture modal!
			if GameManager.completed_events.has("end_errand_1") and not GameManager.completed_events.has("start_errand_2"):
				GameManager.show_merchant_objective_modal(true)

func toggle_quest_ui() -> void:
	is_quest_ui_maximized = !is_quest_ui_maximized
	if is_quest_ui_maximized:
		_dismiss_quest_attention_pulse()
	update_quest_ui()

func _apply_quest_ui_visibility() -> void:
	var hint_text = "[Tab] to minimize" if is_quest_ui_maximized else ""
	
	if quest_hotkey_badge:
		quest_hotkey_badge.visible = not is_quest_ui_maximized
		
	# Scene-created Quest Panel
	if quest_panel:
		quest_panel.visible = true
		quest_panel.custom_minimum_size = Vector2.ZERO
		
		if quest_objectives_lbl:
			quest_objectives_lbl.visible = is_quest_ui_maximized
		if quest_status_lbl:
			quest_status_lbl.visible = is_quest_ui_maximized
		if quest_toggle_lbl:
			quest_toggle_lbl.visible = is_quest_ui_maximized
			quest_toggle_lbl.text = hint_text
		quest_panel.reset_size()
			
	# Dynamic Fallback Quest Panel
	if auto_quest_container:
		auto_quest_container.visible = true
		auto_quest_container.custom_minimum_size = Vector2.ZERO
		
		if auto_objectives_label:
			auto_objectives_label.visible = is_quest_ui_maximized
		if auto_status_label:
			auto_status_label.visible = is_quest_ui_maximized
		if auto_toggle_label:
			auto_toggle_label.visible = is_quest_ui_maximized
			auto_toggle_label.text = hint_text
		auto_quest_container.reset_size()

func _setup_scene_quest_toggle_label() -> void:
	# Check if the user already configured a toggle label in their scene
	if not quest_toggle_lbl:
		quest_toggle_lbl = quest_panel.get_node_or_null("%QuestToggleHint")
	if not quest_toggle_lbl:
		quest_toggle_lbl = quest_panel.get_node_or_null("%ToggleHint")
	if not quest_toggle_lbl:
		quest_toggle_lbl = quest_panel.get_node_or_null("%ToggleLabel")
		
	# If no label exists in the scene yet, dynamically append one to the Vbox
	if not quest_toggle_lbl and quest_panel:
		var vbox = quest_panel.get_node_or_null("Vbox")
		if not vbox:
			for child in quest_panel.get_children():
				if child is VBoxContainer:
					vbox = child
					break
		if vbox:
			quest_toggle_lbl = Label.new()
			quest_toggle_lbl.name = "QuestToggleLabel"
			quest_toggle_lbl.theme = quest_panel.theme
			quest_toggle_lbl.add_theme_font_size_override("font_size", 16)
			quest_toggle_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35, 1))
			vbox.add_child(quest_toggle_lbl)


# QUEST UI REFRESH LOGIC

func update_quest_ui() -> void:
	var active_quest = QuestManager.get_current_active_quest()
	
	var title_text = ""
	var objectives_text = ""
	var status_text = ""
	var status_color = Color(0.9, 0.9, 0.9)
	var story_title = _get_story_objective_title()
	var story_detail = _get_story_objective_detail()
	
	var current_quest_id = ""
	var current_quest_name = ""
	var current_kills = 0
	var current_items = 0
	var is_ready = false
	
	if active_quest:
		current_quest_id = active_quest.quest_id
		current_quest_name = active_quest.get_display_name()
		current_kills = active_quest.current_kills
		current_items = active_quest.current_items
		is_ready = active_quest.are_objectives_met()
		
		title_text = "QUEST: " + current_quest_name if is_quest_ui_maximized else "📜"
		
		var lines: Array[String] = []
		if active_quest.required_kills > 0:
			var kill_done = active_quest.current_kills >= active_quest.required_kills
			var mark = "[X] " if kill_done else "[ ] "
			lines.append(mark + "Alpha Glitches: %d / %d" % [min(active_quest.current_kills, active_quest.required_kills), active_quest.required_kills])
			
		if active_quest.required_items > 0:
			var item_done = active_quest.current_items >= active_quest.required_items
			var mark = "[X] " if item_done else "[ ] "
			lines.append(mark + "%s: %d / %d" % [active_quest.get_formatted_item_name(), min(active_quest.current_items, active_quest.required_items), active_quest.required_items])
			
		objectives_text = "\n".join(lines)
		
		if is_ready:
			status_text = "READY TO TURN IN!"
			status_color = Color(0.1, 0.85, 0.2) # Bright green
		else:
			status_text = "IN PROGRESS"
			status_color = Color(0.95, 0.75, 0.2) # Amber
	else:
		title_text = "OBJECTIVE: " + story_title if is_quest_ui_maximized else "📜"
		objectives_text = story_detail
		status_text = "• Explore Localhost"
		status_color = Color(0.6, 0.8, 1.0) # Light blue
		
	# Update Inspector-linked nodes if present
	if quest_title_lbl:
		quest_title_lbl.text = title_text
	if quest_objectives_lbl:
		quest_objectives_lbl.text = objectives_text
	if quest_status_lbl:
		quest_status_lbl.text = status_text
		quest_status_lbl.modulate = status_color
		
	# Update dynamic fallback nodes if present
	if auto_title_label:
		auto_title_label.text = title_text
	if auto_objectives_label:
		auto_objectives_label.text = objectives_text
	if auto_status_label:
		auto_status_label.text = status_text
		auto_status_label.modulate = status_color
		
	
	# UNIVERSAL QUEST / OBJECTIVE CHANGE DETECTION
	
	if not has_initialized_quest_state:
		has_initialized_quest_state = true
		last_known_story_title = story_title
		last_known_story_detail = story_detail
		last_known_quest_id = current_quest_id
		last_known_quest_name = current_quest_name
		last_known_kills = current_kills
		last_known_items = current_items
		last_known_ready_to_turn_in = is_ready
		
		# On initial load, pulse the glowing border if starting minimized!
		if not is_quest_ui_maximized:
			_trigger_quest_attention_pulse(false)
	else:
		var should_alert = false
		var is_progress_increment = false
		
		# 1. New quest accepted
		if current_quest_id != "" and current_quest_id != last_known_quest_id:
			should_alert = true
		# 2. Quest turned in / completed
		elif last_known_quest_id != "" and current_quest_id == "":
			should_alert = true
		# 3. Objectives met (Ready to Turn In)
		elif is_ready and not last_known_ready_to_turn_in:
			should_alert = true
		# 4. Errand kill count progressed
		elif active_quest and current_kills > last_known_kills and last_known_kills >= 0:
			should_alert = true
			is_progress_increment = true
		# 5. Errand item count progressed
		elif active_quest and current_items > last_known_items and last_known_items >= 0:
			should_alert = true
			is_progress_increment = true
		# 6. Story objective title updated (advance in story)
		elif story_title != last_known_story_title:
			should_alert = true
		# 7. Story objective detail updated
		elif story_detail != last_known_story_detail and not active_quest:
			should_alert = true
			
		if should_alert:
			_trigger_quest_attention_pulse(is_progress_increment)
			
		# Store snapshots
		last_known_story_title = story_title
		last_known_story_detail = story_detail
		last_known_quest_id = current_quest_id
		last_known_quest_name = current_quest_name
		last_known_kills = current_kills
		last_known_items = current_items
		last_known_ready_to_turn_in = is_ready
		
	_apply_quest_ui_visibility()

func _get_story_objective_title() -> String:
	if not GameManager.completed_events.has("met_npc_1"):
		return "Report to Town"
	if not GameManager.completed_events.has("met_leader"):
		return "Go to the Lab"
	if not GameManager.completed_events.has("start_errand_1"):
		return "Talk to Pedro"
	if not GameManager.completed_events.has("end_errand_1"):
		return "Clear the Glitches"
	if not GameManager.completed_events.has("start_errand_2"):
		return "Find Merchant"
	if not GameManager.completed_events.has("end_errand_2"):
		return "Town Clean Up"
	if not GameManager.completed_events.has("start_pre_boss"):
		return "Town In Trouble!"
	if not GameManager.completed_events.has("end_pre_boss"):
		return "Town Defense"
	if not GameManager.completed_events.has("boss_beaten"):
		return "Boss In Lab"
	return "Debrief with Leader"

func _get_story_objective_detail() -> String:
	if not GameManager.completed_events.has("met_npc_1"):
		return "Walk around the park to investigate."
	if not GameManager.completed_events.has("met_leader"):
		return "Find Team Leader in Lab.\n[Press L to view Lab photo]"
	if not GameManager.completed_events.has("start_errand_1"):
		return "Speak with Pedro to receive your errand."
	if not GameManager.completed_events.has("end_errand_1"):
		return "Defeat the glitches and return to Pedro."
	if not GameManager.completed_events.has("start_errand_2"):
		return "Follow the newly opened path to the merchant.\n[Press M to view Merchant photo]"
	if not GameManager.completed_events.has("end_errand_2"):
		return "Defeat glitches near the merchant and return."
	if not GameManager.completed_events.has("start_pre_boss"):
		return "Head into town center. Stop the glitches."
	if not GameManager.completed_events.has("end_pre_boss"):
		return "Clear the town center of Alpha Glitches."
	if not GameManager.completed_events.has("boss_beaten"):
		return "Giant Alpha Glitch spotted in Lab! Defeat it."
	return "Speak to Team Leader for final system compilation."

# ==========================================
# NOTIFICATION SYSTEM
# ==========================================
func _on_checkpoint_saved(checkpoint_name: String) -> void:
	show_notification("💾 Checkpoint Saved: " + checkpoint_name)

func show_notification(message: String, duration: float = 2.5) -> void:
	if not notification_label:
		_build_notification_label()
		
	if notification_label and is_instance_valid(notification_label):
		# Cancel any active animation so previous tweens don't conflict or prematurely hide
		if notif_tween and notif_tween.is_valid():
			notif_tween.kill()
			
		notification_label.z_index = 50
		notification_label.text = message
		notification_label.add_theme_color_override("font_color", Color(0.1, 0.15, 0.1))
		notification_label.size = Vector2.ZERO
		notification_label.reset_size()
		notification_label.position.y = 232.0
		notification_label.modulate.a = 0.0
		notification_label.show()
		
		notif_tween = create_tween()
		notif_tween.set_parallel(true)
		notif_tween.tween_property(notification_label, "modulate:a", 1.0, 0.18)
		notif_tween.tween_property(notification_label, "position:y", 226.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		notif_tween.chain().tween_interval(duration)
		notif_tween.chain().tween_property(notification_label, "modulate:a", 0.0, 0.5)
		notif_tween.tween_callback(func():
			if is_instance_valid(notification_label):
				notification_label.hide()
				notification_label.modulate.a = 0.0
		)


# DYNAMIC FALLBACK BUILDER

func _build_dynamic_quest_ui() -> void:
	auto_quest_container = PanelContainer.new()
	auto_quest_container.name = "AutoQuestContainer"
	
	# Position below the monster counter (top-left)
	auto_quest_container.position = Vector2(10, 58)
	auto_quest_container.custom_minimum_size = Vector2(210, 70)
	
	# Try applying existing dialogue theme or default clean style
	if ResourceLoader.exists("res://dialogue.tres"):
		auto_quest_container.theme = load("res://dialogue.tres")
		
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	auto_quest_container.add_child(vbox)
	
	auto_title_label = Label.new()
	auto_title_label.add_theme_font_size_override("font_size", 16)
	auto_title_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	vbox.add_child(auto_title_label)
	
	auto_objectives_label = Label.new()
	auto_objectives_label.add_theme_font_size_override("font_size", 16)
	auto_objectives_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
	vbox.add_child(auto_objectives_label)
	
	auto_status_label = Label.new()
	auto_status_label.add_theme_font_size_override("font_size", 16)
	auto_status_label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	vbox.add_child(auto_status_label)
	
	auto_toggle_label = Label.new()
	auto_toggle_label.text = "[Tab] to minimize"
	auto_toggle_label.add_theme_font_size_override("font_size", 16)
	auto_toggle_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
	vbox.add_child(auto_toggle_label)
	
	add_child(auto_quest_container)

func _build_notification_label() -> void:
	notification_label = Label.new()
	notification_label.name = "CheckpointNotification"
	notification_label.position = Vector2(10, 60)
	notification_label.add_theme_font_size_override("font_size", 16)
	notification_label.add_theme_color_override("font_color", Color(0,0,0))
	
	if ResourceLoader.exists("res://dialogue.tres"):
		notification_label.theme = load("res://dialogue.tres")
	notification_label.hide()
	notification_label.modulate.a = 0.0
	add_child(notification_label)

func check_glitches_cleared_modal() -> void:
	if GameManager.is_battle_active() or GameManager.current_state != GameManager.GameState.EXPLORATION:
		return
	var active_quest = QuestManager.get_current_active_quest()
	if active_quest and active_quest.required_kills > 0 and active_quest.required_items > 0:
		if active_quest.current_kills >= active_quest.required_kills and active_quest.current_items < active_quest.required_items:
			if not active_quest.get_meta("glitches_cleared_notif_shown", false):
				active_quest.set_meta("glitches_cleared_notif_shown", true)
				var title = "ALPHA GLITCHES ELIMINATED"
				var msg = "All alpha glitches are eliminated in this area, please find the items needed to proceed, you may find it as you go further in the grass."
				GameManager.show_modal_notification(title, msg)


# MINIMIZED QUEST HUD GLOWING BORDER

func _setup_quest_panel_style() -> void:
	var target_panel: Control = quest_panel if quest_panel else auto_quest_container
	if not target_panel:
		return
		
	var existing = target_panel.get_theme_stylebox("panel")
	if existing and existing is StyleBoxFlat:
		quest_panel_style = existing.duplicate()
		default_border_color = quest_panel_style.border_color
	else:
		quest_panel_style = StyleBoxFlat.new()
		quest_panel_style.bg_color = Color(1, 1, 1, 1)
		quest_panel_style.set_border_width_all(4)
		quest_panel_style.set_corner_radius_all(8)
		quest_panel_style.content_margin_left = 8
		quest_panel_style.content_margin_top = 8
		quest_panel_style.content_margin_right = 8
		quest_panel_style.content_margin_bottom = 8
		quest_panel_style.border_color = default_border_color
		
	target_panel.add_theme_stylebox_override("panel", quest_panel_style)

func _apply_border_glow(factor: float) -> void:
	if not quest_panel_style:
		return
	var target_panel: Control = quest_panel if quest_panel else auto_quest_container
	# Interpolate border color from default olive green to radiant red
	quest_panel_style.border_color = default_border_color.lerp(glow_border_color, factor)
	# Outer glowing halo
	quest_panel_style.shadow_size = int(round(factor * 4.0))
	quest_panel_style.shadow_color = Color(glow_border_color.r, glow_border_color.g, glow_border_color.b, factor * 0.85)
	if target_panel and is_instance_valid(target_panel):
		target_panel.queue_redraw()

func _trigger_quest_attention_pulse(is_progress_update: bool = false) -> void:
	if not quest_panel_style:
		_setup_quest_panel_style()
		
	is_quest_alert_active = true
	
	# 1. Auditory Feedback
	var audio = get_node_or_null("/root/AudioManager")
	if audio:
		if is_progress_update and audio.has_method("play_ui_click"):
			audio.play_ui_click()
		elif audio.has_method("play_quest_accepted"):
			audio.play_quest_accepted()
			
	# 2. Glowing Border on the UI button itself (only when minimized)
	if not is_quest_ui_maximized:
		if border_glow_tween and border_glow_tween.is_valid():
			border_glow_tween.kill()
			
		border_glow_tween = create_tween()
		border_glow_tween.set_loops()
		border_glow_tween.tween_method(_apply_border_glow, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		border_glow_tween.tween_method(_apply_border_glow, 1.0, 0.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _dismiss_quest_attention_pulse() -> void:
	is_quest_alert_active = false
	if border_glow_tween and border_glow_tween.is_valid():
		border_glow_tween.kill()
		border_glow_tween = null
		
	_apply_border_glow(0.0)
	
