// Cursor beacon shader
// Expanding rings + bright glow around the cursor when the pane regains focus.
// Helps you instantly find your cursor after tabbing back.

const float DURATION = 0.7;          // seconds for full animation
const float RING_SPEED = 250.0;      // pixels/sec expansion
const float RING_THICKNESS = 4.0;    // pixels
const int NUM_RINGS = 3;             // concentric expanding rings
const float RING_DELAY = 0.08;       // seconds between each ring
const float GLOW_RADIUS = 60.0;      // pixels — bright glow around cursor
const float GLOW_STRENGTH = 0.8;     // peak glow opacity

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = texture(iChannel0, fragCoord / iResolution.xy);

    if (iFocus == 0) return;

    float timeSince = iTime - iTimeFocus;
    if (timeSince > DURATION) return;

    vec2 curCenter = iCurrentCursor.xy + iCurrentCursor.zw * vec2(0.5, -0.5);
    float dist = length(fragCoord - curCenter);

    vec3 color = iCurrentCursorColor.rgb;

    // Bright central glow — fades out over time
    float glowFade = 1.0 - smoothstep(0.0, DURATION * 0.6, timeSince);
    float glow = (1.0 - smoothstep(0.0, GLOW_RADIUS, dist)) * glowFade * GLOW_STRENGTH;

    // Multiple expanding rings, staggered
    float totalRing = 0.0;
    for (int i = 0; i < NUM_RINGS; i++) {
        float delay = float(i) * RING_DELAY;
        float t = timeSince - delay;
        if (t < 0.0) continue;

        float ringRadius = RING_SPEED * t;
        float ringFade = 1.0 - smoothstep(0.0, DURATION - delay, t);
        float ring = smoothstep(RING_THICKNESS, 0.0, abs(dist - ringRadius)) * ringFade;
        totalRing = max(totalRing, ring);
    }

    float effect = max(totalRing * 0.85, glow);
    fragColor.rgb = mix(fragColor.rgb, color, effect);
}
