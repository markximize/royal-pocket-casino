-- PURPOSE: Express independently calculated Blackjack examples and boundaries.
-- CHANGE THIS MODULE WHEN: A rule/action bug or supported rule profile changes.
-- DO NOT PUT HERE: Hardware PASS claims or probabilities guessed from simulations.

local test = require("tests.harness")
local fixtures = require("tests.fixtures")
local copy = require("src.plain_copy")
local cards = require("src.blackjack.cards")
local hand = require("src.blackjack.hand")
local chips = require("src.blackjack.chips")
local rules = require("src.blackjack.rules")
local round = require("src.blackjack.round")
local actions = require("src.blackjack.player_actions")
local seeded = require("src.random.seeded")
local shoe = require("src.blackjack.shoe")
local stats = require("src.progress.statistics")
local equal, act = test.equal, fixtures.act
local unit = {}

function unit.run()
    local ace_cases = {
        { { "A", "K" }, 21, true, true },
        { { "A", "6" }, 17, true, false },
        { { "A", "6", "10" }, 17, false, false },
        { { "A", "A", "5" }, 17, true, false },
        { { "A", "A", "9" }, 21, true, false },
        { { "A", "A", "9", "K" }, 21, false, false },
        { { "K", "Q", "2" }, 22, false, false },
    }
    for _, example in ipairs(ace_cases) do
        test.test("evaluate " .. table.concat(example[1], "+"), function()
            local evaluated = hand.evaluate(fixtures.ids(example[1]), false)
            equal(evaluated.total, example[2])
            equal(evaluated.soft, example[3])
            equal(evaluated.natural, example[4])
        end)
    end
    test.test("a split ace and king is ordinary 21", function()
        equal(hand.evaluate(fixtures.ids({ "A", "K" }), true).natural, false)
    end)
    test.test("catalog builds 312 distinct six-deck cards", function()
        local ids = cards.deck_ids(6)
        equal(#ids, 312)
        equal(cards.describe(53).deck, 2)
        equal(cards.describe(14).suit, 2)
        equal(cards.rank(13), 13)
        equal(cards.value(13), 10)
    end)
    test.test("seed one has independently known Park-Miller values", function()
        local generator = seeded.new(1)
        for _, expected in ipairs({ 16807, 282475249, 1622650073, 984943658, 1144108930 }) do
            equal(seeded.next_state(generator), expected)
        end
    end)
    test.test("initial shuffle advances the owned RNG and preserves the injected seed", function()
        local injected = seeded.new(7)
        local game = round.new(rules.defaults(), injected, seeded.next_integer)
        equal(injected.state, 7)
        assert(game.rng.state ~= 7)
        test.same(game, round.new(rules.defaults(), seeded.new(7), seeded.next_integer))
    end)
    test.test("shuffle is a permutation and bounded draw can reach both endpoints", function()
        local generator = seeded.new(5)
        local current = shoe.new(rules.defaults(), generator, seeded.next_integer)
        local observed = {}
        for _, id in ipairs(current.order) do
            assert(not observed[id])
            observed[id] = true
        end
        for id = 1, 312 do
            assert(observed[id])
        end
        local ends = {}
        for _ = 1, 100 do
            ends[seeded.next_integer(generator, 1, 2)] = true
        end
        assert(ends[1] and ends[2])
    end)
    test.test("five-chip natural returns exactly twelve and a half chips", function()
        equal(chips.return_units(50, "blackjack"), 125)
        assert(not pcall(chips.return_units, 51, "blackjack"))
        assert(not chips.valid_bet(55))
        assert(not chips.is_integer(0 / 0, 0, chips.maximum))
        assert(not pcall(chips.add, chips.maximum, 1))
    end)
    test.test("A+K versus ten+nine credits 250 units and ends at 10150", function()
        local game = fixtures.deal({ "A", "10", "K", "9" })
        equal(game.phase, "round_result")
        equal(game.bankroll_units, 10150)
        equal(game.round.result.returned_units, 250)
        equal(game.shoe.next_index, 5)
    end)
    test.test("both naturals push and do not offer player actions", function()
        local game = fixtures.deal({ "A", "A", "K", "Q" })
        equal(game.bankroll_units, 10000)
        equal(game.round.result.hands[1].outcome, "push")
        assert(not actions.legal(game).hit)
    end)
    test.test("dealer peek ends an ordinary hand before any double or split", function()
        local game = fixtures.deal({ "10", "A", "J", "K" })
        equal(game.phase, "round_result")
        equal(game.bankroll_units, 9900)
        equal(game.round.action_counts.double_actions, 0)
    end)
    test.test("hit to 21 auto finishes; another hit is rejected without mutation", function()
        local game = act(fixtures.deal({ "10", "10", "5", "9", "6" }), "hit")
        equal(game.bankroll_units, 10100)
        local before = copy(game)
        assert(round.apply(game, round.command(game, "hit"), seeded.next_integer) == nil)
        test.same(game, before)
    end)
    test.test("player bust loses and dealer does not draw merely to bust", function()
        local game = act(fixtures.deal({ "10", "6", "9", "10", "8", "K" }), "hit")
        equal(game.bankroll_units, 9900)
        equal(#game.round.dealer.cards, 2)
        equal(game.shoe.next_index, 6)
    end)
    test.test("double 11 to 20 beats 19, returning 400 from a 200 stake", function()
        local game = act(fixtures.deal({ "5", "10", "6", "9", "9" }), "double")
        equal(game.bankroll_units, 10200)
        equal(game.round.result.staked_units, 200)
        equal(game.round.result.returned_units, 400)
        equal(#game.round.hands[1].cards, 3)
    end)
    test.test("a doubled bust loses the whole doubled stake", function()
        equal(act(fixtures.deal({ "10", "10", "2", "9", "K" }), "double").bankroll_units, 9800)
    end)
    test.test("insufficient funds reject split and double without consuming a card", function()
        local game = fixtures.game({ "8", "10", "8", "7", "K" })
        game.bankroll_units = 100
        game = act(game, "deal", { bet_units = 100 })
        local before = copy(game)
        for _, kind in ipairs({ "double", "split" }) do
            assert(round.apply(game, round.command(game, kind), seeded.next_integer) == nil)
            test.same(game, before)
        end
    end)
    test.test("splits deal replacements sequentially and settle one win plus one push", function()
        local game = act(fixtures.deal({ "8", "10", "8", "7", "10", "9" }), "split")
        equal(#game.round.hands[2].cards, 1)
        game = act(game, "stand")
        equal(game.round.active_hand, 2)
        game = act(game, "stand")
        equal(game.bankroll_units, 10100)
        equal(game.round.result.staked_units, 200)
        equal(game.round.result.returned_units, 300)
    end)
    test.test("split aces receive one card each and no natural premium", function()
        local game = act(fixtures.deal({ "A", "9", "A", "8", "K", "9" }), "split")
        equal(game.phase, "round_result")
        equal(game.bankroll_units, 10200)
        equal(game.round.result.returned_units, 400)
        equal(game.round.result.hands[1].natural, false)
    end)
    test.test("replacement ace stays locked because resplitting aces is disabled", function()
        local game = act(fixtures.deal({ "A", "9", "A", "8", "A", "K" }), "split")
        equal(game.phase, "round_result")
        equal(#game.round.hands, 2)
        equal(#game.round.hands[1].cards, 2)
    end)
    test.test("K and Q cannot split despite equal point values", function()
        assert(not actions.legal(fixtures.deal({ "K", "10", "Q", "7" })).split)
    end)
    test.test("resplits stop at four total hands", function()
        local game = fixtures.deal({ "8", "10", "8", "7", "8", "8", "8", "8", "8", "8" })
        for _ = 1, 3 do
            game = act(game, "split")
        end
        equal(#game.round.hands, 4)
        assert(not actions.legal(game).split)
        while game.phase == "player_turn" do
            game = act(game, "stand")
        end
        equal(game.round.result.staked_units, 400)
    end)
    for _, hits_soft in ipairs({ false, true }) do
        test.test(hits_soft and "H17 draws A+6 to soft 19" or "S17 stands on A+6", function()
            local preset = rules.defaults()
            preset.dealer_hits_soft_17 = hits_soft
            local game = act(fixtures.deal({ "10", "A", "8", "6", "2" }, preset), "stand")
            equal(game.bankroll_units, hits_soft and 9900 or 10100)
            equal(#game.round.dealer.cards, hits_soft and 3 or 2)
        end)
    end
    for _, names in ipairs({ { "10" }, { "10", "10", "2", "9" } }) do
        test.test(
            "exhaustion refunds the whole round at deal/action boundary " .. #names,
            function()
                local game = fixtures.deal(names)
                if game.phase == "player_turn" then
                    game = act(game, "double")
                end
                equal(game.bankroll_units, 10000)
                equal(game.round.result.void, true)
                assert(game.shoe.shuffle_pending)
            end
        )
    end
    test.test("exhaustion on split/dealer never pays only part of a round", function()
        for _, kind in ipairs({ "split", "stand" }) do
            local game = act(fixtures.deal({ "8", "6", "8", "10" }), kind)
            equal(game.round.result.void, true)
            equal(game.bankroll_units, 10000)
        end
    end)
    test.test("crossing the cut waits for the round to finish before reshuffling", function()
        local game = fixtures.game({ "10", "10", "2", "9", "2" })
        game.shoe.cut_position = 4
        game = act(game, "deal", { bet_units = 100 })
        equal(game.shoe.generation, 1)
        assert(game.shoe.shuffle_pending)
        game = act(act(game, "stand"), "next_round")
        equal(game.shoe.generation, 1)
        game = act(game, "deal", { bet_units = 100 })
        equal(game.shoe.generation, 2)
        equal(#game.shoe.order, 312)
    end)
    test.test("stale commands and unsupported variants are rejected", function()
        local game = fixtures.game({ "10", "10", "2", "9" })
        local stale = round.command(game, "deal", { bet_units = 100 })
        game = act(game, "deal", { bet_units = 100 })
        assert(round.apply(game, stale, seeded.next_integer) == nil)
        for _, kind in ipairs({ "insurance", "surrender", "even_money", "configure", "shuffle" }) do
            assert(round.apply(game, round.command(game, kind), seeded.next_integer) == nil)
        end
        local unsupported = rules.defaults()
        unsupported.insurance = true
        assert(not rules.validate(unsupported))
        unsupported = rules.defaults()
        unsupported.unknown = true
        assert(not rules.validate(unsupported))
    end)
    test.test("statistics count natural pushes as naturals and voids separately", function()
        local counters = stats.new()
        stats.record(counters, fixtures.deal({ "A", "A", "K", "Q" }).round)
        stats.record(counters, fixtures.deal({ "A" }).round)
        equal(counters.completed_rounds, 1)
        equal(counters.pushes, 1)
        equal(counters.natural_blackjacks, 1)
        equal(counters.void_rounds, 1)
        equal(counters.main_net_units, 0)
    end)
    test.test("numeric headroom is reserved before a bet", function()
        local game = fixtures.game({ "A", "10", "K", "9" })
        game.bankroll_units = chips.maximum
        assert(
            round.apply(game, round.command(game, "deal", { bet_units = 100 }), seeded.next_integer)
                == nil
        )
        local counters = stats.new()
        counters.main_returned_units = chips.maximum
        assert(not stats.can_start(counters, 100))
    end)
end

function unit.rule_matrix()
    local count = 0
    for _, decks in ipairs({ 6, 8 }) do
        for _, soft in ipairs({ false, true }) do
            for _, double_rule in ipairs({ "any_two", "9_to_11", "10_to_11" }) do
                for _, das in ipairs({ true, false }) do
                    for _, penetration in ipairs({ 50, 67, 75 }) do
                        local preset = rules.defaults()
                        preset.deck_count, preset.dealer_hits_soft_17 = decks, soft
                        preset.double_rule, preset.double_after_split, preset.penetration_percent =
                            double_rule, das, penetration
                        count = count + 1
                        test.test("supported profile " .. rules.profile_id(preset), function()
                            assert(rules.validate(preset))
                            local game = fixtures.deal({ "5", "10", "6", "9", "9" }, preset)
                            assert(actions.legal(game).double)
                            equal(act(game, "double").bankroll_units, 10200)
                            game = fixtures.deal({ "8", "10", "8", "7", "3", "3" }, preset)
                            game = act(game, "split")
                            equal(actions.legal(game).double, das)
                            local soft_game = fixtures.deal({ "10", "A", "8", "6", "2" }, preset)
                            equal(act(soft_game, "stand").bankroll_units, soft and 9900 or 10100)
                        end)
                    end
                end
            end
        end
    end
    equal(count, 72)
end

return unit
