-- PURPOSE: Bound JSON input before the vendored parser can recurse into it.
-- CHANGE THIS MODULE WHEN: Save byte/depth limits or decoder behavior changes.
-- DO NOT PUT HERE: Executable-Lua loading, filesystem access or save recovery.

local json = require("src.vendor.json")
local safe_json = { maximum_bytes = 1048576 }

function safe_json.decode(contents)
    if type(contents) ~= "string" or #contents > safe_json.maximum_bytes then
        return nil, "JSON size limit exceeded or missing text"
    end
    local depth, quoted, escaped = 0, false, false
    for index = 1, #contents do
        local character = contents:sub(index, index)
        if quoted then
            if escaped then
                escaped = false
            elseif character == "\\" then
                escaped = true
            elseif character == '"' then
                quoted = false
            end
        elseif character == '"' then
            quoted = true
        elseif character == "{" or character == "[" then
            depth = depth + 1
            if depth > 32 then
                return nil, "JSON nesting limit exceeded"
            end
        elseif character == "}" or character == "]" then
            depth = depth - 1
            if depth < 0 then
                return nil, "Unbalanced JSON"
            end
        end
    end
    if quoted or depth ~= 0 then
        return nil, "Incomplete JSON"
    end
    local decoded, value = pcall(json.decode, contents)
    if not decoded then
        return nil, tostring(value)
    end
    return value
end

function safe_json.encode(value)
    local encoded, contents = pcall(json.encode, value)
    if not encoded then
        return nil, tostring(contents)
    end
    if #contents > safe_json.maximum_bytes then
        return nil, "Encoded save is too large"
    end
    return contents
end

return safe_json
