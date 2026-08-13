local ADDON_NAME, AutoSay = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

local WIDTH, PAD, ICON = 480, 24, 20

local PARTY = "|cFFAAAAFF"
local INSTANCE = "|cFFFF7F50"

-- Invented name: the examples must not read as something the player actually said
local EXAMPLE_NAME = "Moonberry"

-- The release notes, one entry per minor release. Features render in listed order, any number
-- of them - the frame sizes itself to whatever is here. Ship the next minor by adding its entry
-- next to this one; old entries can be deleted freely, a minor without an entry shows no popup.
--   icon   atlas name when `atlas` is set, otherwise a texture path
local WHATS_NEW = {
    ["1.6"] = {
        subtitle = L["WhatsNew subtitle"],
        features = {
            { icon = "roleicon-tiny-tank", atlas = true, title = L["WN role title"],
              example = PARTY .. "[Party] " .. EXAMPLE_NAME .. ": tank here, pull respectfully|r" },
            { icon = "Interface\\Icons\\INV_Misc_PocketWatch_01", title = L["WN time title"],
              example = PARTY .. "[Party] " .. EXAMPLE_NAME .. ": night owls unite o/|r" },
            { icon = "Interface\\Icons\\INV_Misc_Key_10", title = L["WN instance title"],
              example = INSTANCE .. "[Instance] " .. EXAMPLE_NAME .. ": hi all, glhf|r" },
            { icon = "Interface\\Icons\\INV_Mask_01", title = L["WN styles title"],
              example = PARTY .. "[Party] " .. EXAMPLE_NAME .. ": well met, travelers|r  |cFF888888(Fantasy)|r" },
            { icon = "Interface\\Icons\\INV_Letter_15", title = L["WN welcome title"],
              example = PARTY .. "[Party] " .. EXAMPLE_NAME .. ": welcome Thrall!|r" },
        },
        closing = L["WN group line"],
    },
}

-- Newest entry in the table, for the preview path on a build with no notes of its own
local function NewestVersion()
    local newest, newestValue
    for version in pairs(WHATS_NEW) do
        local major, minor = version:match("^(%d+)%.(%d+)$")
        local value = (tonumber(major) or 0) * 1000 + (tonumber(minor) or 0)
        if not newestValue or value > newestValue then
            newest, newestValue = version, value
        end
    end
    return newest
end

-- One frame per version rendered, built on demand; a frame cannot be thrown away once created
local frames = {}

local function CreateWhatsNewFrame(key, content)
    local frame = CreateFrame("Frame", "AutoSayWhatsNewFrame" .. key:gsub("%W", "_"), UIParent, "BackdropTemplate")
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

    -- Golden dialog header plate, hanging over the frame's top edge. Mirrors Blizzard's
    -- DialogHeaderTemplate: a child frame holding the texture, with the text anchored to
    -- the CHILD's top (anchoring the text to the raw texture put it outside the visible
    -- plaque band, which is why the title used to render blank).
    local header = CreateFrame("Frame", nil, frame)
    header:SetSize(256, 64)
    header:SetPoint("TOP", frame, "TOP", 0, 12)

    local plate = header:CreateTexture(nil, "ARTWORK")
    plate:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    plate:SetAllPoints(header)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", header, "TOP", 0, -14)
    title:SetTextColor(1, 0.82, 0)
    frame.title = title

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    subtitle:SetPoint("TOP", frame, "TOP", 0, -34)
    subtitle:SetWidth(WIDTH - PAD * 2)
    subtitle:SetText(content.subtitle)

    local y = -34 - subtitle:GetStringHeight() - 16
    local textWidth = WIDTH - PAD * 2 - ICON - 8

    for _, feature in ipairs(content.features) do
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(ICON, ICON)
        icon:SetPoint("TOPLEFT", PAD, y)
        if feature.atlas then
            icon:SetAtlas(feature.icon)
        else
            icon:SetTexture(feature.icon)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end

        local name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        name:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        name:SetTextColor(1, 0.82, 0)
        name:SetText(feature.title)

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
    groupLine:SetText(content.closing)
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

    frames[key] = frame
    return frame
end

-- Whether this release has notes at all - Core asks before scheduling the popup
function Addon:HasWhatsNew(minor)
    return WHATS_NEW[minor] ~= nil
end

-- isPreview: show it without burning the once-per-version flag on close
function Addon:ShowWhatsNew(minor, isPreview)
    local key, content = minor, WHATS_NEW[minor]
    -- No notes for this build: stay silent on the real path (and leave whatsNewSeen alone, so a
    -- later patch that does add notes can still show them), but always give the preview something
    if not content and isPreview then
        key = NewestVersion()
        content = key and WHATS_NEW[key]
    end
    if not content then return end

    local frame = frames[key] or CreateWhatsNewFrame(key, content)

    -- A real popup is already up: previewing must not turn it into one that closes for free
    if isPreview and frame:IsShown() then return end

    frame.minorShown = minor
    frame.isPreview = isPreview or false
    -- Titled by the notes actually on display: a dev-build preview shows the newest
    -- entry's version, not the checkout's own
    frame.title:SetText("AutoSay " .. key)
    frame:Show()
end
