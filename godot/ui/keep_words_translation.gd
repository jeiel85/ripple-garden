class_name KeepWordsTranslation
extends Translation

## Korean is set word by word: a line may break at a space, never inside a word. The text server follows
## ICU's line rule, which lets Korean break between any two syllables ("손 / 을 떼 보세요"), and its keep-all
## option did not hold in testing. So the Korean translation is wrapped and every word's letters are joined
## with WORD JOINER (U+2060), which draws nothing and forbids a break. A word too long for its line is
## still broken by the labels' adaptive wrapping. Format placeholders (`%s`, `%d`) are left intact.

const JOINER := "⁠"

var _inner: Translation
var _cache: Dictionary = {}

func _init(inner: Translation = null) -> void:
	_inner = inner
	if inner != null:
		locale = inner.locale

## Replaces the loaded Korean translation with one that keeps words together; safe to call again.
static func install() -> void:
	var current := TranslationServer.get_translation_object("ko")
	if current == null or current is KeepWordsTranslation:
		return
	TranslationServer.remove_translation(current)
	TranslationServer.add_translation(KeepWordsTranslation.new(current))

func _get_message(src_message: StringName, context: StringName) -> StringName:
	var key := String(context) + "\u0004" + String(src_message)
	if not _cache.has(key):
		var text := _inner.get_message(src_message, context)
		_cache[key] = StringName(keep_words(text)) if text != StringName() else StringName()
	return _cache[key]

func _get_plural_message(src_message: StringName, src_plural_message: StringName, n: int, context: StringName) -> StringName:
	return StringName(keep_words(_inner.get_plural_message(src_message, src_plural_message, n, context)))

## `text` with a joiner between neighbouring letters of a word that has Hangul in it.
static func keep_words(text: String) -> String:
	var out := ""
	for i in text.length():
		var ch := text[i]
		if i > 0 and _joins(text[i - 1], ch):
			out += JOINER
		out += ch
	return out

static func _joins(before: String, after: String) -> bool:
	if before == "%" or before == JOINER or after == JOINER:
		return false  # "%" + "d" is a placeholder; never join twice
	if before.strip_edges().is_empty() or after.strip_edges().is_empty():
		return false
	return _hangul(before) or _hangul(after)

static func _hangul(ch: String) -> bool:
	var code := ch.unicode_at(0)
	return (code >= 0xAC00 and code <= 0xD7A3) or (code >= 0x1100 and code <= 0x11FF) or (code >= 0x3130 and code <= 0x318F)
