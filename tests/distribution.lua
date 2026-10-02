-- PURPOSE: Check a fixed fresh-shuffle corpus against predeclared distributions.
-- CHANGE THIS MODULE WHEN: A reviewed sample plan or statistical bound changes.
-- DO NOT PUT HERE: House-edge claims, hidden-card gameplay advice or startup work.

local test = require("tests.harness")
local cards = require("src.blackjack.cards")
local rules = require("src.blackjack.rules")
local shoe = require("src.blackjack.shoe")
local seeded = require("src.random.seeded")
local distribution = {}

-- ## PREDECLARED EXACT-BINOMIAL GATES

-- 36 comparisons, family alpha 0.001, two tails: each tail receives 1/72000.
-- Python 3.12.14 Decimal (80 digits) generated these bounds BEFORE sampling.
-- They assume independent uniform trials; this seeded corpus is a diagnostic.
local samples_per_stream = 1000
local first_seed, last_seed = 1001, 1020
local bounds = {
    first_rank = { 1383, 1699 },
    first_suit = { 4745, 5258 },
    natural = { [6] = { 826, 1078 }, [8] = { 826, 1077 } },
}

local function empty_counts(size)
    local counts = {}
    for index = 1, size do
        counts[index] = 0
    end
    return counts
end

local function player_has_natural(order)
    -- P-D-P-D dealing gives the original player's cards positions 1 and 3.
    -- This independent rank check deliberately does not use hand.evaluate.
    local first_rank, second_rank = cards.rank(order[1]), cards.rank(order[3])
    return (first_rank == 1 and second_rank >= 10) or (second_rank == 1 and first_rank >= 10)
end

local function sample_fresh_shoes(deck_count)
    local observed = { ranks = empty_counts(13), suits = empty_counts(4), naturals = 0 }
    local preset = rules.defaults()
    preset.deck_count = deck_count
    for seed = first_seed, last_seed do
        local generator = seeded.new(seed)
        for _ = 1, samples_per_stream do
            -- Always construct a complete new shoe; never sample depleted hands.
            local shuffled = shoe.new(preset, generator, seeded.next_integer)
            local first_card = cards.describe(shuffled.order[1])
            observed.ranks[first_card.rank] = observed.ranks[first_card.rank] + 1
            observed.suits[first_card.suit] = observed.suits[first_card.suit] + 1
            if player_has_natural(shuffled.order) then
                observed.naturals = observed.naturals + 1
            end
        end
    end
    return observed
end

local function in_range(observed, accepted)
    assert(
        observed >= accepted[1] and observed <= accepted[2],
        string.format(
            "Observed %d, predeclared acceptance [%d,%d]",
            observed,
            accepted[1],
            accepted[2]
        )
    )
end

local function register_comparisons(deck_count, observed)
    local prefix = deck_count .. "-deck fresh-shuffle "
    for rank, name in ipairs(cards.rank_names) do
        test.test(prefix .. "first rank " .. name .. " meets its exact-binomial gate", function()
            in_range(observed.ranks[rank], bounds.first_rank)
        end)
    end
    for suit, name in ipairs(cards.suit_names) do
        test.test(prefix .. "first suit " .. name .. " meets its exact-binomial gate", function()
            in_range(observed.suits[suit], bounds.first_suit)
        end)
    end
    test.test(prefix .. "P-D-P-D original natural meets its exact-binomial gate", function()
        in_range(observed.naturals, bounds.natural[deck_count])
    end)
end

function distribution.run()
    for _, deck_count in ipairs({ 6, 8 }) do
        local observed = sample_fresh_shoes(deck_count)
        register_comparisons(deck_count, observed)
        print(
            string.format(
                "Distribution %dD: n=20000; ranks A..K=[%s] bounds=1383..1699; "
                    .. "suits S,H,D,C=[%s] bounds=4745..5258; naturals=%d bounds=%d..%d",
                deck_count,
                table.concat(observed.ranks, ","),
                table.concat(observed.suits, ","),
                observed.naturals,
                bounds.natural[deck_count][1],
                bounds.natural[deck_count][2]
            )
        )
    end
end

return distribution
