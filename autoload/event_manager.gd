extends Node
## EventManager -- owns the deck of historical encounter cards.
##
## Two draw modes, per the historical mapping brief:
##   Fixed cards form the campaign spine. As soon as a fixed card's mile and
##   flag conditions are met it fires automatically (at most one card per
##   turn), in filename order. Mitchell Shaft, for example, is a fixed
##   historical event -- never a random draw or a preventable player failure.
##   Weighted cards are the texture deck: each turn, if no fixed card is due,
##   there is an event_chance roll for one weighted draw among available,
##   not-yet-drawn cards.
##
## Every card fires at most once, unless a resolved choice sets repeat_card
## (e.g. a failed bond vote returns to the deck).

signal event_drawn(card: EventCard)

const EVENTS_DIR := "res://data/events"

@export_range(0.0, 1.0) var event_chance := 0.6

var deck: Array[EventCard] = []
var drawn_ids: Dictionary = {}        # StringName -> true


func _ready() -> void:
	_load_deck()


func reset() -> void:
	drawn_ids = {}


## Called by Journey during the EVENT phase. Returns the card to display,
## or null when this turn has no event. The caller shows the card and then
## reports the player's pick through resolve_choice().
func try_draw() -> EventCard:
	if GameState.game_over:
		return null
	var available := _available_cards()
	for card in available:
		if card.is_fixed:
			return _draw(card)
	if available.is_empty() or randf() > event_chance:
		return null
	return _draw(_weighted_pick(available))


## Applies the player's chosen option and re-arms the card if the choice
## calls for a repeat (failed bond vote).
func resolve_choice(card: EventCard, choice_index: int) -> void:
	var choice: EventChoice = card.choices[clampi(choice_index, 0, card.choices.size() - 1)]
	if choice.repeat_card:
		drawn_ids.erase(card.event_id)
	GameState.apply_choice(choice)


# --- internals ---------------------------------------------------------------

func _available_cards() -> Array[EventCard]:
	var is_winter := GameState.season == GameState.Season.WINTER
	var out: Array[EventCard] = []
	for card in deck:
		if drawn_ids.has(card.event_id):
			continue
		if card.is_available(GameState.miles_built, is_winter, GameState.flags):
			out.append(card)
	return out


func _draw(card: EventCard) -> EventCard:
	drawn_ids[card.event_id] = true
	event_drawn.emit(card)
	return card


func _weighted_pick(pool: Array[EventCard]) -> EventCard:
	var total := 0.0
	for card in pool:
		total += card.weight
	var roll := randf() * total
	for card in pool:
		roll -= card.weight
		if roll <= 0.0:
			return card
	return pool.back()


func _load_deck() -> void:
	deck.clear()
	var dir := DirAccess.open(EVENTS_DIR)
	if dir == null:
		push_warning("EventManager: no events directory at %s" % EVENTS_DIR)
		return
	var files := dir.get_files()
	files.sort()  # numeric filename prefixes define fixed-card firing order
	for file in files:
		if file.ends_with(".tres") or file.ends_with(".tres.remap"):
			var res := load(EVENTS_DIR + "/" + file.trim_suffix(".remap"))
			if res is EventCard:
				deck.append(res)
