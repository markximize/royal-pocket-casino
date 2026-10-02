-- PURPOSE: Coordinate the small learning, advice, coach and credits pages.
-- CHANGE THIS MODULE WHEN: Educational navigation or controller entry changes.
-- DO NOT PUT HERE: Strategy indices, wager analysis or Blackjack state mutation.

local copy = require("src.plain_copy")
local session = require("src.app.session")
local training = require("src.app.training")
local tutorial = require("src.training.tutorial")
local coach = require("src.progress.session_coach")
local components = require("src.ui.components")
local learning_screen = require("src.ui.learning_screen")
local coach_screen = require("src.ui.coach_screen")
local branding = require("src.ui.branding")
local education = {}
local text, colors = components.text, components.colors

local function open(app, page)
    app.ui.page_origins = app.ui.page_origins or {}
    if app.ui.page ~= page then
        app.ui.page_origins[page] = app.ui.page
    end
    app.ui.page, app.ui.focus = page, 1
end

function education.activate(app, kind)
    local current, ui = app.session, app.ui
    if not current.snapshot then
        return false
    end
    if kind == "learn_hilo" then
        if current.pending then
            return true
        end
        open(app, "tutorial")
        app.lesson = tutorial.new()
        app.lesson.entry = 0
    elseif kind == "assistance_page" or kind == "advice_page" then
        open(app, kind == "assistance_page" and "assistance" or "advice")
    elseif kind == "coach_page" then
        open(app, "coach")
        ui.coach_page = 1
        ui.history_page = 1
        ui.betting_page = 1
    elseif kind == "about_page" then
        open(app, "about")
        ui.notice_page = 1
    elseif kind == "education_back" then
        ui.page, ui.focus = (ui.page_origins and ui.page_origins[ui.page]) or "welcome", 1
        if ui.page == "table" and current.snapshot.game.phase == "betting" then
            ui.focus = 2
        end
    elseif kind == "assist_mode" or kind:sub(1, 7) == "assist_" then
        local preferences = copy(current.snapshot.assistance)
        if kind == "assist_mode" then
            preferences.mode = preferences.mode == "off" and "basic"
                or preferences.mode == "basic" and "advanced"
                or "off"
        else
            local key = kind:sub(8)
            if preferences[key] == nil then
                return false
            end
            preferences[key] = not preferences[key]
        end
        if not session.assistance_settings(current, preferences) and current.pending then
            ui.focus = 1
        end
    elseif kind == "coach_next" or kind == "coach_previous" then
        ui.coach_page = (ui.coach_page - 1 + (kind == "coach_next" and 1 or -1)) % 4 + 1
    elseif kind == "coach_new_session" then
        if not session.new_coaching_session(current) and current.pending then
            ui.focus = 1
        end
    elseif kind == "coach_practice" then
        local recommendation = coach.report(current.snapshot.coach).recommendation
        if recommendation then
            training.start(
                app,
                recommendation.kind == "strategy" and "strategy" or "counting",
                recommendation.category
            )
        end
    elseif kind == "notice_next" or kind == "notice_previous" then
        local maximum = branding.page_count(app.fonts)
        ui.notice_page = (ui.notice_page - 1 + (kind == "notice_next" and 1 or -1)) % maximum + 1
    elseif kind:sub(1, 9) == "tutorial_" then
        local lesson = app.lesson
        if not lesson or current.pending then
            return true
        end
        if kind == "tutorial_submit" then
            tutorial.answer(lesson, lesson.entry)
            ui.focus = 1
        elseif kind == "tutorial_next" then
            tutorial.advance(lesson)
            lesson.entry = 0
            local page = tutorial.current(lesson)
            ui.focus = page.exercise and not page.feedback and 2 or 1
        elseif kind == "tutorial_up" or kind == "tutorial_down" then
            lesson.entry =
                math.max(-416, math.min(416, lesson.entry + (kind == "tutorial_up" and 1 or -1)))
        elseif kind == "tutorial_practice" then
            training.start(app, "counting")
            -- Onboarding uses temporary teaching aids without changing the
            -- player's saved preferences for later independent practice.
            app.trainer.settings.level = "beginner"
            app.trainer.settings.assistance = true
            app.trainer.settings.pace = "slow"
        end
    else
        return false
    end
    return true
end

function education.intent(app, intent)
    if app.ui.page == "tutorial" and app.lesson then
        local page = tutorial.current(app.lesson)
        if page.exercise and not page.feedback and not app.session.pending then
            local change = intent == "count_up" and 1
                or intent == "count_down" and -1
                or intent == "inspect_next" and 5
                or intent == "inspect_previous" and -5
            if change then
                app.lesson.entry = math.max(-416, math.min(416, app.lesson.entry + change))
                return true
            end
        end
    end
    if
        (app.ui.page == "coach" or app.ui.page == "about")
        and (intent == "inspect_next" or intent == "inspect_previous")
    then
        if app.ui.page == "coach" and app.ui.coach_page == 2 then
            local report = coach.report(app.session.snapshot.coach)
            local pages = math.max(1, #report.betting.patterns)
            local direction = intent == "inspect_next" and 1 or -1
            app.ui.betting_page = ((app.ui.betting_page or 1) - 1 + direction) % pages + 1
            return true
        elseif app.ui.page == "coach" and app.ui.coach_page == 4 then
            local history = app.session.snapshot.coach.recent
            local pages = math.max(1, math.ceil(#history / 7))
            local direction = intent == "inspect_next" and 1 or -1
            app.ui.history_page = ((app.ui.history_page or 1) - 1 + direction) % pages + 1
            return true
        end
        education.activate(
            app,
            (app.ui.page == "coach" and "coach_" or "notice_")
                .. (intent == "inspect_next" and "next" or "previous")
        )
        return true
    end
    return false
end

local function buttons(items, list)
    local result = {}
    for index, item in ipairs(items) do
        result[index] = {
            label = item[1],
            kind = item[2],
            enabled = item[3] ~= false,
            x = list and 70 or 20 + (index - 1) * 608 / #items,
            y = list and 105 + (index - 1) * 37 or 418,
            width = list and 500 or 608 / #items - 8,
            height = list and 32 or 38,
        }
    end
    return result
end

function education.buttons(app)
    local ui, snapshot = app.ui, app.session.snapshot
    local educational_page = ui.page == "tutorial"
        or ui.page == "assistance"
        or ui.page == "coach"
        or ui.page == "about"
        or ui.page == "advice"
    if educational_page and app.session.pending then
        return buttons({ { "Retry save", "retry" }, { "Back", "education_back" } })
    end
    if ui.page == "tutorial" then
        return learning_screen.buttons(app.lesson, app.session.pending ~= nil)
    end
    if ui.page == "assistance" then
        local preferences = snapshot.assistance
        local items = {
            {
                "Assisted Play: " .. preferences.mode:upper(),
                "assist_mode",
                not app.session.pending,
            },
        }
        for _, row in ipairs({
            { "Strategy hints", "strategy_hints" },
            { "Explanations", "explanations" },
            { "Deviation prompts", "deviations" },
            { "Check My Count", "check_count" },
        }) do
            items[#items + 1] = {
                row[1] .. ": " .. (preferences[row[2]] and "on" or "off"),
                "assist_" .. row[2],
                not app.session.pending,
            }
        end
        items[#items + 1] = { "Count displays / trainer settings", "count_settings_page" }
        items[#items + 1] = { "Back", "education_back" }
        return buttons(items, true)
    elseif ui.page == "coach" then
        local report = coach.report(snapshot.coach)
        local result = buttons({
            { "Prev", "coach_previous" },
            { "Next", "coach_next" },
            {
                "Practice",
                "coach_practice",
                report.recommendation ~= nil and not app.session.pending,
            },
            {
                "New session",
                "coach_new_session",
                snapshot.game.phase == "betting" and not app.session.pending,
            },
            { "Back", "education_back" },
        })
        local widths, x = { 68, 68, 125, 173, 126 }, 20
        for index, button in ipairs(result) do
            button.x, button.width = x, widths[index]
            x = x + widths[index] + 8
        end
        return result
    elseif ui.page == "about" then
        return buttons({
            { "Prev", "notice_previous" },
            { "Notices / Next", "notice_next" },
            { "Back", "education_back" },
        })
    elseif ui.page == "advice" then
        return buttons({ { "Back", "education_back" } })
    end
end

function education.draw(app, visible)
    local ui, fonts = app.ui, app.fonts
    local selected = education.buttons(app)
    if not selected then
        return false
    end
    if app.session.pending then
        components.background()
        text(fonts.title, "PROGRESS NOT SAVED", 24, 22, colors.gold)
        text(fonts.body, app.session.message, 30, 110, colors.ivory, 575)
        text(
            fonts.body,
            "Your acknowledged progress remains unchanged. "
                .. "Retry saves the same pending change once.",
            30,
            260,
            colors.muted,
            575
        )
    elseif ui.page == "tutorial" then
        ui.pending = app.session.pending ~= nil
        learning_screen.draw(fonts, app.lesson, ui)
        return true
    elseif ui.page == "coach" then
        coach_screen.draw(
            fonts,
            assert(coach.report(app.session.snapshot.coach)),
            ui.coach_page,
            ui.history_page or 1,
            ui.betting_page or 1
        )
    elseif ui.page == "about" then
        branding.about(fonts, ui.notice_page)
    else
        components.background()
        text(
            fonts.title,
            ui.page == "advice" and "YOUR NEXT DECISION" or "ASSISTED PLAY",
            24,
            22,
            colors.gold
        )
        if ui.page == "assistance" then
            text(
                fonts.detail,
                "OFF: pure play. BASIC: strategy. ADVANCED: public count + indices.",
                24,
                56,
                colors.muted,
                592
            )
            text(
                fonts.detail,
                "Count displays are independent in ADVANCED. Checkpoints can stay on.",
                24,
                374,
                colors.muted,
                592
            )
        else
            local advice = visible.advice
            if not advice then
                text(
                    fonts.body,
                    "Advice appears for a visible player decision with assistance ON.",
                    30,
                    130,
                    colors.ivory,
                    580
                )
            else
                text(
                    fonts.body,
                    "BASIC STRATEGY: " .. advice.basic.action:upper(),
                    30,
                    109,
                    colors.gold
                )
                if visible.assistance.explanations then
                    text(fonts.body, advice.basic.explanation, 30, 145, colors.ivory, 570)
                end
                if advice.counts then
                    local settings, count = visible.count_settings, advice.counts
                    local parts = {}
                    if settings.show_running then
                        parts[#parts + 1] = "RC " .. count.running
                    end
                    if settings.show_true then
                        parts[#parts + 1] = "TC " .. count.true_count
                    end
                    if settings.show_decks then
                        parts[#parts + 1] = "EST. DECKS " .. count.decks
                    end
                    text(fonts.body, table.concat(parts, "  •  "), 30, 224, colors.gold)
                    text(
                        fonts.detail,
                        "TC = running count / estimated decks; truncate toward zero.",
                        30,
                        255,
                        colors.muted,
                        570
                    )
                    local message = "No supported deviation is currently triggered."
                    if advice.deviation then
                        message = "COUNT-ADJUSTED: " .. advice.deviation.action:upper()
                        if visible.assistance.explanations then
                            message = message .. "\n" .. advice.deviation.reason
                        end
                    elseif not advice.profile_supported then
                        message = advice.profile_reason
                    end
                    text(fonts.body, message, 30, 295, colors.ivory, 570)
                end
            end
        end
    end
    for index, button in ipairs(selected) do
        components.button(fonts, button, ui.focus == index)
    end
    if app.session.pending then
        text(
            fonts.small,
            "SAVE FAILED — RETRY BEFORE CONTINUING",
            0,
            463,
            colors.gold,
            640,
            "center"
        )
    end
    return true
end

return education
