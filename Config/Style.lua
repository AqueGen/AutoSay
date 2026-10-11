local ADDON_NAME, AutoSay = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local Kit = AutoSay.ConfigKit
local TagSuffix, AddRowBreak, ClassLabel, StyleCounts, TagCounts, BundleDesc = Kit.TagSuffix, Kit.AddRowBreak, Kit.ClassLabel, Kit.StyleCounts, Kit.TagCounts, Kit.BundleDesc

Kit.Pages.style = function()
    return {
        type = "group",
        name = L["Style"],
        order = 3,
        args = {
            styleBundles = {
                type = "group", order = 1, inline = true,
                name = L["Message style bundles"],
                args = (function()
                    local args = {
                        desc = {
                            type = "description", order = 1,
                            name = L["Style bundle desc"],
                        },
                    }
                    -- One row per bundle rather than a grid of buttons: a button could
                    -- only say "all on" or "not all on", and half-enabled bundles were
                    -- indistinguishable from off ones. A row has space for both counts
                    -- and for the same pair of buttons the role and time-of-day
                    -- switches use, so the whole tab reads the same way.
                    for i, style in ipairs(AutoSay.MessageStyles) do
                        local order = 10 + i * 10
                        args["row_" .. style] = {
                            type = "description", order = order, width = 1.2,
                            fontSize = "medium",
                            name = function()
                                local _, selected, _, full = StyleCounts(style)
                                local colour = (selected == 0 and "|cFF888888")
                                    or (full and "|cFF00FF00")
                                    or "|cFFFFD100"
                                return colour .. L["Style " .. style] .. "|r"
                            end,
                        }
                        args["count_" .. style] = {
                            type = "description", order = order + 1, width = 1.1,
                            name = function()
                                local total, selected, sendable = StyleCounts(style)
                                -- The second number only earns its place when it differs:
                                -- printing it next to an identical first one is noise
                                if sendable == selected then
                                    return string.format("|cFFAAAAAA%s|r",
                                        string.format(L["%d/%d selected"], selected, total))
                                end
                                return string.format("|cFFAAAAAA%s|r  |cFFFF7F3F%s|r",
                                    string.format(L["%d/%d selected"], selected, total),
                                    string.format(L["%d sendable now"], sendable))
                            end,
                            desc = function() return BundleDesc(style) end,
                        }
                        args["on_" .. style] = {
                            type = "execute", order = order + 2, width = 0.7,
                            name = L["Enable all"],
                            desc = function() return BundleDesc(style) end,
                            disabled = function()
                                local _, _, _, full = StyleCounts(style)
                                return full
                            end,
                            func = function() Addon:ApplyStyleBundle(style, false, true) end,
                        }
                        args["off_" .. style] = {
                            type = "execute", order = order + 3, width = 0.7,
                            name = L["Disable all"],
                            -- No confirmation: the button greys out when there is
                            -- nothing to disable, and the one beside it puts the whole
                            -- set back, so a misclick costs one more click
                            disabled = function()
                                local _, selected = StyleCounts(style)
                                return selected == 0
                            end,
                            func = function() Addon:ApplyStyleBundle(style, false, false) end,
                        }
                        -- The classes this bundle leans towards, on its own row under
                        -- it. Bundles that suit everyone simply have no such row.
                        if AutoSay.StyleClasses[style] then
                            args["classes_" .. style] = {
                                type = "description", order = order + 4, width = "full",
                                name = function()
                                    local names = {}
                                    for i, token in ipairs(AutoSay.StyleClasses[style]) do
                                        names[i] = ClassLabel(token)
                                    end
                                    table.sort(names, function(a, b)
                                        return a:gsub("|c%x%x%x%x%x%x%x%x", "") < b:gsub("|c%x%x%x%x%x%x%x%x", "")
                                    end)
                                    return "      |cFF808080" .. L["Class flavour"] .. ":|r "
                                        .. table.concat(names, ", ")
                                end,
                            }
                        end
                        AddRowBreak(args, "stylerow_" .. style, order + 5)
                    end
                    return args
                end)(),
            },
            rolePhrases = {
                type = "toggle", order = 1.5, width = 2.3,
                name = L["Role-based phrases"]
                    .. " |A:roleicon-tiny-tank:14:14|a|A:roleicon-tiny-healer:14:14|a|A:roleicon-tiny-dps:14:14|a",
                desc = L["Role-based phrases desc"],
                get = function() return Addon.db.profile.social.rolePhrases end,
                set = function(_, v)
                    Addon.db.profile.social.rolePhrases = v
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay") -- refilter the phrase lists
                end,
            },
            -- Same pair, same rule as the style rows above: grey when there is nothing
            -- left to do, and no confirmation, since each button undoes the other
            roleEnableAll = {
                type = "execute", order = 1.6, width = 0.7,
                name = L["Enable all"],
                desc = L["Enable every role phrase on every channel"],
                disabled = function()
                    local _, _, _, full = TagCounts("role")
                    return full
                end,
                func = function() Addon:SetTaggedPhrasesEnabled("role", true) end,
            },
            roleDisableAll = {
                type = "execute", order = 1.7, width = 0.7,
                name = L["Disable all"],
                desc = L["Disable every role phrase on every channel"],
                disabled = function()
                    local _, selected = TagCounts("role")
                    return selected == 0
                end,
                func = function() Addon:SetTaggedPhrasesEnabled("role", false) end,
            },
            roleRowBreak = {
                type = "description", name = "", order = 1.75, width = "full",
            },
            timeOfDay = {
                type = "toggle", order = 2, width = 2.3,
                name = L["Time-of-day phrases"] .. TagSuffix("morning/evening/night"),
                desc = L["Time-of-day phrases desc"],
                get = function() return Addon.db.profile.social.timeOfDay end,
                set = function(_, v)
                    Addon.db.profile.social.timeOfDay = v
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                end,
            },
            bandEnableAll = {
                type = "execute", order = 2.1, width = 0.7,
                name = L["Enable all"],
                desc = L["Enable every time-of-day phrase on every channel"],
                disabled = function()
                    local _, _, _, full = TagCounts("band")
                    return full
                end,
                func = function() Addon:SetTaggedPhrasesEnabled("band", true) end,
            },
            bandDisableAll = {
                type = "execute", order = 2.2, width = 0.7,
                name = L["Disable all"],
                desc = L["Disable every time-of-day phrase on every channel"],
                disabled = function()
                    local _, selected = TagCounts("band")
                    return selected == 0
                end,
                func = function() Addon:SetTaggedPhrasesEnabled("band", false) end,
            },
            bandRowBreak = {
                type = "description", name = "", order = 2.3, width = "full",
            },
            tone = {
                type = "group", order = 4, inline = true,
                name = L["Tone"],
                args = {
                    lowercaseFirst = {
                        type = "toggle", order = 1, width = "full",
                        name = L["Lowercase first letter"],
                        desc = L["Lowercase first letter desc"],
                        get = function() return Addon.db.profile.social.lowercaseFirst end,
                        set = function(_, v) Addon.db.profile.social.lowercaseFirst = v end,
                    },
                },
            },
        },
    }
end
