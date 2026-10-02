-- PURPOSE: Configure the desktop preview and its separate save identity.
-- CHANGE THIS MODULE WHEN: Window or preview lifecycle settings change.
-- DO NOT PUT HERE: Gameplay decisions or platform launch paths.

function love.conf(configuration)
    configuration.identity = "royal-pocket-casino-desktop-preview"
    configuration.version = "11.5"
    configuration.console = false
    configuration.window.title = "Royal Pocket Casino - V0.1 Test Candidate"
    configuration.window.width = 640
    configuration.window.height = 480
    configuration.window.resizable = false
    configuration.window.highdpi = false
    configuration.window.vsync = 1
    configuration.modules.physics = false
    configuration.modules.video = false
    configuration.modules.thread = false
    for _, argument in ipairs(arg or {}) do
        if argument == "--handheld" then
            configuration.window.fullscreen = true
            configuration.window.fullscreentype = "desktop"
        end
        if argument == "--smoke-test" then
            configuration.identity = "royal-pocket-casino-preview-smoke"
        end
        if argument == "--self-test" then
            configuration.identity = "royal-pocket-casino-preview-tests"
            configuration.window = nil
            configuration.modules.graphics = false
            configuration.modules.audio = false
            configuration.modules.joystick = false
        end
    end
end
