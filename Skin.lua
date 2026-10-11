local ADDON_NAME = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)

local FLAT = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}
local SLATE = { 0.08, 0.09, 0.11, 0.97 }
local PANE = { 0.11, 0.12, 0.15, 0.9 }
local EDGE = { 0.3, 0.3, 0.35, 1 }
local GOLD = { 1, 0.82, 0 }

local function Save(frame)
    return {
        backdrop = frame:GetBackdrop(),
        color = { frame:GetBackdropColor() },
        border = { frame:GetBackdropBorderColor() },
    }
end

local function Paint(frame, bg)
    frame:SetBackdrop(FLAT)
    frame:SetBackdropColor(unpack(bg))
    frame:SetBackdropBorderColor(unpack(EDGE))
end

local function Restore(frame, saved)
    frame:SetBackdrop(saved.backdrop)
    frame:SetBackdropColor(unpack(saved.color))
    frame:SetBackdropBorderColor(unpack(saved.border))
end

local function TintTreeButtons(tree, on)
    for _, button in ipairs(tree.buttons) do
        local hl = button:GetHighlightTexture()
        if on then
            button.autosayHighlight = button.autosayHighlight or { hl:GetVertexColor() }
            hl:SetVertexColor(unpack(GOLD))
        elseif button.autosayHighlight then
            hl:SetVertexColor(unpack(button.autosayHighlight))
        end
    end
end

local function UnskinTree(skin)
    local tree = skin.tree
    if not tree then return end
    Restore(tree.treeframe, skin.treeframe)
    Restore(tree.border, skin.border)
    tree.autosaySkinned = nil
    TintTreeButtons(tree, false)
    skin.tree = nil
end

local function SkinTree(widget)
    local skin = widget.autosaySkin
    local tree
    for _, child in ipairs(widget.children) do
        if child.type == "TreeGroup" then tree = child end
    end
    if tree == skin.tree then return end
    UnskinTree(skin)
    if not tree then return end

    skin.tree = tree
    skin.treeframe = Save(tree.treeframe)
    skin.border = Save(tree.border)
    Paint(tree.treeframe, PANE)
    Paint(tree.border, PANE)
    tree.autosaySkinned = true
    if not tree.autosayHooked then
        tree.autosayHooked = true
        hooksecurefunc(tree, "RefreshTree", function(t)
            if t.autosaySkinned then TintTreeButtons(t, true) end
        end)
    end
    TintTreeButtons(tree, true)
end

function Addon:SkinConfigWindow(widget)
    if not widget.autosaySkin then
        local frame = widget.frame
        local skin = { frame = Save(frame), hidden = {}, titleColor = { widget.titletext:GetTextColor() } }
        widget.autosaySkin = skin
        Paint(frame, SLATE)
        for _, region in ipairs({ frame:GetRegions() }) do
            if region:IsObjectType("Texture") and region:GetTextureFileID() == 131080 and region:IsShown() then
                region:Hide()
                skin.hidden[#skin.hidden + 1] = region
            end
        end
        widget.titletext:SetTextColor(unpack(GOLD))
        if not widget.autosayHooked then
            widget.autosayHooked = true
            hooksecurefunc(widget, "Show", function(w)
                if w.autosaySkin then SkinTree(w) end
            end)
        end
    end
    SkinTree(widget)
end

function Addon:UnskinConfigWindow(widget)
    local skin = widget.autosaySkin
    if not skin then return end
    widget.autosaySkin = nil
    UnskinTree(skin)
    Restore(widget.frame, skin.frame)
    for _, region in ipairs(skin.hidden) do region:Show() end
    widget.titletext:SetTextColor(unpack(skin.titleColor))
end
