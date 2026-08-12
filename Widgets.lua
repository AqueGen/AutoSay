--[[-----------------------------------------------------------------------------
AutoSayCollapse Widget
A collapsible list header in the native WoW style: a [+]/[-] expand icon followed
by a left-aligned label, with the usual quest-title highlight on hover.

Rendered by AceConfigDialog for an "execute" option that sets
dialogControl = "AutoSayCollapse". The option's name must start with "+" or "-";
that prefix is the fold-state contract and is stripped from the visible label.
-------------------------------------------------------------------------------]]
local Type, Version = "AutoSayCollapse", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

local PLUS_ICON = [[Interface\Buttons\UI-PlusButton-Up]]
local MINUS_ICON = [[Interface\Buttons\UI-MinusButton-Up]]

--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]
local function Button_OnClick(frame, ...)
    AceGUI:ClearFocus()
    frame.obj:Fire("OnClick", ...)
end

local function Control_OnEnter(frame)
    frame.obj:Fire("OnEnter")
end

local function Control_OnLeave(frame)
    frame.obj:Fire("OnLeave")
end

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
    ["OnAcquire"] = function(self)
        self:SetHeight(22)
        self:SetWidth(200)
        self:SetDisabled(false)
        self:SetText()
    end,

    ["SetText"] = function(self, text)
        text = text or ""
        local prefix = text:sub(1, 1)
        if prefix == "+" or prefix == "-" then
            self.icon:SetTexture(prefix == "+" and PLUS_ICON or MINUS_ICON)
            self.icon:Show()
            text = text:sub(2):gsub("^ ", "", 1)
        else
            self.icon:Hide()
        end
        self.text:SetText(text)
    end,

    ["SetDisabled"] = function(self, disabled)
        self.disabled = disabled
        if disabled then
            self.frame:Disable()
            self.text:SetTextColor(0.5, 0.5, 0.5)
        else
            self.frame:Enable()
            self.text:SetTextColor(1, 0.82, 0)
        end
    end,

    -- AceConfigDialog only calls these for icon-style execute options, but keep
    -- them as no-ops so a stray image/imageWidth on the option cannot error.
    ["SetImage"] = function() end,
    ["SetImageSize"] = function() end,
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local function Constructor()
    local name = "AutoSayCollapse" .. AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Button", name, UIParent)
    frame:Hide()

    frame:EnableMouse(true)
    frame:SetScript("OnClick", Button_OnClick)
    frame:SetScript("OnEnter", Control_OnEnter)
    frame:SetScript("OnLeave", Control_OnLeave)

    frame:SetHighlightTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]], "ADD")
    local highlight = frame:GetHighlightTexture()
    highlight:ClearAllPoints()
    highlight:SetAllPoints(frame)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", frame, "LEFT", 2, 0)
    icon:SetTexture(PLUS_ICON)

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    text:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")

    local widget = {
        icon  = icon,
        text  = text,
        frame = frame,
        type  = Type
    }
    for method, func in pairs(methods) do
        widget[method] = func
    end

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
