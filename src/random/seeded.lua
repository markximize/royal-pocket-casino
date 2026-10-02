-- PURPOSE: Implement versioned Park-Miller randomness for reproducible shoes.
-- CHANGE THIS MODULE WHEN: The algorithm or bounded-draw contract changes.
-- DO NOT PUT HERE: OS seeding, game rules, rendering or cryptographic claims.

local seeded = { modulus = 2147483647, algorithm_id = "park_miller", version = 1 }
local multiplier = 16807

function seeded.new(seed)
    assert(type(seed) == "number" and seed == math.floor(seed))
    assert(seed >= 1 and seed < seeded.modulus)
    return {
        algorithm_id = seeded.algorithm_id,
        version = seeded.version,
        initial_seed = seed,
        state = seed,
    }
end

function seeded.next_state(generator)
    -- The product is below 2^46, so Lua 5.1 doubles represent it exactly.
    generator.state = generator.state * multiplier % seeded.modulus
    return generator.state
end

function seeded.next_integer(generator, minimum, maximum)
    local range = maximum - minimum + 1
    assert(range >= 1 and range <= seeded.modulus - 1)
    local population = seeded.modulus - 1
    local acceptance_limit = population - population % range
    local sample
    repeat
        sample = seeded.next_state(generator) - 1
    until sample < acceptance_limit
    return minimum + sample % range
end

return seeded
