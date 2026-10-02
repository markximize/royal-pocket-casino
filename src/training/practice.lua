-- PURPOSE: Run isolated strategy rounds or exposed-card Hi-Lo drills.
-- CHANGE THIS MODULE WHEN: Question progression, checkpoints or practice pacing change.
-- DO NOT PUT HERE: Normal bankroll, saved statistics, rendering or platform randomness.

local copy = require("src.plain_copy")
local round = require("src.blackjack.round")
local shoe = require("src.blackjack.shoe")
local seeded = require("src.random.seeded")
local cards = require("src.blackjack.cards")
local player_view = require("src.app.player_view")
local strategy = require("src.training.basic_strategy")
local deviations = require("src.training.deviations")
local hi_lo = require("src.training.hi_lo")
local practice = {}
local maximum_search_steps = 2000
local targeted_goal = 20

local function given_counts(true_count)
    -- These are labeled exercise inputs, never claims about this generated shoe.
    -- Six decks minus 104 public cards gives exactly four estimated decks.
    return { running = true_count * 4, true_count = true_count, decks = 4, exposed = 104 }
end

local function deviation_question(current, basic_advice)
    -- Probe above this compact profile's indices to identify a covered hand.
    -- The authoritative lookup supplies its index; practice has no index table.
    local probe_true_count = 10
    local adjusted =
        deviations.recommend(current.game, given_counts(probe_true_count), basic_advice)
    if not adjusted then
        return nil
    end
    local at_index = current.drills_done % 2 == 0
    local question_count = at_index and adjusted.index or adjusted.index - 1
    current.practice_counts = given_counts(question_count)
    local recommendation = copy(basic_advice)
    recommendation.category = "deviation"
    recommendation.basic_action = basic_advice.action
    recommendation.deviation_index = adjusted.index
    recommendation.profile = adjusted.profile
    if at_index then
        recommendation.action = adjusted.action
        recommendation.explanation = "Given TC +"
            .. question_count
            .. " reaches index +"
            .. adjusted.index
            .. "; this profile chooses Stand. Basic strategy is Hit."
    else
        recommendation.explanation = "Given TC +"
            .. question_count
            .. " is below index +"
            .. adjusted.index
            .. "; retain basic Hit."
    end
    return recommendation
end

local function selected_question(current, recommendation)
    current.practice_counts = nil
    if current.target == "deviation" then
        return deviation_question(current, recommendation)
    elseif current.target == "mixed" then
        return recommendation
    elseif current.target == "double" and recommendation.action == "double" then
        return recommendation
    elseif current.target == recommendation.category then
        return recommendation
    end
    return nil
end

local function apply(current, action)
    local next_game, reason = round.apply(
        current.game,
        round.command(current.game, action, action == "deal" and { bet_units = 100 } or nil),
        seeded.next_integer
    )
    if not next_game then
        current.error = tostring(reason)
        return false
    end
    current.game = next_game
    return true
end

local function find_decision(current)
    for _ = 1, maximum_search_steps do
        if current.game.phase == "player_turn" then
            local recommendation, reason = strategy.recommend(current.game)
            if not recommendation then
                current.recommendation, current.error = nil, reason
                return
            end
            current.recommendation = selected_question(current, recommendation)
            if current.recommendation then
                current.phase = "question"
                return
            end
            -- Skipped questions still use real legal actions in the shared engine.
            if not apply(current, recommendation.action) then
                return
            end
        elseif current.game.phase == "round_result" then
            if not apply(current, "next_round") then
                return
            end
        elseif current.game.bankroll_units < 100 then
            -- Practice funding belongs only to this ephemeral round engine.
            current.game.bankroll_units = 10000
        else
            if not apply(current, "deal") then
                return
            end
        end
    end
    current.recommendation = nil
    current.error = "No practice decision could be generated. Start a new session."
end

local function fresh_shoe(current)
    local generation = current.shoe and current.shoe.generation + 1 or 1
    current.shoe = shoe.new(current.rules, current.generator, seeded.next_integer, generation)
    current.observer = hi_lo.new(generation)
    current.card, current.shoe_complete = nil, false
    current.elapsed, current.since_check, current.phase = 0, 0, "cards"
    current.check_due = nil
    current.paused = false
end

function practice.new(mode, preset, seed, settings, target)
    local current = {
        mode = mode,
        rules = copy(preset),
        settings = copy(settings),
        phase = "question",
        target = target or "mixed",
        drills_done = 0,
    }
    if current.target ~= "mixed" then
        current.goal = targeted_goal
    end
    if mode == "strategy" then
        current.game = round.new(preset, seeded.new(seed), seeded.next_integer)
        local supported_targets =
            { mixed = true, hard = true, soft = true, pair = true, double = true, deviation = true }
        if not supported_targets[current.target] then
            current.error = "This strategy practice category is unavailable."
            return current
        end
        if current.target == "deviation" then
            local supported, reason = deviations.supported(preset)
            if not supported then
                current.error = reason
                return current
            end
        end
        find_decision(current)
    else
        if current.target == "running" or current.target == "true_count" then
            current.settings.level, current.settings.assistance = "advanced", false
        elseif current.target ~= "mixed" then
            current.error = "This counting practice category is unavailable."
            return current
        end
        current.generator = seeded.new(seed)
        fresh_shoe(current)
    end
    return current
end

function practice.table_view(current)
    return player_view.build({
        snapshot = { game = current.game, statistics = {}, settings = {}, revision = 0 },
    })
end

function practice.counts(current)
    local observer = current.observer
    local decks = assert(
        hi_lo.estimate_decks(
            current.rules.deck_count,
            observer.exposed_count,
            current.settings.deck_step
        )
    )
    return {
        running = observer.running_count,
        exposed = observer.exposed_count,
        decks = decks,
        true_count = assert(
            hi_lo.true_count(observer.running_count, decks, current.settings.rounding)
        ),
    }
end

function practice.check(current, kind)
    if current.phase == "feedback" or current.phase == "answer" then
        return false
    end
    if
        (current.target == "running" or current.target == "true_count")
        and kind ~= current.target
    then
        return false
    end
    current.was_paused = current.paused
    current.check_due = nil
    current.phase, current.answer_kind, current.entry = "answer", kind, 0
    return true
end

function practice.answer(current, value)
    if current.mode == "strategy" then
        if current.phase ~= "question" or not current.recommendation then
            return nil
        end
        local visible = practice.table_view(current)
        if not visible.legal[value] then
            return nil
        end
        return {
            kind = "strategy",
            correct = value == current.recommendation.action,
            explanation = current.recommendation.explanation,
            action = value,
            expected = current.recommendation.action,
            category = current.recommendation.category,
            dealer_value = cards.value(current.game.round.dealer.cards[1]),
            double_opportunity = current.recommendation.action == "double",
            basic_action = current.recommendation.basic_action,
            deviation_index = current.recommendation.deviation_index,
        }
    end
    if current.phase ~= "answer" then
        return nil
    end
    local counts = practice.counts(current)
    local expected = current.answer_kind == "running" and counts.running or counts.true_count
    return {
        kind = current.answer_kind == "running" and "running" or "true_count",
        correct = value == expected,
        expected = expected,
        explanation = current.answer_kind == "running"
                and "Add only exposed card tags. Each physical card counts once."
            or "Running count ÷ estimated decks, truncated toward zero.",
    }
end

function practice.accept(current, answer)
    if current.phase == "feedback" then
        return
    end
    current.drills_done = (current.drills_done or 0) + 1
    current.feedback, current.phase = answer, "feedback"
end

function practice.next(current)
    if current.phase ~= "feedback" then
        return
    end
    if current.mode == "strategy" then
        if apply(current, current.feedback.action) then
            find_decision(current)
        end
    else
        current.phase, current.since_check, current.elapsed = "cards", 0, 0
        current.paused = current.was_paused or current.shoe_complete
    end
    current.feedback = nil
end

function practice.update(current, elapsed)
    if current.mode ~= "counting" or current.phase ~= "cards" or current.paused then
        return
    end
    local intervals = { slow = 2.5, comfortable = 1.5, fast = 0.7 }
    current.elapsed = current.elapsed + elapsed
    if current.elapsed < intervals[current.settings.pace] then
        return
    end
    -- Reveal at most one card per frame, even after a long OS stall.
    current.elapsed = 0
    if current.check_due then
        local kind = current.check_due
        practice.check(current, kind)
        return
    end
    current.card = shoe.draw(current.shoe)
    if not current.card then
        current.shoe_complete, current.paused = true, true
        return
    end
    current.observer =
        assert(hi_lo.observe(current.observer, current.shoe.generation, { current.card }))
    current.since_check = current.since_check + 1
    if current.shoe.shuffle_pending then
        current.shoe_complete, current.paused = true, true
    end
    if current.settings.level ~= "beginner" and current.since_check >= 10 then
        current.checkpoint = (current.checkpoint or 0) + 1
        -- Keep the checkpoint card on screen for a complete selected interval.
        -- Opening an answer screen in this update would hide an unseen card.
        if current.target == "running" or current.target == "true_count" then
            current.check_due = current.target
        else
            current.check_due = current.settings.level == "advanced"
                    and current.checkpoint % 2 == 0
                    and "true_count"
                or "running"
        end
    end
end

function practice.shuffle(current)
    if current.mode == "counting" then
        fresh_shoe(current)
    end
end

return practice
