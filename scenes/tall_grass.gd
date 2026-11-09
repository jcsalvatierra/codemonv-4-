extends Area2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	# Make sure it defaults to idle and normal rendering when it spawns
	anim.play("idle")
	anim.z_index = 0

# Called when the player steps INTO the grass
func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		# NEW: Tell the player they are in the grass!
		if body.has_method("add_grass_overlap"):
			body.add_grass_overlap()
		# 1. Start a tiny delay (0.1s) before the grass reacts. 
		# (Keeps it feeling responsive but not overly instantaneous)
		await get_tree().create_timer(0.3).timeout
		
		# 2. SAFEGUARD: Check if the player is STILL in the grass after the delay!
		# If they sprinted through it super fast, we don't want it to randomly rustle behind them.
		if overlaps_body(body):
			anim.play("stepped")
			
			# z_index overrides Y-sorting. Setting it to 1 guarantees 
			# this specific grass tile renders ON TOP of the player!
			anim.z_index = 1

# Called when the player steps OUT of the grass
func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		# 1. Start a 0.3 second delay timer to let the grass settle naturally
		# NEW: Tell the player they left this grass tile!
		if body.has_method("remove_grass_overlap"):
			body.remove_grass_overlap()
		
		# 2. SAFEGUARD: Check if the player is truly gone and didn't step back in
		if not overlaps_body(body):
			
			anim.z_index = 0
			await get_tree().create_timer(0.1).timeout
			anim.play("idle")
			
			# Reset the z-index back to 0 so it behaves normally again
			
