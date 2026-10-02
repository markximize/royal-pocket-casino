-- PURPOSE: Check test-save integrity, bounded metrics and input evidence rules.
-- CHANGE THIS MODULE WHEN: The diagnostic contracts change.
-- DO NOT PUT HERE: Blackjack tests or fake hardware compatibility claims.

local save_format = require("save_format")
local frame_metrics = require("frame_metrics")
local input = require("input")
local platform = require("platform")
local self_test = {}

local function test_save_format()
    local contents = save_format.encode(3, "manual_write")
    local decoded = assert(save_format.decode(contents))
    assert(decoded.launch_count == 3 and decoded.last_test == "manual_write")
    assert(
        save_format.decode("save_version=2\nlaunch_count=3\nlast_successful_test=launch\n") == nil
    )
    assert(
        save_format.decode("save_version=1\nlaunch_count=0\nlast_successful_test=launch\n") == nil
    )
    assert(save_format.decode(contents .. "extra=unexpected\n") == nil)
    assert(save_format.decode(string.rep("x", 513)) == nil)
    assert(save_format.decode(nil) == nil)
    print("PASS versioned test-save validation")
end

local function test_storage_failures()
    local original_filesystem = love.filesystem
    local stored, writes = nil, 0
    love.filesystem = {
        getInfo = function()
            return stored and {} or nil
        end,
        read = function()
            return stored
        end,
        write = function(filename, contents)
            stored = contents
            writes = writes + 1
            return true
        end,
    }
    local first = platform.begin_launch()
    assert(first.previous_read == "NONE" and first.launch_count == 1)
    local second = platform.begin_launch()
    assert(second.previous_read == "PASS" and second.launch_count == 2)
    stored = "corrupted diagnostic"
    local failed = platform.begin_launch()
    assert(failed.previous_read == "FAIL" and failed.write_status == "BLOCKED")
    assert(writes == 2 and stored == "corrupted diagnostic")
    stored = save_format.encode(4, "launch")
    love.filesystem.write = function()
        return false, "simulated disk full"
    end
    local full_disk = platform.begin_launch()
    assert(full_disk.write_status == "FAIL" and full_disk.launch_count == 5)
    assert(stored == save_format.encode(4, "launch"))
    love.filesystem = original_filesystem
    print("PASS launch increment, corruption preservation, write failure")
end

local function test_timing_window()
    local metrics = frame_metrics.new()
    for _ = 1, 2500 do
        frame_metrics.record(metrics, 0.010)
    end
    frame_metrics.refresh(metrics)
    assert(#metrics.samples == 1200)
    assert(math.abs(metrics.mean_ms - 10) < 0.0001)
    assert(metrics.p99_ms == 10 and metrics.over_50_ms == 0)
    frame_metrics.record(metrics, 0.100)
    assert(metrics.over_50_ms == 1 and metrics.maximum_ms == 100)
    print("PASS bounded frame window and long-interval count")
end

local function test_input_evidence()
    local state = input.new()
    local joystick = {
        getID = function()
            return 7
        end,
    }
    input.keyboard(state, "a")
    assert(state.seen.A == nil)
    input.raw_button(state, joystick, 3, true)
    assert(state.seen.A == nil)
    assert(input.gamepad_button(state, joystick, "a", true) == "A")
    assert(state.seen.A == true)
    input.gamepad_button(state, joystick, "back", true)
    assert(state.seen.SELECT == true)
    for index = 1, 100 do
        input.remember(state, "event " .. index)
    end
    assert(#state.log == 80 and state.log[1] == "event 21")
    print("PASS keyboard/raw events cannot masquerade as mapped-controller evidence")
end

function self_test.run()
    assert(type(require("report").build) == "function", "Report module must export its builder")
    print("PASS report module exports its builder (clean-exit regression)")
    test_save_format()
    test_storage_failures()
    test_timing_window()
    test_input_evidence()
    local written, write_error =
        love.filesystem.write("self-test-file.txt", "versioned test fixture\n")
    assert(written, write_error)
    assert(love.filesystem.read("self-test-file.txt") == "versioned test fixture\n")
    assert(love.filesystem.remove("self-test-file.txt"))
    print("PASS real LOVE filesystem write/read of separate disposable fixture")
    print("All diagnostic checks passed; hardware/audio hearing are NOT verified.")
end

return self_test
