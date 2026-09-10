extends Area2D

const VELOCIDADE = 600.0
var voando: bool = true

# Pegamos referências dos nós da cena
@onready var sprite: Sprite2D = $Sprite2D
@onready var shape_dano: CollisionShape2D = $CollisionShape2D
@onready var plataforma_shape: CollisionShape2D = $StaticBody2D/CollisionShape2D

func _ready() -> void:
	# 1. Começa com a plataforma desativada (para não empurrar o player enquanto voa)
	plataforma_shape.set_deferred("disabled", true)
	
	# 2. Conecta o sinal de colisão automaticamente
	body_entered.connect(_on_body_entered)
	
	# 3. Trava de segurança: se a flecha for atirada pro vazio infinito, some após 10s
	get_tree().create_timer(10.0).timeout.connect(func(): if voando: queue_free())

func _physics_process(delta: float) -> void:
	# Só move para frente se ainda estiver voando
	if voando:
		position += transform.x * VELOCIDADE * delta

# Função chamada no exato frame que a flecha encosta em algo físico
func _on_body_entered(body: Node2D) -> void:
	# Checa se ainda está voando e se bateu no cenário (TileMapLayer ou outro StaticBody2D)
	# (Isso impede que a flecha grude no próprio Player ou em inimigos)
	if voando and (body is TileMapLayer or body is StaticBody2D):
		voando = false # Faz a flecha parar de se mover
		
		# Desativa o "fantasma" que detecta impacto para evitar bugs
		shape_dano.set_deferred("disabled", true)
		
		# Ativa a nossa plataforma física para o player poder subir
		plataforma_shape.set_deferred("disabled", false)
		
		# Inicia a contagem regressiva para sumir
		iniciar_fade_out()

func iniciar_fade_out() -> void:
	# Espera os 5 segundos com a flecha cravada na parede
	await get_tree().create_timer(5.0).timeout
	
	# Cria uma animação suave via código (Tween) para desaparecer
	var tween = create_tween()
	# Faz a opacidade (modulate:a) do projétil inteiro ir de 100% para 0% em 1 segundo
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	
	# Quando o efeito de sumir (fade-out) terminar, deleta o projétil do jogo
	# Em vez de colocar tudo em uma linha, separamos para o Godot entender melhor:
	tween.finished.connect(_on_tween_finished)

# Adicione esta função fora da iniciar_fade_out (lá no final do script)
func _on_tween_finished() -> void:
	queue_free()
