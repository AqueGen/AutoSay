local ADDON_NAME, AutoSay = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local Kit = AutoSay.ConfigKit

Kit.Pages.testMode = function()
    return {
        type = "group",
        name = L["Test Mode"],
        order = 50,
        hidden = function() return not Addon.db.profile.testMode end,
        args = {
            description = {
                type = "description",
                name = L["Test mode description"],
                order = 0,
                fontSize = "medium",
            },
            simulateGroupEvents = {
                type = "group",
                name = L["Party"] .. " / " .. L["Raid"],
                inline = true,
                order = 10,
                args = {
                    simulateParty = {
                        type = "execute",
                        name = L["Join Party"],
                        desc = L["Simulate joining a party"],
                        order = 1,
                        width = 0.8,
                        func = function() Addon:TestJoinParty() end,
                        disabled = function() return not Addon.db.profile.testMode end,
                    },
                    simulateRaid = {
                        type = "execute",
                        name = L["Join Raid"],
                        desc = L["Simulate joining a raid"],
                        order = 2,
                        width = 0.8,
                        func = function() Addon:TestJoinRaid() end,
                        disabled = function() return not Addon.db.profile.testMode end,
                    },
                    simulateInstance = {
                        type = "execute",
                        name = L["Enter Instance"],
                        desc = L["Simulate zoning into an instance group"],
                        order = 2.5,
                        width = 1.0,
                        func = function() Addon:TestJoinInstance() end,
                        disabled = function() return not Addon.db.profile.testMode end,
                    },
                    simulateLeave = {
                        type = "execute",
                        name = L["Leave Group"],
                        desc = L["Simulate leaving current group"],
                        order = 3,
                        width = 0.8,
                        func = function() Addon:TestLeaveGroup() end,
                        disabled = function() return not Addon.db.profile.testMode or not Addon.testState.simulatedGroupType end,
                    },
                    simulateReconnect = {
                        type = "execute",
                        name = L["Reconnect"],
                        desc = L["Simulate reconnecting to group"],
                        order = 4,
                        width = 0.8,
                        func = function() Addon:TestReconnect() end,
                        disabled = function() return not Addon.db.profile.testMode or not Addon.testState.simulatedGroupType end,
                    },
                    simulatePlayerJoin = {
                        type = "execute",
                        name = L["Random Player Joins"],
                        desc = L["Simulate a random player joining your group"],
                        order = 5,
                        width = 1.0,
                        func = function() Addon:TestPlayerJoins() end,
                        disabled = function() return not Addon.db.profile.testMode or not Addon.testState.simulatedGroupType end,
                    },
                },
            },
            simulateGuildEvents = {
                type = "group",
                name = L["Guild"],
                inline = true,
                order = 20,
                args = {
                    simulateGuild = {
                        type = "execute",
                        name = L["Guild Greeting"],
                        desc = L["Simulate guild login greeting"],
                        order = 1,
                        width = 0.8,
                        func = function() Addon:TestGuildGreeting() end,
                        disabled = function() return not Addon.db.profile.testMode end,
                    },
                    simulateGuildBye = {
                        type = "execute",
                        name = L["Guild Goodbye"],
                        desc = L["Simulate guild logout goodbye"],
                        order = 2,
                        width = 0.8,
                        func = function() Addon:TestGuildGoodbye() end,
                        disabled = function() return not Addon.db.profile.testMode end,
                    },
                    -- Guild Member Login simulation hidden until feature is fully working
                    -- simulateGuildMemberLogin = {
                    --     type = "execute",
                    --     name = L["Guild Member Login"],
                    --     desc = L["Simulate a guild member logging in"],
                    --     order = 3,
                    --     width = 1.0,
                    --     func = function() Addon:TestGuildMemberLogin() end,
                    --     disabled = function() return not Addon.db.profile.testMode end,
                    -- },
                },
            },
            simulateMythicPlus = {
                type = "group",
                name = L["Mythic+"],
                inline = true,
                order = 25,
                args = {
                    simulateRole = {
                        type = "select",
                        name = L["Simulate role"],
                        desc = L["Simulate role desc"],
                        order = 1,
                        width = 0.8,
                        values = {
                            leader = L["Leader"],
                            joined = L["Joined"],
                        },
                        sorting = { "leader", "joined" },
                        get = function() return Addon.testState.mythicPlusRole end,
                        set = function(_, val) Addon.testState.mythicPlusRole = val end,
                        disabled = function() return not Addon.db.profile.testMode end,
                    },
                    simulateKeyAnnounce = {
                        type = "execute",
                        name = L["Simulate M+ Flow"],
                        desc = L["Simulate M+ flow desc"],
                        order = 2,
                        width = 1.2,
                        func = function() Addon:TestMythicPlusFlow() end,
                        disabled = function() return not Addon.db.profile.testMode end,
                    },
                    simulateKeyStart = {
                        type = "execute",
                        name = L["Simulate Key Start"],
                        desc = L["Simulate key start desc"],
                        order = 3,
                        width = 1.2,
                        func = function() Addon:TestKeyStart() end,
                        disabled = function() return not Addon.db.profile.testMode end,
                    },
                    simulateTimed = {
                        type = "execute",
                        name = L["Simulate Timed"],
                        desc = L["Simulate completing a timed M+ key"],
                        order = 4,
                        width = 1.0,
                        func = function() Addon:TestCompletionTimed() end,
                        disabled = function() return not Addon.db.profile.testMode end,
                    },
                    simulateDepleted = {
                        type = "execute",
                        name = L["Simulate Depleted"],
                        desc = L["Simulate completing a depleted M+ key"],
                        order = 5,
                        width = 1.0,
                        func = function() Addon:TestCompletionDepleted() end,
                        disabled = function() return not Addon.db.profile.testMode end,
                    },
                },
            },
            simulationContext = {
                type = "group",
                name = L["Simulation context"],
                inline = true,
                order = 27,
                args = {
                    simulateAssignedRole = {
                        type = "select",
                        name = L["Simulate assigned role"],
                        desc = L["Simulate assigned role desc"],
                        order = 1,
                        width = 0.8,
                        values = {
                            TANK = L["Tank"],
                            HEALER = L["Healer"],
                            DAMAGER = L["DPS"],
                        },
                        sorting = { "TANK", "HEALER", "DAMAGER" },
                        get = function() return Addon.testState.simulatedRole end,
                        set = function(_, val) Addon.testState.simulatedRole = val end,
                        disabled = function() return not Addon.db.profile.testMode end,
                    },
                    simulateRealTime = {
                        type = "toggle",
                        name = L["Use real time"],
                        desc = L["Use real time desc"],
                        order = 2,
                        width = 0.8,
                        get = function() return Addon.testState.simulatedHour == nil end,
                        set = function(_, val)
                            if val then
                                Addon.testState.simulatedHour = nil
                            else
                                Addon.testState.simulatedHour = tonumber(date("%H"))
                            end
                        end,
                        disabled = function() return not Addon.db.profile.testMode end,
                    },
                    simulateHour = {
                        type = "range",
                        name = L["Simulate hour"],
                        desc = L["Simulate hour desc"],
                        order = 3,
                        width = 1.5,
                        min = 0, max = 23, step = 1,
                        get = function() return Addon.testState.simulatedHour or tonumber(date("%H")) end,
                        set = function(_, val) Addon.testState.simulatedHour = val end,
                        disabled = function() return not Addon.db.profile.testMode or Addon.testState.simulatedHour == nil end,
                    },
                },
            },
            statusGroup = {
                type = "group",
                name = L["Status"],
                inline = true,
                order = 30,
                args = {
                    currentStatus = {
                        type = "description",
                        name = function()
                            local status = "|cFFFFCC00Current Status:|r\n"
                            if Addon.db.profile.testMode then
                                status = status .. "Simulation: |cFF00FF00ON|r\n"
                            else
                                status = status .. "Simulation: |cFFFF0000OFF|r\n"
                            end

                            if Addon.testState.simulatedGroupType then
                                status = status .. "Simulated group: |cFFFFFF00" .. Addon.testState.simulatedGroupType .. "|r\n"
                            else
                                status = status .. "Simulated group: |cFF888888None|r\n"
                            end

                            local groupCooldown = math.max(0, Addon.db.profile.cooldown - (GetTime() - Addon.state.lastGroupMessageTime))
                            local guildCooldown = math.max(0, Addon.db.profile.cooldown - (GetTime() - Addon.state.lastGuildMessageTime))

                            status = status .. "Group cooldown: "
                            if groupCooldown > 0 then
                                status = status .. "|cFFFF8800" .. string.format("%.1f", groupCooldown) .. "s|r"
                            else
                                status = status .. "|cFF00FF00Ready|r"
                            end

                            status = status .. " | Guild cooldown: "
                            if guildCooldown > 0 then
                                status = status .. "|cFFFF8800" .. string.format("%.1f", guildCooldown) .. "s|r"
                            else
                                status = status .. "|cFF00FF00Ready|r"
                            end

                            return status
                        end,
                        order = 1,
                        fontSize = "medium",
                    },
                    resetButton = {
                        type = "execute",
                        name = L["Reset Test State"],
                        desc = L["Reset all test state and cooldowns"],
                        order = 2,
                        width = 1.0,
                        func = function() Addon:TestReset() end,
                        disabled = function() return not Addon.db.profile.testMode end,
                    },
                    refreshButton = {
                        type = "execute",
                        name = L["Refresh Status"],
                        desc = L["Refresh the status display"],
                        order = 3,
                        width = 0.8,
                        func = function()
                            -- Trigger options refresh
                            LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                        end,
                    },
                },
            },
            debugGroup = {
                type = "group",
                name = L["Debug"],
                inline = true,
                order = 40,
                args = {
                    debugMode = {
                        type = "toggle",
                        name = L["Debug mode"],
                        desc = L["Show debug messages in chat"],
                        order = 1,
                        width = "full",
                        get = function() return Addon.db.profile.debugMode end,
                        set = function(_, val) Addon.db.profile.debugMode = val end,
                    },
                    sessionLog = {
                        type = "toggle",
                        name = L["Record session log"],
                        desc = L["Record session log desc"],
                        order = 2,
                        width = 1.6,
                        get = function() return Addon:LoggingEnabled() and true or false end,
                        set = function(_, val)
                            if val then Addon:StartLogging() else Addon:StopLogging() end
                        end,
                    },
                    showLog = {
                        type = "execute",
                        name = L["Copy log"],
                        desc = L["Copy log desc"],
                        order = 3,
                        width = 1.0,
                        func = function() Addon:ShowLogWindow() end,
                    },
                    clearLog = {
                        type = "execute",
                        name = L["Clear log"],
                        order = 4,
                        width = 1.0,
                        func = function() Addon:ClearLog() end,
                    },
                },
            },
        },
    }
end
