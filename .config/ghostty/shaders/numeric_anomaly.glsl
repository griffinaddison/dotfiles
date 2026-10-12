// numeric_anomaly.glsl — Ghostty custom shader for ROS2 numeric data visualization
//
// Adds a heatmap-style color wash to terminal lines based on text density and
// brightness. Designed for ROS2 developers monitoring numeric data streams
// (e.g., `ros2 topic echo /imu/data` or `ros2 topic hz /scan`).
//
// - Denser/brighter text regions get warmer colors (orange-red)
// - Sparser regions get cooler colors (blue)
// - Anomalous lines (density spikes) are highlighted with extra saturation
// - Subtle time-based hue drift prevents visual adaptation
//
// Usage:
//   In your Ghostty config (~/.config/ghostty/config), add:
//     custom-shader = /path/to/ros2_ghostty_shaders/shaders/numeric_anomaly.glsl
//
//   Then run your ROS2 commands as usual:
//     ros2 topic echo /sensor_data
//     ros2 topic hz /lidar/points
//

// Approximate terminal line height in UV space.
// ~18px line height is common; we estimate from resolution.
float getLineHeight() {
    return 18.0 / iResolution.y;
}

// Sample a row's brightness and density across its width.
// Returns vec3(avgBrightness, density, variance).
vec3 sampleRow(float rowY) {
    const int NUM_SAMPLES = 24;
    float totalBright = 0.0;
    float totalBrightSq = 0.0;
    float denseCount = 0.0;
    float brightThreshold = 0.15;

    for (int i = 0; i < NUM_SAMPLES; i++) {
        float sx = (float(i) + 0.5) / float(NUM_SAMPLES);
        vec4 s = texture(iChannel0, vec2(sx, rowY));
        float lum = dot(s.rgb, vec3(0.2126, 0.7152, 0.0722));
        totalBright += lum;
        totalBrightSq += lum * lum;
        if (lum > brightThreshold) {
            denseCount += 1.0;
        }
    }

    float avg = totalBright / float(NUM_SAMPLES);
    float avgSq = totalBrightSq / float(NUM_SAMPLES);
    float variance = avgSq - avg * avg;
    float density = denseCount / float(NUM_SAMPLES);

    return vec3(avg, density, variance);
}

// Cool-to-warm heatmap ramp.
vec3 heatmapColor(float t) {
    vec3 cool   = vec3(0.1, 0.15, 0.35);  // blue
    vec3 mid    = vec3(0.1, 0.35, 0.15);  // green
    vec3 warm   = vec3(0.4, 0.15, 0.05);  // orange-red

    if (t < 0.5) {
        return mix(cool, mid, t * 2.0);
    } else {
        return mix(mid, warm, (t - 0.5) * 2.0);
    }
}

// Rotate hue of an RGB color by an angle (radians).
vec3 hueShift(vec3 col, float shift) {
    float cosA = cos(shift);
    float sinA = sin(shift);
    // Rodrigues rotation around the (1,1,1) axis in RGB space
    vec3 k = vec3(0.57735); // normalized (1,1,1)
    return col * cosA + cross(k, col) * sinA + k * dot(k, col) * (1.0 - cosA);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 color = texture(iChannel0, uv);

    float lineHeight = getLineHeight();

    // Current pixel's position within its character row (0..1).
    float rowFract = fract(uv.y / lineHeight);

    // Center Y of the current row.
    float rowCenter = (floor(uv.y / lineHeight) + 0.5) * lineHeight;

    // Sample current row.
    vec3 rowInfo = sampleRow(rowCenter);
    float avgBright  = rowInfo.x;
    float density    = rowInfo.y;
    float variance   = rowInfo.z;

    // Sample neighbor rows for spike detection.
    vec3 aboveInfo = sampleRow(rowCenter - lineHeight);
    vec3 belowInfo = sampleRow(rowCenter + lineHeight);

    float neighborAvgDensity = (aboveInfo.y + belowInfo.y) * 0.5;

    // Spike detection: current row is significantly denser than neighbors.
    float spikeFactor = 0.0;
    if (neighborAvgDensity > 0.001) {
        spikeFactor = clamp((density - neighborAvgDensity) / (neighborAvgDensity + 0.05) - 0.5, 0.0, 1.0);
    } else if (density > 0.15) {
        spikeFactor = clamp(density - 0.15, 0.0, 1.0);
    }

    // Combine density and variance for the heatmap index.
    // High variance (mixed text/spaces) is a strong signal for data lines.
    float heatIndex = clamp(density * 0.7 + variance * 3.0 + avgBright * 0.3, 0.0, 1.0);

    // Get base heatmap color.
    vec3 tint = heatmapColor(heatIndex);

    // Slow time-based hue drift (~30 second cycle).
    float hueOffset = iTime * (6.2831853 / 30.0); // 2*PI / 30s
    tint = hueShift(tint, hueOffset * 0.15); // subtle shift

    // Determine opacity: base 8-12% range, boosted for spikes.
    float baseOpacity = mix(0.08, 0.12, heatIndex);

    // Boost opacity and saturation for anomalous spike lines.
    float spikeBoost = spikeFactor * 0.15;
    float opacity = baseOpacity + spikeBoost;

    // Concentrate tint in the bottom portion of the row ("underline" zone).
    // Bottom 30% of the row gets full tint; fades above that.
    float underlineMask = smoothstep(0.5, 0.85, rowFract);

    // Only apply tint to dark/background pixels.
    float pixelLum = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    float bgMask = 1.0 - smoothstep(0.08, 0.25, pixelLum);

    // Final tint application.
    float finalAlpha = opacity * underlineMask * bgMask;
    vec3 result = mix(color.rgb, color.rgb + tint, finalAlpha);

    fragColor = vec4(result, color.a);
}
