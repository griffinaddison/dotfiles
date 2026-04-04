// Cursor beacon shader — water droplet ripple
// Simulates a water drop hitting the terminal surface on focus gain.
// Uses the 2D wave equation: sinusoidal ripples propagating inward
// with 1/√r amplitude falloff and refractive lensing of terminal content.

const float DURATION = 0.7;           // seconds for ripples to fade
const float WAVE_SPEED = 450.0;       // pixels/sec — ripple propagation speed
const float WAVELENGTH = 480.0;       // pixels between wave crests
const float AMPLITUDE = 20.0;         // pixels — peak refraction displacement
const float DAMPING = 2.0;            // exponential damping rate
const float NUM_WAVES = 5.0;          // number of visible wave crests

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    if (iFocus == 0) {
        fragColor = texture(iChannel0, uv);
        return;
    }

    float timeSince = iTime - iTimeFocus;
    if (timeSince > DURATION) {
        fragColor = texture(iChannel0, uv);
        return;
    }

    vec2 curCenter = iCurrentCursor.xy + iCurrentCursor.zw * vec2(0.5, -0.5);
    vec2 toFrag = fragCoord - curCenter;
    float dist = length(toFrag);
    vec2 radialDir = (dist > 0.1) ? toFrag / dist : vec2(0.0, 1.0);

    // Contracting ripple: wavefront starts far and collapses inward
    float maxRadius = WAVE_SPEED * DURATION;
    float wavefront = maxRadius - WAVE_SPEED * timeSince;

    // Signed distance from this fragment to the wavefront
    float fromFront = dist - wavefront;

    // Only ripple behind the wavefront (where it has already passed)
    // Sinusoidal wave with spatial frequency 2π/wavelength
    float k = 6.2832 / WAVELENGTH;
    float wave = sin(fromFront * k);

    // Envelope: waves exist only near/behind the wavefront, fade with distance from it
    // Also 1/√r amplitude falloff for 2D circular waves (conservation of energy)
    float behindFront = smoothstep(-5.0, 10.0, fromFront);
    float spatialEnvelope = exp(-max(fromFront, 0.0) / (WAVELENGTH * NUM_WAVES));
    float radialFalloff = 1.0 / max(sqrt(dist / 50.0), 1.0);
    float timeFade = exp(-timeSince * DAMPING);

    float height = wave * behindFront * spatialEnvelope * radialFalloff * timeFade;

    // Refraction: displace UV sampling based on wave height gradient
    // Water surface normal tilts radially, bending light like a lens
    vec2 refractOffset = radialDir * height * AMPLITUDE / iResolution.xy;
    vec2 refractedUV = clamp(uv + refractOffset, 0.0, 1.0);
    fragColor = texture(iChannel0, refractedUV);

    // Caustic brightening at wave peaks (light focuses at crests)
    float caustic = height * height * 2.0;
    fragColor.rgb += vec3(caustic) * timeFade * 1.2;

    // Subtle specular highlight on wave crests
    float specular = max(height, 0.0);
    specular = pow(specular, 3.0);
    fragColor.rgb += vec3(1.0) * specular * timeFade * 0.5;
}
