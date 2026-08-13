local ADDON_NAME, AutoSay = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

local WIDTH, PAD, ICON = 480, 24, 20

local PARTY = "|cFFAAAAFF"
local INSTANCE = "|cFFFF7F50"

-- Invented name: the examples must not read as something the player actually said
local EXAMPLE_NAME = "Moonberry"

-- One block per feature, in display order. `atlas` wins over `texture` when set.
local features = {
    { atlas = "roleicon-tiny-tank", title = "WN role title",
      example = PARTY .. "[Party] " .. EXAMPLE_NAME .. ": tank here, pull respectfully|r" },
    { texture = "Interface\\Icons\\INV_Misc_PocketWatch_01", title = "WN time title",
      example = PARTY .. "[Party] " .. EXAMPLE_NAME .. ": night owls unite o/|r" },
    { texture = "Interface\\Icons\\INV_Misc_Key_10", title = "WN instance title",
      example = INSTANCE .. "[Instance] " .. EXAMPLE_NAME .. ": hi all, glhf|r" },
    { texture = "Interface\\Icons\\INV_Mask_01", title = "WN styles title",
      example = PARTY .. "[Party] " .. EXAMPLE_NAME .. ": well met, travelers|r  |cFF888888(Fantasy)|r" },
    { texture = "Interface\\Icons\\INV_Letter_15", title = "WN welcome title",
      example = PARTY .. "[Party] " .. EXAMPLE_NAME .. ": welcome Thrall!|r" },
}

local frame

local function CreateWhatsNewFrame()
    frame = CreateFrame("Frame", "AutoSayWhatsNewFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(WIDTH)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    -- Esc closes it like any Blizzard dialog
    tinsert(UISpecialFrames, frame:GetName())

    -- The flag is burned on close, not on show: an error before the user reads it
    -- must not cost them the popup. Both the version and the preview flag are read off
    -- the frame, which ShowWhatsNew rewrites per call - the closure would otherwise keep
    -- whatever the very first show happened to pass. A preview skips the write.
    frame:SetScript("OnHide", function()
        if frame.isPreview then return end
        Addon.db.global.whatsNewSeen = frame.minorShown
    end)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    -- Golden dialog header plate, hanging over the frame's top edge
    local plate = frame:CreateTexture(nil, "ARTWORK")
    plate:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    plate:SetSize(256, 64)
    plate:SetPoint("TOP", frame, "TOP", 0, 12)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("CENTER", plate, "CENTER", 0, 12)
    title:SetTextColor(1, 0.82, 0)
    frame.title = title

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    subtitle:SetPoint("TOP", frame, "TOP", 0, -34)
    subtitle:SetWidth(WIDTH - PAD * 2)
    subtitle:SetText(L["WhatsNew subtitle"])

    local y = -34 - subtitle:GetStringHeight() - 16
    local textWidth = WIDTH - PAD * 2 - ICON - 8

    for _, feature in ipairs(features) do
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(ICON, ICON)
        icon:SetPoint("TOPLEFT", PAD, y)
        if feature.atlas then
            icon:SetAtlas(feature.atlas)
        else
            icon:SetTexture(feature.texture)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end

        local name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        name:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        name:SetTextColor(1, 0.82, 0)
        name:SetText(L[feature.title])

        local example = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        example:SetPoint("TOPLEFT", PAD + ICON + 8, y - ICON - 2)
        example:SetWidth(textWidth)
        example:SetJustifyH("LEFT")
        example:SetText(feature.example)

        y = y - ICON - 2 - example:GetStringHeight() - 12
    end

    local groupLine = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    groupLine:SetPoint("TOPLEFT", PAD, y - 2)
    groupLine:SetWidth(WIDTH - PAD * 2)
    groupLine:SetJustifyH("LEFT")
    groupLine:SetTextColor(0.6, 0.6, 0.6)
    groupLine:SetText(L["WN group line"])
    y = y - 2 - groupLine:GetStringHeight()

    local gotIt = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    gotIt:SetSize(90, 22)
    gotIt:SetPoint("BOTTOMRIGHT", -PAD, 18)
    gotIt:SetText(L["Got it"])
    gotIt:SetScript("OnClick", function() frame:Hide() end)

    local settings = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    settings:SetSize(140, 26)
    settings:SetPoint("RIGHT", gotIt, "LEFT", -8, 0)
    settings:SetText(L["Open settings"])
    settings:GetFontString():SetTextColor(1, 0.82, 0)
    settings:SetScript("OnClick", function()
        frame:Hide()
        Addon:OpenConfig()
    end)

    local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footer:SetPoint("BOTTOMLEFT", PAD, 22)
    footer:SetText(L["Made in Ukraine"])

    -- Content decides the height: examples wrap to a different number of lines per locale
    frame:SetHeight(-y + 56)

    local intro = frame:CreateAnimationGroup()
    local fade = intro:CreateAnimation("Alpha")
    fade:SetFromAlpha(0)
    fade:SetToAlpha(1)
    fade:SetDuration(0.25)
    local grow = intro:CreateAnimation("Scale")
    grow:SetScaleFrom(0.95, 0.95)
    grow:SetScaleTo(1, 1)
    grow:SetDuration(0.25)
    frame:SetScript("OnShow", function() intro:Play() end)
end

-- isPreview: show it without burning the once-per-version flag on close
function Addon:ShowWhatsNew(minor, isPreview)
    if not frame then
        CreateWhatsNewFrame()
    end

    -- A real popup is already up: previewing must not turn it into one that closes for free
    if isPreview and frame:IsShown() then return end

    frame.minorShown = minor
    frame.isPreview = isPreview or false
    frame.title:SetText("AutoSay " .. minor)
    frame:Show()
end
