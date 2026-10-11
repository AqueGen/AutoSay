local ADDON_NAME, AutoSay = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local Kit = AutoSay.ConfigKit
local TagSuffix, MatrixChannels, MythicPlusPartyNotice, BuildMessageMatrix, BuildCustomMessageList = Kit.TagSuffix, Kit.MatrixChannels, Kit.MythicPlusPartyNotice, Kit.BuildMessageMatrix, Kit.BuildCustomMessageList

Kit.Pages.mythicplus = function()
    return {
        type = "group",
        name = "|cFFFF00FFMythic+|r",
        order = 35,
        hidden = function() return not Addon.db.profile.mythicplus.enabled end,
        args = {
            overview = {
                type = "description", order = 0, fontSize = "medium",
                name = L["Mythic+ overview"],
            },
            -- Group Ready (key announce when group fills 5/5)
            groupReady = {
                type = "group",
                name = L["Group Ready"],
                order = 1,
                args = {
                    partyOffNotice = {
                        type = "description", order = 0.5, width = "full",
                        name = MythicPlusPartyNotice,
                    },
                    settingsGroup = {
                        type = "group",
                        name = L["Settings"],
                        inline = true,
                        order = 1,
                        args = {
                            announceOnFull = {
                                type = "toggle",
                                name = L["Announce when group is full"] .. TagSuffix("leader"),
                                desc = L["Send a message when your M+ group reaches 5 players"]
                                    .. "\n\n" .. L["Leader only note"],
                                order = 1,
                                width = "full",
                                get = function() return Addon.db.profile.mythicplus.announceOnFull end,
                                set = function(_, val) Addon.db.profile.mythicplus.announceOnFull = val end,
                            },
                            announceOnStart = {
                                type = "toggle",
                                name = L["Announce at key start"] .. TagSuffix("leader"),
                                desc = L["Announce at key start desc"]
                                    .. "\n\n" .. L["Leader only note"],
                                order = 2,
                                width = "full",
                                get = function() return Addon.db.profile.mythicplus.announceOnStart end,
                                set = function(_, val) Addon.db.profile.mythicplus.announceOnStart = val end,
                            },
                            howItWorks = {
                                type = "description",
                                name = "|cFF888888" .. L["M+ how it works"] .. "|r",
                                order = 3,
                                fontSize = "medium",
                            },
                            includeKeyLevel = {
                                type = "toggle",
                                name = L["Include key level"],
                                desc = L["Include key level desc"],
                                order = 4,
                                width = "full",
                                get = function() return Addon.db.profile.mythicplus.includeKeyLevel end,
                                set = function(_, val) Addon.db.profile.mythicplus.includeKeyLevel = val end,
                            },
                        },
                    },
                    dungeonNamesGroup = {
                        type = "group",
                        name = L["Dungeon Names"],
                        inline = true,
                        order = 3,
                        args = {
                            useClientLanguage = {
                                type = "toggle",
                                name = L["Use client language for dungeon names"],
                                desc = L["Use client language for dungeon names desc"],
                                order = 1,
                                width = "full",
                                get = function() return Addon.db.profile.mythicplus.useClientLanguage end,
                                set = function(_, val)
                                    Addon.db.profile.mythicplus.useClientLanguage = val
                                    LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                                end,
                            },
                            dungeonNamesPreview = {
                                type = "description",
                                name = function()
                                    local useClient = Addon.db.profile.mythicplus.useClientLanguage
                                    local names = {}
                                    for id, enName in pairs(AutoSay.DungeonNames) do
                                        if useClient then
                                            local localName = select(1, C_ChallengeMode.GetMapUIInfo(id))
                                            names[#names + 1] = localName or enName
                                        else
                                            names[#names + 1] = enName
                                        end
                                    end
                                    -- pairs order is unstable: without a sort the rows reshuffle on every redraw
                                    table.sort(names)
                                    -- Split into two rows of 4
                                    local half = math.ceil(#names / 2)
                                    local row1 = {}
                                    local row2 = {}
                                    for i, n in ipairs(names) do
                                        if i <= half then
                                            row1[#row1 + 1] = "|cFFFFFFFF" .. n .. "|r"
                                        else
                                            row2[#row2 + 1] = "|cFFFFFFFF" .. n .. "|r"
                                        end
                                    end
                                    return table.concat(row1, ",  ") .. "\n" .. table.concat(row2, ",  ")
                                end,
                                order = 2,
                                width = "full",
                                fontSize = "medium",
                            },
                        },
                    },
                    messagesGroup = {
                        type = "group",
                        name = L["Messages"],
                        inline = true,
                        order = 10,
                        args = BuildMessageMatrix("mplusKeyAnnounce", AutoSay.KeyAnnounce,
                            MatrixChannels({ "mythicplus" }, "enabledKeyAnnounce", "mplusKey")),
                    },
                    customGroup = {
                        type = "group",
                        name = L["Custom Messages"],
                        inline = true,
                        order = 12,
                        args = BuildCustomMessageList("mythicplus", "customKeyAnnounce", "Custom Messages", "mplusKey"),
                    },
                    placeholderNote = {
                        type = "description",
                        name = "|cFF888888" .. L["Placeholder hint"] .. "|r",
                        order = 13,
                        fontSize = "medium",
                    },
                },
            },
            timedRun = {
                type = "group",
                name = L["Timed run"],
                order = 2,
                args = {
                    partyOffNotice = {
                        type = "description", order = 0.5, width = "full",
                        name = MythicPlusPartyNotice,
                    },
                    completionTimedEnabled = {
                        type = "toggle",
                        name = L["Send message when timed"],
                        desc = L["Send message when timed desc"],
                        order = 0.75,
                        width = "full",
                        get = function() return Addon.db.profile.mythicplus.completionTimedEnabled end,
                        set = function(_, val) Addon.db.profile.mythicplus.completionTimedEnabled = val end,
                    },
                    messages = {
                        type = "group",
                        name = L["Messages"],
                        inline = true,
                        order = 1,
                        args = BuildMessageMatrix("mplusCompletionTimed", AutoSay.CompletionTimed,
                            MatrixChannels({ "mythicplus" }, "enabledCompletionTimed", "mplusCompletionTimed")),
                    },
                    customs = {
                        type = "group",
                        name = L["Custom timed messages"],
                        inline = true,
                        order = 2,
                        args = BuildCustomMessageList("mythicplus", "customCompletionTimed", "Custom timed messages", "mplusCompletionTimed"),
                    },
                    placeholderNote = {
                        type = "description",
                        name = "\n|cFF888888" .. L["Completion placeholder hint"] .. "|r",
                        order = 3,
                        fontSize = "medium",
                    },
                },
            },
            depletedRun = {
                type = "group",
                name = L["Depleted run"],
                order = 3,
                args = {
                    partyOffNotice = {
                        type = "description", order = 0.5, width = "full",
                        name = MythicPlusPartyNotice,
                    },
                    completionDepletedEnabled = {
                        type = "toggle",
                        name = L["Send message when depleted"],
                        desc = L["Send message when depleted desc"],
                        order = 0.75,
                        width = "full",
                        get = function() return Addon.db.profile.mythicplus.completionDepletedEnabled end,
                        set = function(_, val) Addon.db.profile.mythicplus.completionDepletedEnabled = val end,
                    },
                    messages = {
                        type = "group",
                        name = L["Messages"],
                        inline = true,
                        order = 1,
                        args = BuildMessageMatrix("mplusCompletionDepleted", AutoSay.CompletionDepleted,
                            MatrixChannels({ "mythicplus" }, "enabledCompletionDepleted", "mplusCompletionDepleted")),
                    },
                    customs = {
                        type = "group",
                        name = L["Custom depleted messages"],
                        inline = true,
                        order = 2,
                        args = BuildCustomMessageList("mythicplus", "customCompletionDepleted", "Custom depleted messages", "mplusCompletionDepleted"),
                    },
                    placeholderNote = {
                        type = "description",
                        name = "\n|cFF888888" .. L["Completion placeholder hint"] .. "|r",
                        order = 3,
                        fontSize = "medium",
                    },
                },
            },
        },
    }
end
