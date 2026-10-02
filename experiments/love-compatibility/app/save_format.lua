-- PURPOSE: Encode/validate the three fields in the disposable test save.
-- CHANGE THIS MODULE WHEN: The compatibility save format changes.
-- DO NOT PUT HERE: Filesystem calls or production progress/migrations.
-- For Python learners: A returned table exposes functions like a small module.

local save_format = {}
local maximum_launches = 1000000000

-- ## VERSIONED TEST DATA

function save_format.encode(launch_count, last_test)
    assert(launch_count >= 1 and launch_count < maximum_launches)
    assert(launch_count == math.floor(launch_count))
    assert(last_test == "launch" or last_test == "manual_write")
    return string.format(
        "save_version=1\nlaunch_count=%d\nlast_successful_test=%s\n",
        launch_count,
        last_test
    )
end

function save_format.decode(contents)
    if type(contents) ~= "string" or #contents > 512 then
        return nil, "Save must be text below 513 bytes"
    end
    local version, count, last_test =
        contents:match("^save_version=(%d+)\nlaunch_count=(%d+)\nlast_successful_test=([%w_]+)\n$")
    if not version then
        return nil, "Invalid test-save format"
    end
    if version ~= "1" then
        return nil, "Unsupported test-save version: " .. version
    end
    local launch_count = tonumber(count)
    if not launch_count or launch_count < 1 or launch_count >= maximum_launches then
        return nil, "Launch count outside supported range"
    end
    if last_test ~= "launch" and last_test ~= "manual_write" then
        return nil, "Unknown saved test name"
    end
    return { launch_count = launch_count, last_test = last_test }
end

return save_format
