-- PURPOSE: Coordinate deterministic round phases and automatic transitions.
-- CHANGE THIS MODULE WHEN: Dealing order, commands or phase boundaries change.
-- DO NOT PUT HERE: UI, OS randomness, JSON, save writes or payout formulas.

local copy = require("src.plain_copy")
local chips = require("src.blackjack.chips")
local cards = require("src.blackjack.cards")
local hand = require("src.blackjack.hand")
local rules = require("src.blackjack.rules")
local shoe = require("src.blackjack.shoe")
local player_actions = require("src.blackjack.player_actions")
local dealer = require("src.blackjack.dealer")
local settlement = require("src.blackjack.settlement")
local round = {}

function round.new(preset, generator, next_integer)
    assert(rules.validate(preset))
    local owned_generator = copy(generator)
    local initial_shoe = shoe.new(preset, owned_generator, next_integer)
    return {
        phase = "betting",
        bankroll_units = 10000,
        round_sequence = 0,
        command_sequence = 0,
        rules = copy(preset),
        rng = owned_generator,
        shoe = initial_shoe,
    }
end

function round.command(game, kind, fields)
    local command = copy(fields or {})
    command.kind = kind
    command.expected_sequence = game.command_sequence
    command.expected_round = game.round_sequence
    command.expected_hand = game.round and game.round.active_hand or 0
    return command
end

-- ## AUTOMATIC RESOLUTION

local function finish(game, is_void)
    local current_round = game.round
    current_round.dealer.revealed = true
    if is_void then
        game.bankroll_units = current_round.opening_bankroll_units
        current_round.result = { void = true, reason = "Shoe exhausted: round refunded" }
        game.shoe.shuffle_pending = true
    else
        current_round.result = settlement.summarize(current_round)
        game.bankroll_units = chips.add(game.bankroll_units, current_round.result.returned_units)
    end
    for _, player_hand in ipairs(current_round.hands) do
        player_hand.status = "finished"
    end
    game.phase = "round_result"
    shoe.finish_round(game.shoe)
end

local function advance(game)
    local current_round = game.round
    while current_round.active_hand <= #current_round.hands do
        local current = current_round.hands[current_round.active_hand]
        if current.status == "pending" then
            current.status = "playing"
            if not player_actions.draw_to_hand(game, current) then
                finish(game, true)
                return
            end
        end
        if current.status == "playing" then
            return
        end
        current_round.active_hand = current_round.active_hand + 1
    end
    -- Preserve a valid hand index for result inspection; it is no longer actionable.
    current_round.active_hand = #current_round.hands
    finish(game, not dealer.play(game))
end

local function deal(game, bet_units)
    game.round_sequence = game.round_sequence + 1
    game.round = {
        id = game.round_sequence,
        opening_bankroll_units = game.bankroll_units,
        active_hand = 1,
        initial_bet_units = bet_units,
        start_index = game.shoe.next_index,
        hands = { hand.new({}, bet_units) },
        dealer = { cards = {}, revealed = false },
        action_counts = {
            hit_actions = 0,
            stand_actions = 0,
            double_actions = 0,
            split_actions = 0,
        },
    }
    game.bankroll_units = game.bankroll_units - bet_units
    game.phase = "player_turn"
    for deal_index = 1, 4 do
        local recipient = deal_index % 2 == 1 and game.round.hands[1] or game.round.dealer
        local card_id = shoe.draw(game.shoe)
        if not card_id then
            finish(game, true)
            return
        end
        recipient.cards[#recipient.cards + 1] = card_id
    end
    local upcard_rank = cards.rank(game.round.dealer.cards[1])
    local peek = upcard_rank == 1 or upcard_rank >= 10
    if
        (peek and hand.evaluate(game.round.dealer.cards, false).natural)
        or hand.evaluate(game.round.hands[1].cards, false).natural
    then
        finish(game, false)
    end
end

-- ## COMMAND BOUNDARIES

local function validate_command(game, command)
    if
        type(command) ~= "table"
        or command.expected_sequence ~= game.command_sequence
        or command.expected_round ~= game.round_sequence
        or command.expected_hand ~= (game.round and game.round.active_hand or 0)
    then
        return false, "Stale or malformed command"
    end
    if
        game.command_sequence >= chips.maximum
        or game.round_sequence >= chips.maximum
        or game.shoe.generation >= chips.maximum
    then
        return false, "Sequence limit reached"
    end
    local kind = command.kind
    if game.phase == "player_turn" then
        if not player_actions.legal(game)[kind] then
            return false, "Action unavailable: " .. tostring(kind)
        end
    elseif kind == "next_round" then
        if game.phase ~= "round_result" then
            return false, "No round result to close"
        end
    elseif game.phase ~= "betting" then
        return false, "Finish the current round first"
    elseif kind == "deal" then
        if not chips.valid_bet(command.bet_units) or command.bet_units > game.bankroll_units then
            return false, "Choose a funded bet from 5 to 100 chips, in steps of 5"
        end
        if game.bankroll_units > chips.maximum - command.bet_units * 16 then
            return false, "Insufficient numeric headroom for a complete round"
        end
    elseif kind == "configure" then
        return rules.validate(command.rules)
    elseif kind == "refill" then
        if game.bankroll_units >= chips.minimum_bet then
            return false, "Free refill is available below the minimum bet, between rounds"
        end
    elseif kind ~= "shuffle" then
        return false, "Unknown command"
    end
    return true
end

function round.apply(game, command, next_integer)
    local allowed, reason = validate_command(game, command)
    if not allowed then
        return nil, reason
    end
    local candidate = copy(game)
    local effect = {}
    local kind = command.kind
    if candidate.phase == "player_turn" then
        if not player_actions.apply(candidate, kind) then
            finish(candidate, true)
        else
            advance(candidate)
        end
    elseif kind == "next_round" then
        candidate.phase, candidate.round = "betting", nil
    elseif kind == "deal" then
        if candidate.shoe.shuffle_pending then
            candidate.shoe = shoe.new(
                candidate.rules,
                candidate.rng,
                next_integer,
                candidate.shoe.generation + 1
            )
        end
        deal(candidate, command.bet_units)
    else
        if kind == "configure" then
            candidate.rules = copy(command.rules)
        elseif kind == "refill" then
            effect.grant_units = 10000 - candidate.bankroll_units
            candidate.bankroll_units = 10000
        end
        candidate.shoe =
            shoe.new(candidate.rules, candidate.rng, next_integer, candidate.shoe.generation + 1)
    end
    candidate.command_sequence = candidate.command_sequence + 1
    if candidate.phase == "round_result" and game.phase ~= "round_result" then
        effect.completed_round = candidate.round
    end
    return candidate, effect
end

return round
