shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// Hit Flash Uniforms
uniform float flash_modifier : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Outline Uniforms
uniform bool is_outlined = false;
uniform float outline_width : hint_range(1.0, 20.0) = 4.0;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_threshold : hint_range(0.0, 1.0) = 0.2;
uniform float camera_zoom: hint_range(0.1, 10.0) = 1.0;

const int SAMPLES = 16;

void fragment() {
    // 1. Fetch the flattened children from the screen buffer
    vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);

    // 2. Un-premultiply the alpha
    if (c.a > 0.0001) {
        c.rgb /= c.a; 
    }

    // 3. Apply the Hit Flash
    c.rgb = mix(c.rgb, flash_color.rgb, flash_modifier);

    // Circular outline — only on transparent pixels
    if (is_outlined && c.a < 0.5) {
        vec2 step = SCREEN_PIXEL_SIZE * outline_width * camera_zoom;
        float accumulated = 0.0;

        for (int i = 0; i < SAMPLES; i++) {
            float angle = (float(i) / float(SAMPLES)) * TAU;
            vec2 offset = vec2(cos(angle), sin(angle)) * step;
            accumulated += textureLod(screen_texture, SCREEN_UV + offset, 0.0).a;
        }

        if ((accumulated / float(SAMPLES)) > outline_threshold) {
            // edge_blend: 1.0 on fully transparent pixels, fades to 0.0 on opaque ones
            // This smoothly merges the outline into the sprite's soft edge instead of cutting hard
            float edge_blend = 1.0 - c.a;
            c.rgb = mix(c.rgb, outline_color.rgb, edge_blend);
            c.a = max(c.a, outline_color.a * edge_blend);
        }
    }

    // Output final color
    COLOR *= c;
}