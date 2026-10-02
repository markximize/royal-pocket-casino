-- PURPOSE: Validate card ownership, round legality and exact saved accounting.
-- CHANGE THIS MODULE WHEN: A game-state invariant or supported state changes.
-- DO NOT PUT HERE: Repairing invalid fields, rendering or file selection.

local check = require("src.check")
local rules = require("src.blackjack.rules")
local hand = require("src.blackjack.hand")
local player_actions = require("src.blackjack.player_actions")
local settlement = require("src.blackjack.settlement")
local chips = require("src.blackjack.chips")
local cards = require("src.blackjack.cards")
local dealer = require("src.blackjack.dealer")
local seeded = require("src.random.seeded")
local validation = {}

local function validate_shoe(game)
    local current = game.shoe
    local total = 52 * game.rules.deck_count
    if
        not check.object(current, {
            "deck_count",
            "order",
            "next_index",
            "discarded",
            "cut_position",
            "shuffle_pending",
            "generation",
        })
        or current.deck_count ~= game.rules.deck_count
        or not check.array(current.order, total)
        or #current.order ~= total
        or not check.array(current.discarded, total)
        or not check.integer(current.next_index, 1, total + 1)
        or not check.integer(current.generation, 1)
        or not check.boolean(current.shuffle_pending)
        or current.cut_position ~= math.floor(total * game.rules.penetration_percent / 100)
    then
        return false, "Invalid production shoe"
    end
    local membership = {}
    for _, card_id in ipairs(current.order) do
        if not check.integer(card_id, 1, total) or membership[card_id] then
            return false, "Duplicate or invalid physical card"
        end
        membership[card_id] = true
    end
    for index, card_id in ipairs(current.discarded) do
        if card_id ~= current.order[index] then
            return false, "Discarded cards do not match draw order"
        end
    end
    local discarded_expected = game.phase == "player_turn" and #current.discarded
        or current.next_index - 1
    if #current.discarded ~= discarded_expected or #current.discarded >= current.next_index then
        return false, "Invalid discard partition"
    end
    if current.next_index - 1 >= current.cut_position and not current.shuffle_pending then
        return false, "Crossed cut without pending shuffle"
    end
    return true
end

local function validate_hand(player_hand, add_card, allow_incomplete)
    if
        not check.object(
            player_hand,
            { "cards", "stake_units", "from_split", "split_aces", "doubled", "status" }
        )
        or not check.array(player_hand.cards, 22)
        or not check.integer(player_hand.stake_units, 50, 2000)
        or player_hand.stake_units % 50 ~= 0
        or not check.boolean(player_hand.from_split)
        or not check.boolean(player_hand.split_aces)
        or not check.boolean(player_hand.doubled)
        or (
            player_hand.status ~= "playing"
            and player_hand.status ~= "pending"
            and player_hand.status ~= "finished"
        )
    then
        return false
    end
    if player_hand.split_aces and not player_hand.from_split then
        return false
    end
    if not allow_incomplete then
        if player_hand.status == "pending" then
            if not player_hand.from_split or #player_hand.cards ~= 1 then
                return false
            end
        elseif #player_hand.cards < 2 then
            return false
        end
        if player_hand.split_aces and (#player_hand.cards ~= 2 or player_hand.doubled) then
            return false
        end
        if
            player_hand.doubled and (#player_hand.cards ~= 3 or player_hand.status ~= "finished")
        then
            return false
        end
    end
    for _, card_id in ipairs(player_hand.cards) do
        if not add_card(card_id) then
            return false
        end
    end
    if
        player_hand.split_aces
        and (#player_hand.cards == 0 or cards.rank(player_hand.cards[1]) ~= 1)
    then
        return false
    end
    return true
end

local function validate_round(game)
    local current = game.round
    if
        not check.object(current, {
            "id",
            "opening_bankroll_units",
            "active_hand",
            "hands",
            "initial_bet_units",
            "start_index",
            "dealer",
            "action_counts",
        }, { "result" })
        or current.id ~= game.round_sequence
        or not check.integer(current.opening_bankroll_units)
        or not chips.valid_bet(current.initial_bet_units)
        or not check.integer(current.start_index, 1, #game.shoe.order + 1)
        or not check.array(current.hands, 4)
        or #current.hands == 0
        or not check.integer(current.active_hand, 1, #current.hands)
        or not check.object(current.dealer, { "cards", "revealed" })
        or not check.array(current.dealer.cards, 22)
        or not check.boolean(current.dealer.revealed)
        or not check.object(
            current.action_counts,
            { "hit_actions", "stand_actions", "double_actions", "split_actions" }
        )
    then
        return false, "Malformed saved round"
    end
    for _, count in pairs(current.action_counts) do
        if not check.integer(count, 0, 512) then
            return false, "Invalid round action count"
        end
    end
    local is_void = game.phase == "round_result"
        and type(current.result) == "table"
        and current.result.void == true
    if current.action_counts.split_actions ~= #current.hands - 1 then
        return false, "Split count does not match final hands"
    end
    local round_cards, total_stakes, doubled_hands = {}, 0, 0
    local function add_card(card_id)
        if not check.integer(card_id, 1, #game.shoe.order) or round_cards[card_id] then
            return false
        end
        round_cards[card_id] = true
        return true
    end
    for index, player_hand in ipairs(current.hands) do
        if not validate_hand(player_hand, add_card, is_void) then
            return false, "Illegal saved player hand"
        end
        if
            player_hand.stake_units
                ~= current.initial_bet_units * (player_hand.doubled and 2 or 1)
            or player_hand.from_split ~= (#current.hands > 1)
        then
            return false, "Saved stake or split origin disagrees with initial bet"
        end
        if player_hand.doubled then
            doubled_hands = doubled_hands + 1
        end
        if game.phase == "player_turn" then
            local expected = index < current.active_hand and "finished"
                or index > current.active_hand and "pending"
                or "playing"
            if player_hand.status ~= expected then
                return false, "Current-hand progression is inconsistent"
            end
            if player_hand.split_aces then
                return false, "Split aces cannot remain in a player decision"
            end
        elseif player_hand.status ~= "finished" then
            return false, "Result contains an unfinished hand"
        end
        total_stakes = total_stakes + player_hand.stake_units
    end
    if doubled_hands ~= current.action_counts.double_actions then
        return false, "Double count disagrees with hands"
    end
    for _, card_id in ipairs(current.dealer.cards) do
        if not add_card(card_id) then
            return false, "Duplicate dealer card"
        end
    end
    local drawn, round_card_count = {}, 0
    for index = current.start_index, game.shoe.next_index - 1 do
        drawn[game.shoe.order[index]] = true
        round_card_count = round_card_count + 1
    end
    for card_id in pairs(round_cards) do
        if not drawn[card_id] then
            return false, "Round references an undealt card"
        end
        round_card_count = round_card_count - 1
    end
    if round_card_count ~= 0 or (not is_void and #current.dealer.cards < 2) then
        return false, "Round does not own exactly its drawn cards"
    end
    if game.phase == "player_turn" then
        for index = #game.shoe.discarded + 1, game.shoe.next_index - 1 do
            if not round_cards[game.shoe.order[index]] then
                return false, "Drawn card missing from active round"
            end
        end
        local card_count = 0
        for _ in pairs(round_cards) do
            card_count = card_count + 1
        end
        if
            card_count ~= game.shoe.next_index - 1 - #game.shoe.discarded
            or #current.dealer.cards ~= 2
            or current.dealer.revealed
            or current.result ~= nil
            or not player_actions.legal(game).hit
            or hand.evaluate(current.dealer.cards, false).natural
            or game.bankroll_units ~= current.opening_bankroll_units - total_stakes
        then
            return false, "Illegal active round or escrow"
        end
    else
        if not current.dealer.revealed or type(current.result) ~= "table" then
            return false, "Missing revealed result"
        end
        if is_void then
            if
                not check.object(current.result, { "void", "reason" })
                or current.result.reason ~= "Shoe exhausted: round refunded"
                or game.bankroll_units ~= current.opening_bankroll_units
                or not game.shoe.shuffle_pending
            then
                return false, "Invalid void refund"
            end
        else
            if dealer.should_draw(current, game.rules) then
                return false, "Dealer settled before completing its required draws"
            end
            local expected = settlement.summarize(current)
            if
                not check.object(
                    current.result,
                    { "hands", "staked_units", "returned_units", "net_units", "void" }
                )
                or not check.array(current.result.hands, 4)
                or #current.result.hands ~= #expected.hands
            then
                return false, "Invalid settlement summary"
            end
            for name, value in pairs(expected) do
                if name ~= "hands" and current.result[name] ~= value then
                    return false, "Settlement totals disagree with cards"
                end
            end
            for index, row in ipairs(expected.hands) do
                if
                    not check.object(
                        current.result.hands[index],
                        { "outcome", "stake_units", "return_units", "natural", "bust" }
                    )
                then
                    return false, "Invalid hand result"
                end
                for name, value in pairs(row) do
                    if current.result.hands[index][name] ~= value then
                        return false, "Saved payout disagrees with cards"
                    end
                end
            end
            if game.bankroll_units ~= current.opening_bankroll_units + expected.net_units then
                return false, "Settled bankroll disagrees with returns"
            end
        end
    end
    return true
end

function validation.validate(game)
    if
        not check.object(game, {
            "phase",
            "bankroll_units",
            "round_sequence",
            "command_sequence",
            "rules",
            "rng",
            "shoe",
        }, { "round" })
        or not check.integer(game.bankroll_units)
        or not check.integer(game.round_sequence)
        or not check.integer(game.command_sequence)
        or game.round_sequence > game.command_sequence
    then
        return false, "Invalid game fields or counters"
    end
    local rules_ok, reason = rules.validate(game.rules)
    if not rules_ok then
        return false, reason
    end
    if
        not check.object(game.rng, { "algorithm_id", "version", "initial_seed", "state" })
        or game.rng.algorithm_id ~= seeded.algorithm_id
        or game.rng.version ~= seeded.version
        or not check.integer(game.rng.initial_seed, 1, seeded.modulus - 1)
        or not check.integer(game.rng.state, 1, seeded.modulus - 1)
        or (
            game.phase ~= "betting"
            and game.phase ~= "player_turn"
            and game.phase ~= "round_result"
        )
    then
        return false, "Unsupported RNG or phase"
    end
    local shoe_ok, shoe_reason = validate_shoe(game)
    if not shoe_ok then
        return false, shoe_reason
    end
    if game.phase == "betting" then
        return game.round == nil, "Betting state must not contain a round"
    end
    return validate_round(game)
end

return validation
