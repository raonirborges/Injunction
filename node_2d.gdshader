shader_type canvas_item;

// Primeira cor de fundo
uniform vec4 color_chave_1 : source_color = vec4(0.0, 1.0, 0.0, 1.0);
// Segunda cor de fundo
uniform vec4 color_chave_2 : source_color = vec4(1.0, 0.0, 1.0, 1.0);

// Margem de erro para limpezas de borda
uniform float tolerancia : hint_range(0.0, 1.0) = 0.1;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Se a cor do pixel for parecida com a COR 1 **OU** com a COR 2, apaga o pixel
	if (distance(tex_color.rgb, color_chave_1.rgb) < tolerancia || distance(tex_color.rgb, color_chave_2.rgb) < tolerancia) {
		tex_color.a = 0.0;
	}
	
	COLOR = tex_color;
}