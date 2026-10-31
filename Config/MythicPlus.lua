-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local ADDON_NAME, AutoSay = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local Kit = AutoSay.ConfigKit
local TagSuffix, MatrixChannels, MythicPlusPartyNotice, BuildMessageMatrix, BuildCustomMessageList = Kit.TagSuffix, Kit.MatrixChannels, Kit.MythicPlusPartyNotice, Kit.BuildMessageMatrix, Kit.BuildCustomMessageList

local function Toggle(order, field, name, desc)
    return {
        type = "toggle", order = order, width = "full",
        name = name, desc = desc,
        get = function() return Addon.db.profile.mythicplus[field] end,
        set = function(_, val)
            Addon.db.profile.mythicplus[field] = val
            LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay") -- regrey the phrase lists
        end,
    }
end

-- The names a key announce would use, for the language toggle's tooltip
local function DungeonNamesDesc()
    local useClient = Addon.db.profile.mythicplus.useClientLanguage
    local names = {}
    for id, enName in pairs(AutoSay.DungeonNames) do
        local localName = useClient and C_ChallengeMode.GetMapUIInfo(id)
        names[#names + 1] = localName or enName
    end
    -- pairs order is unstable: without a sort the list reshuffles on every redraw
    table.sort(names)
    return L["Use client language for dungeon names desc"] .. "\n\n|cFFFFFFFF" .. table.concat(names, "\n") .. "|r"
end

-- A phrase list page: ticks, own lines and the placeholders they may use
local function ListPage(order, name, poolId, pool, enabledKey, poolKind, customsKey, customsLabel, hintKey)
    return {
        type = "group", order = order, name = name,
        args = {
            messages = {
                type = "group", name = L["Messages"], inline = true, order = 1,
                args = BuildMessageMatrix(poolId, pool, MatrixChannels({ "mythicplus" }, enabledKey, poolKind)),
            },
            customs = {
                type = "group", name = L["My own lines"], inline = true, order = 2,
                args = BuildCustomMessageList("mythicplus", customsKey, customsLabel, poolKind),
            },
            placeholderNote = {
                type = "description", order = 3, fontSize = "medium",
                name = "\n|cFF888888" .. L[hintKey] .. "|r",
            },
        },
    }
end

Kit.Pages.mythicplus = function()
    return {
        type = "group",
        name = L["Mythic+"],
        order = 35,
        hidden = function() return not Addon.db.profile.mythicplus.enabled end,
        args = {
            overview = {
                type = "description", order = 0, fontSize = "medium",
                name = L["Mythic+ overview"],
            },
            partyOffNotice = {
                type = "description", order = 0.5, width = "full",
                name = MythicPlusPartyNotice,
            },
            keyGroup = {
                type = "group", name = L["Group Ready"], inline = true, order = 1,
                args = {
                    announceOnFull = Toggle(1, "announceOnFull",
                        L["Announce when group is full"] .. TagSuffix("leader"),
                        L["Send a message when your M+ group reaches 5 players"] .. "\n\n" .. L["Leader only note"]),
                    announceOnStart = Toggle(2, "announceOnStart",
                        L["Announce at key start"] .. TagSuffix("leader"),
                        L["Announce at key start desc"] .. "\n\n" .. L["Leader only note"]),
                    includeKeyLevel = Toggle(3, "includeKeyLevel",
                        L["Include key level"], L["Include key level desc"]),
                    useClientLanguage = Toggle(4, "useClientLanguage",
                        L["Use client language for dungeon names"], DungeonNamesDesc),
                    -- Under the two announce toggles it explains
                    howItWorks = {
                        type = "description", order = 2.5, fontSize = "medium",
                        name = "|cFF888888" .. L["M+ how it works"] .. "|r",
                    },
                },
            },
            endGroup = {
                type = "group", name = L["End of the run"], inline = true, order = 2,
                args = {
                    completionTimedEnabled = Toggle(1, "completionTimedEnabled",
                        L["Send message when timed"], L["Send message when timed desc"]),
                    completionDepletedEnabled = Toggle(2, "completionDepletedEnabled",
                        L["Send message when depleted"], L["Send message when depleted desc"]),
                },
            },
            groupReady = ListPage(1, L["Group Ready"], "mplusKeyAnnounce", AutoSay.KeyAnnounce,
                "enabledKeyAnnounce", "mplusKey", "customKeyAnnounce", "Custom Messages", "Placeholder hint"),
            timedRun = ListPage(2, L["Timed run"], "mplusCompletionTimed", AutoSay.CompletionTimed,
                "enabledCompletionTimed", "mplusCompletionTimed", "customCompletionTimed",
                "Custom timed messages", "Completion placeholder hint"),
            depletedRun = ListPage(3, L["Depleted run"], "mplusCompletionDepleted", AutoSay.CompletionDepleted,
                "enabledCompletionDepleted", "mplusCompletionDepleted", "customCompletionDepleted",
                "Custom depleted messages", "Completion placeholder hint"),
        },
    }
end
