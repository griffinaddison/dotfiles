// topic_pulse.glsl — Ghostty custom shader for ROS2 terminal awareness
//
// Usage:
//   In your Ghostty config (~/.config/ghostty/config), add:
//     custom-shader = /path/to/ros2_ghostty_shaders/shaders/topic_pulse.glsl
//     custom-shader-animation = always
//
// Effect:
//   The terminal background gently "breathes" based on content density.
//   - Dense text (active topic data): warm amber-tinted pulse
//   - Empty/sparse screen (idle / no data): cool blue-gray flat tint
//   - Left and right halves pulse semi-independently for tmux split panes
//   - Only background pixels are affected; bright text is untouched
//
// Designed for ROS2 developers who want ambient feedback on data flow.

// Compute luminance from an RGB color
float luminance(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// Sample activity (average luminance) over a grid of points within a region
// region: vec4(xMin, yMin, xMax, yMax) in UV space
float sampleActivity(vec4 region) {
    float total = 0.0;
    float count = 0.0;
    // 4 columns x 4 rows = 16 sample points per zone
    for (int ix = 0; ix < 4; ix++) {
        for (int iy = 0; iy < 4; iy++) {
            float sx = region.x + (float(ix) + 0.5) / 4.0 * (region.z - region.x);
            float sy = region.y + (float(iy) + 0.5) / 4.0 * (region.w - region.y);
            vec3 sam = texture(iChannel0, vec2(sx, sy)).rgb;
            total += luminance(sam);
            count += 1.0;
        }
    }
    return total / count;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 color = texture(iChannel0, uv);

    // --- Zone detection ---
    // Left zone: x in [0.0, 0.5], Right zone: x in [0.5, 1.0]
    bool isLeftZone = uv.x < 0.5;

    // Define sampling regions (slightly inset to avoid edge artifacts)
    vec4 leftRegion  = vec4(0.02, 0.05, 0.48, 0.95);
    vec4 rightRegion = vec4(0.52, 0.05, 0.98, 0.95);

    // --- Activity metrics ---
    float leftActivity  = sampleActivity(leftRegion);
    float rightActivity = sampleActivity(rightRegion);

    // Pick activity for the current pixel's zone
    float activity = isLeftZone ? leftActivity : rightActivity;

    // Smooth activity into a 0..1 blend factor
    // Low activity (~0.0) = idle, high activity (>0.08) = active
    // Typical terminal background luminance is ~0.0; text pushes average up
    float activityBlend = smoothstep(0.02, 0.12, activity);

    // --- Pulse computation ---
    // Zone phase offsets so left and right breathe independently
    float zoneOffset = isLeftZone ? 0.0 : 2.1;

    // Active: gentle sinusoidal brightness oscillation (warm breath)
    float activePulse = 1.0 + 0.03 * sin(iTime * 3.0 + zoneOffset);

    // Idle: slight constant dimming (flatline, no oscillation)
    float idlePulse = 1.0 - 0.02;

    // Blend between idle and active pulse based on activity
    float pulse = mix(idlePulse, activePulse, activityBlend);

    // --- Tint computation ---
    // Warm amber tint for active zones
    vec3 warmTint = vec3(1.02, 1.005, 0.98);
    // Cool blue-gray tint for idle zones
    vec3 coolTint = vec3(0.97, 0.98, 1.03);

    vec3 tint = mix(coolTint, warmTint, activityBlend);

    // --- Apply only to dark (background) pixels ---
    float pixelLum = luminance(color.rgb);
    // Pixels below this threshold are considered background
    float bgThreshold = 0.35;
    // Smoothly ramp effect to zero as pixel brightness increases
    float bgMask = 1.0 - smoothstep(0.15, bgThreshold, pixelLum);

    // Final color: blend between original and pulsed/tinted version
    vec3 modulated = color.rgb * pulse * tint;
    vec3 result = mix(color.rgb, modulated, bgMask);

    fragColor = vec4(result, color.a);
}
