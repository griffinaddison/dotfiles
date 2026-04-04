// Cursor smear shader
// Stretches and smears the terminal content in the direction of cursor movement,
// like a cartoon character being squash-and-stretched mid-dash.

const float FADE_DURATION = 0.4;    // seconds — longer visible smear
const float SMEAR_STRENGTH = 28.0;  // max pixel offset multiplier
const float SMEAR_RADIUS = 90.0;    // pixels — wider area affected

float sdfSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    float scale = min(iResolution.x, iResolution.y);

    // Cursor centers
    vec2 curCenter = iCurrentCursor.xy + iCurrentCursor.zw * vec2(0.5, -0.5);
    vec2 prevCenter = iPreviousCursor.xy + iPreviousCursor.zw * vec2(0.5, -0.5);
    vec2 delta = curCenter - prevCenter;
    float jumpDist = length(delta);

    float moveIntensity = smoothstep(3.0, 40.0, jumpDist);

    float timeSince = iTime - iTimeCursorChange;
    float timeFade = 1.0 - smoothstep(0.0, FADE_DURATION, timeSince);
    float intensity = moveIntensity * timeFade;

    if (intensity < 0.001) {
        fragColor = texture(iChannel0, uv);
        return;
    }

    // Trail width scales with jump distance:
    // ~5 chars = cursor-width trail, bigger jumps get wider
    float charWidth = iCurrentCursor.zw.x;
    float cursorHalfH = iCurrentCursor.zw.y * 0.5;
    float charsJumped = jumpDist / max(charWidth, 1.0);
    // At 5 chars: radius = cursorHalfH. Grows with sqrt beyond that, capped at SMEAR_RADIUS.
    float baseRadius = clamp(cursorHalfH * sqrt(max(charsJumped, 1.0) / 5.0), cursorHalfH, SMEAR_RADIUS);

    // Diffusion: trail widens over time like smoke (radius grows as sqrt(t),
    // the 2D diffusion kernel width). Diffusion coefficient tuned for visual effect.
    float diffusionCoeff = 8000.0; // px²/s — how fast the trail spreads
    float trailRadius = sqrt(baseRadius * baseRadius + diffusionCoeff * timeSince);
    trailRadius = min(trailRadius, SMEAR_RADIUS);

    // Gravity: trail sags downward over time (0.5 * g * t², screen +Y is up)
    float gravity = 80.0; // px/s² — subtle buoyant drift
    vec2 gravityOffset = vec2(0.0, -0.5 * gravity * timeSince * timeSince);

    float distToTrail = sdfSegment(fragCoord - gravityOffset, curCenter, prevCenter);
    float trailInfluence = 1.0 - smoothstep(0.0, trailRadius, distToTrail);

    // Conservation of mass: opacity scales inversely with trail area (∝ 1/radius)
    float densityFalloff = baseRadius / max(trailRadius, baseRadius);
    trailInfluence *= densityFalloff;

    // Smear direction (opposite of movement — pixels "lag behind")
    vec2 moveDir = normalize(delta);
    vec2 smearDir = -moveDir;

    // Where along the trail is this fragment? 0 = prev, 1 = current
    vec2 toCur = fragCoord - prevCenter;
    float alongTrail = dot(toCur, moveDir) / jumpDist;
    alongTrail = clamp(alongTrail, 0.0, 1.0);

    // Strongest near current cursor position, fading toward where it came from.
    // The "tail" trails behind the cursor's destination.
    float tailBias = pow(alongTrail, 2.0);

    // Directional bias: pixels directly behind the cursor (along motion axis)
    // get much more displacement than pixels off to the side.
    // This makes the smear clearly directional like a comet tail.
    vec2 perpDir = vec2(-moveDir.y, moveDir.x);
    float perpDist = abs(dot(fragCoord - curCenter, perpDir));
    float directionalFocus = exp(-perpDist * perpDist / (trailRadius * trailRadius * 0.12));

    float smearAmount = intensity * trailInfluence * directionalFocus * SMEAR_STRENGTH;

    vec2 offset = smearDir * smearAmount * tailBias * iCurrentCursor.zw.y * 0.5;
    vec2 smearUV = (fragCoord + offset) / iResolution.xy;
    smearUV = clamp(smearUV, 0.0, 1.0);

    // Chromatic aberration via Cauchy dispersion: n(λ) = A + B/λ²
    // Wavelengths: R=650nm, G=550nm, B=450nm
    // Dispersion offset ∝ (n(λ) - n_ref), normalized so green is zero.
    // Cauchy B coefficient scaled for visual effect.
    float cauchyB = 8000.0; // nm² — controls dispersion spread
    float nR = cauchyB / (650.0 * 650.0); // 0.0189
    float nG = cauchyB / (550.0 * 550.0); // 0.0264
    float nB = cauchyB / (450.0 * 450.0); // 0.0395
    // Relative to green (center channel): red bends less, blue bends more
    float dispR = nR - nG; // negative (less refraction)
    float dispG = 0.0;
    float dispB = nB - nG; // positive (more refraction) — and |dispB| > |dispR|

    // Radial scaling: aberration is zero on the optical axis (trail center)
    // and increases toward the periphery, like a real lens.
    float radialScale = perpDist / max(trailRadius, 1.0);
    radialScale = smoothstep(0.0, 1.0, radialScale); // smooth ramp from center

    float aberration = 120.0; // overall aberration strength in pixels
    float abScale = aberration * smearAmount * tailBias * radialScale / SMEAR_STRENGTH;
    vec2 uvR = clamp((fragCoord + offset + smearDir * dispR * abScale) / iResolution.xy, 0.0, 1.0);
    vec2 uvG = clamp((fragCoord + offset + smearDir * dispG * abScale) / iResolution.xy, 0.0, 1.0);
    vec2 uvB = clamp((fragCoord + offset + smearDir * dispB * abScale) / iResolution.xy, 0.0, 1.0);

    vec4 original = texture(iChannel0, uv);
    vec4 smeared;
    smeared.r = texture(iChannel0, uvR).r;
    smeared.g = texture(iChannel0, uvG).g;
    smeared.b = texture(iChannel0, uvB).b;
    smeared.a = 1.0;

    float blend = trailInfluence * directionalFocus * intensity * 0.65;
    fragColor = mix(original, smeared, blend);

    // Cartoon cloud: soft white haze that follows the smear shape
    float cloudAlpha = blend * tailBias * 0.12;
    fragColor.rgb = mix(fragColor.rgb, vec3(1.0), cloudAlpha);
}
