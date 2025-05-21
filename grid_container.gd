extends Node2D

# Grid properties
var grid_width = 160
var grid_height = 130
var cell_size = 5
var cloner_pulse = 0.0
# Element types - updated with new elements and STEAM
enum Element {EMPTY, SAND, WATER, WALL, FIRE, OIL, SMOKE, PLANT, ICE, POWDER, CLONER, VOID, STEAM}
# The grid will store our elements
var grid = []
var current_element = Element.SAND
var brush_size = 3

# Add to the top of your Simulation script with other variables
var brush_size_multiplier = 1.0  # Default multiplier for brush size
var base_brush_size = 3  # Default brush size

# Add this function to set the brush size multiplier
func set_brush_size_multiplier(value):
	brush_size_multiplier = value
	brush_size = int(base_brush_size * brush_size_multiplier)
	brush_size = max(1, brush_size)  # Ensure minimum size of 1
	print("Brush size set to: ", brush_size)
# Add this as a class variable at the top of your Simulation script
var density_multiplier = 1.0  # Default multiplier for quantity
var base_density = {
	Element.WATER: 0.95,
	Element.OIL: 0.9,
	Element.POWDER: 0.85,
	Element.ICE: 0.8,
	Element.SAND: 0.75,
	Element.SMOKE: 0.7,
	Element.FIRE: 0.8,
	Element.PLANT: 0.7,
	Element.CLONER: 1.0,
	Element.VOID: 1.0,
	Element.WALL: 1.0,
	Element.EMPTY: 1.0,
	Element.STEAM: 0.65,  # Steam is lighter than smoke
}

# Add this function to set the quantity multiplier
func set_quantity_multiplier(value):
	density_multiplier = clamp(value, 0.2, 3.0)  # Limit between 20% to 300%
	print("Quantity multiplier set to: ", density_multiplier)
	
# Element colors - added new colors for steam
var colors = {
	Element.EMPTY: Color(0, 0, 0, 0),
	Element.SAND: Color(0.76, 0.7, 0.5),
	Element.WATER: Color(0.3, 0.5, 0.8, 0.75),
	Element.WALL: Color(0.5, 0.5, 0.5),
	Element.FIRE: Color(0.9, 0.3, 0.1, 0.85),
	Element.OIL: Color(0.4, 0.2, 0.1, 0.8),
	Element.SMOKE: Color(0.7, 0.7, 0.7, 0.4),
	Element.PLANT: Color(0.3, 0.7, 0.4),
	Element.ICE: Color(0.8, 0.95, 1.0, 0.8),  # Light blue for ice
	Element.POWDER: Color(0.9, 0.6, 0.2, 0.9), # Orange-yellow for powder
	Element.CLONER: Color(0.2, 0.9, 0.2, 0.9), # Bright green for cloner
	Element.VOID: Color(0.1, 0.1, 0.1, 0.9),   # Very dark gray for void
	Element.STEAM: Color(0.9, 0.9, 0.9, 0.5)   # Whiter and more transparent than smoke
}

# Optimization variables
var active_cells = []
var updated_this_frame = {}
var processing_active = true

# Performance optimization
var max_updates_per_frame = 3000  # Increased for smoother simulation
var current_frame = 0
var update_frequency = 1

# Fluid dynamics parameters - enhanced for more fluid behavior
var water_diffusion_chance = 0.95   # Increased for more fluid water
var oil_diffusion_chance = 0.85     # Adjusted for oil
var smoke_diffusion_chance = 0.8    # For smoke
var fire_diffusion_chance = 0.5     # For fire movement
var steam_diffusion_chance = 0.9    # Steam moves faster than smoke

# Maximum flow distances
var water_flow_distance = 5  # Water flows faster horizontally
var oil_flow_distance = 4    # Oil flows a bit slower

# New parameters for ice and powder
var ice_melt_chance = 0.001   # Normal melting rate (very slow)
var ice_fire_melt_chance = 0.2 # Fast melting near fire
var powder_explosion_radius = 5  # How big the explosion is
var powder_explosion_chance = 0.9 # Probability of exploding when touching fire

# Water evaporation parameters
var water_evaporation_chance = 0.15  # Chance for water to evaporate when heated
var steam_condensation_chance = 0.005  # Chance for steam to condense back to water
var steam_lifetime = 300  # How long steam exists before possibly turning into water (in frames)

func _ready():
	# Initialize the grid with empty cells
	for y in range(grid_height):
		var row = []
		for x in range(grid_width):
			row.append(Element.EMPTY)
		grid.append(row)
	
	# For testing, add some initial elements
	for x in range(40, 120):
		grid[80][x] = Element.WALL

func _process(_delta):
	current_frame += 1
	
	# Make cloner blocks pulsate
	cloner_pulse += _delta * 2.0
	colors[Element.CLONER] = Color(0.2, 0.7 + 0.3 * sin(cloner_pulse), 0.2, 0.9)
	
	# Only update every update_frequency frames
	if processing_active and current_frame % update_frequency == 0:
		update_simulation()
		queue_redraw()

func _draw():
	# Draw each cell in the grid
	for y in range(grid_height):
		for x in range(grid_width):
			var element = grid[y][x]
			if element != Element.EMPTY:
				var rect = Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
				draw_rect(rect, colors[element])

func _input(event):
	if event is InputEventMouseButton or (event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		# Get the mouse position and convert to grid coordinates
		var mouse_pos = get_local_mouse_position()
		var grid_x = int(mouse_pos.x / cell_size)
		var grid_y = int(mouse_pos.y / cell_size)
		
		# Ensure we're within grid bounds
		if grid_x < 0 or grid_x >= grid_width or grid_y < 0 or grid_y >= grid_height:
			return
			
		# Place elements with enhanced brush size for liquids and powders
		var actual_brush_size = brush_size
		if current_element == Element.WATER or current_element == Element.OIL:
			actual_brush_size += 2  # Larger brush for liquids
		elif current_element == Element.POWDER or current_element == Element.ICE:
			actual_brush_size += 1  # Slightly larger for powder and ice
			
		# Add a debug print to verify the brush size
		print("Using brush size: ", actual_brush_size)
		
		for by in range(-actual_brush_size + 1, actual_brush_size):
			for bx in range(-actual_brush_size + 1, actual_brush_size):
				# Calculate distance from center for circular brush
				var distance = sqrt(bx*bx + by*by)
				if distance > actual_brush_size:
					continue  # Skip if outside the circular brush radius
				
				var place_x = grid_x + bx
				var place_y = grid_y + by
				
				# Ensure we're within grid bounds
				if place_x >= 0 and place_x < grid_width and place_y >= 0 and place_y < grid_height:
					# Place element with some randomness based on element type
					var place_chance = 1.0
					if current_element == Element.WATER or current_element == Element.OIL:
						place_chance = 0.9  # 90% chance for liquids
					elif current_element == Element.POWDER:
						place_chance = 0.85  # 85% chance for powder
						
					if randf() < place_chance:
						grid[place_y][place_x] = current_element
						# Add placed cell and neighbors to active cells list
						add_cell_to_active(place_x, place_y)

# Helper function to add a cell and its neighbors to the active cells list
func add_cell_to_active(x, y):
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx = x + dx
			var ny = y + dy
			var new_pos = Vector2(nx, ny)
			if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
				if not active_cells.has(new_pos):
					active_cells.append(new_pos)

# Called from UI buttons
func set_current_element(element):
	# Convert the element string to the enum value
	match element:
		"SAND":
			current_element = Element.SAND
		"WATER":
			current_element = Element.WATER
		"WALL":
			current_element = Element.WALL
		"FIRE":
			current_element = Element.FIRE
		"OIL":
			current_element = Element.OIL
		"SMOKE":
			current_element = Element.SMOKE
		"PLANT":
			current_element = Element.PLANT
		"ICE":
			current_element = Element.ICE
		"POWDER":
			current_element = Element.POWDER
		"STEAM":
			current_element = Element.STEAM
		_:
			# Default to SAND if unknown element
			current_element = Element.SAND

func set_brush_size(size):
	brush_size = size

func toggle_processing():
	processing_active = !processing_active

func update_simulation():
	updated_this_frame.clear()
	
	# Ensure we have active cells
	if active_cells.size() < 10:
		for _i in range(10):
			var rx = randi() % grid_width
			var ry = randi() % grid_height
			if grid[ry][rx] != Element.EMPTY:
				active_cells.append(Vector2(rx, ry))
	
	# Process only a limited number of cells per frame for better performance
	var cells_to_process = min(active_cells.size(), max_updates_per_frame)
	var new_active_cells = []
	
	# Process a subset of active cells
	for i in range(cells_to_process):
		if active_cells.size() == 0:
			break
			
		var pos_index = randi() % active_cells.size()
		var pos = active_cells[pos_index]
		active_cells.remove_at(pos_index)
		
		var x = int(pos.x)
		var y = int(pos.y)
		
		# Skip if already updated this frame or out of bounds
		var pos_key = str(x) + "," + str(y)
		if updated_this_frame.has(pos_key) or x < 0 or x >= grid_width or y < 0 or y >= grid_height:
			continue
			
		var element = grid[y][x]
		var moved = false
		
		match element:
			Element.SAND:
				moved = update_sand(x, y)
			Element.WATER:
				moved = update_water(x, y)
			Element.FIRE:
				moved = update_fire(x, y)
			Element.OIL:
				moved = update_oil(x, y)
			Element.SMOKE:
				moved = update_smoke(x, y)
			Element.PLANT:
				moved = update_plant(x, y)
			Element.ICE:
				moved = update_ice(x, y)
			Element.POWDER:
				moved = update_powder(x, y)
			Element.CLONER:
				moved = update_cloner(x, y)
			Element.VOID:
				moved = update_void(x, y)
			Element.STEAM:
				moved = update_steam(x, y)
				
		# Mark as updated
		updated_this_frame[pos_key] = true
		
		# If the element moved or was updated, track surrounding cells
		if moved:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx = x + dx
					var ny = y + dy
					var new_pos = Vector2(nx, ny)
					if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
						if not new_active_cells.has(new_pos):
							new_active_cells.append(new_pos)
	
	# Add remaining unprocessed cells back to the active_cells
	active_cells.append_array(new_active_cells)
	
	# If we have too many active cells, randomly remove some to maintain performance
	if active_cells.size() > max_updates_per_frame * 2:
		active_cells.shuffle()
		active_cells.resize(max_updates_per_frame)
		
	# Liquid accumulation pass - helps prevent disappearing bottom layers
	if current_frame % 5 == 0:  # Only run every 5 frames for performance
		for x in range(grid_width):
			var bottom_y = grid_height - 1
			# If the bottom cell is empty but there are liquid cells above, move them down
			if grid[bottom_y][x] == Element.EMPTY:
				# Look up the column for the first liquid
				for y in range(bottom_y - 1, -1, -1):
					if grid[y][x] == Element.WATER or grid[y][x] == Element.OIL:
						# Move the liquid down
						grid[bottom_y][x] = grid[y][x]
						grid[y][x] = Element.EMPTY
						active_cells.append(Vector2(x, bottom_y))
						break

func update_sand(x, y):
	# Sand behavior is already good, just keeping it efficient
	if y < grid_height - 1:
		if grid[y + 1][x] == Element.EMPTY:
			grid[y][x] = Element.EMPTY
			grid[y + 1][x] = Element.SAND
			return true
		
		# Check diagonals
		var dirs = [1, -1]
		dirs.shuffle()
		
		for dir in dirs:
			var new_x = x + dir
			if new_x >= 0 and new_x < grid_width and grid[y + 1][new_x] == Element.EMPTY:
				grid[y][x] = Element.EMPTY
				grid[y + 1][new_x] = Element.SAND
				return true
		
		# Displace liquids
		if grid[y + 1][x] == Element.WATER or grid[y + 1][x] == Element.OIL:
			var liquid = grid[y + 1][x]
			grid[y + 1][x] = Element.SAND
			grid[y][x] = liquid
			return true
	
	return false

func update_water(x, y):
	# Check for heat sources below the water to cause evaporation
	if y < grid_height - 1:
		var heat_below = false
		
		# Check if there's fire, wall with fire nearby, or hot sand below
		if grid[y + 1][x] == Element.FIRE:
			heat_below = true
		elif grid[y + 1][x] == Element.WALL:
			# Check if the wall has fire adjacent to it
			for dy in range(0, 2):  # Check below and at the wall's level
				for dx in range(-1, 2):
					var nx = x + dx
					var ny = y + 1 + dy
					if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
						if grid[ny][nx] == Element.FIRE:
							heat_below = true
							break
				if heat_below:
					break
		elif grid[y + 1][x] == Element.SAND:
			# Check if the sand has fire adjacent to it (hot sand)
			for dy in range(0, 2):
				for dx in range(-1, 2):
					var nx = x + dx
					var ny = y + 1 + dy
					if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
						if grid[ny][nx] == Element.FIRE:
							heat_below = true
							break
				if heat_below:
					break
		
		# If there's heat below, the water has a chance to evaporate
		if heat_below and randf() < water_evaporation_chance:
			grid[y][x] = Element.STEAM
			return true
	
	
	# Sometimes create extra water droplets for more pixels
	if randf() < 0.001:  # Rare chance
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nx = x + dx
				var ny = y + dy
				if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
					if grid[ny][nx] == Element.EMPTY:
						grid[ny][nx] = Element.WATER
						return true
	
	# Check if at the bottom of the grid - water should accumulate and not disappear
	if y == grid_height - 1:
		# At the bottom, only try horizontal movement
		var dirs = [1, -1]
		dirs.shuffle()
		
		for dir in dirs:
			var new_x = x + dir
			if new_x >= 0 and new_x < grid_width and grid[y][new_x] == Element.EMPTY:
				# Move horizontally with high probability to create pooling effect
				if randf() < 0.9:
					grid[y][x] = Element.EMPTY
					grid[y][new_x] = Element.WATER
					return true
		
		# If can't move, just stay where it is
		return false
	
	# Check if can fall straight down first
	if y < grid_height - 1:
		if grid[y + 1][x] == Element.EMPTY:
			grid[y][x] = Element.EMPTY
			grid[y + 1][x] = Element.WATER
			return true
		
		# Check if there's an obstacle below - if so, try to accumulate
		if grid[y + 1][x] != Element.EMPTY and grid[y + 1][x] != Element.WATER:
			# Try to spread horizontally with high probability
			var dirs = [1, -1]
			dirs.shuffle()
			
			for dir in dirs:
				var new_x = x + dir
				if new_x >= 0 and new_x < grid_width and grid[y][new_x] == Element.EMPTY:
					grid[y][x] = Element.EMPTY
					grid[y][new_x] = Element.WATER
					return true
		
		# Check diagonals for falling
		var dirs = [1, -1]
		dirs.shuffle()
		
		for dir in dirs:
			var new_x = x + dir
			if new_x >= 0 and new_x < grid_width and grid[y + 1][new_x] == Element.EMPTY:
				grid[y][x] = Element.EMPTY
				grid[y + 1][new_x] = Element.WATER
				return true
	
	# Constant movement simulation - check for any empty spaces around
	var movement_dirs = [
		[1, 0], [-1, 0],  # Left and right
		[1, -1], [-1, -1],  # Diagonal up
		[0, -1]  # Up (for bubbling effect)
	]
	movement_dirs.shuffle()
	
	# Try to always move if possible - creates constant fluid motion
	for dir in movement_dirs:
		var new_x = x + dir[0]
		var new_y = y + dir[1]
		
		if new_x >= 0 and new_x < grid_width and new_y >= 0 and new_y < grid_height:
			if grid[new_y][new_x] == Element.EMPTY:
				# Higher probability of horizontal movement for more fluid look
				var move_prob = 0.95 if dir[1] == 0 else 0.3
				if randf() < move_prob:
					grid[y][x] = Element.EMPTY
					grid[new_y][new_x] = Element.WATER
					return true
	
	# Water layering - check if there's water above
	if y > 0 and grid[y-1][x] == Element.WATER:
		# If there's water above, current water has a small chance to move
		# This helps create a more stable bottom layer
		if randf() < 0.1:
			var dirs = [1, -1]
			dirs.shuffle()
			
			for dir in dirs:
				var new_x = x + dir
				if new_x >= 0 and new_x < grid_width and grid[y][new_x] == Element.EMPTY:
					grid[y][x] = Element.EMPTY
					grid[y][new_x] = Element.WATER
					return true
	
	# Extinguish fire
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
				if grid[ny][nx] == Element.FIRE:
					grid[ny][nx] = Element.STEAM  # Changed from SMOKE to STEAM
					return true
					
	# Water melts ice on contact
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
				if grid[ny][nx] == Element.ICE and randf() < 0.01:
					grid[ny][nx] = Element.WATER
					return true
	
	return false

func update_oil(x, y):
	# Check for heat sources below the oil to cause it to catch fire
	if y < grid_height - 1:
		var heat_below = false
		
		# Check if there's fire below or near the oil
		for dy in range(0, 2):  # Check below
			for dx in range(-1, 2):
				var nx = x + dx
				var ny = y + dy
				if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
					if grid[ny][nx] == Element.FIRE:
						heat_below = true
						break
			if heat_below:
				break
		
		# If there's heat below, the oil has a high chance to catch fire
		if heat_below and randf() < 0.3:  # Higher chance than water evaporation
			grid[y][x] = Element.FIRE
			return true
	
	
	# Sometimes create extra oil droplets for more pixels
	if randf() < 0.0005:  # Very rare chance (less than water)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nx = x + dx
				var ny = y + dy
				if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
					if grid[ny][nx] == Element.EMPTY:
						grid[ny][nx] = Element.OIL
						return true
	
	# Check if at the bottom of the grid - oil should accumulate and not disappear
	if y == grid_height - 1:
		# At the bottom, only try horizontal movement
		var dirs = [1, -1]
		dirs.shuffle()
		
		for dir in dirs:
			var new_x = x + dir
			if new_x >= 0 and new_x < grid_width and grid[y][new_x] == Element.EMPTY:
				# Move horizontally with high probability to create pooling effect
				if randf() < 0.8:  # Slightly less than water due to higher viscosity
					grid[y][x] = Element.EMPTY
					grid[y][new_x] = Element.OIL
					return true
		
		# If can't move, just stay where it is
		return false
	
	# Check if can fall straight down first
	if y < grid_height - 1:
		if grid[y + 1][x] == Element.EMPTY:
			grid[y][x] = Element.EMPTY
			grid[y + 1][x] = Element.OIL
			return true
			
		# Check if there's an obstacle below - if so, try to accumulate
		if grid[y + 1][x] != Element.EMPTY and grid[y + 1][x] != Element.OIL:
			# Try to spread horizontally with high probability
			var dirs = [1, -1]
			dirs.shuffle()
			
			for dir in dirs:
				var new_x = x + dir
				if new_x >= 0 and new_x < grid_width and grid[y][new_x] == Element.EMPTY:
					grid[y][x] = Element.EMPTY
					grid[y][new_x] = Element.OIL
					return true
		
		# Check diagonals for falling
		var dirs = [1, -1]
		dirs.shuffle()
		
		for dir in dirs:
			var new_x = x + dir
			if new_x >= 0 and new_x < grid_width and grid[y + 1][new_x] == Element.EMPTY:
				grid[y][x] = Element.EMPTY
				grid[y + 1][new_x] = Element.OIL
				return true
	
	# Constant movement simulation - similar to water but with different parameters
	var movement_dirs = [
		[1, 0], [-1, 0],  # Left and right
		[1, -1], [-1, -1],  # Diagonal up
		[0, -1]  # Up (bubbling, but less than water)
	]
	movement_dirs.shuffle()
	
	# Oil is more viscous than water, but still tries to move if possible
	for dir in movement_dirs:
		var new_x = x + dir[0]
		var new_y = y + dir[1]
		
		if new_x >= 0 and new_x < grid_width and new_y >= 0 and new_y < grid_height:
			if grid[new_y][new_x] == Element.EMPTY:
				# Lower probabilities than water due to higher viscosity
				var move_prob = 0.85 if dir[1] == 0 else 0.2
				if randf() < move_prob:
					grid[y][x] = Element.EMPTY
					grid[new_y][new_x] = Element.OIL
					return true
	
	# Oil layering - check if there's oil above
	if y > 0 and grid[y-1][x] == Element.OIL:
		# If there's oil above, current oil has a smaller chance to move
		# This helps create a more stable bottom layer
		if randf() < 0.08:  # Less than water
			var dirs = [1, -1]
			dirs.shuffle()
			
			for dir in dirs:
				var new_x = x + dir
				if new_x >= 0 and new_x < grid_width and grid[y][new_x] == Element.EMPTY:
					grid[y][x] = Element.EMPTY
					grid[y][new_x] = Element.OIL
					return true
	
	# Check if oil touches fire, if so, catch fire
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
				if grid[ny][nx] == Element.FIRE:
					grid[y][x] = Element.FIRE
					return true
	
	return false

func update_fire(x, y):
	# Modified fire behavior to move more like smoke but slower
	
	# Fire has a chance to rise as smoke or steam depending on surroundings
	if randf() < 0.1:
		# Check if there was water nearby that's being evaporated
		var water_nearby = false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nx = x + dx
				var ny = y + dy
				if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
					if grid[ny][nx] == Element.WATER:
						water_nearby = true
						break
			if water_nearby:
				break
		
		# If water was nearby, produce steam, otherwise produce smoke
		if water_nearby:
			grid[y][x] = Element.STEAM
		else:
			grid[y][x] = Element.SMOKE
		return true
	
	# Fire can now move upward like smoke, but with less probability
	if y > 0 and randf() < fire_diffusion_chance * 0.4:  # Lower chance than smoke
		if grid[y - 1][x] == Element.EMPTY:
			grid[y][x] = Element.EMPTY
			grid[y - 1][x] = Element.FIRE
			return true
		
		# Fire can also move diagonally upward
		var dirs = [1, -1]
		dirs.shuffle()
		
		for dir in dirs:
			var new_x = x + dir
			if new_x >= 0 and new_x < grid_width and y > 0 and grid[y - 1][new_x] == Element.EMPTY:
				grid[y][x] = Element.EMPTY
				grid[y - 1][new_x] = Element.FIRE
				return true
	
	
	# Fire can also spread sideways like smoke
	if randf() < fire_diffusion_chance * 0.3:
		var dir = 1 if randf() < 0.5 else -1
		var new_x = x + dir
		
		if new_x >= 0 and new_x < grid_width and grid[y][new_x] == Element.EMPTY:
			grid[y][x] = Element.EMPTY
			grid[y][new_x] = Element.FIRE
			return true
	
	# Fire spreads to flammable neighbors
	# Fire spreads to flammable neighbors
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
				if grid[ny][nx] == Element.OIL:
					if randf() < 0.4:
						grid[ny][nx] = Element.FIRE
						return true
				elif grid[ny][nx] == Element.PLANT:
					if randf() < 0.3:
						grid[ny][nx] = Element.FIRE
						return true
				# Powder can explode when touching fire
				elif grid[ny][nx] == Element.POWDER:
					if randf() < powder_explosion_chance:
						create_explosion(nx, ny, powder_explosion_radius)
						return true
				# Ice melts faster when touching fire
				elif grid[ny][nx] == Element.ICE:
					if randf() < ice_fire_melt_chance:
						grid[ny][nx] = Element.WATER
						return true
				# Water evaporates into steam when touching fire
				elif grid[ny][nx] == Element.WATER:
					if randf() < water_evaporation_chance * 2:  # Higher chance when directly touching
						grid[ny][nx] = Element.STEAM
						return true
	
	# Fire has a chance to burn out
	if randf() < 0.04:
		grid[y][x] = Element.EMPTY
		return true
	
	return false
# Add this function to your Simulation.gd script
func clear_grid():
	# Reset the grid to all empty cells
	for y in range(grid_height):
		for x in range(grid_width):
			grid[y][x] = Element.EMPTY
	
	# Clear active cells list
	active_cells.clear()
	
	# Force a redraw
	queue_redraw()
	
	print("Grid cleared")
func update_smoke(x, y):
	# Smoke behavior - already good, just making it more consistent
	
	# Smoke rises up
	if y > 0 and grid[y - 1][x] == Element.EMPTY:
		grid[y][x] = Element.EMPTY
		grid[y - 1][x] = Element.SMOKE
		return true
	
	# Smoke can also rise diagonally
	if y > 0 and randf() < 0.5:
		var dirs = [1, -1]
		dirs.shuffle()
		
		for dir in dirs:
			var new_x = x + dir
			if new_x >= 0 and new_x < grid_width and grid[y - 1][new_x] == Element.EMPTY:
				grid[y][x] = Element.EMPTY
				grid[y - 1][new_x] = Element.SMOKE
				return true
	
	# Smoke can drift sideways
	if randf() < smoke_diffusion_chance:
		var dir = 1 if randf() < 0.5 else -1
		var drift_dist = 1 + int(randf() * 2)  # Can drift 1-2 cells
		var new_x = x + (dir * drift_dist)
		
		if new_x >= 0 and new_x < grid_width and grid[y][new_x] == Element.EMPTY:
			grid[y][x] = Element.EMPTY
			grid[y][new_x] = Element.SMOKE
			return true
	
	# Smoke has a chance to dissipate
	if randf() < 0.025:
		grid[y][x] = Element.EMPTY
		return true
	
	return false

# New function to handle steam behavior
func update_steam(x, y):
	# Steam rises faster than smoke
	if y > 0 and grid[y - 1][x] == Element.EMPTY:
		grid[y][x] = Element.EMPTY
		grid[y - 1][x] = Element.STEAM
		return true
	
	# Steam can rise diagonally with higher probability than smoke
	if y > 0 and randf() < 0.7:  # Higher than smoke
		var dirs = [1, -1]
		dirs.shuffle()
		
		for dir in dirs:
			var new_x = x + dir
			if new_x >= 0 and new_x < grid_width and grid[y - 1][new_x] == Element.EMPTY:
				grid[y][x] = Element.EMPTY
				grid[y - 1][new_x] = Element.STEAM
				return true
	
	# Steam can drift sideways more than smoke
	if randf() < steam_diffusion_chance:
		var dir = 1 if randf() < 0.5 else -1
		var drift_dist = 1 + int(randf() * 3)  # Can drift 1-3 cells
		var new_x = x + (dir * drift_dist)
		
		if new_x >= 0 and new_x < grid_width and grid[y][new_x] == Element.EMPTY:
			grid[y][x] = Element.EMPTY
			grid[y][new_x] = Element.STEAM
			return true
	
	# Steam condensation - can turn back into water when it cools
	# More likely to condense when near cold elements or at top of screen
	var condensation_modifier = 1.0
	
	# Higher chance to condense at the top of the screen
	if y < grid_height * 0.2:  # Top 20% of screen
		condensation_modifier *= 2.0
	
	# Check for cold elements nearby (ice, water)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
				if grid[ny][nx] == Element.ICE:
					condensation_modifier *= 3.0  # Much higher chance near ice
				elif grid[ny][nx] == Element.WATER:
					condensation_modifier *= 1.5  # Higher chance near water
	
	# Apply condensation chance with modifiers
	if randf() < steam_condensation_chance * condensation_modifier:
		# Steam condenses into water droplet
		grid[y][x] = Element.WATER
		return true
	
	# Steam has a chance to dissipate (slightly less than smoke)
	if randf() < 0.02:
		grid[y][x] = Element.EMPTY
		return true
	
	return false

func update_plant(x, y):
	# Plant behavior remains the same
	if randf() < 0.01:
		var grow_dirs = [[0, -1], [1, 0], [-1, 0]]
		grow_dirs.shuffle()
		
		for dir in grow_dirs:
			var nx = x + dir[0]
			var ny = y + dir[1]
			if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height and grid[ny][nx] == Element.EMPTY:
				grid[ny][nx] = Element.PLANT
				return true
	
	# Check for water nearby
	var has_water_nearby = false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
				if grid[ny][nx] == Element.WATER:
					has_water_nearby = true
					break
		if has_water_nearby:
			break
	
	# Plants can die if no water nearby
	if not has_water_nearby and randf() < 0.0005:
		grid[y][x] = Element.EMPTY
		return true
	
	return false

# New functions for ice and powder

func update_ice(x, y):
	# Ice is static but can melt
	
	# Check if touching fire (fast melt)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
				if grid[ny][nx] == Element.FIRE:
					# Fast melt near fire
					if randf() < ice_fire_melt_chance:
						grid[y][x] = Element.WATER
						return true
	
	# Chance to freeze surrounding water
	if randf() < 0.01:  # Low chance
		var water_found = false
		var water_positions = []
		
		# Check for water nearby
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nx = x + dx
				var ny = y + dy
				if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
					if grid[ny][nx] == Element.WATER:
						water_found = true
						water_positions.append(Vector2(nx, ny))
		
		# Chance to freeze a random water cell
		if water_found and randf() < 0.2:  # 20% chance if water found
			var random_index = randi() % water_positions.size()
			var water_pos = water_positions[random_index]
			grid[water_pos.y][water_pos.x] = Element.ICE
			return true
	
	# Natural melting over time (very slow)
	if randf() < ice_melt_chance:
		grid[y][x] = Element.WATER
		return true
	
	return false

func update_powder(x, y):
	# Powder behaves similar to sand but can explode
	
	# Normal sand-like falling behavior
	if y < grid_height - 1:
		if grid[y + 1][x] == Element.EMPTY:
			grid[y][x] = Element.EMPTY
			grid[y + 1][x] = Element.POWDER
			return true
		
		# Check diagonals for falling
		var dirs = [1, -1]
		dirs.shuffle()
		
		for dir in dirs:
			var new_x = x + dir
			if new_x >= 0 and new_x < grid_width and grid[y + 1][new_x] == Element.EMPTY:
				grid[y][x] = Element.EMPTY
				grid[y + 1][new_x] = Element.POWDER
				return true
	
	# Check if touching fire - explode!
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
				if grid[ny][nx] == Element.FIRE:
					if randf() < powder_explosion_chance:
						create_explosion(x, y, powder_explosion_radius)
						return true
	
	return false

# Helper function to create an explosion
func create_explosion(center_x, center_y, radius):
	# Remove powder at epicenter
	grid[center_y][center_x] = Element.EMPTY
	
	# Create fire and force in the explosion radius
	for y in range(center_y - radius, center_y + radius + 1):
		for x in range(center_x - radius, center_x + radius + 1):
			if x >= 0 and x < grid_width and y >= 0 and y < grid_height:
				# Calculate distance from center
				var distance = sqrt(pow(x - center_x, 2) + pow(y - center_y, 2))
				
				if distance <= radius:
					# Elements at the center become fire
					if distance < radius / 2:
						if grid[y][x] != Element.WALL:
							grid[y][x] = Element.FIRE
					# Elements further out are affected by the force
					elif grid[y][x] != Element.EMPTY and grid[y][x] != Element.WALL:
						# Calculate direction from center
						var dir_x = x - center_x
						var dir_y = y - center_y
						
						# Normalize direction
						var length = sqrt(dir_x * dir_x + dir_y * dir_y)
						if length > 0:
							dir_x = dir_x / length
							dir_y = dir_y / length
						
						# Calculate force based on distance
						var force = (radius - distance) / radius
						
						# Calculate new position
						var new_x = x + int(dir_x * force * 3)
						var new_y = y + int(dir_y * force * 3)
						
						# Ensure new position is within grid
						if new_x >= 0 and new_x < grid_width and new_y >= 0 and new_y < grid_height:
							if grid[new_y][new_x] == Element.EMPTY:
								# Move the element to the new position
								grid[new_y][new_x] = grid[y][x]
								grid[y][x] = Element.EMPTY
								# Add to active cells
								active_cells.append(Vector2(new_x, new_y))
					
					# Add smoke or steam at the edges of the explosion
					elif distance > radius * 0.7 and distance <= radius and grid[y][x] == Element.EMPTY:
						if randf() < 0.4:
							# Check if there was water nearby that's being evaporated
							var water_nearby = false
							for dy in range(-2, 3):
								for dx in range(-2, 3):
									var nx = x + dx
									var ny = y + dy
									if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
										if grid[ny][nx] == Element.WATER:
											water_nearby = true
											break
								if water_nearby:
									break
							
							# If water was nearby, produce steam, otherwise produce smoke
							if water_nearby:
								grid[y][x] = Element.STEAM
							else:
								grid[y][x] = Element.SMOKE
							active_cells.append(Vector2(x, y))
				
				# Make sure all cells in the blast radius are marked as active
				active_cells.append(Vector2(x, y))
	
	# Create some additional fire particles
	var fire_count = int(radius * 1.5)
	for _i in range(fire_count):
		var angle = randf() * 2 * PI
		var distance = randf() * radius
		
		var fx = int(center_x + cos(angle) * distance)
		var fy = int(center_y + sin(angle) * distance)
		
		if fx >= 0 and fx < grid_width and fy >= 0 and fy < grid_height and grid[fy][fx] == Element.EMPTY:
			grid[fy][fx] = Element.FIRE
			active_cells.append(Vector2(fx, fy))
			
	# Create some debris (powder) flung further out
	var debris_count = int(radius * 2)
	for _i in range(debris_count):
		var angle = randf() * 2 * PI
		var distance = radius + randf() * radius  # Beyond the explosion radius
		
		var dx = int(center_x + cos(angle) * distance)
		var dy = int(center_y + sin(angle) * distance)
		
		if dx >= 0 and dx < grid_width and dy >= 0 and dy < grid_height and grid[dy][dx] == Element.EMPTY:
			if randf() < 0.5:
				grid[dy][dx] = Element.POWDER
			else:
				grid[dy][dx] = Element.SMOKE
			active_cells.append(Vector2(dx, dy))
			
# In the update_void function, add this after erasing elements
func update_void(x, y):
	# Void erases any element that touches it (except WALL, CLONER, and VOID)
	var erased_something = false
	
	# Check surrounding cells
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue  # Skip self
				
			var nx = x + dx
			var ny = y + dy
			
			if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
				# If there's an element next to the void that can be erased
				if grid[ny][nx] != Element.EMPTY and grid[ny][nx] != Element.WALL and grid[ny][nx] != Element.CLONER and grid[ny][nx] != Element.VOID:
					# Erase it
					grid[ny][nx] = Element.EMPTY
					active_cells.append(Vector2(nx, ny))
					erased_something = true
	
	# Gravitational pull effect - check in a larger radius
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			if abs(dx) <= 1 and abs(dy) <= 1:
				continue  # Skip immediate neighbors (already handled)
				
			var distance = sqrt(dx*dx + dy*dy)
			if distance > 3:
				continue  # Skip if too far
				
			var nx = x + dx
			var ny = y + dy
			
			if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
				# If there's a movable element that can be pulled
				if (grid[ny][nx] == Element.SAND or grid[ny][nx] == Element.WATER or 
					grid[ny][nx] == Element.OIL or grid[ny][nx] == Element.SMOKE or
					grid[ny][nx] == Element.POWDER or grid[ny][nx] == Element.STEAM):  # Added STEAM to movable elements
					
					# Calculate direction towards void
					var dir_x = -1 if dx > 0 else 1 if dx < 0 else 0
					var dir_y = -1 if dy > 0 else 1 if dy < 0 else 0
					
					# Try to move element towards void
					var new_x = nx + dir_x
					var new_y = ny + dir_y
					
					if new_x >= 0 and new_x < grid_width and new_y >= 0 and new_y < grid_height:
						if grid[new_y][new_x] == Element.EMPTY:
							# Pull element towards void with probability based on distance
							if randf() < 0.8 / distance:
								grid[new_y][new_x] = grid[ny][nx]
								grid[ny][nx] = Element.EMPTY
								active_cells.append(Vector2(new_x, new_y))
								erased_something = true
	
	return erased_something
	
	
func update_cloner(x, y):
	# Cloner is static but clones any element that touches it
	var elements_to_clone = []
	var clone_positions = []
	
	# Check surrounding cells
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue  # Skip self
				
			var nx = x + dx
			var ny = y + dy
			
			if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
				# If there's an element next to the cloner that can be cloned
				if grid[ny][nx] != Element.EMPTY and grid[ny][nx] != Element.CLONER and grid[ny][nx] != Element.VOID:
					# Remember this element for cloning
					elements_to_clone.append(grid[ny][nx])
				# Check for empty spaces to clone into
				elif grid[ny][nx] == Element.EMPTY:
					clone_positions.append(Vector2(nx, ny))
	
	# If we have elements to clone and empty positions
	if elements_to_clone.size() > 0 and clone_positions.size() > 0:
		for pos in clone_positions:
			# Pick a random element to clone
			var element_to_clone = elements_to_clone[randi() % elements_to_clone.size()]
			# Clone into the empty position
			if randf() < 0.7:  # 70% chance to clone each frame
				grid[pos.y][pos.x] = element_to_clone
				active_cells.append(pos)
		return true
	
	return false
