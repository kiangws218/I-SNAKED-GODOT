extends GameSession

func _ready() -> void:
	store = SaveStore.new("user://chapter2_preview_saves")
	super._ready()
	# Review fixture only. Normal map entry uses the player's actual history.
	state.flags["prologue_complete"] = true
	state.flags["forest_bridge_open"] = true
	state.actors["buck"]["met"] = true
	state.actors["miro"]["met"] = true
	state.player["length"] = 14
	menus.hide_all()
	hud.visible = true
	await load_map(&"chapter2_slice", &"", false, false)
