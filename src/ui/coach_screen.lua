-- PURPOSE: Present decision evidence, wager observations and recent progress.
-- CHANGE THIS MODULE WHEN: Coach pages or readable summaries change.
-- DO NOT PUT HERE: Pattern thresholds, scoring, save writes or random praise.

local components = require("src.ui.components")
local screen = {}
local text, colors, amount = components.text, components.colors, components.amount
local titles = { "DECISION QUALITY", "BETTING BEHAVIOR", "RESULTS", "SESSION HISTORY" }

local function score_label(score)
    if score.attempts == 0 then
        return "—"
    end
    local percent = math.floor(100 * score.correct / score.attempts + 0.5)
    return string.format("%d%%  %d/%d", percent, score.correct, score.attempts)
end

function screen.draw(fonts, report, page, history_page, betting_page)
    components.background()
    text(fonts.title, "SESSION COACH", 24, 22, colors.gold)
    text(fonts.detail, titles[page] .. "  •  " .. page .. "/4", 24, 56, colors.muted)
    if page == 1 then
        text(fonts.body, "Good decisions can still lose. Wins do not prove skill.", 28, 101)
        local names = { "hard", "soft", "pair", "double", "deviation" }
        for index, name in ipairs(names) do
            local play, drills = report.decisions[name], report.practice[name]
            local combined = {
                attempts = play.attempts + drills.attempts,
                correct = play.correct + drills.correct,
            }
            text(fonts.body, name:upper() .. " play + drills", 30, 143 + (index - 1) * 29)
            text(
                fonts.body,
                score_label(combined),
                390,
                143 + (index - 1) * 29,
                colors.gold,
                210,
                "right"
            )
        end
        text(fonts.body, "Running / true-count practice", 30, 293)
        local count_label = "RC: " .. score_label(report.practice.running)
        count_label = count_label .. "    TC: " .. score_label(report.practice.true_count)
        text(fonts.body, count_label, 30, 320, colors.gold)
        text(
            fonts.small,
            "Doubles also belong to a hand category during play.",
            30,
            348,
            colors.muted
        )
        text(
            fonts.detail,
            report.recommendation and report.recommendation.message or report.message,
            30,
            365,
            colors.muted,
            575
        )
    elseif page == 2 then
        text(fonts.body, "Observed wagers: " .. report.betting.samples, 30, 101)
        text(
            fonts.detail,
            "Patterns describe behavior, not intent or guaranteed results.",
            30,
            133,
            colors.muted,
            575
        )
        if #report.betting.patterns == 0 then
            text(fonts.body, report.betting.message, 30, 182, colors.ivory, 575)
        else
            local index = math.min(betting_page or 1, #report.betting.patterns)
            local pattern = report.betting.patterns[index]
            text(fonts.body, pattern.message, 30, 182, colors.ivory, 570)
            text(
                fonts.detail,
                "L/R: observations  " .. index .. "/" .. #report.betting.patterns,
                30,
                305,
                colors.muted
            )
        end
        text(
            fonts.detail,
            "A bigger wager after a loss does not change the next hand's odds.",
            30,
            355,
            colors.gold,
            575
        )
    elseif page == 3 then
        local result = report.results
        local rows = {
            {
                "Rounds / wins / losses / pushes",
                result.rounds
                    .. " / "
                    .. result.wins
                    .. " / "
                    .. result.losses
                    .. " / "
                    .. result.pushes,
            },
            { "Natural Blackjacks", result.blackjacks },
            { "Net chips (grants excluded)", amount(result.net_units, true) },
            {
                "Biggest round win / loss",
                amount(result.biggest_win_units) .. " / " .. amount(result.biggest_loss_units),
            },
            {
                "Current / maximum drawdown",
                amount(result.drawdown_units) .. " / " .. amount(result.max_drawdown_units),
            },
            { "Win / loss streak", result.win_streak .. " / " .. result.loss_streak },
        }
        for index, row in ipairs(rows) do
            text(fonts.detail, row[1], 30, 115 + (index - 1) * 44, colors.muted)
            text(fonts.body, tostring(row[2]), 30, 132 + (index - 1) * 44)
        end
    else
        text(
            fonts.detail,
            "New session stores a summary; restarts keep the current session.",
            30,
            100,
            colors.muted,
            570
        )
        text(fonts.body, "SESSION     STRATEGY     COUNT     NET CHIPS", 30, 150, colors.gold)
        if #report.history == 0 then
            text(fonts.body, "No completed coaching sessions yet.", 30, 193)
        end
        local last = math.max(0, #report.history - (history_page - 1) * 7)
        local first = math.max(1, last - 6)
        text(fonts.detail, "L/R: older / newer history pages", 30, 385, colors.muted)
        for index = first, last do
            local row = report.history[index]
            local strategy = row.strategy.percent and row.strategy.percent .. "%" or "—"
            local count = row.counting.percent and row.counting.percent .. "%" or "—"
            text(fonts.body, string.format("%d", row.id), 30, 188 + (index - first) * 28)
            text(fonts.body, strategy, 188, 188 + (index - first) * 28)
            text(fonts.body, count, 338, 188 + (index - first) * 28)
            text(fonts.body, amount(row.net_units, true), 458, 188 + (index - first) * 28)
        end
    end
end

return screen
