extends CharacterBody2D

var SPEED: float = GameManager.CHARACTERS_SPEED #Default is 50
const TILE_SIZE: float = 16.0 
const BATTLE_SCENE = preload("res://scenes/battle_scene.tscn")

const TURN_TIME: float = 0.08

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray_cast: RayCast2D = $CollisionRayCast

var current_direction: String = "down"

var grass_overlap_count: int = 0
var in_tall_grass: bool = false

# Grid Movement Variables
var is_moving: bool = false
var target_position: Vector2 = Vector2.ZERO

# Turn-in-place gate (idle -> new direction only)
var is_turning: bool = false
var turn_time_left: float = 0.0

# Priority order for held keys (first match wins on diagonal presses).
const INPUT_DIRECTIONS := [
	["ui_right", "right", Vector2.RIGHT],
	["ui_left", "left", Vector2.LEFT],
	["ui_down", "down", Vector2.DOWN],
	["ui_up", "up", Vector2.UP],
]

func _ready() -> void:
	GameManager.current_player = self
	
	# Force the FSM into exploration mode on load
	GameManager.change_state(GameManager.GameState.EXPLORATION)

	# If a saved checkpoint position exists, restore the player there!
	if GameManager.checkpoint_player_pos != Vector2.ZERO:
		global_position = GameManager.checkpoint_player_pos.snapped(Vector2(TILE_SIZE, TILE_SIZE))
		current_direction = GameManager.checkpoint_player_dir
	elif GameManager.checkpoint_name != "Initial Spawn" and GameManager.checkpoint_name != "":
		# Dev Jump to Checkpoint Mode
		var world = get_parent()
		var checkpoint_marker = world.get_node_or_null("Checkpoints/" + GameManager.checkpoint_name)
		if checkpoint_marker:
			global_position = checkpoint_marker.global_position.snapped(Vector2(TILE_SIZE, TILE_SIZE))
			current_direction = "down"
		else:
			global_position = global_position.snapped(Vector2(TILE_SIZE, TILE_SIZE))
	else:
		# Snap the player perfectly to the 16x16 grid when they spawn
		global_position = global_position.snapped(Vector2(TILE_SIZE, TILE_SIZE))
		# Establish initial checkpoint at first spawn
		GameManager.save_checkpoint(global_position, current_direction, "Spawn Point")
		
	target_position = global_position
	
	# Initialize RayCast direction based on default facing
	match current_direction:
		"right": ray_cast.target_position = Vector2.RIGHT * TILE_SIZE
		"left": ray_cast.target_position = Vector2.LEFT * TILE_SIZE
		"up": ray_cast.target_position = Vector2.UP * TILE_SIZE
		_: ray_cast.target_position = Vector2.DOWN * TILE_SIZE
		
	anim.play("idle_" + current_direction)
	
	# Start World Exploration BGM
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_bgm_world"):
		audio.play_bgm_world()
		
	# One-time controls window show on initial game spawn
	if not GameManager.has_shown_controls:
		GameManager.has_shown_controls = true
		get_tree().create_timer(0.25).timeout.connect(func():
			if is_instance_valid(self) and GameManager.current_state == GameManager.GameState.EXPLORATION:
				if not GameManager.has_set_profile or GameManager.current_player_name.is_empty():
					GameManager.ensure_profile_set(func():
						GameManager.show_controls_popup()
					)
				else:
					GameManager.show_controls_popup()
		)

func _exit_tree() -> void:
	if GameManager.current_player == self:
		GameManager.current_player = null


# INTERACTION LOGIC (NEW)

# INTERACTION LOGIC (TILEMAP UPDATE)

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_state != GameManager.GameState.EXPLORATION:
		return
	if is_moving or is_turning:
		return
		
	if event.is_action_pressed("ui_accept"):
		ray_cast.force_raycast_update()
		
		if ray_cast.is_colliding():
			var hit_object = ray_cast.get_collider()
			
			# CHECK 1: Did we hit a specific Node (like an NPC)?
			if hit_object.has_method("interact"):
				var audio = get_node_or_null("/root/AudioManager")
				if audio and audio.has_method("play_dialogue_interact"):
					audio.play_dialogue_interact()
				hit_object.interact()
				return
				
			# CHECK 2: Did we hit the TileMapLayer (like a Sign)?
			if hit_object is TileMapLayer:
				# 1. Calculate exactly which tile we are pointing at
				var point_ahead = global_position + ray_cast.target_position
				
				# 2. Convert that world position into TileMap grid coordinates
				var map_coords = hit_object.local_to_map(hit_object.to_local(point_ahead))
				
				# 3. Get the data for that specific tile
				var tile_data = hit_object.get_cell_tile_data(map_coords)
				
				if tile_data:
					var hit_tile_set = hit_object.tile_set
					
					# Ask the TileSet: "Do you have a Custom Data Layer named 'dialogue_id'?"
					# If it returns -1, the layer DOES NOT exist on this TileSet.
					if hit_tile_set and hit_tile_set.get_custom_data_layer_by_name("dialogue_id") != -1:
						# 4. Fetch the custom data
						var dialogue_id = tile_data.get_custom_data("dialogue_id")
						
						# THE GUARD: Ensure it's not null, it IS a string, and it's not empty!
						if dialogue_id != null and typeof(dialogue_id) == TYPE_STRING and dialogue_id.strip_edges() != "":
							var audio = get_node_or_null("/root/AudioManager")
							if audio and audio.has_method("play_dialogue_interact"):
								audio.play_dialogue_interact()
							print("Reading sign: ", dialogue_id)
							_trigger_dialogue(dialogue_id)
						else:
							# Optional: Helpful debug print to see what you actually hit
							print("Hit a tile, but no valid dialogue_id found.")

# Helper function to keep things clean
func _trigger_dialogue(dialogue_id: String) -> void:
	GameManager.change_state(GameManager.GameState.DIALOGUE)
	
	# Load your dialogue file
	var dialogue_file = preload("res://dialogues/signs.dialogue")
	DialogueManager.show_example_dialogue_balloon(dialogue_file, dialogue_id)
	
	await DialogueManager.dialogue_ended
	GameManager.change_state(GameManager.GameState.EXPLORATION)

func _physics_process(delta: float) -> void:
	# 1. OBEY THE FSM
	if GameManager.current_state != GameManager.GameState.EXPLORATION:
		#anim.play("idle_" + current_direction)
		return

	# 2. GRID MOVEMENT EXECUTION
	if is_moving:
		global_position = global_position.move_toward(target_position, SPEED * delta)

		if global_position == target_position:
			is_moving = false
			_take_step_in_grass()

			# Already in motion — redirect instantly if a key is still held.
			# No turn gate here, so navigating corners never stutters.
			if GameManager.current_state == GameManager.GameState.EXPLORATION:
				_continue_or_stop()

	elif is_turning:
		# Only reached from a dead stop. Hold the turn pose briefly so a
		# quick tap-and-release reads as "just turn", not "start walking".
		turn_time_left -= delta
		if turn_time_left <= 0.0:
			is_turning = false
			_continue_or_stop()

	else:
		_handle_grid_input()

func _get_input_direction() -> Array:
	# Returns [Vector2 motion_dir, String dir_name] for the highest-priority
	# key currently held, or [] if nothing is pressed.
	for entry in INPUT_DIRECTIONS:
		if Input.is_action_pressed(entry[0]):
			return [entry[2], entry[1]]
	return []

func _handle_grid_input() -> void:
	# Only called when the player was already standing still.
	var result := _get_input_direction()

	if result.is_empty():
		anim.play("idle_" + current_direction)
		return

	var dir_name: String = result[1]

	if dir_name != current_direction:
		# Fresh direction from idle — turn first, gated briefly.
		current_direction = dir_name
		ray_cast.target_position = result[0] * TILE_SIZE # <--- RAYCAST UPDATE
		is_turning = true
		turn_time_left = TURN_TIME
		anim.play("turn_" + current_direction)
		return

	# Already facing this way — no turn needed, just try to step.
	_try_step(result[0])

func _continue_or_stop() -> void:
	# Called the instant a tile-step finishes, or the instant the turn gate
	# elapses. Whatever direction is held right now (even a brand new one)
	# is taken immediately — this is what makes turning corners mid-walk free.
	var result := _get_input_direction()

	if result.is_empty():
		anim.play("idle_" + current_direction)
		return

	current_direction = result[1]
	ray_cast.target_position = result[0] * TILE_SIZE # <--- RAYCAST UPDATE
	_try_step(result[0])

func _try_step(input_dir: Vector2) -> void:
	var motion: Vector2 = input_dir * TILE_SIZE

	# test_move checks if the target tile has a physics collision (like a wall)
	if not test_move(global_transform, motion):
		target_position = global_position + motion
		is_moving = true
		anim.play("walk_" + current_direction)
	else:
		anim.play("idle_" + current_direction)

func _take_step_in_grass() -> void:
	if in_tall_grass:
		# If all glitches in this area are eliminated but items are still needed, ensure reminder modal is shown
		if not GameManager.is_battle_active() and GameManager.current_state == GameManager.GameState.EXPLORATION:
			var active_quest = QuestManager.get_current_active_quest()
			if active_quest and active_quest.required_kills > 0 and active_quest.required_items > 0:
				if active_quest.current_kills >= active_quest.required_kills and active_quest.current_items < active_quest.required_items:
					if not active_quest.get_meta("glitches_cleared_notif_shown", false):
						active_quest.set_meta("glitches_cleared_notif_shown", true)
						var title = "ALPHA GLITCHES ELIMINATED"
						var msg = "All alpha glitches are eliminated in this area, please find the items needed to proceed, you may find it as you go further in the grass."
						GameManager.show_modal_notification(title, msg)
						return

		var encounter_triggered = GameManager.check_for_encounter()

		if encounter_triggered:
			_trigger_encounter_sequence()

func _trigger_encounter_sequence() -> void:
	# 1. Freeze player movement and inputs instantly
	is_moving = false
	is_turning = false
	anim.play("idle_" + current_direction)
	GameManager.change_state(GameManager.GameState.DEBUGGING)
	
	# 2. Play alert encounter sound
	var audio = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("play_battle_encounter"):
		audio.play_battle_encounter()
		
	# 3. Show HUD toast notification
	var ui_node = get_node_or_null("UI")
	if ui_node and ui_node.has_method("show_notification"):
		ui_node.show_notification("⚠️ ALPHA GLITCH DETECTED!", 1.2)
		
	# 4. Display animated exclamation mark above the player's head
	var alert_badge = _spawn_exclamation_badge()
	
	# 5. Brief dramatic pause (anticipation before battle)
	await get_tree().create_timer(0.65).timeout
	
	if is_instance_valid(alert_badge):
		alert_badge.queue_free()
		
	# 6. SPAWN THE BATTLE UI
	var battle = BATTLE_SCENE.instantiate()
	get_tree().root.add_child(battle)
	
	# Wait for battle to finish and fully exit tree before triggering deferred modals
	await battle.tree_exited
	await get_tree().process_frame
	GameManager.check_pending_modal()

func _spawn_exclamation_badge() -> Node2D:
	var container = Node2D.new()
	container.name = "EncounterAlertBadge"
	container.position = Vector2(8, -14)
	container.z_index = 20 # Render above all tiles and tall grass
	
	# Bubble background panel
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	style.border_color = Color(0.1, 0.1, 0.1, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.text = "!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1, 1.0))
	label.add_theme_font_size_override("font_size", 16)
	if ResourceLoader.exists("res://assets/fonts/pokemon-emerald.otf"):
		label.add_theme_font_override("font", load("res://assets/fonts/pokemon-emerald.otf"))
		
	panel.add_child(label)
	
	panel.custom_minimum_size = Vector2(14, 16)
	panel.position = Vector2(-7, -16)
	container.add_child(panel)
	
	var pointer = ColorRect.new()
	pointer.color = Color(0.1, 0.1, 0.1, 1.0)
	pointer.custom_minimum_size = Vector2(2, 2)
	pointer.position = Vector2(-1, 0)
	container.add_child(pointer)
	
	# Pop-in bounce animation
	container.scale = Vector2(0.1, 0.1)
	add_child(container)
	
	var tween = create_tween()
	tween.tween_property(container, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.08)
	tween.parallel().tween_property(container, "position:y", -16.0, 0.08)
	
	return container

# ==========================================
# GRASS SCENE COLLECTION LOGIC
# ==========================================
func add_grass_overlap() -> void:
	grass_overlap_count += 1
	in_tall_grass = (grass_overlap_count > 0)

func remove_grass_overlap() -> void:
	grass_overlap_count -= 1
	in_tall_grass = (grass_overlap_count > 0)


func teleport(new_position: Vector2) -> void:
	# 1. Snap the new position to the grid just to be 100% safe
	new_position = new_position.snapped(Vector2(TILE_SIZE, TILE_SIZE))
	
	# 2. Instantly move the player
	global_position = new_position
	
	# 3. Update the target_position so the grid math doesn't pull us back
	target_position = new_position
	
	# 4. Stop any lingering movement logic
	is_moving = false
	
	print("Teleported to: ", global_position)

# Pushes the player back one tile (used by blocking NPCs)
func push_back() -> void:
	# Raycast target_position is conveniently the exact vector of our last step!
	var backward_step = -ray_cast.target_position 
	var bounce_pos = global_position + backward_step
	
	# Use your existing teleport logic to safely snap back to the previous tile
	teleport(bounce_pos)

func force_idle() -> void:
	# 1. Snap them to their destination so they don't freeze between tiles
	#global_position = target_position 
	#is_moving = false
	#is_turning = false
	
	# 2. Force the idle animation to play
	if anim:
		anim.play("idle_" + current_direction)
