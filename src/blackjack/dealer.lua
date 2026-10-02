-- PURPOSE: Reveal the hole and apply S17/H17 only when comparisons need draws.
-- CHANGE THIS MODULE WHEN: Dealer draw/stop policy changes.
-- DO NOT PUT HERE: Payouts, player commands, save writes or cosmetic draws.

local hand = require("src.blackjack.hand")
local shoe = require("src.blackjack.shoe")
local dealer = {}

function dealer.should_draw(current_round, preset)
    local comparison_needed = false
    for _, player_hand in ipairs(current_round.hands) do
        local evaluated = hand.evaluate(player_hand.cards, player_hand.from_split)
        if not evaluated.bust and not evaluated.natural then
            comparison_needed = true
        end
    end
    local evaluated = hand.evaluate(current_round.dealer.cards, false)
    return comparison_needed
        and (
            evaluated.total < 17
            or (evaluated.total == 17 and evaluated.soft and preset.dealer_hits_soft_17)
        )
end

function dealer.play(game)
    local current_round = game.round
    current_round.dealer.revealed = true
    while dealer.should_draw(current_round, game.rules) do
        local card_id = shoe.draw(game.shoe)
        if not card_id then
            return false
        end
        table.insert(current_round.dealer.cards, card_id)
    end
    return true
end

return dealer
