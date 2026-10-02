class_name FluidosManager
extends Sprite2D

# Configurações do tamanho do mundo de fluidos
@export var largura_grid: int = 256
@export var altura_grid: int = 144

# Arraste os nós de TileMapLayer no Inspector para mapear as colisões sólidas
@export var tilemaps_alvo: Array[TileMapLayer] = []

# Frequência do canal de combate lento (Ex: 0.08s = ~12 TPS)
@export var tempo_tick_combate: float = 0.08
var _cronometro_combate: float = 0.0

# Estrutura do Grid (Array 2D nativo em GDScript)
# Cada célula guarda um Dictionary com: { "tipo": int, "volume": int, "hp": int, "massa": int }
var _grid_mundo: Array = []

# Variáveis para a Ponte de Dados com a GPU
var _imagem_dados: Image
var _textura_dados: ImageTexture

func _ready() -> void:
	# Inicializa a matriz 2D
	_grid_mundo.resize(largura_grid)
	for x in range(largura_grid):
		_grid_mundo[x] = []
		_grid_mundo[x].resize(altura_grid)
		for y in range(altura_grid):
			_grid_mundo[x][y] = { "tipo": 0, "volume": 0, "hp": 0, "massa": 0 }

	# Prepara a textura Rgb8 dinâmica
	_imagem_dados = Image.create_empty(largura_grid, altura_grid, false, Image.FORMAT_RGB8)
	_textura_dados = ImageTexture.create_from_image(_imagem_dados)
	texture = _textura_dados

	# Mapeia as colisões dos TileMaps para o grid
	mapear_colisoes_cenario()
	
	# Preenche o mundo com uma massa de teste
	inicializar_mundo_teste()

func _process(delta: float) -> void:
	# 1. CANAL RÁPIDO: Física de Fluxo e Gravidade (60 FPS)
	atualizar_fisica_fluxo()

	# 2. CANAL LENTO: Combate de Fluidos e Diluição
	_cronometro_combate += delta
	if _cronometro_combate >= tempo_tick_combate:
		atualizar_combate_fluidos()
		_cronometro_combate = 0.0

	# 3. RENDERIZAÇÃO: Traduzindo a CPU para a GPU
	for x in range(largura_grid):
		for y in range(altura_grid):
			var celula: Dictionary = _grid_mundo[x][y]

			if celula.tipo == 255 or celula.tipo == 0:
				_imagem_dados.set_pixel(x, y, Color(0, 0, 0))
				continue

			var canal_r: float = celula.tipo / 255.0
			var canal_g: float = celula.volume / 100.0
			var canal_b: float = celula.hp / 100.0

			_imagem_dados.set_pixel(x, y, Color(canal_r, canal_g, canal_b))

	_textura_dados.update(_imagem_dados)

# ==========================================
# FÍSICA CELULAR E GRAVIDADE
# ==========================================
func atualizar_fisica_fluxo() -> void:
	# Varre de baixo para cima para evitar queda dupla no mesmo frame
	for y in range(altura_grid - 2, -1, -1):
		var da_esq_pra_dir: bool = (Engine.get_frames_drawn() % 2 == 0)

		for i in range(largura_grid):
			var x: int = i if da_esq_pra_dir else (largura_grid - 1 - i)
			var celula: Dictionary = _grid_mundo[x][y]

			if celula.tipo == 0 or celula.tipo == 255:
				continue

			# 1. Cai reto se estiver vazio
			if tentar_mover(x, y, x, y + 1):
				continue

			# 2. Escorre nas diagonais
			var dir1: int = -1 if da_esq_pra_dir else 1
			var dir2: int = 1 if da_esq_pra_dir else -1
			if tentar_mover(x, y, x + dir1, y + 1):
				continue
			if tentar_mover(x, y, x + dir2, y + 1):
				continue

			# 3. Espalha nas laterais para nivelar a superfície
			if tentar_mover(x, y, x + dir1, y):
				continue
			if tentar_mover(x, y, x + dir2, y):
				continue

func tentar_mover(x_atual: int, y_atual: int, x_novo: int, y_novo: int) -> bool:
	if x_novo < 0 or x_novo >= largura_grid or y_novo < 0 or y_novo >= altura_grid:
		return false

	# Só move se o destino for AR (0)
	if _grid_mundo[x_novo][y_novo].tipo == 0:
		_grid_mundo[x_novo][y_novo] = _grid_mundo[x_atual][y_atual].duplicate()
		_grid_mundo[x_atual][y_atual] = { "tipo": 0, "volume": 0, "hp": 0, "massa": 0 }
		return true
		
	return false

# ==========================================
# LÓGICA DE COMBATE BASEADA EM PI E MASSA
# ==========================================
func atualizar_combate_fluidos() -> void:
	# Cria uma cópia profunda para não interferir na verificação simultânea
	var proximo_grid: Array = []
	proximo_grid.resize(largura_grid)
	for x in range(largura_grid):
		proximo_grid[x] = []
		proximo_grid[x].resize(altura_grid)
		for y in range(altura_grid):
			proximo_grid[x][y] = _grid_mundo[x][y].duplicate()

	for x in range(1, largura_grid - 1):
		for y in range(1, altura_grid - 1):
			var cel_atual: Dictionary = _grid_mundo[x][y]
			if cel_atual.tipo == 0 or cel_atual.tipo == 255:
				continue

			# Recalcula a pressão/massa da piscina em cruz
			cel_atual.massa = calcular_massa_cruz(x, y, cel_atual.tipo)

			# Avalia a briga com os 4 vizinhos diretos
			avaliar_combate_vizinho(cel_atual, _grid_mundo[x + 1][y], proximo_grid[x][y])
			avaliar_combate_vizinho(cel_atual, _grid_mundo[x - 1][y], proximo_grid[x][y])
			avaliar_combate_vizinho(cel_atual, _grid_mundo[x][y + 1], proximo_grid[x][y])
			avaliar_combate_vizinho(cel_atual, _grid_mundo[x][y - 1], proximo_grid[x][y])

	_grid_mundo = proximo_grid

func avaliar_combate_vizinho(atual: Dictionary, vizinho: Dictionary, proximo_estado: Dictionary) -> void:
	if vizinho.tipo == 0 or vizinho.tipo == 255 or vizinho.tipo == atual.tipo:
		return

	var poder_atual: int = obter_poder(atual.tipo)
	var poder_vizinho: int = obter_poder(vizinho.tipo)
	var diff: int = poder_atual - poder_vizinho

	var recebe_dano: bool = false

	# REGRA 1: ÁGUA (4) vs SANGUE (-4). Empate absoluto (|diff| = 8). Desempate por Massa.
	if abs(diff) == 8:
		if atual.massa < vizinho.massa:
			recebe_dano = true
	# REGRA 2: EXPLOSIVO (1) perde para a ÁGUA (4) ignorando a massa
	elif atual.tipo == 2 and vizinho.tipo == 1:
		recebe_dano = true
	# REGRA 3: EXPLOSIVO (1) perde para o SANGUE (-4)
	elif atual.tipo == 2 and vizinho.tipo == 3:
		recebe_dano = true

	if recebe_dano:
		# Perde 5 HP por tick de combate (efeito visual de tinta se diluindo)
		proximo_estado.hp = max(0, proximo_estado.hp - 5)
		
		# Se zera o HP, a célula é completamente convertida no fluido vencedor
		if proximo_estado.hp <= 0:
			proximo_estado.tipo = vizinho.tipo
			proximo_estado.hp = 100

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
# EXPLOSÃO INSTANTÂNEA EM CADEIA
# ==========================================
func disparar_explosao_chain(start_x: int, start_y: int) -> void:
	var fila_explosao: Array = [Vector2i(start_x, start_y)]

	while fila_explosao.size() > 0:
		var pos: Vector2i = fila_explosao.pop_front()
		var x: int = pos.x
		var y: int = pos.y

		if x < 0 or x >= largura_grid or y < 0 or y >= altura_grid:
			continue

		# Se não for explosivo (2), ignora
		if _grid_mundo[x][y].tipo != 2:
			continue

		# Consome o combustível imediatamente
		_grid_mundo[x][y] = { "tipo": 0, "volume": 0, "hp": 0, "massa": 0 }

		# Dispara em cadeia para os 4 cantos no mesmo frame
		fila_explosao.append(Vector2i(x + 1, y))
		fila_explosao.append(Vector2i(x - 1, y))
		fila_explosao.append(Vector2i(x, y + 1))
		fila_explosao.append(Vector2i(x, y - 1))

# ==========================================
# MAPEAMENTO DE COLISÃO DO TILESET
# ==========================================
func mapear_colisoes_cenario() -> void:
	if tilemaps_alvo.is_empty():
		return

	for tilemap in tilemaps_alvo:
		if tilemap == null:
			continue

		for pos_cel in tilemap.get_used_cells():
			var pos_mundo: Vector2 = tilemap.to_global(tilemap.map_to_local(pos_cel))
			var pos_local: Vector2 = to_local(pos_mundo)

			var x: int = floor(pos_local.x)
			var y: int = floor(pos_local.y)

			if x >= 0 and x < largura_grid and y >= 0 and y < altura_grid:
				_grid_mundo[x][y].tipo = 255 # Marca como Sólido/Parede

func inicializar_mundo_teste() -> void:
	for x in range(largura_grid):
		for y in range(altura_grid):
			if _grid_mundo[x][y].tipo == 255:
				continue

			if y > altura_grid / 4 and y < altura_grid / 2 and x > 20 and x < largura_grid - 20:
				_grid_mundo[x][y] = { "tipo": 1, "volume": 100, "hp": 100, "massa": 5 } # Água
			else:
				_grid_mundo[x][y] = { "tipo": 0, "volume": 0, "hp": 0, "massa": 0 }     # Ar

# ==========================================
# INTERAÇÃO COM O JOGADOR / ENTIDADES
# ==========================================
func verificar_fluido_na_posicao(posicao_global: Vector2) -> int:
	var pos_local: Vector2 = to_local(posicao_global)
	var x: int = floor(pos_local.x)
	var y: int = floor(pos_local.y)

	if x >= 0 and x < largura_grid and y >= 0 and y < altura_grid:
		return _grid_mundo[x][y].tipo
	return 0
