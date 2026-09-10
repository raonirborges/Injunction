extends RigidBody2D

# Destrói a gota se cair muito fundo ou passar do tempo para economizar memória
func _ready() -> void:
	await get_tree().create_timer(15.0).timeout
	queue_free()
