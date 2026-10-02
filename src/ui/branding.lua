-- PURPOSE: Display the supplied logo, project credits and included license notices.
-- CHANGE THIS MODULE WHEN: Branding placement, credits or notice presentation changes.
-- DO NOT PUT HERE: Editing the logo, choosing licenses or downloading assets.

local components = require("src.ui.components")
local schema = require("src.persistence.save_schema")
local branding = {}
local text, colors = components.text, components.colors
local logo_image, logo_checked, notice_pages
local copyright = "© 2026 MarkXimize Interactive"
local notices = {
    { "LÖVE 11.5 and bundled libraries", "notices/love-11.5-license.txt" },
    { "Bitstream Vera default font", "notices/bitstream-vera-license.txt" },
    { "rxi/json.lua", "notices/json-lua-license.txt" },
}

-- ## CACHE THE SUPPLIED IMAGE WITHOUT ALTERING IT

function branding.logo(x, y, width, height)
    if not logo_checked then
        logo_checked = true
        local loaded, image = pcall(love.graphics.newImage, "assets/royal-pocket-casino-logo.png")
        if loaded then
            logo_image = image
            logo_image:setFilter("linear", "linear")
        else
            print("Brand logo unavailable: " .. tostring(image))
        end
    end
    if not logo_image then
        return false
    end
    local scale = math.min(width / logo_image:getWidth(), height / logo_image:getHeight())
    local centered_x = x + (width - logo_image:getWidth() * scale) / 2
    local centered_y = y + (height - logo_image:getHeight() * scale) / 2
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(logo_image, centered_x, centered_y, 0, scale, scale)
    return true
end

-- ## READ FULL INCLUDED NOTICES ONCE

local function prepare_notices(fonts)
    if notice_pages then
        return
    end
    notice_pages = {}
    for _, notice in ipairs(notices) do
        local contents, reason = love.filesystem.read(notice[2])
        if not contents then
            contents = "Included notice unavailable: " .. tostring(reason)
        end
        contents = contents:gsub("\r\n", "\n"):gsub("\r", "\n")
        local lines = {}
        for paragraph in (contents .. "\n"):gmatch("(.-)\n") do
            local _, wrapped = fonts.detail:getWrap(paragraph, 576)
            if #wrapped == 0 then
                lines[#lines + 1] = ""
            else
                for _, line in ipairs(wrapped) do
                    lines[#lines + 1] = line
                end
            end
        end
        local page
        for index, line in ipairs(lines) do
            if (index - 1) % 17 == 0 then
                page = { title = notice[1], lines = {} }
                notice_pages[#notice_pages + 1] = page
            end
            page.lines[#page.lines + 1] = line
        end
    end
end

function branding.page_count(fonts)
    prepare_notices(fonts)
    return 1 + #notice_pages
end

local function credits(fonts)
    branding.logo(29, 92, 118, 118)
    text(fonts.body, "Royal Pocket Casino", 173, 105, colors.ivory)
    text(fonts.detail, "A MarkXimize Interactive title", 173, 134, colors.ivory)
    text(fonts.detail, copyright, 173, 159, colors.gold)
    text(fonts.detail, "An offline Blackjack game and learning app.", 173, 187, colors.muted, 428)
    local rows = {
        "Original source and assets: license decisions pending.",
        "LÖVE: zlib-style runtime license; bundled libraries differ.",
        "Default font: Bitstream Vera font license.",
        "JSON decoder: rxi/json.lua, MIT license.",
        "PortMaster: uses your existing installation; no runtime bundled.",
    }
    for index, row in ipairs(rows) do
        text(fonts.detail, row, 32, 227 + (index - 1) * 31, colors.ivory, 576)
    end
    text(
        fonts.small,
        "Next pages contain the complete included third-party notices.",
        32,
        384,
        colors.muted
    )
end

function branding.about(fonts, notice_page)
    components.background()
    local count = branding.page_count(fonts)
    notice_page = math.max(1, math.min(count, notice_page or 1))
    text(
        fonts.title,
        notice_page == 1 and "ABOUT & CREDITS" or "THIRD-PARTY NOTICES",
        24,
        22,
        colors.gold
    )
    text(
        fonts.detail,
        "Version " .. schema.app_version .. "  •  Page " .. notice_page .. " / " .. count,
        24,
        56,
        colors.muted
    )
    if notice_page == 1 then
        credits(fonts)
    else
        local page = notice_pages[notice_page - 1]
        text(fonts.body, page.title, 32, 94, colors.gold)
        for index, line in ipairs(page.lines) do
            text(fonts.detail, line, 32, 123 + (index - 1) * 16, colors.ivory)
        end
    end
    text(fonts.small, copyright, 0, 463, colors.muted, 640, "center")
end

return branding
