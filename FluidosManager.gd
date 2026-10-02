extends Sprite2D

@export var largura_grid: int = 320
@export var altura_grid: int = 180
@export var tilemaps_alvo: Array[TileMapLayer] = []
@export var tempo_tick_combate: float = 0.08
@export var fps_simulacao: float = 30.0 # Controla a frequência da física para salvar CPU

var _cronometro_fisica: float = 0.0
var _intervalo_fisica: float = 1.0 / 30.0
var _cronometro_combate: float = 0.0

var _grid_mundo: Array = []
var _imagem_dados: Image
var _textura_dados: ImageTexture
var _buffer_pixels: PackedByteArray

# Bounding Box Ativo para evitar iterar sobre 57.600 células vazias
var _min_x_ativo: int = 0
var _max_x_ativo: int = 319
var _min_y_ativo: int = 0
var _max_y_ativo: int = 179

func _ready() -> void:
	_intervalo_fisica = 1.0 / fps_simulacao

	# Inicialização da Matriz
	_grid_mundo.resize(largura_grid)
	for x in range(largura_grid):
		_grid_mundo[x] = []
		_grid_mundo[x].resize(altura_grid)
		for y in range(altura_grid):
			_grid_mundo[x][y] = { "tipo": 0, "volume": 0, "hp": 0, "massa": 0 }

	_buffer_pixels.resize(largura_grid * altura_grid * 3)
	_imagem_dados = Image.create_empty(largura_grid, altura_grid, false, Image.FORMAT_RGB8)
	_textura_dados = ImageTexture.create_from_image(_imagem_dados)
	texture = _textura_dados

	mapear_colisoes_cenario()
	inicializar_mundo_teste()

func _process(delta: float) -> void:
	_cronometro_fisica += delta
	if _cronometro_fisica >= _intervalo_fisica:
		atualizar_fisica_fluxo()
		_cronometro_fisica = 0.0

	_cronometro_combate += delta
	if _cronometro_combate >= tempo_tick_combate:
		atualizar_combate_fluidos()
		_cronometro_combate = 0.0

	renderizar_otimizado()

# ==========================================
# RENDERIZAÇÃO OTIMIZADA VIA BUFFER
# ==========================================
func renderizar_otimizado() -> void:
	var idx: int = 0
	for y in range(altura_grid):
		for x in range(largura_grid):
			var celula: Dictionary = _grid_mundo[x][y]

			if celula.tipo == 255 or celula.tipo == 0:
				_buffer_pixels[idx] = 0
				_buffer_pixels[idx + 1] = 0
				_buffer_pixels[idx + 2] = 0
			else:
				_buffer_pixels[idx] = celula.tipo
				_buffer_pixels[idx + 1] = int(celula.volume * 2.55)
				_buffer_pixels[idx + 2] = int(celula.hp * 2.55)

			idx += 3

	_imagem_dados.set_data(largura_grid, altura_grid, false, Image.FORMAT_RGB8, _buffer_pixels)
	_textura_dados.update(_imagem_dados)

# ==========================================
# MAPEAMENTO DE COLISÃO COM OFFSET DE ANCORAGEM
# ==========================================
func mapear_colisoes_cenario() -> void:
	if tilemaps_alvo.is_empty():
		return

	for x in range(largura_grid):
		for y in range(altura_grid):
			if _grid_mundo[x][y].tipo == 255:
				_grid_mundo[x][y].tipo = 0

	var offset_canto: Vector2 = Vector2.ZERO
	if centered:
		offset_canto = Vector2(largura_grid * scale.x, altura_grid * scale.y) / 2.0

	for tilemap in tilemaps_alvo:
		if tilemap == null: continue

		for pos_cel in tilemap.get_used_cells():
			var pos_global_tile: Vector2 = tilemap.to_global(tilemap.map_to_local(pos_cel))
			var pos_local: Vector2 = to_local(pos_global_tile) + offset_canto - Vector2(4, 4)

			var start_x: int = int(round(pos_local.x / scale.x))
			var start_y: int = int(round(pos_local.y / scale.y))

			var tamanho_em_celulas_x: int = max(1, int(round(8.0 / scale.x)))
			var tamanho_em_celulas_y: int = max(1, int(round(8.0 / scale.y)))

			for dx in range(tamanho_em_celulas_x):
				for dy in range(tamanho_em_celulas_y):
					var gx: int = start_x + dx
					var gy: int = start_y + dy

					if gx >= 0 and gx < largura_grid and gy >= 0 and gy < altura_grid:
						_grid_mundo[gx][gy].tipo = 255

# ==========================================
# FÍSICA E NIVELAMENTO LÍQUIDO
# ==========================================
func atualizar_fisica_fluxo() -> void:
	var novo_min_x: int = largura_grid
	var novo_max_x: int = 0
	var novo_min_y: int = altura_grid
	var novo_max_y: int = 0

	for y in range(altura_grid - 2, -1, -1):
		var da_esq_pra_dir: bool = (Engine.get_frames_drawn() % 2 == 0)

		for i in range(largura_grid):
			var x: int = i if da_esq_pra_dir else (largura_grid - 1 - i)
			var celula: Dictionary = _grid_mundo[x][y]

			if celula.tipo == 0 or celula.tipo == 255:
				continue

			# Acompanha o Bounding Box ativo
			novo_min_x = min(novo_min_x, x)
			novo_max_x = max(novo_max_x, x)
			novo_min_y = min(novo_min_y, y)
			novo_max_y = max(novo_max_y, y)

			# 1. Gravidade Reta (Baixo)
			if tentar_mover(x, y, x, y + 1): continue

			# 2. Diagonais
			var dir1: int = -1 if da_esq_pra_dir else 1
			var dir2: int = 1 if da_esq_pra_dir else -1

			if tentar_mover(x, y, x + dir1, y + 1): continue
			if tentar_mover(x, y, x + dir2, y + 1): continue

			# 3. Flutuabilidade Lateral Avançada (Desfaz morrinhos)
			if escorrer_lateral_longo(x, y, dir1): continue
			if escorrer_lateral_longo(x, y, dir2): continue

func escorrer_lateral_longo(x: int, y: int, direcao: int) -> bool:
	# Procura até 3 casas de distância por uma depressão/buraco
	for distancia in range(1, 4):
		var target_x: int = x + (direcao * distancia)
		if target_x < 0 or target_x >= largura_grid:
			break

		# Encontrou parede, para a busca nessa direção
		if _grid_mundo[target_x][y].tipo == 255:
			break

		# Se encontrou um espaço vazio abaixo da linha ou ao lado, escorre pra lá
		if _grid_mundo[target_x][y + 1].tipo == 0:
			return tentar_mover(x, y, x + direcao, y)
		elif _grid_mundo[target_x][y].tipo == 0:
			return tentar_mover(x, y, target_x, y)

	return false

func tentar_mover(x_atual: int, y_atual: int, x_novo: int, y_novo: int) -> bool:
	if x_novo < 0 or x_novo >= largura_grid or y_novo < 0 or y_novo >= altura_grid:
		return false

	if _grid_mundo[x_novo][y_novo].tipo == 0:
		_grid_mundo[x_novo][y_novo].tipo = _grid_mundo[x_atual][y_atual].tipo
		_grid_mundo[x_novo][y_novo].volume = _grid_mundo[x_atual][y_atual].volume
		_grid_mundo[x_novo][y_novo].hp = _grid_mundo[x_atual][y_atual].hp
		_grid_mundo[x_novo][y_novo].massa = _grid_mundo[x_atual][y_atual].massa

		_grid_mundo[x_atual][y_atual].tipo = 0
		_grid_mundo[x_atual][y_atual].volume = 0
		_grid_mundo[x_atual][y_atual].hp = 0
		_grid_mundo[x_atual][y_atual].massa = 0
		return true

	return false

# ==========================================
# LÓGICA DE COMBATE E REAÇÕES
# ==========================================
func atualizar_combate_fluidos() -> void:
	for x in range(1, largura_grid - 1):
		for y in range(1, altura_grid - 1):
			var cel_atual: Dictionary = _grid_mundo[x][y]
			if cel_atual.tipo == 0 or cel_atual.tipo == 255:
				continue

			cel_atual.massa = calcular_massa_cruz(x, y, cel_atual.tipo)

			avaliar_combate_vizinho(cel_atual, _grid_mundo[x + 1][y])
			avaliar_combate_vizinho(cel_atual, _grid_mundo[x - 1][y])
			avaliar_combate_vizinho(cel_atual, _grid_mundo[x][y + 1])
			avaliar_combate_vizinho(cel_atual, _grid_mundo[x][y - 1])

func avaliar_combate_vizinho(atual: Dictionary, vizinho: Dictionary) -> void:
	if vizinho.tipo == 0 or vizinho.tipo == 255 or vizinho.tipo == atual.tipo:
		return

	var diff: int = obter_poder(atual.tipo) - obter_poder(vizinho.tipo)
	var recebe_dano: bool = false

	if abs(diff) == 8:
		if atual.massa < vizinho.massa: recebe_dano = true
	elif atual.tipo == 2 and (vizinho.tipo == 1 or vizinho.tipo == 3):
		recebe_dano = true

	if recebe_dano:
		atual.hp = max(0, atual.hp - 5)
		if atual.hp <= 0:
			atual.tipo = vizinho.tipo
			atual.hp = 100

func obter_poder(tipo: int) -> int:
	match tipo:
		1: return 4   # Água
		2: return 1   # Explosivo
		3: return -4  # Sangue
		_: return 0

func calcular_massa_cruz(origin_x: int, origin_y: int, tipo: int) -> int:
	var massa: int = 0
	for offset in range(1, 4):
		if origin_x + offset < largura_grid and _grid_mundo[origin_x + offset][origin_y].tipo == tipo: massa += 1
		if origin_x - offset >= 0 and _grid_mundo[origin_x - offset][origin_y].tipo == tipo: massa += 1
		if origin_y + offset < altura_grid and _grid_mundo[origin_x][origin_y + offset].tipo == tipo: massa += 1
		if origin_y - offset >= 0 and _grid_mundo[origin_x][origin_y - offset].tipo == tipo: massa += 1
	return massa

# ==========================================
# TESTE INICIAL
# ==========================================
func inicializar_mundo_teste() -> void:
	for x in range(largura_grid):
		for y in range(altura_grid):
			if _grid_mundo[x][y].tipo == 255:
				continue

			if y > 5 and y < 30 and x > (largura_grid / 2 - 25) and x < (largura_grid / 2 + 25):
				_grid_mundo[x][y] = { "tipo": 1, "volume": 100, "hp": 100, "massa": 5 }
