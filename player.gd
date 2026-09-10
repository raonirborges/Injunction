extends CharacterBody2D

const SPEED = 75.0
const JUMP_VELOCITY = -190.0
const FORCA_KNOCKBACK_X = 200.0
const FORCA_KNOCKBACK_Y = -120.0
var sofrendo_knockback: bool = false
var hp: int = 100

@export var cena_gota: PackedScene

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var familiar: AnimatedSprite2D = $Familiar

# Conecta o novo sprite da munição visual que está dentro do Familiar
@onready var municao_visual: Sprite2D = $Familiar/MunicaoVisual

@export var raio_arco: float = 30.0  
@export var altura_pivot: float = -10.0 
var angulo_atual_familiar: float = 0.0

@export var cena_projetil: PackedScene
var municao_atual: int = 1
var municao_maxima: int = 1
var estado_besta: String = "livre"

func _ready() -> void:
	familiar.animation_finished.connect(_on_familiar_animation_finished)
	# Garante que a flecha visual comece aparecendo (já que a munição inicial é 1)
	municao_visual.visible = true

func _physics_process(delta: float) -> void:
	
	if not is_on_floor():
		velocity += get_gravity() * delta

	if not sofrendo_knockback:
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = JUMP_VELOCITY

		var direction := Input.get_axis("ui_left", "ui_right")
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	# Spawna água continuamente na posição do mouse enquanto segura a tecla Z (atirar_agua)
	if Input.is_action_pressed("atirar_agua"):
		spawnar_gota()

	move_and_slide()
	
	controlar_tiro()
	atualizar_animacao()
	atualizar_familiar(delta)

func spawnar_gota() -> void:
	if cena_gota:
		var gota = cena_gota.instantiate()
		get_parent().add_child(gota)
		gota.global_position = get_global_mouse_position()
	else:
		printerr("ERRO: Arraste a cena da gota para o campo 'Cena Gota' no Inspector do Player!")

func controlar_tiro() -> void:
	if estado_besta == "livre":
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and municao_atual > 0:
			atirar()
		elif Input.is_physical_key_pressed(KEY_R) and municao_atual < municao_maxima:
			recarregar()

func atirar() -> void:
	estado_besta = "atirando"
	municao_atual -= 1
	familiar.play("besta_shot")
	
	# Esconde a flecha visual presa na besta imediatamente ao atirar!
	municao_visual.visible = false
	
	if cena_projetil:
		var projetil = cena_projetil.instantiate()
		get_parent().add_child(projetil)
		projetil.global_position = familiar.global_position
		projetil.global_rotation = angulo_atual_familiar
	else:
		printerr("ERRO: Arraste a cena do projetil para o Inspector!")

func recarregar() -> void:
	estado_besta = "recarregando"
	familiar.play("besta_reload")

func _on_familiar_animation_finished() -> void:
	if familiar.animation == "besta_shot":
		estado_besta = "livre"
	elif familiar.animation == "besta_reload":
		municao_atual = municao_maxima
		estado_besta = "livre"
		# Faz a flecha visual voltar a aparecer quando a recarga terminar!
		municao_visual.visible = true

func atualizar_animacao() -> void:
	if velocity.x > 0:
		sprite.flip_h = true
	elif velocity.x < 0:
		sprite.flip_h = false

	if not is_on_floor():
		sprite.play("jump")
	elif abs(velocity.x) > 0:
		sprite.play("walking")
	else:
		sprite.play("idle")

func atualizar_familiar(delta: float) -> void:
	var pos_mouse = get_global_mouse_position()
	var centro_global = global_position + Vector2(0, altura_pivot)
	var centro_local = Vector2(0, altura_pivot)
	var angulo_alvo = centro_global.angle_to_point(pos_mouse)
	
	angulo_atual_familiar = lerp_angle(angulo_atual_familiar, angulo_alvo, 12.0 * delta)
	familiar.position = centro_local + Vector2(cos(angulo_atual_familiar), sin(angulo_atual_familiar)) * raio_arco
	
	familiar.flip_h = false
	familiar.global_rotation = angulo_atual_familiar + (PI / 4.0)

	if estado_besta == "livre":
		if municao_atual > 0:
			familiar.play("idle_ammo")
		else:
			familiar.play("idle_no_ammo")

func levar_dano(quantidade: int, posicao_inimigo: Vector2 = Vector2.ZERO) -> void:
	if sofrendo_knockback: return
	hp -= quantidade
	sofrendo_knockback = true
	if global_position.x >= posicao_inimigo.x: velocity.x = FORCA_KNOCKBACK_X
	else: velocity.x = -FORCA_KNOCKBACK_X
	velocity.y = FORCA_KNOCKBACK_Y
	get_tree().create_timer(0.3).timeout.connect(func(): sofrendo_knockback = false)
	if hp <= 0: queue_free()
