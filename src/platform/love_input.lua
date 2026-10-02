-- PURPOSE: Translate desktop keys and SDL gamepad labels to UI intentions.
-- CHANGE THIS MODULE WHEN: Verified bindings or navigation behavior changes.
-- DO NOT PUT HERE: Raw hardware guesses, legal actions or wager mutation.

local input = {}
local keys = {
    left = "previous",
    up = "previous",
    right = "next",
    down = "next",
    ["return"] = "confirm",
    space = "confirm",
    escape = "back",
    tab = "menu",
    h = "hit",
    s = "stand",
    d = "double",
    p = "split",
    q = "inspect_previous",
    e = "inspect_next",
    x = "count_down",
    y = "count_up",
}
local buttons = {
    dpleft = "previous",
    dpup = "previous",
    dpright = "next",
    dpdown = "next",
    a = "confirm",
    b = "back",
    start = "menu",
    leftshoulder = "inspect_previous",
    rightshoulder = "inspect_next",
    x = "count_down",
    y = "count_up",
}

function input.key(key)
    return keys[key]
end
function input.gamepad(button)
    return buttons[button]
end

return input
