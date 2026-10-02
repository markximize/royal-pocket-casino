-- PURPOSE: Observe mapped and raw controller events without guessing buttons.
-- CHANGE THIS MODULE WHEN: Input logging or diagnostic navigation changes.
-- DO NOT PUT HERE: Game actions, device-specific hardcoded button numbers.

local input = {}
input.labels = { "UP", "DOWN", "LEFT", "RIGHT", "A", "B", "X", "Y", "L", "R", "START", "SELECT" }
local mapped_labels = {
    dpup = "UP",
    dpdown = "DOWN",
    dpleft = "LEFT",
    dpright = "RIGHT",
    a = "A",
    b = "B",
    x = "X",
    y = "Y",
    leftshoulder = "L",
    rightshoulder = "R",
    start = "START",
    back = "SELECT",
}

function input.new()
    return { seen = {}, log = {}, last_mapped = "none", last_raw = "none", controllers = {} }
end

function input.remember(state, message)
    state.log[#state.log + 1] = message
    if #state.log > 80 then
        table.remove(state.log, 1)
    end
end

-- ## CONTROLLER DETECTION

function input.refresh_controllers(state)
    state.controllers = {}
    for _, joystick in ipairs(love.joystick.getJoysticks()) do
        state.controllers[#state.controllers + 1] = {
            id = joystick:getID(),
            name = joystick:getName(),
            guid = joystick:getGUID(),
            mapped = joystick:isGamepad(),
            buttons = joystick:getButtonCount(),
            axes = joystick:getAxisCount(),
            hats = joystick:getHatCount(),
        }
    end
end

-- ## MAPPED AND RAW EVENTS

function input.gamepad_button(state, joystick, button, pressed)
    local label = mapped_labels[button] or button
    local message =
        string.format("pad %s %s %s", joystick:getID(), label, pressed and "down" or "up")
    state.last_mapped = message
    input.remember(state, message)
    if pressed then
        state.seen[label] = true
        return label
    end
end

function input.raw_button(state, joystick, button, pressed)
    local message = string.format(
        "raw pad %s button %d %s",
        joystick:getID(),
        button,
        pressed and "down" or "up"
    )
    state.last_raw = message
    input.remember(state, message)
end

function input.raw_hat(state, joystick, hat, direction)
    local message = string.format("raw pad %s hat %d = %s", joystick:getID(), hat, direction)
    state.last_raw = message
    input.remember(state, message)
end

function input.raw_axis(state, joystick, axis, value)
    -- A bounded log records useful movement, not thousands of tiny drift events.
    if math.abs(value) >= 0.75 then
        state.last_raw = string.format("raw pad %s axis %d = %.2f", joystick:getID(), axis, value)
    end
end

function input.keyboard(state, key)
    state.last_mapped = "keyboard " .. key .. " (not controller evidence)"
    input.remember(state, state.last_mapped)
end

return input
