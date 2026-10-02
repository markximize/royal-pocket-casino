-- PURPOSE: Observe public physical cards and calculate the Hi-Lo count.
-- CHANGE THIS MODULE WHEN: Hi-Lo tags or documented count conventions change.
-- DO NOT PUT HERE: Hidden shoe reads, dealing, bankroll, statistics or graphics.

local cards = require("src.blackjack.cards")
local hi_lo = {}
local maximum_cards = 8 * 52

local function is_integer(value, minimum, maximum)
    return type(value) == "number"
        and value == value
        and value >= minimum
        and value <= maximum
        and value == math.floor(value)
end

local function valid_ids(card_ids)
    if type(card_ids) ~= "table" then
        return nil, "Public cards must be an ordered array."
    end
    for index, card_id in pairs(card_ids) do
        if not is_integer(index, 1, #card_ids) then
            return nil, "Public cards must be an ordered array without gaps."
        end
        if not is_integer(card_id, 1, maximum_cards) then
            return nil, "A public card has an invalid physical ID."
        end
    end
    for index = 1, #card_ids do
        if not card_ids[index] then
            return nil, "Public cards must be an ordered array without gaps."
        end
    end
    return true
end

-- ## CANONICAL HI-LO TAGS

function hi_lo.tag(card_id)
    if not is_integer(card_id, 1, maximum_cards) then
        return nil, "Hi-Lo requires a valid physical card ID."
    end
    local rank = cards.rank(card_id)
    if rank >= 2 and rank <= 6 then
        return 1
    elseif rank >= 7 and rank <= 9 then
        return 0
    end
    return -1
end

function hi_lo.new(generation)
    if not is_integer(generation, 1, 1000000000000) then
        return nil, "Shoe generation must be a positive integer."
    end
    return { generation = generation, seen = {}, running_count = 0, exposed_count = 0 }
end

local function validate_observer(current)
    if type(current) ~= "table" or type(current.seen) ~= "table" then
        return nil, "Hi-Lo observer state is missing."
    end
    local empty, reason = hi_lo.new(current.generation)
    if not empty then
        return nil, reason
    end
    local running_count, exposed_count = 0, 0
    for card_id, exposed in pairs(current.seen) do
        local tag = hi_lo.tag(card_id)
        if not tag or exposed ~= true then
            return nil, "Hi-Lo exposure history is invalid."
        end
        running_count = running_count + tag
        exposed_count = exposed_count + 1
    end
    if current.running_count ~= running_count or current.exposed_count ~= exposed_count then
        return nil, "Hi-Lo count disagrees with its exposure history."
    end
    return true
end

-- ## PUBLIC-CARD OBSERVATION

function hi_lo.observe(current, generation, card_ids)
    local valid, reason = validate_observer(current)
    if not valid then
        return nil, reason
    end
    local observed, generation_error = hi_lo.new(generation)
    if not observed then
        return nil, generation_error
    end
    if generation < current.generation then
        return nil, "Cannot observe cards from an older shoe generation."
    end
    local valid_cards, card_error = valid_ids(card_ids)
    if not valid_cards then
        return nil, card_error
    end
    if generation == current.generation then
        for card_id in pairs(current.seen) do
            observed.seen[card_id] = true
        end
        observed.running_count = current.running_count
        observed.exposed_count = current.exposed_count
    end
    for _, card_id in ipairs(card_ids) do
        if not observed.seen[card_id] then
            observed.seen[card_id] = true
            observed.running_count = observed.running_count + hi_lo.tag(card_id)
            observed.exposed_count = observed.exposed_count + 1
        end
    end
    return observed
end

function hi_lo.visible_ids(visible)
    if type(visible) ~= "table" or type(visible.hands) ~= "table" then
        return nil, "A public Blackjack view is required."
    end
    if type(visible.dealer) ~= "table" or type(visible.dealer.cards) ~= "table" then
        return nil, "Public dealer cards are missing."
    end
    local card_ids = {}
    for _, player_hand in ipairs(visible.hands) do
        if type(player_hand) ~= "table" then
            return nil, "Public player hands are invalid."
        end
        local valid, reason = valid_ids(player_hand.cards)
        if not valid then
            return nil, reason
        end
        for _, card_id in ipairs(player_hand.cards) do
            card_ids[#card_ids + 1] = card_id
        end
    end
    for _, dealer_card in ipairs(visible.dealer.cards) do
        if type(dealer_card) ~= "table" then
            return nil, "Public dealer cards are invalid."
        end
        -- Even an accidentally supplied ID must contribute nothing while hidden.
        if not dealer_card.hidden then
            if not is_integer(dealer_card.id, 1, maximum_cards) then
                return nil, "A public dealer card has an invalid physical ID."
            end
            card_ids[#card_ids + 1] = dealer_card.id
        end
    end
    return card_ids
end

-- ## DECK ESTIMATION AND TRUE COUNT

function hi_lo.estimate_decks(deck_count, exposed_count, step)
    if step == nil then
        step = 0.5
    end
    if not is_integer(deck_count, 1, 8) then
        return nil, "Deck estimation requires one to eight standard decks."
    end
    if not is_integer(exposed_count, 0, deck_count * 52) then
        return nil, "Exposed-card count is outside this shoe's size."
    end
    if step ~= 0.5 and step ~= 1 then
        return nil, "Deck estimates support half-deck or whole-deck steps."
    end
    -- Use only exposed cards, not the shoe cursor or hidden hole. Round UP.
    local remaining_cards = deck_count * 52 - exposed_count
    local estimate = math.ceil(remaining_cards / (52 * step)) * step
    return math.max(step, estimate)
end

function hi_lo.true_count(running_count, estimated_decks, rounding)
    if rounding == nil then
        rounding = "truncate"
    end
    if not is_integer(running_count, -maximum_cards, maximum_cards) then
        return nil, "Running count must be a bounded integer."
    end
    if type(estimated_decks) ~= "number" or estimated_decks ~= estimated_decks then
        return nil, "Estimated decks must be a finite positive number."
    end
    if estimated_decks < 0.5 or estimated_decks > 8 then
        return nil, "Estimated decks must be between half a deck and eight decks."
    end
    if rounding ~= "truncate" and rounding ~= "floor" then
        return nil, "True-count rounding must be truncate or floor."
    end
    local quotient = running_count / estimated_decks
    if rounding == "truncate" and quotient < 0 then
        return math.ceil(quotient)
    end
    return math.floor(quotient)
end

return hi_lo
