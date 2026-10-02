-- PURPOSE: Render a readable casino table, visible hands, wagers and results.
-- CHANGE THIS MODULE WHEN: Table composition or labeled controls change.
-- DO NOT PUT HERE: Drawing new cards, settlement formulas or save operations.

local components = require("src.ui.components")
local card_draw = require("src.ui.card_draw")
local chip = require("src.ui.chip_draw")
local screen = {}
local colors, text, amount = components.colors, components.text, components.amount

function screen.buttons(visible, ui)
    local items
    if visible.pending then
        items = { { "Retry save", "retry", true } }
    elseif visible.error then
        items = { { "Exit", "exit", true } }
    elseif visible.phase == "betting" then
        items = {
            { "−5", "bet_down", ui.bet_units > 50 },
            { "Deal " .. amount(ui.bet_units), "deal", ui.bet_units <= visible.bankroll_units },
            { "+5", "bet_up", ui.bet_units + 50 <= math.min(1000, visible.bankroll_units) },
            { "Menu", "menu", true },
        }
        if visible.bankroll_units < 50 then
            items[2] = { "Free refill", "refill", true }
        end
    elseif visible.phase == "round_result" then
        items = { { "Next round", "next_round", true }, { "Menu", "menu", true } }
    else
        items = {
            { "Hit [H]", "hit", visible.legal.hit },
            { "Stand [S]", "stand", visible.legal.stand },
            { "Double [D]", "double", visible.legal.double },
            { "Split [P]", "split", visible.legal.split },
        }
    end
    local buttons = {}
    for index, item in ipairs(items) do
        buttons[index] = {
            label = item[1],
            kind = item[2],
            enabled = item[3] and not visible.animating,
            x = 20 + (index - 1) * 608 / #items,
            y = 418,
            width = 608 / #items - 8,
            height = 38,
        }
    end
    if visible.phase == "betting" and not visible.pending and not visible.error then
        for index, denomination in ipairs({ 5, 10, 25 }) do
            buttons[#buttons + 1] = {
                label = "Add " .. denomination,
                kind = "chip_" .. denomination,
                enabled = ui.bet_units + denomination * 10
                    <= math.min(1000, visible.bankroll_units),
                chip = denomination,
                x = 212 + (index - 1) * 78,
                y = 300,
                width = 60,
                height = 60,
            }
        end
    end
    return buttons
end

local function header(fonts, visible)
    components.crown(33, 30, 14)
    text(fonts.title, "ROYAL POCKET CASINO", 59, 13, colors.gold)
    text(fonts.small, "MARKXIMIZE INTERACTIVE  •  BLACKJACK", 60, 43, colors.muted)
    if visible.error then
        return
    end
    text(fonts.small, "VIRTUAL CHIPS", 422, 8, colors.muted)
    local wallet = amount(visible.bankroll_units)
    text(#wallet > 9 and fonts.body or fonts.amount, wallet, 422, 25, colors.ivory)
    text(fonts.detail, "MENU", 562, 28, colors.gold)
    local settings, count = visible.count_settings, visible.count
    if settings and count then
        local parts = {}
        if settings.show_running then
            parts[#parts + 1] = "RC " .. string.format("%+d", count.running)
        end
        if settings.show_true then
            parts[#parts + 1] = "TC " .. string.format("%+d", count.true_count)
        end
        if settings.show_decks then
            parts[#parts + 1] = "DECKS " .. count.decks
        end
        text(fonts.small, table.concat(parts, "  •  "), 26, 64, colors.gold)
    end
end

local function betting(fonts, ui)
    text(fonts.detail, "BLACKJACK PAYS 3:2", 0, 106, colors.gold, 640, "center")
    text(fonts.hero, "Take your seat", 0, 143, colors.ivory, 640, "center")
    love.graphics.setColor(0.84, 0.70, 0.40, 0.5)
    love.graphics.ellipse("line", 320, 235, 126, 42)
    chip.stack(fonts, ui.bet_units, 249, 235)
    text(fonts.amount, amount(ui.bet_units), 334, 210, colors.ivory, 80, "center")
    text(fonts.small, "YOUR BET", 334, 243, colors.gold, 80, "center")
    text(fonts.detail, "ADD CHIPS", 0, 278, colors.muted, 640, "center")
    text(fonts.detail, "5–100 chips  •  No cash value", 0, 373, colors.muted, 640, "center")
end

local function result_title(visible, selected)
    if visible.animating then
        return "Dealing…"
    end
    if not visible.result then
        return "Your move"
    end
    if visible.result.void then
        return "ROUND REFUNDED"
    end
    local row = visible.result.hands[selected]
    if row.natural and row.outcome == "blackjack" then
        return "BLACKJACK"
    end
    if row.bust then
        return "BUST"
    end
    local labels = { win = "YOU WIN", loss = "DEALER WINS", push = "PUSH", blackjack = "BLACKJACK" }
    return labels[row.outcome]
end

local function hands(fonts, visible, ui)
    local count = #visible.hands
    local selected = visible.phase == "player_turn" and visible.active_hand
        or math.min(ui.inspect_hand, count)
    local expand = false
    for _, player in ipairs(visible.hands) do
        if #player.cards > (count > 2 and 4 or 8) then
            expand = true
        end
    end
    for index, player in ipairs(visible.hands) do
        local area, x = 588 / count, 26 + (index - 1) * 588 / count
        local label = count == 1 and "YOUR HAND" or "HAND " .. index
        if player.status == "pending" then
            label = label .. " • WAITING"
        end
        if player.total then
            label = label .. "  " .. player.total .. (player.soft and " SOFT" or "")
        end
        text(
            count > 2 and fonts.detail or fonts.body,
            label,
            x,
            248,
            selected == index and colors.gold or colors.muted,
            area,
            "center"
        )
        if not expand then
            local width, height =
                count > 2 and 48 or count == 2 and 64 or 76,
                count > 2 and 78 or count == 2 and 94 or 100
            if selected == index then
                love.graphics.setColor(0.8, 0.68, 0.38, 0.25)
                love.graphics.rectangle("line", x + 2, 273, area - 4, 121, 9, 9)
            end
            card_draw.fan(
                fonts,
                player.cards,
                x + 6,
                276,
                area - 12,
                width,
                height,
                visible.animation,
                index
            )
            text(
                fonts.small,
                "BET " .. amount(player.stake_units) .. (player.doubled and " • DOUBLED" or ""),
                x,
                379,
                colors.muted,
                area,
                "center"
            )
        end
    end
    if expand then
        card_draw.row(fonts, visible.hands[selected].cards, 276)
        text(
            fonts.small,
            "Expanded hand " .. selected .. " • Q/E or shoulders to inspect",
            0,
            390,
            colors.muted,
            640,
            "center"
        )
    end
end

function screen.draw(fonts, visible, ui)
    components.background()
    header(fonts, visible)
    if visible.error then
        text(fonts.title, "Progress could not be loaded", 30, 125, colors.gold)
        text(fonts.body, tostring(visible.error), 30, 175, colors.ivory, 580)
        text(fonts.body, "Existing save files are preserved.", 30, 300)
    elseif visible.phase == "betting" then
        betting(fonts, ui)
    else
        text(
            fonts.body,
            "DEALER" .. (visible.dealer.total and "  " .. visible.dealer.total or ""),
            26,
            94,
            colors.ivory
        )
        local preset = visible.rules
        text(
            fonts.small,
            preset.deck_count
                .. " DECKS  •  "
                .. (preset.dealer_hits_soft_17 and "H17" or "S17")
                .. "  •  3:2",
            405,
            96,
            colors.muted,
            204,
            "right"
        )
        card_draw.fan(fonts, visible.dealer.cards, 28, 119, 584, 65, 91, visible.animation)
        local selected = math.min(ui.inspect_hand, #visible.hands)
        text(
            visible.result and fonts.amount or fonts.body,
            result_title(visible, selected),
            0,
            visible.result and 212 or 216,
            colors.gold,
            640,
            "center"
        )
        hands(fonts, visible, ui)
    end
    for index, button in ipairs(screen.buttons(visible, ui)) do
        components.button(fonts, button, ui.focus == index)
    end
    local footer = visible.pending and "SAVE FAILED — RETRY BEFORE CONTINUING"
        or visible.message and visible.message ~= "Saved locally" and visible.message
        or visible.animating and "Enter / A: finish animation  •  Menu: Esc / Start"
        or "Arrows / D-pad: select  •  Enter / A: confirm  •  Esc / Start: menu"
    text(fonts.small, footer, 0, 462, colors.muted, 640, "center")
    if visible.result and not visible.animating then
        love.graphics.setColor(colors.panel)
        love.graphics.rectangle("fill", 102, 391, 436, 23, 7, 7)
        if visible.result.void then
            text(
                fonts.small,
                "Shoe exhausted — full stake restored; next round shuffles",
                0,
                397,
                colors.gold,
                640,
                "center"
            )
        else
            local result = visible.result
            text(
                fonts.small,
                "STAKED "
                    .. amount(result.staked_units)
                    .. "  •  RETURNED "
                    .. amount(result.returned_units)
                    .. "  •  NET "
                    .. amount(result.net_units, true),
                0,
                397,
                colors.gold,
                640,
                "center"
            )
        end
    elseif visible.advice and visible.assistance.strategy_hints then
        local advice = visible.advice
        local label = advice.deviation and "COUNT-ADJUSTED " or "BASIC STRATEGY "
        love.graphics.setColor(colors.panel)
        love.graphics.rectangle("fill", 55, 391, 530, 23, 7, 7)
        text(
            fonts.detail,
            label .. advice.action:upper() .. "  •  Menu: explanation",
            0,
            397,
            colors.gold,
            640,
            "center"
        )
    elseif visible.shuffle_pending then
        text(fonts.small, "Fresh shoe before the next deal", 0, 397, colors.muted, 640, "center")
    end
end

return screen
