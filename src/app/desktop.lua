-- PURPOSE: Coordinate preview navigation, presentation and native lifecycle.
-- CHANGE THIS MODULE WHEN: Menu behavior or desktop integration changes.
-- DO NOT PUT HERE: Blackjack formulas, hidden-card rendering or a general manager.

local session = require("src.app.session")
local settings = require("src.app.settings")
local player_view = require("src.app.player_view")
local native = require("src.platform.native_storage")
local audio = require("src.platform.audio")
local components = require("src.ui.components")
local table_screen = require("src.ui.table_screen")
local menu_screen = require("src.ui.menu_screen")
local welcome_screen = require("src.ui.welcome_screen")
local presentation = require("src.ui.presentation")
local smoke = require("src.app.smoke_test")
local training = require("src.app.training")
local training_screen = require("src.ui.training_screen")
local count_view = require("src.app.count_view")
local desktop = {}
local assistance = require("src.app.assistance")
local education = require("src.app.education")

function desktop.new(smoke_test)
    local storage, storage_error = native.new()
    local current = storage and session.open(storage) or { message = storage_error }
    local previous_round = current.snapshot and current.snapshot.game.round
    local wagers = current.snapshot and current.snapshot.coach.wagers or {}
    local previous_wager = previous_round and previous_round.initial_bet_units
        or wagers[#wagers] and wagers[#wagers].bet_units
        or 100
    local app = {
        session = current,
        ui = {
            page = "welcome",
            focus = 1,
            bet_units = previous_wager,
            inspect_hand = 1,
            page_origins = {},
        },
        fonts = components.fonts(),
        tone = audio.new(),
        smoke = smoke_test and smoke.new(current.snapshot) or nil,
    }
    local visible = player_view.build(current)
    app.presentation = presentation.new(visible)
    if visible.phase ~= "betting" then
        app.ui.focus = 1
    elseif visible.bankroll_units then
        app.ui.focus = 2
        app.ui.bet_units =
            math.max(50, math.min(previous_wager, math.floor(visible.bankroll_units / 50) * 50))
    end
    print("Royal Pocket Casino " .. require("src.persistence.save_schema").app_version)
    print("Save directory: " .. love.filesystem.getSaveDirectory())
    local major, minor, patch, codename = love.getVersion()
    print(
        string.format(
            "Runtime: LOVE %d.%d.%d %s / %s",
            major,
            minor,
            patch,
            codename,
            love.system.getOS()
        )
    )
    print(string.format("Display: %dx%d", love.graphics.getDimensions()))
    local joysticks = love.joystick.getJoysticks()
    print("Detected controllers: " .. #joysticks)
    for _, joystick in ipairs(joysticks) do
        print(
            "Controller: "
                .. joystick:getName()
                .. " / "
                .. joystick:getGUID()
                .. " / gamepad="
                .. tostring(joystick:isGamepad())
        )
    end
    return app
end

function desktop.visible(app)
    local authoritative = player_view.build(app.session)
    local visible = app.presentation and presentation.view(app.presentation, authoritative)
        or authoritative
    -- Card/result reveals may pause; preferences and trainer progress must still
    -- come from the latest acknowledged save rather than a presentation copy.
    for _, name in ipairs({
        "settings",
        "assistance",
        "count_settings",
        "training",
        "message",
        "pending",
        "revision",
    }) do
        visible[name] = authoritative[name]
    end
    if
        app.session.snapshot
        and visible.count_settings
        and visible.assistance
        and visible.assistance.mode == "advanced"
        and (
            visible.count_settings.show_running
            or visible.count_settings.show_true
            or visible.count_settings.show_decks
        )
    then
        visible.count = count_view.build(app.session.snapshot.game, visible, visible.count_settings)
    end
    if app.session.snapshot then
        visible.advice = assistance.build(
            app.session.snapshot.game,
            visible,
            visible.assistance,
            visible.count_settings
        )
    end
    return visible
end

local function play_pending_sounds(app)
    if not app.presentation or not app.session.snapshot then
        return
    end
    for _, name in ipairs(presentation.sounds(app.presentation)) do
        audio.play(app.tone, name, app.session.snapshot.settings)
    end
end

function desktop.buttons(app)
    local visible = desktop.visible(app)
    local educational_buttons = app.session.snapshot and education.buttons(app)
    if educational_buttons then
        return educational_buttons
    end
    if app.ui.page == "training" and app.trainer then
        return training_screen.buttons(app.trainer, app.session.pending ~= nil)
    end
    if app.ui.page == "table" or visible.error then
        return table_screen.buttons(visible, app.ui)
    end
    if app.ui.page == "welcome" or app.ui.page == "help" then
        return welcome_screen.buttons(visible, app.ui)
    end
    return menu_screen.buttons(visible, app.ui)
end

function desktop.activate(app, kind)
    local ui, current = app.ui, app.session
    local settings_category = settings.category(kind)
    local before = player_view.build(current)
    if kind == "exit" then
        love.event.quit()
        return
    end
    if ui.page == "training" and training.activate(app, kind) then
        return
    end
    if kind == "retry" then
        if session.retry(current) then
            if app.pending_kind or before.error then
                app.presentation = app.presentation or presentation.new(before)
                presentation.begin(
                    app.presentation,
                    before,
                    player_view.build(current),
                    app.pending_kind or "resume",
                    current.snapshot.settings.reduced_motion
                )
            end
            app.pending_kind = nil
            ui.focus = ui.page == "table" and current.snapshot.game.phase == "betting" and 2 or 1
        end
        return
    end
    if not current.snapshot then
        return
    end
    if education.activate(app, kind) then
        return
    end
    if kind == "strategy_start" or kind == "counting_start" then
        training.start(app, kind == "strategy_start" and "strategy" or "counting")
        return
    elseif kind == "check_count" or kind == "check_true_count" then
        if
            current.pending
            or presentation.busy(app.presentation)
            or not ui.table_seen
            or current.snapshot.assistance.mode ~= "advanced"
            or not current.snapshot.assistance.check_count
        then
            return
        end
        local visible = desktop.visible(app)
        training.check_table(
            app,
            count_view.build(current.snapshot.game, visible, current.snapshot.count_settings)
        )
        if kind == "check_true_count" then
            app.trainer.answer_kind = "true_count"
        end
        return
    elseif kind == "count_settings_page" then
        ui.page_origins = ui.page_origins or {}
        ui.page_origins.count_settings = ui.page
        ui.page, ui.focus = "count_settings", 1
        return
    elseif settings_category == "count_preferences" then
        settings.change(current, kind)
        return
    end
    if kind == "menu" then
        ui.menu_origin = ui.page == "welcome" and "welcome" or "table"
        ui.page, ui.focus = "menu", 1
        return
    elseif kind == "home" then
        if current.pending and app.pending_training_answer then
            return
        end
        ui.page, ui.focus = "welcome", 1
        return
    elseif kind == "play" then
        ui.page, ui.focus = "table", current.snapshot.game.phase == "betting" and 2 or 1
        return
    elseif kind == "help" then
        ui.help_origin = ui.page
        ui.page, ui.focus = "help", 1
        return
    elseif kind == "back" then
        if education.buttons(app) then
            education.activate(app, "education_back")
            return
        end
        ui.page, ui.focus =
            ui.page == "help" and (ui.help_origin or "welcome")
                or ui.page == "menu" and (ui.menu_origin or "table")
                or (ui.page_origins and ui.page_origins[ui.page])
                or "menu",
            1
        if ui.page == "table" and current.snapshot.game.phase == "betting" then
            ui.focus = 2
        end
        return
    elseif kind == "rules_page" then
        ui.page_origins = ui.page_origins or {}
        ui.page_origins.rules = ui.page
        ui.page, ui.focus = "rules", 1
        return
    elseif kind == "statistics_page" then
        ui.page_origins = ui.page_origins or {}
        if ui.page ~= "training_statistics" then
            ui.page_origins.statistics = ui.page
        end
        ui.page, ui.focus = "statistics", 1
        return
    elseif kind == "training_statistics_page" then
        ui.page_origins = ui.page_origins or {}
        ui.page_origins.training_statistics = (ui.page_origins.statistics or "menu")
        ui.page, ui.focus = "training_statistics", 1
        return
    elseif kind == "save_folder" then
        native.open_save_folder()
        return
    end
    if presentation.busy(app.presentation) and settings_category ~= "preferences" then
        return
    end
    if
        kind == "bet_down"
        or kind == "bet_up"
        or kind == "chip_5"
        or kind == "chip_10"
        or kind == "chip_25"
    then
        if current.snapshot.game.phase ~= "betting" or current.pending then
            return
        end
        local change = kind == "bet_down" and -50
            or kind == "chip_10" and 100
            or kind == "chip_25" and 250
            or 50
        local maximum = math.min(1000, math.floor(current.snapshot.game.bankroll_units / 50) * 50)
        ui.bet_units = math.max(50, math.min(maximum, ui.bet_units + change))
        audio.play(app.tone, change < 0 and "chip_down" or "chip_up", current.snapshot.settings)
        return
    end
    local accepted
    if settings_category then
        accepted = settings.change(current, kind)
    else
        accepted =
            session.command(current, kind, kind == "deal" and { bet_units = ui.bet_units } or nil)
        if accepted then
            app.presentation = app.presentation or presentation.new(before)
            presentation.begin(
                app.presentation,
                before,
                player_view.build(current),
                kind,
                current.snapshot.settings.reduced_motion
            )
            ui.focus, ui.inspect_hand =
                1, current.snapshot.game.round and current.snapshot.game.round.active_hand or 1
            if current.snapshot.game.phase == "betting" then
                ui.focus = 2
            end
            if kind == "deal" or kind == "double" or kind == "split" then
                audio.play(app.tone, "chips", current.snapshot.settings)
            end
        end
        if not accepted and current.pending then
            app.pending_kind = kind
            ui.focus = 1
        end
    end
    if accepted then
        if not current.snapshot.settings.sound_enabled or current.snapshot.settings.volume == 0 then
            audio.stop(app.tone)
        end
        if not presentation.busy(app.presentation) then
            audio.play(app.tone, "button", current.snapshot.settings)
        end
        play_pending_sounds(app)
        if current.snapshot.game.phase == "betting" then
            ui.bet_units = math.max(
                50,
                math.min(ui.bet_units, math.floor(current.snapshot.game.bankroll_units / 50) * 50)
            )
        end
    end
end

function desktop.intent(app, intent)
    if not intent then
        return
    end
    local ui = app.ui
    if education.intent(app, intent) then
        return
    end
    if ui.page == "training" then
        if intent == "menu" or intent == "back" then
            desktop.activate(app, "home")
            return
        end
        if training.intent(app, intent) then
            return
        end
    end
    if intent == "menu" or intent == "back" then
        if not app.session.snapshot then
            love.event.quit()
            return
        end
        if ui.page == "welcome" and intent == "back" then
            return
        end
        desktop.activate(app, (ui.page == "table" or ui.page == "welcome") and "menu" or "back")
    elseif intent == "previous" or intent == "next" then
        local buttons, direction = desktop.buttons(app), intent == "next" and 1 or -1
        for _ = 1, #buttons do
            ui.focus = (ui.focus - 1 + direction) % #buttons + 1
            if buttons[ui.focus].enabled then
                break
            end
        end
        if app.session.snapshot then
            audio.play(app.tone, "navigation", app.session.snapshot.settings)
        end
    elseif intent == "confirm" then
        if ui.page == "table" and presentation.busy(app.presentation) then
            presentation.finish(app.presentation)
            play_pending_sounds(app)
            return
        end
        local button = desktop.buttons(app)[ui.focus]
        if button and button.enabled then
            desktop.activate(app, button.kind)
        end
    elseif intent == "inspect_previous" or intent == "inspect_next" then
        local visible = desktop.visible(app)
        if visible.phase == "round_result" then
            ui.inspect_hand = (ui.inspect_hand - 1 + (intent == "inspect_next" and 1 or -1))
                    % #visible.hands
                + 1
        end
    elseif ui.page == "table" then
        local visible = desktop.visible(app)
        if visible.legal and visible.legal[intent] then
            desktop.activate(app, intent)
        end
    end
end

function desktop.mouse(app, x, y)
    if app.ui.page == "table" and x >= 548 and y >= 12 and y <= 58 then
        desktop.activate(app, "menu")
        return
    end
    for index, button in ipairs(desktop.buttons(app)) do
        if button.enabled and components.contains(button, x, y) then
            app.ui.focus = index
            desktop.activate(app, button.kind)
            return
        end
    end
end

function desktop.update(app, elapsed)
    if app.presentation and app.ui.page == "table" then
        if app.session.snapshot and app.session.snapshot.settings.reduced_motion then
            presentation.finish(app.presentation)
        else
            presentation.update(app.presentation, elapsed)
        end
        play_pending_sounds(app)
    end
    training.update(app, elapsed)
    if app.smoke then
        smoke.update(app, elapsed, desktop.activate)
    end
end

function desktop.draw(app)
    local visible = desktop.visible(app)
    if app.session.snapshot and education.draw(app, visible) then
        if app.smoke then
            smoke.draw(app.smoke)
        end
        return
    elseif app.ui.page == "training" and app.trainer then
        training_screen.draw(
            app.fonts,
            app.trainer,
            app.ui,
            visible.training.strategy,
            app.session.pending ~= nil,
            app.session.message
        )
    elseif app.ui.page == "table" or visible.error then
        table_screen.draw(app.fonts, visible, app.ui)
        if not visible.error then
            app.ui.table_seen = true
        end
    elseif app.ui.page == "welcome" or app.ui.page == "help" then
        welcome_screen.draw(app.fonts, visible, app.ui)
    else
        menu_screen.draw(app.fonts, visible, app.ui)
    end
    if app.smoke then
        smoke.draw(app.smoke)
    end
end

function desktop.quit(app)
    if not app then
        return
    end
    audio.stop(app.tone)
    if app.smoke then
        smoke.report(app)
    end
end

return desktop
