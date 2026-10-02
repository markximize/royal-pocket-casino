-- PURPOSE: Teach Hi-Lo through a short fixed sequence before timed card practice.
-- CHANGE THIS MODULE WHEN: Beginner lessons or their explicit exercises change.
-- DO NOT PUT HERE: Random shoes, normal bankroll, save writes or controller drawing.
-- For Python learners: these ordered tables play the role of lists of dictionaries.

local cards = require("src.blackjack.cards")
local hi_lo = require("src.training.hi_lo")
local copy = require("src.plain_copy")
local tutorial = {}

local pages = {
    {
        stage = 1,
        title = "1 / 5  Hi-Lo tags",
        lines = {
            "2-6: +1     7-9: 0     10/J/Q/K/A: -1",
            "Start at zero after every shuffle.",
            "Count faces you can see; never the hidden hole card.",
        },
    },
    {
        stage = 1,
        title = "Tag a low card",
        card_ids = { 6 },
        lines = { "A low card leaving the shoe adds one." },
        exercise = { kind = "tag", prompt = "What is the Hi-Lo tag of 6?", unit = "tag" },
    },
    {
        stage = 1,
        title = "Tag a high card",
        card_ids = { 13 },
        lines = { "Tens, face cards and Aces subtract one." },
        exercise = { kind = "tag", prompt = "What is the Hi-Lo tag of King?", unit = "tag" },
    },
    {
        stage = 2,
        title = "2 / 5  Running Count",
        lines = {
            "Keep one total as exposed cards appear.",
            "5, King, 8: +1 -1 +0 = 0.",
            "A neutral 7, 8 or 9 leaves the count unchanged.",
        },
    },
    {
        stage = 2,
        title = "Keep the total",
        card_ids = { 2, 6, 12 },
        lines = { "Start at 0. Cards appear left to right: 2, 6, Queen." },
        exercise = { kind = "running", prompt = "What is the final running count?", unit = "RC" },
    },
    {
        stage = 2,
        title = "High and low cancel",
        card_ids = { 1, 3, 5, 13 },
        lines = { "Start at 0. Ace, 3, 5, King are exposed." },
        exercise = { kind = "running", prompt = "What is the final running count?", unit = "RC" },
    },
    {
        stage = 3,
        title = "3 / 5  Decks remaining",
        lines = {
            "Estimate from exposed cards only: 52 cards per deck.",
            "Round UP to the next half deck, minimum 0.5.",
            "About 2.8 decks becomes 3.0 decks.",
            "Enter half-deck steps: 6 steps means 3 decks.",
        },
    },
    {
        stage = 3,
        title = "Round the estimate upward",
        lines = {
            "Six decks start with 312 cards; 166 are exposed.",
            "146 cards remain: about 2.8 decks, rounded UP.",
            "Enter half-deck steps, not whole decks.",
        },
        exposed = 166,
        exercise = {
            kind = "half_decks",
            prompt = "How many half-deck steps remain?",
            unit = "steps",
        },
    },
    {
        stage = 3,
        title = "Keep a minimum half deck",
        lines = {
            "Six decks: 300 exposed cards leave just 12 cards.",
            "The divisor still has a minimum of 0.5 deck.",
            "One half-deck step means 0.5 deck.",
        },
        exposed = 300,
        exercise = {
            kind = "half_decks",
            prompt = "How many half-deck steps remain?",
            unit = "steps",
        },
    },
    {
        stage = 4,
        title = "4 / 5  True Count",
        lines = {
            "True Count = Running Count / estimated decks.",
            "Drop the fraction toward zero.",
            "+2.8 becomes +2; -2.8 becomes -2.",
            "This is truncation, not rounding to nearest.",
        },
    },
    {
        stage = 4,
        title = "Convert a positive count",
        lines = { "RC +7 / 2.5 estimated decks = +2.8.", "Drop the fraction toward zero." },
        running = 7,
        decks = 2.5,
        exercise = { kind = "true", prompt = "Enter the integer true count.", unit = "TC" },
    },
    {
        stage = 4,
        title = "Convert a negative count",
        lines = { "RC -7 / 2.5 estimated decks = -2.8.", "Move toward zero, not toward -3." },
        running = -7,
        decks = 2.5,
        exercise = { kind = "true", prompt = "Enter the integer true count.", unit = "TC" },
    },
    {
        stage = 5,
        title = "5 / 5  A table checkpoint",
        lines = {
            "Count player faces and the dealer upcard.",
            "A hidden card contributes nothing until revealed.",
            "Try two short checks, then enter the Count Trainer.",
        },
    },
    {
        stage = 5,
        title = "Leave the hole card out",
        card_ids = { 5, 6, 9 },
        hidden_card = true,
        lines = {
            "New shoe: player 5 + 6; dealer 9 and a card back.",
            "Only these three faces are exposed.",
        },
        exercise = { kind = "running", prompt = "Enter the exposed running count.", unit = "RC" },
    },
    {
        stage = 5,
        title = "Now the hole is revealed",
        card_ids = { 5, 6, 9, 1 },
        lines = {
            "The dealer reveals an Ace. Count it exactly once.",
            "This is the same shoe; do not restart at zero.",
        },
        exercise = { kind = "running", prompt = "Enter the new running count.", unit = "RC" },
    },
}

-- ## FIXED, PUBLIC EXERCISES

local function expected_answer(page)
    local kind = page.exercise.kind
    if kind == "tag" then
        return assert(hi_lo.tag(page.card_ids[1]))
    elseif kind == "half_decks" then
        return assert(hi_lo.estimate_decks(6, page.exposed)) * 2
    elseif kind == "true" then
        return assert(hi_lo.true_count(page.running, page.decks))
    end
    local observed = assert(hi_lo.observe(hi_lo.new(1), 1, page.card_ids))
    return observed.running_count
end

local function answer_explanation(page, expected)
    if page.exercise.kind == "half_decks" then
        return expected .. " half-deck steps = " .. (expected / 2) .. " estimated decks."
    elseif page.exercise.kind == "true" then
        return "Truncate "
            .. page.running
            .. " / "
            .. page.decks
            .. " toward zero: "
            .. expected
            .. "."
    end
    local labels = {}
    for _, card_id in ipairs(page.card_ids) do
        local tag = hi_lo.tag(card_id)
        local tag_label = tag > 0 and "+" .. tag or tostring(tag)
        labels[#labels + 1] = cards.rank_names[cards.rank(card_id)] .. " (" .. tag_label .. ")"
    end
    return table.concat(labels, ", ") .. " gives " .. expected .. "."
end

-- ## LESSON LIFECYCLE

function tutorial.new()
    return { index = 1, feedback = nil, complete = false }
end

function tutorial.current(state)
    if state.complete then
        return {
            title = "Ready to practice",
            lines = { "Beginner mode can show tags while you learn." },
            complete = true,
        }
    end
    local page = copy(pages[state.index])
    page.page_number = state.index
    page.page_count = #pages
    page.feedback = copy(state.feedback)
    return page
end

function tutorial.answer(state, answer)
    local page = pages[state.index]
    if state.complete or not page or not page.exercise then
        return nil, "This lesson does not ask for an answer."
    end
    if state.feedback then
        return copy(state.feedback)
    end
    if type(answer) ~= "number" or answer ~= math.floor(answer) or math.abs(answer) > 416 then
        return nil, "Enter a bounded whole-number answer."
    end
    local expected = expected_answer(page)
    state.feedback = {
        correct = answer == expected,
        expected = expected,
        explanation = answer_explanation(page, expected),
    }
    return copy(state.feedback)
end

function tutorial.advance(state)
    if state.complete then
        return false, "The tutorial is complete."
    end
    if pages[state.index].exercise and not state.feedback then
        return false, "Answer this short exercise before continuing."
    end
    state.index = state.index + 1
    state.feedback = nil
    state.complete = state.index > #pages
    return true
end

return tutorial
