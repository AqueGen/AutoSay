local ADDON_NAME = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

local function ConfirmOn() return Addon.db.profile.confirm.enabled end

-- Shown once after an update, never on a new install. Raise `id` for each new message.
local NEWS = {
    id = 1,
    pages = {
        {
            title = L["Ask before sending"],
            note = L["News confirm"],
            path = { "general" },
            get = ConfirmOn,
            set = function(on) Addon:SetConfirmEnabled(on) end,
        },
        {
            title = L["News pins title"],
            note = L["News pins"],
            path = { "group", "greetingsSelf" },
            needs = ConfirmOn,
            needsText = L["News pins needs confirm"],
        },
    },
}

local WIDTH, PAD, GAP, BUTTON_H, CHECK_H, ICON_SIZE = 480, 10, 8, 22, 24, 32
local DELAY = 2

local frame

local function BuildPage(f, page, top)
    local p = CreateFrame("Frame", nil, f)
    p:SetPoint("TOPLEFT", PAD, -top)
    p:SetPoint("RIGHT", -PAD, 0)

    local head = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    head:SetPoint("TOPLEFT")
    head:SetText(page.title)

    local note = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    note:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -GAP / 2)
    note:SetWidth(WIDTH - 2 * PAD)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    note:SetText(page.note)
    local height = head:GetStringHeight() + GAP / 2 + note:GetStringHeight()

    if page.set then
        p.check = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
        p.check:SetSize(CHECK_H, CHECK_H)
        p.check:SetPoint("TOPLEFT", note, "BOTTOMLEFT", -4, -GAP / 2)
        p.check.Text:SetText(L["Enable"])
        p.check:SetScript("OnClick", function(self) page.set(self:GetChecked()) end)
        height = height + GAP / 2 + CHECK_H
    end
    if page.needs then
        p.needs = p:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        p.needs:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -GAP)
        p.needs:SetWidth(WIDTH - 2 * PAD)
        p.needs:SetJustifyH("LEFT")
        p.needs:SetText(page.needsText)
        height = height + GAP + p.needs:GetStringHeight()
    end
    p:SetHeight(height)
    p:Hide()
    return p, height
end

local function ShowPage(f, index)
    f.index = index
    local page = NEWS.pages[index]
    for i, p in ipairs(f.pages) do p:SetShown(i == index) end
    local p = f.pages[index]
    if p.check then p.check:SetChecked(page.get()) end
    local ready = not page.needs or page.needs()
    if p.needs then p.needs:SetShown(not ready) end
    f.open:SetEnabled(ready)
    f.counter:SetText(index .. " / " .. #NEWS.pages)
    f.back:SetEnabled(index > 1)
    f.next:SetEnabled(index < #NEWS.pages)
end

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

    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("TOPLEFT", PAD, -PAD)
    icon:SetTexture(Addon.ICON)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", icon, "RIGHT", GAP, 0)
    title:SetText(L["News title"])
    f.counter = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.counter:SetPoint("TOPRIGHT", -PAD, -PAD)

    local top = PAD + ICON_SIZE + 2 * GAP
    local tallest = 0
    f.pages = {}
    for i, page in ipairs(NEWS.pages) do
        local p, h = BuildPage(f, page, top)
        f.pages[i] = p
        tallest = math.max(tallest, h)
    end

    f.back = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.back:SetSize(80, BUTTON_H)
    f.back:SetPoint("BOTTOMLEFT", PAD, PAD)
    f.back:SetText(L["Back"])
    f.back:SetScript("OnClick", function() ShowPage(f, f.index - 1) end)

    f.next = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.next:SetSize(80, BUTTON_H)
    f.next:SetPoint("LEFT", f.back, "RIGHT", GAP, 0)
    f.next:SetText(L["Next"])
    f.next:SetScript("OnClick", function() ShowPage(f, f.index + 1) end)

    local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(120, BUTTON_H)
    close:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    close:SetText(L["Close"])
    close:SetScript("OnClick", function() f:Hide() end)

    -- The window steps aside for the settings and comes back on the same page when they close
    f.open = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.open:SetSize(120, BUTTON_H)
    f.open:SetPoint("RIGHT", close, "LEFT", -GAP, 0)
    f.open:SetText(L["Open settings"])
    f.open:SetScript("OnClick", function()
        local index = f.index
        f:Hide()
        Addon:OpenConfig(function()
            f:Show()
            ShowPage(f, index)
        end)
        LibStub("AceConfigDialog-3.0"):SelectGroup("AutoSay", unpack(NEWS.pages[index].path))
    end)

    f:SetHeight(top + tallest + 2 * GAP + BUTTON_H + PAD)
    return f
end

function Addon:ShowNews()
    frame = frame or Build()
    frame:Show()
    ShowPage(frame, 1)
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
