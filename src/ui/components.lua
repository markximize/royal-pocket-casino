-- PURPOSE: Share cached fonts, palette and simple focusable button drawing.
-- CHANGE THIS MODULE WHEN: Basic readability, colors or button visuals change.
-- DO NOT PUT HERE: A widget framework, input routing or game state.

local components = {}
components.colors = {
    ivory = { 0.94, 0.92, 0.84 },
    gold = { 0.82, 0.69, 0.39 },
    muted = { 0.55, 0.62, 0.57 },
    panel = { 0.035, 0.095, 0.075 },
    felt = { 0.025, 0.15, 0.105 },
    disabled = { 0.25, 0.32, 0.28 },
}

function components.fonts()
    return {
        title = love.graphics.newFont(24),
        amount = love.graphics.newFont(26),
        body = love.graphics.newFont(18),
        detail = love.graphics.newFont(14),
        small = love.graphics.newFont(12),
        hero = love.graphics.newFont(38),
        rank = love.graphics.newFont(23),
    }
end

function components.text(font, message, x, y, color, width, alignment)
    love.graphics.setFont(font)
    love.graphics.setColor(color or components.colors.ivory)
    if width then
        love.graphics.printf(message, x, y, width, alignment or "left")
    else
        love.graphics.print(message, x, y)
    end
end

function components.amount(units, signed)
    local absolute = math.abs(units)
    local sign = units < 0 and "-" or signed and units > 0 and "+" or ""
    local label = string.format("%d", math.floor(absolute / 10))
    if absolute % 10 ~= 0 then
        label = label .. "." .. tostring(absolute % 10)
    end
    return sign .. label
end

function components.button(fonts, button, focused)
    if button.chip then
        require("src.ui.chip_draw").draw(
            fonts,
            button.chip,
            button.x + button.width / 2,
            button.y + button.height / 2,
            24,
            focused,
            button.enabled
        )
        return
    end
    local palette = components.colors
    love.graphics.setColor(focused and { 0.16, 0.20, 0.12 } or palette.panel)
    love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, 5, 5)
    love.graphics.setColor(
        not button.enabled and palette.disabled or focused and palette.gold or palette.muted
    )
    love.graphics.setLineWidth(focused and 2 or 1)
    love.graphics.rectangle("line", button.x, button.y, button.width, button.height, 5, 5)
    local caption_color = button.enabled and palette.ivory or palette.muted
    components.text(
        fonts.body,
        button.label,
        button.x + 4,
        button.y + (button.height - 21) / 2,
        caption_color,
        button.width - 8,
        "center"
    )
end

-- ## SHARED ORIGINAL TABLE AND BRAND ART

function components.crown(x, y, size)
    love.graphics.setColor(components.colors.gold)
    love.graphics.polygon(
        "fill",
        x - size,
        y - size * 0.5,
        x - size * 0.5,
        y,
        x,
        y - size,
        x + size * 0.5,
        y,
        x + size,
        y - size * 0.5,
        x + size * 0.75,
        y + size * 0.65,
        x - size * 0.75,
        y + size * 0.65
    )
    love.graphics.rectangle("fill", x - size * 0.75, y + size * 0.8, size * 1.5, size * 0.18)
end

local background_canvas
local function draw_background()
    love.graphics.clear(0.035, 0.065, 0.058)
    love.graphics.setColor(0.14, 0.11, 0.075)
    love.graphics.rectangle("fill", 8, 73, 624, 337, 28, 28)
    love.graphics.setColor(0.055, 0.20, 0.15)
    love.graphics.rectangle("fill", 14, 78, 612, 328, 25, 25)
    love.graphics.setColor(0.07, 0.23, 0.17, 0.5)
    -- A fixed vector pattern avoids texture files, per-frame randomness and large buffers.
    for row = 0, 24 do
        for column = 0, 42 do
            love.graphics.points(22 + column * 14 + row % 2 * 5, 85 + row * 13)
        end
    end
    love.graphics.setColor(
        components.colors.gold[1],
        components.colors.gold[2],
        components.colors.gold[3],
        0.55
    )
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", 19, 83, 602, 319, 21, 21)
end

function components.background()
    if not background_canvas then
        background_canvas = love.graphics.newCanvas(640, 480)
        local previous = love.graphics.getCanvas()
        love.graphics.push("all")
        love.graphics.setCanvas(background_canvas)
        draw_background()
        love.graphics.setCanvas(previous)
        love.graphics.pop()
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(background_canvas)
end

function components.contains(button, x, y)
    return x >= button.x
        and x <= button.x + button.width
        and y >= button.y
        and y <= button.y + button.height
end

return components
