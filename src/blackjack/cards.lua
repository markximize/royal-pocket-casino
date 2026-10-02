-- PURPOSE: Define a canonical physical-card catalog from numeric card IDs.
-- CHANGE THIS MODULE WHEN: Rank, suit or deck membership changes.
-- DO NOT PUT HERE: Hand totals, shuffle, payouts or drawing instructions.

local cards = {}
cards.rank_names = { "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K" }
cards.suit_names = { "S", "H", "D", "C" }

function cards.rank(card_id)
    return (card_id - 1) % 13 + 1
end

function cards.describe(card_id)
    return {
        id = card_id,
        rank = cards.rank(card_id),
        suit = math.floor((card_id - 1) % 52 / 13) + 1,
        deck = math.floor((card_id - 1) / 52) + 1,
    }
end

function cards.value(card_id)
    return math.min(cards.rank(card_id), 10)
end

function cards.deck_ids(deck_count)
    local card_ids = {}
    for card_id = 1, 52 * deck_count do
        card_ids[card_id] = card_id
    end
    return card_ids
end

return cards
