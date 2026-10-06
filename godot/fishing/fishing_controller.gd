class_name FishingController
extends Node

enum State { READY, AIM, CAST, WAIT, BITE_HINT, HOOK, FIGHT, LAND, INSPECT, RELEASE }

signal state_changed(previous: State, current: State)

var state: State = State.READY

func transition(next_state: State) -> void:
    if next_state == state:
        return
    var previous := state
    state = next_state
    state_changed.emit(previous, state)

func reset() -> void:
    transition(State.READY)
