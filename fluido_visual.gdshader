shader_type canvas_item;

uniform vec4 cor_agua : source_color = vec4(0.1, 0.4, 0.9, 0.85);       // Tipo 1
uniform vec4 cor_explosivo : source_color = vec4(0.9, 0.6, 0.1, 0.9);   // Tipo 2
uniform vec4 cor_sangue : source_color = vec4(0.8, 0.05, 0.1, 0.9);     // Tipo 3

void fragment() {
	vec4 dados = texture(TEXTURE, UV);
	
	// Converte de volta os canais normalizados (0.0 a 1.0) para valores de 0 a 255
	int tipo = int(round(dados.r * 255.0));
	float volume = dados.g;
	float hp = dados.b;

	if (tipo == 0 || tipo == 255 || volume <= 0.0) {
		COLOR = vec4(0.0);
	} 
	else {
		vec4 cor_base = vec4(0.0);

		if (tipo == 1) {
			cor_base = cor_agua;
		} 
		else if (tipo == 2) {
			cor_base = cor_explosivo;
		} 
		else if (tipo == 3) {
			cor_base = cor_sangue;
		}

		cor_base.a *= mix(0.3, 1.0, hp);
		COLOR = vec4(cor_base.rgb, cor_base.a * clamp(volume * 1.2, 0.0, 1.0));
	}
}