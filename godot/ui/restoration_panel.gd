class_name RestorationPanel
extends PanelContainer

## Restoring the pond (UI_UX §6): show what is needed, ask for a decision, then let the world do
## the talking. The panel states the requirement, names what the next stage will bring, and has one
## button; the actual change plays out in the scene, not in a long reward popup.

signal confirmed
signal close_pressed

var restoration: RestorationService
var region_id := ""

var _level: Label
var _points: Label
var _bar: ProgressBar
var _brings: Label
var _hint: Label
var _confirm: Button

func _init() -> void:
	custom_minimum_size = Vector2(640, 0)
	var box := UiKit.vbox(14)
	var header := UiKit.hbox(12)
	var title := UiKit.label(tr("ui.restore.title"), "TitleLabel", HORIZONTAL_ALIGNMENT_LEFT, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UiKit.button(tr("ui.close"), func() -> void: close_pressed.emit()))
	box.add_child(header)
	_level = UiKit.label("")
	_points = UiKit.label("", "DimLabel")
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 26)
	_bar.show_percentage = false
	_brings = UiKit.label("", "DimLabel")
	_hint = UiKit.label("", "DimLabel")
	_confirm = UiKit.button(tr("ui.restore.confirm"), func() -> void: confirmed.emit(), true, UiTheme.TOUCH_MIN_PX * 1.15)
	for node in [_level, _points, _bar, _brings, _hint, UiKit.spacer(4), _confirm]:
		box.add_child(node)
	add_child(UiKit.margin(box, 24))

func setup(p_restoration: RestorationService, p_region_id: String) -> void:
	restoration = p_restoration
	region_id = p_region_id

func refresh() -> void:
	var requirement := restoration.get_requirement(region_id)
	var cap := restoration.max_level(region_id)
	_level.text = tr("ui.restore.level") % [requirement.level, cap]
	_brings.visible = not requirement.at_cap
	if requirement.at_cap:
		_points.text = tr("ui.restore.points_total") % requirement.points
		_bar.max_value = 100.0  # the bar may still hold the previous stage's maximum
		_bar.value = 100.0
		_hint.text = tr("ui.restore.at_cap")
		_confirm.disabled = true
		return
	_points.text = tr("ui.restore.points") % [requirement.points, requirement.points_needed]
	_bar.max_value = float(requirement.points_needed)
	_bar.value = float(mini(requirement.points, requirement.points_needed))
	_brings.text = tr("ui.restore.next_brings") % _next_stage_names(requirement.next_level)
	_hint.text = tr("ui.restore.ready") if requirement.can_restore else tr("ui.restore.need_more")
	_confirm.disabled = not requirement.can_restore

## Names of the scenery and wildlife that first appear at `level`, from the region layout.
func _next_stage_names(level: int) -> String:
	var layout := ContentDB.get_layout(region_id)
	var names: Array[String] = []
	for prop in layout.get("props", []):
		if int(prop.get("min_level", 0)) == level:
			var prop_name := tr("ui.prop." + prop["kind"])
			if not prop_name in names:
				names.append(prop_name)
	for animal in layout.get("ambient_animals", []):
		if int(animal["min_level"]) == level:
			var animal_name := tr("ui.animal." + animal["kind"])
			if not animal_name in names:
				names.append(animal_name)
	if names.is_empty():
		names.append(tr("ui.restore.clearer_water"))
	return ", ".join(names)
