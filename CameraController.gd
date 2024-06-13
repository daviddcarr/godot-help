extends Node3D

const RAY_LENGTH = 1000

@onready var camera = $Smoothcam/Camera3D


# ---------------------- #
# Process & Interaction
# ---------------------- #
func _physics_process(delta):
	_interact()	

	
func _interact():
	if GameManager.current_mode != Types.GameModes.IDLE:
		# Check game mode and act accordingly
		match GameManager.current_mode:
			Types.GameModes.BUILD:
				# send position to GridObjects
				Events.player_is_interacting.emit(fire_ray_with_mask([3]))
					# snap to grid
					# show preview object
					# place object on click
				pass
			Types.GameModes.PAINT:
				Events.player_is_interacting.emit(fire_ray_with_mask([6]))
				# Detect object hit and apply current material
				pass
			Types.GameModes.MANAGE:
				# Detect NPCs & Manageable objects clicked on
				# Show management UI
				pass
		pass

	
	
# ---------------------- #
# Helper Functions
# ---------------------- #
func fire_ray_with_mask(mask_array: Array[int]) -> Dictionary:
	var space_state = get_world_3d().direct_space_state
	var mousepos = get_viewport().get_mouse_position()
	
	var origin = camera.project_ray_origin(mousepos)
	var end = origin + camera.project_ray_normal(mousepos) * RAY_LENGTH
	
	# Might need to move this into match statement to filter what needs
	# to be interacted with
	var collision_mask = Globals.get_layer_mask(mask_array)
	var query = PhysicsRayQueryParameters3D.create(origin,end,collision_mask)
	query.collide_with_areas = true

	return space_state.intersect_ray(query)
