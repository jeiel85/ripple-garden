class_name KoreanParticles
extends RefCounted

## Korean chooses its particles from the word before them, so the source text writes the choice —
## "을(류)" — and this resolves it once the placeholders are filled: 을 after a syllable that ends
## in a consonant (받침), 를 after one that ends in a vowel. Without it the choice stays on screen
## ("봄날의 약속을(를) 선물 받았어요") (BACKLOG "한국어 조사 자동 선택").
##
## Only Korean text carries these markers; English and Japanese strings pass through unchanged.
## Enter through Loc: the shipped Korean translation joins the marker's own letters with word
## joiners (KeepWordsTranslation), which resolve() strips before matching and Loc re-applies.

## The marker spellings, shared with the guard test that fails when a choosing string is formatted
## with a bare tr() instead of Loc.
const MARKERS: PackedStringArray = ["을(를)", "이(가)", "은(는)", "과(와)", "(으)로"]

## marker → the form after a final consonant → the form after a vowel.
## "lier" marks (으)로, whose ㄹ final takes 로 like a vowel ending (달로, 서울로).
const _PARTICLES: Array[Dictionary] = [
	{"marker": "을(를)", "final": "을", "plain": "를"},
	{"marker": "이(가)", "final": "이", "plain": "가"},
	{"marker": "은(는)", "final": "은", "plain": "는"},
	{"marker": "과(와)", "final": "과", "plain": "와"},
	{"marker": "(으)로", "final": "으로", "plain": "로", "lier": true},
]

## `text` with every particle choice resolved. Word joiners are removed first (they sit between the
## marker's own letters in the joined Korean translation); callers that need the joiners back
## re-join with KeepWordsTranslation.keep_words().
static func resolve(text: String) -> String:
	var out := text.replace(KeepWordsTranslation.JOINER, "")
	for particle in _PARTICLES:
		out = _pick(out, particle)
	return out

static func _pick(text: String, particle: Dictionary) -> String:
	var marker: String = particle["marker"]
	var out := ""
	var i := 0
	while i < text.length():
		if text.substr(i, marker.length()) == marker:
			out += _form(out, particle)
			i += marker.length()
		else:
			out += text[i]
			i += 1
	return out

## The form the word written so far (everything before the marker) calls for.
static func _form(prefix: String, particle: Dictionary) -> String:
	if prefix.is_empty():
		return particle["final"]  # nothing to read: the final-consonant form
	var code := prefix[prefix.length() - 1].unicode_at(0)
	if code < 0xAC00 or code > 0xD7A3:
		return particle["final"]  # digits and Latin read with a final consonant (3을, A이)
	var final_sound := (code - 0xAC00) % 28 != 0
	if final_sound and particle.get("lier", false) and (code - 0xAC00) % 28 == 8:
		return particle["plain"]  # a ㄹ final takes 로: 달로, 서울로
	return particle["final"] if final_sound else particle["plain"]
