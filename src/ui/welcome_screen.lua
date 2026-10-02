-- PURPOSE: Offer a clear entry point, controls and plain-language rules.
-- CHANGE THIS MODULE WHEN: First-run navigation or player help changes.
-- DO NOT PUT HERE: New game state, trainer scoring, accounts or future-game buttons.

local components = require("src.ui.components")
local branding = require("src.ui.branding")
local welcome = {}
local colors, text = components.colors, components.text

function welcome.buttons(visible, ui)
    if ui.page == "help" then
        return {
            {
                label = "Back",
                kind = "back",
                enabled = true,
                x = 180,
                y = 421,
                width = 280,
                height = 35,
            },
        }
    end
    local items = {
        { "Continue", "play", visible.phase ~= "betting" },
        { "Blackjack", "play", true },
        { "Basic Strategy", "strategy_start", not visible.pending },
        { "Card Counting", "counting_start", not visible.pending },
        { "Learn Hi-Lo", "learn_hilo", not visible.pending },
        { "Statistics", "statistics_page", true },
        { "Settings", "menu", true },
        { "Exit", "exit" },
    }
    local buttons = {}
    for index, item in ipairs(items) do
        buttons[index] = {
            label = item[1],
            kind = item[2],
            enabled = item[3] ~= false,
            x = 292,
            y = 117 + (index - 1) * 39,
            width = 318,
            height = 33,
        }
    end
    return buttons
end

function welcome.draw(fonts, visible, ui)
    components.background()
    if ui.page == "help" then
        text(fonts.title, "YOUR BLACKJACK TABLE", 26, 22, colors.gold)
        local paragraphs = {
            { "THE GOAL", "Get closer to 21 than the dealer. Over 21 is a bust." },
            { "YOUR CARDS", "Aces count as 1 or 11. Face cards count as 10." },
            { "YOUR MOVE", "Hit adds a card. Stand finishes your hand." },
            {
                "DOUBLE / SPLIT",
                "Double adds an equal bet and one card. "
                    .. "Split a same-rank pair into two funded hands.",
            },
            {
                "THE RESULT",
                "A natural Ace + ten-value card pays 3:2. "
                    .. "Ordinary wins pay 1:1. A push returns your stake.",
            },
        }
        for index, paragraph in ipairs(paragraphs) do
            local y = 89 + (index - 1) * 58
            text(fonts.small, paragraph[1], 30, y, colors.gold)
            text(fonts.body, paragraph[2], 30, y + 16, colors.ivory, 580)
        end
    else
        text(fonts.title, "ROYAL POCKET CASINO", 0, 22, colors.ivory, 640, "center")
        text(
            fonts.detail,
            "BLACKJACK  •  PRACTICE  •  LEARN",
            0,
            57,
            colors.gold,
            640,
            "center"
        )
        branding.logo(22, 103, 250, 250)
        text(fonts.small, "© 2026 MarkXimize Interactive", 22, 387, colors.gold, 250, "center")
        text(fonts.small, "A dedicated offline casino table", 22, 413, colors.muted, 250, "center")
    end
    for index, button in ipairs(welcome.buttons(visible, ui)) do
        components.button(fonts, button, ui.focus == index)
    end
    text(
        fonts.small,
        ui.page == "help" and "Arrows: select • Enter / A: confirm • Esc / B: back"
            or "Offline play  •  Virtual chips only  •  No cash value",
        0,
        463,
        colors.muted,
        640,
        "center"
    )
end

return welcome
