-- PURPOSE: Regress hardware focus, assistance, coaching and saved-player upgrades.
-- CHANGE THIS MODULE WHEN: A release integration contract or hardware bug changes.
-- DO NOT PUT HERE: Native durability claims or expected answers computed by advisers.

local test = require("tests.harness")
local persistence = require("tests.persistence")
local fixtures = require("tests.fixtures")
local session = require("src.app.session")
local desktop = require("src.app.desktop")
local education = require("src.app.education")
local training = require("src.app.training")
local animation = require("src.ui.presentation")
local input = require("src.platform.love_input")
local coach = require("src.progress.session_coach")
local schema = require("src.persistence.save_schema")
local copy = require("src.plain_copy")
local native = require("src.platform.native_storage")
local components = require("src.ui.components")
local audio = require("src.platform.audio")
local count_view = require("src.app.count_view")
local polish = {}

local function app_fixture(hash, ranks)
    local current, storage = persistence.fixture(hash, ranks)
    return {
        session = current,
        ui = {
            page = "table",
            focus = 2,
            bet_units = 250,
            inspect_hand = 1,
            table_seen = true,
            page_origins = {},
        },
    },
        storage
end

local function finish_animation(app)
    if app.presentation then
        animation.finish(app.presentation)
    end
end

local function set_assistance(current, mode)
    local preferences = copy(current.snapshot.assistance)
    preferences.mode = mode
    assert(session.assistance_settings(current, preferences), current.message)
end

local function enabled_button(app, kind)
    for _, button in ipairs(desktop.buttons(app)) do
        if button.kind == kind then
            return button.enabled
        end
    end
    return false
end

local function completed_win(hash)
    -- Player K+Q stands on 20 against dealer 10+7, winning the original wager.
    local app, storage = app_fixture(hash, { "K", "10", "Q", "7" })
    desktop.activate(app, "deal")
    finish_animation(app)
    desktop.activate(app, "stand")
    finish_animation(app)
    test.equal(app.session.snapshot.game.phase, "round_result")
    test.equal(app.session.snapshot.game.round.result.net_units, 250)
    return app, storage
end

local function version_two_fixture(hash)
    local current, storage = persistence.fixture(hash, { "5", "10", "6", "9", "9" })
    assert(session.training_answer(current, "strategy", true, "soft"))
    assert(session.training_answer(current, "running", false))
    assert(session.training_answer(current, "true_count", true))
    local preferences = copy(current.snapshot.count_settings)
    preferences.show_running, preferences.show_decks = true, true
    preferences.level, preferences.pace, preferences.assistance = "advanced", "fast", false
    assert(session.count_settings(current, preferences))
    assert(session.settings(current, { sound_enabled = false, volume = 3, reduced_motion = true }))
    assert(session.command(current, "deal", { bet_units = 250 }))
    local original = copy(current.snapshot)
    original.format_version = 2
    original.app_version = "0.1.0-preview.3"
    original.assistance, original.coach = nil, nil
    storage.files["save_a.json"], storage.files["save_b.json"] = nil, nil
    local bytes = assert(schema.encode(original, hash))
    storage.files["save_a.json"] = bytes
    return session.open(storage), storage, original, bytes
end

local function same_old_progress(actual, original)
    for _, name in ipairs({ "game", "statistics", "training", "count_settings", "settings" }) do
        test.same(actual[name], original[name])
    end
    local identity_fields = { "profile_id", "lineage_id", "created_at", "starting_bankroll_units" }
    for _, name in ipairs(identity_fields) do
        test.equal(actual[name], original[name])
    end
end

local function with_startup_adapters(storage, scenario)
    local real_new, real_fonts, real_audio = native.new, components.fonts, audio.new
    local real_framework = rawget(_G, "love")
    local framework = {}
    for name, value in pairs(real_framework or {}) do
        framework[name] = value
    end
    -- Keep the real SHA adapter; replace only constructor-only display APIs.
    framework.filesystem = {
        getSaveDirectory = function()
            return "in-memory test save"
        end,
    }
    framework.graphics = {
        getDimensions = function()
            return 640, 480
        end,
    }
    framework.system = {
        getOS = function()
            return "test platform"
        end,
    }
    framework.joystick = {
        getJoysticks = function()
            return {}
        end,
    }
    framework.getVersion = function()
        return 11, 5, 0, "test"
    end
    native.new = function()
        return storage
    end
    components.fonts = function()
        return {}
    end
    audio.new = function()
        return nil
    end
    rawset(_G, "love", framework)
    local passed, reason = pcall(scenario)
    rawset(_G, "love", real_framework)
    native.new, components.fonts, audio.new = real_new, real_fonts, real_audio
    assert(passed, reason)
end

local function with_given_count(scenario)
    local real_count = count_view.build
    -- Policy integration fixture, not an exposure-engine test: the public-count
    -- adapter supplies RC +16 / four estimated decks = integer TC +4.
    count_view.build = function()
        return { running = 16, true_count = 4, decks = 4, exposed = 104 }
    end
    local passed, reason = pcall(scenario)
    count_view.build = real_count
    assert(passed, reason)
end

function polish.run(hash)
    if not hash then
        return
    end

    -- ## PRIMARY NEXT-ROUND ACTION

    test.test("betting-state restart retains the last completed 25-chip wager", function()
        local app, storage = completed_win(hash)
        desktop.activate(app, "next_round")
        with_startup_adapters(storage, function()
            local restarted = desktop.new(false)
            test.equal(restarted.ui.bet_units, 250)
            desktop.activate(restarted, "play")
            test.equal(restarted.ui.focus, 2)
            test.equal(desktop.buttons(restarted)[2].kind, "deal")
        end)
    end)

    test.test(
        "an assistance save failure exposes a focused Retry without applying preferences",
        function()
            local app, storage = app_fixture(hash, { "K", "10", "Q", "7" })
            education.activate(app, "assistance_page")
            local before = copy(app.session.snapshot)
            local write = storage.write
            storage.write = function()
                return false, "disk full"
            end
            app.ui.focus = 4
            education.activate(app, "assist_deviations")
            test.equal(app.ui.focus, 1)
            test.equal(desktop.buttons(app)[1].kind, "retry")
            test.same(app.session.snapshot, before)
            storage.write = write
            desktop.intent(app, "confirm")
            test.equal(app.session.pending, nil)
            test.equal(app.session.snapshot.assistance.deviations, false)
            test.equal(app.session.snapshot.revision, before.revision + 1)
            test.same(app.session.snapshot.game, before.game)
        end
    )

    test.test("restarting an active 25-chip hand keeps that wager for the next round", function()
        local current, storage = persistence.fixture(hash, { "K", "10", "Q", "7" })
        assert(session.command(current, "deal", { bet_units = 250 }))
        with_startup_adapters(storage, function()
            local app = desktop.new(false)
            test.equal(app.ui.bet_units, 250)
            desktop.activate(app, "play")
            desktop.activate(app, "stand")
            finish_animation(app)
            desktop.activate(app, "next_round")
            test.equal(app.ui.bet_units, 250)
            test.equal(app.ui.focus, 2)
            test.equal(desktop.buttons(app)[2].kind, "deal")
        end)
    end)
    test.test("startup still caps the default wager to a funded five chips", function()
        local current, storage = persistence.fixture(hash, { "10", "10", "6", "9", "10" })
        for loss = 1, 10 do
            if current.snapshot.game.phase == "round_result" then
                assert(session.command(current, "next_round"))
            end
            assert(session.command(current, "shuffle"))
            current.snapshot.game.shoe.order =
                fixtures.full_order({ "10", "10", "6", "9", "10" }, 6)
            local stake = loss == 10 and 950 or 1000
            assert(session.command(current, "deal", { bet_units = stake }))
            assert(session.command(current, "hit"))
            test.equal(current.snapshot.game.round.result.net_units, -stake)
        end
        assert(session.command(current, "next_round"))
        test.equal(current.snapshot.game.bankroll_units, 50)
        with_startup_adapters(storage, function()
            local app = desktop.new(false)
            test.equal(app.ui.bet_units, 50)
            desktop.activate(app, "play")
            test.equal(app.ui.focus, 2)
            test.equal(desktop.buttons(app)[2].kind, "deal")
            test.equal(desktop.buttons(app)[2].enabled, true)
        end)
    end)

    test.test("settlement returns focus to Deal and preserves the previous wager", function()
        local app = completed_win(hash)
        desktop.activate(app, "next_round")
        test.equal(app.session.snapshot.game.phase, "betting")
        test.equal(app.ui.bet_units, 250)
        test.equal(app.ui.focus, 2)
        test.equal(desktop.buttons(app)[app.ui.focus].kind, "deal")
        test.equal(app.session.snapshot.game.bankroll_units, 10250)
    end)
    for _, control in ipairs({
        { "keyboard Enter", input.key("return") },
        { "controller A", input.gamepad("a") },
    }) do
        test.test(
            control[1] .. " deals the preserved wager instead of selecting minus five",
            function()
                local app = completed_win(hash)
                desktop.activate(app, "next_round")
                desktop.intent(app, control[2])
                test.equal(app.ui.bet_units, 250)
                test.equal(app.session.snapshot.game.round.initial_bet_units, 250)
                test.equal(app.session.snapshot.game.bankroll_units, 10000)
            end
        )
    end
    test.test(
        "D-pad still reaches minus five and changes a wager only after confirmation",
        function()
            local app = completed_win(hash)
            desktop.activate(app, "next_round")
            desktop.intent(app, input.gamepad("dpleft"))
            test.equal(app.ui.focus, 1)
            test.equal(app.ui.bet_units, 250)
            desktop.intent(app, input.gamepad("a"))
            test.equal(app.ui.bet_units, 200)
            test.equal(app.session.snapshot.game.phase, "betting")
        end
    )
    test.test(
        "failed next-round save focuses Retry then returns to Deal without changing the wager",
        function()
            local app, storage = completed_win(hash)
            local write = storage.write
            storage.write = function()
                return false, "disk full"
            end
            desktop.activate(app, "next_round")
            assert(app.session.pending)
            test.equal(app.session.snapshot.game.phase, "round_result")
            test.equal(app.ui.focus, 1)
            test.equal(desktop.buttons(app)[app.ui.focus].kind, "retry")
            test.equal(app.ui.bet_units, 250)
            storage.write = write
            desktop.intent(app, input.gamepad("a"))
            assert(not app.session.pending)
            test.equal(app.session.snapshot.game.phase, "betting")
            test.equal(app.ui.focus, 2)
            test.equal(desktop.buttons(app)[app.ui.focus].kind, "deal")
            test.equal(app.ui.bet_units, 250)
            test.equal(app.session.snapshot.game.bankroll_units, 10250)
        end
    )
    for _, control in ipairs({
        { "controller A", input.gamepad("a") },
        { "keyboard Enter", input.key("return") },
    }) do
        test.test(
            "failed Deal focuses Retry so " .. control[1] .. " saves exactly one candidate",
            function()
                local app, storage = app_fixture(hash, { "5", "10", "6", "7" })
                local before_revision, write = app.session.snapshot.revision, storage.write
                local fail_write, write_calls = true, 0
                storage.write = function(name, contents)
                    write_calls = write_calls + 1
                    if fail_write then
                        return false, "disk full"
                    end
                    return write(name, contents)
                end
                desktop.intent(app, control[2])
                assert(app.session.pending)
                test.equal(app.ui.focus, 1)
                test.equal(desktop.buttons(app)[1].kind, "retry")
                test.equal(app.ui.bet_units, 250)
                test.equal(app.session.snapshot.game.bankroll_units, 10000)
                fail_write = false
                desktop.intent(app, control[2])
                assert(not app.session.pending)
                test.equal(app.session.snapshot.revision, before_revision + 1)
                test.equal(app.session.snapshot.game.phase, "player_turn")
                test.equal(app.session.snapshot.game.round.initial_bet_units, 250)
                test.equal(app.session.snapshot.game.bankroll_units, 9750)
                test.equal(write_calls, 2, "One failed write and one adopted retry")
                test.equal(session.retry(app.session), false)
                test.equal(write_calls, 2)
            end
        )
    end

    test.test(
        "nested assistance settings return through each parent before the table menu",
        function()
            local app = app_fixture(hash, { "5", "10", "6", "7" })
            app.ui.page, app.ui.menu_origin = "menu", "table"
            desktop.activate(app, "assistance_page")
            test.equal(app.ui.page, "assistance")
            desktop.activate(app, "count_settings_page")
            test.equal(app.ui.page, "count_settings")
            desktop.intent(app, input.gamepad("b"))
            test.equal(app.ui.page, "assistance")
            desktop.intent(app, input.gamepad("b"))
            test.equal(app.ui.page, "menu")
            desktop.intent(app, input.gamepad("b"))
            test.equal(app.ui.page, "table")
            test.equal(app.ui.focus, 2)
        end
    )

    test.test(
        "tutorial handoff uses slow assisted Beginner practice and preserves saved preferences",
        function()
            local app = app_fixture(hash, { "5", "10", "6", "7" })
            local preferences = copy(app.session.snapshot.count_settings)
            preferences.level, preferences.assistance, preferences.pace = "advanced", false, "fast"
            assert(session.count_settings(app.session, preferences))
            local before = copy(app.session.snapshot)
            desktop.activate(app, "learn_hilo")
            -- This fixture starts from the terminal lesson, whose button is the handoff.
            app.lesson.complete = true
            desktop.activate(app, "tutorial_practice")
            test.equal(app.ui.page, "training")
            test.equal(app.trainer.mode, "counting")
            test.equal(app.trainer.target, "mixed")
            test.equal(app.trainer.settings.level, "beginner")
            test.equal(app.trainer.settings.assistance, true)
            test.equal(app.trainer.settings.pace, "slow")
            test.same(app.session.snapshot, before)
            test.same(app.session.snapshot.count_settings, preferences)
        end
    )

    -- ## ASSISTANCE USES PUBLIC INFORMATION

    test.test("Assisted Play OFF hides advice HUD and normal count checkpoints", function()
        local app = app_fixture(hash, { "5", "6", "6", "A" })
        local displays = copy(app.session.snapshot.count_settings)
        displays.show_running, displays.show_true, displays.show_decks = true, true, true
        assert(session.count_settings(app.session, displays))
        desktop.activate(app, "deal")
        finish_animation(app)
        local visible = desktop.visible(app)
        test.equal(visible.advice, nil)
        test.equal(visible.count, nil)
        desktop.activate(app, "menu")
        test.equal(enabled_button(app, "check_count"), false)
        test.equal(enabled_button(app, "check_true_count"), false)
        desktop.activate(app, "check_count")
        test.equal(app.ui.page, "menu")
        test.equal(app.trainer, nil)
    end)
    test.test(
        "BASIC uses current S17 H17 and double restrictions without a counting HUD",
        function()
            local app = app_fixture(hash, { "5", "A", "6", "9" })
            set_assistance(app.session, "basic")
            desktop.activate(app, "deal")
            test.equal(desktop.visible(app).advice, nil, "Unshown cards cannot receive advice")
            finish_animation(app)
            local visible = desktop.visible(app)
            test.equal(visible.advice.basic.action, "hit", "S17 hard 11 against Ace")
            test.equal(visible.advice.counts, nil)
            test.equal(visible.count, nil)

            local h17 = app_fixture(hash, { "5", "A", "6", "9" })
            local h17_rules = copy(h17.session.snapshot.game.rules)
            h17_rules.dealer_hits_soft_17 = true
            assert(session.command(h17.session, "configure", { rules = h17_rules }))
            -- Configure shuffles; restore only this in-memory test shoe's known order.
            h17.session.snapshot.game.shoe.order = fixtures.full_order({ "5", "A", "6", "9" }, 6)
            set_assistance(h17.session, "basic")
            desktop.activate(h17, "deal")
            finish_animation(h17)
            test.equal(
                desktop.visible(h17).advice.basic.action,
                "double",
                "H17 hard 11 against Ace"
            )

            local restricted = app_fixture(hash, { "A", "6", "6", "9" })
            local preset = copy(restricted.session.snapshot.game.rules)
            preset.double_rule = "10_to_11"
            assert(session.command(restricted.session, "configure", { rules = preset }))
            restricted.session.snapshot.game.shoe.order =
                fixtures.full_order({ "A", "6", "6", "9" }, 6)
            set_assistance(restricted.session, "basic")
            desktop.activate(restricted, "deal")
            finish_animation(restricted)
            test.equal(
                desktop.visible(restricted).advice.basic.action,
                "hit",
                "Soft 17 cannot double under D10"
            )
        end
    )
    test.test(
        "ADVANCED count remains hidden until exposure and HUD choices are independent",
        function()
            local app = app_fixture(hash, { "5", "6", "6", "A" })
            set_assistance(app.session, "advanced")
            desktop.activate(app, "deal")
            finish_animation(app)
            local visible = desktop.visible(app)
            test.equal(visible.count, nil, "All three HUD switches default off")
            test.equal(visible.advice.counts.running, 3, "Only 5, 6 and 6 are public")
            assert(visible.dealer.cards[2].hidden and visible.dealer.cards[2].id == nil)
            local before = copy(app.session.snapshot.game)
            desktop.activate(app, "hud_running")
            visible = desktop.visible(app)
            assert(visible.count_settings.show_running)
            test.equal(visible.count_settings.show_true, false)
            test.equal(visible.count_settings.show_decks, false)
            test.equal(visible.count.running, 3)
            test.same(app.session.snapshot.game, before)
            desktop.activate(app, "stand")
            test.equal(desktop.visible(app).count.running, 3, "Committed hole is still unshown")
            finish_animation(app)
            test.equal(desktop.visible(app).count.running, 2, "Revealed Ace now subtracts one")
        end
    )
    test.test(
        "advanced visual counts can all stay off while count checkpoints remain enabled",
        function()
            local app = app_fixture(hash, { "5", "6", "6", "A" })
            set_assistance(app.session, "advanced")
            desktop.activate(app, "deal")
            finish_animation(app)
            local normal = copy(app.session.snapshot.game)
            desktop.activate(app, "menu")
            assert(enabled_button(app, "check_count"))
            assert(enabled_button(app, "check_true_count"))
            desktop.activate(app, "check_count")
            test.equal(app.ui.page, "training")
            test.equal(app.trainer.counts.running, 3)
            app.trainer.entry = 3
            training.activate(app, "training_submit")
            test.equal(app.session.snapshot.training.counting.running_correct, 1)
            test.equal(app.session.snapshot.coach.active.practice.running.correct, 1)
            test.same(app.session.snapshot.game, normal)
            training.activate(app, "training_next")
            test.equal(app.ui.page, "table")
            test.equal(desktop.visible(app).count, nil)
        end
    )
    test.test(
        "assistance preferences persist without changing an active bankroll or shoe",
        function()
            local app, storage = app_fixture(hash, { "5", "10", "6", "9" })
            desktop.activate(app, "deal")
            finish_animation(app)
            local normal = copy(app.session.snapshot.game)
            education.activate(app, "assist_mode")
            education.activate(app, "assist_mode")
            education.activate(app, "assist_strategy_hints")
            education.activate(app, "assist_explanations")
            education.activate(app, "assist_deviations")
            education.activate(app, "assist_check_count")
            local expected = {
                mode = "advanced",
                strategy_hints = false,
                explanations = false,
                deviations = false,
                check_count = false,
            }
            test.same(app.session.snapshot.assistance, expected)
            test.same(session.open(storage).snapshot.assistance, expected)
            test.same(app.session.snapshot.game, normal)
        end
    )

    -- ## DECISIONS AND OUTCOMES ARE SEPARATE

    test.test(
        "Advanced deviation prompts off keep basic Hit and basic coaching consistent",
        function()
            local app = app_fixture(hash, { "10", "10", "5", "7", "2" })
            set_assistance(app.session, "advanced")
            local preferences = copy(app.session.snapshot.assistance)
            preferences.deviations = false
            assert(session.assistance_settings(app.session, preferences))
            desktop.activate(app, "deal")
            finish_animation(app)
            with_given_count(function()
                local advice = desktop.visible(app).advice
                test.equal(advice.basic.action, "hit")
                test.equal(advice.action, "hit")
                test.equal(advice.deviation, nil)
                assert(session.command(app.session, "hit"))
            end)
            test.same(app.session.snapshot.coach.active.play.hard, { attempts = 1, correct = 1 })
            test.same(
                app.session.snapshot.coach.active.play.deviation,
                { attempts = 0, correct = 0 }
            )
        end
    )
    test.test(
        "Advanced supported deviation grades Stand correctly despite the resulting loss",
        function()
            local app = app_fixture(hash, { "10", "10", "5", "7" })
            set_assistance(app.session, "advanced")
            desktop.activate(app, "deal")
            finish_animation(app)
            with_given_count(function()
                local advice = desktop.visible(app).advice
                test.equal(advice.basic.action, "hit")
                test.equal(advice.action, "stand")
                test.equal(advice.deviation.index, 4)
                assert(session.command(app.session, "stand"))
            end)
            test.equal(app.session.snapshot.game.round.result.net_units, -250)
            test.same(
                app.session.snapshot.coach.active.play.deviation,
                { attempts = 1, correct = 1 }
            )
            test.same(app.session.snapshot.coach.active.play.hard, { attempts = 0, correct = 0 })
        end
    )

    test.test("a correct Stand losing to dealer 18 remains a correct decision", function()
        local current = persistence.fixture(hash, { "10", "10", "7", "8" })
        assert(session.command(current, "deal", { bet_units = 100 }))
        assert(session.command(current, "stand"))
        test.equal(current.snapshot.game.round.result.net_units, -100)
        test.same(current.snapshot.coach.active.play.hard, { attempts = 1, correct = 1 })
        test.equal(current.snapshot.coach.active.results.losses, 1)
        local report = assert(coach.report(current.snapshot.coach))
        test.equal(report.strategy.percent, 100)
        test.equal(report.recommendation, nil)
    end)
    test.test(
        "an incorrect Stand winning against dealer bust remains an incorrect decision",
        function()
            local current = persistence.fixture(hash, { "10", "3", "2", "10", "10" })
            assert(session.command(current, "deal", { bet_units = 100 }))
            assert(session.command(current, "stand"))
            test.equal(current.snapshot.game.round.result.net_units, 100)
            test.same(current.snapshot.coach.active.play.hard, { attempts = 1, correct = 0 })
            test.equal(current.snapshot.coach.active.results.wins, 1)
            test.equal(assert(coach.report(current.snapshot.coach)).strategy.percent, 0)
        end
    )
    test.test(
        "twenty Double drills improve the Double practice category once per answer",
        function()
            local app = app_fixture(hash, { "5", "10", "6", "9" })
            for _ = 1, 10 do
                assert(session.training_answer(app.session, "strategy", false, "double"))
            end
            local normal = copy(app.session.snapshot.game)
            training.start(app, "strategy", "double")
            for drill = 1, 20 do
                assert(app.trainer.recommendation, app.trainer.error)
                test.equal(app.trainer.recommendation.action, "double")
                training.activate(app, "answer_double")
                training.activate(app, "answer_double")
                test.equal(app.trainer.drills_done, drill)
                training.activate(app, "training_next")
            end
            test.equal(app.ui.page, "coach")
            test.same(
                app.session.snapshot.coach.active.practice.double,
                { attempts = 30, correct = 20 }
            )
            test.equal(app.session.snapshot.coach.active.practice.hard.attempts, 0)
            test.equal(app.session.snapshot.coach.active.practice.soft.attempts, 0)
            test.same(app.session.snapshot.game, normal)
        end
    )
    test.test(
        "a coaching counter limit rejects an answer without throwing or changing progress",
        function()
            local current = persistence.fixture(hash, { "5", "10", "6", "9" })
            for _, summary in ipairs({
                current.snapshot.coach.active,
                current.snapshot.coach.lifetime,
            }) do
                summary.practice.running = { attempts = 1000000000000, correct = 1000000000000 }
            end
            assert(schema.validate(current.snapshot))
            local before, files = copy(current.snapshot), copy(current.storage.files)
            local did_not_throw, accepted = pcall(session.training_answer, current, "running", true)
            test.equal(did_not_throw, true)
            test.equal(accepted, false)
            test.equal(current.pending, nil)
            test.same(current.snapshot, before)
            test.same(current.storage.files, files)
        end
    )

    -- ## VERSION TWO SAVES RETAIN ALL OLD PROGRESS

    test.test(
        "v2 loads read-only and first v3 commit retains exact source backup and player progress",
        function()
            local current, storage, original, bytes = version_two_fixture(hash)
            assert(current.snapshot, current.message)
            test.equal(current.snapshot.format_version, 3)
            test.equal(current.saved.snapshot.format_version, 2)
            test.equal(current.migration_from, 2)
            test.equal(current.snapshot.revision, original.revision)
            same_old_progress(current.snapshot, original)
            test.equal(current.snapshot.assistance.mode, "off")
            test.equal(current.snapshot.coach.active.results.rounds, 0)
            test.equal(current.snapshot.coach.active.practice.mixed.attempts, 0)
            test.equal(storage.files["save_a.json"], bytes)
            test.equal(storage.files["backup_format_2.json"], nil)
            local previous_hash = current.saved.hash
            set_assistance(current, "basic")
            same_old_progress(current.snapshot, original)
            test.equal(storage.files["backup_format_2.json"], bytes)
            test.equal(storage.files["save_a.json"], bytes)
            test.equal(current.snapshot.revision, original.revision + 1)
            test.equal(current.snapshot.parent_snapshot_hash, previous_hash)
            test.equal(current.snapshot.app_version, schema.app_version)
            test.same(session.open(storage).snapshot, current.snapshot)
        end
    )
    test.test(
        "failed v2 backup preserves source and exact pending answer until one successful retry",
        function()
            local current, storage, original, bytes = version_two_fixture(hash)
            local before = copy(current.snapshot)
            local write = storage.write
            storage.write = function(name, contents)
                if name == "backup_format_2.json" then
                    return false, "disk full before migration backup"
                end
                return write(name, contents)
            end
            test.equal(session.training_answer(current, "running", true), false)
            assert(current.pending)
            test.equal(
                current.pending.training.counting.running_attempts,
                original.training.counting.running_attempts + 1
            )
            test.same(current.snapshot, before)
            test.equal(storage.files["save_a.json"], bytes)
            test.equal(storage.files["save_b.json"], nil)
            storage.write = write
            assert(session.retry(current), current.message)
            test.equal(
                current.snapshot.training.counting.running_attempts,
                original.training.counting.running_attempts + 1
            )
            test.equal(
                current.snapshot.training.counting.running_correct,
                original.training.counting.running_correct + 1
            )
            test.equal(current.snapshot.coach.active.practice.running.correct, 1)
            test.equal(storage.files["backup_format_2.json"], bytes)
            test.same(current.snapshot.game, original.game)
            test.equal(session.retry(current), false)
            test.same(session.open(storage).snapshot, current.snapshot)
        end
    )
end

return polish
