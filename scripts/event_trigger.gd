extends Area2D

const TILE_SIZE: float = 16.0

@export_group("Dialogue Settings")
@export var dialogue_id: String = "intro_dialogue"

# Link the actor in the Inspector
@export var npc_node: Node2D
var NPC_SPEED: float = 200.0 

@export_group("Cinematic Settings")
@export_enum("player_first", "npc_first", "simultaneous") var movement_order: String = "player_first"

@export_group("Player Movement (Optional)")
@export var player_entrance_markers: Array[Marker2D] 
@export_enum("x_first", "y_first") var player_path_order: String = "x_first"
@export_enum("up", "down", "left", "right", "none") var player_face_after: String = "up"
@export var player_exit_markers: Array[Marker2D] 
@export_enum("x_first", "y_first") var player_exit_path_order: String = "x_first"
@export_enum("up", "down", "left", "right", "none") var player_face_after_exit: String = "none"

@export_group("NPC Entrance Settings")
@export var npc_name: String = "npc_1"
@export var entrance_markers: Array[Marker2D] 
@export_enum("x_first", "y_first") var enter_path_order: String = "x_first"

@export_group("NPC Exit Settings")
@export var exit_markers: Array[Marker2D]
@export_enum("x_first", "y_first") var exit_path_order: String = "x_first"
@export_enum("up", "down", "left", "right", "none") var face_after_exit: String = "none"
@export var despawn_after_exit: bool = false

@export_group("Micro-Event Tracking")
@export var requires_event_to_appear: String = ""
@export var disappears_on_event: String = ""
@export var event_to_trigger_on_finish: String = ""
# NEW: Pinpoint exactly WHEN the event fires!
@export_enum("after_battle", "after_exit", "after_everything") var event_trigger_timing: String = "after_everything"
@export var play_only_once: bool = true 

@export_group("Quest Settings (Optional)")
@export var quest_to_give: QuestData

@export_group("Combat Settings (Optional)")
@export var triggers_battle: bool = false
@export var is_sudden_death: bool = false 
@export var battle_scene_path: String = "res://scenes/battle_scene.tscn"
@export_enum("battle_then_exit", "exit_then_battle") var combat_timing: String = "battle_then_exit"
@export var post_battle_dialogue_id: String = ""

var has_triggered: bool = false

func _ready() -> void:
	NPC_SPEED = GameManager.CHARACTERS_SPEED
	# Snap ALL markers to the grid
	var all_markers = entrance_markers + exit_markers + player_entrance_markers + player_exit_markers
	for marker in all_markers:
		if marker:
			marker.global_position = marker.global_position.snapped(Vector2(TILE_SIZE, TILE_SIZE))
			
	_check_if_expired()

func _process(delta: float) -> void:
	if not has_triggered:
		_check_if_expired()

func _check_if_expired() -> void:
	var should_expire = false
	
	if disappears_on_event != "":
		if GameManager.completed_events.has(disappears_on_event):
			should_expire = true
	else:
		if play_only_once and event_to_trigger_on_finish != "" and GameManager.completed_events.has(event_to_trigger_on_finish):
			should_expire = true
		
	if should_expire:
		if is_instance_valid(npc_node) and despawn_after_exit:
			npc_node.queue_free()
		set_process(false)
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and not has_triggered:
		await get_tree().create_timer(0.25).timeout
		
		# 1. Prerequisites
		if requires_event_to_appear != "" and not GameManager.completed_events.has(requires_event_to_appear): return 
		if play_only_once and event_to_trigger_on_finish != "" and GameManager.completed_events.has(event_to_trigger_on_finish): return 
		
		has_triggered = true
		
		if body.has_method("force_idle"):
			body.force_idle()
		
		GameManager.change_state(GameManager.GameState.DIALOGUE)
		
		# 2. CINEMATIC ENTRANCES
		if movement_order == "player_first":
			await _execute_player_walk(body, player_entrance_markers, player_path_order, player_face_after)
			await _execute_npc_walk(body, entrance_markers, enter_path_order, true)
		elif movement_order == "npc_first":
			await _execute_npc_walk(body, entrance_markers, enter_path_order, true)
			await _execute_player_walk(body, player_entrance_markers, player_path_order, player_face_after)
		else: 
			_execute_player_walk(body, player_entrance_markers, player_path_order, player_face_after) 
			await _execute_npc_walk(body, entrance_markers, enter_path_order, true) 
			await get_tree().create_timer(0.2).timeout 
		
		# 3. Pre-Battle Dialogue
		var dialogue_file = preload("res://dialogues/events.dialogue")
		if dialogue_id != "":
			DialogueManager.show_example_dialogue_balloon(dialogue_file, dialogue_id)
			await DialogueManager.dialogue_ended
		
		# 4. Give Quest
		if quest_to_give != null:
			QuestManager.accept_quest(quest_to_give)
			
		# 5. BATTLE FORK (If Battle First)
		if triggers_battle and combat_timing == "battle_then_exit":
			var won = await _run_battle_sequence(dialogue_file)
			if GameManager.current_state == GameManager.GameState.GAME_OVER: return # Stop cutscene if player died!
			if won:
				_try_complete_event("after_battle")
			else:
				has_triggered = false # Reset so they can try again
				return
			
		# 6. EXITS
		# NPC Exit
		if is_instance_valid(npc_node) and exit_markers.size() > 0:
			var npc_sprite = npc_node.get_node_or_null("AnimatedSprite2D")
			for marker in exit_markers:
				if marker:
					await _walk_grid_path(npc_node, marker, npc_sprite, exit_path_order, false)
			if npc_sprite and face_after_exit != "none":
				_play_anim(npc_sprite, "idle", face_after_exit, false)
			if despawn_after_exit and is_instance_valid(npc_node):
				npc_node.queue_free()
				
		# Player Exit
		if player_exit_markers.size() > 0:
			await _execute_player_walk(body, player_exit_markers, player_exit_path_order, player_face_after_exit)
			
		_try_complete_event("after_exit")
			
		# 7. BATTLE FORK (If Exit First)
		if triggers_battle and combat_timing == "exit_then_battle":
			var won = await _run_battle_sequence(dialogue_file)
			if GameManager.current_state == GameManager.GameState.GAME_OVER: return
			if won:
				_try_complete_event("after_battle")
			else:
				has_triggered = false
				return
		
		# 8. Mark Event Complete (Fallback for after_everything)
		_try_complete_event("after_everything") # <--- CHECK 4
		
		# If this was the finale cutscene, transition to victory!
		if dialogue_id == "finale" or event_to_trigger_on_finish == "game_finished":
			GameManager.complete_event("game_finished")
			
		# 9. Return to Exploration
		if GameManager.current_state != GameManager.GameState.GAME_OVER and GameManager.current_state != GameManager.GameState.VICTORY:
			GameManager.change_state(GameManager.GameState.EXPLORATION)
			
		_check_if_expired()

# --- NEW: TIMING CHECKER ---
func _try_complete_event(timing_checkpoint: String) -> void:
	if event_to_trigger_on_finish == "":
		return
		
	# Only fire if the current checkpoint matches the designer's choice!
	if event_trigger_timing == timing_checkpoint:
		if not GameManager.completed_events.has(event_to_trigger_on_finish):
			GameManager.complete_event(event_to_trigger_on_finish)

# --- COMBAT HELPER ---
func _run_battle_sequence(dialogue_file) -> bool:
	GameManager.change_state(GameManager.GameState.DEBUGGING)
	var battle_scene = load(battle_scene_path)
	var win_state = [false]
	if battle_scene:
		var battle_instance = battle_scene.instantiate()
		
		battle_instance.reward_event = "" 
		battle_instance.is_sudden_death = is_sudden_death
		get_tree().root.add_child(battle_instance)
		
		var on_win = func(): win_state[0] = true
		if battle_instance.has_signal("battle_won"):
			battle_instance.battle_won.connect(on_win)
		
		# 🛑 PAUSE SCRIPT UNTIL BATTLE IS OVER
		await battle_instance.tree_exited 
		
		if win_state[0]:
			GameManager.change_state(GameManager.GameState.DIALOGUE)
			
			if post_battle_dialogue_id != "":
				DialogueManager.show_example_dialogue_balloon(dialogue_file, post_battle_dialogue_id)
				await DialogueManager.dialogue_ended
				
	return win_state[0]

# --- CINEMATIC WALK HELPERS ---
func _execute_player_walk(body: Node2D, markers: Array[Marker2D], p_order: String, face: String) -> void:
	var player_sprite: AnimatedSprite2D = body.get_node_or_null("AnimatedSprite2D")
	if markers.size() > 0:
		for marker in markers:
			if marker:
				await _walk_grid_path(body, marker, player_sprite, p_order, true)
		if player_sprite and face != "none":
			_play_anim(player_sprite, "idle", face, true)
			
			if "current_direction" in body:
				body.current_direction = face
func _execute_npc_walk(body: Node2D, markers: Array[Marker2D], p_order: String, face_player: bool) -> void:
	if not is_instance_valid(npc_node): return
	var npc_sprite = npc_node.get_node_or_null("AnimatedSprite2D")
	if markers.size() > 0:
		for marker in markers:
			if marker:
				await _walk_grid_path(npc_node, marker, npc_sprite, p_order, false)
		if npc_sprite and face_player:
			var face_dir = _get_facing_direction(npc_node.global_position, body.global_position)
			_play_anim(npc_sprite, "idle", face_dir, false)

# ==========================================
# HELPER FUNCTIONS: THE GRID PATHFINDER
# ==========================================
func _play_anim(sprite: AnimatedSprite2D, state: String, dir: String, is_player: bool) -> void:
	if not sprite: return
	if is_player:
		sprite.play("%s_%s" % [state, dir]) 
	else:
		sprite.play("%s_%s_%s" % [npc_name, state, dir]) 

func _walk_grid_path(character: Node2D, target: Marker2D, sprite: AnimatedSprite2D, order: String, is_player: bool) -> void:
	var start_pos = character.global_position
	var end_pos = target.global_position
	var diff_x = end_pos.x - start_pos.x
	var diff_y = end_pos.y - start_pos.y
	
	if order == "x_first":
		await _move_axis(character, sprite, "x", end_pos.x, diff_x, is_player)
		await _move_axis(character, sprite, "y", end_pos.y, diff_y, is_player)
	else:
		await _move_axis(character, sprite, "y", end_pos.y, diff_y, is_player)
		await _move_axis(character, sprite, "x", end_pos.x, diff_x, is_player)

func _move_axis(character: Node2D, sprite: AnimatedSprite2D, axis: String, target_val: float, diff: float, is_player: bool) -> void:
	if abs(diff) < 1.0: return 
		
	
	var dir_str = ""
	if axis == "x":
		dir_str = "right" if diff > 0 else "left"
	else:
		dir_str = "down" if diff > 0 else "up"
		
	_play_anim(sprite, "walk", dir_str, is_player)
	
	# 🧠 Player Brain Sync (Keeps player facing correct way mid-walk)
	if is_player and "current_direction" in character:
		character.current_direction = dir_str
		
	if not is_inside_tree() or not get_tree(): return
	var tween = get_tree().create_tween()
	var duration = abs(diff) / NPC_SPEED
	
	if axis == "x": 
		tween.tween_property(character, "global_position:x", target_val, duration)
	else: 
		tween.tween_property(character, "global_position:y", target_val, duration)
		
	await tween.finished

func _get_facing_direction(from_pos: Vector2, to_pos: Vector2) -> String:
	var diff = to_pos - from_pos
	if abs(diff.x) > abs(diff.y): return "right" if diff.x > 0 else "left"
	else: return "down" if diff.y > 0 else "up"
