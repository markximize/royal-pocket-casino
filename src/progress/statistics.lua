-- PURPOSE: Reduce completed/void summaries into exact lifetime counters once.
-- CHANGE THIS MODULE WHEN: A documented statistic definition changes.
-- DO NOT PUT HERE: Rule decisions, wagers, rendering or timestamp ordering.

local chips = require("src.blackjack.chips")
local statistics = { version = 1 }
statistics.names = {
    "completed_rounds",
    "settled_hands",
    "wins",
    "losses",
    "pushes",
    "natural_blackjacks",
    "player_busts",
    "hit_actions",
    "stand_actions",
    "split_actions",
    "double_actions",
    "main_staked_units",
    "main_returned_units",
    "main_net_units",
    "void_rounds",
    "chip_grants_units",
}

function statistics.new()
    local counters = {}
    for _, name in ipairs(statistics.names) do
        counters[name] = 0
    end
    return counters
end

function statistics.can_start(counters, bet_units)
    for _, name in ipairs(statistics.names) do
        if math.abs(counters[name]) > chips.maximum - math.max(512, bet_units * 16) then
            return false, "Statistics limit reached; existing progress preserved"
        end
    end
    return true
end

function statistics.record(counters, current_round)
    if current_round.result.void then
        counters.void_rounds = chips.add(counters.void_rounds, 1)
        return
    end
    local result = current_round.result
    counters.completed_rounds = chips.add(counters.completed_rounds, 1)
    counters.settled_hands = chips.add(counters.settled_hands, #result.hands)
    for _, row in ipairs(result.hands) do
        local category = row.outcome == "loss" and "losses"
            or row.outcome == "push" and "pushes"
            or "wins"
        counters[category] = chips.add(counters[category], 1)
        if row.natural then
            counters.natural_blackjacks = chips.add(counters.natural_blackjacks, 1)
        end
        if row.bust then
            counters.player_busts = chips.add(counters.player_busts, 1)
        end
    end
    for name, count in pairs(current_round.action_counts) do
        counters[name] = chips.add(counters[name], count)
    end
    counters.main_staked_units = chips.add(counters.main_staked_units, result.staked_units)
    counters.main_returned_units = chips.add(counters.main_returned_units, result.returned_units)
    counters.main_net_units = chips.add(counters.main_net_units, result.net_units)
end

return statistics
