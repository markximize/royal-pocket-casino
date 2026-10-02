-- PURPOSE: Run opt-in desktop screenshot/timing checks on an isolated profile.
-- CHANGE THIS MODULE WHEN: The reviewed visual check sequence changes.
-- DO NOT PUT HERE: Normal navigation, scenario fixtures or device support claims.

local copy = require("src.plain_copy")
local native = require("src.platform.native_storage")
local smoke = {}

function smoke.new(snapshot)
    return {
        elapsed = 0,
        stage = 1,
        count = 0,
        maximum = 0,
        frames = {},
        initial_revision = snapshot and snapshot.revision or 0,
        initial_rounds = snapshot and snapshot.statistics.completed_rounds or 0,
    }
end

local sequence = {
    { time = 0.2, capture = "desktop-welcome.png" },
    { time = 0.5, action = "play" },
    { time = 0.7, action = "prepare" },
    { time = 1.0, capture = "desktop-betting.png" },
    { time = 1.3, action = "deal" },
    { time = 1.75, capture = "desktop-animation.png" },
    { time = 3.0, capture = "desktop-preview.png" },
    { time = 3.5, action = "stand" },
    { time = 6.0, capture = "desktop-result.png" },
    { time = 6.3, action = "menu" },
    { time = 6.6, capture = "desktop-menu.png" },
    { time = 6.8, action = "statistics_page" },
    { time = 7.1, capture = "desktop-statistics.png" },
    { time = 7.3, action = "rules_page" },
    { time = 7.6, capture = "desktop-rules.png" },
    { time = 7.8, action = "help" },
    { time = 8.1, capture = "desktop-help.png" },
    { time = 8.5, action = "strategy_start" },
    { time = 8.8, capture = "desktop-strategy.png" },
    { time = 9.1, action = "strategy_correct" },
    { time = 9.4, capture = "desktop-strategy-feedback.png" },
    { time = 9.7, action = "training_next" },
    { time = 10.0, action = "counting_start" },
    { time = 12.0, capture = "desktop-counting.png" },
    { time = 12.3, action = "training_check_running" },
    { time = 12.6, capture = "desktop-count-entry.png" },
    { time = 12.9, action = "count_correct" },
    { time = 13.2, capture = "desktop-count-feedback.png" },
    { time = 13.5, action = "training_next" },
    { time = 13.8, action = "training_check_true" },
    { time = 14.1, capture = "desktop-true-entry.png" },
    { time = 14.4, action = "count_correct" },
    { time = 14.7, capture = "desktop-true-feedback.png" },
    { time = 15.0, action = "home" },
    { time = 15.3, action = "statistics_page" },
    { time = 15.6, action = "training_statistics_page" },
    { time = 15.9, capture = "desktop-training-statistics.png" },
    { time = 16.2, action = "menu" },
    { time = 16.5, action = "count_settings_page" },
    { time = 16.8, capture = "desktop-count-settings.png" },
    { time = 17.1, action = "assistance_page" },
    { time = 17.4, capture = "polish-assistance.png" },
    { time = 17.7, action = "assist_mode" },
    { time = 18.0, action = "assist_mode" },
    { time = 18.3, action = "play" },
    { time = 18.6, action = "prepare" },
    { time = 18.9, action = "deal" },
    { time = 20.7, capture = "polish-assisted-table.png" },
    { time = 21.0, action = "advice_page" },
    { time = 21.3, capture = "polish-advice.png" },
    { time = 21.6, action = "learn_hilo" },
    { time = 21.9, capture = "polish-tutorial-tags.png" },
    { time = 22.2, action = "tutorial_next" },
    { time = 22.5, capture = "polish-tutorial-exercise.png" },
    { time = 22.8, action = "tutorial_submit" },
    { time = 23.1, capture = "polish-tutorial-feedback.png" },
    { time = 23.4, action = "coach_page" },
    { time = 23.7, capture = "polish-coach-quality.png" },
    { time = 24.0, action = "coach_next" },
    { time = 24.3, capture = "polish-coach-betting.png" },
    { time = 24.6, action = "coach_next" },
    { time = 24.9, capture = "polish-coach-results.png" },
    { time = 25.2, action = "coach_next" },
    { time = 25.5, capture = "polish-coach-history.png" },
    { time = 25.8, action = "about_page" },
    { time = 26.1, capture = "polish-about.png" },
    { time = 26.4, action = "notice_next" },
    { time = 26.7, capture = "polish-notices.png" },
    { time = 28.0, action = "learn_hilo" },
}

-- Inspect every lesson with the actual Windows fonts, including feedback.
-- This sequence runs only with --smoke-test and uses its separate save identity.
for page = 1, 15 do
    local time = 28.3 + (page - 1) * 0.9
    local prefix = string.format("lesson-%02d", page)
    sequence[#sequence + 1] = { time = time, capture = prefix .. ".png" }
    sequence[#sequence + 1] = { time = time + 0.2, action = "tutorial_review_answer" }
    sequence[#sequence + 1] = { time = time + 0.4, capture = prefix .. "-feedback.png" }
    sequence[#sequence + 1] = { time = time + 0.6, action = "tutorial_next" }
end
sequence[#sequence + 1] = { time = 42.0, capture = "lesson-complete.png" }
sequence[#sequence + 1] = { time = 42.3, action = "tutorial_practice" }
sequence[#sequence + 1] = { time = 45.0, capture = "lesson-beginner-practice.png" }
sequence[#sequence + 1] = { time = 46.0, action = "exit" }

function smoke.update(app, elapsed, activate)
    local state = app.smoke
    state.elapsed = state.elapsed + elapsed
    if state.elapsed > 2 then
        state.count = state.count + 1
        state.maximum = math.max(state.maximum, elapsed * 1000)
        state.frames[(state.count - 1) % 600 + 1] = elapsed * 1000
    end
    local step = sequence[state.stage]
    if not step or state.elapsed < step.time then
        return
    end
    state.stage = state.stage + 1
    if step.capture then
        state.capture = step.capture
    elseif step.action == "prepare" then
        if app.session.snapshot and app.session.snapshot.game.phase == "round_result" then
            activate(app, "next_round")
        end
    elseif step.action == "strategy_correct" then
        assert(app.trainer.recommendation, app.trainer.error)
        activate(app, "answer_" .. app.trainer.recommendation.action)
    elseif step.action == "count_correct" then
        local counts = require("src.training.practice").counts(app.trainer)
        app.trainer.entry = app.trainer.answer_kind == "running" and counts.running
            or counts.true_count
        activate(app, "training_submit")
    elseif step.action == "tutorial_review_answer" then
        if require("src.training.tutorial").current(app.lesson).exercise then
            activate(app, "tutorial_submit")
        end
    elseif
        step.action ~= "stand"
        or (app.session.snapshot and app.session.snapshot.game.phase == "player_turn")
    then
        activate(app, step.action)
    end
end

function smoke.draw(state)
    if state.capture then
        native.capture(state.capture)
        state.capture = nil
    end
end

function smoke.report(app)
    if not app.session.snapshot then
        return
    end
    local snapshot, state = app.session.snapshot, app.smoke
    local frames = copy(state.frames)
    table.sort(frames)
    local format = "App: %s\nPhase: %s\nBankroll units: %d\nInitial revision: %d\nRevision: %d\n"
        .. "Initial completed rounds: %d\nCompleted rounds: %d\nFPS: %d\nLoop p99 ms: %.3f\n"
        .. "Strategy attempts: %d\nRunning attempts: %d\nTrue-count attempts: %d\n"
        .. "Maximum loop interval ms: %.3f\nLua heap KiB: %.1f\n"
        .. "Save directory: %s\nHardware: UNVERIFIED\n"
    native.write_report(
        string.format(
            format,
            snapshot.app_version,
            snapshot.game.phase,
            snapshot.game.bankroll_units,
            state.initial_revision,
            snapshot.revision,
            state.initial_rounds,
            snapshot.statistics.completed_rounds,
            love.timer.getFPS(),
            frames[math.ceil(#frames * 0.99)] or 0,
            snapshot.training.strategy.attempts,
            snapshot.training.counting.running_attempts,
            snapshot.training.counting.true_attempts,
            state.maximum,
            collectgarbage("count"),
            love.filesystem.getSaveDirectory()
        )
    )
end

return smoke
