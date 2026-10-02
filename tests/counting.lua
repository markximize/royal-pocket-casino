-- PURPOSE: Verify public-card Hi-Lo observation and explicit count conventions.
-- CHANGE THIS MODULE WHEN: An exposure bug or count convention changes.
-- DO NOT PUT HERE: Expected answers calculated from the implementation under test.

local test = require("tests.harness")
local fixtures = require("tests.fixtures")
local cards = require("src.blackjack.cards")
local copy = require("src.plain_copy")
local hi_lo = require("src.training.hi_lo")
local player_view = require("src.app.player_view")
local presentation = require("src.ui.presentation")
local rules = require("src.blackjack.rules")
local seeded = require("src.random.seeded")
local shoe = require("src.blackjack.shoe")
local counting = {}
local equal = test.equal

local function exposed_view(game)
    return player_view.build({
        snapshot = { game = game, statistics = {}, settings = {}, revision = 1 },
    })
end

local function observe(current, generation, card_ids)
    local next_observer, reason = hi_lo.observe(current, generation, card_ids)
    assert(next_observer, reason)
    return next_observer
end

function counting.run()
    test.test("a fresh shoe starts with zero exposed cards and running count zero", function()
        local current = assert(hi_lo.new(1))
        equal(current.running_count, 0)
        equal(current.exposed_count, 0)
        equal(next(current.seen), nil)
        equal(hi_lo.estimate_decks(6, 0), 6)
    end)
    local tags = { -1, 1, 1, 1, 1, 1, 0, 0, 0, -1, -1, -1, -1 }
    for rank, expected in ipairs(tags) do
        test.test("Hi-Lo tag for " .. cards.rank_names[rank] .. " is " .. expected, function()
            equal(hi_lo.tag(rank), expected)
            equal(hi_lo.tag(rank + 13), expected, "Another suit")
            equal(hi_lo.tag(rank + 52 * 5), expected, "Another deck")
        end)
    end
    test.test("low neutral and high exposures produce the independently known sequence", function()
        local card_ids = fixtures.ids({ "2", "3", "7", "A", "K", "6", "9", "10" })
        local expected_counts = { 1, 2, 2, 1, 0, 1, 1, 0 }
        local current = assert(hi_lo.new(1))
        for index, card_id in ipairs(card_ids) do
            current = observe(current, 1, { card_id })
            equal(current.running_count, expected_counts[index])
            equal(current.exposed_count, index)
        end
    end)
    test.test(
        "observation returns a new state without mutating the previous exposure map",
        function()
            local current = assert(hi_lo.new(1))
            local original = copy(current)
            local counted = observe(current, 1, { 2, 3, 10 })
            equal(counted.running_count, 1)
            equal(counted.exposed_count, 3)
            test.same(current, original)
            counted.seen[4] = true
            equal(current.seen[4], nil)
        end
    )
    test.test(
        "the same physical card counts once while identical ranks in other decks count",
        function()
            local current = observe(assert(hi_lo.new(1)), 1, { 2, 2, 54 })
            equal(current.running_count, 2)
            equal(current.exposed_count, 2)
            local repeated = observe(current, 1, { 2, 54, 54 })
            equal(repeated.running_count, 2)
            equal(repeated.exposed_count, 2)
        end
    )
    test.test("dealer hole remains excluded until the real round reveals it", function()
        -- Player 2+3, dealer 6+Ace: only 2, 3 and 6 are public before Stand.
        local game = fixtures.deal({ "2", "6", "3", "A" })
        local current =
            observe(assert(hi_lo.new(1)), 1, assert(hi_lo.visible_ids(exposed_view(game))))
        equal(current.running_count, 3)
        equal(current.exposed_count, 3)
        equal(current.seen[1], nil, "Hidden Ace")
        game = fixtures.act(game, "stand")
        equal(game.phase, "round_result")
        current = observe(current, 1, assert(hi_lo.visible_ids(exposed_view(game))))
        equal(current.running_count, 2)
        equal(current.exposed_count, 4)
    end)
    test.test(
        "a hidden dealer entry contributes nothing even if an ID is accidentally present",
        function()
            local visible = {
                hands = { { cards = { 2, 3 } } },
                dealer = { cards = { { id = 6 }, { hidden = true, id = 1 } } },
            }
            test.same(assert(hi_lo.visible_ids(visible)), { 2, 3, 6 })
        end
    )
    test.test(
        "count follows displayed dealing and the visible midpoint of the hole flip",
        function()
            local game = fixtures.game({ "2", "6", "3", "A" })
            local before = exposed_view(game)
            game = fixtures.act(game, "deal", { bet_units = 100 })
            local after = exposed_view(game)
            local timeline = presentation.new(before)
            presentation.begin(timeline, before, after, "deal", false)
            local current = assert(hi_lo.new(1))
            current =
                observe(current, 1, assert(hi_lo.visible_ids(presentation.view(timeline, after))))
            equal(current.running_count, 0, "Cards not displayed yet")
            local expected = { 1, 2, 3, 3 }
            for index, expected_count in ipairs(expected) do
                presentation.update(timeline, index == 1 and 0.01 or 0.24)
                local displayed = presentation.view(timeline, after)
                current = observe(current, 1, assert(hi_lo.visible_ids(displayed)))
                equal(current.running_count, expected_count, "Displayed deal step " .. index)
            end
            presentation.finish(timeline)
            game = fixtures.act(game, "stand")
            local revealed = exposed_view(game)
            presentation.begin(timeline, after, revealed, "stand", false)
            presentation.update(timeline, 0.1)
            current = observe(
                current,
                1,
                assert(hi_lo.visible_ids(presentation.view(timeline, revealed)))
            )
            equal(current.running_count, 3, "Still seeing the card back")
            presentation.update(timeline, 0.05)
            current = observe(
                current,
                1,
                assert(hi_lo.visible_ids(presentation.view(timeline, revealed)))
            )
            equal(current.running_count, 2, "Ace face is now visible")
            equal(current.exposed_count, 4)
        end
    )
    test.test("split hands count new public cards and never count moved originals twice", function()
        -- Exposed 4, 6, 4 gives +3; first split replacement 2 raises it to +4.
        local game = fixtures.deal({ "4", "6", "4", "A", "2", "3" })
        local current =
            observe(assert(hi_lo.new(1)), 1, assert(hi_lo.visible_ids(exposed_view(game))))
        game = fixtures.act(game, "split")
        local visible = exposed_view(game)
        equal(#visible.hands, 2)
        current = observe(current, 1, assert(hi_lo.visible_ids(visible)))
        equal(current.running_count, 4)
        equal(current.exposed_count, 4)
        game = fixtures.act(game, "stand")
        current = observe(current, 1, assert(hi_lo.visible_ids(exposed_view(game))))
        equal(current.running_count, 5)
        equal(current.exposed_count, 5)
    end)
    test.test(
        "a newer shuffle generation starts at zero and physical IDs may appear again",
        function()
            local current = observe(assert(hi_lo.new(1)), 1, { 2, 3 })
            local empty = observe(current, 2, {})
            equal(empty.running_count, 0)
            equal(empty.exposed_count, 0)
            local next_shoe = observe(empty, 2, { 2, 10 })
            equal(next_shoe.running_count, 0)
            equal(next_shoe.exposed_count, 2)
            equal(current.running_count, 2, "Old generation retained")
            assert(not hi_lo.observe(next_shoe, 1, { 3 }))
        end
    )
    test.test("a predetermined shoe yields the same count sequence on every replay", function()
        local order = fixtures.ids({ "5", "10", "2", "8", "Q", "6", "A" })
        local expected = { 1, 0, 1, 1, 0, 1, 0 }
        for _ = 1, 2 do
            local current_shoe = shoe.fixture(copy(order))
            local current = assert(hi_lo.new(1))
            for index, expected_count in ipairs(expected) do
                current = observe(current, 1, { assert(shoe.draw(current_shoe)) })
                equal(current.running_count, expected_count, "Exposure " .. index)
            end
        end
    end)
    test.test(
        "replaying a seeded full shoe preserves every observed count and ends balanced",
        function()
            local first = shoe.new(rules.defaults(), seeded.new(713), seeded.next_integer)
            local second = shoe.new(rules.defaults(), seeded.new(713), seeded.next_integer)
            local first_count, second_count = assert(hi_lo.new(1)), assert(hi_lo.new(1))
            for _ = 1, 312 do
                first_count = observe(first_count, 1, { assert(shoe.draw(first)) })
                second_count = observe(second_count, 1, { assert(shoe.draw(second)) })
                equal(first_count.running_count, second_count.running_count)
            end
            equal(first_count.running_count, 0)
            equal(first_count.exposed_count, 312)
            equal(hi_lo.estimate_decks(6, 312), 0.5)
        end
    )
    test.test("deck estimation rounds up to half decks using only exposed-card quantity", function()
        equal(hi_lo.estimate_decks(6, 1), 6)
        equal(hi_lo.estimate_decks(6, 26), 5.5)
        equal(hi_lo.estimate_decks(6, 27), 5.5)
        equal(hi_lo.estimate_decks(6, 52), 5)
        equal(hi_lo.estimate_decks(6, 166), 3, "146 cards remain, about 2.8 decks")
        equal(hi_lo.estimate_decks(6, 311), 0.5)
        equal(hi_lo.estimate_decks(6, 26, 1), 6)
        equal(hi_lo.estimate_decks(8, 26), 7.5)
    end)
    test.test("true count truncates toward zero by default including negative quotients", function()
        equal(hi_lo.true_count(8, 2.8), 2)
        equal(hi_lo.true_count(-8, 2.8), -2)
        equal(hi_lo.true_count(-1, 3), 0)
        equal(hi_lo.true_count(0, 0.5), 0)
        equal(hi_lo.true_count(3, 0.5), 6)
        equal(hi_lo.true_count(-6, 2, "truncate"), -3)
    end)
    test.test("explicit floor convention differs for negative noninteger true counts", function()
        equal(hi_lo.true_count(-8, 2.8, "floor"), -3)
        equal(hi_lo.true_count(8, 2.8, "floor"), 2)
    end)
    test.test("invalid count inputs fail with a reason without inventing a count", function()
        for _, card_id in ipairs({ 0, -1, 417, 1.5, "A", math.huge }) do
            local tag, reason = hi_lo.tag(card_id)
            equal(tag, nil)
            assert(type(reason) == "string")
        end
        assert(not hi_lo.new(0))
        assert(not hi_lo.observe({}, 1, { 2 }))
        assert(not hi_lo.observe(assert(hi_lo.new(1)), 1, { 0 }))
        assert(not hi_lo.observe(assert(hi_lo.new(1)), 1, { named = 2 }))
        assert(not hi_lo.observe(assert(hi_lo.new(1)), 1, { [1] = 2, [3] = 3 }))
        assert(not hi_lo.observe(assert(hi_lo.new(1)), 0, {}))
        local inconsistent = assert(hi_lo.new(1))
        inconsistent.running_count = 1
        assert(not hi_lo.observe(inconsistent, 1, {}))
        assert(not hi_lo.estimate_decks(6, 313))
        assert(not hi_lo.estimate_decks(6, 1.5))
        assert(not hi_lo.estimate_decks(6, 1, 0.25))
        assert(not hi_lo.estimate_decks(6, 1, false))
        assert(not hi_lo.true_count(2, 0))
        assert(not hi_lo.true_count(2, 0.1))
        assert(not hi_lo.true_count(2, math.huge))
        assert(not hi_lo.true_count(0 / 0, 1))
        assert(not hi_lo.true_count(1.5, 1))
        assert(not hi_lo.true_count(2, 1, "nearest"))
        assert(not hi_lo.true_count(2, 1, false))
        assert(not hi_lo.visible_ids({}))
        assert(not hi_lo.visible_ids({ hands = {}, dealer = { cards = { { id = 0 } } } }))
    end)
end

return counting
