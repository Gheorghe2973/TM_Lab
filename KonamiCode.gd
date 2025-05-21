extends Node

# Konami Code sequence: Up, Up, Down, Down, Left, Right, Left, Right, B, A
const KONAMI_CODE = [
	KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_B, KEY_A
]

# To track user input
var input_sequence = []
var eye_spawned = false
var eye_instance = null

# Reference to the Eye of Cthulhu scene
var eye_scene = preload("res://ctulhu.tscn")

func _ready():
	# Initialize
	set_process_input(true)
	randomize()

func _input(event):
	if event is InputEventKey and event.pressed:
		# Record the pressed key
		input_sequence.append(event.keycode)
		
		# Keep only the most recent inputs matching the Konami code length
		if input_sequence.size() > KONAMI_CODE.size():
			input_sequence.pop_front()
		
		# Check if the Konami code was entered
		if input_sequence == KONAMI_CODE:
			print("Konami Code activated!")
			spawn_eye_of_cthulhu()
			
			# Reset the sequence after successful activation
			input_sequence.clear()

func spawn_eye_of_cthulhu():
	# Only spawn one eye at a time
	if eye_spawned:
		return
	
	# Create instance of Eye of Cthulhu
	eye_instance = eye_scene.instantiate()
	
	# Add to the scene tree at a high level to avoid interfering with the simulation
	# This uses get_tree().root to add the eye directly to the root
	get_tree().root.add_child(eye_instance)
	
	# Position it randomly on screen
	var viewport_size = get_viewport().get_visible_rect().size
	eye_instance.position = Vector2(
		randf_range(100, viewport_size.x - 100),
		randf_range(100, viewport_size.y - 100)
	)
	
	eye_spawned = true
	
	# Make eye wander for a while then disappear
	var timer = get_tree().create_timer(30.0)  # 30 seconds of wandering
	timer.timeout.connect(_on_eye_timer_timeout)

func _on_eye_timer_timeout():
	if eye_instance != null:
		eye_instance.queue_free()
		eye_instance = null
		eye_spawned = false
