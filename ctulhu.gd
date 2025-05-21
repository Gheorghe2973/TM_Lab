extends Node2D

# Konami Code sequence: Up, Up, Down, Down, Left, Right, Left, Right, B, A
const KONAMI_CODE = [
	KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_B, KEY_A
]

# To track user input
var input_sequence = []
var active = false

# Movement properties
var speed = 100.0
var wander_range = 150.0
var target_position = Vector2.ZERO
var rotation_speed = 2.0

# Animation properties
var pulse_speed = 3.0
var scale_min = 0.9
var scale_max = 1.1
var current_time = 0.0

# Phase properties
var phase = 1
var phase_change_timer = 0.0
var phase_change_interval = 10.0
var dash_timer = 0.0
var dash_interval = 3.0
var is_dashing = false
var dash_speed = 400.0
var dash_direction = Vector2.ZERO
var dash_duration = 0.5
var current_dash_time = 0.0

# Lifetime properties
var lifetime = 30.0
var fade_duration = 2.0
var is_fading = false
var fade_timer = 0.0

func _ready():
	# Start hidden
	visible = false
	set_process(false)
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
	if active:
		return
		
	# Position randomly on screen
	var viewport_size = get_viewport().get_visible_rect().size
	position = Vector2(
		randf_range(100, viewport_size.x - 100),
		randf_range(100, viewport_size.y - 100)
	)
	
	# Set a random target
	_get_new_target()
	
	# Add a subtle rotation
	rotation = randf_range(0, TAU)
	
	# Make visible and start processing
	visible = true
	active = true
	set_process(true)
	
	# Start the self-destruct timer
	var timer = get_tree().create_timer(lifetime - fade_duration)
	timer.timeout.connect(_start_fade_out)

func _process(delta):
	current_time += delta
	
	# Check if we're in fade-out mode
	if is_fading:
		_handle_fade_out(delta)
		return
	
	# Handle phase changes
	phase_change_timer += delta
	if phase_change_timer >= phase_change_interval:
		phase_change_timer = 0
		phase = 2 if phase == 1 else 1
		
		# Reset dash timer when entering phase 2
		if phase == 2:
			dash_timer = 0
	
	# Handle movement based on current phase
	if phase == 1:
		_handle_wander_movement(delta)
	else:  # phase 2
		_handle_aggressive_movement(delta)
	
	# Pulse animation (scale up and down)
	var pulse_factor = sin(current_time * pulse_speed) * 0.5 + 0.5
	var current_scale = lerp(scale_min, scale_max, pulse_factor)
	scale = Vector2(current_scale, current_scale)
	
	# Rotate the eye
	rotation += rotation_speed * delta

func _handle_wander_movement(delta):
	# Move toward target position
	var direction = target_position - position
	
	if direction.length() < 10:
		# Reached target, get a new one
		_get_new_target()
	else:
		# Move toward target
		position += direction.normalized() * speed * delta

func _handle_aggressive_movement(delta):
	if is_dashing:
		# Handle dash movement
		position += dash_direction * dash_speed * delta
		current_dash_time += delta
		
		if current_dash_time >= dash_duration:
			is_dashing = false
			# Get a new target after dashing
			_get_new_target()
	else:
		# Normal movement between dashes
		_handle_wander_movement(delta)
		
		# Check if it's time to dash
		dash_timer += delta
		if dash_timer >= dash_interval:
			dash_timer = 0
			_start_dash()

func _start_dash():
	is_dashing = true
	current_dash_time = 0
	
	# Get screen center or player position for targeting
	var viewport_size = get_viewport().get_visible_rect().size
	var center = viewport_size / 2
	
	# Dash toward the center or a random direction
	if randf() > 0.3:
		dash_direction = (center - position).normalized()
	else:
		dash_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func _get_new_target():
	# Create a new random target within the wander range
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Keep the eye on screen
	target_position = Vector2(
		clamp(randf_range(position.x - wander_range, position.x + wander_range), 50, viewport_size.x - 50),
		clamp(randf_range(position.y - wander_range, position.y + wander_range), 50, viewport_size.y - 50)
	)

# Start the fade out process
func _start_fade_out():
	is_fading = true
	fade_timer = 0.0

# Handle fading out and destruction
func _handle_fade_out(delta):
	fade_timer += delta
	
	if fade_timer >= fade_duration:
		# Time to reset
		visible = false
		active = false
		is_fading = false
		phase = 1
		phase_change_timer = 0
		set_process(false)
		modulate.a = 1.0  # Reset alpha
	else:
		# Gradually fade out
		var alpha = 1.0 - (fade_timer / fade_duration)
		modulate.a = alpha
		
		# Also slow down movement as it fades
		speed = speed * 0.98
		rotation_speed = rotation_speed * 0.98
