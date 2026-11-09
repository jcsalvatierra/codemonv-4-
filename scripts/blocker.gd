extends StaticBody2D

@export_group("Pure Micro-Event Tracking")
# If set, the blocker will ONLY appear kung san the event has happened.
# Leave empty if you want it to appear by default.
@export var requires_event_to_appear: String = ""

# If set, the blocker will instantly disappear when this event happens.
@export var disappears_on_event: String = ""

func _ready() -> void:
	_check_state()

func _process(delta: float) -> void:
	_check_state()

func _check_state() -> void:
	var should_delete = false
	
	# 1. If it requires an event to appear, but that event hasn't happened yet -> DELETE
	if requires_event_to_appear != "" and not GameManager.completed_events.has(requires_event_to_appear):
		should_delete = true
		
	# 2. If it is supposed to disappear upon an event, and that event HAS happened -> DELETE
	if disappears_on_event != "" and GameManager.completed_events.has(disappears_on_event):
		should_delete = true
	
	if should_delete:
		set_process(false) 
		queue_free()
