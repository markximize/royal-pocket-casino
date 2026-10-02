-- PURPOSE: Recommend a legal, total-dependent play under the supported game rules.
-- CHANGE THIS MODULE WHEN: Documented strategy advice or game rule support changes.
-- DO NOT PUT HERE: Card dealing, bankroll changes, count deviations or UI.
-- Sources, fallback assumptions and verification limits are in docs/TRAINING_RULES.md.

local cards = require("src.blackjack.cards")
local hand = require("src.blackjack.hand")
local rules = require("src.blackjack.rules")
local player_actions = require("src.blackjack.player_actions")
local basic_strategy = {}

-- ## SUPPORTED PROFILE BOUNDARY

function basic_strategy.supported(preset)
    return rules.validate(preset)
end

local function between(value, minimum, maximum)
    return value >= minimum and value <= maximum
end

-- ## PAIRS BEFORE TOTALS

local function split_preferred(rank, dealer_value, double_after_split)
    if rank == 1 or rank == 8 then
        return true
    elseif rank == 2 or rank == 3 then
        local lowest_upcard = double_after_split and 2 or 4
        return between(dealer_value, lowest_upcard, 7)
    elseif rank == 4 then
        return double_after_split and between(dealer_value, 5, 6)
    elseif rank == 6 then
        local lowest_upcard = double_after_split and 2 or 3
        return between(dealer_value, lowest_upcard, 6)
    elseif rank == 7 then
        return between(dealer_value, 2, 7)
    elseif rank == 9 then
        return between(dealer_value, 2, 6) or dealer_value == 8 or dealer_value == 9
    end
    return false
end

-- These functions return both the preferred play and its ordinary fallback.
-- A three-card hand, table restriction or unfunded extra stake can block Double.
local function hard_choice(total, dealer_value, hits_soft_17)
    local fallback = "hit"
    if total >= 17 then
        fallback = "stand"
    elseif total >= 13 and between(dealer_value, 2, 6) then
        fallback = "stand"
    elseif total == 12 and between(dealer_value, 4, 6) then
        fallback = "stand"
    end
    if total == 9 and between(dealer_value, 3, 6) then
        return "double", fallback
    elseif total == 10 and between(dealer_value, 2, 9) then
        return "double", fallback
    elseif total == 11 and (dealer_value ~= 1 or hits_soft_17) then
        return "double", fallback
    end
    return fallback, fallback
end

local function soft_choice(total, dealer_value, hits_soft_17)
    if total >= 19 then
        if total == 19 and dealer_value == 6 and hits_soft_17 then
            return "double", "stand"
        end
        return "stand", "stand"
    elseif total == 18 then
        local lowest_double = hits_soft_17 and 2 or 3
        if between(dealer_value, lowest_double, 6) then
            return "double", "stand"
        elseif dealer_value == 1 or dealer_value >= 9 then
            return "hit", "hit"
        end
        return "stand", "stand"
    end
    local lowest_double = 5
    if total == 15 or total == 16 then
        lowest_double = 4
    elseif total == 17 then
        lowest_double = 3
    end
    if total >= 13 and between(dealer_value, lowest_double, 6) then
        return "double", "hit"
    end
    return "hit", "hit"
end

local function total_reason(action, evaluated)
    if action == "double" then
        return "This starting total favors one extra stake and exactly one card."
    elseif action == "hit" then
        if evaluated.soft then
            return "The Ace can become 1 while you improve this total."
        elseif evaluated.total <= 11 then
            return "One additional card cannot bust this hand."
        end
        return "This total is weak against the upcard; draw despite the bust risk."
    elseif evaluated.soft then
        return "Keep this useful total instead of risking a weaker hand."
    elseif evaluated.total >= 17 then
        return "Keep a strong total instead of risking a bust."
    end
    return "Let the dealer play from a weak upcard instead of risking a bust."
end

-- ## READ-ONLY ADVICE

function basic_strategy.recommend(game)
    local supported, reason = basic_strategy.supported(game.rules)
    if not supported then
        return nil, reason
    end
    local legal = player_actions.legal(game)
    if not legal.hit then
        return nil, "There is no active player decision."
    end

    local current = game.round.hands[game.round.active_hand]
    local evaluated = hand.evaluate(current.cards, current.from_split)
    local upcard = game.round.dealer.cards[1]
    local dealer_value = cards.value(upcard)
    local dealer_label = cards.rank_names[cards.rank(upcard)]
    local matching_pair = #current.cards == 2
        and cards.rank(current.cards[1]) == cards.rank(current.cards[2])
    local pair_wanted = matching_pair
        and split_preferred(
            cards.rank(current.cards[1]),
            dealer_value,
            game.rules.double_after_split
        )
    if pair_wanted and legal.split then
        local pair_rank = cards.rank(current.cards[1])
        local explanation = "This pair is preferred as two hands under these rules."
        if pair_rank == 8 then
            explanation = "Separate hard 16 into two hands beginning with 8."
        elseif pair_rank == 1 then
            explanation = "Give each Ace its own additional card."
        end
        return {
            action = "split",
            category = "pair",
            explanation = explanation,
        }
    end

    local category = evaluated.soft and "soft" or "hard"
    local preferred, fallback
    if evaluated.soft then
        preferred, fallback =
            soft_choice(evaluated.total, dealer_value, game.rules.dealer_hits_soft_17)
    else
        preferred, fallback =
            hard_choice(evaluated.total, dealer_value, game.rules.dealer_hits_soft_17)
    end
    local chosen = preferred
    local explanation_prefix = ""
    if preferred == "double" and not legal.double then
        chosen = fallback
        explanation_prefix = "Double is unavailable; "
    elseif pair_wanted and not legal.split then
        explanation_prefix = "Split is unavailable; "
    end
    local action_label = chosen:sub(1, 1):upper() .. chosen:sub(2)
    return {
        action = chosen,
        category = category,
        explanation = explanation_prefix
            .. action_label
            .. " "
            .. category
            .. " "
            .. evaluated.total
            .. " against "
            .. dealer_label
            .. ". "
            .. total_reason(chosen, evaluated),
    }
end

return basic_strategy
