// =============================================================================
// tmux_focus.glsl — Yellow glow rectangle around active tmux pane
// =============================================================================

const vec3 ACTIVE_BORDER = vec3(0.0, 1.0, 0.0);  // colour46
const float COLOR_TOLERANCE = 0.15;
const vec3 YELLOW = vec3(1.0, 0.9, 0.0);
const float GLOW_WIDTH = 4.0;       // thickness of the yellow border in pixels
const float GLOW_SOFTNESS = 6.0;    // how far the glow fades outward

float colorMatch(vec3 a, vec3 b) {
    float dist = length(a - b);
    return step(dist, COLOR_TOLERANCE);
}

float isActiveBorderAt(vec2 uv) {
    vec3 s = texture(iChannel0, clamp(uv, 0.0, 1.0)).rgb;
    return colorMatch(s, ACTIVE_BORDER);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec4 original = texture(iChannel0, uv);
    vec2 texel = 1.0 / iResolution.xy;

    // Scan to find bounding box of active border pixels.
    // Sample along ~40 horizontal and ~40 vertical lines.
    float minX = 1.0, maxX = 0.0;
    float minY = 1.0, maxY = 0.0;
    bool found = false;

    int SCAN_LINES = 40;
    int SCAN_POINTS = 60;

    // Scan horizontal lines at various Y positions
    for (int row = 0; row < SCAN_LINES; row++) {
        float sy = (float(row) + 0.5) / float(SCAN_LINES);
        for (int col = 0; col < SCAN_POINTS; col++) {
            float sx = (float(col) + 0.5) / float(SCAN_POINTS);
            if (isActiveBorderAt(vec2(sx, sy)) > 0.5) {
                minX = min(minX, sx);
                maxX = max(maxX, sx);
                minY = min(minY, sy);
                maxY = max(maxY, sy);
                found = true;
            }
        }
    }

    if (!found) {
        fragColor = original;
        return;
    }

    // Convert bounding box to pixel coords
    vec2 bboxMin = vec2(minX, minY) * iResolution.xy;
    vec2 bboxMax = vec2(maxX, maxY) * iResolution.xy;

    // Distance from current pixel to the bounding box edges
    // (negative = inside, positive = outside)
    float distLeft   = abs(fragCoord.x - bboxMin.x);
    float distRight  = abs(fragCoord.x - bboxMax.x);
    float distBottom = abs(fragCoord.y - bboxMin.y);
    float distTop    = abs(fragCoord.y - bboxMax.y);

    // Check if we're near any edge of the bounding box
    bool inYRange = fragCoord.y >= bboxMin.y - GLOW_SOFTNESS && fragCoord.y <= bboxMax.y + GLOW_SOFTNESS;
    bool inXRange = fragCoord.x >= bboxMin.x - GLOW_SOFTNESS && fragCoord.x <= bboxMax.x + GLOW_SOFTNESS;

    float edgeDist = 9999.0;

    // Left edge
    if (inYRange) edgeDist = min(edgeDist, distLeft);
    // Right edge
    if (inYRange) edgeDist = min(edgeDist, distRight);
    // Bottom edge
    if (inXRange) edgeDist = min(edgeDist, distBottom);
    // Top edge
    if (inXRange) edgeDist = min(edgeDist, distTop);

    // Glow intensity: solid within GLOW_WIDTH, fades out over GLOW_SOFTNESS
    float glowIntensity = 1.0 - smoothstep(GLOW_WIDTH, GLOW_WIDTH + GLOW_SOFTNESS, edgeDist);

    vec3 result = mix(original.rgb, YELLOW, glowIntensity * 0.7);

    fragColor = vec4(result, original.a);
}
