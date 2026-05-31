-- ==============================================================================
-- 2. Love2D Main Program (Lua)
-- ==============================================================================

local G = {} -- Global state table

function love.load()
    love.window.setFullscreen(true)
    local w, h = love.graphics.getDimensions()
    love.window.setTitle("Mandelbrot Explorer (Love2D Shader)")

    -- Initialize Mandelbrot state
    G.center_re = -0.5     -- Viewport center real part (Re)
    G.center_im = 0.0      -- Viewport center imaginary part (Im)
    G.scale = 3.0          -- Viewport width (complex plane span for entire screen)
    G.maxIterations = 100  -- Default iterations
    G.isDragging = false   -- Drag state flag
    G.lastMouseX = 0       -- Last mouse X position
    G.lastMouseY = 0       -- Last mouse Y position

    -- Flag to control whether program has started
    G.isStarted = false

    -- Font for warning screen
    G.fontLarge = love.graphics.newFont(32)
    G.fontSmall = love.graphics.newFont(20)

    -- Create shader
    G.shader = love.graphics.newShader("mandelbrot.glsl")

    -- To apply the shader, we draw a full-screen quad
    G.canvas = love.graphics.newCanvas(w, h)
end

-- Convert screen coordinates (px, py) to complex plane (c_re, c_im)
function screenToComplex(px, py)
    local w, h = love.graphics.getDimensions()
    local aspect = w / h

    -- Normalize to [-1, 1] space
    local uv_x = (px / w) * 2 - 1
    local uv_y = (py / h) * 2 - 1

    -- Map to complex plane
    local c_re = G.center_re + uv_x * aspect * G.scale * 0.5
    local c_im = G.center_im + uv_y * G.scale * 0.5

    return c_re, c_im
end

-- ==============================================================================
-- 3. Input: Keyboard (SPACE to start)
-- ==============================================================================

function love.keypressed(key)
    -- Before start: press SPACE to enter main view
    if not G.isStarted and key == 'space' then
        G.isStarted = true
    end
    -- After start: press Q to increase iterations
    if G.isStarted and key == 'q' then
        G.maxIterations = G.maxIterations + 50
    end
    -- After start: press A to decrease iterations
    if G.isStarted and key == 'a' then
        G.maxIterations = math.max(10, G.maxIterations - 50)
    end
end

-- ==============================================================================
-- 4. Input: Drag (Pan) - only active after start
-- ==============================================================================

function love.mousepressed(x, y, button, isTouch)
    if not G.isStarted then return end -- Ignore input before start
    -- Middle mouse button (button 3) for dragging
    if button == 3 then
        G.isDragging = true
        G.lastMouseX = x
        G.lastMouseY = y
    end
end

function love.mousereleased(x, y, button, isTouch)
    if not G.isStarted then return end
    if button == 3 then
        G.isDragging = false
    end
end

function love.mousemoved(x, y, dx, dy)
    if not G.isStarted then return end
    -- Drag logic
    if G.isDragging then
        local w, h = love.graphics.getDimensions()
        local aspect = w / h

        -- Calculate complex plane delta per pixel
        local scale_factor_re = G.scale * aspect / w
        local scale_factor_im = G.scale / h

        -- Update center: drag direction opposite to center movement
        G.center_re = G.center_re - dx * scale_factor_re
        G.center_im = G.center_im - dy * scale_factor_im
    end
end

-- ==============================================================================
-- 5. Input: Zoom - only active after start
-- ==============================================================================

function love.wheelmoved(x, y)
    if not G.isStarted then return end
    
    local mouse_x, mouse_y = love.mouse.getPosition()
    local zoom_factor = 1.25 -- Zoom multiplier per step
    local zoom_amount = y    -- y > 0 scroll up (zoom in), y < 0 scroll down (zoom out)

    if zoom_amount ~= 0 then
        -- 1. Record current mouse position in complex plane (as new center)
        local c_re_before, c_im_before = screenToComplex(mouse_x, mouse_y)

        -- 2. Apply zoom
        if zoom_amount > 0 then
            G.scale = G.scale / zoom_factor
        else
            G.scale = G.scale * zoom_factor
        end

        -- 3. Recalculate mouse position in complex plane after zoom
        local c_re_after, c_im_after = screenToComplex(mouse_x, mouse_y)

        -- 4. Offset center to keep mouse position fixed on screen
        G.center_re = G.center_re + (c_re_before - c_re_after)
        G.center_im = G.center_im + (c_im_before - c_im_after)
    end
end

-- ==============================================================================
-- 6. Render and Update
-- ==============================================================================

function love.update(dt)
    -- Update time regardless of start state, to keep shader animation accurate
    G.time = love.timer.getTime()
    G.shader:send("u_time", G.time)
end

function love.draw()
    local w, h = love.graphics.getDimensions()
    
    if not G.isStarted then
        -- Draw warning screen
        love.graphics.setColor(0.05, 0.05, 0.05) -- Dark background

        -- Warning title
        love.graphics.setColor(1, 0.2, 0.2) -- Red warning
        love.graphics.setFont(G.fontLarge)
        local warning_text = "Photosensitivity Warning"
        love.graphics.printf(warning_text, 0, h/2 - 100, w, "center")

        -- Warning message and prompt
        love.graphics.setColor(1, 1, 1) -- White text
        love.graphics.setFont(G.fontSmall)
        local message_text = "This program contains rapidly changing bright colors and complex patterns that may induce photosensitive epilepsy.\nIf you or a family member has a history of epilepsy, proceed with caution or exit immediately.\n\nPress the [SPACE] key to continue."
        love.graphics.printf(message_text, 0, h/2 - 30, w, "center")

        -- return -- Stop fractal drawing
    else

    -- *******************************************
    -- Main program (fractal rendering)
    -- *******************************************

    -- Bind shader to drawing context
    love.graphics.setShader(G.shader)

    -- Send uniform parameters to shader
    G.shader:send("u_center", {G.center_re, G.center_im})
    G.shader:send("u_scale", G.scale)
    G.shader:send("u_maxIterations", G.maxIterations)
    -- u_time is passed in love.update, ensuring real-time updates

    -- Draw a full-screen quad
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- Disable shader
    love.graphics.setShader()

    -- Display debug info
    love.graphics.setFont(G.fontSmall)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format("Center (C): %.10f + %.10fi", G.center_re, G.center_im), 10, 10)
    love.graphics.print(string.format("Scale: %.10f", G.scale), 10, 30)
    love.graphics.print(string.format("Max Iterations: %d (Q/A to adjust)", G.maxIterations), 10, 50)
    love.graphics.print("Zoom: Scroll Wheel | Pan: Middle Mouse Button", 10, 70)
    end
end
