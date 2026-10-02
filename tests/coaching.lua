-- PURPOSE: Verify coaching evidence, conservative patterns and bounded sessions.
-- CHANGE THIS MODULE WHEN: Coach behavior or a regression changes.
-- DO NOT PUT HERE: Real saves, UI snapshots or expected strategy chart entries.

local test = require("tests.harness")
local copy = require("src.plain_copy")
local coach = require("src.progress.session_coach")
local betting = require("src.progress.betting_analysis")
local suite = {}

local function decide(state, category, action, expected, deviation)
    return assert(coach.decision(state, {
        category = category,
        action = action,
        expected = deviation or expected,
        basic_expected = expected,
        deviation_expected = deviation,
    }))
end

local function observation(bet, outcome, bankroll, stake)
    local staked = stake or bet
    return {
        bet_units = bet,
        opening_bankroll_units = bankroll or 10000,
        staked_units = staked,
        outcome = outcome,
        net_units = outcome == "win" and staked or outcome == "loss" and -staked or 0,
    }
end

local function has_pattern(report, kind)
    for _, pattern in ipairs(report.patterns) do
        if pattern.kind == kind then
            return true
        end
    end
    return false
end

local function pattern_fixture(bets, outcomes, bankroll, stakes)
    local observations = {}
    for index, bet in ipairs(bets) do
        observations[index] = observation(bet, outcomes[index], bankroll, stakes and stakes[index])
    end
    return assert(betting.analyze(observations))
end

function suite.run()
    -- ## OUTCOME IS NOT DECISION QUALITY

    test.test("new coach has no invented history or strategy judgments", function()
        local state = coach.new()
        assert(coach.validate(state))
        local report = assert(coach.report(state))
        assert(report.recommendation == nil and report.strategy.percent == nil)
        test.equal(#state.recent, 0)
        test.equal(#report.betting.patterns, 0)
    end)
    test.test("three losing rounds cannot turn correct decisions into mistakes", function()
        local state = coach.new()
        for _ = 1, 3 do
            state = decide(state, "hard", "hit", "hit")
            state = assert(coach.round(state, observation(100, "loss")))
        end
        local report = assert(coach.report(state))
        test.equal(report.strategy.percent, 100)
        test.equal(report.results.losses, 3)
        test.equal(report.results.net_units, -300)
    end)
    test.test("a winning result never awards correctness to the wrong strategy action", function()
        local state = decide(coach.new(), "soft", "stand", "hit")
        state = assert(coach.round(state, observation(100, "win")))
        local report = assert(coach.report(state))
        test.equal(report.decisions.soft.correct, 0)
        test.equal(report.strategy.percent, 0)
        test.equal(report.results.wins, 1)
    end)
    test.test("hard soft and pair decisions retain separate mistake counts", function()
        local state = decide(coach.new(), "hard", "stand", "hit")
        state = decide(state, "soft", "hit", "stand")
        state = decide(state, "pair", "hit", "split")
        for _, category in ipairs({ "hard", "soft", "pair" }) do
            test.equal(state.active.play[category].attempts, 1)
            test.equal(state.active.play[category].correct, 0)
        end
    end)
    test.test("missing a double records the hard decision and double weakness once", function()
        local state = decide(coach.new(), "hard", "hit", "double")
        test.equal(state.active.play.hard.attempts, 1)
        test.equal(state.active.play.double.attempts, 1)
        test.equal(state.active.play.double.correct, 0)
        test.equal(assert(coach.report(state)).strategy.attempts, 1)
    end)
    test.test("taking an incorrect double also belongs to double practice evidence", function()
        local state = decide(coach.new(), "soft", "double", "stand")
        test.equal(state.active.play.double.attempts, 1)
        test.equal(state.active.play.double.correct, 0)
    end)
    test.test("correct count deviation is not a basic-strategy mistake", function()
        local state = decide(coach.new(), "hard", "stand", "hit", "stand")
        test.equal(state.active.play.deviation.correct, 1)
        test.equal(state.active.play.hard.attempts, 0)
        assert(assert(coach.report(state)).strategy.percent == nil)
    end)
    test.test("ignoring an applicable deviation records only deviation inaccuracy", function()
        local state = decide(coach.new(), "hard", "hit", "hit", "stand")
        test.equal(state.active.play.deviation.attempts, 1)
        test.equal(state.active.play.deviation.correct, 0)
        test.equal(state.active.play.hard.attempts, 0)
    end)
    test.test("running and true count answers remain distinct from game decisions", function()
        local state = assert(coach.training(coach.new(), "running", true))
        state = assert(coach.training(state, "true_count", false))
        test.equal(state.active.practice.running.correct, 1)
        test.equal(state.active.practice.true_count.correct, 0)
        test.equal(state.active.play.hard.attempts, 0)
        test.equal(assert(coach.report(state)).counting.percent, 50)
    end)
    test.test("recording an answer never mutates the supplied state", function()
        local state = coach.new()
        local before = copy(state)
        decide(state, "hard", "hit", "hit")
        coach.training(state, "running", true)
        coach.round(state, observation(100, "push"))
        test.same(state, before)
    end)
    test.test("invalid or contradictory decision evidence is rejected", function()
        local state = coach.new()
        assert(coach.decision(state, {
            category = "hard",
            action = "hit",
            expected = "hit",
            correct = false,
        }) == nil)
        assert(
            coach.decision(state, { category = "invented", action = "hit", expected = "hit" })
                == nil
        )
        assert(coach.training(state, "running", "true") == nil)
        assert(coach.training(state, "strategy", true, "unknown") == nil)
        test.same(state, coach.new())
    end)

    -- ## CONSERVATIVE BETTING PATTERNS

    test.test("10 loss 20 loss 40 loss 80 win 10 resembles Martingale after five rounds", function()
        local report = pattern_fixture({ 100, 200, 400, 800, 100 }, {
            "loss",
            "loss",
            "loss",
            "win",
            "push",
        })
        assert(has_pattern(report, "martingale_like"))
        test.equal(report.evidence.largest_doubling_run, 3)
    end)
    test.test(
        "four rounds with three doubled losses are insufficient for a pattern label",
        function()
            local report = pattern_fixture(
                { 100, 200, 400, 800 },
                { "loss", "loss", "loss", "win" }
            )
            test.equal(#report.patterns, 0)
        end
    )
    test.test("occasional wager increases after two losses do not imply loss chasing", function()
        local report = pattern_fixture({ 100, 150, 200, 200, 100, 100 }, {
            "loss",
            "loss",
            "win",
            "win",
            "push",
            "loss",
        })
        assert(
            not has_pattern(report, "loss_chasing") and not has_pattern(report, "martingale_like")
        )
    end)
    test.test(
        "three non-doubling increases after losses are described without a Martingale claim",
        function()
            local report = pattern_fixture({ 100, 150, 200, 250, 100 }, {
                "loss",
                "loss",
                "loss",
                "win",
                "push",
            })
            assert(
                has_pattern(report, "loss_chasing") and not has_pattern(report, "martingale_like")
            )
        end
    )
    test.test("doubling after wins is not loss chasing", function()
        local report = pattern_fixture({ 100, 200, 400, 800, 100 }, {
            "win",
            "win",
            "win",
            "win",
            "push",
        })
        assert(
            not has_pattern(report, "martingale_like") and not has_pattern(report, "loss_chasing")
        )
        test.equal(report.evidence.win_increases, 3)
    end)
    test.test(
        "one oversized round is insufficient but two include split-double exposure",
        function()
            local bets, outcomes =
                { 100, 100, 100, 100, 100 }, { "push", "push", "push", "push", "push" }
            local one = pattern_fixture(bets, outcomes, 1000, { 200, 100, 100, 100, 100 })
            local two = pattern_fixture(bets, outcomes, 1000, { 200, 200, 100, 100, 100 })
            assert(not has_pattern(one, "oversized") and has_pattern(two, "oversized"))
        end
    )
    test.test("exactly ten percent exposure does not trigger over-ten-percent warning", function()
        local report = pattern_fixture({ 100, 100, 100, 100, 100 }, {
            "win",
            "loss",
            "push",
            "win",
            "loss",
        }, 1000)
        test.equal(report.evidence.oversized, 0)
    end)
    test.test(
        "repeated 50-percent-plus changes in opposite directions show variable sizing",
        function()
            local report = pattern_fixture({ 100, 300, 100, 300, 100 }, {
                "win",
                "win",
                "win",
                "win",
                "push",
            })
            assert(has_pattern(report, "erratic"))
            test.equal(report.evidence.direction_changes, 3)
        end
    )
    test.test("five stable bets are too early to praise consistent sizing", function()
        local report = pattern_fixture({ 100, 100, 100, 100, 100 }, {
            "win",
            "loss",
            "push",
            "win",
            "loss",
        })
        assert(not has_pattern(report, "consistent"))
    end)
    test.test("ten unchanged restrained bets show consistency even when all lose", function()
        local bets, outcomes = {}, {}
        for index = 1, 10 do
            bets[index], outcomes[index] = 100, "loss"
        end
        local report = pattern_fixture(bets, outcomes)
        assert(has_pattern(report, "consistent"))
    end)
    test.test("invalid wager amounts and contradictory results are rejected", function()
        local value = observation(100, "loss")
        value.net_units = 100
        assert(betting.analyze({ value }) == nil)
        value = observation(75, "push")
        assert(betting.analyze({ value }) == nil)
        value = observation(100, "push", 100, 200)
        assert(betting.analyze({ value }) == nil)
        value = observation(100, "loss")
        value.blackjacks = 1
        assert(betting.analyze({ value }) == nil)
    end)

    test.test(
        "natural Blackjack records its exact 3-to-2 net without an invented decision",
        function()
            local value = observation(100, "win")
            value.net_units, value.blackjacks = 150, 1
            local state = assert(coach.round(coach.new(), value))
            test.equal(state.active.results.blackjacks, 1)
            test.equal(state.active.results.net_units, 150)
            test.equal(state.active.results.biggest_win_units, 150)
            test.equal(state.active.play.hard.attempts, 0)
        end
    )

    -- ## PRACTICE PRIORITIES AND SESSION HISTORY

    test.test("nine wrong soft answers cannot yet select a strong practice priority", function()
        local state = coach.new()
        for _ = 1, 9 do
            state = assert(coach.training(state, "strategy", false, "soft"))
        end
        assert(assert(coach.report(state)).recommendation == nil)
    end)
    test.test(
        "ten soft answers select a twenty-drill weakness rather than a random message",
        function()
            local state = coach.new()
            for index = 1, 10 do
                state = assert(coach.training(state, "strategy", index <= 7, "soft"))
            end
            local recommendation = assert(coach.report(state)).recommendation
            test.equal(recommendation.category, "soft")
            test.equal(recommendation.accuracy, 70)
            test.equal(recommendation.drills, 20)
            test.equal(recommendation.source, "current session")
        end
    )
    test.test("five true-count answers meet their separate lower evidence threshold", function()
        local state = coach.new()
        for index = 1, 5 do
            state = assert(coach.training(state, "true_count", index <= 3))
        end
        local recommendation = assert(coach.report(state)).recommendation
        test.equal(recommendation.kind, "true_count")
        test.equal(recommendation.accuracy, 60)
    end)
    test.test("lowest accuracy wins with deterministic soft-before-pair tie breaking", function()
        local state = coach.new()
        for _ = 1, 10 do
            state = assert(coach.training(state, "strategy", false, "pair"))
            state = assert(coach.training(state, "strategy", false, "soft"))
            state = assert(coach.training(state, "strategy", true, "hard"))
        end
        test.equal(assert(coach.report(state)).recommendation.category, "soft")
    end)
    test.test("a perfect sample never produces invented weaknesses", function()
        local state = coach.new()
        for _ = 1, 10 do
            state = decide(state, "hard", "hit", "hit")
        end
        assert(assert(coach.report(state)).recommendation == nil)
    end)
    test.test("new session retains evidence and offers a lifetime fallback", function()
        local state = coach.new()
        for _ = 1, 10 do
            state = decide(state, "pair", "hit", "split")
        end
        state = assert(coach.close_session(state))
        test.equal(state.active.id, 2)
        test.equal(state.active.play.pair.attempts, 0)
        test.equal(state.lifetime.play.pair.attempts, 10)
        test.equal(assert(coach.report(state)).recommendation.source, "recorded lifetime")
    end)
    test.test("closing an empty session does not consume a history slot", function()
        test.same(assert(coach.close_session(coach.new())), coach.new())
    end)
    test.test("twenty completed sessions retain exactly the most recent fifteen", function()
        local state = coach.new()
        for _ = 1, 20 do
            state = assert(coach.training(state, "running", false))
            state = assert(coach.close_session(state))
        end
        test.equal(#state.recent, 15)
        test.equal(state.recent[1].id, 6)
        test.equal(state.recent[15].id, 20)
        test.equal(state.lifetime.practice.running.attempts, 20)
        assert(coach.validate(state))
    end)
    test.test("forty-three rounds retain only forty observations and all result totals", function()
        local state = coach.new()
        for _ = 1, 43 do
            state = assert(coach.round(state, observation(100, "loss")))
        end
        test.equal(#state.wagers, 40)
        test.equal(state.active.results.rounds, 43)
        test.equal(state.lifetime.results.net_units, -4300)
        state = assert(coach.close_session(state))
        test.equal(#state.wagers, 0)
        test.equal(state.recent[1].results.rounds, 43)
    end)
    test.test(
        "drawdown is measured from recorded peak and excludes arbitrary outcome coaching",
        function()
            local state = assert(coach.round(coach.new(), observation(100, "win")))
            state = assert(coach.round(state, observation(100, "loss")))
            state = assert(coach.round(state, observation(200, "loss")))
            test.equal(state.active.results.peak_net_units, 100)
            test.equal(state.active.results.drawdown_units, 300)
            test.equal(state.active.results.max_drawdown_units, 300)
            test.equal(state.active.results.loss_streak, 2)
            test.equal(state.active.results.biggest_loss_units, 200)
        end
    )
    test.test("fractional scores unknown fields and excess histories fail validation", function()
        local state = coach.new()
        state.active.play.soft.attempts = 0.5
        assert(not coach.validate(state))
        state = coach.new()
        state.unexpected = true
        assert(not coach.validate(state))
        state = coach.new()
        for index = 1, 16 do
            state.recent[index] = copy(state.active)
        end
        assert(not coach.validate(state))
    end)
    test.test("bounded counter overflow preserves every existing score", function()
        local state = coach.new()
        state.lifetime.play.hard = { attempts = 1000000000000, correct = 1000000000000 }
        state.active.play.hard = copy(state.lifetime.play.hard)
        assert(coach.validate(state))
        local before = copy(state)
        assert(
            coach.decision(state, { category = "hard", action = "hit", expected = "hit" }) == nil
        )
        test.same(state, before)
    end)
    test.test("identical evidence produces identical coaching and history reports", function()
        local state = coach.new()
        for _ = 1, 10 do
            state = assert(coach.training(state, "strategy", false, "soft"))
        end
        test.same(assert(coach.report(state)), assert(coach.report(copy(state))))
    end)
    test.test(
        "completed session percentages show recorded improvement without changing results",
        function()
            local state = coach.new()
            for _, correct_answers in ipairs({ 78, 84, 91 }) do
                for index = 1, 100 do
                    state =
                        assert(coach.training(state, "strategy", index <= correct_answers, "hard"))
                end
                state = assert(coach.close_session(state))
            end
            local history = assert(coach.report(state)).history
            test.equal(history[1].strategy.percent, 78)
            test.equal(history[2].strategy.percent, 84)
            test.equal(history[3].strategy.percent, 91)
            test.equal(state.lifetime.results.rounds, 0)
        end
    )
    test.test(
        "lifetime and recent counters cannot disagree even when individually bounded",
        function()
            local state = assert(coach.training(coach.new(), "running", true))
            state = assert(coach.close_session(state))
            local malformed = copy(state)
            malformed.lifetime.practice.running.attempts = 2
            assert(not coach.validate(malformed))
            malformed = copy(state)
            malformed.recent[1].id = 2
            assert(not coach.validate(malformed))
        end
    )
    test.test(
        "drawdown progression can continue after wins without guessing loss-chasing intent",
        function()
            local report = pattern_fixture({ 800, 100, 200, 300, 400 }, {
                "loss",
                "win",
                "win",
                "win",
                "push",
            })
            assert(has_pattern(report, "drawdown_progression"))
            assert(not has_pattern(report, "loss_chasing"))
            test.equal(report.evidence.drawdown_increases, 3)
        end
    )
    test.test("retained wagers agree with complete current round results", function()
        local state = assert(coach.round(coach.new(), observation(100, "loss")))
        state.wagers[1] = observation(100, "win")
        assert(not coach.validate(state))
    end)
    test.test("truncated wager window cannot invent more wins than the active session", function()
        local state = coach.new()
        for _ = 1, 41 do
            state = assert(coach.round(state, observation(100, "loss")))
        end
        state.wagers[1] = observation(100, "win")
        assert(not coach.validate(state))
    end)
    test.test("completed history cannot use session zero or skip retained sessions", function()
        local state =
            assert(coach.close_session(assert(coach.training(coach.new(), "running", true))))
        state.active.id, state.recent[1].id = 1, 0
        assert(not coach.validate(state))
        state = coach.new()
        state.active.id = 17
        assert(not coach.validate(state))
    end)
    test.test("retained mistakes fit lifetime mistakes after old history expires", function()
        local state = coach.new()
        for _ = 1, 17 do
            state = assert(coach.training(state, "running", true))
            state = assert(coach.close_session(state))
        end
        for _, completed in ipairs(state.recent) do
            completed.practice.running.correct = 0
        end
        assert(not coach.validate(state))
    end)
    test.test("double correct and mistake subsets fit their base categories", function()
        local state = decide(coach.new(), "hard", "hit", "double")
        state.active.play.double.correct, state.lifetime.play.double.correct = 1, 1
        assert(not coach.validate(state))
        state = decide(coach.new(), "hard", "double", "double")
        state.active.play.double.correct, state.lifetime.play.double.correct = 0, 0
        assert(not coach.validate(state))
    end)
    test.test("zero-round summaries cannot carry phantom wagers", function()
        local state = coach.new()
        state.active.results.staked_units, state.lifetime.results.staked_units = 100, 100
        assert(not coach.validate(state))
    end)
    test.test("ordinary stakes and payouts remain multiples of the real opening bet", function()
        local value = observation(100, "win", 10000, 150)
        assert(not betting.valid_observation(value))
        value = observation(100, "win")
        value.net_units = 125
        assert(not betting.valid_observation(value))
    end)
    test.test("twenty double drills improve double evidence and count once overall", function()
        local state = coach.new()
        for _ = 1, 10 do
            state = decide(state, "hard", "hit", "double")
        end
        for _ = 1, 20 do
            state = assert(coach.training(state, "strategy", true, "double"))
        end
        local report = assert(coach.report(state))
        test.equal(report.practice.double.attempts, 20)
        test.equal(report.practice.double.correct, 20)
        test.equal(report.strategy.attempts, 30)
        test.equal(report.strategy.correct, 20)
        test.equal(report.strategy.percent, 67)
        test.equal(state.active.play.double.attempts, 10)
    end)
    test.test(
        "retained result peaks and omitted net remain possible in lifetime history",
        function()
            local state = assert(coach.round(coach.new(), observation(100, "win")))
            state = assert(coach.close_session(state))
            state.lifetime.results.biggest_win_units = 50
            assert(not coach.validate(state))
            state = coach.new()
            for _ = 1, 17 do
                state = assert(coach.round(state, observation(100, "loss")))
                state = assert(coach.close_session(state))
            end
            state.lifetime.results.net_units = -100
            state.lifetime.results.drawdown_units = 100
            assert(not coach.validate(state))
        end
    )
    test.test(
        "retained forty-round streaks cannot exceed the whole session's best streak",
        function()
            local state = assert(coach.round(coach.new(), observation(100, "push")))
            for _ = 1, 20 do
                state = assert(coach.round(state, observation(100, "win")))
            end
            for _ = 1, 20 do
                state = assert(coach.round(state, observation(100, "loss")))
            end
            state.active.results.best_win_streak, state.lifetime.results.best_win_streak = 1, 1
            assert(not coach.validate(state))
        end
    )
end

return suite
