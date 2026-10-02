-- PURPOSE: Check published strategy examples, legal fallbacks and hidden-card isolation.
-- CHANGE THIS MODULE WHEN: A strategy row or verified profile changes.
-- DO NOT PUT HERE: Expected results calculated by the strategy function itself.

local test = require("tests.harness")
local fixtures = require("tests.fixtures")
local rules = require("src.blackjack.rules")
local hand = require("src.blackjack.hand")
local actions = require("src.blackjack.player_actions")
local copy = require("src.plain_copy")
local strategy = require("src.training.basic_strategy")
local strategy_tests = {}

local function decision(player_ranks, dealer_rank, preset)
    local ranks = {}
    for _, rank in ipairs(player_ranks) do
        ranks[#ranks + 1] = rank
    end
    ranks[#ranks + 1] = dealer_rank
    ranks[#ranks + 1] = "5"
    local physical_ids = fixtures.ids(ranks)
    local player_ids = {}
    for index = 1, #player_ranks do
        player_ids[index] = physical_ids[index]
    end
    return {
        rules = preset or rules.defaults(),
        phase = "player_turn",
        bankroll_units = 1000,
        round = {
            active_hand = 1,
            hands = { hand.new(player_ids, 100) },
            dealer = {
                cards = { physical_ids[#player_ranks + 1], physical_ids[#player_ranks + 2] },
            },
        },
    }
end

local function expect_action(player_ranks, dealer_rank, expected, preset)
    local game = decision(player_ranks, dealer_rank, preset)
    local before = copy(game)
    local recommendation, reason = strategy.recommend(game)
    assert(recommendation, reason)
    test.equal(recommendation.action, expected)
    assert(actions.legal(game)[recommendation.action])
    assert(#recommendation.explanation > 0)
    test.same(game, before)
end

local function expect_profile_boundaries(preset)
    local hard_eleven = "hit"
    if preset.dealer_hits_soft_17 then
        hard_eleven = "double"
    end
    local soft_high_double = "stand"
    if preset.dealer_hits_soft_17 and preset.double_rule == "any_two" then
        soft_high_double = "double"
    end
    local soft_seventeen = "hit"
    if preset.double_rule == "any_two" then
        soft_seventeen = "double"
    end
    local hard_nine = "double"
    if preset.double_rule == "10_to_11" then
        hard_nine = "hit"
    end
    local small_pair = "hit"
    if preset.double_after_split then
        small_pair = "split"
    end
    expect_action({ "6", "5" }, "A", hard_eleven, preset)
    expect_action({ "A", "7" }, "2", soft_high_double, preset)
    expect_action({ "A", "8" }, "6", soft_high_double, preset)
    expect_action({ "A", "6" }, "6", soft_seventeen, preset)
    expect_action({ "5", "4" }, "3", hard_nine, preset)
    expect_action({ "2", "2" }, "2", small_pair, preset)
    expect_action({ "3", "3" }, "3", small_pair, preset)
    expect_action({ "4", "4" }, "5", small_pair, preset)
    expect_action({ "6", "6" }, "2", small_pair, preset)
end

function strategy_tests.run()
    local examples = {
        { { "5", "4" }, "2", "hit" },
        { { "5", "4" }, "3", "double" },
        { { "6", "4" }, "9", "double" },
        { { "6", "4" }, "10", "hit" },
        { { "6", "5" }, "10", "double" },
        { { "6", "5" }, "A", "hit" },
        { { "10", "2" }, "3", "hit" },
        { { "10", "2" }, "4", "stand" },
        { { "10", "6" }, "6", "stand" },
        { { "10", "6" }, "10", "hit" },
        { { "10", "7" }, "A", "stand" },
        { { "A", "2" }, "4", "hit" },
        { { "A", "2" }, "5", "double" },
        { { "A", "4" }, "4", "double" },
        { { "A", "6" }, "3", "double" },
        { { "A", "7" }, "2", "stand" },
        { { "A", "7" }, "3", "double" },
        { { "A", "7" }, "8", "stand" },
        { { "A", "7" }, "9", "hit" },
        { { "A", "7" }, "A", "hit" },
        { { "A", "8" }, "6", "stand" },
        { { "A", "A" }, "10", "split" },
        { { "8", "8" }, "A", "split" },
        { { "2", "2" }, "2", "split" },
        { { "3", "3" }, "3", "split" },
        { { "4", "4" }, "5", "split" },
        { { "4", "4" }, "4", "hit" },
        { { "5", "5" }, "6", "double" },
        { { "6", "6" }, "2", "split" },
        { { "7", "7" }, "7", "split" },
        { { "7", "7" }, "8", "hit" },
        { { "9", "9" }, "7", "stand" },
        { { "9", "9" }, "8", "split" },
        { { "9", "9" }, "A", "stand" },
        { { "K", "K" }, "6", "stand" },
        { { "K", "Q" }, "6", "stand" },
    }
    for _, example in ipairs(examples) do
        test.test(
            "S17 strategy " .. table.concat(example[1], "+") .. " against " .. example[2],
            function()
                expect_action(example[1], example[2], example[3])
            end
        )
    end

    test.test("H17 changes hard 11 versus Ace and soft 18/19 doubles", function()
        local preset = rules.defaults()
        preset.dealer_hits_soft_17 = true
        expect_action({ "6", "5" }, "A", "double", preset)
        expect_action({ "A", "7" }, "2", "double", preset)
        expect_action({ "A", "8" }, "6", "double", preset)
        expect_action({ "A", "9" }, "6", "stand", preset)
    end)
    test.test("turning DAS off changes low-pair splitting", function()
        local preset = rules.defaults()
        preset.double_after_split = false
        expect_action({ "2", "2" }, "3", "hit", preset)
        expect_action({ "3", "3" }, "3", "hit", preset)
        expect_action({ "3", "3" }, "4", "split", preset)
        expect_action({ "4", "4" }, "6", "hit", preset)
        expect_action({ "6", "6" }, "2", "hit", preset)
        expect_action({ "6", "6" }, "3", "split", preset)
    end)
    test.test(
        "restricted totals disable soft doubles and D10 disables hard nine doubles",
        function()
            local preset = rules.defaults()
            preset.double_rule = "9_to_11"
            expect_action({ "A", "6" }, "6", "hit", preset)
            expect_action({ "A", "7" }, "3", "stand", preset)
            expect_action({ "5", "4" }, "3", "double", preset)
            expect_action({ "4", "4" }, "5", "split", preset)
            preset.double_rule = "10_to_11"
            expect_action({ "5", "4" }, "3", "hit", preset)
            expect_action({ "6", "4" }, "6", "double", preset)
            expect_action({ "4", "4" }, "6", "split", preset)
        end
    )
    test.test("three-card hard eleven hits and three-card soft eighteen stands", function()
        expect_action({ "3", "3", "5" }, "6", "hit")
        expect_action({ "A", "3", "4" }, "6", "stand")
    end)
    test.test("no DAS blocks a double on a split hand and keeps the proper fallback", function()
        local preset = rules.defaults()
        preset.double_after_split = false
        local hard_eleven = decision({ "8", "3" }, "6", preset)
        hard_eleven.round.hands[1].from_split = true
        test.equal(assert(strategy.recommend(hard_eleven)).action, "hit")
        local soft_eighteen = decision({ "7", "A" }, "6", preset)
        soft_eighteen.round.hands[1].from_split = true
        test.equal(assert(strategy.recommend(soft_eighteen)).action, "stand")
    end)
    test.test("a blocked split plays eights as hard sixteen", function()
        local game = decision({ "8", "8" }, "10")
        game.bankroll_units = 0
        local recommendation = assert(strategy.recommend(game))
        test.equal(recommendation.action, "hit")
        test.equal(recommendation.category, "hard")
        assert(recommendation.explanation:find("Split is unavailable", 1, true))
        game.bankroll_units = 1000
        for _ = 1, 3 do
            game.round.hands[#game.round.hands + 1] = hand.new(fixtures.ids({ "2" }), 100)
        end
        test.equal(assert(strategy.recommend(game)).action, "hit")
    end)
    test.test("unfunded soft 18 and H17 soft 19 doubles fall back to stand", function()
        local preset = rules.defaults()
        preset.dealer_hits_soft_17 = true
        for _, player_ranks in ipairs({ { "A", "7" }, { "A", "8" } }) do
            local game = decision(player_ranks, "6", preset)
            game.bankroll_units = 0
            test.equal(assert(strategy.recommend(game)).action, "stand")
        end
    end)
    test.test("a locked split Ace has no player recommendation", function()
        local game = decision({ "A", "A" }, "6")
        game.round.hands[1].from_split = true
        game.round.hands[1].split_aces = true
        game.round.hands[1].status = "finished"
        assert(strategy.recommend(game) == nil)
    end)
    test.test("advice ignores the hole card and unknown shoe", function()
        local game = decision({ "10", "6" }, "10")
        local recommendation = assert(strategy.recommend(game))
        game.round.dealer.cards[2] = fixtures.ids({ "A" })[1]
        game.shoe = { order = { 999999 }, next_index = 1 }
        test.same(assert(strategy.recommend(game)), recommendation)
    end)
    test.test("a result and unsupported game rules never receive invented advice", function()
        local game = decision({ "10", "6" }, "10")
        game.phase = "round_result"
        assert(strategy.recommend(game) == nil)
        game.phase = "player_turn"
        game.rules.surrender = true
        assert(strategy.recommend(game) == nil)
    end)
    test.test(
        "all 72 gameplay configurations use their rules and legal strategy fallbacks",
        function()
            local configurations = 0
            for _, deck_count in ipairs({ 6, 8 }) do
                for _, hits_soft_17 in ipairs({ false, true }) do
                    for _, double_rule in ipairs({ "any_two", "9_to_11", "10_to_11" }) do
                        for _, double_after_split in ipairs({ false, true }) do
                            for _, penetration in ipairs({ 50, 67, 75 }) do
                                local preset = rules.defaults()
                                preset.deck_count = deck_count
                                preset.dealer_hits_soft_17 = hits_soft_17
                                preset.double_rule = double_rule
                                preset.double_after_split = double_after_split
                                preset.penetration_percent = penetration
                                assert(strategy.supported(preset))
                                expect_profile_boundaries(preset)
                                configurations = configurations + 1
                            end
                        end
                    end
                end
            end
            test.equal(configurations, 72)
        end
    )
    test.test(
        "a strategy sweep never suggests an illegal action or changes decision state",
        function()
            local presets = {}
            for _, deck_count in ipairs({ 6, 8 }) do
                for _, hits_soft_17 in ipairs({ false, true }) do
                    for _, double_rule in ipairs({ "any_two", "9_to_11", "10_to_11" }) do
                        for _, double_after_split in ipairs({ false, true }) do
                            local preset = rules.defaults()
                            preset.deck_count = deck_count
                            preset.dealer_hits_soft_17 = hits_soft_17
                            preset.double_rule = double_rule
                            preset.double_after_split = double_after_split
                            presets[#presets + 1] = preset
                        end
                    end
                end
            end
            local ranks = { "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K" }
            for _, preset in ipairs(presets) do
                for first_rank_index, first_rank in ipairs(ranks) do
                    for second_rank_index = first_rank_index, #ranks do
                        for _, dealer_rank in ipairs(ranks) do
                            local game = decision(
                                { first_rank, ranks[second_rank_index] },
                                dealer_rank,
                                preset
                            )
                            local before = copy(game)
                            local legal = actions.legal(game)
                            local recommendation = strategy.recommend(game)
                            if legal.hit then
                                assert(recommendation and legal[recommendation.action])
                                local category = recommendation.category
                                assert(
                                    category == "hard" or category == "soft" or category == "pair"
                                )
                                assert(#recommendation.explanation > 0)
                            else
                                assert(recommendation == nil)
                            end
                            test.same(game, before)
                        end
                    end
                end
            end
        end
    )
end

return strategy_tests
