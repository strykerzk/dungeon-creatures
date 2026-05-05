shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 1.0;
uniform bool is_outlined = false;

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    
    if (is_outlined && col.a == 0.0) {
        vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
        float outline = texture(TEXTURE, UV + vec2(-size.x, 0)).a;
        outline += texture(TEXTURE, UV + vec2(0, size.y)).a;
        outline += texture(TEXTURE, UV + vec2(size.x, 0)).a;
        outline += texture(TEXTURE, UV + vec2(0, -size.y)).a;
        outline += texture(TEXTURE, UV + vec2(-size.x, size.y)).a;
        outline += texture(TEXTURE, UV + vec2(size.x, size.y)).a;
        outline += texture(TEXTURE, UV + vec2(-size.x, -size.y)).a;
        outline += texture(TEXTURE, UV + vec2(size.x, -size.y)).a;
        outline = min(outline, 1.0);
        
        COLOR = mix(col, outline_color, outline);
    } else {
        COLOR = col;
    }
}
