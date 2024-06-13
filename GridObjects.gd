extends Node3D

var cursor_pos: Vector3 = Vector3.ZERO
var can_place_object: bool = false
var placed_objects = {}
var current_rotation: int = 0

# Build object vars + test object
var preview_object: Node3D = null
@export var current_object: PlaceableObject

# Paint object vars + test color
var current_paintable_object: Node3D = null
var object_original_color: Material = StandardMaterial3D.new()
@export var current_material: Material = StandardMaterial3D.new()


func _ready():
	Events.player_is_interacting.connect(process_target)
	GameManager.game_mode_changed.connect(swap_game_mode)
		
func process_target(ray_target: Dictionary) -> void:
	if "position" in ray_target:
		match GameManager.current_mode:
			Types.GameModes.BUILD:
				var rounded_pos = snap_to_grid_position(ray_target.position, current_object.type)
				if rounded_pos != cursor_pos:
					cursor_pos = rounded_pos
					check_can_place_object()
					set_preview_object(current_object)
			Types.GameModes.PAINT:
				set_preview_color(ray_target)
				pass
	else: 
		if preview_object:
			remove_preview_object()
		if current_paintable_object:
			reset_paintable_object_color()
		can_place_object = false

func set_preview_color(target: Dictionary) -> void:
	var collider = target.collider
	if collider != current_paintable_object:
		if current_paintable_object:
			reset_paintable_object_color()
			
		if collider.has_node("MeshInstance3D"):
			print(target)
			var mesh_instance = collider.get_node("MeshInstance3D")
			object_original_color = mesh_instance.mesh.material.duplicate()
			object_original_color.resource_local_to_scene = true
			print("Object Original Color: " + str(object_original_color))
			
			var material_instance = current_material.duplicate()
			material_instance.resource_local_to_scene = true
			mesh_instance.mesh.material = material_instance
	
			current_paintable_object = collider

	
func reset_paintable_object_color():
	print("Resetting to Original Color: " + str(object_original_color))
	if current_paintable_object and current_paintable_object.has_node("MeshInstance3D"):
		print("Resetting..")
		var mesh_instance = current_paintable_object.get_node("MeshInstance3D")
		mesh_instance.mesh.material = object_original_color
		current_paintable_object = null
		object_original_color = StandardMaterial3D.new()

func set_preview_object(object: PlaceableObject) -> void:
	remove_preview_object()
	if can_place_object and GameManager.current_mode != Types.GameModes.IDLE:
		match GameManager.current_mode:
			Types.GameModes.BUILD:
				preview_object = object.scene.instantiate()
				preview_object.position = cursor_pos
				preview_object.rotation_degrees.y = current_rotation
				preview_object.collision_layer = 3
				if preview_object.has_node("MeshInstance3D"):
					var mesh_instance: MeshInstance3D = preview_object.get_node("MeshInstance3D")
					var unique_material = mesh_instance.mesh.material.duplicate() as StandardMaterial3D
					unique_material.resource_local_to_scene = true
					mesh_instance.mesh.material = unique_material				
					add_child(preview_object)
		
func remove_preview_object() -> void:
	if preview_object:
		remove_child(preview_object)
		preview_object = null

func place_object(object: PlaceableObject) -> void:
	if can_place_object:
		var new_object = object.scene.instantiate()
		if object.cost <= GameManager.player_currency:
			GameManager.remove_currency(object.cost)
			new_object.position = cursor_pos
			new_object.rotation_degrees.y = current_rotation
			
			if new_object.has_node("MeshInstance3D"):
				var mesh_instance: MeshInstance3D = new_object.get_node("MeshInstance3D")
				var unique_material = mesh_instance.mesh.material.duplicate() as StandardMaterial3D
				unique_material.resource_local_to_scene = true
				mesh_instance.mesh.material = unique_material				
				add_child(new_object)
				placed_objects[cursor_pos] = new_object
			

###############################
# Probably not relevant bits: #
###############################

func _unhandled_input(event: InputEvent) -> void:
	if current_object and event is InputEventMouseButton:
		if event.button_index == 1 and event.pressed:
			if current_object:
				place_object(current_object)
		elif event.button_index == 2 and event.pressed:
			print("Right Click")
	if current_object and event is InputEventKey:
		if event.is_action_pressed("object_rotate_cw"):
			rotate_preview_object(90)
		if event.is_action_pressed("object_rotate_ccw"):
			rotate_preview_object(-90)

func swap_game_mode(game_mode: Types.GameModes) -> void:
	if preview_object:
		remove_preview_object()
	if current_paintable_object:
		reset_paintable_object_color()

func rotate_preview_object(degrees: int) -> void:
	current_rotation = (current_rotation + degrees) % 360
	if preview_object:
		preview_object.rotation_degrees.y = current_rotation
		
func check_can_place_object() -> void:
	can_place_object = !placed_objects.has(cursor_pos)
	if preview_object:
		preview_object.visible = can_place_object
	
func snap_to_grid_position(unsnapped_position: Vector3, object_type: Types.PlaceableObjects) -> Vector3:
	match current_object.type:
		Types.PlaceableObjects.WALL:
			var x_weight = abs((unsnapped_position.x - round(unsnapped_position.x)) - 0.5)
			var z_weight = abs((unsnapped_position.z - round(unsnapped_position.z)) - 0.5)
				
			if x_weight > z_weight:
				current_rotation = 90
				return Vector3(
					round(unsnapped_position.x),
					round(unsnapped_position.y),
					round(unsnapped_position.z + 0.5) - 0.5
				)
			else:
				current_rotation = 0
				return Vector3(
					round(unsnapped_position.x + 0.5) - 0.5,
					round(unsnapped_position.y),
					round(unsnapped_position.z)
				)
		Types.PlaceableObjects.FURNITURE:
			# Find nearest point in the center of a grid cell (0.5, 1.5) (3.5, -10.5)
			return Vector3(
				round(unsnapped_position.x + 0.5) - 0.5,
				round(unsnapped_position.y),
				round(unsnapped_position.z + 0.5) - 0.5
			)
		Types.PlaceableObjects.CORNER:
			# Keep Rounded Position (1, 1) (2, 4)
			return Vector3(
				round(unsnapped_position.x), 
				round(unsnapped_position.y), 
				round(unsnapped_position.z)
			)
		_:
			return unsnapped_position
			
func get_wall_corners(wall_position: Vector3) -> Array[Vector3]:
	return [
		Vector3(floor(wall_position.x), wall_position.y, floor(wall_position.z)),
		Vector3(ceil(wall_position.x), wall_position.y, ceil(wall_position.z))
	]
