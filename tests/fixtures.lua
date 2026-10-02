-- PURPOSE: Build explicit P-D-P-D scenario shoes with distinct physical IDs.
-- CHANGE THIS MODULE WHEN: Fixture creation or stable deterministic inputs change.
-- DO NOT PUT HERE: Expected payouts, hidden production shortcuts or real saves.

local cards = require("src.blackjack.cards")
local rules = require("src.blackjack.rules")
local round = require("src.blackjack.round")
local shoe = require("src.blackjack.shoe")
local seeded = require("src.random.seeded")
local fixtures = {}

function fixtures.ids(rank_names)
    local rank_numbers, copies, card_ids = {}, {}, {}
    for index, name in ipairs(cards.rank_names) do
        rank_numbers[name] = index
    end
    for _, name in ipairs(rank_names) do
        local rank = assert(rank_numbers[name], "Unknown fixture rank " .. tostring(name))
        local used = copies[rank] or 0
        card_ids[#card_ids + 1] = rank + 13 * used
        copies[rank] = used + 1
    end
    return card_ids
end

function fixtures.game(rank_names, preset)
    local game = round.new(preset or rules.defaults(), seeded.new(12345), seeded.next_integer)
    game.shoe = shoe.fixture(fixtures.ids(rank_names), game.rules.deck_count)
    return game
end

function fixtures.full_order(rank_names, deck_count)
    local order, present = fixtures.ids(rank_names), {}
    for _, id in ipairs(order) do
        present[id] = true
    end
    for _, id in ipairs(cards.deck_ids(deck_count)) do
        if not present[id] then
            order[#order + 1] = id
        end
    end
    return order
end

function fixtures.act(game, kind, fields)
    local next_game, reason =
        round.apply(game, round.command(game, kind, fields), seeded.next_integer)
    assert(next_game, reason)
    return next_game
end

function fixtures.deal(rank_names, preset, bet_units)
    return fixtures.act(fixtures.game(rank_names, preset), "deal", { bet_units = bet_units or 100 })
end

return fixtures
