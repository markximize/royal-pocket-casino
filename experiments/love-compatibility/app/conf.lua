-- PURPOSE: Configure this disposable diagnostic, not the production game.
-- CHANGE THIS MODULE WHEN: The test window or enabled framework modules change.
-- DO NOT PUT HERE: Device paths, controller assumptions, or casino rules.

function love.conf(configuration)
    configuration.identity = "royal-pocket-casino-compatibility"
    configuration.version = "11.5"
    configuration.console = true
    configuration.window.title = "Royal Pocket Casino - Compatibility Test"
    configuration.window.width = 640
    configuration.window.height = 480
    configuration.window.resizable = false
    configuration.window.vsync = 1
    configuration.window.msaa = 0
    configuration.window.highdpi = false
    configuration.modules.physics = false
    configuration.modules.video = false
    configuration.modules.thread = false

    -- Headless verification still uses the real LÖVE filesystem module.
    for _, argument in ipairs(arg or {}) do
        if argument == "--handheld" then
            configuration.window.fullscreen = true
            configuration.window.fullscreentype = "desktop"
        end
        if argument == "--self-test" then
            configuration.window = nil
            configuration.modules.graphics = false
            configuration.modules.audio = false
            configuration.modules.joystick = false
        end
    end
end
