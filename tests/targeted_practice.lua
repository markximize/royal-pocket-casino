-- PURPOSE: Check targeted real-engine questions and clearly supplied count exercises.
-- CHANGE THIS MODULE WHEN: A practice filter or checkpoint category changes.
-- DO NOT PUT HERE: Normal-game mutations, synthetic settlements or hidden-card answers.

local test = require("tests.harness")
local practice = require("src.training.practice")
local rules = require("src.blackjack.rules")
local basic = require("src.training.basic_strategy")
local deviations = require("src.training.deviations")
local hi_lo = require("src.training.hi_lo")
local seeded = require("src.random.seeded")
local round = require("src.blackjack.round")
local copy = require("src.plain_copy")
local targeted_tests = {}

local function settings()
    return {
        level = "beginner",
        assistance = true,
        pace = "comfortable",
        deck_step = 0.5,
        rounding = "truncate",
    }
end

local function answer_recommended(current)
    local answer = assert(practice.answer(current, current.recommendation.action))
    assert(answer.correct)
    practice.accept(current, answer)
    return answer
end

function targeted_tests.run()
    for _, target in ipairs({ "hard", "soft", "pair", "double" }) do
        test.test(
            "twenty " .. target .. " drills contain only matching real legal decisions",
            function()
                local current = practice.new("strategy", rules.defaults(), 7183, settings(), target)
                test.equal(current.target, target)
                test.equal(current.goal, 20)
                for drill = 1, 20 do
                    assert(current.recommendation, current.error)
                    test.equal(current.game.phase, "player_turn")
                    local recommendation = assert(basic.recommend(current.game))
                    if target == "double" then
                        test.equal(recommendation.action, "double")
                    else
                        test.equal(recommendation.category, target)
                    end
                    assert(practice.table_view(current).legal[current.recommendation.action])
                    local answer = answer_recommended(current)
                    test.equal(answer.category, recommendation.category)
                    test.equal(current.drills_done, drill)
                    practice.next(current)
                end
            end
        )
    end
    test.test("mixed practice keeps the existing unfiltered first legal decision", function()
        local first = practice.new("strategy", rules.defaults(), 71, settings())
        local second = practice.new("strategy", rules.defaults(), 71, settings(), "mixed")
        test.same(first, second)
        test.equal(first.goal, nil)
    end)
    test.test("targeted practice follows the configured H17 and restricted-double rules", function()
        local preset = rules.defaults()
        preset.dealer_hits_soft_17 = true
        preset.double_rule = "10_to_11"
        preset.double_after_split = false
        local before = copy(preset)
        local current = practice.new("strategy", preset, 543, settings(), "double")
        for _ = 1, 10 do
            assert(current.recommendation, current.error)
            test.same(current.game.rules, preset)
            test.equal(current.recommendation.action, "double")
            local visible = practice.table_view(current)
            test.equal(visible.hands[visible.active_hand].total >= 10, true)
            test.equal(visible.hands[visible.active_hand].total <= 11, true)
            answer_recommended(current)
            practice.next(current)
        end
        test.same(preset, before)
    end)
    test.test("deviation practice alternates at-index Stand with below-index basic Hit", function()
        local current = practice.new("strategy", rules.defaults(), 81, settings(), "deviation")
        for drill = 1, 20 do
            local advice = assert(current.recommendation, current.error)
            test.equal(advice.category, "deviation")
            test.equal(advice.basic_action, "hit")
            test.equal(current.practice_counts.decks, 4)
            test.equal(current.practice_counts.exposed, 104)
            test.equal(current.practice_counts.running, current.practice_counts.true_count * 4)
            test.equal(hi_lo.estimate_decks(6, current.practice_counts.exposed), 4)
            local ordinary = assert(basic.recommend(current.game))
            test.equal(ordinary.action, "hit")
            local adjusted = deviations.recommend(current.game, current.practice_counts, ordinary)
            if drill % 2 == 1 then
                test.equal(advice.action, "stand")
                test.equal(current.practice_counts.true_count, advice.deviation_index)
                test.equal(assert(adjusted).action, "stand")
            else
                test.equal(advice.action, "hit")
                test.equal(current.practice_counts.true_count, advice.deviation_index - 1)
                test.equal(adjusted, nil)
            end
            assert(advice.explanation:find("Given TC", 1, true))
            local before_shoe = copy(current.game.shoe)
            local answer = answer_recommended(current)
            test.equal(answer.deviation_index, advice.deviation_index)
            test.same(current.game.shoe, before_shoe, "Answer does not fabricate past exposures")
            practice.next(current)
        end
    end)
    test.test(
        "unsupported deviation rules return a visible reason without generating a substitute",
        function()
            local preset = rules.defaults()
            preset.dealer_hits_soft_17 = true
            local current = practice.new("strategy", preset, 1, settings(), "deviation")
            assert(current.error:find("six decks and S17", 1, true))
            test.equal(current.recommendation, nil)
            test.equal(current.game.phase, "betting")
            assert(not practice.answer(current, "stand"))
        end
    )
    for _, target in ipairs({ "running", "true_count" }) do
        test.test(
            target .. " practice checks only its selected count with assistance hidden",
            function()
                local preferences = settings()
                preferences.pace = "fast"
                local before = copy(preferences)
                local current = practice.new("counting", rules.defaults(), 5, preferences, target)
                test.equal(current.settings.level, "advanced")
                test.equal(current.settings.assistance, false)
                test.equal(current.settings.pace, "fast")
                test.equal(current.goal, 20)
                local before_wrong_check = copy(current)
                local other_kind = target == "running" and "true_count" or "running"
                test.equal(practice.check(current, other_kind), false)
                test.same(current, before_wrong_check)
                for checkpoint = 1, 3 do
                    for _ = 1, 10 do
                        practice.update(current, 0.7)
                    end
                    test.equal(current.phase, "cards", "Checkpoint card is still visible")
                    test.equal(current.observer.exposed_count, checkpoint * 10)
                    practice.update(current, 0.7)
                    test.equal(current.phase, "answer")
                    test.equal(current.answer_kind, target)
                    local counts = practice.counts(current)
                    local expected = target == "running" and counts.running or counts.true_count
                    local answer = assert(practice.answer(current, expected))
                    assert(answer.correct)
                    test.equal(answer.kind, target)
                    practice.accept(current, answer)
                    practice.next(current)
                end
                test.same(preferences, before)
            end
        )
    end
    test.test("acknowledging one targeted answer twice counts one drill", function()
        local current = practice.new("strategy", rules.defaults(), 8, settings(), "soft")
        local answer = assert(practice.answer(current, current.recommendation.action))
        practice.accept(current, answer)
        practice.accept(current, answer)
        test.equal(current.drills_done, 1)
    end)
    test.test("targeted drills do not alter the caller's game rules RNG or preferences", function()
        local normal = round.new(rules.defaults(), seeded.new(81), seeded.next_integer)
        local preferences = settings()
        local normal_before, settings_before = copy(normal), copy(preferences)
        local current = practice.new("strategy", normal.rules, 811, preferences, "soft")
        for _ = 1, 5 do
            answer_recommended(current)
            practice.next(current)
        end
        test.same(normal, normal_before)
        test.same(preferences, settings_before)
    end)
    test.test("an unknown target is unavailable rather than silently mixed", function()
        local strategy_current =
            practice.new("strategy", rules.defaults(), 1, settings(), "unknown")
        assert(strategy_current.error)
        test.equal(strategy_current.recommendation, nil)
        local counting_current =
            practice.new("counting", rules.defaults(), 1, settings(), "unknown")
        assert(counting_current.error)
        test.equal(counting_current.shoe, nil)
    end)
    test.test("identical seeds and targets produce identical targeted questions", function()
        local first = practice.new("strategy", rules.defaults(), 18, settings(), "deviation")
        local second = practice.new("strategy", rules.defaults(), 18, settings(), "deviation")
        for _ = 1, 5 do
            test.same(first, second)
            answer_recommended(first)
            answer_recommended(second)
            practice.next(first)
            practice.next(second)
        end
        test.same(first, second)
    end)
end

return targeted_tests
