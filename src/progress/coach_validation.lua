-- PURPOSE: Reject inconsistent coach aggregates, bounded history and wagers.
-- CHANGE THIS MODULE WHEN: Saved coaching evidence or its invariants change.
-- DO NOT PUT HERE: Default fields, migration, advice or storage repair.

local check = require("src.check")
local summary = require("src.progress.coach_summary")
local betting = require("src.progress.betting_analysis")
local validation = { history_limit = 15 }

local function contained_in_lifetime(state, candidate)
    for _, name in ipairs({ "play", "practice" }) do
        for category, score in pairs(candidate[name]) do
            local lifetime = state.lifetime[name][category]
            if
                score.attempts > lifetime.attempts
                or score.correct > lifetime.correct
                or score.attempts - score.correct > lifetime.attempts - lifetime.correct
            then
                return false
            end
        end
    end
    for _, name in ipairs({
        "rounds",
        "wins",
        "losses",
        "pushes",
        "blackjacks",
        "staked_units",
        "biggest_win_units",
        "biggest_loss_units",
        "max_drawdown_units",
        "best_win_streak",
        "best_loss_streak",
    }) do
        if candidate.results[name] > state.lifetime.results[name] then
            return false
        end
    end
    return true
end

local function valid_recorded_totals(state)
    local totals = summary.new(0)
    local available = { state.active }
    for _, completed in ipairs(state.recent) do
        available[#available + 1] = completed
    end
    for _, value in ipairs(available) do
        for _, group in ipairs({ "play", "practice" }) do
            for category, score in pairs(value[group]) do
                totals[group][category].attempts = totals[group][category].attempts + score.attempts
                totals[group][category].correct = totals[group][category].correct + score.correct
            end
        end
        for _, name in ipairs({
            "rounds",
            "wins",
            "losses",
            "pushes",
            "blackjacks",
            "staked_units",
            "net_units",
        }) do
            totals.results[name] = totals.results[name] + value.results[name]
        end
    end
    local complete_history = state.active.id == #state.recent + 1
    for _, group in ipairs({ "play", "practice" }) do
        for category, score in pairs(totals[group]) do
            local lifetime = state.lifetime[group][category]
            if
                score.attempts > lifetime.attempts
                or score.correct > lifetime.correct
                or score.attempts - score.correct > lifetime.attempts - lifetime.correct
                or (
                    complete_history
                    and (score.attempts ~= lifetime.attempts or score.correct ~= lifetime.correct)
                )
            then
                return false
            end
        end
    end
    for _, name in ipairs({ "rounds", "wins", "losses", "pushes", "blackjacks", "staked_units" }) do
        if
            totals.results[name] > state.lifetime.results[name]
            or (complete_history and totals.results[name] ~= state.lifetime.results[name])
        then
            return false
        end
    end
    if complete_history then
        return totals.results.net_units == state.lifetime.results.net_units
    end
    local omitted_stakes = state.lifetime.results.staked_units - totals.results.staked_units
    local omitted_net = state.lifetime.results.net_units - totals.results.net_units
    local omitted_rounds = state.lifetime.results.rounds - totals.results.rounds
    return omitted_stakes >= omitted_rounds * 50
        and omitted_net >= -omitted_stakes
        and omitted_net <= omitted_stakes * 1.5
end

local function valid_wager_totals(state)
    local reconstructed = summary.new(state.active.id)
    for _, observation in ipairs(state.wagers) do
        if not betting.valid_observation(observation) then
            return false
        end
        summary.round(reconstructed, observation)
    end
    local actual, recent = state.active.results, reconstructed.results
    if actual.rounds <= betting.limits.observations then
        for name, value in pairs(recent) do
            if actual[name] ~= value then
                return false
            end
        end
        return true
    end
    for _, name in ipairs({
        "wins",
        "losses",
        "pushes",
        "blackjacks",
        "staked_units",
        "biggest_win_units",
        "biggest_loss_units",
        "max_drawdown_units",
        "drawdown_units",
        "best_win_streak",
        "best_loss_streak",
    }) do
        if recent[name] > actual[name] then
            return false
        end
    end
    local earlier_stakes = actual.staked_units - recent.staked_units
    local earlier_net = actual.net_units - recent.net_units
    if
        earlier_stakes < (actual.rounds - betting.limits.observations) * 50
        or earlier_net < -earlier_stakes
        or earlier_net > earlier_stakes * 1.5
    then
        return false
    end
    for _, name in ipairs({ "win_streak", "loss_streak" }) do
        if
            (recent[name] < betting.limits.observations and actual[name] ~= recent[name])
            or actual[name] < recent[name]
        then
            return false
        end
    end
    return true
end

function validation.validate(state)
    if
        not check.object(state, { "version", "lifetime", "active", "recent", "wagers" })
        or state.version ~= 1
        or not summary.validate(state.lifetime)
        or state.lifetime.id ~= 0
        or not summary.validate(state.active)
        or state.active.id < 1
        or not check.array(state.recent, validation.history_limit)
        or not check.array(state.wagers, betting.limits.observations)
        or not contained_in_lifetime(state, state.active)
    then
        return false, "Invalid coach summary fields or counters"
    end
    local first_id = state.active.id - #state.recent
    for index, completed in ipairs(state.recent) do
        if
            not summary.validate(completed)
            or not summary.has_evidence(completed)
            or completed.id ~= first_id + index - 1
            or not contained_in_lifetime(state, completed)
        then
            return false, "Invalid completed session history"
        end
    end
    if
        (#state.recent == 0 and state.active.id ~= 1)
        or #state.recent ~= math.min(state.active.id - 1, validation.history_limit)
        or #state.wagers ~= math.min(state.active.results.rounds, betting.limits.observations)
        or not valid_recorded_totals(state)
        or not valid_wager_totals(state)
    then
        return false, "Coach session history does not agree"
    end
    return true
end

return validation
