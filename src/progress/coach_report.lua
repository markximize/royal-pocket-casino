-- PURPOSE: Choose deterministic evidence-based practice priorities and feedback.
-- CHANGE THIS MODULE WHEN: Minimum samples or recommendation wording changes.
-- DO NOT PUT HERE: Random messages, outcomes-as-skill judgments or rendering.

local betting = require("src.progress.betting_analysis")
local copy = require("src.plain_copy")
local report = { strategy_minimum = 10, count_minimum = 5, drill_length = 20 }
local priorities =
    { "soft", "pair", "hard", "double", "deviation", "running", "true_count", "mixed" }
local names = {
    soft = "Soft totals",
    pair = "Pairs",
    hard = "Hard totals",
    double = "Doubles",
    deviation = "Deviations",
    running = "Running count",
    true_count = "True count",
    mixed = "Mixed strategy",
}

local function combined_score(value, category)
    local play, practice = value.play[category], value.practice[category]
    return {
        attempts = (play and play.attempts or 0) + (practice and practice.attempts or 0),
        correct = (play and play.correct or 0) + (practice and practice.correct or 0),
    }
end

local function select_priority(value)
    local selected
    for _, category in ipairs(priorities) do
        local score = combined_score(value, category)
        local minimum = (category == "running" or category == "true_count") and report.count_minimum
            or report.strategy_minimum
        if score.attempts >= minimum and score.correct < score.attempts then
            local rate = score.correct / score.attempts
            if not selected or rate < selected.rate then
                selected = {
                    category = category,
                    name = names[category],
                    attempts = score.attempts,
                    correct = score.correct,
                    rate = rate,
                    accuracy = math.floor(rate * 100 + 0.5),
                    drills = report.drill_length,
                    kind = (category == "running" or category == "true_count") and category
                        or "strategy",
                }
            end
        end
    end
    return selected
end

function report.accuracy(value, group)
    local attempts, correct = 0, 0
    local categories = group == "count" and { "running", "true_count" }
        or { "hard", "soft", "pair", "mixed" }
    for _, category in ipairs(categories) do
        local score = combined_score(value, category)
        attempts, correct = attempts + score.attempts, correct + score.correct
    end
    if group ~= "count" then
        -- Targeted double drills have an exclusive practice bucket. Normal-play
        -- doubles already belong to hard/soft/pair, so their subscore stays out.
        attempts = attempts + value.practice.double.attempts
        correct = correct + value.practice.double.correct
    end
    return {
        attempts = attempts,
        correct = correct,
        percent = attempts > 0 and math.floor(correct / attempts * 100 + 0.5) or nil,
    }
end

function report.build(state)
    local recommendation = select_priority(state.active)
    local source = "current session"
    if not recommendation then
        recommendation = select_priority(state.lifetime)
        source = "recorded lifetime"
    end
    if recommendation then
        recommendation.source = source
        recommendation.message = string.format(
            "%s: %d%% over %d answers. Practice %d drills.",
            recommendation.name,
            recommendation.accuracy,
            recommendation.attempts,
            recommendation.drills
        )
    end
    local history = {}
    for _, completed in ipairs(state.recent) do
        history[#history + 1] = {
            id = completed.id,
            strategy = report.accuracy(completed, "strategy"),
            counting = report.accuracy(completed, "count"),
            rounds = completed.results.rounds,
            net_units = completed.results.net_units,
        }
    end
    return {
        strategy = report.accuracy(state.active, "strategy"),
        counting = report.accuracy(state.active, "count"),
        decisions = copy(state.active.play),
        practice = copy(state.active.practice),
        results = copy(state.active.results),
        recommendation = recommendation,
        betting = assert(betting.analyze(state.wagers)),
        history = history,
        message = recommendation and "Results do not determine decision quality."
            or "Record 10 category answers or 5 count answers before selecting a weakness.",
    }
end

return report
