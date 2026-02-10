//
// Simple fullscreen blur shader for Hyprland screen_shader.
// The script replaces @BLUR_RADIUS@ with an integer radius.
//

#version 300 es

precision mediump float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

const int radius = @BLUR_RADIUS@;

void main() {

    vec2 texel = 1.0 / vec2(textureSize(tex, 0));
    vec3 sum = vec3(0.0);
    float count = 0.0;

    for (int x = -radius; x <= radius; x++) {
        for (int y = -radius; y <= radius; y++) {
            sum += texture(tex, v_texcoord + vec2(float(x), float(y)) * texel).rgb;
            count += 1.0;
        }
    }

    fragColor = vec4(sum / count, 1.0);
}
