extends MeshInstance3D

@export var _visible_in_game := false

func _ready():
	visible = _visible_in_game
