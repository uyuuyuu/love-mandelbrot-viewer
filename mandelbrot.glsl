// Uniform variables passed from Lua
extern vec2 u_center;        // Viewport center in complex plane (Real, Imag)
extern float u_scale;       // Zoom level: complex plane span corresponding to screen width
extern int u_maxIterations;  // Maximum iterations (for the shader loop)
extern float u_time;

// Love2D/GLSL shader entry point
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // Screen aspect ratio
    float aspect = love_ScreenSize.x / love_ScreenSize.y;

    // 1. Map screen coordinates (screen_coords) to point c in complex plane
    // screen_coords range is [0, width] x [0, height]
    // Normalize to [-1, 1] space
    vec2 uv = screen_coords.xy / love_ScreenSize.xy; // (0 to 1)
    uv = uv * 2.0 - 1.0;                            // (-1 to 1)

    // Adjust aspect ratio and apply zoom
    // u_scale represents the complex plane span for the entire screen width
    vec2 c = u_center + vec2(uv.x * aspect, uv.y) * u_scale * 0.5;

    // 2. Mandelbrot iteration core (z_{n+1} = z_n^2 + c)
    vec2 z = vec2(0.0);
    int iterations = 0;
    float R_SQUARED = 4.0; // Escape radius squared (2.0 * 2.0)

    // Note: GLSL loop variable must be int and range must be determinable
    for (int i = 0; i < 1000; i++) {
        if (i >= u_maxIterations) break; // Early exit

        float zr_sq = z.x * z.x;
        float zi_sq = z.y * z.y;

        if (zr_sq + zi_sq > R_SQUARED) {
            iterations = i;
            break;
        }

        // New z.x (real part) = z.x^2 - z.y^2 + c.x
        float temp_z_x = zr_sq - zi_sq + c.x;

        // New z.y (imaginary part) = 2 * z.x * z.y + c.y
        z.y = 2.0 * z.x * z.y + c.y;
        z.x = temp_z_x;

        iterations = i;
    }

    // 3. Smooth coloring
    vec3 finalColor;
    if (iterations == u_maxIterations) {
        // Points inside the set: black
        finalColor = vec3(0.0);
    } else {
        // Points outside the set: color by iteration count
        // Use log trick for smoother color transitions (Escape Time Algorithm)
        float log_zn = log(z.x*z.x + z.y*z.y) / 2.0;
        float nu = log(log_zn / log(2.0)) / log(2.0);
        float t = float(iterations) + 1.0 - nu; // Smooth iteration count

        // Map t to color (simple example: periodic colors)
        float freq = 0.15; // Color frequency
        // Use u_time to make colors dynamic
        finalColor.r = 0.5 + 0.5 * cos(freq * (t + 30.0 * u_time));
        finalColor.g = 0.5 + 0.5 * cos(freq * (t + 30.0 * u_time) + 2.0);
        finalColor.b = 0.5 + 0.5 * cos(freq * (t + 30.0 * u_time) + 4.0);
    }

    return vec4(finalColor, 1.0);
}
