-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local ADDON_NAME, AutoSay = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local Kit = AutoSay.ConfigKit
local ClassLabel, StyleCounts, BundleDesc = Kit.ClassLabel, Kit.StyleCounts, Kit.BundleDesc

-- The classes a style leans towards, appended to its tooltip
local function ClassFlavour(style)
    local tokens = AutoSay.StyleClasses[style]
    if not tokens then return "" end
    local names = {}
    for i, token in ipairs(tokens) do names[i] = ClassLabel(token) end
    table.sort(names, function(a, b)
        return a:gsub("|c%x%x%x%x%x%x%x%x", "") < b:gsub("|c%x%x%x%x%x%x%x%x", "")
    end)
    return "\n\n|cFF808080" .. L["Class flavour"] .. ":|r " .. table.concat(names, ", ")
end

-- One tick per style: ticked when every phrase of it is on, AceGUI's grey "mixed" tick when
-- some are. A click cycles ticked -> mixed -> clear, so a partly-on style clears in one
-- click and a cleared one fills in one more. The name repeats it in colour: grey off,
-- gold partly on with the count, green all on.
local function StyleToggles()
    local args = {
        desc = { type = "description", order = 0, name = L["Style bundle desc"] },
    }
    for i, style in ipairs(AutoSay.MessageStyles) do
        args[style] = {
            type = "toggle", order = i, width = 1.3,
            name = function()
                local total, selected, _, full = StyleCounts(style)
                if selected == 0 then return "|cFF888888" .. L["Style " .. style] .. "|r" end
                if full then return "|cFF00FF00" .. L["Style " .. style] .. "|r" end
                return string.format("|cFFFFD100%s|r |cFFAAAAAA%d/%d|r", L["Style " .. style], selected, total)
            end,
            desc = function()
                -- How many of the ticked phrases the current switches let out, when not all
                local _, selected, sendable = StyleCounts(style)
                local note = sendable < selected
                    and ("\n\n|cFFFF7F3F" .. string.format(L["%d sendable now"], sendable) .. "|r") or ""
                return BundleDesc(style) .. ClassFlavour(style) .. note
            end,
            tristate = true,
            get = function()
                local _, selected, _, full = StyleCounts(style)
                if full then return true end
                if selected == 0 then return false end
                return nil
            end,
            set = function(_, val) Addon:ApplyStyleBundle(style, false, val == true) end,
        }
    end
    return args
end

Kit.Pages.style = function()
    return {
        type = "group",
        name = L["Style"],
        order = 3,
        args = {
            styleBundles = {
                type = "group", order = 1, inline = true,
                name = L["Message style bundles"],
                args = StyleToggles(),
            },
        },
    }
end
