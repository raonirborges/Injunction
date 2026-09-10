extends TileMapLayer

@export var parede_map: TileMapLayer # Arraste o ParedeMap aqui pelo Inspector

const TILE_AGUA = Vector2i(0, 0) # Coordenada do quadrado azul no seu TileSet
const SOURCE_ID = 0

var celulas_ativas: Array[Vector2i] = []

func _ready():
	# 1. Varre o mapa inteiro e força TODA célula de água a entrar na lista de ativas
	var celulas_pintadas = get_used_cells()
	for celula in celulas_pintadas:
		if get_cell_source_id(celula) == SOURCE_ID:
			if not celulas_ativas.has(celula):
				celulas_ativas.append(celula)

	# 2. Cria o timer via código para atualizar a simulação em "ticks"
	var timer = Timer.new()
	timer.wait_time = 0.05 # Velocidade que a água escorre
	timer.autostart = true
	timer.timeout.connect(simular_liquido)
	add_child(timer)

# Use esta função para spawnar água no mundo (conecte num botão, clique do mouse ou cano)
func adicionar_liquido(posicao_global: Vector2):
	var celula = local_to_map(posicao_global)
	if not celulas_ativas.has(celula):
		set_cell(celula, SOURCE_ID, TILE_AGUA)
		celulas_ativas.append(celula)

func simular_liquido():
	var novas_celulas: Array[Vector2i] = []
	var celulas_removidas: Array[Vector2i] = []

	# Processa de baixo para cima para a água cair de forma consistente
	celulas_ativas.sort_custom(func(a, b): return a.y > b.y)

	for celula in celulas_ativas:
		var baixo = celula + Vector2i(0, 1)
		var esquerda = celula + Vector2i(-1, 0)
		var direita = celula + Vector2i(1, 0)

		# 1. Tenta cair primeiro
		if celula_vazia(baixo):
			mover_agua(celula, baixo, novas_celulas, celulas_removidas)
			continue

		# 2. Se bateu no chão, tenta escorrer para os lados
		var pode_esq = celula_vazia(esquerda)
		var pode_dir = celula_vazia(direita)

		if pode_esq and pode_dir:
			if randf() > 0.5:
				mover_agua(celula, esquerda, novas_celulas, celulas_removidas)
			else:
				mover_agua(celula, direita, novas_celulas, celulas_removidas)
		elif pode_esq:
			mover_agua(celula, esquerda, novas_celulas, celulas_removidas)
		elif pode_dir:
			mover_agua(celula, direita, novas_celulas, celulas_removidas)
		else:
			# 3. SE NÃO PODE CAIR NEM ESCORRER: Remove da lista de ativas (ela descansou!)
			celulas_removidas.append(celula)

	# Atualiza o registro de quais blocos de água ainda estão em movimento
	for c in celulas_removidas:
		celulas_ativas.erase(c)
	for c in novas_celulas:
		if not celulas_ativas.has(c):
			celulas_ativas.append(c)

	for celula in celulas_ativas:
		var baixo = celula + Vector2i(0, 1)
		var esquerda = celula + Vector2i(-1, 0)
		var direita = celula + Vector2i(1, 0)

		# 1. Tenta cair primeiro (Gravidade do autômato celular)
		if celula_vazia(baixo):
			mover_agua(celula, baixo, novas_celulas, celulas_removidas)
			continue

		# 2. Se bateu no chão, tenta escorrer para os lados
		var pode_esq = celula_vazia(esquerda)
		var pode_dir = celula_vazia(direita)

		if pode_esq and pode_dir:
			# Espalha aleatoriamente para parecer natural
			if randf() > 0.5:
				mover_agua(celula, esquerda, novas_celulas, celulas_removidas)
			else:
				mover_agua(celula, direita, novas_celulas, celulas_removidas)
		elif pode_esq:
			mover_agua(celula, esquerda, novas_celulas, celulas_removidas)
		elif pode_dir:
			mover_agua(celula, direita, novas_celulas, celulas_removidas)

	# Atualiza o registro de quais blocos de água ainda estão em movimento
	for c in celulas_removidas:
		celulas_ativas.erase(c)
	for c in novas_celulas:
		if not celulas_ativas.has(c):
			celulas_ativas.append(c)

func celula_vazia(celula: Vector2i) -> bool:
	# Falso se bater em parede
	if parede_map and parede_map.get_cell_source_id(celula) != -1:
		return false
	# Falso se já houver água neste bloco
	if get_cell_source_id(celula) != -1:
		return false
	return true

func mover_agua(de: Vector2i, para: Vector2i, novas: Array, removidas: Array):
	set_cell(de, -1, Vector2i(-1, -1)) # Apaga do local antigo
	set_cell(para, SOURCE_ID, TILE_AGUA) # Cria no local novo
	removidas.append(de)
	novas.append(para)
