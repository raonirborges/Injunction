extends CharacterBody2D

@export var dano: int = 10
@export var velocidade: float = 50.0        # Velocidade moderada
@export var distancia_patrulha: float = 50.0 # Alcance de 100 pra cada lado

var posicao_inicial_x: float
var direcao: int = 1 # 1 = move para a direita | -1 = move para a esquerda

func _ready() -> void:
	# Guarda a posição X original de onde o inimigo foi posicionado na cena
	posicao_inicial_x = global_position.x

func _physics_process(delta: float) -> void:
	# 1. GRAVIDADE: Se não estiver no chão, cai usando a gravidade do projeto
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 2. MOVIMENTO DE PATRULHA:
	# Se andou 100 pixels para a direita (+100), vira para a esquerda (-1)
	if global_position.x >= posicao_inicial_x + distancia_patrulha:
		direcao = -1
	# Se andou 100 pixels para a esquerda (-100), vira para a direita (1)
	elif global_position.x <= posicao_inicial_x - distancia_patrulha:
		direcao = 1

	# Bônus: Se bater em uma parede no caminho, inverte a direção na hora
	if is_on_wall():
		direcao *= -1

	# Aplica a velocidade horizontal
	velocity.x = direcao * velocidade

	# Aplica a física (movimento + gravidade)
	move_and_slide()

# Função conectada ao sinal body_entered da Area2D
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.has_method("levar_dano"):
		body.levar_dano(dano, global_position)
