extends Area2D

@export_group("Dialogue Settings")
@export var dialogue_id: String = "path_blocked_1"

@export_group("Pure Micro-Event Tracking")
# If this event has happened, this blocker allows the player to pass freely!
@export var disappears_on_event: String = ""

func _ready() -> void:
	_check_if_cleared()

func _process(delta: float) -> void:
	_check_if_cleared()

func _check_if_cleared() -> void:
	# If the event has happened, delete this trigger so it never stops the player again!
	if disappears_on_event != "" and GameManager.completed_events.has(disappears_on_event):
		set_process(false)
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		
		# 1. Double-check if the event has happened (just in case)
		if disappears_on_event != "" and GameManager.completed_events.has(disappears_on_event):
			return 
			
		# 2. Stop the player and show the warning dialogue!
		GameManager.change_state(GameManager.GameState.DIALOGUE)
		
		var dialogue_file = preload("res://dialogues/events.dialogue")
		DialogueManager.show_example_dialogue_balloon(dialogue_file, dialogue_id)
		
		# 3. Wait for the player to finish reading
		await DialogueManager.dialogue_ended
		
		# 4. Push them backward and return to Exploration!
		if body.has_method("push_back"):
			body.push_back()
			
		GameManager.change_state(GameManager.GameState.EXPLORATION)
