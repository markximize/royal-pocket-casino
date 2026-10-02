-- PURPOSE: Check original sound bounds, cached playback and public result cues.
-- CHANGE THIS MODULE WHEN: Sound recipes or presentation event contracts change.
-- DO NOT PUT HERE: Subjective listening claims or physical-device audio approval.

local test = require("tests.harness")
local audio = require("src.platform.audio")
local design = require("src.platform.sound_design")
local presentation = require("src.ui.presentation")
local view = require("src.app.player_view")
local fixtures = require("tests.fixtures")
local copy = require("src.plain_copy")
local scenarios = {}
local settings = { sound_enabled = true, volume = 6 }

local function playback_fixture()
    local clock, sources, allocations = { time = 0 }, {}, { data = 0, writes = 0 }
    local bank = audio.new({
        now = function()
            return clock.time
        end,
        new_data = function(count)
            allocations.data = allocations.data + 1
            return {
                setSample = function(_, index)
                    assert(index >= 0 and index < count)
                    allocations.writes = allocations.writes + 1
                end,
            }
        end,
        new_source = function()
            local source = { playing = false, plays = 0, stops = 0 }
            function source:isPlaying()
                return self.playing
            end
            function source:play()
                self.playing, self.plays = true, self.plays + 1
            end
            function source:stop()
                self.playing, self.stops = false, self.stops + 1
            end
            function source:setVolume(volume)
                self.volume = volume
            end
            sources[#sources + 1] = source
            return source
        end,
    })
    return bank, clock, sources, allocations
end

local function playing_count(sources)
    local count = 0
    for _, source in ipairs(sources) do
        if source.playing then
            count = count + 1
        end
    end
    return count
end

local function public_view(game)
    return view.build({
        snapshot = { game = game, statistics = {}, settings = settings, revision = 1 },
    })
end

local function result_sounds(before, after, command)
    local current = presentation.new(public_view(before))
    presentation.begin(current, public_view(before), public_view(after), command, true)
    return presentation.sounds(current), current
end

function scenarios.run()
    -- ## ORIGINAL WAVEFORM AND RESOURCE BOUNDS

    test.test("every original sound is finite, quiet, short and faded at both ends", function()
        local total_samples = 0
        for _, recipe in ipairs(design.recipes) do
            for variant = 1, recipe.variants do
                local samples, peak = design.generate(recipe.name, variant), 0
                assert(#samples > 0 and #samples <= 6720, "Sound exceeds 420 ms")
                test.equal(samples[1], 0)
                test.equal(samples[#samples], 0)
                for _, sample in ipairs(samples) do
                    assert(sample == sample and math.abs(sample) <= 0.20, recipe.name)
                    peak = math.max(peak, math.abs(sample))
                end
                assert(peak > 0.001, recipe.name .. " is silent")
                total_samples = total_samples + #samples
            end
        end
        assert(total_samples * 2 < 96 * 1024, "Decoded 16-bit mono PCM exceeds 96 KiB")
    end)
    test.test("legacy and new event names all have original sound recipes", function()
        local names = {
            "card",
            "flip",
            "chips",
            "button",
            "win",
            "loss",
            "push",
            "chip_up",
            "chip_down",
            "payout",
            "blackjack",
            "navigation",
            "bust",
        }
        for _, name in ipairs(names) do
            assert(design.generate(name), name)
        end
        assert(not design.generate("unknown"))
        assert(not design.generate("card", 0))
        assert(not design.generate("card", 4))
    end)
    test.test("paper variants reproduce exactly and never call ambient randomness", function()
        math.randomseed(202601)
        local expected_random = math.random()
        math.randomseed(202601)
        local first = design.generate("card", 1)
        test.same(first, design.generate("card", 1))
        local second, difference = design.generate("card", 2), 0
        for index, sample in ipairs(first) do
            difference = difference + math.abs(sample - second[index])
        end
        assert(difference > 1, "Paper variants must differ")
        for _, recipe in ipairs(design.recipes) do
            assert(design.generate(recipe.name))
        end
        test.equal(math.random(), expected_random, "Ambient random stream")
    end)
    test.test("natural cue contains nonzero energy in each of three short note windows", function()
        local samples = design.generate("blackjack")
        for note = 1, 3 do
            local energy = 0
            for index = (note - 1) * 2240 + 1, note * 2240 do
                energy = energy + samples[index] ^ 2
            end
            assert(energy > 0.1, "Silent natural note " .. note)
        end
    end)

    -- ## CACHED PLAYBACK WITHOUT A SOUND DEVICE

    test.test("startup caches nineteen sources and playback allocates no new sounds", function()
        local bank, _, sources, allocations = playback_fixture()
        test.equal(#sources, 19)
        test.equal(allocations.data, 19)
        test.equal(allocations.writes, 45488)
        assert(audio.play(bank, "card", settings))
        test.equal(allocations.data, 19)
        test.equal(allocations.writes, 45488)
    end)
    test.test("headless nil bank needs neither settings nor LÖVE", function()
        local played, reason = audio.play(nil, "card", nil)
        assert(not played)
        test.equal(reason, "unavailable")
        audio.stop(nil)
    end)
    test.test("unknown sound events and playback failures do not interrupt gameplay", function()
        local bank = playback_fixture()
        local played, reason = audio.play(bank, "unknown", settings)
        assert(not played)
        test.equal(reason, "unknown event")
        bank.events.card.voices[1].source.play = function()
            error("Simulated unavailable output")
        end
        played, reason = audio.play(bank, "card", settings)
        assert(not played)
        test.equal(reason, "unavailable")
    end)
    test.test("mute and zero volume stop every active source", function()
        local bank, _, sources = playback_fixture()
        assert(audio.play(bank, "win", settings))
        assert(not audio.play(bank, "button", { sound_enabled = false, volume = 6 }))
        test.equal(playing_count(sources), 0)
        assert(audio.play(bank, "card", settings))
        assert(not audio.play(bank, "button", { sound_enabled = true, volume = 0 }))
        test.equal(playing_count(sources), 0)
    end)
    test.test("volume uses the saved zero-to-ten scale and rejects invalid values", function()
        local bank = playback_fixture()
        assert(audio.play(bank, "card", { sound_enabled = true, volume = 3 }))
        test.equal(bank.events.card.voices[1].source.volume, 0.3)
        for _, volume in ipairs({ -1, 11, "6", math.huge }) do
            local played, reason =
                audio.play(bank, "win", { sound_enabled = true, volume = volume })
            assert(not played)
            test.equal(reason, "invalid volume")
        end
    end)
    test.test("repeated navigation and chip changes share short cooldowns", function()
        local bank, clock = playback_fixture()
        assert(audio.play(bank, "navigation", settings))
        local played, reason = audio.play(bank, "button", settings)
        assert(not played)
        test.equal(reason, "cooldown")
        clock.time = 0.10
        assert(audio.play(bank, "chip_up", settings))
        assert(not audio.play(bank, "chip_down", settings))
        clock.time = 0.16
        assert(audio.play(bank, "chip_down", settings))
    end)
    test.test("paper sources rotate deterministically without cutting a playing variant", function()
        local bank, clock = playback_fixture()
        for variant = 1, 3 do
            clock.time = variant * 0.10
            assert(audio.play(bank, "card", settings))
            test.equal(bank.events.card.voices[variant].source.plays, 1)
        end
        clock.time = 0.40
        local played, reason = audio.play(bank, "card", settings)
        assert(not played)
        test.equal(reason, "busy")
    end)
    test.test(
        "four-voice cap preserves outcome and payout by replacing older quiet cues",
        function()
            local bank, clock, sources = playback_fixture()
            for index, name in ipairs({ "card", "chip_up", "button", "flip" }) do
                clock.time = index * 0.10
                assert(audio.play(bank, name, settings))
            end
            test.equal(playing_count(sources), 4)
            clock.time = 0.50
            local played, reason = audio.play(bank, "navigation", settings)
            assert(not played)
            test.equal(reason, "voice limit")
            assert(audio.play(bank, "blackjack", settings))
            assert(audio.play(bank, "payout", settings))
            test.equal(playing_count(sources), 4)
            assert(bank.events.blackjack.voices[1].source.playing)
            assert(bank.events.payout.voices[1].source.playing)
            assert(not bank.events.card.voices[1].source.playing)
            assert(not bank.events.chip_up.voices[1].source.playing)
        end
    )

    test.test("stopping cached voices permits immediate playback again", function()
        local bank, _, sources = playback_fixture()
        assert(audio.play(bank, "navigation", settings))
        audio.stop(bank)
        test.equal(playing_count(sources), 0)
        assert(audio.play(bank, "navigation", settings))
    end)

    -- ## RESULT CUES FOLLOW PUBLIC REVEALS

    test.test("natural and payout cues wait until the dealer hole reveal finishes", function()
        local before = fixtures.game({ "A", "10", "K", "9" })
        local after = fixtures.act(before, "deal", { bet_units = 100 })
        local saved_before, saved_after = copy(before), copy(after)
        local current = presentation.new(public_view(before))
        presentation.begin(current, public_view(before), public_view(after), "deal", false)
        test.same(presentation.sounds(current), {})
        presentation.update(current, 0.80)
        assert(current.displayed.dealer.cards[2].hidden and not current.displayed.result)
        for _, name in ipairs(presentation.sounds(current)) do
            test.equal(name, "card")
        end
        presentation.update(current, 10)
        local sounds = presentation.sounds(current)
        test.equal(sounds[#sounds - 1], "blackjack")
        test.equal(sounds[#sounds], "payout")
        presentation.finish(current)
        test.same(presentation.sounds(current), {})
        test.same(before, saved_before)
        test.same(after, saved_after)
    end)
    test.test("ordinary twenty-one uses win and payout rather than the natural cue", function()
        local before = fixtures.deal({ "10", "6", "5", "10", "6", "10" })
        local after = fixtures.act(before, "hit")
        test.same(result_sounds(before, after, "hit"), { "win", "payout" })
    end)
    test.test("two naturals push without a payout-collection cue", function()
        local before = fixtures.game({ "A", "A", "K", "Q" })
        local after = fixtures.act(before, "deal", { bet_units = 100 })
        test.same(result_sounds(before, after, "deal"), { "push" })
    end)
    test.test("a public player bust has its own quiet result cue", function()
        local before = fixtures.deal({ "10", "10", "9", "7", "5" })
        test.same(result_sounds(before, fixtures.act(before, "hit"), "hit"), { "bust" })
    end)
    test.test("ordinary loss has no collection cue", function()
        local before = fixtures.deal({ "10", "10", "6", "9" })
        test.same(result_sounds(before, fixtures.act(before, "stand"), "stand"), { "loss" })
    end)
    test.test("an exhausted fixture refunds without pretending to pay a win", function()
        local before = fixtures.deal({ "5", "6", "6", "10" })
        local after = fixtures.act(before, "stand")
        assert(after.round.result.void)
        test.same(result_sounds(before, after, "stand"), { "button" })
    end)
    test.test("one busted split and one winning split use net push feedback", function()
        local game = fixtures.deal({ "8", "10", "8", "7", "10", "10", "10" })
        game = fixtures.act(game, "split")
        local before = fixtures.act(game, "hit")
        local after = fixtures.act(before, "stand")
        test.equal(after.round.result.net_units, 0)
        test.same(result_sounds(before, after, "stand"), { "push" })
    end)
    test.test("split ace and ten wins remain ordinary wins", function()
        local before = fixtures.deal({ "A", "10", "A", "7", "K", "Q" })
        local after = fixtures.act(before, "split")
        test.same(result_sounds(before, after, "split"), { "win", "payout" })
    end)
end

return scenarios
