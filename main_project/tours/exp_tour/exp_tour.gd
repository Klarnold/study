@tool
extends GDTour

const NODES_PATH := "test_experiment_2d/nodes";
const GOBOT := ToursPreloads.gobot;

func _build() -> void:
	set_command_context(CommandContext.TOUR_RESET)
	editor_reset_state(
		func reset_editor_state_for_tour():
			var view_options_menu: PopupMenu = EditorInterfaceAccess.get_node(EditorNodePoints.NODE_3D_EDITOR_MAIN_TOOLBAR_VIEW_OPTIONS_BUTTON).get_popup();
			Utils.activate_menu_option_by_shortcut(view_options_menu, "canvas_item_editor/pan_view");
	)

	set_command_context(CommandContext.WELCOME_BOOKEND);
	steps_welcome();
	set_command_context(CommandContext.TOUR_STEP);
	make_steps();
	set_command_context(CommandContext.FINALE_BOOKEND);
	steps_finale();

func steps_welcome() -> void:
	bubble_set_bookend_title(atr("NIMBER"));
	bubble_set_bookend_button_text(atr("[img=256x256]res://icon.svg[/img]"));
	bubble_add_bookend_text([
		"[center]" + atr("Zip zopa")
	], Bubble.BookendTextStyle.KEY)

	queue_command(func() -> void: print("QUAZAAAAR"));

func make_steps() -> void:
	var layout_root: Control = EditorInterfaceAccess.get_node(EditorNodePoints.LAYOUT_ROOT);
	var canvas_item_editor: Control = EditorInterfaceAccess.get_node(EditorNodePoints.CANVAS_ITEM_EDITOR);
	context_set("2D");
	scene_open("res://experiments/test_experiment_2d.tscn");
	bubble_set_title(atr("Angels are gone"));
	bubble_add_text(
		[
			atr("void is not when empty."),
			atr("void is then when empty is you"),
		]
	)
	complete_step();

	bubble_set_title(atr("cogem amanai"));
	bubble_add_text(
		[
			atr("roses are red"),
			atr("sky is blue"),
			atr("sugar is sweet"),
			atr("and so are you"),
		]
	)
	bubble_add_task(
		atr("Create god [b]3 times[/b]"),
		3,
		func add_nodes(_task: Task) -> int:
			var node: Node = get_scene_node_by_path(NODES_PATH);
			#print(get_scene_node_by_path("test_experiment_2d"))
			if node == null: return 2;
			var nodes_count: int = node.get_child_count();
			return nodes_count;
	)
	highlight_editor_nodes([EditorNodePoints.CANVAS_ITEM_EDITOR]);
	scene_select_nodes_by_path([NODES_PATH]);
	complete_step();
	
	bubble_set_title(atr("that's it folks"));
	bubble_add_text([atr("cogem amanai")])
	print()
	var node_paths: Array[String] = [NODES_PATH];
	for child in get_scene_node_by_path(NODES_PATH).get_children():
		print(get_scene_node_by_path(NODES_PATH).owner.name)
		node_paths.append(get_scene_node_by_path(NODES_PATH).owner.name + "/" + str(get_scene_node_by_path(NODES_PATH).owner.get_path_to(child, true)));
	highlight_scene_nodes_by_path(node_paths);
	print(node_paths)
	highlight_editor_nodes([EditorNodePoints.INSPECTOR_DOCK, EditorNodePoints.NODE_3D_EDITOR]);
	context_set_3d();
	complete_step();




func steps_finale() -> void:
	bubble_set_bookend_title(atr("void is all that left"));

	bubble_add_bookend_text([
		"[center]" + atr("probably this is this") + "[/center]", "[center]" + atr("and that is that") + "[/center]"
	], Bubble.BookendTextStyle.KEY);
