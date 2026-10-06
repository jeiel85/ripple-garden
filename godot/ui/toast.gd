class_name Toast
extends PanelContainer

## A single quiet line of feedback (UI_UX §1: no stacked reward popups). Messages queue and are
## shown one after another; a new message never overlaps the current one. Copy is short and
## observational: "It slipped back into the water", never "Failed!".

const FADE_SEC := 0.25
const MIN_SHOW_SEC := 2.2

var reduced_motion := false

var _label: Label
var _queue: Array[String] = []
var _showing := false
var _timer: Timer

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(480, 0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_next)
	add_child(_timer)

## Queues `text` (already translated). Duplicates of the message being shown are dropped.
func show_message(text: String) -> void:
	if text.is_empty() or (_showing and _label.text == text) or text in _queue:
		return
	_queue.append(text)
	if not _showing:
		_next()

func is_showing() -> bool:
	return _showing

func pending_count() -> int:
	return _queue.size()

func _next() -> void:
	if _queue.is_empty():
		_showing = false
		if reduced_motion:
			visible = false
		else:
			var tween := create_tween()
			tween.tween_property(self, "modulate:a", 0.0, FADE_SEC)
			tween.tween_callback(func() -> void: visible = _showing)
		return
	_showing = true
	_label.text = _queue.pop_front()
	visible = true
	modulate.a = 1.0 if reduced_motion else 0.0
	if not reduced_motion:
		create_tween().tween_property(self, "modulate:a", 1.0, FADE_SEC)
	_timer.start(MIN_SHOW_SEC + minf(2.0, _label.text.length() * 0.04))
