-- PURPOSE: Own shuffle order, cursor, discards and between-round penetration.
-- CHANGE THIS MODULE WHEN: Shoe construction or shuffle boundaries change.
-- DO NOT PUT HERE: An RNG implementation, hand rules, credits or graphics.

local cards = require("src.blackjack.cards")
local shoe = {}

function shoe.new(preset, generator, next_integer, generation)
    local order = cards.deck_ids(preset.deck_count)
    for index = #order, 2, -1 do
        local other = next_integer(generator, 1, index)
        assert(other >= 1 and other <= index and other == math.floor(other))
        order[index], order[other] = order[other], order[index]
    end
    return {
        deck_count = preset.deck_count,
        order = order,
        next_index = 1,
        discarded = {},
        cut_position = math.floor(#order * preset.penetration_percent / 100),
        shuffle_pending = false,
        generation = generation or 1,
    }
end

function shoe.draw(current_shoe)
    local card_id = current_shoe.order[current_shoe.next_index]
    if not card_id then
        return nil
    end
    current_shoe.next_index = current_shoe.next_index + 1
    if current_shoe.next_index - 1 >= current_shoe.cut_position then
        current_shoe.shuffle_pending = true
    end
    return card_id
end

function shoe.finish_round(current_shoe)
    -- Result hands reference discards for display; they no longer own escrow/cards.
    for index = #current_shoe.discarded + 1, current_shoe.next_index - 1 do
        current_shoe.discarded[#current_shoe.discarded + 1] = current_shoe.order[index]
    end
end

function shoe.fixture(order, deck_count)
    return {
        order = order,
        deck_count = deck_count or 6,
        next_index = 1,
        discarded = {},
        cut_position = #order,
        shuffle_pending = false,
        generation = 1,
        test_fixture = true,
    }
end

return shoe
