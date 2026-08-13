local ADDON_NAME, AutoSay = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

local WIDTH, PAD = 460, 20

-- One line per feature, in display order
local bulletKeys = {
    "WhatsNew instance",
    "WhatsNew styles",
    "WhatsNew roles",
    "WhatsNew timeofday",
    "WhatsNew names",
    "WhatsNew group",
}

local frame

local function CreateWhatsNewFrame(minor)
    frame = CreateFrame("Frame", "AutoSayWhatsNewFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetWidth(WIDTH)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Esc closes it like any Blizzard dialog
    tinsert(UISpecialFrames, frame:GetName())

    -- The flag is burned on close, not on show: an error before the user reads it
    -- must not cost them the popup. A test-mode preview must not burn the real
    -- one-time show, so it skips the write instead.
    frame:SetScript("OnHide", function()
        if Addon.whatsNewPreview then
            Addon.whatsNewPreview = nil
            return
        end
        Addon.db.global.whatsNewSeen = minor
    end)

    local title = "AutoSay " .. minor .. " - " .. L["What's new"]
    if frame.SetTitle then
        frame:SetTitle(title)
    elseif frame.TitleText then
        frame.TitleText:SetText(title)
    end

    local y = -34

    local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", PAD, y)
    header:SetText("|cFF0099FFAuto|r|cFFFFD700Say|r " .. minor)
    y = y - 22

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOPLEFT", PAD, y)
    subtitle:SetTextColor(0.7, 0.7, 0.7)
    subtitle:SetText(L["WhatsNew subtitle"])
    y = y - 24

    for _, key in ipairs(bulletKeys) do
        local bullet = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        bullet:SetPoint("TOPLEFT", PAD, y)
        bullet:SetWidth(WIDTH - PAD * 2)
        bullet:SetJustifyH("LEFT")
        bullet:SetText("|cFFFFD700-|r " .. L[key])
        y = y - bullet:GetStringHeight() - 10
    end

    local gotIt = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    gotIt:SetSize(110, 22)
    gotIt:SetPoint("BOTTOMRIGHT", -PAD, 14)
    gotIt:SetText(L["Got it"])
    gotIt:SetScript("OnClick", function() frame:Hide() end)

    local settings = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    settings:SetSize(130, 22)
    settings:SetPoint("RIGHT", gotIt, "LEFT", -8, 0)
    settings:SetText(L["Open settings"])
    settings:SetScript("OnClick", function()
        frame:Hide()
        Addon:OpenConfig()
    end)

    local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footer:SetPoint("BOTTOMLEFT", PAD, 20)
    footer:SetText(L["Made in Ukraine"])

    -- Content decides the height: the bullets wrap to a different number of lines per locale
    frame:SetHeight(-y + 46)
end

function Addon:ShowWhatsNew(minor)
    if not frame then
        CreateWhatsNewFrame(minor)
    end
    frame:Show()
end
