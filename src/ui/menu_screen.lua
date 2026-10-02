-- PURPOSE: Present a small menu, statistics and the supported rule settings.
-- CHANGE THIS MODULE WHEN: A documented setting or visible metric changes.
-- DO NOT PUT HERE: Gameplay decisions, save decoding or future trainer features.

local components = require("src.ui.components")
local menu_screen = {}
local palette, text, amount = components.colors, components.text, components.amount

function menu_screen.buttons(visible, ui)
    local items
    if ui.page == "statistics" or ui.page == "training_statistics" then
        items = {
            {
                ui.page == "statistics" and "Training statistics" or "Gameplay statistics",
                ui.page == "statistics" and "training_statistics_page" or "statistics_page",
                true,
            },
            { "Back", "back", true },
        }
    elseif ui.page == "count_settings" then
        local settings = visible.count_settings
        items = {
            {
                "Running-count HUD: " .. (settings.show_running and "on" or "off"),
                "hud_running",
                not visible.pending,
            },
            {
                "True-count HUD: " .. (settings.show_true and "on" or "off"),
                "hud_true",
                not visible.pending,
            },
            {
                "Decks-remaining HUD: " .. (settings.show_decks and "on" or "off"),
                "hud_decks",
                not visible.pending,
            },
            { "Trainer: " .. settings.level, "training_level", not visible.pending },
            { "Card pace: " .. settings.pace, "training_pace", not visible.pending },
            {
                "Card-value help: " .. (settings.assistance and "on" or "off"),
                "training_assistance",
                not visible.pending,
            },
            { "Back", "back", true },
        }
    elseif ui.page == "rules" then
        local allowed = visible.phase == "betting" and not visible.pending
        local preset = visible.rules
        items = {
            { "Decks: " .. preset.deck_count, "decks", allowed },
            {
                "Dealer: " .. (preset.dealer_hits_soft_17 and "hits soft 17" or "stands soft 17"),
                "soft17",
                allowed,
            },
            { "Double: " .. preset.double_rule:gsub("_", " "), "double_rule", allowed },
            {
                "Double after split: " .. (preset.double_after_split and "on" or "off"),
                "das",
                allowed,
            },
            { "Penetration: " .. preset.penetration_percent .. "%", "penetration", allowed },
            { "Back", "back", true },
        }
    else
        items = {
            { "Continue", "back", true },
            {
                "Sound: " .. (visible.settings.sound_enabled and "on" or "off"),
                "sound",
                not visible.pending,
            },
            { "Volume: " .. visible.settings.volume .. "/10", "volume", not visible.pending },
            {
                "Reduced motion: " .. (visible.settings.reduced_motion and "on" or "off"),
                "motion",
                not visible.pending,
            },
            { "Table rules", "rules_page", true },
            { "Statistics", "statistics_page", true },
            { "Counting settings", "count_settings_page", true },
            {
                "Check running count",
                "check_count",
                not visible.pending
                    and not visible.animating
                    and ui.table_seen
                    and visible.assistance.mode == "advanced"
                    and visible.assistance.check_count,
            },
            {
                "Check true count",
                "check_true_count",
                not visible.pending
                    and not visible.animating
                    and ui.table_seen
                    and visible.assistance.mode == "advanced"
                    and visible.assistance.check_count,
            },
            { "Shuffle shoe", "shuffle", visible.phase == "betting" and not visible.pending },
            { "Open save folder", "save_folder", true },
            {
                visible.pending and "Retry pending save" or "How to play",
                visible.pending and "retry" or "help",
                true,
            },
            { "Assisted Play", "assistance_page", true },
            { "Strategy explanation", "advice_page", visible.advice ~= nil },
            { "Session Coach", "coach_page", true },
            { "About / Credits", "about_page", true },
            { "Home", "home", true },
            { "Exit", "exit", true },
        }
    end
    local buttons = {}
    for index, item in ipairs(items) do
        local statistics_page = ui.page == "statistics" or ui.page == "training_statistics"
        local list_page = ui.page == "rules" or ui.page == "count_settings"
        local y = statistics_page and 421
            or list_page and 103 + (index - 1) * 33
            or 105 + math.floor((index - 1) / 2) * 35
        buttons[index] = {
            label = item[1],
            kind = item[2],
            enabled = item[3],
            x = statistics_page and 24 + (index - 1) * 308
                or list_page and 80
                or 24 + (index - 1) % 2 * 308,
            y = y,
            width = list_page and 480 or 284,
            height = list_page and 29 or statistics_page and 35 or 31,
        }
    end
    return buttons
end

function menu_screen.draw(fonts, visible, ui)
    components.background()
    local title = ui.page == "statistics" and "YOUR STATISTICS"
        or ui.page == "training_statistics" and "TRAINING STATISTICS"
        or ui.page == "count_settings" and "COUNTING SETTINGS"
        or ui.page == "rules" and "TABLE RULES"
        or "TABLE MENU"
    text(fonts.title, title, 24, 22, palette.gold)
    text(fonts.detail, "Royal Pocket Casino  •  your offline table", 24, 56, palette.muted)
    if ui.page == "statistics" then
        local counters = visible.statistics
        local rows = {
            { "Completed rounds", counters.completed_rounds },
            { "Settled hands", counters.settled_hands },
            {
                "Wins / losses / pushes",
                counters.wins .. " / " .. counters.losses .. " / " .. counters.pushes,
            },
            { "Natural Blackjacks", counters.natural_blackjacks },
            { "Player busts", counters.player_busts },
            { "Splits / doubles", counters.split_actions .. " / " .. counters.double_actions },
            { "Chips staked", amount(counters.main_staked_units) },
            { "Chips returned", amount(counters.main_returned_units) },
            { "Net chips", amount(counters.main_net_units, true) },
            { "Void rounds", counters.void_rounds },
        }
        for index, row in ipairs(rows) do
            text(fonts.body, row[1], 40, 105 + (index - 1) * 28)
            text(
                fonts.body,
                tostring(row[2]),
                350,
                105 + (index - 1) * 28,
                palette.ivory,
                250,
                "right"
            )
        end
    elseif ui.page == "training_statistics" then
        local strategy, counting = visible.training.strategy, visible.training.counting
        local function accuracy(correct, attempts)
            return attempts == 0 and "—" or string.format("%.1f%%", correct * 100 / attempts)
        end
        local rows = {
            { "Strategy attempts", strategy.attempts },
            { "Correct / incorrect", strategy.correct .. " / " .. strategy.incorrect },
            { "Strategy accuracy", accuracy(strategy.correct, strategy.attempts) },
            { "Strategy streak / best", strategy.streak .. " / " .. strategy.best_streak },
            { "Counting attempts", counting.attempts },
            {
                "Running correct / attempts",
                counting.running_correct .. " / " .. counting.running_attempts,
            },
            { "Running accuracy", accuracy(counting.running_correct, counting.running_attempts) },
            { "True correct / attempts", counting.true_correct .. " / " .. counting.true_attempts },
            { "True accuracy", accuracy(counting.true_correct, counting.true_attempts) },
            { "Counting streak / best", counting.streak .. " / " .. counting.best_streak },
        }
        for index, row in ipairs(rows) do
            text(fonts.body, row[1], 30, 105 + (index - 1) * 28)
            text(
                fonts.body,
                tostring(row[2]),
                360,
                105 + (index - 1) * 28,
                palette.ivory,
                245,
                "right"
            )
        end
    elseif ui.page == "count_settings" then
        text(
            fonts.body,
            "2–6: +1    7–9: 0    Tens / Aces: −1",
            0,
            345,
            palette.ivory,
            640,
            "center"
        )
        text(
            fonts.detail,
            "Deck estimate: half decks, rounded up, minimum 0.5.",
            0,
            378,
            palette.muted,
            640,
            "center"
        )
        text(
            fonts.detail,
            "True count truncates toward zero. Advanced hides card help.",
            0,
            405,
            palette.muted,
            640,
            "center"
        )
    elseif ui.page == "rules" then
        text(
            fonts.detail,
            "Change rules at the betting screen. Each change starts a fresh shoe.",
            24,
            323,
            palette.muted,
            592
        )
        text(
            fonts.body,
            "Natural Blackjack pays 3:2. Dealer checks for Blackjack.",
            24,
            359,
            palette.ivory,
            592
        )
        text(
            fonts.body,
            "Split same ranks, up to 4 hands. Split aces get one card.",
            24,
            385,
            palette.ivory,
            592
        )
    end
    for index, button in ipairs(menu_screen.buttons(visible, ui)) do
        components.button(fonts, button, ui.focus == index)
    end
    text(fonts.detail, tostring(visible.message or ""):sub(1, 80), 24, 462, palette.muted)
end

return menu_screen
