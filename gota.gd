extends RigidBody2D

func _ready() -> void:
	# A gota some sozinha após 10 segundos para não pesar o jogo
	await get_tree().create_timer(10.0).timeout
	queue_free()
