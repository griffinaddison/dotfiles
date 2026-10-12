// Debug: turn screen pink if cursor is visible, to test uniforms
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = texture(iChannel0, fragCoord.xy / iResolution.xy);

    // Debug: show cursor position as a big pink dot using same
    // normalization as the working cursor_smear shader
    vec2 norm_frag = (fragCoord * 2.0 - iResolution.xy) / iResolution.y;
    vec2 norm_cursor = (iCurrentCursor.xy * 2.0 - iResolution.xy) / iResolution.y;

    float dist = length(norm_frag - norm_cursor);

    // Big 0.1 radius dot (in normalized space, that's ~large)
    float glow = 1.0 - smoothstep(0.0, 0.15, dist);

    fragColor.rgb = mix(fragColor.rgb, vec3(1.0, 0.0, 0.6), glow * 0.8);
}
