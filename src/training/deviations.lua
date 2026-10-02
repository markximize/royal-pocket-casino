-- PURPOSE: Apply a small published Hi-Lo index profile to public player decisions.
-- CHANGE THIS MODULE WHEN: A sourced index or its explicit applicability changes.
-- DO NOT PUT HERE: Counting hidden cards, dealing, wager advice, saves or graphics.
-- Sources and estimator limits are documented in docs/LEARNING_GUIDE.md.

local cards = require("src.blackjack.cards")
local hand = require("src.blackjack.hand")
local rules = require("src.blackjack.rules")
local player_actions = require("src.blackjack.player_actions")
local hi_lo = require("src.training.hi_lo")
local deviations = {}

local profile_id = "hi_lo_i18_s17_6d_positive_stands_v1"
local indices = {
    { id = "15_v_10", total = 15, upcard = 10, index = 4 },
    { id = "12_v_3", total = 12, upcard = 3, index = 2 },
    { id = "12_v_2", total = 12, upcard = 2, index = 3 },
    { id = "16_v_9", total = 16, upcard = 9, index = 5 },
}

-- ## PROFILE AND PUBLIC-COUNT BOUNDARIES

function deviations.supported(preset)
    local valid, reason = rules.validate(preset)
    if not valid then
        return false, reason
    end
    if preset.deck_count ~= 6 or preset.dealer_hits_soft_17 then
        return false, "Deviation profile requires six decks and S17."
    end
    if preset.double_rule ~= "any_two" or not preset.double_after_split then
        return false, "Deviation profile requires any-two doubling and DAS."
    end
    return true
end

local function verified_true_count(counts)
    if type(counts) ~= "table" then
        return nil, "Public count information is unavailable."
    end
    local estimated, reason = hi_lo.estimate_decks(6, counts.exposed)
    if not estimated then
        return nil, reason
    end
    if counts.decks ~= estimated then
        return nil, "Deck estimate does not use the locked half-deck convention."
    end
    local true_count, count_error = hi_lo.true_count(counts.running, estimated)
    if true_count == nil then
        return nil, count_error
    end
    if counts.true_count ~= true_count then
        return nil, "True count does not use the locked truncation convention."
    end
    return true_count
end

-- ## READ-ONLY INDEX LOOKUP

function deviations.recommend(game, counts, basic_advice)
    if type(game) ~= "table" then
        return nil, "A player decision is required."
    end
    local supported, reason = deviations.supported(game.rules)
    if not supported then
        return nil, reason
    end
    local legal = player_actions.legal(game)
    if not legal.hit or not legal.stand then
        return nil, "There is no active player decision."
    end
    if type(basic_advice) ~= "table" or basic_advice.action ~= "hit" then
        return nil, "No supported change from basic strategy is available."
    end
    local current = game.round.hands[game.round.active_hand]
    if current.from_split or #current.cards ~= 2 then
        return nil, "This profile covers original two-card hands only."
    end
    if cards.rank(current.cards[1]) == cards.rank(current.cards[2]) then
        return nil, "This profile omits pairs."
    end
    local evaluated = hand.evaluate(current.cards, false)
    if evaluated.soft then
        return nil, "This profile covers hard totals only."
    end
    local true_count, count_error = verified_true_count(counts)
    if true_count == nil then
        return nil, count_error
    end
    local dealer_value = cards.value(game.round.dealer.cards[1])
    for _, entry in ipairs(indices) do
        if evaluated.total == entry.total and dealer_value == entry.upcard then
            if true_count < entry.index then
                return nil, "The published index has not been reached."
            end
            return {
                action = "stand",
                basic_action = basic_advice.action,
                index = entry.index,
                profile = profile_id,
                id = entry.id,
                reason = "TC reached +"
                    .. entry.index
                    .. "; this Hi-Lo profile stands instead of hitting.",
            }
        end
    end
    return nil, "No deviation in this compact profile covers this decision."
end

return deviations
