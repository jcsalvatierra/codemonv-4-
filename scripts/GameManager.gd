extends Node

signal player_hp_changed(new_hp, max_hp)
signal game_over_triggered()
signal checkpoint_saved(checkpoint_name)
signal game_finished()
signal dev_mode_toggled(is_enabled)
signal event_completed(event_id)


# 1. FINITE STATE MACHINE (FSM)

enum GameState { MAIN_MENU, EXPLORATION, DIALOGUE, DEBUGGING, GAME_OVER, VICTORY }

var current_state: GameState = GameState.MAIN_MENU


# 1.5 STORY PROGRESSION STATE

enum StoryPhase {
	PHASE_0_SPAWN,           # Start in park
	PHASE_1_GO_TO_LAB,       # Talked to intro NPC, paths blocked
	PHASE_2_ERRAND_1,        # 1st Errand (Easy - 3 bugs)
	PHASE_3_GO_TO_MERCHANT,  # Errand 1 done, path 2 opens
	PHASE_4_ERRAND_2,        # 2nd Errand (Medium - 3 bugs)
	PHASE_5_TOWN_INVASION,   # Errand 2 done, Town invasion (Hard - 3 bugs)
	PHASE_6_BOSS_FIGHT,      # Boss time (1 Giant Bug)
	PHASE_7_VICTORY          # Game beaten
}
var current_story_phase: StoryPhase = StoryPhase.PHASE_0_SPAWN
var completed_events: Array[String] = []


# 2. PLAYER & QUEST VARIABLES

var max_hp: int = 5
var player_hp: int = 5
var total_bugs_defeated: int = 0
var current_language_phase: String = ""

# Reference to the active Player sa instance (set by player.gd on _ready)
var current_player: CharacterBody2D = null


# 2.5 CHECKPOINT DATA STORAGE

var has_checkpoint: bool = false
var checkpoint_events: Array[String] = []
var checkpoint_bugs_defeated: int = 0
var checkpoint_player_pos: Vector2 = Vector2.ZERO
var checkpoint_player_dir: String = "down"
var checkpoint_story_phase: StoryPhase = StoryPhase.PHASE_0_SPAWN
var checkpoint_quests: Dictionary = {}
var checkpoint_name: String = "Initial Spawn"
var last_checkpoint_id: String = ""
var checkpoint_just_restored: bool = false

const AUTO_CHECKPOINT_EVENTS: Array[String] = [
	"met_npc_1",
	"met_leader",
	"start_errand_1",
	"end_errand_1",
	"pre_meet_merchant",
	"start_errand_2",
	"end_errand_2",
	"start_pre_boss",
	"end_pre_boss"
]


# 2.8 DEV TOOLS & KILL SWITCH

var allow_dev_mode: bool = false 
var dev_mode: bool = false # Current state of dev mode (F1)
var dev_config: DevCheckpointConfig = null
var debug_canvas: CanvasLayer = null
var debug_label: Label = null

func _init() -> void:
	if FileAccess.file_exists("res://resources/dev_checkpoint_config.tres"):
		dev_config = load("res://resources/dev_checkpoint_config.tres") as DevCheckpointConfig
	else:
		_generate_default_dev_checkpoints()

func _generate_default_dev_checkpoints() -> void:
	dev_config = DevCheckpointConfig.new()
	var auto_events = ["met_npc_1", "met_leader", "start_errand_1", "end_errand_1", "pre_meet_merchant", "start_errand_2", "end_errand_2", "start_pre_boss", "end_pre_boss"]
	var accumulated_events: Array[String] = []
	for i in range(auto_events.size()):
		var evt = auto_events[i]
		accumulated_events.append(evt)
		var cp = DevCheckpoint.new()
		cp.checkpoint_id = evt
		cp.display_name = "Dev: " + evt
		cp.completed_events = accumulated_events.duplicate()
		if evt == "met_npc_1": cp.story_phase = 1
		elif evt == "met_leader": cp.story_phase = 2
		elif evt == "start_errand_1": 
			cp.story_phase = 2
			cp.active_quest = load("res://quests/quest_1.tres") as QuestData
		elif evt == "end_errand_1": 
			cp.story_phase = 3
			cp.total_bugs_defeated = 3
			cp.completed_quests.append(load("res://quests/quest_1.tres") as QuestData)
		elif evt == "pre_meet_merchant": 
			cp.story_phase = 4
			cp.total_bugs_defeated = 3
			cp.completed_quests.append(load("res://quests/quest_1.tres") as QuestData)
		elif evt == "start_errand_2": 
			cp.story_phase = 4
			cp.total_bugs_defeated = 3
			cp.active_quest = load("res://quests/quest_2.tres") as QuestData
			cp.completed_quests.append(load("res://quests/quest_1.tres") as QuestData)
		elif evt == "end_errand_2": 
			cp.story_phase = 5
			cp.total_bugs_defeated = 6
			cp.completed_quests.append(load("res://quests/quest_1.tres") as QuestData)
			cp.completed_quests.append(load("res://quests/quest_2.tres") as QuestData)
		elif evt == "start_pre_boss" or evt == "end_pre_boss": 
			cp.story_phase = 6
			cp.total_bugs_defeated = 6
			cp.completed_quests.append(load("res://quests/quest_1.tres") as QuestData)
			cp.completed_quests.append(load("res://quests/quest_2.tres") as QuestData)
		dev_config.checkpoints.append(cp)
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("resources"): dir.make_dir("resources")
	ResourceSaver.save(dev_config, "res://resources/dev_checkpoint_config.tres")
	print("Generated dev_checkpoint_config.tres")


# 2.9 SPEEDRUN TIMER & LEADERBOARD CONFIG

var current_player_name: String = ""
var run_elapsed_time: float = 0.0
var run_timer_active: bool = false
var leaderboard_api_url: String = "https://codemon-web.vercel.app/api/leaderboard"
var leaderboard_api_key: String = "63475319-c588-4952-8992-54a79c8a3585" # Optional token for x-api-key header
var total_expected_monsters: int = 15


# 2.92 PROFILE PERSISTENCE CONFIG

const PROFILE_SAVE_PATH: String = "user://profile.json"
var has_set_profile: bool = false
var saved_profiles: Array = []
var in_game_profile_prompt_instance: CanvasLayer = null

func load_profile_data() -> void:
	has_set_profile = false
	current_player_name = ""
	saved_profiles = []
	
	if not FileAccess.file_exists(PROFILE_SAVE_PATH):
		return
		
	var file = FileAccess.open(PROFILE_SAVE_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		var json = JSON.new()
		if json.parse(content) == OK and json.data is Dictionary:
			var data: Dictionary = json.data
			var active = str(data.get("active_name", "")).strip_edges()
			var is_set = bool(data.get("has_set_profile", false))
			var list = data.get("saved_profiles", [])
			if list is Array:
				for item in list:
					var p = str(item).strip_edges()
					if not p.is_empty() and p != "Coder_1" and p != "Coder 1" and not saved_profiles.has(p):
						saved_profiles.append(p)
			else:
				saved_profiles = []
				
			# Invalidate any previously seeded placeholder test strings
			if active == "Coder_1" or active == "Coder 1":
				active = ""
				is_set = false
				
			if is_set and not active.is_empty():
				current_player_name = active
				has_set_profile = true
				if not saved_profiles.has(current_player_name):
					saved_profiles.append(current_player_name)
			elif saved_profiles.size() > 0:
				current_player_name = saved_profiles[0]
				has_set_profile = true
			else:
				current_player_name = ""
				has_set_profile = false
				saved_profiles = []
		else:
			has_set_profile = false
			current_player_name = ""
			saved_profiles = []
	else:
		has_set_profile = false
		current_player_name = ""
		saved_profiles = []

func save_profile_data(new_name: String = "") -> bool:
	var clean_name = new_name.strip_edges()
	if clean_name.is_empty():
		clean_name = current_player_name.strip_edges()
		
	if clean_name.is_empty() or clean_name == "Coder_1" or clean_name == "Coder 1":
		return false
		
	current_player_name = clean_name
	has_set_profile = true
	if not saved_profiles.has(current_player_name):
		saved_profiles.append(current_player_name)
		
	var data = {
		"active_name": current_player_name,
		"has_set_profile": true,
		"saved_profiles": saved_profiles
	}
	var file = FileAccess.open(PROFILE_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	print("Profile saved: ", current_player_name, " | All profiles: ", saved_profiles)
	return true

func ensure_profile_set(on_confirmed: Callable = Callable()) -> void:
	if has_set_profile and not current_player_name.strip_edges().is_empty():
		if on_confirmed.is_valid():
			on_confirmed.call()
		return
		
	show_profile_creation_dialog(on_confirmed)

func show_profile_creation_dialog(on_confirmed: Callable = Callable()) -> void:
	if in_game_profile_prompt_instance and is_instance_valid(in_game_profile_prompt_instance):
		return
		
	in_game_profile_prompt_instance = CanvasLayer.new()
	in_game_profile_prompt_instance.layer = 45
	in_game_profile_prompt_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.04, 0.07, 0.05, 0.88)
	in_game_profile_prompt_instance.add_child(backdrop)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	in_game_profile_prompt_instance.add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 150)
	if ResourceLoader.exists("res://dialogue.tres"):
		panel.theme = load("res://dialogue.tres")
		
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.12, 0.09, 0.98)
	panel_style.border_color = Color(0.3, 0.6, 0.38, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 14
	panel_style.content_margin_right = 14
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
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
	subtitle.text = "Enter your alias to play:"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.85, 0.8, 1.0))
	vbox.add_child(subtitle)
	
	var line_edit = LineEdit.new()
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
	
	var btn_confirm = Button.new()
	btn_confirm.text = "Confirm & Save"
	btn_confirm.add_theme_font_size_override("font_size", 16)
	vbox.add_child(btn_confirm)
	
	var on_submit = func():
		var chosen_name = line_edit.text.strip_edges()
		if chosen_name.is_empty():
			warn_lbl.text = "Please enter an alias."
			line_edit.grab_focus()
			return
		save_profile_data(chosen_name)
		in_game_profile_prompt_instance.queue_free()
		in_game_profile_prompt_instance = null
		if on_confirmed.is_valid():
			on_confirmed.call()
			
	btn_confirm.pressed.connect(on_submit)
	line_edit.text_submitted.connect(func(_text): on_submit.call())
	
	add_child(in_game_profile_prompt_instance)
	line_edit.grab_focus()


# 2.95 QUESTION TIMER CONFIG (Configurable)

var base_question_time: float = 30.0 # Default minimum 30s
var time_per_level: float = 5.0     # +5s for every level
var timer_enabled: bool = true

# Helper to format seconds into MM:SS.ms
func format_run_time(time_seconds: float) -> String:
	var total_secs = max(0.0, time_seconds)
	var minutes = int(total_secs) / 60
	var seconds = int(total_secs) % 60
	var ms = int((total_secs - int(total_secs)) * 100)
	return "%02d:%02d.%02d" % [minutes, seconds, ms]


# 3. LINEAR CONGRUENTIAL GENERATOR (LCG)

var lcg_seed: int = 12345
const LCG_A: int = 1103515245
const LCG_C: int = 12345
const LCG_M: int = 2147483648

var CHARACTERS_SPEED = 50

# Persistent pause menu instance
var pause_menu_instance: CanvasLayer = null

# One-time controls window instance & tracking
var has_shown_controls: bool = false
var controls_popup_instance: CanvasLayer = null

# Centered Theme Modal Notification system (Lab & Area Cleared notifications)
@export_group("Lab Objective Modal")
@export var lab_image: Texture2D = null
var has_shown_lab_modal: bool = false

@export_group("Merchant Objective Modal")
@export var merchant_image: Texture2D = null
var has_shown_merchant_modal: bool = false

var active_modal_instance: CanvasLayer = null
var active_battle_instance: Node = null
var pending_modal_data: Dictionary = {}


# SYSTEM FUNCTIONS

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	lcg_seed = randi()
	load_profile_data()
	_setup_pause_menu()
	_setup_debug_hud()
	print("GameManager initialized. Active profile: ", current_player_name)

func _setup_debug_hud() -> void:
	debug_canvas = CanvasLayer.new()
	debug_canvas.name = "DevDebugHUD"
	debug_canvas.layer = 128
	debug_canvas.visible = false
	
	var panel = PanelContainer.new()
	panel.modulate.a = 0.85
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-300, 10)
	panel.custom_minimum_size = Vector2(280, 200)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	debug_label = Label.new()
	debug_label.add_theme_font_size_override("font_size", 12)
	debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_bottom", 10)
	
	m.add_child(debug_label)
	panel.add_child(m)
	debug_canvas.add_child(panel)
	add_child(debug_canvas)

func _process(delta: float) -> void:
	if run_timer_active and not get_tree().paused and current_state != GameState.MAIN_MENU and current_state != GameState.GAME_OVER and current_state != GameState.VICTORY:
		run_elapsed_time += delta
		
	if debug_canvas and debug_canvas.visible:
		_update_debug_text()

func _update_debug_text() -> void:
	if not debug_label: return
	
	var txt = "--- DEV DEBUG INFO (F3) ---\n"
	txt += "Phase: " + str(current_story_phase) + " | HP: " + str(player_hp) + "/" + str(max_hp) + "\n"
	txt += "Bugs Defeated: " + str(total_bugs_defeated) + "\n\n"
	
	txt += "[ COMPLETED EVENTS ]\n"
	if completed_events.is_empty():
		txt += " (None)\n"
	else:
		# Just show the last 4 to avoid massive clutter, or all if short
		var start_idx = max(0, completed_events.size() - 5)
		if start_idx > 0:
			txt += " ...\n"
		for i in range(start_idx, completed_events.size()):
			txt += " - " + completed_events[i] + "\n"
			
	txt += "\n[ ACTIVE QUESTS ]\n"
	if QuestManager.active_quests.is_empty():
		txt += " (None)\n"
	else:
		for q_id in QuestManager.active_quests:
			var q = QuestManager.active_quests[q_id]
			var prog = ""
			if q.required_kills > 0: prog = " Kills: %d/%d" % [q.current_kills, q.required_kills]
			if q.required_items > 0: prog += " Items: %d/%d" % [q.current_items, q.required_items]
			var status = "[DONE]" if q.is_completed else "[ ]"
			txt += " " + status + " " + q.quest_name + prog + "\n"
			
	debug_label.text = txt

func _setup_pause_menu() -> void:
	if pause_menu_instance != null and is_instance_valid(pause_menu_instance):
		return
		
	var pause_script = load("res://scripts/pause_menu.gd")
	if pause_script:
		pause_menu_instance = CanvasLayer.new()
		pause_menu_instance.name = "PauseMenuLayer"
		pause_menu_instance.layer = 35
		pause_menu_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		pause_menu_instance.set_script(pause_script)
		add_child(pause_menu_instance)

func show_controls_popup() -> void:
	if controls_popup_instance != null and is_instance_valid(controls_popup_instance):
		return
		
	var popup_script = load("res://scripts/controls_popup.gd")
	if popup_script:
		controls_popup_instance = CanvasLayer.new()
		controls_popup_instance.name = "ControlsPopupLayer"
		controls_popup_instance.layer = 40
		controls_popup_instance.tree_exited.connect(func(): controls_popup_instance = null)
		controls_popup_instance.set_script(popup_script)
		add_child(controls_popup_instance)

func register_battle_instance(battle_node: Node) -> void:
	active_battle_instance = battle_node
	if not battle_node.tree_exited.is_connected(_on_battle_tree_exited):
		battle_node.tree_exited.connect(_on_battle_tree_exited)

func unregister_battle_instance(battle_node: Node) -> void:
	if active_battle_instance == battle_node:
		active_battle_instance = null
		_on_battle_tree_exited()

func _on_battle_tree_exited() -> void:
	active_battle_instance = null
	if is_inside_tree():
		get_tree().process_frame.connect(_process_pending_modal_after_battle, CONNECT_ONE_SHOT)

func _process_pending_modal_after_battle() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_battle_active() and current_state == GameState.EXPLORATION:
		check_pending_modal()

func is_battle_active() -> bool:
	if current_state == GameState.DEBUGGING:
		return true
	if active_battle_instance != null and is_instance_valid(active_battle_instance) and not active_battle_instance.is_queued_for_deletion():
		return true
	var tree = get_tree()
	if tree:
		var battle_nodes = tree.get_nodes_in_group("battle_scene")
		for node in battle_nodes:
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				return true
		for child in tree.root.get_children():
			if is_instance_valid(child) and not child.is_queued_for_deletion():
				if child.name.begins_with("BattleScene"):
					return true
	return false

func show_modal_notification(title: String, message: String, image: Texture2D = null, on_dismiss: Callable = Callable()) -> CanvasLayer:
	# If battle is active or visible, queue it until returning to exploration!
	if is_battle_active():
		print("[GameManager] Battle is active/visible. Deferring modal: ", title)
		pending_modal_data = {
			"title": title,
			"message": message,
			"image": image,
			"on_dismiss": on_dismiss
		}
		return null

	if active_modal_instance != null and is_instance_valid(active_modal_instance):
		active_modal_instance.queue_free()
		active_modal_instance = null
		
	var modal_script = load("res://scripts/modal_notification.gd")
	if modal_script:
		var modal = modal_script.create(title, message, image, "Got It", on_dismiss)
		modal.name = "ModalNotificationLayer"
		active_modal_instance = modal
		modal.tree_exited.connect(func():
			if active_modal_instance == modal:
				active_modal_instance = null
		)
		add_child(modal)
		return modal
	return null

func check_pending_modal() -> void:
	if is_battle_active() or current_state != GameState.EXPLORATION:
		return
	if not pending_modal_data.is_empty():
		var data = pending_modal_data.duplicate()
		pending_modal_data.clear()
		show_modal_notification(
			data.get("title", ""),
			data.get("message", ""),
			data.get("image", null),
			data.get("on_dismiss", Callable())
		)
	elif current_player:
		var p_ui = current_player.get_node_or_null("UI")
		if p_ui and p_ui.has_method("check_glitches_cleared_modal"):
			p_ui.check_glitches_cleared_modal()

func show_lab_objective_modal(force: bool = false) -> void:
	if not force and has_shown_lab_modal:
		return
	has_shown_lab_modal = true
	var img = lab_image
	if img == null and current_player:
		var p_ui = current_player.get_node_or_null("UI")
		if p_ui and "lab_image" in p_ui and p_ui.lab_image != null:
			img = p_ui.lab_image
			lab_image = img
			
	var msg = "Pedro told you to report to Team Leader at the Lab!\nLook for this building in town."
	show_modal_notification("MISSION: GO TO THE LAB", msg, img)

func show_merchant_objective_modal(force: bool = false) -> void:
	if not force and has_shown_merchant_modal:
		return
	has_shown_merchant_modal = true
	var img = merchant_image
	if img == null and current_player:
		var p_ui = current_player.get_node_or_null("UI")
		if p_ui and "merchant_image" in p_ui and p_ui.merchant_image != null:
			img = p_ui.merchant_image
			merchant_image = img
			
	var msg = "Juan told you about a tech merchant down the path!\nLook for the merchant by going north west of town"
	show_modal_notification("MISSION: FIND THE MERCHANT", msg, img)

func _unhandled_input(event: InputEvent) -> void:
	# Dev hotkey: F1 toggles dev mode on/off
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1 and allow_dev_mode:
			toggle_dev_mode()
		elif event.keycode == KEY_F3 and dev_mode:
			if debug_canvas:
				debug_canvas.visible = not debug_canvas.visible

func toggle_dev_mode() -> void:
	dev_mode = !dev_mode
	print("Dev Mode toggled: ", "ON" if dev_mode else "OFF")
	dev_mode_toggled.emit(dev_mode)

func complete_event(event_id: String) -> void:
	if not completed_events.has(event_id):
		completed_events.append(event_id)
		
		print("\n========================================")
		print("MICRO-EVENT COMPLETED: ", event_id)
		print("CURRENT MEMORY: ", completed_events)
		print("========================================\n")
		
		# Auto-save checkpoint if milestone reached
		if AUTO_CHECKPOINT_EVENTS.has(event_id):
			save_checkpoint(Vector2.ZERO, "", _format_checkpoint_name(event_id), event_id)
			
		# Check if this event finishes the whole game
		if event_id == "game_finished":
			finish_game()
			
		event_completed.emit(event_id)
		
		# If Pedro told player to go to the lab, show the Lab modal with the lab picture
		if event_id == "met_npc_1":
			get_tree().create_timer(0.35).timeout.connect(func():
				show_lab_objective_modal()
			)
		elif event_id == "pre_meet_merchant":
			get_tree().create_timer(0.35).timeout.connect(func():
				show_merchant_objective_modal()
			)

func change_state(new_state: GameState) -> void:
	current_state = new_state
	print("FSM State changed to: ", GameState.keys()[current_state])

func _calculate_lcg_roll() -> float:
	lcg_seed = (LCG_A * lcg_seed + LCG_C) % LCG_M
	return float(lcg_seed) / float(LCG_M)

func check_for_encounter(encounter_threshold: float = 0.15) -> bool:
	if not QuestManager.needs_enemy("alpha_glitch"):
		return false
		
	var roll = _calculate_lcg_roll()
	return roll <= encounter_threshold

func take_damage(amount: int) -> void:
	player_hp = max(0, player_hp - amount)
	print("System damaged! Current HP: ", player_hp)
	
	player_hp_changed.emit(player_hp, max_hp)
	if player_hp <= 0:
		trigger_game_over()


# CHECKPOINT MANAGEMENT

func save_checkpoint(custom_pos: Vector2 = Vector2.ZERO, custom_dir: String = "", cp_label: String = "", micro_event: String = "") -> void:
	# Refuse to save checkpoints if the game has already concluded in victory
	if current_state == GameState.VICTORY or current_story_phase == StoryPhase.PHASE_7_VICTORY:
		print("Checkpoint save ignored: Game has already finished in victory state.")
		return

	var event_to_append: String = micro_event
	
	# If no explicit micro_event was passed, check if cp_label is or maps to an event ID
	if event_to_append == "" and cp_label != "":
		if AUTO_CHECKPOINT_EVENTS.has(cp_label) or cp_label.begins_with("start_") or cp_label.begins_with("end_") or cp_label.begins_with("met_") or cp_label.begins_with("quest_") or cp_label.begins_with("collected_"):
			event_to_append = cp_label
		else:
			for ev in AUTO_CHECKPOINT_EVENTS:
				if _format_checkpoint_name(ev) == cp_label:
					event_to_append = ev
					break
	
	if event_to_append != "":
		last_checkpoint_id = event_to_append
		if not completed_events.has(event_to_append):
			completed_events.append(event_to_append)
			print("MICRO-EVENT COMPLETED (IN CHECKPOINT): ", event_to_append)
			
	checkpoint_events = completed_events.duplicate()
	checkpoint_bugs_defeated = total_bugs_defeated
	checkpoint_story_phase = current_story_phase
	checkpoint_quests = QuestManager.get_quests_snapshot()
	
	if custom_pos != Vector2.ZERO:
		checkpoint_player_pos = custom_pos
	elif is_instance_valid(current_player):
		checkpoint_player_pos = current_player.global_position
	else:
		checkpoint_player_pos = Vector2(272, 128)
		
	if custom_dir != "":
		checkpoint_player_dir = custom_dir
	elif is_instance_valid(current_player) and "current_direction" in current_player:
		checkpoint_player_dir = current_player.current_direction
	else:
		checkpoint_player_dir = "down"
		
	if cp_label != "":
		checkpoint_name = cp_label
	else:
		checkpoint_name = "Phase %d (%d bugs)" % [current_story_phase, total_bugs_defeated]
		
	has_checkpoint = true
	print("Checkpoint Saved: ", checkpoint_name, " at ", checkpoint_player_pos, " | Events: ", checkpoint_events)
	checkpoint_saved.emit(checkpoint_name)
	
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_checkpoint_saved"):
		audio.play_checkpoint_saved()

func flush_checkpoint() -> void:
	has_checkpoint = false
	checkpoint_events.clear()
	checkpoint_quests.clear()
	checkpoint_bugs_defeated = 0
	checkpoint_story_phase = StoryPhase.PHASE_0_SPAWN
	checkpoint_name = "Initial Spawn"
	checkpoint_player_pos = Vector2(272, 128)
	checkpoint_player_dir = "down"
	checkpoint_just_restored = false
	has_shown_lab_modal = false
	print("Checkpoints flushed: Saved checkpoint cleared after game completion.")

func restore_checkpoint() -> void:
	if not has_checkpoint:
		print("WARNING: No checkpoint found to restore! Resetting to default.")
		start_new_game()
		return
		
	var config_restored = false
	if last_checkpoint_id != "" and dev_config != null:
		var target_cp: DevCheckpoint = null
		for cp in dev_config.checkpoints:
			if cp.checkpoint_id == last_checkpoint_id:
				target_cp = cp
				break
				
		if target_cp:
			# Apply loaded config data precisely like dev mode
			completed_events.clear()
			completed_events.append_array(target_cp.completed_events)
			current_story_phase = target_cp.story_phase as StoryPhase
			total_bugs_defeated = target_cp.total_bugs_defeated
			
			QuestManager.active_quests.clear()
			for cq in target_cp.completed_quests:
				if cq:
					var clone = cq.duplicate()
					clone.is_completed = true
					QuestManager.active_quests[clone.quest_id] = clone
					
			if target_cp.active_quest:
				var active_clone = target_cp.active_quest.duplicate()
				active_clone.is_completed = false
				if active_clone.required_kills > 0:
					active_clone.current_kills = target_cp.quest_progress
				elif active_clone.required_items > 0:
					active_clone.current_items = target_cp.quest_progress
				QuestManager.active_quests[active_clone.quest_id] = active_clone
				
			QuestManager.quest_updated.emit()
			config_restored = true
			print("Checkpoint Restored (From DevConfig): ", last_checkpoint_id)
			
	if not config_restored:
		# Fallback to pure runtime snapshot memory if no config match
		completed_events = checkpoint_events.duplicate()
		total_bugs_defeated = checkpoint_bugs_defeated
		current_story_phase = checkpoint_story_phase
		QuestManager.restore_quests_snapshot(checkpoint_quests)
		print("Checkpoint Restored (Runtime Snapshot Fallback): ", checkpoint_name)
		
	player_hp = max_hp
	player_hp_changed.emit(player_hp, max_hp)
	
	checkpoint_just_restored = true

func _format_checkpoint_name(event_id: String) -> String:
	match event_id:
		"met_npc_1": return "Park Explored"
		"met_leader": return "Lab Briefing"
		"start_errand_1": return "Errand 1 Accepted"
		"end_errand_1": return "Errand 1 Completed"
		"pre_meet_merchant": return "Merchant Path Opened"
		"start_errand_2": return "Errand 2 Accepted"
		"end_errand_2": return "Errand 2 Completed"
		"start_pre_boss": return "Town Center Breach"
		"end_pre_boss": return "Town Defended"
		_: return event_id.capitalize()

func cleanup_overlays() -> void:
	get_tree().paused = false
	if pause_menu_instance != null and is_instance_valid(pause_menu_instance):
		if pause_menu_instance.has_method("resume_game"):
			pause_menu_instance.resume_game()
		else:
			pause_menu_instance.hide()
			
	if controls_popup_instance != null and is_instance_valid(controls_popup_instance):
		controls_popup_instance.queue_free()
		controls_popup_instance = null
		
	if active_modal_instance != null and is_instance_valid(active_modal_instance):
		active_modal_instance.queue_free()
		active_modal_instance = null
			
	for child in get_tree().root.get_children():
		if child.name == "DynamicGameOver" or child.name == "GameOver":
			child.queue_free()
		elif child.name == "DynamicVictoryScreen" or child.name == "GameFinished":
			child.queue_free()
		elif child.name.begins_with("BattleScene") or child.has_method("_end_battle"):
			child.queue_free()

func go_to_main_menu() -> void:
	cleanup_overlays()
	run_timer_active = false
	change_state(GameState.MAIN_MENU)
	
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_bgm_main_menu"):
		audio.play_bgm_main_menu()
		
	if ResourceLoader.exists("res://scenes/main_menu.tscn"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		start_new_game()

func respawn_at_checkpoint() -> void:
	cleanup_overlays()
	restore_checkpoint()
	
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_bgm_world"):
		audio.play_bgm_world()
		
	change_state(GameState.EXPLORATION)
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func start_new_game() -> void:
	cleanup_overlays()
	has_shown_controls = false
	player_hp = max_hp
	total_bugs_defeated = 0
	completed_events.clear()
	current_story_phase = StoryPhase.PHASE_0_SPAWN
	flush_checkpoint()
	QuestManager.reset_all_quests()
	
	# Start speedrun timer
	run_elapsed_time = 0.0
	run_timer_active = true
	
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_bgm_world"):
		audio.play_bgm_world()
		
	player_hp_changed.emit(player_hp, max_hp)
	change_state(GameState.EXPLORATION)
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func jump_to_dev_checkpoint(checkpoint_id: String) -> void:
	if not dev_mode: return
	cleanup_overlays()
	
	var target_cp: DevCheckpoint = null
	if dev_config:
		for cp in dev_config.checkpoints:
			if cp.checkpoint_id == checkpoint_id:
				target_cp = cp
				break
				
	if not target_cp:
		print("ERROR: Checkpoint ID not found in dev_config: ", checkpoint_id)
		return
		
	# Apply loaded config data
	completed_events.clear()
	completed_events.append_array(target_cp.completed_events)
	current_story_phase = target_cp.story_phase as StoryPhase
	total_bugs_defeated = target_cp.total_bugs_defeated
	
	# Seed QuestData!
	QuestManager.active_quests.clear()
	for cq in target_cp.completed_quests:
		if cq:
			var clone = cq.duplicate()
			clone.is_completed = true
			QuestManager.active_quests[clone.quest_id] = clone
			
	if target_cp.active_quest:
		var active_clone = target_cp.active_quest.duplicate()
		active_clone.is_completed = false
		if active_clone.required_kills > 0:
			active_clone.current_kills = target_cp.quest_progress
		elif active_clone.required_items > 0:
			active_clone.current_items = target_cp.quest_progress
		QuestManager.active_quests[active_clone.quest_id] = active_clone
		
	QuestManager.quest_updated.emit()
	
	player_hp = max_hp
	player_hp_changed.emit(player_hp, max_hp)
	
	checkpoint_player_pos = Vector2.ZERO
	checkpoint_name = checkpoint_id
	checkpoint_just_restored = true
	
	# For dev jump, we treat it like a restored checkpoint but set run_elapsed_time to something or leave it
	change_state(GameState.EXPLORATION)
	get_tree().change_scene_to_file("res://scenes/world.tscn")


# GAME OVER & GAME FINISHED

func trigger_game_over() -> void:
	change_state(GameState.GAME_OVER)
	print("GAME OVER: System HP depleted to 0!")
	game_over_triggered.emit()
	
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_bgm_game_over"):
		audio.play_bgm_game_over()
	
	# If game_over.tscn exists, instantiate it on root
	if ResourceLoader.exists("res://scenes/game_over.tscn"):
		var already_open = false
		for child in get_tree().root.get_children():
			if child.name == "GameOver":
				already_open = true
				break
		if not already_open:
			var go_scene = load("res://scenes/game_over.tscn")
			var go_node = go_scene.instantiate()
			go_node.name = "GameOver"
			get_tree().root.add_child(go_node)
	else:
		# Dynamic fallback UI directly from game_over_ui.gd
		var already_open = false
		for child in get_tree().root.get_children():
			if child.name == "DynamicGameOver":
				already_open = true
				break
		if not already_open:
			var go_canvas = CanvasLayer.new()
			go_canvas.name = "DynamicGameOver"
			var go_script = load("res://scripts/game_over_ui.gd")
			go_canvas.set_script(go_script)
			get_tree().root.add_child(go_canvas)

func finish_game() -> void:
	change_state(GameState.VICTORY)
	current_story_phase = StoryPhase.PHASE_7_VICTORY
	run_timer_active = false
	print("VICTORY: Game Finished! Localhost Town is safe.")
	print("Clear Time: ", format_run_time(run_elapsed_time), " (", run_elapsed_time, "s)")
	
	# Flush saved checkpoints so player cannot continue from a checkpoint after finishing the game
	flush_checkpoint()
	QuestManager.reset_all_quests()
	
	# Record to leaderboard (encrypted local file + online sync)
	var lm = get_node_or_null("/root/LeaderboardManager")
	if lm and lm.has_method("record_run"):
		lm.record_run(current_player_name, run_elapsed_time, total_bugs_defeated)
		
	game_finished.emit()
	
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_bgm_victory"):
		audio.play_bgm_victory()
	
	# If a dedicated game_finished scene exists, transition to it
	if ResourceLoader.exists("res://scenes/game_finished.tscn"):
		get_tree().change_scene_to_file("res://scenes/game_finished.tscn")
	else:
		# Fallback overlay if game_finished.tscn not created yet
		var victory_canvas = CanvasLayer.new()
		victory_canvas.name = "DynamicVictoryScreen"
		var victory_ctrl = Control.new()
		var victory_script = load("res://scripts/game_finished_ui.gd")
		victory_ctrl.set_script(victory_script)
		victory_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
		victory_canvas.add_child(victory_ctrl)
		get_tree().root.add_child(victory_canvas)
