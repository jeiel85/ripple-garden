class_name BuildProfile
extends RefCounted

## The three build profiles of TECH_SPEC §18:
##   debug    an editor / debug-template run
##   qa       a build exported with the custom feature tag "qa" (see export preset "Windows QA")
##   release  everything else: no debug menu, no cheats
## Debug tooling is allowed in debug and qa only. DebugService refuses every command in release
## even if something calls it, so a cheat path can never ship active.

static func profile() -> String:
	if OS.has_feature("qa"):
		return "qa"
	if OS.is_debug_build():
		return "debug"
	return "release"

static func debug_tools_enabled() -> bool:
	return profile() != "release"
