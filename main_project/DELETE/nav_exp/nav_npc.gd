extends CharacterBody3D

@export var target_node: Node3D
@export var nav_reg: NavigationRegion3D;
@export_range(1.0, 100.0, 0.1) var speed = 0.1;

@onready var navigation_agent_3d: NavigationAgent3D = %NavigationAgent3D

func _physics_process(delta: float) -> void:
	navigation_agent_3d.target_position = target_node.global_position
	_move_to(delta, _get_target_pos(target_node));
	move_and_slide();

func _move_to(delta: float, target_pos: Vector3) -> void:
	global_position += (target_pos - global_position) * delta * speed;

func _get_target_pos(target: Node3D) -> Vector3:
	return navigation_agent_3d.get_next_path_position()
