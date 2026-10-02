-- PURPOSE: Validate bounded integer chip units and exact payout arithmetic.
-- CHANGE THIS MODULE WHEN: Chip scale, bounds or payout divisibility changes.
-- DO NOT PUT HERE: Currency symbols, rendering or account balances.

local chips = { scale = 10, maximum = 1000000000000, minimum_bet = 50, maximum_bet = 1000 }

function chips.is_integer(value, minimum, maximum)
    return type(value) == "number"
        and value == value
        and value == math.floor(value)
        and value >= minimum
        and value <= maximum
end

function chips.add(left, right)
    assert(chips.is_integer(left, -chips.maximum, chips.maximum))
    assert(chips.is_integer(right, -chips.maximum, chips.maximum))
    local sum = left + right
    assert(math.abs(sum) <= chips.maximum, "Chip unit limit exceeded")
    return sum
end

function chips.return_units(stake_units, outcome)
    assert(chips.is_integer(stake_units, 1, chips.maximum / 5))
    if outcome == "blackjack" then
        assert(stake_units % 2 == 0, "Natural payout must be exact")
        return stake_units * 5 / 2
    elseif outcome == "win" then
        return stake_units * 2
    elseif outcome == "push" then
        return stake_units
    end
    assert(outcome == "loss")
    return 0
end

function chips.valid_bet(bet_units)
    return chips.is_integer(bet_units, chips.minimum_bet, chips.maximum_bet) and bet_units % 50 == 0
end

return chips
