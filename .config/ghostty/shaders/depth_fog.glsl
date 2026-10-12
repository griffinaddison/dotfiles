// =============================================================================
// Depth Fog Shader for Ghostty Terminal
// =============================================================================
//
// A custom Ghostty shader for ROS2 developers that applies a "depth fog"
// effect: older output at the top of the terminal gradually fades and
// desaturates into a cool blue-gray fog, while fresh output at the bottom
// stays vivid and crisp.
//
// ERROR (red) and WARN (yellow) lines are EXEMPT from the fog effect and
// always render at full brightness regardless of their vertical position,
// so you never miss critical diagnostics scrolling off-screen.
//
// Usage:
//   1. Copy this file to your Ghostty custom shaders directory, or point
//      your Ghostty config at it:
//
//        custom-shader = /path/to/depth_fog.glsl
//        custom-shader-animation = true
//
//   2. Restart Ghostty or reload the config.
//
// Tuning:
//   - FOG_START / FOG_END   : vertical range where fog ramps up
//   - FOG_COLOR              : the color old text fades toward
//   - FOG_INTENSITY          : max fog blend factor (0.0 = off, 1.0 = full)
//   - GLOW_STRENGTH          : brightness of the "freshness glow" at bottom
//   - NEIGHBOR_RANGE         : how many horizontal pixels to sample for
//                              severity detection
//
// =============================================================================

// ---------------------------------------------------------------------------
// Tuning constants
// ---------------------------------------------------------------------------
const float FOG_START     = 0.3;   // normalized Y where fog begins (0 = top)
const float FOG_END       = 0.9;   // normalized Y where fog reaches maximum
const vec3  FOG_COLOR     = vec3(0.12, 0.13, 0.18); // dark cool blue-gray
const float FOG_INTENSITY = 0.65;  // max blend toward fog color
const float GLOW_STRENGTH = 0.08;  // warmth added to the bottom 5%
const int   NEIGHBOR_RANGE = 8;    // horizontal pixels to scan for severity

// ---------------------------------------------------------------------------
// RGB <-> HSV conversion helpers
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
    vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

// ---------------------------------------------------------------------------
// Check if a color is in the ERROR (red) or WARN (yellow) hue range
// Returns 0.0 .. 1.0 indicating severity confidence.
// ---------------------------------------------------------------------------
float severityScore(vec3 rgb) {
    vec3 hsv = rgb2hsv(rgb);
    float hue = hsv.x;
    float sat = hsv.y;
    float val = hsv.z;

    // Need minimum saturation and brightness to count as a colored indicator
    float satGate = smoothstep(0.25, 0.45, sat);
    float valGate = smoothstep(0.15, 0.30, val);

    // Red hue: wraps around 0/1, so check both ends  (roughly 0..30 and 330..360 deg)
    float red = smoothstep(0.0, 0.02, hue)          // ramp up from pure 0
              * smoothstep(0.11, 0.08, hue)          // ramp down toward orange
              + smoothstep(0.92, 0.97, hue);         // wrap-around reds near 1.0

    // Yellow / orange hue: ~30..65 deg  (0.083 .. 0.18 in normalized hue)
    float yellow = smoothstep(0.06, 0.10, hue) * smoothstep(0.20, 0.15, hue);

    float hueScore = clamp(red + yellow, 0.0, 1.0);

    return hueScore * satGate * valGate;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 original = texture(iChannel0, uv);

    // 1. Fog strength based on vertical position.
    //    uv.y = 0 at bottom, 1 at top in Ghostty (standard OpenGL).
    //    We want fog at the TOP (old output).
    float normalizedDepth = uv.y;   // 1.0 at top (old), 0.0 at bottom (fresh)
    float fogStrength = smoothstep(FOG_START, FOG_END, normalizedDepth);

    // 2. Severity exemption: sample current pixel + horizontal neighbors.
    float severity = 0.0;
    vec2 pixelSize = 1.0 / iResolution.xy;

    for (int i = -NEIGHBOR_RANGE; i <= NEIGHBOR_RANGE; i++) {
        vec2 sampleUV = uv + vec2(float(i) * pixelSize.x, 0.0);
        sampleUV.x = clamp(sampleUV.x, 0.0, 1.0);
        vec3 sampleRGB = texture(iChannel0, sampleUV).rgb;
        severity = max(severity, severityScore(sampleRGB));
    }

    float severityExempt = smoothstep(0.3, 0.7, severity);

    // 3. Effective fog (severity-exempt lines keep full color)
    float effectiveFog = fogStrength * (1.0 - severityExempt);

    // 4. Build the fogged color
    vec3 rgb = original.rgb;

    // Luminance (Rec. 601)
    float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
    vec3 gray = vec3(luma);

    // Desaturate toward grayscale
    vec3 desaturated = mix(rgb, gray, effectiveFog);

    // Reduce contrast toward middle values
    vec3 midGray = vec3(luma * 0.5 + 0.05);
    vec3 lowContrast = mix(desaturated, midGray, effectiveFog * 0.3);

    // Shift toward the cool fog color
    vec3 fogged = mix(lowContrast, FOG_COLOR, effectiveFog * FOG_INTENSITY);

    // 5. Freshness glow at the very bottom (newest output)
    //    Warm tint in the bottom 5% of the screen.
    float freshZone = smoothstep(0.05, 0.0, uv.y); // 1 at bottom edge, 0 above 5%
    vec3 warmTint = vec3(0.15, 0.08, 0.0); // subtle warm amber
    fogged += warmTint * freshZone * GLOW_STRENGTH;

    // 6. Output
    fragColor = vec4(fogged, original.a);
}
