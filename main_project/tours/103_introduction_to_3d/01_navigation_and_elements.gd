@tool
extends "res://addons/godot_tours/tour.gd"

const Gobot := preload("res://addons/godot_tours/bubble/gobot/gobot.gd")

const GAME_CAMERA_PATH := "Game/Camera3D"
const GAME_DIRECTIONAL_LIGHT_PATH := "Game/DirectionalLight3D"
const GAME_WORLD_ENVIRONMENT_PATH := "Game/WorldEnvironment"
const PATH_WORLD_ENVIRONMENT_TRES := "res://level/vfx/world_environment.tres"

const RESOURCES := {
	world_environment = preload(PATH_WORLD_ENVIRONMENT_TRES),
}


func _build() -> void:
	set_command_context(CommandContext.TOUR_RESET)
	editor_reset_state(
		func reset_editor_state_for_tour():
			# Reset the viewport configuration.
			var view_options_menu: PopupMenu = EditorInterfaceAccess.get_node(EditorNodePoints.NODE_3D_EDITOR_MAIN_TOOLBAR_VIEW_OPTIONS_BUTTON).get_popup()
			Utils.activate_menu_option_by_shortcut(view_options_menu, "spatial_editor/1_viewport")

			# Reset view buttons.
			var snap_button: Button = EditorInterfaceAccess.get_node(EditorNodePoints.NODE_3D_EDITOR_MAIN_TOOLBAR_SNAP_BUTTON)
			snap_button.button_pressed = false
			var sun_button: Button = EditorInterfaceAccess.get_node(EditorNodePoints.NODE_3D_EDITOR_MAIN_TOOLBAR_PREVIEW_SUN_BUTTON)
			sun_button.button_pressed = true
			var environment_button: Button = EditorInterfaceAccess.get_node(EditorNodePoints.NODE_3D_EDITOR_MAIN_TOOLBAR_PREVIEW_ENVIRONMENT_BUTTON)
			environment_button.button_pressed = true
	)

	set_command_context(CommandContext.WELCOME_BOOKEND)
	steps_welcome()
	set_command_context(CommandContext.TOUR_STEP)
	part_010_start()
	set_command_context(CommandContext.FINALE_BOOKEND)
	steps_finale()


func steps_welcome() -> void:
	bubble_set_bookend_title(atr("Introduction to 3D in Godot"))
	bubble_set_bookend_button_text(atr("LET'S GET RIGHT INTO IT!"))
	bubble_add_bookend_text([
		"[center]" + atr("In this tour, you take your first steps in 3D with the Godot editor.") + "[/center]",
	], Bubble.BookendTextStyle.RECAP)
	bubble_add_bookend_text([
		"[center]" + atr("You learn to navigate the 3D view, move and rotate nodes in 3D space, and add the essential elements every 3D game needs: a camera and a light.") + "[/center]",
	], Bubble.BookendTextStyle.KEY)
	bubble_add_bookend_text([
		"[center]" + atr("In the next tours, you assemble a small 3D game from premade parts and put all of this into practice.") + "[/center]",
	], Bubble.BookendTextStyle.INFO)

	queue_command(func() -> void: bubble._avatar.do_wink())


func part_010_start() -> void:
	var layout_root: Control = EditorInterfaceAccess.get_node(EditorNodePoints.LAYOUT_ROOT)
	var spatial_editor: Control = EditorInterfaceAccess.get_node(EditorNodePoints.NODE_3D_EDITOR)
	var inspector_dock: EditorDock = EditorInterfaceAccess.get_node(EditorNodePoints.INSPECTOR_DOCK)
	var filesystem_tree: Tree = EditorInterfaceAccess.get_node(EditorNodePoints.FILE_SYSTEM_TREE)
	var run_bar_play_current_button: Button = EditorInterfaceAccess.get_node(EditorNodePoints.RUN_BAR_PLAY_CURRENT_BUTTON)

	var spatial_editor_toolbar_move_button: Button = EditorInterfaceAccess.get_node(EditorNodePoints.NODE_3D_EDITOR_MAIN_TOOLBAR_MOVE_BUTTON)
	var spatial_editor_toolbar_rotate_button: Button = EditorInterfaceAccess.get_node(EditorNodePoints.NODE_3D_EDITOR_MAIN_TOOLBAR_ROTATE_BUTTON)
	var spatial_editor_toolbar_sun_button: Button = EditorInterfaceAccess.get_node(EditorNodePoints.NODE_3D_EDITOR_MAIN_TOOLBAR_PREVIEW_SUN_BUTTON)
	var spatial_editor_toolbar_environment_button: Button = EditorInterfaceAccess.get_node(EditorNodePoints.NODE_3D_EDITOR_MAIN_TOOLBAR_PREVIEW_ENVIRONMENT_BUTTON)
	var spatial_editor_toolbar_view_menu_button: MenuButton = EditorInterfaceAccess.get_node(EditorNodePoints.NODE_3D_EDITOR_MAIN_TOOLBAR_VIEW_OPTIONS_BUTTON)

	var spatial_editor_viewport_1_camera_preview_button: CheckBox = EditorInterfaceAccess.get_node_relative(EditorInterfaceAccess.get_node_3d_viewport(0), EditorNodePoints.NODE_3D_EDITOR_VIEWPORT_CAMERA_PREVIEW_CHECK)

	context_set_3d()
	scene_open("res://level/unfinished_game.tscn")
	spatial_editor_focus()
	bubble_set_title(atr("The unfinished game scene"))
	bubble_add_text(
		[
			atr("I just opened the scene [b]unfinished_game.tscn[/b] for you."),
			atr("This small game scene has a character, platforms, and a flag."),
			atr("Run the scene by clicking the [b]Run Current Scene[/b] button at the top right of the editor or pressing [b]%s[/b] on your keyboard.") % shortcuts.run_current,
			atr("You'll see a completely gray screen... Don't panic! It's to be expected. I'll explain why in the next step."),
			atr("Press [b]%s[/b] or close the game window to stop the game.") % shortcuts.stop
		]
	)
	bubble_add_task_press_button(run_bar_play_current_button)
	highlight_editor_nodes([EditorNodePoints.RUN_BAR_PLAY_CURRENT_BUTTON], true)
	complete_step()

	bubble_set_title(atr("The gray screen"))
	bubble_add_text(
		[
			atr("When running the game, the screen is completely gray because the scene currently lacks a camera."),
			atr("In the 3D world, like in the real world, we need something like a pair of eyes or a virtual camera to tell the computer where to look and what to display."),
			atr("In Godot, to add and control the game's 3D camera, we use the [b]Camera3D[/b] node."),
		]
	)
	complete_step()

	bubble_set_title(atr("Add the camera node"))

	bubble_add_text(
		[
			atr("Let's add a [b]Camera3D[/b] node to the scene."),
			atr('To add the camera, select the [b]Game[/b] node in the Scene dock and click the [b]Add Child Node[/b] button at the top left. You can also press [b]%s+A[/b] on your keyboard to open the Add Node dialog. Search for the [b]Camera3D[/b] node and create it in the scene.') % [
				shortcuts.ctrl,
			],
			atr("This creates and places the camera at the origin of the 3D game world."),
			atr("Note that if you make a mistake at any point, you can press [b]%s+Z[/b] to undo the last action.") % shortcuts.ctrl,
		]
	)

	bubble_add_task(
		atr("Add a [b]Camera3D[/b] as a child of the [b]Game[/b] node"),
		1,
		func add_camera_as_child_of_game_task(_task: Task) -> int:
			var camera := get_scene_node_by_path(GAME_CAMERA_PATH)
			return 1 if camera != null else 0
	)

	bubble_move_and_anchor(spatial_editor, Bubble.At.TOP_LEFT)

	highlight_scene_nodes_by_path(["Game"], -1, false)
	highlight_editor_nodes([EditorNodePoints.SCENE_TREE_ADD_NODE_BUTTON], true)
	complete_step()


	bubble_set_title(atr("The Camera3D node"))
	bubble_add_text([
			atr("After creating the node, notice the camera icon in the 3D view."),
			atr("It comes with a small tapered wireframe box that extends from it. This wireframe represents the direction in which the camera is looking.")
		]
	)
	bubble_add_texture(preload("res://icon.svg"))
	bubble_move_and_anchor(inspector_dock, Bubble.At.BOTTOM_RIGHT)
	bubble_set_avatar_at(Bubble.AvatarAt.LEFT)
	highlight_editor_nodes([EditorNodePoints.NODE_3D_EDITOR])
	complete_step()

	bubble_set_title(atr("Run the scene"))
	bubble_add_text(
		[
			atr("Try running the scene now to see... something, at least! The camera is located at the world's origin, and it's facing a platform, so that's what you'll see."),
			atr("The running game remains dark because there are no lights in the scene. We will add a light later."),
			atr("Run the scene by clicking the [b]Run Current Scene[/b] button at the top right of the editor or pressing [b]%s[/b] on your keyboard. Press [b]%s[/b] or close the game window to stop the game.") % [
				shortcuts.run_current,
				shortcuts.stop,
			]
		]
	)
	bubble_move_and_anchor(layout_root, Bubble.At.CENTER)
	bubble_add_task_press_button(run_bar_play_current_button)
	highlight_editor_nodes([EditorNodePoints.RUN_BAR_PLAY_CURRENT_BUTTON], true)
	complete_step()

	bubble_set_title(atr("The camera preview"))
	bubble_add_text(
		[
			atr("At the top of the [b]Inspector[/b] dock on the right, you'll notice a camera preview. When you select the [b]Camera3D[/b] node, this preview shows exactly what the camera sees."),
			atr("The lighting in this preview might look different from your running scene. That's because the preview uses the editor's default lighting setup."),
			atr("We'll learn how to disable these default lights later in the tour. For now, let's focus on positioning the camera behind our character by moving the viewport and manipulating 3D nodes.")
		]
	)
	bubble_move_and_anchor(spatial_editor, Bubble.At.CENTER_RIGHT)
	highlight_editor_nodes([EditorNodePoints.INSPECTOR_DOCK_INSPECTOR], true)
	scene_select_nodes_by_path([GAME_CAMERA_PATH])
	complete_step()

	bubble_set_title(atr("How to navigate the 3D view"))
	bubble_add_text(
		[
			atr("To move nodes in 3D, we often need to turn, pan, and zoom the view. Here's how you can do that in the 3D view:"),
			"[ul]" +
			atr("To rotate the 3D view, hold the [b]Middle Mouse Button[/b] down and move the mouse.") + "\n" +
			atr("To pan the view and move around, hold the [b]Shift[/b] key and [b]Middle Mouse Button[/b] down, then move the mouse.") + "\n" +
			atr("To zoom in and out, use the mouse wheel.") +
			"[/ul]",
			atr("Try moving, turning, and zooming the view to test the controls."),
		]
	)
	bubble_move_and_anchor(inspector_dock, Bubble.At.BOTTOM_RIGHT)
	highlight_editor_nodes([EditorNodePoints.NODE_3D_EDITOR])
	complete_step()

	bubble_set_title(atr("Focus the camera node"))
	bubble_add_text(
		[
			atr("When you rotate the view, it rotates around a point. This point is the last point of [b]focus[/b] you set in the editor. By default, it's located at the center of the view."),
			atr("You can quickly align the view to a node and make that node the focus point by selecting a node and pressing the [b]%s[/b] key on your keyboard.") % shortcuts.focus,
			atr("Ensure that the [b]Camera3D[/b] node is selected in the [b]Scene[/b] dock and press [b]%s[/b] to focus the view on the camera.") % shortcuts.focus,
			atr("This will re-center the view on the camera. The view will rotate around this point until you change it again."),
			atr("Note that, for the shortcut to work, the mouse cursor should be over the 3D view."),
		]
	)
	bubble_add_task_focus_node(GAME_CAMERA_PATH.get_file())
	bubble_move_and_anchor(inspector_dock, Bubble.At.BOTTOM_RIGHT)
	bubble_set_avatar_at(Bubble.AvatarAt.LEFT)
	highlight_editor_nodes([EditorNodePoints.NODE_3D_EDITOR])
	highlight_scene_nodes_by_path([GAME_CAMERA_PATH])
	scene_select_nodes_by_path([GAME_CAMERA_PATH])
	complete_step()

	bubble_set_title(atr("Rotate the view around the camera"))
	bubble_add_text([
		atr("Now that the camera node is in focus, try rotating the view. Hold the [b]Middle Mouse Button[/b] and drag to rotate the view around the camera."),
	])
	highlight_editor_nodes([EditorNodePoints.NODE_3D_EDITOR])
	complete_step()

	bubble_set_title(atr("Select the Move Mode"))
	bubble_add_text(
		[
			atr("To move a 3D object, as in 2D, you can use the %s [b]Move Mode[/b] in the toolbar at the top. Click the Move Mode icon in the toolbar above the viewport to display only the 3D position manipulator. You can also press [b]%s[/b] on your keyboard to activate it.") % [
				bbcode_generate_icon_image_by_name("ToolMove"),
				shortcuts.move_mode,
			],
		]
	)
	bubble_add_task_toggle_button(spatial_editor_toolbar_move_button, true, atr("Switch to [b]Move Mode[/b]"))
	bubble_move_and_anchor(spatial_editor, Bubble.At.CENTER)
	bubble_set_avatar_at(Bubble.AvatarAt.LEFT)
	highlight_editor_nodes([EditorNodePoints.NODE_3D_EDITOR_MAIN_TOOLBAR_MOVE_BUTTON])
	complete_step()

	bubble_set_title(atr("The 3D position manipulator"))
	bubble_add_text(
		[
			atr("The position manipulator has three axes you can click and drag to move the camera node along that axis. The red line corresponds to the X axis, the green line to the vertical Y axis, and the blue line to the Z axis."),
			atr("You can also click and drag on the floating colored squares between axes to move the camera within the corresponding plane.")
		]
	)
	bubble_add_video(preload("res://crow_logo.ogv"))
	bubble_move_and_anchor(layout_root, Bubble.At.CENTER)
	complete_step()

	bubble_set_title(atr("Move the camera"))
	bubble_add_text(
		[
			atr("Click and drag on the position manipulator axes and squares to move the camera node behind the character, in the floating blue box."),
			atr("Use the navigation tricks you learned previously to move the view as needed:"),
			"[ul]" +
			(atr("Change the editor's focus point with [b]%s[/b].") % shortcuts.focus) + "\n" +
			atr("Rotate the view with the [b]Middle Mouse Click[/b].") + "\n" +
			atr("Pan the view with [b]Shift + Middle Mouse Click[/b].") + "\n" +
			atr("Zoom in and out with the [b]Mouse Wheel[/b].") +
			"[/ul]",
		]
	)
	bubble_add_texture(preload("res://icon.svg"))
	bubble_add_task_node_to_guide(Guide3DTaskParameters.new("Camera3D", Vector3(0, 0, -20), Guide3DCheckMode.IN_BOUNDING_BOX))
	bubble_move_and_anchor(inspector_dock, Bubble.At.BOTTOM_RIGHT)
	highlight_editor_nodes([EditorNodePoints.NODE_3D_EDITOR])
	complete_step()

	bubble_set_title(atr("The camera direction"))
	bubble_add_text(
		[
			atr("Notice the tapered pink box that expands from the camera icon in the viewport. This box wireframe represents the direction in which the camera is looking."),
			atr("There's a little purple triangle above the purple wireframe in the viewport. It indicates the up direction of the camera. It should be pointing up or the view will be inverted."),
			atr("At the moment, the camera is looking away from the player character."),
			atr("To look at the player character, we need to rotate the box wireframe so that it extends towards the player."),
		]
	)
	bubble_add_texture(preload("res://icon.svg"))
	complete_step()

	bubble_set_title(atr("Select the Rotate mode"))
	bubble_add_text(
		[
			atr("Select the %s [b]Rotate Mode[/b] in the toolbar above the viewport to display the rotation manipulator.") % bbcode_generate_icon_image_by_name("ToolRotate"),
			atr("This manipulator has three circles representing the rotations you can perform: you can turn the selected node around the [b]x[/b], [b]y[/b], and [b]z[/b] axes."),
			atr("For example, clicking and dragging on the green circle will rotate the camera around the vertical axis, the y-axis.")
		]
	)
	bubble_move_and_anchor(spatial_editor, Bubble.At.CENTER)
	bubble_add_video(preload("res://crow_logo.ogv"))
	bubble_add_task_toggle_button(spatial_editor_toolbar_rotate_button, true, atr("Turn the [b]Rotate Mode[/b] button ON."))
	highlight_editor_nodes([EditorNodePoints.NODE_3D_EDITOR_MAIN_TOOLBAR_ROTATE_BUTTON])
	complete_step()

	bubble_set_title(atr("Make the camera look at the player"))
	bubble_add_text(
		[
			atr("Using the Rotate mode, turn the camera to look towards the player. You can rotate it around the y axis by clicking and dragging the green circle on the rotation manipulator."),
			atr("Your camera should be behind the player character and looking at it. You don't need to make the orientation perfect; you'll be able to adjust it later."),
			atr("You can press [b]%s[/b] at any time to run the scene and see what the camera sees. Press [b]%s[/b] to stop the game.") % [shortcuts.run_current, shortcuts.stop],
			atr("Don't worry about the fact everything is dark; we'll address that in a moment.")
		]
	)
	bubble_move_and_anchor(inspector_dock, Bubble.At.BOTTOM_RIGHT)
	bubble_add_texture(preload("res://icon.svg"))
	highlight_editor_nodes([EditorNodePoints.NODE_3D_EDITOR])
	bubble_add_task(
		atr("Rotate the camera around the y axis to look at the player"),
		1,
		func rotate_directional_light_task(_task: Task) -> int:
			var camera: Camera3D = get_scene_node_by_path(GAME_CAMERA_PATH)
			var angle: float = wrapf(abs(camera.global_rotation_degrees.y), 0.0, 360.0)
			return 1 if angle > 160.0 and angle < 200.0 else 0
	)
	complete_step()

	bubble_set_title(atr("The camera preview"))
	bubble_add_text(
		[
			atr("While the [b]Inspector[/b] camera preview is helpful, it disappears as soon as you select any other node."),
			atr("Thankfully, Godot offers a better solution: the viewport preview. This lets you see through the camera's eyes while you work on your level."),
			atr("You can toggle the viewport preview by clicking the [b]Preview[/b] checkbox at the top left of the viewport."),
			atr("Once enabled, you should see your player character from the camera's perspective. You can also toggle this preview by pressing [b]%s+P[/b] on your keyboard.") % shortcuts.ctrl
		]
	)
	bubble_add_task(
		atr("Turn on the camera preview"),
		1,
		func check_camera_preview_task(_task: Task) -> int:
			return 1 if spatial_editor_viewport_1_camera_preview_button.button_pressed else 0
	)
	bubble_move_and_anchor(inspector_dock, Bubble.At.BOTTOM_RIGHT)
	scene_select_nodes_by_path([GAME_CAMERA_PATH])
	highlight_controls([spatial_editor_viewport_1_camera_preview_button])
	complete_step()

	bubble_set_title(atr("Split the view in two"))
	bubble_add_text(
		[
			atr("With a single view, we have to switch in and out of preview to edit the scene. That's not convenient, is it?"),
			atr("We can split the view into two to see both simultaneously!"),
			atr("To split the view, click the [b]View[/b] button in the toolbar and select one of the options."),
			atr('Go ahead and split the view into two viewports vertically. In the View menu, the option is "2 Viewports (Alt)". You can also press [b]%s+Alt+2[/b] on your keyboard.' % shortcuts.ctrl)
		]
	)
	bubble_add_task(
		atr("Split the view into two vertical viewports"),
		1,
		func split_view_in_two_task(_task: Task) -> int:
			var view_popup := spatial_editor_toolbar_view_menu_button.get_popup()
			var item_index := Utils.find_menu_option_by_shortcut(view_popup, "spatial_editor/2_viewports_alt")
			return 1 if view_popup.is_item_checked(item_index) else 0
	)
	highlight_editor_nodes([EditorNodePoints.NODE_3D_EDITOR_MAIN_TOOLBAR_VIEW_OPTIONS_BUTTON])
	complete_step()

	bubble_set_title(atr("Working with two views"))
	bubble_add_text(
		[
			atr("Notice how the view is now split into two viewports. The left viewport shows the camera preview, and the right viewport shows the free view."),
			atr("In the free view, you can move the camera around and see the scene from different angles."),
			atr("Try moving and turning the camera with the %s Move Mode (%s) and the %s Rotate Mode (%s) to see the camera preview update in real-time.") % [
				bbcode_generate_icon_image_by_name("ToolMove"),
				shortcuts.move_mode,
				bbcode_generate_icon_image_by_name("ToolRotate"),
				shortcuts.rotate_mode,
			],
		]
	)
	highlight_editor_nodes([EditorNodePoints.NODE_3D_EDITOR])
	complete_step()

	bubble_set_title(atr("Run the scene"))
	bubble_add_text(
		[
			atr("Press [b]%s[/b] to play the scene again. You should see the player character and the platforms, with a pretty dark scene and a gray sky. Press [b]%s[/b] to close the running game.") % [
				shortcuts.run_current,
				shortcuts.stop,
			]
		]
	)
	bubble_add_task_press_button(run_bar_play_current_button)
	highlight_editor_nodes([EditorNodePoints.RUN_BAR_PLAY_CURRENT_BUTTON])
	complete_step()

	bubble_set_title(atr("In 3D, you need light"))
	bubble_add_text(
		[
			atr("A 3D game is composed of 3D geometry shaded by [b]materials[/b] and [b]light[/b]."),
			atr("Our scene has 3D geometry and materials predefined, but currently, it does not have light."),
			atr("It looks fine in the viewport because Godot provides default lighting to help us prototype scenes until we add our own lights."),
		]
	)
	highlight_editor_nodes([EditorNodePoints.NODE_3D_EDITOR])
	complete_step()

	bubble_set_title(atr("Turn off the default lights"))
	bubble_add_text(
		[
			atr("To see the scene in the viewport as it looks in the game, we need to turn off the default lights."),
			atr("In the toolbar, click the %s [b]Toggle preview sunlight[/b] and %s [b]Toggle preview environment[/b] buttons to turn off the default lights.") % [
				bbcode_generate_icon_image_by_name("PreviewSun"),
				bbcode_generate_icon_image_by_name("PreviewEnvironment")
			],
			atr("The viewport should become dark and gray, as in the game.")
		]
	)
	highlight_editor_nodes([
		EditorNodePoints.NODE_3D_EDITOR_MAIN_TOOLBAR_PREVIEW_SUN_BUTTON,
		EditorNodePoints.NODE_3D_EDITOR_MAIN_TOOLBAR_PREVIEW_ENVIRONMENT_BUTTON,
	])
	bubble_add_task(
		atr("Turn off the sun preview"),
		1,
		func preview_sun_off_task(_task: Task) -> int: return (
			0 if spatial_editor_toolbar_sun_button.button_pressed else 1
		)
	)
	bubble_add_task(
		atr("Turn off the environment preview"),
		1,
		func preview_environment_off_task(_task: Task) -> int: return (
			0 if spatial_editor_toolbar_environment_button.button_pressed else 1
		)
	)
	complete_step()

	bubble_set_title(atr("The most common light types"))
	bubble_add_text(
		[
			atr("Godot has three nodes representing different types of lights:"),
			"[ol]" +
			atr("The [b]OmniLight3D[/b] simulates light bulbs. It lights a spherical area.") + "\n" +
			atr("The [b]SpotLight3D[/b] simulates a flashlight or spotlight. It illuminates a cone-shaped area.") + "\n" +
			atr("The [b]DirectionalLight3D[/b] node simulates the sun. It applies uniform directional lighting to the entire scene.") +
			"[/ol]",
			atr("As our scene is an exterior, we will add a [b]DirectionalLight3D[/b] node to simulate sunlight."),
		]
	)
	bubble_move_and_anchor(spatial_editor, Bubble.At.CENTER)
	complete_step()

	bubble_set_title(atr("Add a directional light"))
	bubble_add_text(
		[
			atr("Select the [b]Game[/b] node in the Scene dock and add a [b]DirectionalLight3D[/b] node as a child of it."),
			atr("You can press [b]%s+A[/b] on your keyboard to open the Add Node dialog. Search for the [b]DirectionalLight3D[/b] node and create it in the scene.") % shortcuts.ctrl
		]
	)
	bubble_add_task(
		atr("Add a [b]DirectionalLight3D[/b] node to the scene"),
		1,
		func add_directional_light_as_child_of_game_task(_task: Task) -> int:
			var directional_light := get_scene_node_by_path(GAME_DIRECTIONAL_LIGHT_PATH)
			return 1 if directional_light != null else 0
	)
	bubble_move_and_anchor(spatial_editor, Bubble.At.TOP_LEFT)
	highlight_scene_nodes_by_path(["Game"], -1, false)
	highlight_editor_nodes([EditorNodePoints.SCENE_TREE_ADD_NODE_BUTTON], true)
	complete_step()

	bubble_set_title(atr("The directional light"))
	bubble_add_text(
		[
			atr("At first, the light is aligned with the ground plane so it does not illuminate the floor. It illuminates the character from the front."),
			atr("We'll rotate the light to angle it down and light up the character and the ground."),
			atr("First, hover the right viewport with the mouse and focus the directional light by pressing the [b]%s[/b] key. This will center the view on the light.") % shortcuts.focus
		]
	)
	bubble_add_task_focus_node(GAME_DIRECTIONAL_LIGHT_PATH.get_file())
	bubble_move_and_anchor(inspector_dock, Bubble.At.BOTTOM_RIGHT)
	highlight_editor_nodes([EditorNodePoints.NODE_3D_EDITOR])
	highlight_scene_nodes_by_path([GAME_DIRECTIONAL_LIGHT_PATH])
	complete_step()

	bubble_set_title(atr("Activate the Rotate mode"))
	bubble_add_text(
		[
			atr("We can use the [b]Rotate Mode[/b] in the toolbar to rotate the light. Click the icon or press [b]%s[/b] on your keyboard to activate the [b]Rotate Mode[/b].") % shortcuts.rotate_mode
		]
	)
	bubble_add_task_toggle_button(
		spatial_editor_toolbar_rotate_button,
		true,
		atr("Turn the [b]Rotate Mode[/b] button ON.")
	)
	highlight_editor_nodes([EditorNodePoints.NODE_3D_EDITOR_MAIN_TOOLBAR_ROTATE_BUTTON])
	complete_step()

	bubble_set_title(atr("The rotation manipulator"))
	bubble_add_text(
		[
			atr("We used the rotation manipulator before with the camera. It has three circles representing the rotations you can perform: you can turn the selected node around the [b]x[/b], [b]y[/b], and [b]z[/b] axes."),
			atr("Left click and drag on any of these three circles to rotate the light around the corresponding axis."),
			atr("Left clicking and dragging anywhere else in the viewport will rotate the light parallel to the view's forward axis.")
		]
	)
	bubble_move_and_anchor(spatial_editor, Bubble.At.CENTER)
	complete_step()

	bubble_set_title(atr("Rotate the directional light"))
	bubble_add_text(
		[
			atr("The light direction is represented by the white wire arrow that's aligned with the ground plane by default."),
			atr("Rotate the light by clicking and dragging on the red circle to rotate it around the [b]x[/b]-axis and angle it down."),
			atr("If you still have the two viewports active, you should see the character and the ground get lit uniformly from above.")
		]
	)
	bubble_add_task(
		atr("Rotate the light to angle it down"),
		1,
		func rotate_directional_light_task(_task: Task) -> int:
			var directional_light: DirectionalLight3D = get_scene_node_by_path(GAME_DIRECTIONAL_LIGHT_PATH)
			return 1 if directional_light.global_rotation.x < 0 else 0
	)
	bubble_move_and_anchor(inspector_dock, Bubble.At.BOTTOM_RIGHT)
	bubble_add_video(preload("res://crow_logo.ogv"))
	highlight_editor_nodes([EditorNodePoints.NODE_3D_EDITOR])
	complete_step()

	bubble_set_title(atr("To shade or not to shade"))
	bubble_add_text(
		[
			atr("Notice how the player character does not cast a shadow in the camera preview on the left."),
			atr("By default, lights in 3D games do not cast shadows because shadows have a rendering cost. Having too many shadow-casting lights can slow down the game, but having none doesn't give the visuals enough depth."),
			atr("Let's see how to activate shadows on our [b]DirectionalLight3D[/b] to make it cast shadows in the game."),
		]
	)
	highlight_editor_nodes([EditorNodePoints.NODE_3D_EDITOR])
	complete_step()

	bubble_set_title(atr("Enable shadows on the directional light"))
	bubble_add_text(
		[
			atr("Make sure you have the [b]DirectionalLight3D[/b] node selected. Then, in the [b]Inspector[/b], turn on the [b]Shadow[/b] category by clicking the checkbox to the right of the label. Shadows will appear behind the character and the flag."),
			atr("There are a bunch of settings to tweak the quality and range of the shadows, but we'll learn all about that later in the course."),
		]
	)
	bubble_add_task(
		atr("Enable shadows on the [b]DirectionalLight3D[/b] node"),
		1,
		func _enable_light_shadows_task(_task: Task) -> int:
			var directional_light: DirectionalLight3D = get_scene_node_by_path(GAME_DIRECTIONAL_LIGHT_PATH)
			return 1 if directional_light.shadow_enabled else 0
	)
	bubble_move_and_anchor(spatial_editor, Bubble.At.TOP_RIGHT)
	scene_select_nodes_by_path([GAME_DIRECTIONAL_LIGHT_PATH])
	highlight_editor_nodes([EditorNodePoints.INSPECTOR_DOCK_INSPECTOR])
	complete_step()

	bubble_set_title(atr("Run the scene"))
	bubble_add_text(
		[
			atr("Run the scene again with [b]%s[/b] to see that the character is lit and casts a shadow on the ground. The game should look slightly better now.") % shortcuts.run_current,
			atr("Press [b]%s[/b] to close the running game.") % shortcuts.stop,
			atr("The scene still lacks a sky. We'll add one next.")
		]
	)
	bubble_add_task_press_button(run_bar_play_current_button)
	highlight_editor_nodes([EditorNodePoints.RUN_BAR_PLAY_CURRENT_BUTTON])
	complete_step()

	bubble_set_title(atr("The world environment"))
	bubble_add_text(
		[
			atr("While we added a directional light, we still have lots of shaded areas in our level, and the background is all gray."),
			atr("To control the background, we can use a [b]WorldEnvironment[/b] node. This node takes an [b]Environment[/b] resource and lets us define what the sky should look like. It also controls post-processing effects built into Godot, like fog, contrast, and more."),
			atr("We won't create an environment from scratch now; we'll learn how to do that later in the course. For now, we'll use one I've prepared for you.")
		]
	)
	bubble_move_and_anchor(spatial_editor, Bubble.At.CENTER)
	bubble_set_avatar_at(Bubble.AvatarAt.CENTER)
	complete_step()

	bubble_set_title(atr("Add a WorldEnvironment node"))
	bubble_add_text(
		[
			atr("Let's add a [b]WorldEnvironment[/b] node to the scene."),
			atr("Select the [b]Game[/b] node in the Scene dock and add a new [b]WorldEnvironment[/b] node as a child of it. This node alone does nothing; it needs an [b]Environment[/b] resource to work."),
			atr("We'll add it in the next step.")
		]
	)
	bubble_add_task(
		atr("Add a [b]WorldEnvironment[/b] node to the scene"),
		1,
		func add_world_environment_as_child_of_game_task(_task: Task) -> int:
			var world_environment := get_scene_node_by_path(GAME_WORLD_ENVIRONMENT_PATH)
			return 1 if world_environment != null else 0
	)
	bubble_move_and_anchor(spatial_editor, Bubble.At.TOP_LEFT)
	bubble_set_avatar_at(Bubble.AvatarAt.LEFT)
	highlight_scene_nodes_by_path(["Game"], -1, false)
	highlight_editor_nodes([EditorNodePoints.SCENE_TREE_ADD_NODE_BUTTON], true)
	complete_step()

	bubble_set_title(atr("Add the environment resource"))
	bubble_add_text(
		[
			atr("With the [b]WorldEnvironment[/b] node selected, click and drag the [b]world_environment.tres[/b] file from the [b]FileSystem[/b] dock onto the [b]Environment[/b] property in the [b]Inspector[/b]."),
			atr("It's an environment I've prepared for you. It has a soft purple sky and uses the fog effect to give the platforms depth.")
		]
	)
	bubble_move_and_anchor(layout_root, Bubble.At.CENTER)
	bubble_set_avatar_at(Bubble.AvatarAt.CENTER)
	highlight_filesystem_paths([PATH_WORLD_ENVIRONMENT_TRES])
	scene_select_nodes_by_path([GAME_WORLD_ENVIRONMENT_PATH])
	highlight_inspector_properties(["environment"])
	bubble_add_task_set_node_property(
		GAME_WORLD_ENVIRONMENT_PATH.get_file(), "environment", RESOURCES.world_environment,
		atr("Set the [b]Environment[/b] property to [b]%s[/b]") % PATH_WORLD_ENVIRONMENT_TRES.get_file()
	)
	mouse_click_drag_by_callable(
		get_tree_item_center_by_path.bind(filesystem_tree, PATH_WORLD_ENVIRONMENT_TRES),
		get_inspector_property_center.bind("environment")
	)
	complete_step()

	bubble_set_title(atr("The ambient lighting"))
	bubble_add_text(
		[
			atr("The sky brightens the scene and gives it a more appealing look. It uses a simple, uniform light that comes from all directions, called [b]ambient lighting[/b]."),
			atr("It's a very efficient and performance-friendly way to light a scene. It also works great for stylized visuals, like the style we're going for in this course.")
		]
	)
	bubble_move_and_anchor(spatial_editor, Bubble.At.CENTER_RIGHT)
	bubble_set_avatar_at(Bubble.AvatarAt.CENTER)
	highlight_editor_nodes([EditorNodePoints.NODE_3D_EDITOR])
	complete_step()

	bubble_set_title(atr("Expand the ambient light"))
	bubble_add_text(
		[
			atr("Let's see how it works in the [b]Inspector[/b] dock. With the [b]WorldEnvironment[/b] node selected, in the Inspector, click on the [b]world_environment.tres[/b] resource to expand its properties. Then, expand the [b]Ambient Light[/b] category."),
			atr("It reveals four properties: [b]Source[/b], [b]Color[/b], [b]Sky Contribution[/b], and [b]Energy[/b]."),
			atr("The source of the ambient light is the purple sky, and it contributes to the scene's lighting. The sky colors are mixed with the [b]Color[/b] property based on the [b]Sky Contribution[/b] value. The [b]Energy[/b] property controls the intensity of the ambient light.")
		]
	)
	scene_select_nodes_by_path([GAME_WORLD_ENVIRONMENT_PATH])
	highlight_editor_nodes([EditorNodePoints.INSPECTOR_DOCK_INSPECTOR])
	complete_step()

	bubble_set_title(atr("Tweak the ambient light"))
	bubble_add_text(
		[
			atr("Take a moment to play with these properties and see how they affect the scene."),
			atr("The [b]Color[/b] property is particularly fun to tweak! It tints all the platforms and the character with the color you choose."),
			atr("Note that the Color property won't do anything if [b]Sky Contribution[/b] is set to [b]1.0[/b]. You need to lower the sky's contribution to see the effect.")
		]
	)
	bubble_move_and_anchor(spatial_editor, Bubble.At.CENTER_RIGHT)
	scene_select_nodes_by_path([GAME_WORLD_ENVIRONMENT_PATH])
	highlight_editor_nodes([EditorNodePoints.INSPECTOR_DOCK_INSPECTOR, EditorNodePoints.NODE_3D_EDITOR])
	complete_step()


func steps_finale() -> void:
	bubble_set_bookend_title(atr("Excellent!"))

	bubble_add_bookend_text([
		"[center]" + atr("You now know how to navigate the 3D view and set up the essential elements of a 3D scene.") + "[/center]",
	], Bubble.BookendTextStyle.RECAP)
	bubble_add_bookend_text([
		"[center]" + atr("Your progress will be saved if you quit now.") + "[/center]",
	], Bubble.BookendTextStyle.KEY)
	bubble_add_bookend_text([
		"[center]" + atr("In the next tours, you assemble a small 3D game from premade parts and explore 3D geometry and materials.") + "[/center]",
	], Bubble.BookendTextStyle.INFO)
	queue_command(func() -> void: bubble._avatar.set_expression(Gobot.Expressions.HAPPY))
