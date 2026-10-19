class_name Loc
extends RefCounted

## The one entry point for localized text that takes arguments. A Korean string that chooses its
## particle ("을(류)") must be formatted here and not with a bare `tr(key) % args`, or the choice
## shows on screen. Loc translates, fills the placeholders, resolves the particles
## (KoreanParticles) and puts the word joiners back, so English and Japanese — which carry no
## markers — print exactly as `tr(key) % args` would.
##
##   Loc.t("ui.toast.bought", tr("fish.mandarin.name"))
##   Loc.t("ui.map.locked", [name, level, now, fish, now])

static func t(key: String, args: Variant = null) -> String:
	return format(TranslationServer.translate(key), args)

## `format` already translated, filled with `args` (one value or an array) and particle-resolved.
static func format(text: String, args: Variant = null) -> String:
	if args == null or (args is Array and (args as Array).is_empty()):
		return _finish(text)
	return _finish(text % args)

## Keeps the joined Korean translation joined after the marker's letters were stripped to resolve.
static func _finish(text: String) -> String:
	var joined := KeepWordsTranslation.JOINER in text
	var resolved := KoreanParticles.resolve(text)
	return KeepWordsTranslation.keep_words(resolved) if joined else resolved
