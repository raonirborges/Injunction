shader_type canvas_item;

// 1. CONFIGURAÇÃO DE CORES (Você pode mudar essas cores direto no Inspector do Godot!)
uniform vec4 cor_agua : source_color = vec4(0.0, 0.4, 0.9, 1.0);       // Azul
uniform vec4 cor_explosivo : source_color = vec4(0.1, 0.8, 0.2, 1.0);  // Verde/Amarelo
uniform vec4 cor_sangue : source_color = vec4(0.7, 0.0, 0.0, 1.0);     // Vermelho escuro

void fragment() {
    // 2. LEITURA DOS DADOS TRANSMITIDOS PELO C#
    // Pega a cor do pixel atual enviado pela CPU
    vec4 dados_celula = texture(TEXTURE, UV);
    
    // Multiplica de volta para descobrir os valores originais que guardamos
    int tipo = int(round(dados_celula.r * 255.0));
    float volume = dados_celula.g;
    float hp = dados_celula.b; // Vai de 0.0 a 1.0

    // Se o tipo for Ar (0) ou não tiver volume, o shader descarta o pixel (fica invisível)
    if (tipo == 0 || volume == 0.0) {
        discard;
    }

    // 3. DETERMINAÇÃO DA COR BASE E EFEITO DE DILUIÇÃO (CORANTE)
    vec4 cor_final = vec4(0.0);

    if (tipo == 1) {
        // ÁGUA: Se o HP cair, mistura gradualmente com a cor do Sangue
        cor_final = mix(cor_sangue, cor_agua, hp);
    }
    else if (tipo == 2) {
        // LÍQUIDO EXPLOSIVO: Mantém a cor estável
        cor_final = cor_explosivo;
    }
    else if (tipo == 3) {
        // SANGUE: Se o HP cair, mistura gradualmente com a cor da Água
        cor_final = mix(cor_agua, cor_sangue, hp);
    }

    // 4. CORTE DO NÍVEL DO VOLUME DO LÍQUIDO
    // O UV.y vai de 0.0 (topo do bloco) a 1.0 (base do bloco)
    // Se a posição atual for maior que o volume guardado, o pixel desaparece.
    // Isso faz com que blocos com volume 0.5 preencham apenas metade do pixel art!
    if (1.0 - UV.y > volume) {
        discard;
    }

    // Aplica a cor final calculada com degradê na tela
    COLOR = vec4(cor_final.rgb, 0.5);
}
