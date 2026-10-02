-- PURPOSE: Own bounded decision, practice and result summaries for the coach.
-- CHANGE THIS MODULE WHEN: Recorded coaching evidence or its invariants change.
-- DO NOT PUT HERE: Advice tables, betting labels, persistence or presentation.

local check = require("src.check")
local chips = require("src.blackjack.chips")
local summary = {}

summary.play_categories = { "hard", "soft", "pair", "double", "deviation" }
summary.practice_categories = {
    "hard",
    "soft",
    "pair",
    "double",
    "deviation",
    "running",
    "true_count",
    "mixed",
}
local result_names = {
    "rounds",
    "wins",
    "losses",
    "pushes",
    "blackjacks",
    "net_units",
    "staked_units",
    "biggest_win_units",
    "biggest_loss_units",
    "peak_net_units",
    "drawdown_units",
    "max_drawdown_units",
    "win_streak",
    "loss_streak",
    "best_win_streak",
    "best_loss_streak",
}

local function empty_scores(categories)
    local scores = {}
    for _, category in ipairs(categories) do
        scores[category] = { attempts = 0, correct = 0 }
    end
    return scores
end

function summary.new(id)
    local results = {}
    for _, name in ipairs(result_names) do
        results[name] = 0
    end
    return {
        id = id,
        play = empty_scores(summary.play_categories),
        practice = empty_scores(summary.practice_categories),
        results = results,
    }
end

local function valid_scores(scores, categories)
    if not check.object(scores, categories) then
        return false
    end
    for _, category in ipairs(categories) do
        local score = scores[category]
        if
            not check.object(score, { "attempts", "correct" })
            or not check.integer(score.attempts)
            or not check.integer(score.correct, 0, score.attempts)
        then
            return false
        end
    end
    return true
end

function summary.validate(value)
    if
        not check.object(value, { "id", "play", "practice", "results" })
        or not check.integer(value.id)
        or not valid_scores(value.play, summary.play_categories)
        or not valid_scores(value.practice, summary.practice_categories)
        or not check.object(value.results, result_names)
    then
        return false
    end
    local results = value.results
    local ordinary_attempts = value.play.hard.attempts
        + value.play.soft.attempts
        + value.play.pair.attempts
    local ordinary_correct = value.play.hard.correct
        + value.play.soft.correct
        + value.play.pair.correct
    if
        value.play.double.attempts > ordinary_attempts
        or value.play.double.correct > ordinary_correct
        or value.play.double.attempts - value.play.double.correct
            > ordinary_attempts - ordinary_correct
    then
        return false
    end
    for _, name in ipairs(result_names) do
        local minimum = name == "net_units" and -chips.maximum or 0
        if not check.integer(results[name], minimum) then
            return false
        end
        if results.rounds == 0 and results[name] ~= 0 then
            return false
        end
    end
    if
        results.wins + results.losses + results.pushes ~= results.rounds
        or results.blackjacks > results.wins + results.pushes
        or results.staked_units < results.rounds * 50
        or results.net_units < -results.staked_units
        or results.net_units > results.staked_units * 1.5
        or results.biggest_win_units > results.staked_units * 1.5
        or results.biggest_loss_units > results.staked_units
        or (results.wins == 0 and results.biggest_win_units ~= 0)
        or (results.wins > 0 and results.biggest_win_units == 0)
        or (results.losses == 0 and results.biggest_loss_units ~= 0)
        or (results.losses > 0 and results.biggest_loss_units == 0)
        or results.win_streak > results.best_win_streak
        or results.best_win_streak > results.wins
        or results.loss_streak > results.best_loss_streak
        or results.best_loss_streak > results.losses
        or (results.win_streak > 0 and results.loss_streak > 0)
        or results.peak_net_units < math.max(0, results.net_units)
        or results.drawdown_units ~= results.peak_net_units - results.net_units
        or results.max_drawdown_units < results.drawdown_units
        or results.max_drawdown_units > results.staked_units
    then
        return false
    end
    return true
end

-- These mutators operate only on the private copy created by session_coach.
local function score_answer(scores, category, correct)
    local score = scores[category]
    score.attempts = score.attempts + 1
    if correct then
        score.correct = score.correct + 1
    end
end

function summary.decision(value, decision)
    if decision.deviation_expected and decision.deviation_expected ~= decision.basic_expected then
        -- Following a supported deviation must not be marked as a basic-strategy
        -- mistake. Its separate score describes the actual count-aware choice.
        score_answer(value.play, "deviation", decision.action == decision.deviation_expected)
        return
    end
    score_answer(value.play, decision.category, decision.action == decision.basic_expected)
    if decision.basic_expected == "double" or decision.action == "double" then
        score_answer(value.play, "double", decision.action == decision.basic_expected)
    end
end

function summary.training(value, kind, correct, category)
    local target = kind == "strategy" and (category or "mixed") or kind
    score_answer(value.practice, target, correct)
end

function summary.round(value, observation)
    local results = value.results
    results.rounds = results.rounds + 1
    local outcome_name = observation.outcome == "win" and "wins"
        or observation.outcome == "loss" and "losses"
        or "pushes"
    results[outcome_name] = results[outcome_name] + 1
    results.blackjacks = results.blackjacks + (observation.blackjacks or 0)
    results.staked_units = results.staked_units + observation.staked_units
    results.net_units = results.net_units + observation.net_units
    results.biggest_win_units = math.max(results.biggest_win_units, observation.net_units)
    results.biggest_loss_units = math.max(results.biggest_loss_units, -observation.net_units)
    results.peak_net_units = math.max(results.peak_net_units, results.net_units)
    results.drawdown_units = results.peak_net_units - results.net_units
    results.max_drawdown_units = math.max(results.max_drawdown_units, results.drawdown_units)
    results.win_streak = observation.outcome == "win" and results.win_streak + 1 or 0
    results.loss_streak = observation.outcome == "loss" and results.loss_streak + 1 or 0
    results.best_win_streak = math.max(results.best_win_streak, results.win_streak)
    results.best_loss_streak = math.max(results.best_loss_streak, results.loss_streak)
end

function summary.has_evidence(value)
    if value.results.rounds > 0 then
        return true
    end
    for _, group in ipairs({ value.play, value.practice }) do
        for _, score in pairs(group) do
            if score.attempts > 0 then
                return true
            end
        end
    end
    return false
end

return summary
