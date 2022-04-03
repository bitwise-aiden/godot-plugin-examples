tool
extends EditorPlugin


# Lifecycle methods

func _enter_tree():
	if Engine.editor_hint:
		add_autoload_singleton("StreamComment", "res://addons/stream_comment/stream_comment.gd")

		yield(get_tree(), "idle_frame")

		var stream_comment_instance: Node = get_node("/root/StreamComment")

		var editor: EditorInterface = get_editor_interface()
		var script_editor: ScriptEditor = editor.get_script_editor()

		script_editor.connect(
			"editor_script_changed",
			stream_comment_instance,
			"__script_changed",
			[script_editor]
		)


func _exit_tree():
	if Engine.editor_hint:
		remove_autoload_singleton("StreamComment")


# Private methods

func __find_active_text_edit(node: Node) -> TextEdit:
	if node is TextEdit && node.has_focus():
		return node as TextEdit

	for child in node.get_children():
		var active_text_edit: TextEdit = __find_active_text_edit(child)

		if active_text_edit:
			return active_text_edit

	return null


func __get_active_text_edit() -> TextEdit:
	var editor: EditorInterface = self.get_editor_interface()

	var active_text_edit: TextEdit = __find_active_text_edit(editor)

	return null
