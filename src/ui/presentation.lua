-- PURPOSE: Reveal already-committed visible cards at a readable pace.
-- CHANGE THIS MODULE WHEN: Deal, flip or dealer pacing changes.
-- DO NOT PUT HERE: Drawing from the shoe, payouts, saving or hidden-hole lookup.

local copy = require("src.plain_copy")
local hand = require("src.blackjack.hand")
local presentation = {}

function presentation.new(visible)
    return { displayed = copy(visible), steps = {}, index = 1, elapsed = 0, sounds = {} }
end

function presentation.busy(current)
    return current and current.final ~= nil
end

local function refresh_totals(visible)
    for _, player in ipairs(visible.hands) do
        local evaluated = hand.evaluate(player.cards, player.from_split)
        player.total = #player.cards > 0 and evaluated.total or nil
        player.soft, player.bust, player.natural = evaluated.soft, evaluated.bust, evaluated.natural
    end
    local dealer_ids = {}
    for _, card in ipairs(visible.dealer.cards) do
        if card.hidden then
            visible.dealer.total = nil
            return
        end
        dealer_ids[#dealer_ids + 1] = card.id
    end
    visible.dealer.total = #dealer_ids > 0 and hand.evaluate(dealer_ids, false).total or nil
end

local function outcome_sound(visible)
    if not visible.result then
        return nil
    end
    if visible.result.void then
        return "button"
    end
    if visible.result.net_units > 0 then
        for _, result in ipairs(visible.result.hands) do
            if result.outcome == "blackjack" then
                return "blackjack"
            end
        end
        return "win"
    elseif visible.result.net_units < 0 then
        local all_bust = #visible.hands > 0
        for _, player in ipairs(visible.hands) do
            all_bust = all_bust and player.bust
        end
        if all_bust then
            return "bust"
        end
        return "loss"
    end
    return "push"
end

function presentation.finish(current)
    if not current.final then
        return
    end
    current.displayed = copy(current.final)
    current.final, current.steps, current.active = nil, {}, nil
    local sound = outcome_sound(current.displayed)
    if sound then
        current.sounds[#current.sounds + 1] = sound
        if not current.displayed.result.void and current.displayed.result.net_units > 0 then
            current.sounds[#current.sounds + 1] = "payout"
        end
    end
end

local function enqueue(current, kind, card, player_index)
    current.steps[#current.steps + 1] = {
        kind = kind,
        card = copy(card),
        player_index = player_index,
        duration = kind == "flip" and 0.28 or 0.24,
    }
end

local function wager_total(visible)
    local total = 0
    for _, player in ipairs(visible.hands or {}) do
        total = total + player.stake_units
    end
    return total
end

-- ## BUILD A PRESENTATION FROM FILTERED VIEWS

function presentation.begin(current, before, after, command, reduced_motion)
    current.sounds, current.steps, current.index, current.elapsed = {}, {}, 1, 0
    current.active, current.final = nil, copy(after)
    if reduced_motion or before.error or after.error or after.phase == "betting" then
        presentation.finish(current)
        return
    end
    local displayed = copy(after)
    displayed.animating, displayed.result, displayed.legal = true, nil, {}
    displayed.statistics = copy(before.statistics)
    local added_stake = command == "deal" and wager_total(after)
        or wager_total(after) - wager_total(before)
    displayed.bankroll_units = before.bankroll_units - math.max(0, added_stake)
    displayed.dealer = { cards = command == "deal" and {} or copy(before.dealer.cards) }
    current.displayed = displayed
    local known_cards = {}
    if command ~= "deal" then
        for _, player in ipairs(before.hands) do
            for _, id in ipairs(player.cards) do
                known_cards[id] = true
            end
        end
    end
    for _, player in ipairs(displayed.hands) do
        player.cards = {}
    end
    if command == "deal" then
        for index = 1, 2 do
            if after.hands[1].cards[index] then
                enqueue(current, "player", after.hands[1].cards[index], 1)
            end
            if after.dealer.cards[index] then
                enqueue(
                    current,
                    "dealer",
                    index == 2 and { hidden = true } or after.dealer.cards[index]
                )
            end
        end
    else
        for index, player in ipairs(after.hands) do
            for _, id in ipairs(player.cards) do
                if known_cards[id] then
                    displayed.hands[index].cards[#displayed.hands[index].cards + 1] = id
                else
                    enqueue(current, "player", id, index)
                end
            end
        end
    end
    if
        after.dealer.cards[2]
        and not after.dealer.cards[2].hidden
        and (command == "deal" or (before.dealer.cards[2] and before.dealer.cards[2].hidden))
    then
        enqueue(current, "flip", after.dealer.cards[2])
    end
    for index = 3, #after.dealer.cards do
        enqueue(current, "dealer", after.dealer.cards[index])
    end
    refresh_totals(displayed)
    if #current.steps == 0 then
        presentation.finish(current)
    end
end

local function start_step(current)
    local step = current.steps[current.index]
    if not step then
        presentation.finish(current)
        return
    end
    current.active = step
    if step.kind == "player" then
        local player = current.displayed.hands[step.player_index]
        player.cards[#player.cards + 1] = step.card
        step.card_index = #player.cards
    elseif step.kind == "dealer" then
        local cards = current.displayed.dealer.cards
        cards[#cards + 1] = step.card
        step.card_index = #cards
    else
        step.card_index = 2
    end
    current.sounds[#current.sounds + 1] = step.kind == "flip" and "flip" or "card"
    refresh_totals(current.displayed)
end

function presentation.update(current, elapsed)
    if not presentation.busy(current) then
        return
    end
    current.elapsed = current.elapsed + elapsed
    while presentation.busy(current) do
        if not current.active then
            start_step(current)
        end
        if not current.active then
            break
        end
        local step = current.active
        step.progress = math.min(1, current.elapsed / step.duration)
        if step.kind == "flip" and step.progress >= 0.5 then
            current.displayed.dealer.cards[2] = copy(step.card)
            refresh_totals(current.displayed)
        end
        if current.elapsed < step.duration then
            break
        end
        current.elapsed = current.elapsed - step.duration
        current.index, current.active = current.index + 1, nil
    end
end

function presentation.view(current, authoritative)
    if not presentation.busy(current) then
        return authoritative
    end
    local visible = copy(current.displayed)
    visible.animation = copy(current.active)
    return visible
end

function presentation.sounds(current)
    local sounds = current.sounds
    current.sounds = {}
    return sounds
end

return presentation
