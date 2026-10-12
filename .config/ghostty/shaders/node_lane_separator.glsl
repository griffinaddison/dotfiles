// =============================================================================
// node_lane_separator.glsl — Ghostty Custom Shader
// =============================================================================
// Visually groups interleaved ROS2 multi-node log output by detecting bands of
// terminal text that share similar colors (each node typically prints in a
// distinct hue) and adding:
//   1. A faint background tint per color-band (so lines from the same node
//      share a subtle stripe).
//   2. Thin separator lines where the dominant color changes between rows
//      (i.e. where output switches from one node to another).
//
// Ghostty config (ghostty.conf):
//   custom-shader = ~/ros2_ghostty_shaders/shaders/node_lane_separator.glsl
//   custom-shader-animation = true
// =============================================================================

// ---- RGB to HSV conversion --------------------------------------------------
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(
        abs(q.z + (q.w - q.y) / (6.0 * d + e)),   // H  [0,1]
        d / (q.x + e),                               // S  [0,1]
        q.x                                          // V  [0,1]
    );
}

// ---- Compute the dominant-hue bucket for a given row ------------------------
// Samples the LEFT portion of the line (first ~38% of width) where ROS2 node
// names and log-level tags live.  Returns an integer bucket 0-7, or -1 when
// no saturated color is found (neutral / default text).
//
// Hue averaging uses sin/cos to handle the circular wrap-around correctly.
int dominantBucket(float rowY) {
    const int   NUM_SAMPLES      = 14;
    const float LEFT_FRAC        = 0.38;
    const float SAT_THRESHOLD    = 0.20;
    const float BRIGHT_THRESHOLD = 0.15;  // ignore very dark pixels
    const int   NUM_BUCKETS      = 8;

    float sinSum = 0.0;
    float cosSum = 0.0;
    int   saturatedCount = 0;

    for (int i = 0; i < NUM_SAMPLES; i++) {
        // Spread samples across the left portion, avoiding the very edge
        float t = (float(i) + 0.5) / float(NUM_SAMPLES);
        float sampleX = t * LEFT_FRAC;

        vec4  texel = texture(iChannel0, vec2(sampleX, rowY));
        vec3  hsv   = rgb2hsv(texel.rgb);

        if (hsv.y >= SAT_THRESHOLD && hsv.z >= BRIGHT_THRESHOLD) {
            float angle = hsv.x * 6.28318530718; // hue -> radians
            sinSum += sin(angle);
            cosSum += cos(angle);
            saturatedCount++;
        }
    }

    if (saturatedCount < 2) {
        return -1; // neutral — not enough colored pixels
    }

    // Average hue via atan2 of accumulated sin/cos
    float avgAngle = atan(sinSum, cosSum);           // [-pi, pi]
    if (avgAngle < 0.0) avgAngle += 6.28318530718;   // [0, 2pi]
    float avgHue = avgAngle / 6.28318530718;          // [0, 1]

    // Quantize into NUM_BUCKETS buckets (each 45 degrees wide)
    int bucket = int(floor(avgHue * float(NUM_BUCKETS)));
    bucket = clamp(bucket, 0, NUM_BUCKETS - 1);
    return bucket;
}

// ---- Tint palette -----------------------------------------------------------
// Eight faint pastel tints, one per hue bucket.
vec3 bucketTint(int bucket) {
    if (bucket == 0) return vec3(0.55, 0.70, 0.95);  // pale blue
    if (bucket == 1) return vec3(0.55, 0.90, 0.60);  // pale green
    if (bucket == 2) return vec3(0.75, 0.55, 0.90);  // pale purple
    if (bucket == 3) return vec3(0.50, 0.88, 0.88);  // pale cyan
    if (bucket == 4) return vec3(0.92, 0.55, 0.65);  // pale rose
    if (bucket == 5) return vec3(0.92, 0.80, 0.45);  // pale amber
    if (bucket == 6) return vec3(0.45, 0.82, 0.76);  // pale teal
    if (bucket == 7) return vec3(0.72, 0.62, 0.88);  // pale lavender
    return vec3(0.7);                                  // fallback gray
}

// =============================================================================
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv    = fragCoord.xy / iResolution.xy;
    vec4 color = texture(iChannel0, uv);

    // Approximate character cell height (assume ~60 rows of text)
    float charHeight = 1.0 / 60.0; // in UV space

    // Snap to the vertical centre of the current character row
    float rowCenterY = (floor(uv.y / charHeight) + 0.5) * charHeight;

    // ---- Dominant-hue bucket for current and previous row -------------------
    int curBucket  = dominantBucket(rowCenterY);
    int prevBucket = dominantBucket(rowCenterY - charHeight);

    // ---- Background tint (only on dark / background-ish pixels) -------------
    vec3 hsv = rgb2hsv(color.rgb);
    float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    bool isDark = luminance < 0.18;

    if (curBucket >= 0 && isDark) {
        vec3 tint = bucketTint(curBucket);
        color.rgb = mix(color.rgb, tint, 0.06); // 6% opacity tint
    }

    // ---- Separator line where the bucket changes ----------------------------
    // Draw a 1-2 px line at the top edge of the current character row when the
    // bucket differs from the row above.
    if (curBucket != prevBucket) {
        float rowTopY = floor(uv.y / charHeight) * charHeight;
        float pixelH  = 1.0 / iResolution.y;
        float distFromTop = uv.y - rowTopY;

        // Two-pixel-thick line (in UV space ≈ 2 screen pixels)
        if (distFromTop < 2.0 * pixelH) {
            // Neutral separator: semi-transparent mid-gray
            vec3 sepColor = vec3(0.45, 0.48, 0.52);
            float sepAlpha = 0.35;
            color.rgb = mix(color.rgb, sepColor, sepAlpha);
        }
    }

    fragColor = color;
}
