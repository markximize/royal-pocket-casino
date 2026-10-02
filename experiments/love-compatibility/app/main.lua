-- PURPOSE: Connect framework callbacks to the isolated diagnostic modules.
-- CHANGE THIS MODULE WHEN: Diagnostic actions or application lifecycle change.
-- DO NOT PUT HERE: Casino logic or platform-specific launch paths.

local platform = require("platform")
local input = require("input")
local frame_metrics = require("frame_metrics")
local screen = require("screen")
local state, fonts, tone
local smoke_test = false
local screenshot_requested = false

local function has_argument(arguments, name)
    for _, argument in ipairs(arguments) do
        if argument == name then
            return true
        end
    end
    return false
end

-- ## APPLICATION LIFECYCLE

function love.load(arguments)
    if has_argument(arguments, "--self-test") then
        require("self_test").run()
        love.event.quit(0)
        return
    end
    smoke_test = has_argument(arguments, "--smoke-test")
    state = {
        runtime = platform.runtime_info(),
        input = input.new(),
        metrics = frame_metrics.new(),
        memory = platform.memory_info(),
        elapsed = 0,
        refresh_elapsed = 0,
        save = platform.begin_launch(),
        actions = { "TONE", "SAVE", "REPORT", "EXIT" },
        selected_action = 1,
        tone_requests = 0,
        message = "AUDIO READY: select TONE; confirm sound yourself",
    }
    input.refresh_controllers(state.input)
    fonts = screen.new()
    local tone_error
    tone, tone_error = platform.create_tone()
    state.tone_ready = tone ~= nil
    state.audio_error = tone_error
    if not tone then
        state.message = "AUDIO FAIL: " .. tostring(tone_error)
    elseif state.save.error then
        state.message = "SAVE ERROR: " .. state.save.error
    end
    print("Royal Pocket Casino compatibility diagnostic 1")
    print("LOVE " .. state.runtime.version .. "; OS " .. state.runtime.os)
    print("Save directory: " .. state.runtime.save_directory)
end

local function write_report()
    local contents = require("report").build(state)
    local written, write_error = platform.write_report(contents)
    state.message = written and "REPORT written to diagnostic save directory"
        or "REPORT FAIL: " .. tostring(write_error)
    if platform.test_output_directory() then
        platform.write_test_artifact("desktop-report.txt", contents)
    end
    return contents
end

local function activate_action()
    local action = state.actions[state.selected_action]
    if action == "TONE" then
        local played, play_error = platform.play_tone(tone)
        state.audio_error = nil
        if not played then
            state.audio_error = tostring(play_error)
        end
        state.tone_requests = state.tone_requests + 1
        state.message = played and "AUDIO requested 440 Hz tone; hearing is NOT verified"
            or "AUDIO FAIL: " .. tostring(play_error)
    elseif action == "SAVE" then
        platform.write_save(state.save, "manual_write")
        state.message = "SAVE "
            .. state.save.write_status
            .. (state.save.error and ": " .. state.save.error or ": readback checked")
    elseif action == "REPORT" then
        write_report()
    elseif state.exit_confirmation then
        love.event.quit()
    else
        state.exit_confirmation = true
    end
end

local function navigate(label)
    if label == "B" and state.exit_confirmation then
        state.exit_confirmation = false
    elseif label == "A" then
        activate_action()
    elseif label == "LEFT" or label == "UP" then
        state.selected_action = (state.selected_action - 2) % #state.actions + 1
        state.exit_confirmation = false
    elseif label == "RIGHT" or label == "DOWN" then
        state.selected_action = state.selected_action % #state.actions + 1
        state.exit_confirmation = false
    end
end

function love.update(delta_seconds)
    if not state then
        return
    end
    state.elapsed = state.elapsed + delta_seconds
    state.refresh_elapsed = state.refresh_elapsed + delta_seconds
    frame_metrics.record(state.metrics, delta_seconds)
    if state.refresh_elapsed >= 1 then
        state.refresh_elapsed = 0
        frame_metrics.refresh(state.metrics)
        state.memory = platform.memory_info()
    end
    if smoke_test then
        if state.elapsed >= 1 and state.tone_requests == 0 then
            activate_action()
        elseif state.elapsed >= 5 and screenshot_requested then
            love.event.quit()
        end
    end
end

function love.draw()
    if not state then
        return
    end
    screen.draw(fonts, state)
    if smoke_test and state.elapsed >= 4 and not screenshot_requested then
        screenshot_requested = true
        love.graphics.captureScreenshot(function(image_data)
            local encoded = image_data:encode("png")
            local written, screenshot_error =
                platform.write_test_artifact("desktop-screen.png", encoded:getString())
            assert(written, screenshot_error)
        end)
    end
end

function love.quit()
    if state then
        write_report()
        if tone then
            tone:stop()
        end
    end
end

-- ## CONTROLLER AND KEYBOARD CALLBACKS

function love.gamepadpressed(joystick, button)
    navigate(input.gamepad_button(state.input, joystick, button, true))
end

function love.gamepadreleased(joystick, button)
    input.gamepad_button(state.input, joystick, button, false)
end

function love.joystickpressed(joystick, button)
    input.raw_button(state.input, joystick, button, true)
end

function love.joystickreleased(joystick, button)
    input.raw_button(state.input, joystick, button, false)
end

function love.joystickhat(joystick, hat, direction)
    input.raw_hat(state.input, joystick, hat, direction)
end

function love.joystickaxis(joystick, axis, value)
    input.raw_axis(state.input, joystick, axis, value)
end

function love.joystickadded()
    if state then
        input.refresh_controllers(state.input)
    end
end

function love.joystickremoved()
    if state then
        input.refresh_controllers(state.input)
    end
end

function love.keypressed(key, scancode, is_repeat)
    if not state or is_repeat then
        return
    end
    input.keyboard(state.input, key)
    if key == "escape" then
        if state.exit_confirmation then
            state.exit_confirmation = false
        else
            love.event.quit()
        end
        return
    end
    local labels = { left = "LEFT", right = "RIGHT", up = "UP", down = "DOWN", ["return"] = "A" }
    navigate(labels[key])
end
