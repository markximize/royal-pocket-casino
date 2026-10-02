-- PURPOSE: Connect isolated practice answers to the existing durable progress session.
-- CHANGE THIS MODULE WHEN: Trainer navigation, count entry or retry adoption changes.
-- DO NOT PUT HERE: Blackjack strategy tables, counting tags or rendering formulas.

local practice = require("src.training.practice")
local session = require("src.app.session")
local copy = require("src.plain_copy")
local audio = require("src.platform.audio")
local training = {}

function training.start(app, mode, target)
    local snapshot = app.session.snapshot
    if app.session.pending or not snapshot then
        return
    end
    app.trainer = practice.new(
        mode,
        snapshot.game.rules,
        app.session.storage.new_seed(),
        snapshot.count_settings,
        target
    )
    app.ui.page, app.ui.focus = "training", 1
end

function training.check_table(app, counts)
    app.trainer = {
        mode = "normal_count",
        phase = "answer",
        answer_kind = "running",
        entry = 0,
        counts = copy(counts),
    }
    app.ui.page, app.ui.focus = "training", 2
end

local function submit(app, value)
    local current = app.trainer
    if current.phase == "feedback" or app.session.pending then
        return
    end
    local answer
    if current.mode == "normal_count" then
        local expected = current.answer_kind == "running" and current.counts.running
            or current.counts.true_count
        answer = {
            kind = current.answer_kind,
            correct = value == expected,
            expected = expected,
            explanation = "Only cards you have seen count. "
                .. "The dealer hole card waits for its reveal.",
        }
    else
        answer = practice.answer(current, value)
    end
    if not answer then
        return
    end
    local category = current.recommendation and current.recommendation.category
    if current.target == "double" then
        category = "double"
    end
    if session.training_answer(app.session, answer.kind, answer.correct, category) then
        practice.accept(current, answer)
        audio.play(app.tone, answer.correct and "win" or "loss", app.session.snapshot.settings)
        app.ui.focus = 1
    elseif app.session.pending then
        app.pending_training_answer = answer
        app.ui.focus = 1
    end
end

function training.activate(app, kind)
    local current = app.trainer
    if not current then
        return false
    end
    if app.session.pending and kind ~= "training_retry" then
        return kind:sub(1, 9) == "training_"
            or kind:sub(1, 7) == "answer_"
            or kind == "count_down"
            or kind == "count_up"
    end
    if kind == "count_down" or kind == "count_up" then
        if current.phase == "answer" and not app.session.pending then
            current.entry =
                math.max(-416, math.min(416, current.entry + (kind == "count_up" and 1 or -1)))
        end
    elseif kind == "training_submit" then
        submit(app, current.entry)
    elseif kind:sub(1, 7) == "answer_" then
        submit(app, kind:sub(8))
    elseif kind == "training_retry" then
        if session.retry(app.session) and app.pending_training_answer then
            practice.accept(current, app.pending_training_answer)
            app.pending_training_answer, app.ui.focus = nil, 1
        end
    elseif kind == "training_next" then
        if current.goal and current.drills_done >= current.goal then
            app.ui.page, app.ui.focus = "coach", 1
            app.ui.coach_page = 1
        elseif current.mode == "normal_count" then
            app.ui.page = "table"
            app.ui.focus = app.session.snapshot.game.phase == "betting" and 2 or 1
        else
            practice.next(current)
            app.ui.focus = 1
        end
    elseif kind == "training_cancel" then
        if current.mode == "normal_count" then
            app.ui.page = "table"
            app.ui.focus = app.session.snapshot.game.phase == "betting" and 2 or 1
        else
            current.phase, app.ui.focus = "cards", 1
            current.elapsed, current.since_check = 0, 0
        end
    elseif kind == "training_pause" then
        current.paused = not current.paused
    elseif kind == "training_shuffle" then
        practice.shuffle(current)
    elseif kind == "training_check_running" or kind == "training_check_true" then
        practice.check(current, kind == "training_check_running" and "running" or "true_count")
        app.ui.focus = 2
    else
        return false
    end
    return true
end

function training.intent(app, intent)
    local current = app.trainer
    if current.phase == "answer" and (intent == "inspect_previous" or intent == "inspect_next") then
        if not app.session.pending then
            current.entry = math.max(
                -416,
                math.min(416, current.entry + (intent == "inspect_next" and 5 or -5))
            )
        end
        return true
    end
    if intent == "count_down" or intent == "count_up" then
        training.activate(app, intent)
        return true
    end
    if
        current.mode == "strategy"
        and (intent == "hit" or intent == "stand" or intent == "double" or intent == "split")
    then
        training.activate(app, "answer_" .. intent)
        return true
    end
    return false
end

function training.update(app, elapsed)
    if app.ui.page == "training" and app.trainer and not app.session.pending then
        local previous_card = app.trainer.card
        practice.update(app.trainer, elapsed)
        if app.trainer.card and app.trainer.card ~= previous_card then
            audio.play(app.tone, "card", app.session.snapshot.settings)
        end
        if app.trainer.phase == "answer" and not app.trainer.entry_focus then
            app.ui.focus, app.trainer.entry_focus = 2, true
        end
        if app.trainer.phase ~= "answer" then
            app.trainer.entry_focus = nil
        end
    end
end

return training
