tool
extends Node


# Private classes

class __TextEditState:
	# Public variables

	var __cursor_line: int
	var __cursor_column: int

	var __indentation: int

	var __selection_active: bool

	var __selection_from_line: int
	var __selection_from_column: int

	var __selection_to_line: int
	var __selection_to_column: int

	var __scroll_horizontal: int
	var __scroll_vertical: float

	var __text_edit: TextEdit


	# Lifecycle methods

	func _init(
		_text_edit: TextEdit
	):
		__text_edit = _text_edit

		__cursor_line = __text_edit.cursor_get_line()
		__cursor_column = __text_edit.cursor_get_column()

		__selection_active = __text_edit.is_selection_active()

		if __selection_active:
			__selection_from_line = __text_edit.get_selection_from_line()
			__selection_from_column = __text_edit.get_selection_from_column()

			__selection_to_line = __text_edit.get_selection_to_line()
			__selection_to_column = __text_edit.get_selection_to_column()

		__scroll_horizontal = __text_edit.scroll_horizontal
		__scroll_vertical = __text_edit.scroll_vertical


	# Public methods

	func active_line() -> int:
		if __selection_active:
			return __selection_from_line

		return __cursor_line


	func active_indentation() -> int:
		var active_line: String = __text_edit.get_line(active_line())

		return active_line.length() - active_line.dedent().length()


	func clear() -> void:
		__text_edit.deselect()


	func restore(
		_line_offset: int = 0
	) -> void:
		__text_edit.cursor_set_line(__cursor_line + _line_offset)
		__text_edit.cursor_set_column(__cursor_column)

		if __selection_active:
			__text_edit.select(
				__selection_from_line + _line_offset,
				__selection_from_column,
				__selection_to_line + _line_offset,
				__selection_to_column
			)

		__text_edit.scroll_horizontal = __scroll_horizontal
		__text_edit.scroll_vertical = __scroll_vertical


# Private variables

var __active_text_edit: TextEdit
var __comment_queue: Array = []


# Public methods

func comment(
	_text: String,
	_escape: bool = true
) -> bool:
	if !__active_text_edit:
		return  false

	var state: __TextEditState = __TextEditState.new(__active_text_edit)

	state.clear()

	var active_line: int = state.active_line()
	var active_indentation: int = state.active_indentation()

	var line_offset: int = 1

	var padding: String = "\t".repeat(active_indentation)

	if !_text.begins_with("#"):
		_text = "# " + _text

	if _escape:
		_text = _text.c_escape()
	else:
		line_offset += _text.count("\n")
		_text = _text.replace("\n", "\n%s# " % padding)

	__active_text_edit.cursor_set_line(active_line, false)
	__active_text_edit.cursor_set_column(0, false)
	__active_text_edit.insert_text_at_cursor("%s%s\n" % [padding, _text])

	state.restore(line_offset)

	return true


func enqueue_comment(
	_text: String,
	_escape: bool = true
) -> void:
	__comment_queue.append([_text, _escape])


# Private variables

func __find_active_text_edit(
	_node: Node
) -> TextEdit:
	if _node is TextEdit && _node.has_focus():
		return _node as TextEdit

	for child in _node.get_children():
		var active_text_edit: TextEdit = __find_active_text_edit(child)

		if active_text_edit:
			return active_text_edit

	return null


func __script_changed(
	_script: Script,
	_script_editor: ScriptEditor
) -> void:
	var active_text_edit: TextEdit = __find_active_text_edit(_script_editor)

	if active_text_edit:
		__active_text_edit = active_text_edit

	while !__comment_queue.empty():
		var current_comment: Array = __comment_queue.pop_front()

		var text: String = current_comment[0]
		var escape: bool = current_comment[1]

		comment(text, escape)
