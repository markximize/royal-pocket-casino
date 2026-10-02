-- PURPOSE: Render original card shapes with readable rank and suit indicators.
-- CHANGE THIS MODULE WHEN: Card readability or vector artwork changes.
-- DO NOT PUT HERE: Rank values, hand evaluation, textures or downloaded assets.

local cards = require("src.blackjack.cards")
local components = require("src.ui.components")
local card_draw = {}

local function suit_symbol(suit, x, y, size)
    if suit == 2 then
        love.graphics.circle("fill", x - size * 0.3, y - size * 0.2, size * 0.43)
        love.graphics.circle("fill", x + size * 0.3, y - size * 0.2, size * 0.43)
        love.graphics.polygon("fill", x - size * 0.7, y, x + size * 0.7, y, x, y + size)
    elseif suit == 3 then
        love.graphics.polygon(
            "fill",
            x,
            y - size,
            x + size * 0.7,
            y,
            x,
            y + size,
            x - size * 0.7,
            y
        )
    elseif suit == 1 then
        love.graphics.polygon(
            "fill",
            x,
            y - size,
            x - size * 0.7,
            y + size * 0.2,
            x + size * 0.7,
            y + size * 0.2
        )
        love.graphics.circle("fill", x - size * 0.3, y + size * 0.2, size * 0.4)
        love.graphics.circle("fill", x + size * 0.3, y + size * 0.2, size * 0.4)
        love.graphics.rectangle("fill", x - size * 0.12, y + size * 0.2, size * 0.24, size * 0.8)
    else
        love.graphics.circle("fill", x, y - size * 0.45, size * 0.42)
        love.graphics.circle("fill", x - size * 0.4, y + size * 0.2, size * 0.42)
        love.graphics.circle("fill", x + size * 0.4, y + size * 0.2, size * 0.42)
        love.graphics.rectangle("fill", x - size * 0.12, y + size * 0.2, size * 0.24, size * 0.8)
    end
end

local pip_positions = {
    [2] = { { 0.5, 0.28 }, { 0.5, 0.74 } },
    [3] = { { 0.5, 0.28 }, { 0.5, 0.5 }, { 0.5, 0.74 } },
    [4] = { { 0.3, 0.3 }, { 0.7, 0.3 }, { 0.3, 0.72 }, { 0.7, 0.72 } },
    [5] = { { 0.3, 0.3 }, { 0.7, 0.3 }, { 0.5, 0.51 }, { 0.3, 0.72 }, { 0.7, 0.72 } },
}

function card_draw.draw(fonts, visible_card, x, y, width, height, motion)
    love.graphics.push()
    if motion then
        local progress = motion.progress or 0
        if motion.kind == "flip" then
            love.graphics.translate(x + width / 2, y)
            love.graphics.scale(math.max(0.06, math.abs(1 - progress * 2)), 1)
            x, y = -width / 2, 0
        else
            local eased = 1 - (1 - progress) ^ 3
            x, y = x + (555 - x) * (1 - eased), y + (95 - y) * (1 - eased)
        end
    end
    love.graphics.setColor(0, 0, 0, 0.20)
    love.graphics.rectangle("fill", x + 3, y + 4, width, height, 5, 5)
    local hidden = type(visible_card) == "table" and visible_card.hidden
    love.graphics.setColor(hidden and { 0.045, 0.10, 0.075 } or { 0.95, 0.94, 0.87 })
    love.graphics.rectangle("fill", x, y, width, height, 5, 5)
    love.graphics.setColor(components.colors.gold)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 3, y + 3, width - 6, height - 6, 3, 3)
    if hidden then
        love.graphics.setColor(0.75, 0.62, 0.32, 0.28)
        for row = 1, 5 do
            for column = 1, 3 do
                local px, py = x + width * column / 4, y + height * row / 6
                love.graphics.polygon("line", px, py - 4, px + 3, py, px, py + 4, px - 3, py)
            end
        end
        components.crown(x + width / 2, y + height / 2, width * 0.18)
        love.graphics.pop()
        return
    end
    local id = type(visible_card) == "table" and visible_card.id or visible_card
    local card = cards.describe(id)
    local ink = (card.suit == 2 or card.suit == 3) and { 0.65, 0.13, 0.12 } or { 0.08, 0.12, 0.10 }
    local rank_font = width >= 65 and fonts.rank or fonts.body
    components.text(rank_font, cards.rank_names[card.rank], x + 6, y + 4, ink)
    components.text(fonts.small, cards.suit_names[card.suit], x + width - 16, y + height - 18, ink)
    love.graphics.setColor(ink)
    if width >= 65 and pip_positions[card.rank] then
        for _, position in ipairs(pip_positions[card.rank]) do
            suit_symbol(card.suit, x + width * position[1], y + height * position[2], 6)
        end
    elseif width >= 65 and card.rank >= 11 then
        love.graphics.setColor(0.79, 0.66, 0.38, 0.3)
        love.graphics.rectangle(
            "fill",
            x + width * 0.22,
            y + height * 0.29,
            width * 0.56,
            height * 0.46,
            3,
            3
        )
        components.text(
            fonts.amount,
            cards.rank_names[card.rank],
            x,
            y + height * 0.32,
            ink,
            width,
            "center"
        )
        love.graphics.setColor(ink)
        suit_symbol(card.suit, x + width / 2, y + height * 0.66, 7)
    else
        suit_symbol(card.suit, x + width / 2, y + height * 0.57, math.min(14, height * 0.17))
    end
    love.graphics.pop()
end

function card_draw.fan(
    fonts,
    visible_cards,
    x,
    y,
    area_width,
    width,
    height,
    animation,
    player_index
)
    local count = #visible_cards
    if count == 0 then
        return
    end
    local step = count > 1 and math.min(width + 8, (area_width - width) / (count - 1)) or 0
    local start = x + (area_width - (width + step * (count - 1))) / 2
    for index, card in ipairs(visible_cards) do
        local same_hand = animation
            and player_index
            and animation.kind == "player"
            and animation.player_index == player_index
        local dealer_card = animation and not player_index and animation.kind ~= "player"
        local motion = animation
                and animation.card_index == index
                and (same_hand or dealer_card)
                and animation
            or nil
        card_draw.draw(fonts, card, start + (index - 1) * step, y, width, height, motion)
    end
end

function card_draw.row(fonts, visible_cards, y)
    local count = #visible_cards
    if count == 0 then
        return
    end
    local compact = count > 10
    local width, height, gap, per_row =
        compact and 46 or 55, compact and 49 or 78, 7, compact and 11 or 10
    for index, card in ipairs(visible_cards) do
        local row = math.floor((index - 1) / per_row)
        local columns = math.min(per_row, count - row * per_row)
        local start_x = (640 - (columns * (width + gap) - gap)) / 2
        card_draw.draw(
            fonts,
            card,
            start_x + (index - 1) % per_row * (width + gap),
            y + row * (height + 4),
            width,
            height
        )
    end
end

return card_draw
