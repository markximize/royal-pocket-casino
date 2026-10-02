-- PURPOSE: Own the approved prototype preset and its bounded configuration.
-- CHANGE THIS MODULE WHEN: A documented rule or supported setting changes.
-- DO NOT PUT HERE: Player actions, UI, randomness or silent fallback values.

local rules = {}
local fixed = {
    preset_id = "royal_classic_v1",
    revision = 1,
    blackjack_profit_numerator = 3,
    blackjack_profit_denominator = 2,
    max_hands = 4,
    same_rank_split = true,
    resplit_non_aces = true,
    resplit_aces = false,
    hit_split_aces = false,
    double_split_aces = false,
    surrender = false,
    insurance = false,
    even_money = false,
    hole_card_model = "us",
    dealer_peek = true,
    burn_cards = 0,
}
local configurable = {
    deck_count = { 6, 8 },
    dealer_hits_soft_17 = { false, true },
    double_rule = { "any_two", "9_to_11", "10_to_11" },
    double_after_split = { true, false },
    penetration_percent = { 75, 50, 67 },
}

function rules.defaults()
    local preset = {}
    for name, value in pairs(fixed) do
        preset[name] = value
    end
    for name, choices in pairs(configurable) do
        preset[name] = choices[1]
    end
    return preset
end

function rules.validate(preset)
    if type(preset) ~= "table" then
        return false, "Rules must be an object"
    end
    for name, value in pairs(fixed) do
        if preset[name] ~= value then
            return false, "Unsupported rule: " .. name
        end
    end
    for name, choices in pairs(configurable) do
        local supported = false
        for _, value in ipairs(choices) do
            if preset[name] == value then
                supported = true
            end
        end
        if not supported then
            return false, "Unsupported setting: " .. name
        end
    end
    for name in pairs(preset) do
        if fixed[name] == nil and configurable[name] == nil then
            return false, "Unknown rule: " .. tostring(name)
        end
    end
    return true
end

function rules.profile_id(preset)
    return string.format(
        "%s:%d:%d:%s:%s:%s:%d",
        preset.preset_id,
        preset.revision,
        preset.deck_count,
        tostring(preset.dealer_hits_soft_17),
        preset.double_rule,
        tostring(preset.double_after_split),
        preset.penetration_percent
    )
end

return rules
