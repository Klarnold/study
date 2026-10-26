extends Area3D
class_name InteractableZone

signal input_requested(caller: Node3D)

func _ready() -> void:
	input_requested.connect(request_input);

func request_input(caller: Node3D) -> void:
	pass
