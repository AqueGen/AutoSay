local ADDON_NAME = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

local WIDTH, PAD, GAP, BUTTON_H, BAR_H = 380, 10, 8, 22, 3

local panel

local function SavePoint(frame)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    Addon.db.profile.confirm.point = { point, relativePoint, x, y }
end

local function Place(frame)
    frame:ClearAllPoints()
    local p = Addon.db.profile.confirm.point
    if p then
        frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
    end
end

local function OnUpdate(frame, elapsed)
    frame.sinceTick = frame.sinceTick + elapsed
    if frame.sinceTick < 0.1 then return end
    frame.sinceTick = 0
    local item = Addon.confirm:Current()
    if not item or item.generation ~= Addon.state.sendGeneration then
        Addon:ConfirmDismiss()
        return
    end
    local timeout = Addon.db.profile.confirm.timeout
    local left = Addon.confirm:Remaining(GetTime(), timeout)
    if left <= 0 then
        Addon:ConfirmDismiss()
        return
    end
    frame.bar:SetValue(left / timeout)
    frame.seconds:SetText(math.ceil(left) .. "s")
end

local function Build()
    local f = CreateFrame("Frame", "AutoSayConfirmPanel", UIParent, "BackdropTemplate")
    f:SetWidth(WIDTH)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePoint(self)
    end)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0.08, 0.09, 0.11, 0.95)
    f:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)

    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetPoint("TOPRIGHT", 2, 2)
    f.close:SetScript("OnClick", function() Addon:ConfirmDismiss() end)

    f.header = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.header:SetPoint("TOPLEFT", PAD, -PAD)
    f.header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(PAD + 24), -PAD)
    f.header:SetJustifyH("LEFT")

    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.text:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -GAP)
    f.text:SetWidth(WIDTH - 2 * PAD)
    f.text:SetJustifyH("LEFT")
    f.text:SetWordWrap(true)

    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    f.bar:SetStatusBarColor(1, 0.82, 0, 0.8)
    f.bar:SetMinMaxValues(0, 1)
    f.bar:SetHeight(BAR_H)
    f.bar:SetPoint("BOTTOMLEFT", PAD, PAD)
    f.bar:SetPoint("BOTTOMRIGHT", -PAD, PAD)

    f.send = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.send:SetSize(100, BUTTON_H)
    f.send:SetPoint("BOTTOMLEFT", f.bar, "TOPLEFT", 0, GAP)
    f.send:SetText(L["Confirm send"])
    f.send:SetScript("OnClick", function() Addon:ConfirmSend() end)

    f.another = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.another:SetSize(100, BUTTON_H)
    f.another:SetPoint("LEFT", f.send, "RIGHT", GAP, 0)
    f.another:SetText(L["Confirm another"])
    f.another:SetScript("OnClick", function() Addon:ConfirmReroll() end)

    f.seconds = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.seconds:SetPoint("BOTTOMRIGHT", f.bar, "TOPRIGHT", 0, GAP)

    f.sinceTick = 0
    f:SetScript("OnUpdate", OnUpdate)
    f:Hide()
    Place(f)
    return f
end

function Addon:ShowConfirmPanel(item)
    panel = panel or Build()
    local color = self.ChannelColor[item.channel] or "|cFF00CCFF"
    panel.header:SetText(color .. "[" .. item.channel .. "]|r " .. (item.label or ""))
    panel.text:SetText(item.text)
    panel.another:SetEnabled(self.confirm:CanReroll())
    panel:SetHeight(PAD + panel.header:GetStringHeight() + GAP + panel.text:GetStringHeight()
        + GAP + BUTTON_H + GAP + BAR_H + PAD)
    panel.sinceTick = 1
    Place(panel)
    panel:SetFrameStrata(item.preview and "TOOLTIP" or "DIALOG")
    panel:Show()
end

function Addon:HideConfirmPanel()
    if panel then panel:Hide() end
end

function Addon:ResetConfirmPanelPosition()
    self.db.profile.confirm.point = nil
    if panel then Place(panel) end
end
