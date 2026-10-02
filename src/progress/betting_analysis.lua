-- PURPOSE: Explain recent wager patterns using explicit, conservative thresholds.
-- CHANGE THIS MODULE WHEN: A documented pattern or its evidence threshold changes.
-- DO NOT PUT HERE: Strategy scoring, prediction, payouts or user interface code.

local check = require("src.check")
local analysis = {}

analysis.limits = {
    observations = 40,
    minimum_rounds = 5,
    minimum_controlled_rounds = 10,
    loss_increases = 3,
    doubling_steps = 3,
    doubling_low_percent = 180,
    doubling_high_percent = 220,
    exposure_percent = 10,
    exposure_occurrences = 2,
    erratic_transitions = 4,
    erratic_direction_changes = 3,
    large_change_percent = 50,
}

function analysis.valid_observation(value)
    local natural = type(value) == "table" and value.blackjacks == 1
    local wrong_natural_hand = natural
        and (value.outcome == "loss" or value.staked_units ~= value.bet_units)
    if
        not check.object(value, {
            "bet_units",
            "opening_bankroll_units",
            "net_units",
            "staked_units",
            "outcome",
        }, { "blackjacks" })
        or not check.integer(value.bet_units, 50, 1000)
        or value.bet_units % 50 ~= 0
        or not check.integer(value.opening_bankroll_units, value.bet_units)
        or not check.integer(value.staked_units, value.bet_units, value.bet_units * 8)
        or value.staked_units % 50 ~= 0
        or value.staked_units % value.bet_units ~= 0
        or value.staked_units > value.opening_bankroll_units
        or not check.integer(
            value.net_units,
            -value.staked_units,
            math.max(value.staked_units, value.bet_units * 1.5)
        )
        or value.net_units % 25 ~= 0
        or (not natural and value.net_units % value.bet_units ~= 0)
        or (value.blackjacks ~= nil and not check.integer(value.blackjacks, 0, 1))
        or wrong_natural_hand
        or (
            value.blackjacks == 1
            and value.outcome == "win"
            and value.net_units ~= value.bet_units * 1.5
        )
    then
        return false
    end
    -- A split round can contain both winning and losing hands. These labels
    -- describe the aggregate round net, not the existing per-hand game ledger.
    return (value.outcome == "win" and value.net_units > 0)
        or (value.outcome == "loss" and value.net_units < 0)
        or (value.outcome == "push" and value.net_units == 0)
end

local function scan(observations)
    local evidence = {
        after_loss = 0,
        after_win = 0,
        loss_increases = 0,
        win_increases = 0,
        doubling_run = 0,
        largest_doubling_run = 0,
        oversized = 0,
        large_changes = 0,
        direction_changes = 0,
        drawdown_increases = 0,
        total_changes = 0,
    }
    local previous_direction, net_units, peak_units = 0, 0, 0
    for index, current in ipairs(observations) do
        if
            current.staked_units
            > current.opening_bankroll_units / 100 * analysis.limits.exposure_percent
        then
            evidence.oversized = evidence.oversized + 1
        end
        local previous = observations[index - 1]
        if previous then
            local changed = current.bet_units - previous.bet_units
            if changed ~= 0 then
                evidence.total_changes = evidence.total_changes + 1
            end
            if changed > 0 and net_units < peak_units then
                evidence.drawdown_increases = evidence.drawdown_increases + 1
            end
            if previous.outcome == "loss" then
                evidence.after_loss = evidence.after_loss + 1
                if changed > 0 then
                    evidence.loss_increases = evidence.loss_increases + 1
                end
            elseif previous.outcome == "win" then
                evidence.after_win = evidence.after_win + 1
                if changed > 0 then
                    evidence.win_increases = evidence.win_increases + 1
                end
            end
            local lower_double = previous.bet_units * analysis.limits.doubling_low_percent
            local upper_double = previous.bet_units * analysis.limits.doubling_high_percent
            local doubling = previous.outcome == "loss"
                and current.bet_units * 100 >= lower_double
                and current.bet_units * 100 <= upper_double
            evidence.doubling_run = doubling and evidence.doubling_run + 1 or 0
            evidence.largest_doubling_run =
                math.max(evidence.largest_doubling_run, evidence.doubling_run)
            if
                math.abs(changed) * 100
                >= previous.bet_units * analysis.limits.large_change_percent
            then
                evidence.large_changes = evidence.large_changes + 1
                local direction = changed > 0 and 1 or -1
                if previous_direction ~= 0 and direction ~= previous_direction then
                    evidence.direction_changes = evidence.direction_changes + 1
                end
                previous_direction = direction
            end
        end
        net_units = net_units + current.net_units
        peak_units = math.max(peak_units, net_units)
    end
    return evidence
end

function analysis.analyze(observations)
    if not check.array(observations, analysis.limits.observations) then
        return nil, "Invalid recent wager history"
    end
    for _, observation in ipairs(observations) do
        if not analysis.valid_observation(observation) then
            return nil, "Invalid wager observation"
        end
    end
    local evidence = scan(observations)
    local report = { samples = #observations, evidence = evidence, patterns = {} }
    if #observations < analysis.limits.minimum_rounds then
        report.message = "Play at least 5 rounds before interpreting wager patterns."
        return report
    end
    local function add(kind, message)
        report.patterns[#report.patterns + 1] = { kind = kind, message = message }
    end
    if evidence.largest_doubling_run >= analysis.limits.doubling_steps then
        add(
            "martingale_like",
            "Three near-doubling steps followed losses. This resembles a Martingale; "
                .. "it does not make the next hand more likely to win."
        )
    elseif evidence.loss_increases >= analysis.limits.loss_increases then
        add(
            "loss_chasing",
            "Wagers increased after at least three losses. "
                .. "Increasing bets after losses can deepen a drawdown; "
                .. "the next hand remains uncertain."
        )
    end
    if
        evidence.drawdown_increases >= analysis.limits.loss_increases
        and evidence.loss_increases < analysis.limits.loss_increases
    then
        add(
            "drawdown_progression",
            "Wagers increased at least three times below this window's earlier peak. "
                .. "A bigger stake can deepen a drawdown even after an individual winning round."
        )
    end
    if evidence.oversized >= analysis.limits.exposure_occurrences then
        add(
            "oversized",
            "At least two rounds risked over 10% of the opening bankroll, "
                .. "including splits and doubles. Consider smaller exposure."
        )
    end
    if
        evidence.large_changes >= analysis.limits.erratic_transitions
        and evidence.direction_changes >= analysis.limits.erratic_direction_changes
    then
        add(
            "erratic",
            "Repeated large wager changes moved in both directions. "
                .. "This is variable sizing, not evidence of intent or a profitable system."
        )
    end
    if
        #observations >= analysis.limits.minimum_controlled_rounds
        and evidence.total_changes == 0
        and evidence.oversized == 0
    then
        add(
            "consistent",
            "The last 10 or more opening bets were equal with exposure at or below 10%. "
                .. "Consistent sizing does not guarantee a profit."
        )
    end
    report.message = #report.patterns == 0 and "No repeated pattern met the evidence threshold."
        or "Patterns describe recent wagers, not motives or future outcomes."
    return report
end

return analysis
