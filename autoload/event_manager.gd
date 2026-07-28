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

# --- Pace-risk tuning (Task 10 balance pass may adjust these) ---------------
const PUSHED_INJURY_CHANCE := 0.30      # base chance of an injury on a PUSHED season
const REST_IMPATIENCE_CHANCE := 0.35    # base chance of impatience on a REST season
const STEADY_MISHAP_CHANCE := 0.10      # low baseline on a STEADY season
const LOW_CREW_THRESHOLD := 4           # crew at/below this amplifies injury risk
const LOW_SUPPORT_THRESHOLD := 4        # support at/below this amplifies impatience
const LOW_METER_RISK_BONUS := 0.25      # added chance when the relevant meter is low
# ----------------------------------------------------------------------------

## Which front a card belongs to, derived from its mile_start. Verified against
## the deck: this distributes the 15 fixed cards 3/2/2/2/3/3 across the six
## fronts, with each front's last card granting that front's completion_flag.
func front_of_card(card: EventCard) -> int:
	for i in GameState.segments.size():
		if GameState.segments[i].contains(float(card.mile_start)):
			return i
	return GameState.segments.size() - 1


## True while a front still owes fixed cards, whatever its progress. A front
## that completes faster than its cards can fire -- only one fixed card is drawn
## per turn -- must stay selectable, or its last card is locked out forever.
## That is how the Pulgas connection became unreachable while every front read
## 100%% complete.
func front_has_pending_fixed(front: int) -> bool:
	for card in _fixed_cards_for_front(front):
		if not drawn_ids.has(card.event_id):
			return true
	return false


## The fixed cards belonging to one front, in filename order.
func _fixed_cards_for_front(front: int) -> Array[EventCard]:
	var out: Array[EventCard] = []
	for card in deck:
		if card.is_fixed and front_of_card(card) == front:
			out.append(card)
	return out

var deck: Array[EventCard] = []
var drawn_ids: Dictionary = {}        # StringName -> true


func _ready() -> void:
	_load_deck()


func reset() -> void:
	drawn_ids = {}


## Cards to resolve this turn, in order. Empty, one, or two entries.
##
## The pace-risk roll runs on EVERY turn, including milestone turns. It used to
## be skipped whenever a fixed card was due, which silenced it: the fixed spine
## occupies 15 of a campaign's 20 turns, so the roll fired on 5. A hazard is
## queued AHEAD of the milestone rather than replacing it, so no card is lost
## and a hazard never costs the player a turn.
func try_draw_queue() -> Array[EventCard]:
	var queue: Array[EventCard] = []
	if GameState.game_over:
		return queue
	var available := _available_cards()
	var risk := _risk_for(GameState.work_pace)
	if randf() < float(risk["chance"]):
		var hazard := _pick_hazard(risk["kind"])
		if hazard != null:
			queue.append(_draw(hazard))
	for card in available:
		if card.is_fixed:
			queue.append(_draw(card))
			return queue
	# A texture card only when no milestone is due.
	if available.is_empty() or randf() > event_chance:
		return queue
	queue.append(_draw(_weighted_pick(available)))
	return queue


## Applies the player's chosen option and re-arms the card if the choice
## calls for a repeat (failed bond vote).
func resolve_choice(card: EventCard, choice_index: int) -> void:
	var choice: EventChoice = card.choices[clampi(choice_index, 0, card.choices.size() - 1)]
	if choice.repeat_card:
		drawn_ids.erase(card.event_id)
	GameState.apply_choice(choice)


## Cards eligible this turn. Fixed cards are gated by progress on their OWN
## front rather than by a global mile counter: a front with three cards fires
## them at 1/3, 2/3 and completion. This is what makes working a front, rather
## than waiting for the next link in a chain, the thing that advances the game.
func _available_cards() -> Array[EventCard]:
	var out: Array[EventCard] = []
	for card in deck:
		if card.hazard_kind != &"":
			continue
		if drawn_ids.has(card.event_id):
			continue
		# A card belongs to a front, and is only eligible while that front is the
		# one being worked. Mile-based availability is incoherent now that
		# miles_built is an aggregate across six parallel fronts rather than the
		# position of a single moving front -- under it, the railroad card
		# (mile_end 20) would expire as soon as any two fronts totalled 20 miles.
		if front_of_card(card) != GameState.current_front:
			continue
		if not card.is_available(GameState.flags):
			continue
		if card.is_fixed and not _threshold_reached(card):
			continue
		out.append(card)
	return out


## Whether any of a card's choices grants the given flag. Flags live on
## EventChoice, not EventCard -- a card grants a flag only through an option the
## player picks.
func _grants(card: EventCard, flag: StringName) -> bool:
	if flag == &"":
		return false
	for choice in card.choices:
		if choice.granted_flags.has(flag):
			return true
	return false


## True when the card's own front has advanced far enough to earn it.
## Evenly spread across the front: three cards fire at 1/3, 2/3 and completion;
## two at 1/2 and completion. The first card requires REAL progress -- a zero
## threshold let a REST turn fire it, and card 06 is the first card on its front
## AND grants mountain_tunnel_complete, so zero work bought a completion flag.
func _threshold_reached(card: EventCard) -> bool:
	var front := front_of_card(card)
	var siblings := _fixed_cards_for_front(front)
	var position := siblings.find(card)
	if position < 0 or siblings.is_empty():
		return true
	# The card that grants this front's completion flag lands at 1.0 wherever it
	# sits in filename order. Front 2 is the one place these differ: card 06
	# grants mountain_tunnel_complete but card 07 is last, so without this the
	# Mountain Tunnel was declared complete at 50%% of its own front.
	var completion: StringName = GameState.segments[front].completion_flag
	if _grants(card, completion):
		return GameState.front_progress[front] >= 1.0 - 0.0001
	var rank := position
	for other in siblings:
		if other == card:
			break
		if _grants(other, completion):
			rank -= 1
	var needed := float(rank + 1) / float(siblings.size())
	return GameState.front_progress[front] >= needed - 0.0001


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


## The dominant hazard kind and roll chance for a pace, given current state.
func _risk_for(pace: int) -> Dictionary:
	match pace:
		GameState.Pace.PUSHED:
			var c := PUSHED_INJURY_CHANCE
			if GameState.crew_wellbeing <= LOW_CREW_THRESHOLD:
				c += LOW_METER_RISK_BONUS
			return {"kind": &"injury", "chance": c}
		GameState.Pace.REST:
			var c := REST_IMPATIENCE_CHANCE
			if GameState.public_support <= LOW_SUPPORT_THRESHOLD:
				c += LOW_METER_RISK_BONUS
			return {"kind": &"impatience", "chance": c}
		_:
			# STEADY: a low chance, aimed at whichever meter is currently weaker.
			if GameState.crew_wellbeing <= GameState.public_support:
				return {"kind": &"injury", "chance": STEADY_MISHAP_CHANCE}
			return {"kind": &"impatience", "chance": STEADY_MISHAP_CHANCE}


## Read-only telegraph for the DecisionPanel (Task 4). No side effects.
func risk_preview(pace: int) -> Dictionary:
	var risk := _risk_for(pace)
	var chance: float = risk["chance"]
	var level: StringName = &"low"
	if chance >= 0.40:
		level = &"high"
	elif chance >= 0.25:
		level = &"elevated"
	return {"kind": risk["kind"], "level": level}


func _hazard_pool(kind: StringName) -> Array[EventCard]:
	var out: Array[EventCard] = []
	for card in deck:
		if card.hazard_kind != kind:
			continue
		if drawn_ids.has(card.event_id):
			continue
		if card.is_available(GameState.flags):
			out.append(card)
	return out


func _pick_hazard(kind: StringName) -> EventCard:
	var pool := _hazard_pool(kind)
	if pool.is_empty():
		return null
	return _weighted_pick(pool)


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
