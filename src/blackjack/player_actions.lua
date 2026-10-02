-- PURPOSE: Validate and apply Hit, Stand, Double and Split to the current hand.
-- CHANGE THIS MODULE WHEN: Funding, split restrictions or action legality changes.
-- DO NOT PUT HERE: Dealer play, settlement, files or input bindings.

local cards = require("src.blackjack.cards")
local hand = require("src.blackjack.hand")
local shoe = require("src.blackjack.shoe")
local player_actions = {}

function player_actions.legal(game)
    if game.phase ~= "player_turn" then
        return {}
    end
    local current = game.round.hands[game.round.active_hand]
    local evaluated = hand.evaluate(current.cards, current.from_split)
    if current.status ~= "playing" or evaluated.total >= 21 then
        return {}
    end
    local funded = game.bankroll_units >= current.stake_units
    local double_total_allowed = game.rules.double_rule == "any_two"
        or (game.rules.double_rule == "9_to_11" and evaluated.total >= 9 and evaluated.total <= 11)
        or (
            game.rules.double_rule == "10_to_11"
            and evaluated.total >= 10
            and evaluated.total <= 11
        )
    return {
        hit = true,
        stand = true,
        double = #current.cards == 2
            and funded
            and not current.split_aces
            and double_total_allowed
            and (not current.from_split or game.rules.double_after_split),
        split = #current.cards == 2
            and funded
            and #game.round.hands < game.rules.max_hands
            and not current.split_aces
            and cards.rank(current.cards[1]) == cards.rank(current.cards[2]),
    }
end

function player_actions.draw_to_hand(game, player_hand)
    local card_id = shoe.draw(game.shoe)
    if not card_id then
        return false
    end
    player_hand.cards[#player_hand.cards + 1] = card_id
    if
        hand.evaluate(player_hand.cards, player_hand.from_split).total >= 21
        or player_hand.split_aces
    then
        player_hand.status = "finished"
    end
    return true
end

local function split(game, current)
    local split_aces = cards.rank(current.cards[1]) == 1
    local first = hand.new({ current.cards[1] }, current.stake_units, true, split_aces)
    local second = hand.new({ current.cards[2] }, current.stake_units, true, split_aces, "pending")
    game.bankroll_units = game.bankroll_units - current.stake_units
    game.round.hands[game.round.active_hand] = first
    table.insert(game.round.hands, game.round.active_hand + 1, second)
    return player_actions.draw_to_hand(game, first)
end

function player_actions.apply(game, action)
    local current = game.round.hands[game.round.active_hand]
    local count_name = action .. "_actions"
    game.round.action_counts[count_name] = game.round.action_counts[count_name] + 1
    if action == "stand" then
        current.status = "finished"
        return true
    elseif action == "split" then
        return split(game, current)
    elseif action == "double" then
        game.bankroll_units = game.bankroll_units - current.stake_units
        current.stake_units = current.stake_units * 2
        current.doubled = true
        local drawn = player_actions.draw_to_hand(game, current)
        current.status = "finished"
        return drawn
    end
    return player_actions.draw_to_hand(game, current)
end

return player_actions
