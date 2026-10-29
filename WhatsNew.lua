local ADDON_NAME = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

-- Shown once after an update, never on a new install. Raise `id` for each new message.
local NEWS = {
    id = 1,
    page = "general",
    rows = {
        {
            title = L["Ask before sending"],
            note = L["News confirm"],
            get = function() return Addon.db.profile.confirm.enabled end,
            set = function(on) Addon:SetConfirmEnabled(on) end,
        },
    },
}

local WIDTH, PAD, GAP, BUTTON_H, CHECK_H = 460, 10, 8, 22, 24
local DELAY = 2

local function Build()
    local f = CreateFrame("Frame", "AutoSayWhatsNew", UIParent, "BackdropTemplate")
    tinsert(UISpecialFrames, "AutoSayWhatsNew")
    f:SetWidth(WIDTH)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0.08, 0.09, 0.11, 0.95)
    f:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText(L["News title"])
    local anchor, height = title, PAD + title:GetStringHeight()

    f.checks = {}
    for _, row in ipairs(NEWS.rows) do
        local head = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        head:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2 * GAP)
        head:SetText(row.title)

        local note = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        note:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -GAP / 2)
        note:SetWidth(WIDTH - 2 * PAD)
        note:SetJustifyH("LEFT")
        note:SetWordWrap(true)
        note:SetText(row.note)

        local check = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        check:SetSize(CHECK_H, CHECK_H)
        check:SetPoint("TOPLEFT", note, "BOTTOMLEFT", -4, -GAP / 2)
        check.Text:SetFontObject("GameFontHighlight")
        check.Text:SetText(L["Enable"])
        check:SetScript("OnClick", function(self) row.set(self:GetChecked()) end)
        check.row = row
        f.checks[#f.checks + 1] = check

        anchor = check
        height = height + 2 * GAP + head:GetStringHeight() + GAP / 2 + note:GetStringHeight() + GAP / 2 + CHECK_H
    end

    local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(120, BUTTON_H)
    close:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    close:SetText(L["Close"])
    close:SetScript("OnClick", function() f:Hide() end)

    local open = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    open:SetSize(120, BUTTON_H)
    open:SetPoint("RIGHT", close, "LEFT", -GAP, 0)
    open:SetText(L["Open settings"])
    open:SetScript("OnClick", function()
        f:Hide()
        Addon:OpenConfig()
        LibStub("AceConfigDialog-3.0"):SelectGroup("AutoSay", NEWS.page)
    end)

    f:SetHeight(height + 2 * GAP + BUTTON_H + PAD)
    -- The same switch lives on Quick setup, so the ticks follow it while the window is open
    f:SetScript("OnShow", function()
        for _, check in ipairs(f.checks) do check:SetChecked(check.row.get()) end
    end)
    return f
end

local frame

function Addon:ShowNews()
    frame = frame or Build()
    frame:Hide()
    frame:Show()
end

local function ShowOutOfCombat()
    if not InCombatLockdown() then
        Addon:ShowNews()
        return
    end
    local waiter = CreateFrame("Frame")
    waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
    waiter:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        Addon:ShowNews()
    end)
end

function Addon:ScheduleNews()
    local seen = self.db.global.newsSeen
    self.db.global.newsSeen = NEWS.id
    if self.newInstall or seen >= NEWS.id then return end
    C_Timer.After(DELAY, ShowOutOfCombat)
end
