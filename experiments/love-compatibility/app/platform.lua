-- PURPOSE: Own LÖVE/OS observations, local test storage, tone and debug exports.
-- CHANGE THIS MODULE WHEN: A framework/platform API needs adapting.
-- DO NOT PUT HERE: Screen layout, timing math, or production save architecture.

local save_format = require("save_format")
local platform = {}
local save_filename = "compatibility-save.txt"

-- ## RUNTIME AND MEMORY OBSERVATIONS

function platform.runtime_info()
    local major, minor, revision, codename = love.getVersion()
    local renderer, renderer_version, vendor, device = "unavailable", "", "", ""
    if love.graphics then
        renderer, renderer_version, vendor, device = love.graphics.getRendererInfo()
    end
    return {
        version = string.format("%d.%d.%d", major, minor, revision),
        codename = codename,
        os = love.system.getOS(),
        lua = _VERSION,
        jit = jit and jit.version or "not available",
        renderer = renderer,
        renderer_version = renderer_version,
        vendor = vendor,
        graphics_device = device,
        save_directory = love.filesystem.getSaveDirectory(),
    }
end

function platform.memory_info()
    local memory = { lua_kib = collectgarbage("count") }
    if love.system.getOS() ~= "Linux" then
        return memory
    end
    -- /proc is a Linux-only, read-only observation; Lua heap is NOT process RSS.
    local status_file = io.open("/proc/self/status", "r")
    if not status_file then
        return memory
    end
    local contents = status_file:read("*a")
    status_file:close()
    memory.rss_kib = tonumber(contents:match("VmRSS:%s+(%d+)%s+kB"))
    memory.peak_rss_kib = tonumber(contents:match("VmHWM:%s+(%d+)%s+kB"))
    return memory
end

-- ## WRITE / RESTART / READ TEST

function platform.begin_launch()
    local save = { launch_count = 1, previous_read = "NONE", write_status = "NOT RUN" }
    if love.filesystem.getInfo(save_filename) then
        local contents, read_error = love.filesystem.read(save_filename)
        local previous, validation_error = save_format.decode(contents)
        if not previous then
            save.previous_read = "FAIL"
            save.write_status = "BLOCKED"
            save.error = tostring(read_error or validation_error)
            return save
        end
        save.previous_read = "PASS"
        save.previous_launch_count = previous.launch_count
        save.launch_count = previous.launch_count + 1
        if save.launch_count >= 1000000000 then
            save.write_status = "BLOCKED"
            save.error = "Test launch counter exhausted; preserve existing save"
            return save
        end
    end
    platform.write_save(save, "launch")
    return save
end

function platform.write_save(save, test_name)
    if save.previous_read == "FAIL" or save.write_status == "BLOCKED" then
        return
    end
    local contents = save_format.encode(save.launch_count, test_name)
    local written, write_error = love.filesystem.write(save_filename, contents)
    local readback, read_error = love.filesystem.read(save_filename)
    if not written or readback ~= contents then
        save.write_status = "FAIL"
        save.error = tostring(write_error or read_error or "Readback mismatch")
        return
    end
    save.write_status = "PASS"
    save.error = nil
end

function platform.write_report(contents)
    local written, write_error = love.filesystem.write("compatibility-report.txt", contents)
    return written, write_error
end

-- ## ORIGINAL TEST TONE

function platform.create_tone()
    local created, tone_or_error = pcall(function()
        local sample_rate = 16000
        local sample_count = 4000
        local sound_data = love.sound.newSoundData(sample_count, sample_rate, 16, 1)
        for sample_index = 0, sample_count - 1 do
            local seconds = sample_index / sample_rate
            local fade = math.min(1, sample_index / 160, (sample_count - 1 - sample_index) / 160)
            sound_data:setSample(sample_index, 0.18 * fade * math.sin(2 * math.pi * 440 * seconds))
        end
        return love.audio.newSource(sound_data, "static")
    end)
    if not created then
        return nil, tostring(tone_or_error)
    end
    return tone_or_error
end

function platform.play_tone(tone)
    if not tone then
        return false, "Audio source unavailable"
    end
    local played, play_error = pcall(function()
        tone:stop()
        tone:play()
    end)
    return played, play_error
end

-- ## OPTIONAL DESKTOP VERIFICATION ARTIFACTS

function platform.test_output_directory()
    return os.getenv("RPC_POC_REPORT_DIR")
end

function platform.write_test_artifact(filename, contents)
    local directory = platform.test_output_directory()
    if not directory then
        return false, "RPC_POC_REPORT_DIR is not set"
    end
    local output_file, open_error = io.open(directory .. "/" .. filename, "wb")
    if not output_file then
        return false, open_error
    end
    local written, write_error = output_file:write(contents)
    local closed, close_error = output_file:close()
    return written ~= nil and closed ~= nil, write_error or close_error
end

return platform
