-- PURPOSE: Reconstruct a count from previously disclosed cards and the displayed table.
-- CHANGE THIS MODULE WHEN: Card visibility or counting display conventions change.
-- DO NOT PUT HERE: Drawing cards, strategy, bankroll changes or save writes.

local hi_lo = require("src.training.hi_lo")
local count_view = {}

function count_view.build(game, visible, settings)
    local current_ids = {}
    if game.round then
        for _, player in ipairs(game.round.hands) do
            for _, id in ipairs(player.cards) do
                current_ids[id] = true
            end
        end
        for _, id in ipairs(game.round.dealer.cards) do
            current_ids[id] = true
        end
    end
    local public_ids = {}
    -- Completed-round discards contain the current result too. Exclude that round
    -- until its presentation reveals it; identity comparison never reads its rank.
    for _, id in ipairs(game.shoe.discarded) do
        if not current_ids[id] then
            public_ids[#public_ids + 1] = id
        end
    end
    for _, id in ipairs(hi_lo.visible_ids(visible)) do
        public_ids[#public_ids + 1] = id
    end
    local observed =
        assert(hi_lo.observe(hi_lo.new(game.shoe.generation), game.shoe.generation, public_ids))
    local decks = assert(
        hi_lo.estimate_decks(game.rules.deck_count, observed.exposed_count, settings.deck_step)
    )
    return {
        running = observed.running_count,
        true_count = assert(hi_lo.true_count(observed.running_count, decks, settings.rounding)),
        decks = decks,
        exposed = observed.exposed_count,
    }
end

return count_view
