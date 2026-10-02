-- PURPOSE: Record offline evidence and retain 15 explicitly completed sessions.
-- CHANGE THIS MODULE WHEN: Coaching transactions or history bounds change.
-- DO NOT PUT HERE: Strategy advice, controller actions, clocks or save writes.

local check = require("src.check")
local copy = require("src.plain_copy")
local summary = require("src.progress.coach_summary")
local betting = require("src.progress.betting_analysis")
local validation = require("src.progress.coach_validation")
local coach = { history_limit = validation.history_limit }
local actions = { hit = true, stand = true, double = true, split = true }

function coach.new()
    return {
        version = 1,
        lifetime = summary.new(0),
        active = summary.new(1),
        recent = {},
        wagers = {},
    }
end

function coach.validate(state)
    return validation.validate(state)
end

local function next_state(state, change)
    local valid, reason = coach.validate(state)
    if not valid then
        return nil, reason
    end
    local next_coach = copy(state)
    change(next_coach)
    valid, reason = coach.validate(next_coach)
    if not valid then
        return nil, "Coach counter limit reached; existing evidence preserved: " .. reason
    end
    return next_coach
end

-- ## INDEPENDENT DECISION EVIDENCE

function coach.decision(state, decision)
    local category = type(decision) == "table" and decision.category
    local known_category = category == "hard" or category == "soft" or category == "pair"
    if
        not check.object(decision, { "category", "action", "expected" }, {
            "basic_expected",
            "deviation_expected",
            "correct",
        })
        or not known_category
        or not actions[decision.action]
        or not actions[decision.expected]
        or (decision.basic_expected ~= nil and not actions[decision.basic_expected])
        or (decision.deviation_expected ~= nil and not actions[decision.deviation_expected])
        or (decision.correct ~= nil and decision.correct ~= (decision.action == decision.expected))
    then
        return nil, "Invalid recorded strategy decision"
    end
    local recorded = copy(decision)
    recorded.basic_expected = recorded.basic_expected or recorded.expected
    return next_state(state, function(next_coach)
        summary.decision(next_coach.active, recorded)
        summary.decision(next_coach.lifetime, recorded)
    end)
end

function coach.training(state, kind, correct, category)
    local target = kind == "strategy" and (category or "mixed") or kind
    local allowed = false
    for _, name in ipairs(summary.practice_categories) do
        if name == target then
            allowed = true
        end
    end
    if
        not allowed
        or not check.boolean(correct)
        or (kind ~= "strategy" and category ~= nil)
        or (
            kind ~= "strategy"
            and kind ~= "running"
            and kind ~= "true_count"
            and kind ~= "deviation"
        )
    then
        return nil, "Invalid recorded practice answer"
    end
    return next_state(state, function(next_coach)
        summary.training(next_coach.active, kind, correct, category)
        summary.training(next_coach.lifetime, kind, correct, category)
    end)
end

-- ## SETTLED ROUND AND SESSION BOUNDARIES

function coach.round(state, observation)
    if not betting.valid_observation(observation) then
        return nil, "Invalid completed-round observation"
    end
    return next_state(state, function(next_coach)
        summary.round(next_coach.active, observation)
        summary.round(next_coach.lifetime, observation)
        next_coach.wagers[#next_coach.wagers + 1] = copy(observation)
        if #next_coach.wagers > betting.limits.observations then
            table.remove(next_coach.wagers, 1)
        end
    end)
end

function coach.close_session(state)
    return next_state(state, function(next_coach)
        if not summary.has_evidence(next_coach.active) then
            return
        end
        next_coach.recent[#next_coach.recent + 1] = copy(next_coach.active)
        if #next_coach.recent > coach.history_limit then
            table.remove(next_coach.recent, 1)
        end
        next_coach.active = summary.new(next_coach.active.id + 1)
        next_coach.wagers = {}
    end)
end

function coach.report(state)
    local valid, reason = coach.validate(state)
    if not valid then
        return nil, reason
    end
    return require("src.progress.coach_report").build(state)
end

return coach
