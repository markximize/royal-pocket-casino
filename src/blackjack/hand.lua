-- PURPOSE: Evaluate aces, totals and original-hand Blackjack eligibility.
-- CHANGE THIS MODULE WHEN: Hand evaluation or natural eligibility changes.
-- DO NOT PUT HERE: Dealing, wagers, presentation or strategy advice.

local cards = require("src.blackjack.cards")
local hand = {}

function hand.evaluate(card_ids, from_split)
    local total, ace_count = 0, 0
    for _, card_id in ipairs(card_ids) do
        total = total + cards.value(card_id)
        if cards.rank(card_id) == 1 then
            ace_count = ace_count + 1
        end
    end
    local soft = ace_count > 0 and total + 10 <= 21
    if soft then
        total = total + 10
    end
    return {
        total = total,
        soft = soft,
        bust = total > 21,
        natural = not from_split and #card_ids == 2 and total == 21,
    }
end

function hand.new(card_ids, stake_units, from_split, split_aces, status)
    return {
        cards = card_ids,
        stake_units = stake_units,
        from_split = from_split or false,
        split_aces = split_aces or false,
        doubled = false,
        status = status or "playing",
    }
end

return hand
