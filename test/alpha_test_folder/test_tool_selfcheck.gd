# Test script for tool self-check
# This file was created by Alpha Godot Agent to test write_file tool functionality

class_name TestToolSelfCheck
extends Node

# Member variables for testing
var test_string: String = "Hello from Alpha test"
var test_number: int = 42
var test_array: Array = ["test", "data", "here"]

# Simple function to test script functionality
func get_test_message(include_array: bool = false) -> String:
	var message = "Tool self-check successful! Test number: %d" % test_number
	if include_array:
		message += " Array: " + str(test_array)
	return message

# Ready function for initialization
func _ready() -> void:
	print("Test script loaded successfully")
	print(get_test_message())
