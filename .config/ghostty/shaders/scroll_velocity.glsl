// scroll_velocity.glsl — Content density heatmap strip for Ghostty
//
// Renders a narrow vertical heatmap on the right edge of the terminal.
// Dense text regions glow warm (orange/white), sparse/empty regions stay
// cool (dark blue/teal). Useful for ROS2 developers monitoring terminal
// output at a glance.
//
// Usage:
//   1. Copy this file into your Ghostty custom shader directory, e.g.:
//        ~/.config/ghostty/shaders/scroll_velocity.glsl
//   2. In your Ghostty config, set:
//        custom-shader = ~/.config/ghostty/shaders/scroll_velocity.glsl
//   3. Restart Ghostty or reload the config.
//
// The heatmap strip appears on the right edge (~10px wide). Rows with
// lots of bright/colorful text glow warm; empty or dim rows stay cool.

// Heatmap color ramp: maps density [0,1] to a color.
vec3 heatmapColor(float t) {
    t = clamp(t, 0.0, 1.0);
    // Key stops:
    //   0.0 -> dark blue   (0.05, 0.08, 0.2)
    //   0.3 -> teal         (0.0,  0.4,  0.5)
    //   0.6 -> orange       (1.0,  0.5,  0.1)
    //   1.0 -> white-hot    (1.0,  0.95, 0.8)
    if (t < 0.3) {
        float f = t / 0.3;
        return mix(vec3(0.05, 0.08, 0.2), vec3(0.0, 0.4, 0.5), f);
    } else if (t < 0.6) {
        float f = (t - 0.3) / 0.3;
        return mix(vec3(0.0, 0.4, 0.5), vec3(1.0, 0.5, 0.1), f);
    } else {
        float f = (t - 0.6) / 0.4;
        return mix(vec3(1.0, 0.5, 0.1), vec3(1.0, 0.95, 0.8), f);
    }
}

// Compute luminance from linear RGB.
float luminance(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// Sample a row's density: average brightness + color variance.
// Returns a combined score in [0, 1].
float rowDensity(float y) {
    const int NUM_SAMPLES = 20;
    float stepX = 1.0 / float(NUM_SAMPLES + 1);

    float totalLum = 0.0;
    vec3 totalColor = vec3(0.0);
    vec3 totalColorSq = vec3(0.0);

    for (int i = 1; i <= NUM_SAMPLES; i++) {
        float sx = float(i) * stepX;
        vec3 s = texture(iChannel0, vec2(sx, y)).rgb;
        float lum = luminance(s);
        totalLum += lum;
        totalColor += s;
        totalColorSq += s * s;
    }

    float avgLum = totalLum / float(NUM_SAMPLES);

    // Color variance: mean of per-channel variance
    vec3 mean = totalColor / float(NUM_SAMPLES);
    vec3 meanSq = totalColorSq / float(NUM_SAMPLES);
    vec3 variance = max(meanSq - mean * mean, vec3(0.0));
    float colorVar = (variance.r + variance.g + variance.b) / 3.0;

    // Combine brightness and variance into a density score.
    // Brightness is the primary signal; variance boosts colorful rows.
    float density = clamp(avgLum * 1.2 + colorVar * 3.0, 0.0, 1.0);
    return density;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 baseColor = texture(iChannel0, uv);

    // Strip parameters
    float stripWidthPx = 10.0;
    float borderWidthPx = 2.0;
    float stripEdge = 1.0 - stripWidthPx / iResolution.x;
    float borderEdge = stripEdge + borderWidthPx / iResolution.x;

    if (uv.x > stripEdge) {
        // --- Inside the heatmap strip ---

        // Dark border on the left edge of the strip
        if (uv.x < borderEdge) {
            fragColor = vec4(vec3(0.02, 0.02, 0.04), 1.0);
            return;
        }

        // Vertical blur: sample current row and 2 neighbors
        float pixelY = 1.0 / iResolution.y;
        float d0 = rowDensity(uv.y);
        float d1 = rowDensity(uv.y - pixelY);
        float d2 = rowDensity(uv.y + pixelY);
        float density = d0 * 0.5 + d1 * 0.25 + d2 * 0.25;

        // Time-based shimmer
        float shimmer = 0.9 + 0.1 * sin(iTime * 2.0 + uv.y * 20.0);
        density *= shimmer;
        density = clamp(density, 0.0, 1.0);

        vec3 col = heatmapColor(density);
        fragColor = vec4(col, 1.0);
    } else {
        // --- Outside the strip: pass through with optional warm tint ---

        // Quick density check using a few sample points on this row
        float quickLum = 0.0;
        quickLum += luminance(texture(iChannel0, vec2(0.2, uv.y)).rgb);
        quickLum += luminance(texture(iChannel0, vec2(0.5, uv.y)).rgb);
        quickLum += luminance(texture(iChannel0, vec2(0.8, uv.y)).rgb);
        quickLum /= 3.0;

        // Very subtle warm tint for dense rows
        float tintStrength = clamp(quickLum, 0.0, 1.0) * 0.03;
        vec3 warmTint = vec3(1.0, 0.85, 0.7);
        vec3 tinted = mix(baseColor.rgb, baseColor.rgb * warmTint, tintStrength);

        fragColor = vec4(tinted, baseColor.a);
    }
}
