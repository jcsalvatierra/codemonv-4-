extends CharacterBody2D

const TILE_SIZE: float = 16.0 # Your grid size

@export var dialogue_id: String = "default"

@export_group("Animation Settings")
@export var npc_name: String = "npc_1"
@export_enum("idle", "walk") var default_state: String = "idle"
@export_enum("up", "down", "left", "right") var default_direction: String = "down"

@export_group("Micro-Event Tracking")
@export var requires_event_to_appear: String = ""
@export var disappears_on_event: String = ""

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")

@export_group("Quest Settings (Optional)")
@export var gives_quest: QuestData
@export var dialog_not_started: String = "merchant_intro"
@export var dialog_in_progress: String = "merchant_waiting"
@export var dialog_ready_to_finish: String = "merchant_thanks"
@export var dialog_completed: String = "merchant_post_quest"

func _ready() -> void:
	global_position = global_position.snapped(Vector2(TILE_SIZE, TILE_SIZE))
	_update_visibility_state()

func _process(delta: float) -> void:
	# Continuously check in real-time so it pops in the moment the event finishes!
	_update_visibility_state()

func _update_visibility_state() -> void:
	var should_hide = false
	
	# Rule 1: If it requires an event, but it hasn't happened yet -> HIDE
	if requires_event_to_appear != "" and not GameManager.completed_events.has(requires_event_to_appear):
		should_hide = true
		
	# Rule 2: If it should disappear after an event, and it happened -> HIDE
	if disappears_on_event != "" and GameManager.completed_events.has(disappears_on_event):
		should_hide = true
		
	if should_hide:
		hide() # Hides the sprite
		if collision_shape:
			collision_shape.disabled = true # Disables physical collision so you can't interact with a ghost
	else:
		show() # Shows the sprite
		if collision_shape:
			collision_shape.disabled = false # Enables collision
			
		# Play animation if visible
		if sprite and not sprite.is_playing():
			var anim_to_play = "%s_%s_%s" % [npc_name, default_state, default_direction]
			sprite.play(anim_to_play)

func interact() -> void:
	if not visible:
		return
		
	var dialogue_file = preload("res://dialogues/events.dialogue")
	var text_to_play = dialogue_id # Default fallback
	
	# If this NPC is a Quest Giver, dynamically choose what to say!
	if gives_quest != null:
		var q_id = gives_quest.quest_id
		
		# STATE 1: Quest hasn't been accepted yet
		if not QuestManager.active_quests.has(q_id):
			text_to_play = dialog_not_started
			
			# Start the dialogue, then secretly accept the quest in the background!
			DialogueManager.show_example_dialogue_balloon(dialogue_file, text_to_play)
			await DialogueManager.dialogue_ended
			QuestManager.accept_quest(gives_quest)
			return # Exit early so we don't play the balloon twice
			
		else:
			var active_q = QuestManager.active_quests[q_id]
			
			# STATE 2: Quest is already fully finished
			if active_q.is_completed:
				text_to_play = dialog_completed
				
			# STATE 3: Player has the items! Turn it in!
			elif active_q.are_objectives_met():
				text_to_play = dialog_ready_to_finish
				
				# Show the thank you text, then formally complete the quest!
				DialogueManager.show_example_dialogue_balloon(dialogue_file, text_to_play)
				await DialogueManager.dialogue_ended
				QuestManager.turn_in_quest(q_id)
				return 
				
			# STATE 4: Player accepted it, but doesn't have the items yet
			else:
				text_to_play = dialog_in_progress

	# Show whatever dialogue we selected (Standard or Quest-based)
	DialogueManager.show_example_dialogue_balloon(dialogue_file, text_to_play)
