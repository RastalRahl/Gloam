extends Node
class_name GloamRunPhaseDirector

## Owns the run's phase/day identity.  It does not perform world side effects;
## the composition root reacts to these explicit transitions and starts the
## relevant world systems.

enum Phase { DAY, NIGHT, VICTORY }

signal phase_changed(phase: int, day: int)

var phase: int = Phase.DAY
var day: int = 1
var completed_nights: int = 0
var run_started: bool = false
var nights_to_survive: int = 10


func configure(total_nights: int) -> void:
	nights_to_survive = maxi(1, total_nights)


func start_run() -> void:
	run_started = true
	enter_day()


func enter_day() -> void:
	phase = Phase.DAY
	phase_changed.emit(phase, day)


func enter_night() -> void:
	phase = Phase.NIGHT
	phase_changed.emit(phase, day)


func complete_regular_night() -> void:
	completed_nights += 1
	day += 1
	enter_day()


func enter_victory() -> void:
	phase = Phase.VICTORY
	phase_changed.emit(phase, day)
