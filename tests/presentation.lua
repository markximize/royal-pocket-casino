-- PURPOSE: Exercise input-to-session behavior without a physical controller.
-- CHANGE THIS MODULE WHEN: Navigation, command routing or visible actions change.
-- DO NOT PUT HERE: Hardware compatibility claims or pixel-perfect snapshots.

local test = require("tests.harness")
local desktop = require("src.app.desktop")
local input = require("src.platform.love_input")
local session = require("src.app.session")
local persistence = require("tests.persistence")
local view = require("src.app.player_view")
local animation = require("src.ui.presentation")
local copy = require("src.plain_copy")
local presentation = {}

local function fixture_app(hash, ranks)
    local current, storage = persistence.fixture(hash, ranks)
    return {
        session = current,
        ui = { page = "table", focus = 2, bet_units = 100, inspect_hand = 1 },
    },
        storage
end

function presentation.run(hash)
    test.test(
        "retrying the first profile write can display a valid view without animation",
        function()
            local app = fixture_app(hash, { "A", "10", "K", "9" })
            local after = view.build(app.session)
            local before = { error = "disk full", pending = true }
            local current = animation.new(before)
            animation.begin(current, before, after, "resume", false)
            assert(not animation.busy(current))
            test.same(current.displayed, after)
        end
    )
    test.test("Enter deals, D doubles 11, and the result survives reload", function()
        local app, storage = fixture_app(hash, { "5", "10", "6", "9", "9" })
        desktop.intent(app, input.key("return"))
        assert(view.build(app.session).dealer.cards[2].hidden)
        animation.finish(app.presentation)
        desktop.intent(app, input.key("d"))
        test.equal(app.session.snapshot.game.bankroll_units, 10200)
        test.equal(session.open(storage).snapshot.statistics.double_actions, 1)
    end)
    test.test("focus skips unavailable split and confirm stands on the selected action", function()
        local app = fixture_app(hash, { "10", "10", "7", "9" })
        desktop.intent(app, "confirm")
        animation.finish(app.presentation)
        desktop.intent(app, "previous")
        test.equal(desktop.buttons(app)[app.ui.focus].kind, "double")
        desktop.intent(app, "previous")
        test.equal(desktop.buttons(app)[app.ui.focus].kind, "stand")
        desktop.intent(app, "confirm")
        test.equal(app.session.snapshot.game.phase, "round_result")
        test.equal(app.session.snapshot.statistics.completed_rounds, 1)
    end)
    test.test("mouse bet changes and confirm use the same persisted deal command", function()
        local app = fixture_app(hash, { "A", "10", "K", "9" })
        local plus = desktop.buttons(app)[3]
        desktop.mouse(app, plus.x + 4, plus.y + 4)
        test.equal(app.ui.bet_units, 150)
        local deal = desktop.buttons(app)[2]
        desktop.mouse(app, deal.x + 4, deal.y + 4)
        test.equal(app.session.snapshot.game.bankroll_units, 10225)
    end)
    test.test(
        "Start opens menu, B returns, and shoulder intent inspects settled split hands",
        function()
            local app = fixture_app(hash, { "8", "10", "8", "7", "10", "9" })
            desktop.intent(app, input.gamepad("start"))
            test.equal(app.ui.page, "menu")
            desktop.intent(app, input.gamepad("b"))
            test.equal(app.ui.page, "table")
            desktop.intent(app, "confirm")
            animation.finish(app.presentation)
            desktop.intent(app, input.key("p"))
            animation.finish(app.presentation)
            desktop.intent(app, input.key("s"))
            animation.finish(app.presentation)
            desktop.intent(app, input.key("s"))
            animation.finish(app.presentation)
            app.ui.inspect_hand = 1
            desktop.intent(app, input.gamepad("rightshoulder"))
            test.equal(app.ui.inspect_hand, 2)
            desktop.intent(app, input.gamepad("leftshoulder"))
            test.equal(app.ui.inspect_hand, 1)
        end
    )
    test.test("rapid confirm finishes a deal animation without committing another move", function()
        local app = fixture_app(hash, { "5", "10", "6", "9", "9" })
        desktop.intent(app, "confirm")
        local committed = copy(app.session.snapshot)
        assert(animation.busy(app.presentation))
        desktop.intent(app, "double")
        test.same(app.session.snapshot, committed)
        desktop.intent(app, "confirm")
        assert(not animation.busy(app.presentation))
        test.same(app.session.snapshot, committed)
        desktop.intent(app, "double")
        test.equal(app.session.snapshot.game.bankroll_units, 10200)
    end)
    test.test(
        "animated natural withholds payout and dealer hole until the committed reveal",
        function()
            local app = fixture_app(hash, { "A", "10", "K", "9" })
            desktop.intent(app, "confirm")
            test.equal(app.session.snapshot.game.bankroll_units, 10150)
            local visible = desktop.visible(app)
            assert(visible.result == nil and #visible.dealer.cards == 0)
            test.equal(visible.bankroll_units, 9900)
            animation.update(app.presentation, 0.80)
            visible = desktop.visible(app)
            assert(visible.result == nil and visible.dealer.cards[2].hidden)
            animation.update(app.presentation, 10)
            visible = desktop.visible(app)
            assert(visible.result and not visible.dealer.cards[2].hidden)
            test.equal(visible.bankroll_units, 10150)
        end
    )
    test.test("reduced motion shows the same saved payout immediately", function()
        local app, storage = fixture_app(hash, { "A", "10", "K", "9" })
        local settings = copy(app.session.snapshot.settings)
        settings.reduced_motion = true
        assert(session.settings(app.session, settings))
        desktop.intent(app, "confirm")
        assert(not animation.busy(app.presentation))
        test.equal(desktop.visible(app).result.returned_units, 250)
        test.equal(session.open(storage).snapshot.game.bankroll_units, 10150)
    end)
    test.test("chip selection stays funded and never changes a committed bankroll", function()
        local app = fixture_app(hash, { "5", "10", "6", "9", "9" })
        local before = copy(app.session.snapshot)
        desktop.activate(app, "chip_25")
        test.equal(app.ui.bet_units, 350)
        for _ = 1, 10 do
            desktop.activate(app, "chip_25")
        end
        test.equal(app.ui.bet_units, 1000)
        test.same(app.session.snapshot, before)
    end)
    test.test("failed deal has no new animation or exposed cards", function()
        local app, storage = fixture_app(hash, { "A", "10", "K", "9" })
        storage.write = function()
            return false, "disk full"
        end
        desktop.intent(app, "confirm")
        assert(app.session.pending and not animation.busy(app.presentation))
        test.equal(desktop.visible(app).phase, "betting")
        test.equal(desktop.visible(app).bankroll_units, 10000)
    end)
    test.test(
        "home and help navigation retain an active hand without placing another bet",
        function()
            local app = fixture_app(hash, { "5", "10", "6", "9", "9" })
            desktop.intent(app, "confirm")
            local before = copy(app.session.snapshot)
            desktop.activate(app, "home")
            desktop.activate(app, "help")
            desktop.activate(app, "back")
            test.equal(app.ui.page, "welcome")
            desktop.activate(app, "play")
            test.equal(app.ui.page, "table")
            test.same(app.session.snapshot, before)
        end
    )
end

return presentation
