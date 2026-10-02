-- PURPOSE: Cache original sounds and limit quiet playback through the LÖVE adapter.
-- CHANGE THIS MODULE WHEN: Audio availability, volume, cooldowns or voice limits change.
-- DO NOT PUT HERE: Game outcomes, downloaded recordings or money arithmetic.

local sound_design = require("src.platform.sound_design")
local audio = {}
local voice_limit = 4

local function love_adapter()
    return {
        new_data = function(count)
            return love.sound.newSoundData(count, sound_design.sample_rate, 16, 1)
        end,
        new_source = function(samples)
            return love.audio.newSource(samples, "static")
        end,
        now = function()
            return love.timer.getTime()
        end,
    }
end

local function playback_policy(name)
    if name == "card" or name == "flip" then
        return "paper", 0.04, 1
    elseif name == "chips" or name == "chip_up" or name == "chip_down" then
        return "chips", 0.05, 1
    elseif name == "button" or name == "navigation" then
        return "interface", 0.04, 0
    elseif name == "payout" then
        return "payout", 0.15, 2
    end
    return "outcome", 0.15, 3
end

-- ## BUILD ONCE, PLAY CACHED SOURCES

function audio.new(adapter)
    adapter = adapter or love_adapter()
    local bank = { events = {}, sources = {}, last_play = {}, sequence = 0, now = adapter.now }
    local created, reason = pcall(function()
        for _, recipe in ipairs(sound_design.recipes) do
            local event = { voices = {}, next_variant = 1 }
            bank.events[recipe.name] = event
            for variant = 1, recipe.variants do
                local values = assert(sound_design.generate(recipe.name, variant))
                local samples = adapter.new_data(#values)
                -- Lua arrays start at 1; LÖVE sample positions start at 0.
                for index, value in ipairs(values) do
                    samples:setSample(index - 1, value)
                end
                local voice = { source = adapter.new_source(samples), priority = 0, sequence = 0 }
                event.voices[#event.voices + 1] = voice
                bank.sources[#bank.sources + 1] = voice
            end
        end
    end)
    if not created then
        audio.stop(bank)
        print("Audio unavailable: " .. tostring(reason))
        return nil, reason
    end
    return bank
end

local function available_variant(event)
    for offset = 0, #event.voices - 1 do
        local index = (event.next_variant + offset - 1) % #event.voices + 1
        if not event.voices[index].source:isPlaying() then
            event.next_variant = index % #event.voices + 1
            return event.voices[index]
        end
    end
end

local function reserve_voice(bank, priority)
    local playing, oldest_quiet_voice = 0, nil
    for _, voice in ipairs(bank.sources) do
        if voice.source:isPlaying() then
            playing = playing + 1
            if voice.priority < priority then
                if not oldest_quiet_voice or voice.sequence < oldest_quiet_voice.sequence then
                    oldest_quiet_voice = voice
                end
            end
        end
    end
    if playing < voice_limit then
        return true
    end
    -- A result remains audible after fast-forwarding several card animations.
    if oldest_quiet_voice then
        oldest_quiet_voice.source:stop()
        return true
    end
    return false
end

function audio.play(bank, name, settings)
    if not bank then
        return false, "unavailable"
    end
    if not settings or settings.sound_enabled ~= true or settings.volume == 0 then
        audio.stop(bank)
        return false, "muted"
    end
    local volume = settings.volume
    if type(volume) ~= "number" or volume ~= volume or volume < 0 or volume > 10 then
        return false, "invalid volume"
    end
    local event = bank.events[name]
    if not event then
        return false, "unknown event"
    end
    local played, accepted, reason = pcall(function()
        local group, cooldown, priority = playback_policy(name)
        local now = bank.now()
        if bank.last_play[group] and now - bank.last_play[group] < cooldown then
            return false, "cooldown"
        end
        local voice = available_variant(event)
        if not voice then
            return false, "busy"
        end
        if not reserve_voice(bank, priority) then
            return false, "voice limit"
        end
        voice.source:setVolume(volume / 10)
        voice.source:play()
        bank.sequence = bank.sequence + 1
        voice.priority, voice.sequence = priority, bank.sequence
        bank.last_play[group] = now
        return true
    end)
    if not played then
        print("Audio playback unavailable: " .. tostring(accepted))
        return false, "unavailable"
    end
    return accepted, reason
end

function audio.stop(bank)
    for _, voice in ipairs(bank and bank.sources or {}) do
        pcall(function()
            voice.source:stop()
        end)
    end
    if bank then
        bank.last_play = {}
    end
end

return audio
