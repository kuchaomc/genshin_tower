# Test script for tab indentation
# This script demonstrates proper tab indentation in GDScript

class_name TestTabIndentation
extends Node

# Member variables with proper indentation
var player_name: String = "TestPlayer"
var player_score: int = 0
var is_active: bool = true

# Constant with indentation
const MAX_SCORE: int = 1000

# Function with proper tab indentation
func _ready() -> void:
	# Single tab indentation for function body
	print("Test script loaded")
	
	# Call test function
	_test_indentation()
	
	# Test conditional with proper indentation
	if is_active:
		# Two tabs indentation for conditional body
		print("Player is active")
		
		# Nested conditional
		if player_score > 0:
			# Three tabs indentation
			print("Player has score: ", player_score)
		else:
			print("Player has no score")
	else:
		print("Player is not active")
	
	# Test loop with proper indentation
	for i in range(5):
		# Two tabs for loop body
		print("Iteration: ", i)
		
		# Nested loop
		for j in range(3):
			# Three tabs for nested loop body
			print("  Nested: ", j)

# Another function with proper indentation
func _test_indentation() -> void:
	# Test match statement indentation
	var value: int = 2
	
	match value:
		1:
			# Two tabs for match case body
			print("Value is 1")
		2:
			print("Value is 2")
			# Nested conditional in match case
			if player_name == "TestPlayer":
				print("Test player detected")
		_:
			print("Other value")

	# Test function with parameters and return value
	var result: int = _calculate_score(5, 3)
	print("Calculated score: ", result)

# Function with parameters
func _calculate_score(base: int, multiplier: int) -> int:
	# Calculate and return
	var final_score: int = base * multiplier
	
	# Test early return with indentation
	if final_score > MAX_SCORE:
		return MAX_SCORE
	
	return final_score

# Signal definitions
signal test_completed
signal score_updated(new_score: int)

# Function that emits signals
func _update_score() -> void:
	player_score += 100
	score_updated.emit(player_score)
	
	if player_score >= MAX_SCORE:
		test_completed.emit()