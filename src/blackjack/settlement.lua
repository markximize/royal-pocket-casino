-- PURPOSE: Compare finished hands and produce explicit stake/return summaries.
-- CHANGE THIS MODULE WHEN: Outcome precedence or exact payouts change.
-- DO NOT PUT HERE: Dealer draws, storage, animations or statistics mutation.

local hand = require("src.blackjack.hand")
local chips = require("src.blackjack.chips")
local settlement = {}

local function outcome(player, dealer)
    if dealer.natural then
        return player.natural and "push" or "loss"
    elseif player.natural then
        return "blackjack"
    elseif player.bust then
        return "loss"
    elseif dealer.bust or player.total > dealer.total then
        return "win"
    elseif player.total == dealer.total then
        return "push"
    end
    return "loss"
end

function settlement.summarize(current_round)
    local dealer = hand.evaluate(current_round.dealer.cards, false)
    local summary = { hands = {}, staked_units = 0, returned_units = 0, void = false }
    for _, player_hand in ipairs(current_round.hands) do
        local evaluated = hand.evaluate(player_hand.cards, player_hand.from_split)
        local result = outcome(evaluated, dealer)
        local returned_units = chips.return_units(player_hand.stake_units, result)
        summary.hands[#summary.hands + 1] = {
            outcome = result,
            stake_units = player_hand.stake_units,
            return_units = returned_units,
            natural = evaluated.natural,
            bust = evaluated.bust,
        }
        summary.staked_units = chips.add(summary.staked_units, player_hand.stake_units)
        summary.returned_units = chips.add(summary.returned_units, returned_units)
    end
    summary.net_units = summary.returned_units - summary.staked_units
    return summary
end

return settlement
