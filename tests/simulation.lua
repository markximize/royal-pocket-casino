-- PURPOSE: Sweep deterministic legal play and exact accounting invariants.
-- CHANGE THIS MODULE WHEN: Approved policies, seed corpus or invariants change.
-- DO NOT PUT HERE: Strategy advice, house-edge claims or handset frame-loop work.

local test = require("tests.harness")
local round = require("src.blackjack.round")
local rules = require("src.blackjack.rules")
local seeded = require("src.random.seeded")
local hand = require("src.blackjack.hand")
local actions = require("src.blackjack.player_actions")
local validation = require("src.persistence.game_validation")
local statistics = require("src.progress.statistics")
local simulation = {}

function simulation.run()
    test.test("10000 rounds across ten seeds preserve cards, phases and exact chips", function()
        local completed, visited_splits, visited_doubles = 0, 0, 0
        for seed = 1, 10 do
            local preset = rules.defaults()
            preset.deck_count = seed % 2 == 0 and 8 or 6
            preset.dealer_hits_soft_17 = seed % 3 == 0
            preset.double_after_split = seed % 4 ~= 0
            preset.double_rule = ({ "any_two", "9_to_11", "10_to_11" })[seed % 3 + 1]
            preset.penetration_percent = ({ 50, 67, 75 })[seed % 3 + 1]
            local game = round.new(preset, seeded.new(seed), seeded.next_integer)
            local policy_rng, counters = seeded.new(1000 + seed), statistics.new()
            local function apply(kind, fields)
                local candidate, effect =
                    round.apply(game, round.command(game, kind, fields), seeded.next_integer)
                assert(candidate, effect)
                game = candidate
                if effect.completed_round then
                    statistics.record(counters, effect.completed_round)
                end
                if effect.grant_units then
                    counters.chip_grants_units = counters.chip_grants_units + effect.grant_units
                end
                local valid, reason = validation.validate(game)
                assert(valid, "Seed " .. seed .. ": " .. tostring(reason))
            end
            for _ = 1, 1000 do
                if game.bankroll_units < 50 then
                    apply("refill")
                end
                apply("deal", { bet_units = 50 })
                local decisions = 0
                while game.phase == "player_turn" do
                    decisions = decisions + 1
                    assert(decisions <= 512, "No terminating decision path")
                    local current = game.round.hands[game.round.active_hand]
                    local legal = actions.legal(game)
                    local kind = hand.evaluate(current.cards, current.from_split).total >= 17
                            and "stand"
                        or "hit"
                    if seed > 5 then
                        if legal.split then
                            kind = "split"
                            visited_splits = visited_splits + 1
                        elseif legal.double and seeded.next_integer(policy_rng, 1, 3) == 1 then
                            kind = "double"
                            visited_doubles = visited_doubles + 1
                        elseif seeded.next_integer(policy_rng, 1, 4) == 1 then
                            kind = "stand"
                        end
                    end
                    apply(kind)
                end
                local result = game.round.result
                if not result.void then
                    local stakes, returns = 0, 0
                    for _, row in ipairs(result.hands) do
                        stakes = stakes + row.stake_units
                        local expected_return = 0
                        if row.outcome == "blackjack" then
                            expected_return = row.stake_units * 5 / 2
                        elseif row.outcome == "win" then
                            expected_return = row.stake_units * 2
                        elseif row.outcome == "push" then
                            expected_return = row.stake_units
                        end
                        test.equal(row.return_units, expected_return)
                        returns = returns + row.return_units
                    end
                    test.equal(
                        game.bankroll_units,
                        game.round.opening_bankroll_units - stakes + returns
                    )
                end
                completed = completed + 1
                test.equal(
                    game.bankroll_units,
                    10000 + counters.chip_grants_units + counters.main_net_units
                )
                apply("next_round")
            end
        end
        test.equal(completed, 10000)
        assert(visited_splits > 0 and visited_doubles > 0)
        print(
            string.format(
                "Simulation: %d rounds, %d splits, %d doubles; zero invariant violations",
                completed,
                visited_splits,
                visited_doubles
            )
        )
    end)
end

return simulation
