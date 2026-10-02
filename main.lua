-- PURPOSE: Compose LÖVE lifecycle callbacks for the desktop preview.
-- CHANGE THIS MODULE WHEN: Callback wiring or test entry points change.
-- DO NOT PUT HERE: Blackjack rules, payouts, save parsing or card widgets.

local desktop = require("src.app.desktop")
local input = require("src.platform.love_input")
local app

love.run = require("src.platform.frame_loop").run

function love.load(arguments)
    local smoke_test = false
    for _, argument in ipairs(arguments) do
        if argument == "--self-test" then
            require("tests.run").all(require("src.platform.native_storage").hash)
            love.event.quit(0)
            return
        end
        if argument == "--smoke-test" then
            smoke_test = true
        end
    end
    app = desktop.new(smoke_test)
end

function love.update(elapsed)
    if app then
        desktop.update(app, elapsed)
    end
end
function love.draw()
    if app then
        desktop.draw(app)
    end
end
function love.quit()
    desktop.quit(app)
end
function love.keypressed(key, _scancode, repeated)
    if app and not repeated then
        desktop.intent(app, input.key(key))
    end
end
function love.gamepadpressed(_joystick, button)
    if app then
        desktop.intent(app, input.gamepad(button))
    end
end
function love.mousepressed(x, y, button)
    if app and button == 1 then
        desktop.mouse(app, x, y)
    end
end
