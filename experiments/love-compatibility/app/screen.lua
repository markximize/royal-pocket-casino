-- PURPOSE: Draw one readable 640x480 diagnostic and a tiny animation strip.
-- CHANGE THIS MODULE WHEN: Diagnostic layout/readability needs adjusting.
-- DO NOT PUT HERE: Storage, controller mappings, or hardware verdicts.

local input = require("input")
local screen = {}
local ivory = { 0.94, 0.93, 0.86 }
local gold = { 0.78, 0.65, 0.34 }
local green = { 0.20, 0.48, 0.36 }

function screen.new()
    return {
        title = love.graphics.newFont(22),
        body = love.graphics.newFont(18),
        detail = love.graphics.newFont(16),
    }
end

local function text(font, message, x, y, color)
    love.graphics.setFont(font)
    love.graphics.setColor(color or ivory)
    love.graphics.print(message, x, y)
end

-- ## DIAGNOSTIC VIEW

function screen.draw(fonts, state)
    love.graphics.clear(0.025, 0.055, 0.045, 1)
    text(fonts.title, "ROYAL POCKET CASINO", 16, 9, gold)
    text(fonts.body, "Compatibility Test  /  MarkXimize Interactive", 16, 37)

    local width, height = love.graphics.getDimensions()
    text(fonts.body, string.format("Resolution: %d x %d", width, height), 16, 68)
    text(fonts.body, "LOVE " .. state.runtime.version .. " / " .. state.runtime.os, 321, 68)
    text(
        fonts.body,
        string.format(
            "FPS %d | Loop mean %.1f ms | p99 %.1f ms",
            love.timer.getFPS(),
            state.metrics.mean_ms,
            state.metrics.p99_ms
        ),
        16,
        94
    )

    local rss = state.memory.rss_kib and string.format("%.1f MiB", state.memory.rss_kib / 1024)
        or "unavailable"
    text(
        fonts.detail,
        string.format(
            "Lua heap %.0f KiB | Process RSS %s | >50ms %d",
            state.memory.lua_kib,
            rss,
            state.metrics.over_50_ms
        ),
        16,
        122
    )
    local controller = state.input.controllers[1]
    local controller_text = controller
            and string.format(
                "%s / mapped %s",
                controller.name:sub(1, 29),
                tostring(controller.mapped)
            )
        or "none detected"
    text(
        fonts.detail,
        string.format("Controllers %d: %s", #state.input.controllers, controller_text),
        16,
        147
    )
    text(fonts.body, "INPUT TEST  /  seen labels require physical confirmation", 16, 176, gold)

    for index, label in ipairs(input.labels) do
        local column = (index - 1) % 4
        local row = math.floor((index - 1) / 4)
        local x, y = 16 + column * 155, 202 + row * 33
        love.graphics.setColor(state.input.seen[label] and green or { 0.10, 0.15, 0.13 })
        love.graphics.rectangle("fill", x, y, 143, 28, 3, 3)
        text(fonts.body, label .. (state.input.seen[label] and " seen" or " --"), x + 7, y + 3)
    end

    text(fonts.detail, "Last mapped: " .. state.input.last_mapped:sub(1, 61), 16, 310)
    text(fonts.detail, "Last raw: " .. state.input.last_raw:sub(1, 65), 16, 332)
    text(
        fonts.body,
        string.format(
            "SAVE write %s | prior read %s | launches %d",
            state.save.write_status,
            state.save.previous_read,
            state.save.launch_count
        ),
        16,
        355
    )
    local status_message = state.exit_confirmation and "Exit selected: A/Enter again; B/Esc cancels"
        or state.message
    text(fonts.detail, status_message:sub(1, 76), 16, 382, gold)

    -- A few shapes exercise animation without texture assets or custom shaders.
    love.graphics.setColor(green)
    love.graphics.rectangle("fill", 16, 408, 608, 15, 3, 3)
    love.graphics.setColor(ivory)
    love.graphics.circle("fill", 75 + 30 * math.sin(state.elapsed * 2), 415, 5)
    love.graphics.setColor(gold)
    love.graphics.rectangle("fill", 280 + 40 * math.sin(state.elapsed), 410, 10, 10)
    love.graphics.setColor(ivory)
    love.graphics.polygon("fill", 540, 409, 547 + 5 * math.sin(state.elapsed), 419, 533, 419)

    for index, action in ipairs(state.actions) do
        local x = 16 + (index - 1) * 155
        love.graphics.setColor(index == state.selected_action and gold or { 0.10, 0.15, 0.13 })
        love.graphics.rectangle("line", x, 431, 143, 28, 3, 3)
        text(fonts.body, action, x + 18, 434)
    end
    text(fonts.detail, "D-pad/arrows: choose | A/Enter: run | Esc: exit", 16, 460)
end

return screen
