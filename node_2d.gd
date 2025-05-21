extends Node2D

func _ready():
	# Connect all the element buttons with debug prints
	$Control/VBoxContainer/Sand.pressed.connect(func(): 
		print("Selected Sand")
		$Simulation.current_element = $Simulation.Element.SAND)
	$Control/VBoxContainer2/Clean.pressed.connect(func(): 
		print("Clearing grid")
		$Simulation.clear_grid())
		
	$Control/VBoxContainer/Water.pressed.connect(func(): 
		print("Selected Water")
		$Simulation.current_element = $Simulation.Element.WATER)
		
	$Control/VBoxContainer/Wall.pressed.connect(func(): 
		print("Selected Wall")
		$Simulation.current_element = $Simulation.Element.WALL)
		
	$Control/VBoxContainer/Fire.pressed.connect(func(): 
		print("Selected Fire")
		$Simulation.current_element = $Simulation.Element.FIRE)
		
	$Control/VBoxContainer/Oil.pressed.connect(func(): 
		print("Selected Oil")
		$Simulation.current_element = $Simulation.Element.OIL)
		
	$Control/VBoxContainer/Smoke.pressed.connect(func(): 
		print("Selected Smoke")
		$Simulation.current_element = $Simulation.Element.SMOKE)
		
	$Control/VBoxContainer/Plant.pressed.connect(func(): 
		print("Selected Plant")
		$Simulation.current_element = $Simulation.Element.PLANT)
		
	$Control/VBoxContainer/Ice.pressed.connect(func(): 
		print("Selected Ice")
		$Simulation.current_element = $Simulation.Element.ICE)
		
	$Control/VBoxContainer/Powder.pressed.connect(func(): 
		print("Selected Powder")
		$Simulation.current_element = $Simulation.Element.POWDER)
		
	$Control/VBoxContainer2/Clone.pressed.connect(func(): 
		print("Selected Clone")	
		$Simulation.current_element = $Simulation.Element.CLONER)
		
	$Control/VBoxContainer2/Void.pressed.connect(func(): 
		print("Selected Void")
		$Simulation.current_element = $Simulation.Element.VOID)
		
	$Control/VBoxContainer/Erase.pressed.connect(func(): 
		print("Selected Erase")
		$Simulation.current_element = $Simulation.Element.EMPTY)
	
	# Connect brush size control buttons in VBoxContainer3
	$Control/VBoxContainer3/High.pressed.connect(func(): 
		print("Brush size set to High")
		$Simulation.set_brush_size_multiplier(2.0))  # Double size
		
	$Control/VBoxContainer3/Mid.pressed.connect(func(): 
		print("Brush size set to Medium")
		$Simulation.set_brush_size_multiplier(1.0))  # Default size
		
	$Control/VBoxContainer3/Low.pressed.connect(func(): 
		print("Brush size set to Low")
		$Simulation.set_brush_size_multiplier(0.5))  # Half size
