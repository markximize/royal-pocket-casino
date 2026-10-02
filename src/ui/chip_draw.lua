-- PURPOSE: Draw original denomination chips and a small visual wager stack.
-- CHANGE THIS MODULE WHEN: Chip presentation or readable denominations change.
-- DO NOT PUT HERE: Bankroll arithmetic, bet legality or real-money imagery.

local components = require("src.ui.components")
local chip = {}
local colors =
    { [5] = { 0.66, 0.21, 0.19 }, [10] = { 0.17, 0.36, 0.58 }, [25] = { 0.13, 0.43, 0.30 } }

function chip.draw(fonts, denomination, x, y, radius, focused, enabled)
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.ellipse("fill", x + 2, y + 5, radius, radius)
    love.graphics.setColor(enabled == false and components.colors.disabled or colors[denomination])
    love.graphics.circle("fill", x, y, radius)
    love.graphics.setColor(components.colors.ivory)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", x, y, radius - 3)
    for index = 0, 7 do
        local angle = index * math.pi / 4
        local inner, outer = radius - 7, radius - 1
        love.graphics.setLineWidth(4)
        love.graphics.line(
            x + math.cos(angle) * inner,
            y + math.sin(angle) * inner,
            x + math.cos(angle) * outer,
            y + math.sin(angle) * outer
        )
    end
    love.graphics.setLineWidth(focused and 2 or 1)
    love.graphics.setColor(focused and components.colors.gold or components.colors.ivory)
    love.graphics.circle("line", x, y, radius + (focused and 4 or 0))
    components.text(
        fonts.body,
        tostring(denomination),
        x - radius,
        y - 11,
        components.colors.ivory,
        radius * 2,
        "center"
    )
end

function chip.stack(fonts, units, x, y)
    local remaining = math.floor(units / 10)
    local column = 0
    for _, denomination in ipairs({ 25, 10, 5 }) do
        local count = math.floor(remaining / denomination)
        remaining = remaining - count * denomination
        if count > 0 then
            for level = 1, math.min(count, 5) do
                chip.draw(fonts, denomination, x + column * 48, y - level * 4, 17, false, true)
            end
            column = column + 1
        end
    end
end

return chip
