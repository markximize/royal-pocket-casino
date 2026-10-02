-- PURPOSE: Validate and record local strategy/count answers without changing play.
-- CHANGE THIS MODULE WHEN: A documented training statistic changes.
-- DO NOT PUT HERE: Trainer questions, cards, wagers, rendering or file operations.

local check = require("src.check")
local chips = require("src.blackjack.chips")
local copy = require("src.plain_copy")
local statistics = {}

local strategy_names = { "attempts", "correct", "incorrect", "streak", "best_streak" }
local counting_names = {
    "attempts",
    "running_attempts",
    "running_correct",
    "true_attempts",
    "true_correct",
    "streak",
    "best_streak",
}

local function empty_counters(names)
    local counters = {}
    for _, name in ipairs(names) do
        counters[name] = 0
    end
    return counters
end

function statistics.new()
    return {
        strategy = empty_counters(strategy_names),
        counting = empty_counters(counting_names),
    }
end

local function bounded_counters(counters, names)
    if not check.object(counters, names) then
        return false
    end
    for _, name in ipairs(names) do
        if not check.integer(counters[name]) then
            return false
        end
    end
    return true
end

local function valid_streak(counters, correct)
    if counters.streak > counters.best_streak or counters.best_streak > correct then
        return false
    end
    -- A completely correct history cannot contain an unexplained broken streak.
    if correct == counters.attempts then
        return counters.streak == correct and counters.best_streak == correct
    end
    local incorrect = counters.attempts - correct
    local earlier_correct = correct - counters.streak
    if counters.best_streak > counters.streak and counters.best_streak > earlier_correct then
        return false
    end
    -- Each incorrect answer closes one earlier run. Division avoids multiplying
    -- two bounded counters into an inexactly large intermediate number.
    return math.ceil(earlier_correct / incorrect) <= counters.best_streak
end

function statistics.validate(training)
    if not check.object(training, { "strategy", "counting" }) then
        return false, "Invalid training statistics fields"
    end
    local strategy, counting = training.strategy, training.counting
    if
        not bounded_counters(strategy, strategy_names)
        or strategy.correct + strategy.incorrect ~= strategy.attempts
        or not valid_streak(strategy, strategy.correct)
    then
        return false, "Invalid strategy statistics relationships"
    end
    if
        not bounded_counters(counting, counting_names)
        or counting.running_attempts + counting.true_attempts ~= counting.attempts
        or counting.running_correct > counting.running_attempts
        or counting.true_correct > counting.true_attempts
        or not valid_streak(counting, counting.running_correct + counting.true_correct)
    then
        return false, "Invalid counting statistics relationships"
    end
    return true
end

-- ## SCORE ONE ANSWER

function statistics.record(training, kind, correct)
    local valid, reason = statistics.validate(training)
    if not valid then
        return nil, reason
    end
    if kind ~= "strategy" and kind ~= "running" and kind ~= "true_count" then
        return nil, "Unknown training answer kind"
    end
    if not check.boolean(correct) then
        return nil, "Training answer result must be true or false"
    end
    local next_training = copy(training)
    local counters = kind == "strategy" and next_training.strategy or next_training.counting
    if counters.attempts >= chips.maximum then
        return nil, "Training statistics limit reached; existing progress preserved"
    end
    counters.attempts = counters.attempts + 1
    if kind == "strategy" then
        local outcome = correct and "correct" or "incorrect"
        counters[outcome] = counters[outcome] + 1
    else
        local prefix = kind == "running" and "running" or "true"
        counters[prefix .. "_attempts"] = counters[prefix .. "_attempts"] + 1
        if correct then
            counters[prefix .. "_correct"] = counters[prefix .. "_correct"] + 1
        end
    end
    counters.streak = correct and counters.streak + 1 or 0
    counters.best_streak = math.max(counters.best_streak, counters.streak)
    return next_training
end

return statistics
