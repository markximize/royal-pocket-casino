-- PURPOSE: Adapt native LÖVE storage, hashing, local IDs and clock metadata.
-- CHANGE THIS MODULE WHEN: A verified native API or storage path changes.
-- DO NOT PUT HERE: Browser persistence, game rules or cloud requests.

local native = {}

function native.new_id()
    local bytes = {}
    for index = 1, 16 do
        bytes[index] = string.format("%02x", love.math.random(0, 255))
    end
    -- Local collision-resistant IDs are not passwords or authentication tokens.
    return table.concat(bytes)
end

function native.hash(contents)
    return love.data.encode("string", "hex", love.data.hash("sha256", contents))
end

function native.now()
    local available, timestamp = pcall(os.date, "!%Y-%m-%dT%H:%M:%SZ")
    return available and timestamp or "unavailable"
end

function native.new()
    local device_id
    local identity_info = love.filesystem.getInfo("device-id.txt")
    if identity_info then
        if identity_info.type ~= "file" or identity_info.size ~= 32 then
            return nil, "Invalid device identity preserved in device-id.txt"
        end
        device_id = love.filesystem.read("device-id.txt")
        if type(device_id) ~= "string" or #device_id ~= 32 or not device_id:match("^%x+$") then
            return nil, "Invalid device identity preserved in device-id.txt"
        end
    else
        device_id = native.new_id()
        local written, reason = love.filesystem.write("device-id.txt", device_id)
        if not written then
            return nil, reason
        end
    end
    return {
        device_id = device_id,
        new_id = native.new_id,
        hash = native.hash,
        now = native.now,
        new_seed = function()
            return love.math.random(1, 2147483646)
        end,
        size = function(name)
            local info, reason = love.filesystem.getInfo(name)
            if info and info.type ~= "file" then
                return nil, "Expected save file, found directory"
            end
            return info and info.size, reason
        end,
        read = function(name)
            return love.filesystem.read(name)
        end,
        write = function(name, contents)
            return love.filesystem.write(name, contents)
        end,
    }
end

function native.capture(filename)
    local directory = os.getenv("RPC_PREVIEW_OUTPUT_DIR")
    if not directory then
        return
    end
    love.graphics.captureScreenshot(function(pixels)
        local encoded = pixels:encode("png")
        local output = assert(io.open(directory .. "/" .. filename, "wb"))
        assert(output:write(encoded:getString()))
        assert(output:close())
    end)
end

function native.open_save_folder()
    local directory = love.filesystem.getSaveDirectory():gsub("\\", "/"):gsub(" ", "%%20")
    local prefix = directory:sub(1, 1) == "/" and "file://" or "file:///"
    return love.system.openURL(prefix .. directory)
end

function native.write_report(contents)
    local directory = os.getenv("RPC_PREVIEW_OUTPUT_DIR")
    if not directory then
        return
    end
    local output = assert(io.open(directory .. "/desktop-preview-report.txt", "wb"))
    assert(output:write(contents))
    assert(output:close())
end

return native
