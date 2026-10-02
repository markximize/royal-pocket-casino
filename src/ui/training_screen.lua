-- PURPOSE: Present strategy questions, counting drills and controller count entry.
-- CHANGE THIS MODULE WHEN: Practice readability, feedback or labeled controls change.
-- DO NOT PUT HERE: Strategy tables, counting tags, answer scoring or save writes.

local components = require("src.ui.components")
local card_draw = require("src.ui.card_draw")
local practice = require("src.training.practice")
local hi_lo = require("src.training.hi_lo")
local screen = {}
local text, colors = components.text, components.colors

local function buttons(items, y)
    local result = {}
    for index, item in ipairs(items) do
        result[index] = {
            label = item[1],
            kind = item[2],
            enabled = item[3] ~= false,
            x = 20 + (index - 1) * 608 / #items,
            y = y or 418,
            width = 608 / #items - 8,
            height = 38,
        }
    end
    return result
end

function screen.buttons(current, pending)
    if pending then
        return buttons({ { "Retry save", "training_retry" } })
    end
    if current.error then
        return buttons({ { "Home", "home" } })
    end
    if current.phase == "feedback" then
        return buttons({
            {
                current.mode == "normal_count" and "Back to table"
                    or current.goal and current.drills_done >= current.goal and "Drill complete"
                    or "Next",
                "training_next",
            },
            { "Home", "home" },
        })
    end
    if current.phase == "answer" then
        return buttons({
            { "−1", "count_down" },
            { "Submit", "training_submit" },
            { "+1", "count_up" },
            { "Back", "training_cancel" },
        })
    end
    if current.mode == "strategy" then
        local legal = practice.table_view(current).legal
        return buttons({
            { "Hit", "answer_hit", legal.hit },
            { "Stand", "answer_stand", legal.stand },
            { "Double", "answer_double", legal.double },
            { "Split", "answer_split", legal.split },
        })
    end
    return buttons({
        { current.paused and "Resume" or "Pause", "training_pause", not current.shoe_complete },
        { "Check RC", "training_check_running", current.target ~= "true_count" },
        { "Check TC", "training_check_true", current.target ~= "running" },
        { "New shoe", "training_shuffle" },
    })
end

local function feedback(fonts, current)
    local answer = current.feedback
    text(
        fonts.amount,
        answer.correct and "CORRECT" or "KEEP PRACTICING",
        0,
        99,
        colors.gold,
        640,
        "center"
    )
    text(
        fonts.body,
        "Correct answer: " .. tostring(answer.expected):upper(),
        0,
        145,
        colors.ivory,
        640,
        "center"
    )
    text(fonts.body, answer.explanation, 48, 215, colors.ivory, 544, "center")
    if current.mode ~= "strategy" then
        local counts = current.mode == "normal_count" and current.counts or practice.counts(current)
        text(
            fonts.body,
            "Running " .. counts.running .. "  ÷  " .. counts.decks .. " decks",
            0,
            302,
            colors.gold,
            640,
            "center"
        )
        text(
            fonts.detail,
            "Half-deck estimates round up; true counts truncate toward zero.",
            0,
            342,
            colors.muted,
            640,
            "center"
        )
    end
end

local function entry(fonts, current)
    text(
        fonts.body,
        current.answer_kind == "running" and "WHAT IS YOUR RUNNING COUNT?"
            or "WHAT IS YOUR TRUE COUNT?",
        0,
        115,
        colors.ivory,
        640,
        "center"
    )
    text(fonts.hero, string.format("%+d", current.entry), 0, 197, colors.gold, 640, "center")
    if current.answer_kind ~= "running" then
        local counts = current.mode == "normal_count" and current.counts or practice.counts(current)
        text(
            fonts.body,
            "Estimated decks remaining: " .. counts.decks,
            0,
            277,
            colors.ivory,
            640,
            "center"
        )
        text(
            fonts.detail,
            "Use your running count. Truncate toward zero.",
            0,
            314,
            colors.muted,
            640,
            "center"
        )
    end
    text(fonts.body, "X / Y: −1 / +1    L / R: −5 / +5", 0, 362, colors.muted, 640, "center")
end

local function strategy_question(fonts, current)
    local visible = practice.table_view(current)
    local player = visible.hands[visible.active_hand]
    text(fonts.body, "DEALER SHOWS", 30, 104, colors.gold)
    card_draw.draw(fonts, visible.dealer.cards[1].id, 278, 98, 68, 94)
    text(
        fonts.body,
        "YOUR HAND  " .. player.total .. (player.soft and " SOFT" or " HARD"),
        0,
        209,
        colors.gold,
        640,
        "center"
    )
    card_draw.fan(fonts, player.cards, 32, 244, 576, 72, 104)
    if current.practice_counts then
        local counts = current.practice_counts
        text(
            fonts.detail,
            "GIVEN EXERCISE COUNT: RC "
                .. counts.running
                .. " / "
                .. counts.decks
                .. " decks = TC "
                .. counts.true_count,
            0,
            355,
            colors.gold,
            640,
            "center"
        )
        text(
            fonts.detail,
            "Basic: "
                .. current.recommendation.basic_action:upper()
                .. " • Choose count-adjusted play",
            0,
            375,
            colors.ivory,
            640,
            "center"
        )
    else
        text(fonts.body, "Choose the recommended play", 0, 366, colors.ivory, 640, "center")
    end
end

local function counting_cards(fonts, current)
    local counts = practice.counts(current)
    text(
        fonts.body,
        current.settings.level:upper() .. "  •  SHOE " .. current.shoe.generation,
        0,
        101,
        colors.gold,
        640,
        "center"
    )
    if current.card then
        card_draw.draw(fonts, current.card, 274, 145, 92, 133)
        if current.settings.level ~= "advanced" and current.settings.assistance then
            local tag = assert(hi_lo.tag(current.card))
            text(fonts.amount, string.format("%+d", tag), 409, 195, colors.gold)
        end
    else
        text(
            fonts.body,
            "Start at zero. Count each revealed card.",
            0,
            198,
            colors.ivory,
            640,
            "center"
        )
    end
    if current.settings.level == "beginner" and current.settings.assistance then
        text(
            fonts.amount,
            "RUNNING COUNT  " .. string.format("%+d", counts.running),
            0,
            299,
            colors.ivory,
            640,
            "center"
        )
    else
        text(fonts.body, "Keep the count mentally", 0, 303, colors.ivory, 640, "center")
    end
    text(fonts.body, "Cards exposed: " .. counts.exposed .. "", 0, 344, colors.muted, 640, "center")
    text(
        fonts.detail,
        current.shoe_complete and "Cut reached. Check your count, then start a new shoe."
            or current.paused and "PAUSED"
            or current.settings.level == "beginner" and "2–6: +1    7–9: 0    Tens / Aces: −1"
            or "Checkpoints pause dealing. Continue when ready.",
        0,
        380,
        colors.muted,
        640,
        "center"
    )
end

function screen.draw(fonts, current, ui, statistics, pending, message)
    components.background()
    text(
        fonts.title,
        current.target == "deviation" and "DEVIATION PRACTICE"
            or current.mode == "strategy" and "BASIC STRATEGY"
            or current.mode == "normal_count" and "CHECK YOUR COUNT"
            or "CARD COUNTING",
        24,
        22,
        colors.gold
    )
    local subtitle = "Royal Pocket Casino  •  HI-LO PRACTICE"
    if current.mode == "strategy" then
        local preset = current.rules
        subtitle = table.concat({
            preset.deck_count .. " DECKS",
            preset.dealer_hits_soft_17 and "H17" or "S17",
            "DOUBLE " .. preset.double_rule:gsub("_", " "):upper(),
            preset.double_after_split and "DAS" or "NO DAS",
        }, "  •  ")
    end
    text(fonts.detail, subtitle, 24, 56, colors.muted)
    if current.goal then
        text(
            fonts.detail,
            current.target:upper() .. " " .. current.drills_done .. "/" .. current.goal,
            414,
            28,
            colors.muted,
            200,
            "right"
        )
    end
    if current.error then
        text(fonts.body, current.error, 32, 142, colors.ivory, 576)
    elseif current.phase == "feedback" then
        feedback(fonts, current)
    elseif current.phase == "answer" then
        entry(fonts, current)
    elseif current.mode == "strategy" then
        strategy_question(fonts, current)
    else
        counting_cards(fonts, current)
    end
    if current.mode == "strategy" and statistics then
        local accuracy = statistics.attempts > 0
                and math.floor(100 * statistics.correct / statistics.attempts + 0.5)
            or 0
        love.graphics.setColor(colors.panel)
        love.graphics.rectangle("fill", 140, 389, 360, 25, 7, 7)
        text(
            fonts.detail,
            "Strategy accuracy "
                .. accuracy
                .. "%  •  Streak "
                .. statistics.streak
                .. "  •  Best "
                .. statistics.best_streak,
            0,
            394,
            colors.muted,
            640,
            "center"
        )
    end
    for index, button in ipairs(screen.buttons(current, pending)) do
        components.button(fonts, button, ui.focus == index)
    end
    text(
        fonts.small,
        pending and "SAVE FAILED — RETRY BEFORE CONTINUING"
            or message and message ~= "Saved locally" and message
            or "D-pad: select  •  A: confirm  •  B / Start: home",
        0,
        462,
        colors.muted,
        640,
        "center"
    )
end

return screen
