class_name ResponsiveRow
extends BoxContainer

## A row of cards that becomes a column when side by side would run past the page.
##
## The gear screen's bait and bag summaries needed 769 px side by side at the largest Text Scale with
## Large UI, against a 688 px page (BACKLOG "최대 글자 크기에서 장비 화면 가로 넘침"). Stacked, the
## widest card (429 px) fits with room to spare. The children keep their order; only the axis changes,
## so the same screen reads the same way at every Text Scale.

## Gap between children, in both directions.
var separation_px := 10

func _init(gap: int = 10) -> void:
	separation_px = gap
	vertical = false
	add_theme_constant_override("separation", gap)
	resized.connect(_refit)

func _ready() -> void:
	for child in get_children():
		_watch(child)
	child_entered_tree.connect(_watch)
	_refit()

## A child whose own content grows (a longer count, another language) can push the row over the page.
func _watch(node: Node) -> void:
	if node is Control:
		var control := node as Control
		if not control.minimum_size_changed.is_connected(_refit):
			control.minimum_size_changed.connect(_refit)

## Width the children need when laid out side by side.
func needed_width() -> float:
	var needed := 0.0
	var count := 0
	for child in get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		needed += control.get_combined_minimum_size().x
		count += 1
	if count > 1:
		needed += separation_px * (count - 1)
	return needed

## Whether the children fit side by side in `available` pixels.
func fits(available: float) -> bool:
	return needed_width() <= available + 0.5

func _refit() -> void:
	if not is_inside_tree():
		return
	# The children's own widths do not depend on the axis, so this test cannot flip back and forth:
	# when the row fits it stays a row, and when it does not it stays a column.
	var want := size.x > 1.0 and not fits(size.x)
	if want != vertical:
		vertical = want
		queue_sort()
