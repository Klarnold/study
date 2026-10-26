@tool
extends "res://addons/godot_tours/gdtour_metadata.gd"

func _define() -> void:
	auto_open_tour_list = true

	title = tr("Welcome to GDTours")
	subtitle = tr("Get to Know 3D")
	description.push_back("[center]" + tr("In this series of guided workshops, you take your first steps in 3D with Godot and assemble a small 3D game from parts!") + "[/center]")

	register_tour(
		"103_introduction_to_3d",
		"103",
		tr("Introduction to 3D in Godot"),
		36,
		"res://tours/103_introduction_to_3d/01_navigation_and_elements.gd",
	)
