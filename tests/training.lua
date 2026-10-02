-- PURPOSE: Verify real trainer progression, controller entry and table isolation.
-- CHANGE THIS MODULE WHEN: Training scoring, checkpoints or session integration changes.
-- DO NOT PUT HERE: Hardware claims or expected strategy computed by a second call.

local test = require("tests.harness")
local copy = require("src.plain_copy")
local rules = require("src.blackjack.rules")
local defaults = require("src.persistence.migrations").count_defaults
local practice = require("src.training.practice")
local training = require("src.app.training")
local desktop = require("src.app.desktop")
local persistence = require("tests.persistence")
local session = require("src.app.session")
local count_view = require("src.app.count_view")
local animation = require("src.ui.presentation")
local trainer_tests = {}

function trainer_tests.run(hash)
    test.test("the tenth practice card stays visible before its checkpoint opens", function()
        local settings = defaults()
        settings.level = "practice"
        local current = practice.new("counting", rules.defaults(), 1, settings)
        for _ = 1, 10 do
            practice.update(current, 1.5)
        end
        test.equal(current.phase, "cards")
        test.equal(current.observer.exposed_count, 10)
        assert(current.card and current.check_due == "running")
        practice.update(current, 1.49)
        test.equal(current.phase, "cards")
        practice.update(current, 0.01)
        test.equal(current.phase, "answer")
        test.equal(current.observer.exposed_count, 10)
        local answer = practice.answer(current, current.observer.running_count)
        assert(answer.correct and answer.kind == "running")
    end)
    test.test(
        "advanced checkpoints alternate running and true count without revealing extra cards",
        function()
            local settings = defaults()
            settings.level = "advanced"
            local current = practice.new("counting", rules.defaults(), 2, settings)
            for _ = 1, 11 do
                practice.update(current, 1.5)
            end
            test.equal(current.answer_kind, "running")
            practice.accept(current, practice.answer(current, 123))
            practice.next(current)
            for _ = 1, 11 do
                practice.update(current, 1.5)
            end
            test.equal(current.answer_kind, "true_count")
            test.equal(current.observer.exposed_count, 20)
            local counts = practice.counts(current)
            assert(practice.answer(current, counts.true_count).correct)
            assert(not practice.answer(current, counts.true_count + 1).correct)
        end
    )
    test.test(
        "paused counting and fresh-shoe reset preserve deterministic drill behavior",
        function()
            local current = practice.new("counting", rules.defaults(), 1, defaults())
            current.paused = true
            practice.update(current, 100)
            test.equal(current.observer.running_count, 0)
            test.equal(current.observer.exposed_count, 0)
            current.paused = false
            practice.update(current, 100)
            test.equal(current.observer.exposed_count, 1)
            practice.shuffle(current)
            test.equal(current.observer.exposed_count, 0)
            test.equal(current.observer.running_count, 0)
            test.equal(current.shoe.generation, 2)
        end
    )
    test.test(
        "strategy practice reaches real legal decisions with the configured table rules",
        function()
            local preset = rules.defaults()
            preset.dealer_hits_soft_17, preset.double_rule = true, "10_to_11"
            local current = practice.new("strategy", preset, 12345, defaults())
            assert(current.recommendation, current.error)
            test.same(current.game.rules, preset)
            test.equal(current.game.phase, "player_turn")
            local visible = practice.table_view(current)
            assert(visible.dealer.cards[2].hidden and visible.dealer.cards[2].id == nil)
            assert(practice.answer(current, "insurance") == nil)
        end
    )
    if not hash then
        return
    end
    local function app_fixture(ranks)
        local current, storage = persistence.fixture(hash, ranks)
        return {
            session = current,
            ui = { page = "table", focus = 2, bet_units = 100, inspect_hand = 1 },
        },
            storage
    end
    local function running(app)
        local visible = desktop.visible(app)
        return count_view.build(app.session.snapshot.game, visible, defaults()).running
    end
    test.test(
        "the normal count view excludes a committed but unshown hole and deduplicates discards",
        function()
            local app = app_fixture({ "5", "6", "6", "A" })
            desktop.intent(app, "confirm")
            test.equal(running(app), 0)
            animation.update(app.presentation, 1)
            test.equal(running(app), 3)
            desktop.intent(app, "stand")
            test.equal(running(app), 3)
            animation.update(app.presentation, 1)
            test.equal(running(app), 2)
            assert(session.command(app.session, "next_round"))
            test.equal(running(app), 2)
            assert(session.command(app.session, "shuffle"))
            test.equal(running(app), 0)
        end
    )
    test.test(
        "leaving the table pauses its reveal and count checks wait until the cards are shown",
        function()
            local app = app_fixture({ "5", "6", "6", "A" })
            desktop.intent(app, "confirm")
            desktop.activate(app, "menu")
            desktop.update(app, 20)
            assert(animation.busy(app.presentation))
            desktop.activate(app, "check_count")
            test.equal(app.ui.page, "menu")
            desktop.activate(app, "back")
            desktop.update(app, 1)
            assert(not animation.busy(app.presentation))
        end
    )
    test.test("menu and trainer confirmation cannot reveal the suspended table", function()
        local app = app_fixture({ "5", "6", "6", "A" })
        desktop.intent(app, "confirm")
        desktop.activate(app, "menu")
        app.ui.focus = 2
        local sound_before = app.session.snapshot.settings.sound_enabled
        desktop.intent(app, "confirm")
        assert(animation.busy(app.presentation))
        test.equal(desktop.visible(app).settings.sound_enabled, not sound_before)
        test.equal(running(app), 0)
        desktop.activate(app, "count_settings_page")
        desktop.activate(app, "hud_running")
        assert(desktop.visible(app).count_settings.show_running)
        desktop.activate(app, "home")
        desktop.activate(app, "strategy_start")
        training.activate(app, "answer_" .. app.trainer.recommendation.action)
        assert(animation.busy(app.presentation))
        test.equal(desktop.visible(app).training.strategy.correct, 1)
        desktop.intent(app, "confirm")
        assert(animation.busy(app.presentation))
        test.equal(running(app), 0)
    end)
    test.test(
        "settings retry preserves paused cards rather than revealing the committed hole",
        function()
            local app, storage = app_fixture({ "5", "6", "6", "A" })
            desktop.intent(app, "confirm")
            desktop.activate(app, "menu")
            local before = copy(app.presentation)
            local write = storage.write
            storage.write = function()
                return false, "disk full"
            end
            desktop.activate(app, "sound")
            assert(app.session.pending)
            storage.write = write
            desktop.activate(app, "retry")
            test.same(app.presentation, before)
            assert(not app.session.pending)
            test.equal(running(app), 0)
        end
    )
    test.test(
        "strategy answers score once and leave the normal shoe and bankroll unchanged",
        function()
            local app, storage = app_fixture({ "5", "6", "6", "A" })
            desktop.intent(app, "confirm")
            local normal = copy(app.session.snapshot.game)
            training.start(app, "strategy")
            local chosen = app.trainer.recommendation.action
            training.activate(app, "answer_" .. chosen)
            test.equal(app.trainer.phase, "feedback")
            test.equal(app.session.snapshot.training.strategy.correct, 1)
            training.activate(app, "answer_" .. chosen)
            test.equal(app.session.snapshot.training.strategy.attempts, 1)
            training.activate(app, "training_next")
            test.same(app.session.snapshot.game, normal)
            test.same(session.open(storage).snapshot.game, normal)
        end
    )
    test.test(
        "failed trainer answer focuses retry and cannot advance or leave before one saved score",
        function()
            local app, storage = app_fixture({ "5", "6", "6", "A" })
            training.start(app, "counting")
            practice.check(app.trainer, "running")
            app.ui.focus = 2
            local write = storage.write
            storage.write = function()
                return false, "disk full"
            end
            desktop.intent(app, "confirm")
            assert(app.session.pending and app.pending_training_answer)
            test.equal(app.ui.focus, 1)
            desktop.intent(app, "back")
            test.equal(app.ui.page, "training")
            training.activate(app, "training_next")
            test.equal(app.trainer.phase, "answer")
            storage.write = write
            desktop.intent(app, "confirm")
            test.equal(app.trainer.phase, "feedback")
            test.equal(app.session.snapshot.training.counting.running_correct, 1)
            assert(app.pending_training_answer == nil and app.session.pending == nil)
            desktop.intent(app, "confirm")
            test.equal(app.session.snapshot.training.counting.attempts, 1)
        end
    )
    test.test(
        "count entry uses face buttons and shoulders without a keyboard and persists true answers",
        function()
            local app, storage = app_fixture({ "5", "6", "6", "A" })
            training.check_table(app, { running = -3, true_count = -1, decks = 2.5 })
            app.trainer.answer_kind = "true_count"
            desktop.intent(app, "count_up")
            desktop.intent(app, "inspect_previous")
            desktop.intent(app, "count_up")
            desktop.intent(app, "count_up")
            desktop.intent(app, "count_up")
            test.equal(app.trainer.entry, -1)
            desktop.intent(app, "confirm")
            test.equal(app.session.snapshot.training.counting.true_correct, 1)
            test.equal(session.open(storage).snapshot.training.counting.true_attempts, 1)
        end
    )
end

return trainer_tests
