shader_type canvas_item;

// Assign your GradientTexture1D here in the Inspector
uniform sampler2D gradient_texture : source_color; 
// Adjust rotation angle in degrees
uniform float rotation_degrees : hint_range(0.0, 360.0) = 90.0; 

void fragment() {
    // Center the UV coordinates to pivot around the middle
    vec2 uv = UV - 0.5;
    
    // Convert degrees to radians
    float rad = radians(rotation_degrees);
    
    // Rotate the UV coordinates
    float rotated_x = uv.x * cos(rad) - uv.y * sin(rad);
    
    // Shift UV back to 0.0 - 1.0 range and sample the 1D gradient
    float sample_pos = rotated_x + 0.5;
    
    // Clamp sample position to prevent texture wrapping artifacts
    sample_pos = clamp(sample_pos, 0.0, 1.0);
    
    COLOR = texture(gradient_texture, vec2(sample_pos, 0.0));
}
