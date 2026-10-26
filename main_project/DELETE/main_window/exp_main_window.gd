extends Panel

@export var forms: Dictionary[String, Mesh]
@export var node_meshes: Array[MeshInstance3D]

@onready var grid_container: GridContainer = %GridContainer

func _ready() -> void:
	for mesh_name in forms.keys():
		create_button(mesh_name);

func create_button(mesh_name: String) -> void:
	var btn: Button = Button.new();
	btn.text = mesh_name;
	btn.custom_minimum_size = Vector2(200, 60);
	btn.pressed.connect(_set_meshes.bind(forms[mesh_name]))
	grid_container.add_child(btn);

func _set_meshes(mesh: Mesh) -> void:
	for mesh_node in node_meshes:
		mesh_node.mesh = mesh;
