// Rounded cursor trail shader for Ghostty.
// Based on sahaj-b/ghostty-cursor-shaders cursor_tail.glsl, but draws the
// trail as a rounded capsule between cursor centers so old cursor corners do
// not remain visible during fast tmux cursor movement.

vec3 sRGBToLinear(vec3 c) {
    return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec4 TRAIL_COLOR = vec4(sRGBToLinear(iCurrentCursorColor.rgb), iCurrentCursorColor.a);
const float DURATION = 0.09;
const float MAX_TRAIL_LENGTH = 0.2;
const float THRESHOLD_MIN_DISTANCE = 1.5;
const float BLUR = 2.5;
const float PI = 3.14159265359;

float ease(float x) {
    return sqrt(1.0 - pow(x - 1.0, 2.0));
}

vec2 normalize(vec2 value, float isPosition) {
    return (value * 2.0 - (iResolution.xy * isPosition)) / iResolution.y;
}

float antialias(float distance) {
    return 1.0 - smoothstep(0.0, normalize(vec2(BLUR, BLUR), 0.0).x, distance);
}

float sdfRectangle(in vec2 p, in vec2 xy, in vec2 b) {
    vec2 d = abs(p - xy) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float sdfCapsule(in vec2 p, in vec2 a, in vec2 b, float r) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float denom = dot(ba, ba);

    // When the animated head/tail collapse near the end of the trail, avoid
    // dividing by ~0. That unstable edge case can leave tiny antialiasing
    // fragments outside the real cursor until another cursor redraw happens.
    if (denom < 0.000001) {
        return length(pa) - r;
    }

    float h = clamp(dot(pa, ba) / denom, 0.0, 1.0);
    return length(pa - ba * h) - r;
}

vec2 cursorCenter(vec4 cursor) {
    // Cursor is supplied as top-left x/y plus width/height. In normalized
    // coordinates y grows upward, so the center is x + w/2, y - h/2.
    return vec2(cursor.x + cursor.z * 0.5, cursor.y - cursor.w * 0.5);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
#if !defined(WEB)
    fragColor = texture(iChannel0, fragCoord.xy / iResolution.xy);
#endif

    vec2 vu = normalize(fragCoord, 1.0);
    vec4 currentCursor = vec4(normalize(iCurrentCursor.xy, 1.0), normalize(iCurrentCursor.zw, 0.0));
    vec4 previousCursor = vec4(normalize(iPreviousCursor.xy, 1.0), normalize(iPreviousCursor.zw, 0.0));

    vec2 currentCenter = cursorCenter(currentCursor);
    vec2 previousCenter = cursorCenter(previousCursor);
    vec2 delta = previousCenter - currentCenter;
    float lineLength = length(delta);

    vec4 newColor = vec4(fragColor);
    float minDist = currentCursor.w * THRESHOLD_MIN_DISTANCE;
    float progress = clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0);

    // Stop drawing the trail before the animation fully completes. The final
    // clean frames restore the unmodified terminal framebuffer, which prevents
    // low-alpha edge residue from lingering when TUI apps hide the hardware
    // cursor after tmux copy-mode transitions.
    if (progress < 0.85 && lineLength > minDist) {
        float tailDelay = MAX_TRAIL_LENGTH / lineLength;
        float isLongMove = step(MAX_TRAIL_LENGTH, lineLength);

        float headEasedShort = ease(progress);
        float tailEasedShort = ease(smoothstep(tailDelay, 1.0, progress));
        float headEasedLong = 1.0;
        float tailEasedLong = ease(progress);

        float headEased = mix(headEasedLong, headEasedShort, isLongMove);
        float tailEased = mix(tailEasedLong, tailEasedShort, isLongMove);

        vec2 head = mix(previousCenter, currentCenter, headEased);
        vec2 tail = mix(previousCenter, currentCenter, tailEased);

        // Use a rounded capsule rather than a cursor-sized rectangle. This is
        // what removes the lingering L-shaped/corner artifacts at old cursor
        // positions while preserving the motion trail.
        float radius = min(currentCursor.z, currentCursor.w) * 0.5;
        float sdfTrail = sdfCapsule(vu, tail, head, radius);
        float trailAlpha = antialias(sdfTrail);
        trailAlpha *= 1.0 - smoothstep(0.65, 0.85, progress);
        trailAlpha = trailAlpha < 0.03 ? 0.0 : trailAlpha;
        newColor = mix(newColor, TRAIL_COLOR, trailAlpha);

        // Do not draw over the real current cursor.
        float sdfCurrentCursor = sdfRectangle(vu, currentCenter, currentCursor.zw * 0.5);
        newColor = mix(newColor, fragColor, step(sdfCurrentCursor, 0.0));
    }

    fragColor = newColor;
}
