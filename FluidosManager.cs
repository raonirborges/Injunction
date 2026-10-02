using Godot;
using System;
using System.Collections.Generic;

public partial class FluidosManager : Sprite2D
{
	// ESTRUTURA CELULAR OTIMIZADA PARA MEMÓRIA E CPU
	public struct CelulaLiquido
	{
		public byte Tipo;       // 0=Ar, 1=Água, 2=Explosivo, 3=Sangue, 255=Parede/Sólido
		public byte Volume;     // 0 a 100
		public byte HP;         // 0 a 100 (Vida na briga/Diluição visual)
		public byte MassaGrupo; // Pressão da piscina (0 a 12)
	}

	[Export] public int LarguraGrid = 256;
	[Export] public int AlturaGrid = 144;
	
	// Array de mapas de tiles para colisão perfeita
	[Export] public Godot.Collections.Array<TileMapLayer> TileMapsAlvo { get; set; } = new();

	// CANAL DE SIMULAÇÃO LENTA (Combate e Diluição)
	[Export] public float TempoTickCombate = 0.08f; 
	private float _cronometroCombate = 0f;

	private CelulaLiquido[,] _gridMundo;
	private Image _imagemDados;
	private ImageTexture _texturaDados;

	public override void _Ready()
	{
		_gridMundo = new CelulaLiquido[LarguraGrid, AlturaGrid];
		_imagemDados = Image.CreateEmpty(LarguraGrid, AlturaGrid, false, Image.Format.Rgb8);
		_texturaDados = ImageTexture.CreateFromImage(_imagemDados);
		Texture = _texturaDados;

		MapearColisoesCenario();
		InicializarMundoTeste();
	}

	public override void _Process(double delta)
	{
		// CANAL DE ALTA VELOCIDADE: FÍSICA E GRAVIDADE
		UpdatingFisicaFluxo();

		// CANAL DE BAIXA VELOCIDADE: COMBATE PI-BASEADO
		_cronometroCombate += (float)delta;
		if (_cronometroCombate >= TempoTickCombate)
		{
			AtualizarCombateFluidos();
			_cronometroCombate = 0f;
		}

		// RENDERIZAÇÃO GPU
		for (int x = 0; x < LarguraGrid; x++)
		{
			for (int y = 0; y < AlturaGrid; y++)
			{
				CelulaLiquido celula = _gridMundo[x, y];

				if (celula.Tipo == 255 || celula.Tipo == 0)
				{
					_imagemDados.SetPixel(x, y, new Color(0, 0, 0));
					continue;
				}

				float canalR = celula.Tipo / 255f;
				float canalG = celula.Volume / 100f;
				float canalB = celula.HP / 100f;

				_imagemDados.SetPixel(x, y, new Color(canalR, canalG, canalB));
			}
		}
		_texturaDados.Update(_imagemDados);
	}

	// ==========================================
	// LÓGICA DE FÍSICA E FLUXO CONTRA O TILESET
	// ==========================================
	private void UpdatingFisicaFluxo()
	{
		for (int y = AlturaGrid - 2; y >= 0; y--)
		{
			bool daEsqPraDir = (Engine.GetFramesDrawn() % 2 == 0);

			for (int i = 0; i < LarguraGrid; i++)
			{
				int x = daEsqPraDir ? i : (LarguraGrid - 1 - i);

				if (_gridMundo[x, y].Tipo == 0 || _gridMundo[x, y].Tipo == 255) continue;

				// 1. Cai reto se estiver vazio
				if (TentarMover(x, y, x, y + 1)) continue;

				// 2. Escorre nas diagonais se tiver parede ou líquido parando a queda reta
				int dir1 = daEsqPraDir ? -1 : 1;
				int dir2 = daEsqPraDir ? 1 : -1;
				if (TentarMover(x, y, x + dir1, y + 1)) continue;
				if (TentarMover(x, y, x + dir2, y + 1)) continue;

				// 3. Espalha para as laterais (Nivela a montanha de água no chão)
				if (TentarMover(x, y, x + dir1, y)) continue;
				if (TentarMover(x, y, x + dir2, y)) continue;
			}
		}
	}

	private bool TentarMover(int xAtual, int yAtual, int xNovo, int yNovo)
	{
		if (xNovo < 0 || xNovo >= LarguraGrid || yNovo < 0 || yNovo >= AlturaGrid) return false;

		// A célula de destino precisa ser rigorosamente AR (0)
		if (_gridMundo[xNovo, yNovo].Tipo == 0)
		{
			_gridMundo[xNovo, yNovo] = _gridMundo[xAtual, yAtual];
			_gridMundo[xAtual, yAtual] = new CelulaLiquido { Tipo = 0, Volume = 0, HP = 0, MassaGrupo = 0 };
			return true;
		}
		return false;
	}

	// ==========================================
	// LÓGICA DE COMBATE BASEADA EM PI E MASSA
	// ==========================================
	private void AtualizarCombateFluidos()
	{
		// Cópia temporária para não interferir nas avaliações do mesmo frame
		CelulaLiquido[,] proximoGrid = (CelulaLiquido[,])_gridMundo.Clone();

		for (int x = 1; x < LarguraGrid - 1; x++)
		{
			for (int y = 1; y < AlturaGrid - 1; y++)
			{
				CelulaLiquido celAtual = _gridMundo[x, y];
				if (celAtual.Tipo == 0 || celAtual.Tipo == 255) continue; // Ignora Ar e Parede

				// Atualiza a massa (pressão) calculando a cruz de 3 blocos para trás (desempenho otimizado)
				celAtual.MassaGrupo = CalcularMassaCruz(x, y, celAtual.Tipo);

				// Verifica os 4 vizinhos
				AvaliarCombateVizinho(ref celAtual, _gridMundo[x + 1, y], ref proximoGrid[x, y]);
				AvaliarCombateVizinho(ref celAtual, _gridMundo[x - 1, y], ref proximoGrid[x, y]);
				AvaliarCombateVizinho(ref celAtual, _gridMundo[x, y + 1], ref proximoGrid[x, y]);
				AvaliarCombateVizinho(ref celAtual, _gridMundo[x, y - 1], ref proximoGrid[x, y]);
			}
		}
		_gridMundo = proximoGrid;
	}

	private void AvaliarCombateVizinho(ref CelulaLiquido atual, CelulaLiquido vizinho, ref CelulaLiquido proximoEstado)
	{
		if (vizinho.Tipo == 0 || vizinho.Tipo == 255 || vizinho.Tipo == atual.Tipo) return;

		int poderAtual = ObterPoder(atual.Tipo);
		int poderVizinho = ObterPoder(vizinho.Tipo);
		int diff = poderAtual - poderVizinho;

		bool recebeDano = false;

		// REGRA 1: ÁGUA (4) vs SANGUE (-4). Empate absoluto (8 ou -8). Desempate por Massa.
		if (Mathf.Abs(diff) == 8) 
		{
			if (atual.MassaGrupo < vizinho.MassaGrupo) recebeDano = true;
		}
		// REGRA 2: EXPLOSIVO (1) perde para a ÁGUA (4) ignorando a massa (Massa esmagadora)
		else if (atual.Tipo == 2 && vizinho.Tipo == 1) 
		{
			recebeDano = true;
		}
		// REGRA 3: EXPLOSIVO (1) perde para o SANGUE (-4) 
		else if (atual.Tipo == 2 && vizinho.Tipo == 3) 
		{
			recebeDano = true;
		}

		if (recebeDano)
		{
			// Diluição Visual: Perde 5 de HP por tick lento
			proximoEstado.HP = (byte)Mathf.Max(0, proximoEstado.HP - 5);
			
			// Se zera a vida, ele é engolido e transformado no tipo do vizinho
			if (proximoEstado.HP <= 0)
			{
				proximoEstado.Tipo = vizinho.Tipo;
				proximoEstado.HP = 100; // Renasce purificado no novo fluido
			}
		}
	}

	private int ObterPoder(byte tipo)
	{
		// Tabela de valores decimais estraídos da lógica de PI
		return tipo switch
		{
			1 => 4,   // Água
			2 => 1,   // Explosivo
			3 => -4,  // Sangue
			_ => 0
		};
	}

	private byte CalcularMassaCruz(int originX, int originY, byte tipo)
	{
		// Calcula rapidamente uma cruz de 3 blocos para aplicar "pressão de grupo"
		byte massa = 0;
		for (int offset = 1; offset <= 3; offset++)
		{
			if (originX + offset < LarguraGrid && _gridMundo[originX + offset, originY].Tipo == tipo) massa++;
			if (originX - offset >= 0 && _gridMundo[originX - offset, originY].Tipo == tipo) massa++;
			if (originY + offset < AlturaGrid && _gridMundo[originX, originY + offset].Tipo == tipo) massa++;
			if (originY - offset >= 0 && _gridMundo[originX, originY - offset].Tipo == tipo) massa++;
		}
		return massa;
	}

	// ==========================================
	// SISTEMA DE EXPLOSÃO EM CADEIA INSTANTÂNEA
	// ==========================================
	public void DispararExplosaoChain(int startX, int startY)
	{
		Queue<(int x, int y)> filaExplosao = new Queue<(int x, int y)>();
		filaExplosao.Enqueue((startX, startY));

		while (filaExplosao.Count > 0)
		{
			var (x, y) = filaExplosao.Dequeue();

			if (x < 0 || x >= LarguraGrid || y < 0 || y >= AlturaGrid) continue;

			// Combustão consome o líquido instantaneamente (Tipo 2 -> 0)
			if (_gridMundo[x, y].Tipo != 2) continue;

			_gridMundo[x, y] = new CelulaLiquido { Tipo = 0, Volume = 0, HP = 0, MassaGrupo = 0 };

			filaExplosao.Enqueue((x + 1, y));
			filaExplosao.Enqueue((x - 1, y));
			filaExplosao.Enqueue((x, y + 1));
			filaExplosao.Enqueue((x, y - 1));
		}
	}

	// ==========================================
	// MAPEAMENTO GLOBAL PARA LOCAL DOS TILES
	// ==========================================
	private void MapearColisoesCenario()
	{
		if (TileMapsAlvo == null || TileMapsAlvo.Count == 0) return;

		foreach (TileMapLayer tileMap in TileMapsAlvo)
		{
			if (tileMap == null) continue;

			foreach (Vector2I posCel in tileMap.GetUsedCells())
			{
				Vector2 posMundo = tileMap.ToGlobal(tileMap.MapToLocal(posCel));
				Vector2 posLocal = ToLocal(posMundo);

				int x = Mathf.FloorToInt(posLocal.X);
				int y = Mathf.FloorToInt(posLocal.Y);

				if (x >= 0 && x < LarguraGrid && y >= 0 && y < AlturaGrid)
				{
					_gridMundo[x, y].Tipo = 255; // Marca firmemente o espaço como Sólido (Parede)
				}
			}
		}
	}

	private void InicializarMundoTeste()
	{
		for (int x = 0; x < LarguraGrid; x++)
		{
			for (int y = 0; y < AlturaGrid; y++)
			{
				if (_gridMundo[x, y].Tipo == 255) continue;

				if (y > AlturaGrid / 4 && y < AlturaGrid / 2 && x > 20 && x < LarguraGrid - 20)
				{
					_gridMundo[x, y] = new CelulaLiquido { Tipo = 1, Volume = 100, HP = 100, MassaGrupo = 5 };
				}
				else
				{
					_gridMundo[x, y] = new CelulaLiquido { Tipo = 0, Volume = 0, HP = 0, MassaGrupo = 0 };
				}
			}
		}
	}
}
