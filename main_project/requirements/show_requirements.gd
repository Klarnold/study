extends Control

@export var requirements: Requirements

@onready var show_requirements_lbl: RichTextLabel = %show_requirements_lbl

func _ready() -> void:
	show_requirements_lbl.text = "Required screpts: "
	for script_name in requirements.required_scripts:
		if requirements.required_scripts[script_name] == null:
			show_requirements_lbl.text += "[clr=green]- script %s\n" % script_name;
		else:
			show_requirements_lbl.text += " "
