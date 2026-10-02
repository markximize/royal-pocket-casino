-- PURPOSE: Copy plain snapshot tables before a transaction can change them.
-- CHANGE THIS MODULE WHEN: The supported snapshot value types change.
-- DO NOT PUT HERE: Engine objects, serialization or generic collection helpers.

local function copy(value)
    if type(value) ~= "table" then
        return value
    end
    local copied = {}
    for key, child in pairs(value) do
        copied[key] = copy(child)
    end
    return copied
end

return copy
