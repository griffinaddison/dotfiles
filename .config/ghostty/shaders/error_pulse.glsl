// =============================================================================
// error_pulse.glsl — ROS2 Error/Warning Pulsating Bloom Shader for Ghostty
// =============================================================================
//
// Detects ROS2 log-level colors (ERROR/FATAL = red, WARN = yellow/amber) and
// adds a pulsating radial bloom/glow around them. Non-error regions are subtly
// dimmed when errors are present on screen.
//
// Usage:
//   Add to your Ghostty config (~/.config/ghostty/config):
//
//     custom-shader = ~/ros2_ghostty_shaders/shaders/error_pulse.glsl
//
// =============================================================================

// ---------------------------------------------------------------------------
// RGB <-> HSV helpers
// ---------------------------------------------------------------------------

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)),
                d / (q.x + e),
                q.x);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// ---------------------------------------------------------------------------
// Classify a pixel: 0.0 = normal, 1.0 = error/fatal (red), 0.5 = warn (yellow)
// ---------------------------------------------------------------------------

float classifyPixel(vec3 rgb) {
    vec3 hsv = rgb2hsv(rgb);
    float h = hsv.x * 360.0; // hue in degrees
    float s = hsv.y;
    float v = hsv.z;

    // Need decent saturation and brightness to count as a log-level color
    if (s < 0.35 || v < 0.25) return 0.0;

    // Red hue: 0-15 or 345-360 => ERROR / FATAL
    if (h < 15.0 || h > 345.0) return 1.0;

    // Yellow/amber hue: 35-55 => WARN
    if (h > 35.0 && h < 55.0) return 0.5;

    return 0.0;
}

// ---------------------------------------------------------------------------
// 1D Gaussian weight
// ---------------------------------------------------------------------------

float gaussian(float x, float sigma) {
    return exp(-(x * x) / (2.0 * sigma * sigma));
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 baseColor = texture(iChannel0, uv);
    vec2 texel = 1.0 / iResolution.xy;

    // --- Bloom pass: 11x11 Gaussian kernel around current fragment ----------
    float errorAccum  = 0.0;
    float warnAccum   = 0.0;
    float totalWeight = 0.0;
    float sigma = 3.5;
    int radius = 5; // 11x11 kernel

    for (int y = -radius; y <= radius; y++) {
        for (int x = -radius; x <= radius; x++) {
            vec2 offset = vec2(float(x), float(y)) * texel;
            vec3 samp = texture(iChannel0, uv + offset).rgb;
            float cls = classifyPixel(samp);

            float dist = length(vec2(float(x), float(y)));
            float w = gaussian(dist, sigma);
            totalWeight += w;

            if (cls >= 0.9) {
                errorAccum += w;
            } else if (cls > 0.2) {
                warnAccum += w;
            }
        }
    }

    float errorBloom = errorAccum / totalWeight;
    float warnBloom  = warnAccum  / totalWeight;

    // --- Pulsation factor ---------------------------------------------------
    float pulse = sin(iTime * 5.0) * 0.15 + 0.7;

    // --- Approximate global error presence by sampling sparse grid ----------
    float globalError = 0.0;
    float globalWarn  = 0.0;
    float probeCount  = 0.0;

    for (int py = 0; py < 6; py++) {
        for (int px = 0; px < 8; px++) {
            vec2 probeUV = vec2(
                (float(px) + 0.5) / 8.0,
                (float(py) + 0.5) / 6.0
            );
            vec3 probeSamp = texture(iChannel0, probeUV).rgb;
            float cls = classifyPixel(probeSamp);
            if (cls >= 0.9) globalError += 1.0;
            else if (cls > 0.2) globalWarn += 1.0;
            probeCount += 1.0;
        }
    }

    float errorsOnScreen = step(0.5, globalError + globalWarn);

    // --- Compose output -----------------------------------------------------
    vec3 result = baseColor.rgb;

    // Dim non-error regions when errors are present (~7% reduction)
    float selfClass = classifyPixel(result);
    if (selfClass < 0.1) {
        result *= mix(1.0, 0.93, errorsOnScreen);
    }

    // Add red bloom glow for errors (only to dark/background pixels to preserve text)
    float textMask = smoothstep(0.15, 0.4, dot(result, vec3(0.299, 0.587, 0.114)));
    float bgOnly = 1.0 - textMask;
    vec3 errorGlow = vec3(1.0, 0.15, 0.05) * errorBloom * pulse * 0.6;
    vec3 warnGlow = vec3(1.0, 0.7, 0.1) * warnBloom * pulse * 0.45;

    result += (errorGlow + warnGlow) * bgOnly;

    // Clamp to valid range
    result = clamp(result, 0.0, 1.0);

    fragColor = vec4(result, baseColor.a);
}
