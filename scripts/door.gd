extends Area2D

# This allows us na  iclick ung Door in the editor and pick EXACTLY 
# which Marker2D the player should teleport to!
@export var destination: Marker2D 
@onready var anim_player = $Transition/AnimationPlayer
func _on_body_entered(body: Node2D) -> void:

	if body.name == "Player":
		if destination != null:
			var audio = get_node_or_null("/root/AudioManager")
			if audio and audio.has_method("play_door_enter"):
				audio.play_door_enter()
				
			anim_player.play("fade_black")
			await anim_player.animation_finished
			# Tell the player to teleport to the marker's exact position!
			body.teleport(destination.global_position)
			
			anim_player.play("fade_in")
		else:
			print("WARNING: Door has no destination set!")
