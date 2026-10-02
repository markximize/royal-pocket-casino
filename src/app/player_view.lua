-- PURPOSE: Expose visible cards, readable totals and legal actions to UI.
-- CHANGE THIS MODULE WHEN: Information visibility or displayed fields change.
-- DO NOT PUT HERE: Hidden hole IDs, shoe order, state mutations or advice.

local copy = require("src.plain_copy")
local hand = require("src.blackjack.hand")
local player_actions = require("src.blackjack.player_actions")
local view = {}

function view.build(current)
    if not current.snapshot then
        return { error = current.message, pending = current.pending ~= nil }
    end
    local snapshot = current.snapshot
    local game = snapshot.game
    local visible = {
        phase = game.phase,
        bankroll_units = game.bankroll_units,
        rules = copy(game.rules),
        statistics = copy(snapshot.statistics),
        training = copy(snapshot.training),
        count_settings = copy(snapshot.count_settings),
        settings = copy(snapshot.settings),
        assistance = copy(snapshot.assistance),
        remaining_cards = #game.shoe.order - game.shoe.next_index + 1,
        shuffle_pending = game.shoe.shuffle_pending,
        message = current.message,
        pending = current.pending ~= nil,
        hands = {},
        dealer = { cards = {} },
        legal = player_actions.legal(game),
        revision = snapshot.revision,
    }
    if not game.round then
        return visible
    end
    visible.active_hand = game.round.active_hand
    visible.result = copy(game.round.result)
    for _, player_hand in ipairs(game.round.hands) do
        local evaluated = hand.evaluate(player_hand.cards, player_hand.from_split)
        local player = copy(player_hand)
        player.total, player.soft, player.bust, player.natural =
            evaluated.total, evaluated.soft, evaluated.bust, evaluated.natural
        visible.hands[#visible.hands + 1] = player
    end
    for index, card_id in ipairs(game.round.dealer.cards) do
        if index == 2 and not game.round.dealer.revealed then
            visible.dealer.cards[index] = { hidden = true }
        else
            visible.dealer.cards[index] = { id = card_id }
        end
    end
    if game.round.dealer.revealed then
        local evaluated = hand.evaluate(game.round.dealer.cards, false)
        visible.dealer.total, visible.dealer.soft = evaluated.total, evaluated.soft
    end
    return visible
end

return view
