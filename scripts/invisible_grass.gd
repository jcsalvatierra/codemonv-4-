extends TileMapLayer

@onready var required_event = "start_pre_boss"

func _ready() -> void:
	visible = false
	GameManager.checkpoint_saved.connect(_on_checkpoint_updated)
	_on_checkpoint_updated("")

func _on_checkpoint_updated(_cp_name: String) -> void:
	if GameManager.completed_events.has(required_event):
		enabled = true
	else:
		enabled = false
