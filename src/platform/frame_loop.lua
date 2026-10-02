-- PURPOSE: Cap desktop loop work at 60 Hz when the driver ignores VSync.
-- CHANGE THIS MODULE WHEN: Measured pacing or framework lifecycle requires it.
-- DO NOT PUT HERE: Game decisions, sleep inside the domain or hardware claims.

local frame_loop = {}

function frame_loop.run()
    if love.load then
        love.load(love.arg.parseGameArguments(arg), arg)
    end
    love.timer.step()
    return function()
        local frame_start = love.timer.getTime()
        love.event.pump()
        for name, first, second, third, fourth, fifth, sixth in love.event.poll() do
            if name == "quit" then
                if not love.quit or not love.quit() then
                    return first or 0
                end
            end
            love.handlers[name](first, second, third, fourth, fifth, sixth)
        end
        local elapsed = love.timer.step()
        if love.update then
            love.update(elapsed)
        end
        if love.graphics and love.graphics.isActive() then
            love.graphics.origin()
            love.graphics.clear(love.graphics.getBackgroundColor())
            if love.draw then
                love.draw()
            end
            love.graphics.present()
        end
        -- Include present() blocking time so working VSync is not capped twice.
        local remaining = 1 / 60 - (love.timer.getTime() - frame_start)
        if remaining > 0 then
            love.timer.sleep(remaining)
        end
    end
end

return frame_loop
