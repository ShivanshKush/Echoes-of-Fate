shader_type spatial;
render_mode unshaded, cull_disabled;

instance uniform float fade = 1.0;
uniform sampler2D albedo_texture;

void vertex() {
    mat4 camera_rotation_matrix = mat4(
        VIEW_MATRIX[0],
        vec4(0.0, 1.0, 0.0, 0.0),
        VIEW_MATRIX[2],
        vec4(0.0, 0.0, 0.0, 1.0)
    );
}

void fragment() {
    vec4 base_color = texture(albedo_texture, UV);

    if (base_color.a < 0.1) {
        discard;
    }

    ALBEDO = base_color.rgb;
    ALPHA = base_color.a * fade;
}