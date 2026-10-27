@tool

const Enums := preload("../../utils/eia_enums.gd")
const Types := preload("../../utils/eia_resolver_types.gd")
const Utils := preload("../../utils/eia_resolver_utils.gd")


class OutputDockDef extends Types.Definition:
	func _init() -> void:
		node_type = "EditorLog"
		prefetch_references = [
			Enums.NodePoint.LAYOUT_ROOT,
			Enums.NodePoint.LAYOUT_DOCK_LEFT_LEFT_TOP,
			Enums.NodePoint.LAYOUT_DOCK_LEFT_LEFT_BOTTOM,
			Enums.NodePoint.LAYOUT_DOCK_LEFT_RIGHT_TOP,
			Enums.NodePoint.LAYOUT_DOCK_LEFT_RIGHT_BOTTOM,
			Enums.NodePoint.LAYOUT_DOCK_RIGHT_LEFT_TOP,
			Enums.NodePoint.LAYOUT_DOCK_RIGHT_LEFT_BOTTOM,
			Enums.NodePoint.LAYOUT_DOCK_RIGHT_RIGHT_TOP,
			Enums.NodePoint.LAYOUT_DOCK_RIGHT_RIGHT_BOTTOM,
			Enums.NodePoint.LAYOUT_DOCK_MIDDLE_BOTTOM,
			Enums.NodePoint.LAYOUT_DOCK_BOTTOM_LEFT,
			Enums.NodePoint.LAYOUT_DOCK_BOTTOM_RIGHT,
			Enums.NodePoint.LAYOUT_DOCK_HIDDEN_CONTAINER,
		]

		var custom_script := func(base_node: Node) -> Node:
			var dock_locations := Utils.dock_get_locations()
			for dock_container in dock_locations:
				var dock := dock_container.find_child("Output", false, false)
				if dock:
					return dock

			return null

		resolver_steps = [
			Types.DoCustomStep.new(custom_script),
		]


class OutputDockRichTextDef extends Types.Definition:
	func _init() -> void:
		node_type = "RichTextLabel"
		base_reference = Enums.NodePoint.OUTPUT_DOCK

		resolver_steps = [
			Types.GetChildTypeStep.new("HBoxContainer", 0),
			Types.GetChildTypeStep.new("VBoxContainer", 0),
			Types.GetChildTypeStep.new("RichTextLabel"),
		]


class OutputDockToolbarDef extends Types.Definition:
	func _init() -> void:
		node_type = "HFlowContainer"
		base_reference = Enums.NodePoint.OUTPUT_DOCK

		resolver_steps = [
			Types.GetChildTypeStep.new("HBoxContainer", 0),
			Types.GetChildTypeStep.new("VBoxContainer", 0),
			Types.GetChildTypeStep.new("HFlowContainer", 0),
		]


class OutputDockToolbarTextFilterDef extends Types.Definition:
	func _init() -> void:
		node_type = "LineEdit"
		base_reference = Enums.NodePoint.OUTPUT_DOCK_TOOLBAR

		resolver_steps = [
			Types.GetChildTypeStep.new("LineEdit"),
		]


class OutputDockToolbarClearOutputButtonDef extends Types.Definition:
	func _init() -> void:
		node_type = "Button"
		base_reference = Enums.NodePoint.OUTPUT_DOCK_TOOLBAR

		resolver_steps = [
			Types.GetChildTypeStep.new("Button", 0),
			Types.HasSignalCallableStep.new("pressed", "EditorLog::_clear_request"),
			Types.HasEditorIconStep.new("Clear"),
		]


class OutputDockToolbarCollapseDuplicatesButtonDef extends Types.Definition:
	func _init() -> void:
		node_type = "Button"
		base_reference = Enums.NodePoint.OUTPUT_DOCK_TOOLBAR

		resolver_steps = [
			Types.GetChildTypeStep.new("Button", 1),
			Types.HasSignalCallableStep.new("toggled", "EditorLog::_set_collapse"),
			Types.HasEditorIconStep.new("CombineLines"),
		]


class OutputDockToolbarToggleStandardLogsButtonDef extends Types.Definition:
	func _init() -> void:
		node_type = "Button"
		base_reference = Enums.NodePoint.OUTPUT_DOCK_TOOLBAR

		resolver_steps = [
			Types.GetChildTypeStep.new("HBoxContainer", 0),
			Types.GetChildTypeStep.new("Button", 0),
			Types.HasSignalCallableStep.new("toggled", "EditorLog::_set_filter_active"),
			Types.HasEditorIconStep.new("Popup"),
		]


class OutputDockToolbarToggleErrorsButtonDef extends Types.Definition:
	func _init() -> void:
		node_type = "Button"
		base_reference = Enums.NodePoint.OUTPUT_DOCK_TOOLBAR

		resolver_steps = [
			Types.GetChildTypeStep.new("HBoxContainer", 0),
			Types.GetChildTypeStep.new("Button", 1),
			Types.HasSignalCallableStep.new("toggled", "EditorLog::_set_filter_active"),
			Types.HasEditorIconStep.new("StatusError"),
		]


class OutputDockToolbarToggleWarningsButtonDef extends Types.Definition:
	func _init() -> void:
		node_type = "Button"
		base_reference = Enums.NodePoint.OUTPUT_DOCK_TOOLBAR

		resolver_steps = [
			Types.GetChildTypeStep.new("HBoxContainer", 0),
			Types.GetChildTypeStep.new("Button", 2),
			Types.HasSignalCallableStep.new("toggled", "EditorLog::_set_filter_active"),
			Types.HasEditorIconStep.new("StatusWarning"),
		]


class OutputDockToolbarToggleEditorLogsButtonDef extends Types.Definition:
	func _init() -> void:
		node_type = "Button"
		base_reference = Enums.NodePoint.OUTPUT_DOCK_TOOLBAR

		resolver_steps = [
			Types.GetChildTypeStep.new("HBoxContainer", 0),
			Types.GetChildTypeStep.new("Button", 3),
			Types.HasSignalCallableStep.new("toggled", "EditorLog::_set_filter_active"),
			Types.HasEditorIconStep.new("Edit"),
		]
