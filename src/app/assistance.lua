-- PURPOSE: Prepare optional advice from the shared strategy and public count.
-- CHANGE THIS MODULE WHEN: Assistance visibility or explanatory presentation changes.
-- DO NOT PUT HERE: Dealing, outcome judgments, index data or save writes.

local strategy = require("src.training.basic_strategy")
local deviations = require("src.training.deviations")
local count_view = require("src.app.count_view")
local assistance = {}

function assistance.build(game, visible, preferences, count_settings)
    if not preferences or preferences.mode == "off" or visible.animating then
        return nil
    end
    local basic = strategy.recommend(game)
    if not basic then
        return nil
    end
    local advice = { basic = basic }
    if preferences.mode == "advanced" then
        advice.counts = count_view.build(game, visible, count_settings)
        advice.profile_supported, advice.profile_reason = deviations.supported(game.rules)
        if preferences.deviations then
            advice.deviation = deviations.recommend(game, advice.counts, basic)
        end
    end
    advice.action = advice.deviation and advice.deviation.action or basic.action
    return advice
end

return assistance
