-- PURPOSE: Present short Hi-Lo lessons and untimed controller-friendly exercises.
-- CHANGE THIS MODULE WHEN: Lesson readability, card placement or labeled controls change.
-- DO NOT PUT HERE: Count calculations, answer scoring, shoe RNG or save writes.

local components = require("src.ui.components")
local card_draw = require("src.ui.card_draw")
local tutorial = require("src.training.tutorial")
local screen = {}
local text, colors = components.text, components.colors

local function row_buttons(items, pending)
    local buttons = {}
    for index, item in ipairs(items) do
        buttons[index] = {
            label = item[1],
            kind = item[2],
            enabled = not pending,
            x = 20 + (index - 1) * 608 / #items,
            y = 418,
            width = 608 / #items - 8,
            height = 38,
        }
    end
    return buttons
end

function screen.buttons(state, pending)
    local page = tutorial.current(state)
    if page.complete then
        return row_buttons(
            { { "Start practice", "tutorial_practice" }, { "Home", "home" } },
            pending
        )
    elseif state.feedback then
        return row_buttons({ { "Next", "tutorial_next" }, { "Home", "home" } }, pending)
    elseif page.exercise then
        return row_buttons({
            { "−1", "tutorial_down" },
            { "Submit", "tutorial_submit" },
            { "+1", "tutorial_up" },
            { "Back", "home" },
        }, pending)
    end
    return row_buttons({ { "Next", "tutorial_next" }, { "Back", "home" } }, pending)
end

local function public_cards(fonts, page, y, width, height)
    if not page.card_ids then
        return
    end
    local visible = {}
    for _, id in ipairs(page.card_ids) do
        visible[#visible + 1] = id
    end
    if page.hidden_card then
        visible[#visible + 1] = { hidden = true }
    end
    card_draw.fan(fonts, visible, 32, y, 576, width, height)
end

local function lesson_lines(fonts, page, y)
    for _, line in ipairs(page.lines) do
        local _, wrapped = fonts.body:getWrap(line, 576)
        text(fonts.body, line, 32, y, colors.ivory, 576)
        y = y + math.max(1, #wrapped) * fonts.body:getHeight() + 11
    end
end

local function feedback(fonts, page, answer)
    text(
        fonts.amount,
        answer.correct and "CORRECT" or "LET'S LOOK AGAIN",
        0,
        151,
        colors.gold,
        640,
        "center"
    )
    text(
        fonts.body,
        "Correct answer: " .. answer.expected .. " " .. page.exercise.unit,
        0,
        194,
        colors.ivory,
        640,
        "center"
    )
    text(fonts.body, answer.explanation, 32, 238, colors.ivory, 576, "center")
    public_cards(fonts, page, 310, 59, 84)
end

local function exercise(fonts, page, state)
    lesson_lines(fonts, page, 145)
    local has_cards = page.card_ids ~= nil
    if has_cards then
        public_cards(fonts, page, 208, 68, 96)
    end
    text(fonts.body, page.exercise.prompt, 0, has_cards and 319 or 269, colors.gold, 640, "center")
    local entry = state.entry or 0
    local label = page.exercise.kind == "half_decks" and tostring(entry)
        or string.format("%+d", entry)
    text(
        fonts.amount,
        label .. " " .. page.exercise.unit,
        0,
        has_cards and 349 or 310,
        colors.ivory,
        640,
        "center"
    )
    text(fonts.detail, "X / Y: −1 / +1    L / R: −5 / +5", 0, 381, colors.muted, 640, "center")
end

function screen.draw(fonts, state, ui)
    components.background()
    local page = tutorial.current(state)
    text(fonts.title, "LEARN HI-LO", 24, 22, colors.gold)
    text(
        fonts.detail,
        page.complete and "FIVE SHORT LESSONS COMPLETE"
            or "Lesson "
                .. page.stage
                .. " / 5  •  Page "
                .. page.page_number
                .. " / "
                .. page.page_count,
        24,
        56,
        colors.muted
    )
    text(fonts.amount, page.title, 32, 98, colors.ivory, 576)
    if page.complete then
        lesson_lines(fonts, page, 166)
        text(fonts.body, "You completed the five Hi-Lo lessons.", 32, 229, colors.gold, 576)
        text(
            fonts.body,
            "Start with Beginner to see tags while practicing.",
            32,
            277,
            colors.ivory,
            576
        )
        text(
            fonts.detail,
            "Your normal bankroll and shoe were untouched.",
            32,
            346,
            colors.muted,
            576
        )
    elseif state.feedback then
        feedback(fonts, page, state.feedback)
    elseif page.exercise then
        exercise(fonts, page, state)
    else
        lesson_lines(fonts, page, 161)
        text(
            fonts.detail,
            "Take your time. These lessons have no timer.",
            32,
            365,
            colors.muted,
            576
        )
    end
    for index, button in ipairs(screen.buttons(state, ui.pending)) do
        components.button(fonts, button, ui.focus == index)
    end
    text(
        fonts.small,
        "D-pad: select  •  A: confirm  •  B / Start: home",
        0,
        463,
        colors.muted,
        640,
        "center"
    )
end

return screen
