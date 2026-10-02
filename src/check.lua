-- PURPOSE: Validate plain objects, arrays, identifiers and bounded numbers.
-- CHANGE THIS MODULE WHEN: Shared plain-data shape or size checks change.
-- DO NOT PUT HERE: JSON parsing, filesystem operations or gameplay transitions.

local chips = require("src.blackjack.chips")
local check = {}

function check.object(value, names, optional)
    if type(value) ~= "table" then
        return false
    end
    local accepted = {}
    for _, name in ipairs(names) do
        accepted[name] = true
        if value[name] == nil then
            return false
        end
    end
    for _, name in ipairs(optional or {}) do
        accepted[name] = true
    end
    for name in pairs(value) do
        if not accepted[name] then
            return false
        end
    end
    return true
end

function check.array(value, maximum)
    if type(value) ~= "table" or #value > maximum then
        return false
    end
    local count = 0
    for index in pairs(value) do
        if not chips.is_integer(index, 1, #value) then
            return false
        end
        count = count + 1
    end
    return count == #value
end

function check.integer(value, minimum, maximum)
    return chips.is_integer(value, minimum or 0, maximum or chips.maximum)
end

function check.identifier(value)
    return type(value) == "string" and #value == 32 and value:match("^%x+$") ~= nil
end

function check.hash(value)
    return type(value) == "string" and #value == 64 and value:match("^%x+$") ~= nil
end

function check.boolean(value)
    return type(value) == "boolean"
end

return check
