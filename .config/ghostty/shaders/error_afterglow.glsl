// =============================================================================
// error_afterglow.glsl — Persistent "heat trail" afterglow for ROS2 error logs
// =============================================================================
//
// Purpose:
//   Detects red (ERROR/FATAL) and yellow (WARN) ANSI-colored terminal output
//   and adds a glowing heat-trail effect. Denser clusters of error pixels
//   produce more intense heat. The glow fades toward the top of the screen,
//   simulating temporal decay as content scrolls upward.
//
// Ghostty config:
//   custom-shader = ~/ros2_ghostty_shaders/shaders/error_afterglow.glsl
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
    return vec3(
        abs(q.z + (q.w - q.y) / (6.0 * d + e)),
        d / (q.x + e),
        q.x
    );
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// ---------------------------------------------------------------------------
// Simple per-row pseudo-random hash (deterministic, based on Y coordinate)
// ---------------------------------------------------------------------------

float hashRow(float y) {
    return fract(sin(y * 127.1 + 311.7) * 43758.5453123);
}

// ---------------------------------------------------------------------------
// Classify a pixel's "severity" from its color
//   Returns: 0.0 = neutral, positive = error/warning intensity
//   Channel encoding: x = error weight, y = warning weight
// ---------------------------------------------------------------------------

vec2 classifyPixel(vec3 col) {
    vec3 hsv = rgb2hsv(col);
    float h = hsv.x;  // 0..1 (hue mapped to 0-360 as h*360)
    float s = hsv.y;
    float v = hsv.z;

    float errWeight  = 0.0;
    float warnWeight = 0.0;

    // Error-red: hue near 0 or near 1 (wrapping around 360), sat > 0.3, val > 0.25
    // Hue range: 0-15 deg (0.0-0.042) or 345-360 deg (0.958-1.0)
    if ((h < 0.042 || h > 0.958) && s > 0.3 && v > 0.25) {
        errWeight = s * v;  // stronger color = stronger signal
    }

    // Warning-yellow: hue ~25-65 deg (0.069-0.181), sat > 0.3, val > 0.3
    if (h > 0.069 && h < 0.181 && s > 0.3 && v > 0.3) {
        warnWeight = s * v;
    }

    return vec2(errWeight, warnWeight);
}

// ---------------------------------------------------------------------------
// Gaussian weight for spatial sampling
// ---------------------------------------------------------------------------

float gaussian(float d, float sigma) {
    return exp(-(d * d) / (2.0 * sigma * sigma));
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 original = texture(iChannel0, uv);

    // Pixel size in UV space
    vec2 pixelSize = 1.0 / iResolution.xy;

    // --------------------------------------------------
    // Accumulate heat from surrounding area (~15px radius)
    // --------------------------------------------------
    float radius = 15.0;
    float sigma  = 7.0;

    float errHeat  = 0.0;
    float warnHeat = 0.0;
    float totalWeight = 0.0;

    // Step in increments of 2 pixels for performance
    for (float dy = -radius; dy <= radius; dy += 2.0) {
        for (float dx = -radius; dx <= radius; dx += 2.0) {
            float dist = length(vec2(dx, dy));
            if (dist > radius) continue;

            float w = gaussian(dist, sigma);
            vec2 sampleUV = uv + vec2(dx, dy) * pixelSize;
            sampleUV = clamp(sampleUV, 0.0, 1.0);

            vec3 sampleCol = texture(iChannel0, sampleUV).rgb;
            vec2 severity  = classifyPixel(sampleCol);

            errHeat  += severity.x * w;
            warnHeat += severity.y * w;
            totalWeight += w;
        }
    }

    // Normalize
    errHeat  /= totalWeight;
    warnHeat /= totalWeight;

    // --------------------------------------------------
    // Vertical fade: bottom of screen = full, top = reduced
    // uv.y == 0.0 is top, uv.y == 1.0 is bottom in Ghostty
    // --------------------------------------------------
    float verticalFade = mix(0.2, 1.0, uv.y);

    // --------------------------------------------------
    // Ember-like pulsing: slow sin wave, phase offset per row
    // --------------------------------------------------
    float rowY = floor(uv.y * iResolution.y);
    float phase = hashRow(rowY) * 6.2831853;  // random phase 0..2pi
    float pulse = 0.85 + 0.15 * sin(iTime * 1.5 + phase);

    // --------------------------------------------------
    // Compute final heat intensities
    // --------------------------------------------------
    float errIntensity  = errHeat  * verticalFade * pulse * 8.0;
    float warnIntensity = warnHeat * verticalFade * pulse * 6.0;

    // Soft clamp to avoid blowout
    errIntensity  = min(errIntensity, 1.0);
    warnIntensity = min(warnIntensity, 1.0);

    // --------------------------------------------------
    // Glow colors
    //   Error heat  : deep red-orange  (1.0, 0.25, 0.05)
    //   Warning heat: amber            (1.0, 0.65, 0.1)
    // --------------------------------------------------
    vec3 errGlow  = vec3(1.0, 0.25, 0.05) * errIntensity;
    vec3 warnGlow = vec3(1.0, 0.65, 0.1)  * warnIntensity;

    // --------------------------------------------------
    // Additive blend onto original color
    // --------------------------------------------------
    vec3 result = original.rgb + errGlow + warnGlow;
    result = clamp(result, 0.0, 1.0);

    fragColor = vec4(result, original.a);
}
