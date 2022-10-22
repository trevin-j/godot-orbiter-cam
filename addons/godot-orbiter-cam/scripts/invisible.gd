extends MeshInstance

export(bool) var _visible_in_game := false

func _ready():
	visible = _visible_in_game
