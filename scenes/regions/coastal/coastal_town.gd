extends Region
## Coastal Town — the reference region (build step 3). Everything the town
## *does* is wired here; the layout lives in coastal_town.tscn.
##
## Layout follows assets/map/map_coastal.png at 3x (see docs/map-layout.md):
## road in from the east, inn, market, tide pools under the cliff, cliff
## stairs up to the lookout and lighthouse, harbour on the south shore.

@onready var _harbour_exit: Interactable = $Objects/HarbourExit


func _ready() -> void:
	super()
	_harbour_exit.interacted.connect(_on_harbour_exit)


func _on_harbour_exit(_interactor: Node2D) -> void:
	# The boat to the forest opens with Sable's key gift (her restored
	# lantern lights the harbour). Until then it just waits.
	Dialogue.say("", [
		"The old fishing boat knocks gently against the pier.",
		"It isn't going anywhere yet.",
	])
