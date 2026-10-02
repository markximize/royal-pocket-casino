-- PURPOSE: Translate settings buttons into validated session changes.
-- CHANGE THIS MODULE WHEN: A supported setting or its selection order changes.
-- DO NOT PUT HERE: Navigation, animation, audio playback or Blackjack formulas.

local copy = require("src.plain_copy")
local session = require("src.app.session")
local settings = {}

-- ## SETTINGS COMMANDS

function settings.category(kind)
    if kind == "sound" or kind == "volume" or kind == "motion" then
        return "preferences"
    elseif
        kind:sub(1, 4) == "hud_"
        or kind == "training_level"
        or kind == "training_pace"
        or kind == "training_assistance"
    then
        return "count_preferences"
    elseif
        kind == "decks"
        or kind == "soft17"
        or kind == "double_rule"
        or kind == "das"
        or kind == "penetration"
    then
        return "rules"
    end
    return nil
end

local function cycle(value, choices)
    for index, choice in ipairs(choices) do
        if value == choice then
            return choices[index % #choices + 1]
        end
    end
    error("Unsupported current setting")
end

local function change_preferences(current, kind)
    local preferences = copy(current.snapshot.settings)
    if kind == "sound" then
        preferences.sound_enabled = not preferences.sound_enabled
    elseif kind == "volume" then
        preferences.volume = (preferences.volume + 1) % 11
    else
        preferences.reduced_motion = not preferences.reduced_motion
    end
    return session.settings(current, preferences)
end

local function change_count_preferences(current, kind)
    local preferences = copy(current.snapshot.count_settings)
    if kind == "hud_running" then
        preferences.show_running = not preferences.show_running
    elseif kind == "hud_true" then
        preferences.show_true = not preferences.show_true
    elseif kind == "hud_decks" then
        preferences.show_decks = not preferences.show_decks
    elseif kind == "training_level" then
        preferences.level = cycle(preferences.level, { "beginner", "practice", "advanced" })
        preferences.assistance = preferences.level == "beginner"
    elseif kind == "training_pace" then
        preferences.pace = cycle(preferences.pace, { "slow", "comfortable", "fast" })
    else
        preferences.assistance = not preferences.assistance
    end
    return session.count_settings(current, preferences)
end

local function change_rule(current, kind)
    local preset = copy(current.snapshot.game.rules)
    if kind == "decks" then
        preset.deck_count = cycle(preset.deck_count, { 6, 8 })
    elseif kind == "soft17" then
        preset.dealer_hits_soft_17 = not preset.dealer_hits_soft_17
    elseif kind == "double_rule" then
        preset.double_rule = cycle(preset.double_rule, { "any_two", "9_to_11", "10_to_11" })
    elseif kind == "das" then
        preset.double_after_split = not preset.double_after_split
    elseif kind == "penetration" then
        preset.penetration_percent = cycle(preset.penetration_percent, { 50, 67, 75 })
    end
    return session.command(current, "configure", { rules = preset })
end

-- Copy before editing: only the session may adopt a change after its save passes.
function settings.change(current, kind)
    local category = settings.category(kind)
    if category == "preferences" then
        return change_preferences(current, kind)
    elseif category == "count_preferences" then
        return change_count_preferences(current, kind)
    elseif category == "rules" then
        return change_rule(current, kind)
    end
    return false
end

return settings
