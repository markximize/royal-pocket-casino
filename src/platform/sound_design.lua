-- PURPOSE: Synthesize short original casino sounds from explicit, fixed recipes.
-- CHANGE THIS MODULE WHEN: Paper texture, chip resonance or quiet result tones change.
-- DO NOT PUT HERE: LÖVE sources, gameplay outcomes, music or the game's random generator.

local sound_design = { sample_rate = 16000 }
local two_pi = 2 * math.pi

-- ## SMALL ORIGINAL SOUND PALETTE

sound_design.recipes = {
    { name = "card", kind = "paper", duration = 0.09, variants = 3, level = 0.11 },
    { name = "flip", kind = "paper", duration = 0.13, variants = 2, level = 0.10 },
    { name = "chips", kind = "chip", duration = 0.15, variants = 2, frequency = 1180 },
    { name = "chip_up", kind = "chip", duration = 0.12, variants = 2, frequency = 1320 },
    { name = "chip_down", kind = "chip", duration = 0.12, variants = 2, frequency = 1040 },
    { name = "payout", kind = "chip", duration = 0.27, variants = 1, frequency = 1120 },
    { name = "button", kind = "click", duration = 0.035, variants = 1, frequency = 560 },
    { name = "navigation", kind = "click", duration = 0.028, variants = 1, frequency = 480 },
    { name = "win", kind = "tone", duration = 0.26, variants = 1, notes = { 246.94, 293.66 } },
    { name = "loss", kind = "tone", duration = 0.19, variants = 1, notes = { 164.81 } },
    { name = "push", kind = "tone", duration = 0.15, variants = 1, notes = { 220 } },
    { name = "bust", kind = "tone", duration = 0.18, variants = 1, notes = { 130.81 } },
    {
        name = "blackjack",
        kind = "tone",
        duration = 0.42,
        variants = 1,
        notes = { 261.63, 329.63, 392 },
    },
}

local function recipe_named(name)
    for index, recipe in ipairs(sound_design.recipes) do
        if recipe.name == name then
            return recipe, index
        end
    end
end

local function chip_sample(recipe, time, variation, noise)
    local value = 0
    local impacts = recipe.name == "payout" and 4 or 2
    for impact = 1, impacts do
        local age = time - (impact - 1) * 0.035
        if age >= 0 then
            local frequency = recipe.frequency * (1 + variation * 0.018 + impact * 0.012)
            local resonance = 0.48 * math.sin(two_pi * frequency * age)
                + 0.32 * math.sin(two_pi * frequency * 1.67 * age)
                + 0.20 * math.sin(two_pi * frequency * 2.43 * age)
            local attack = math.min(1, age / 0.0015)
            value = value + (resonance + noise * 0.08) * attack * math.exp(-34 * age) * 0.09
        end
    end
    return value
end

local function tone_sample(recipe, time)
    local note_duration = recipe.duration / #recipe.notes
    local note_index = math.min(#recipe.notes, math.floor(time / note_duration) + 1)
    local age = time - (note_index - 1) * note_duration
    local frequency = recipe.notes[note_index]
    local attack = math.min(1, age / 0.008)
    local release = math.min(1, (note_duration - age) / 0.012)
    local resonance = 0.88 * math.sin(two_pi * frequency * age)
        + 0.12 * math.sin(two_pi * frequency * 2 * age)
    return resonance * attack * release * math.exp(-9 * age) * 0.075
end

-- ## DETERMINISTIC SAMPLE GENERATION

function sound_design.generate(name, variant)
    local recipe, recipe_index = recipe_named(name)
    variant = variant or 1
    if not recipe then
        return nil, "Unknown sound recipe"
    end
    if
        type(variant) ~= "number"
        or variant % 1 ~= 0
        or variant < 1
        or variant > recipe.variants
    then
        return nil, "Unknown sound variant"
    end
    local count = math.floor(recipe.duration * sound_design.sample_rate)
    local samples, low_pass, body = {}, 0, 0
    local seed = recipe_index * 7919 + variant * 104729
    for index = 0, count - 1 do
        -- Local noise is reproducible and never advances the shoe's random stream.
        seed = (seed * 48271) % 2147483647
        local noise = seed / 2147483647 * 2 - 1
        low_pass = low_pass + 0.35 * (noise - low_pass)
        body = body + 0.05 * (noise - body)
        local time = index / sound_design.sample_rate
        local value
        if recipe.kind == "paper" then
            local envelope = math.sin(math.pi * index / (count - 1)) ^ 1.5
            value = (low_pass - body) * envelope * recipe.level
        elseif recipe.kind == "chip" then
            value = chip_sample(recipe, time, variant - 1, noise)
        elseif recipe.kind == "click" then
            local resonance = math.sin(two_pi * recipe.frequency * time) * 0.6
            value = (resonance + (noise - low_pass) * 0.4) * math.exp(-160 * time) * 0.045
        else
            value = tone_sample(recipe, time)
        end
        -- Short fades prevent a click when a cached source starts or ends.
        local fade = math.min(1, time / 0.002, (count - 1 - index) / 128)
        samples[index + 1] = value * fade
    end
    return samples
end

return sound_design
