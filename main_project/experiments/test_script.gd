@tool
extends Node3D
class_name EXPERIMENT

const SC_NAME: String = "spatial_editor/1_viewport";

@export var shortcut_name: String;
@export_tool_button("Exp Tool") var exp_btn: Callable = some_options;

func _ready() -> void:
	pass
	#some_options();

static func some_options() -> void:
	var editor_settings = EditorInterface.get_editor_settings();
	if editor_settings:
		for property in editor_settings.get_property_list():
			print(property.name);
	#print();
	var editor_shortcut: Shortcut = editor_settings.get_shortcut(SC_NAME);
	
	if editor_shortcut:
		print("BIBA")
		print(editor_shortcut.get_property_list());
