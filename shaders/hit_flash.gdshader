shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// Hit Flash Uniforms
uniform float flash_modifier : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Outline Uniforms
uniform bool is_outlined = false;
uniform float outline_width : hint_range(0.0, 10.0) = 1.0;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    // 1. Fetch the flattened children from the screen buffer
    vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);

    // 2. Un-premultiply the alpha
    if (c.a > 0.0001) {
        c.rgb /= c.a; 
    }

    // 3. Apply the Hit Flash
    c.rgb = mix(c.rgb, flash_color.rgb, flash_modifier);

    // 4. Apply the Outline (Only if this pixel is transparent!)
    if (is_outlined && c.a < 0.01) {
        vec2 size = SCREEN_PIXEL_SIZE * outline_width;
        float out_a = textureLod(screen_texture, SCREEN_UV + vec2(-size.x, 0), 0.0).a;
        out_a += textureLod(screen_texture, SCREEN_UV + vec2(0, size.y), 0.0).a;
        out_a += textureLod(screen_texture, SCREEN_UV + vec2(size.x, 0), 0.0).a;
        out_a += textureLod(screen_texture, SCREEN_UV + vec2(0, -size.y), 0.0).a;
        out_a += textureLod(screen_texture, SCREEN_UV + vec2(-size.x, size.y), 0.0).a;
        out_a += textureLod(screen_texture, SCREEN_UV + vec2(size.x, size.y), 0.0).a;
        out_a += textureLod(screen_texture, SCREEN_UV + vec2(-size.x, -size.y), 0.0).a;
        out_a += textureLod(screen_texture, SCREEN_UV + vec2(size.x, -size.y), 0.0).a;
        
        out_a = min(out_a, 1.0);
        
        // If a neighboring pixel has opacity, draw the outline color here
        if (out_a > 0.0) {
            c = outline_color;
        }
    }

    // Output final color
    COLOR *= c;
}