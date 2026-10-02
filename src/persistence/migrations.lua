-- PURPOSE: Add approved learning fields to validated older saves in memory.
-- CHANGE THIS MODULE WHEN: A real save-format migration or its defaults changes.
-- DO NOT PUT HERE: Corruption repair, file writes or changes to saved Blackjack.

local copy = require("src.plain_copy")
local training_statistics = require("src.progress.training_statistics")
local session_coach = require("src.progress.session_coach")
local migrations = {}

function migrations.count_defaults()
    return {
        show_running = false,
        show_true = false,
        show_decks = false,
        rounding = "truncate",
        deck_step = 0.5,
        level = "beginner",
        pace = "comfortable",
        assistance = true,
    }
end

function migrations.assistance_defaults()
    return {
        mode = "off",
        strategy_hints = true,
        explanations = true,
        deviations = true,
        check_count = true,
    }
end

-- The caller validates before and after migration. Loading does not write files,
-- increment a revision, draw a card, or reinterpret the stored table rules.
function migrations.to_current(snapshot)
    local migrated = copy(snapshot)
    if migrated.format_version == 1 then
        migrated.format_version = 2
        migrated.training = training_statistics.new()
        migrated.count_settings = migrations.count_defaults()
    end
    if migrated.format_version == 2 then
        migrated.format_version = 3
        migrated.assistance = migrations.assistance_defaults()
        -- Old totals cannot reconstruct individual decisions or bet sequences.
        -- Keep existing statistics; begin new coaching evidence honestly empty.
        migrated.coach = session_coach.new()
    end
    return migrated
end

return migrations
