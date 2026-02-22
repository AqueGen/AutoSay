local ADDON_NAME, AutoSay = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- Build greeting toggles for a specific channel
local function BuildGreetingToggles(channel)
    local args = {}
    local order = 1
    local defaultCount = 5 -- First 5 are enabled by default

    -- Triggers panels
    if channel == "guild" then
        args.selfJoinGroup = {
            type = "group",
            name = L["On login"],
            inline = true,
            order = order,
            args = {
                onSelfJoin = {
                    type = "toggle",
                    name = L["On login"],
                    desc = L["Send greeting when you log in"],
                    order = 1,
                    width = 1.2,
                    get = function() return Addon.db.profile.guild.onSelfJoin end,
                    set = function(_, val) Addon.db.profile.guild.onSelfJoin = val end,
                },
            },
        }
        order = order + 1
    else
        -- Panel 1: On self join
        args.selfJoinGroup = {
            type = "group",
            name = L["On self join"],
            inline = true,
            order = order,
            args = {
                onSelfJoin = {
                    type = "toggle",
                    name = L["On self join"],
                    desc = channel == "party" and L["Send greeting when you join a party"] or L["Send greeting when you join a raid"],
                    order = 1,
                    width = "full",
                    get = function() return Addon.db.profile[channel].onSelfJoin end,
                    set = function(_, val) Addon.db.profile[channel].onSelfJoin = val end,
                },
                includeGroupNames = {
                    type = "toggle",
                    name = L["Include group member names"],
                    desc = L["Add names of current group members to the greeting"],
                    order = 2,
                    width = "full",
                    hidden = function() return not Addon.db.profile[channel].onSelfJoin end,
                    get = function() return Addon.db.profile[channel].includeGroupNames end,
                    set = function(_, val) Addon.db.profile[channel].includeGroupNames = val end,
                },
            },
        }
        order = order + 1

        -- Panel 2: Greet newcomers
        args.othersJoinGroup = {
            type = "group",
            name = L["Greet newcomers"],
            inline = true,
            order = order,
            args = {
                onOthersJoin = {
                    type = "toggle",
                    name = L["On others join"],
                    desc = channel == "party" and L["Send greeting when others join your party"] or L["Send greeting when others join your raid"],
                    order = 1,
                    width = "full",
                    get = function() return Addon.db.profile[channel].onOthersJoin end,
                    set = function(_, val) Addon.db.profile[channel].onOthersJoin = val end,
                },
                onOthersJoinLeaderOnly = {
                    type = "toggle",
                    name = L["Only if leader"],
                    desc = channel == "party" and L["Only greet newcomers when you are the party leader"] or L["Only greet newcomers when you are the raid leader"],
                    order = 2,
                    width = "full",
                    hidden = function() return not Addon.db.profile[channel].onOthersJoin end,
                    get = function() return Addon.db.profile[channel].onOthersJoinLeaderOnly end,
                    set = function(_, val) Addon.db.profile[channel].onOthersJoinLeaderOnly = val end,
                },
                includeNames = {
                    type = "toggle",
                    name = L["Include player names"],
                    desc = L["Add joined player names to the greeting"],
                    order = 3,
                    width = "full",
                    hidden = function() return not Addon.db.profile[channel].onOthersJoin end,
                    get = function() return Addon.db.profile[channel].includeNames end,
                    set = function(_, val) Addon.db.profile[channel].includeNames = val end,
                },
            },
        }
        order = order + 1
    end

    -- Popular panel
    local popularArgs = {}
    for i = 1, math.min(defaultCount, #AutoSay.Greetings) do
        local msg = AutoSay.Greetings[i]
        popularArgs[msg.key] = {
            type = "toggle",
            name = msg.text,
            order = i,
            width = 1.0,
            get = function() return Addon.db.profile[channel].enabledGreetings[msg.key] end,
            set = function(_, val) Addon.db.profile[channel].enabledGreetings[msg.key] = val end,
        }
    end
    args.popularGroup = {
        type = "group",
        name = L["Popular"],
        inline = true,
        order = order,
        args = popularArgs,
    }
    order = order + 1

    -- More panel
    local moreArgs = {}
    for i = defaultCount + 1, #AutoSay.Greetings do
        local msg = AutoSay.Greetings[i]
        moreArgs[msg.key] = {
            type = "toggle",
            name = msg.text,
            order = i - defaultCount,
            width = 1.0,
            get = function() return Addon.db.profile[channel].enabledGreetings[msg.key] end,
            set = function(_, val) Addon.db.profile[channel].enabledGreetings[msg.key] = val end,
        }
    end
    args.moreGroup = {
        type = "group",
        name = L["More"],
        inline = true,
        order = order,
        args = moreArgs,
    }
    order = order + 1

    -- Custom greeting panel
    args.customGroup = {
        type = "group",
        name = L["Custom greeting"],
        inline = true,
        order = order,
        args = {
            useCustomGreeting = {
                type = "toggle",
                name = L["Use custom greeting"],
                desc = L["Include your custom greeting in the message pool"],
                order = 1,
                width = 1.2,
                get = function() return Addon.db.profile[channel].useCustomGreeting end,
                set = function(_, val) Addon.db.profile[channel].useCustomGreeting = val end,
            },
            customGreeting = {
                type = "input",
                name = L["Custom greeting"],
                desc = L["Enter your custom greeting message"],
                order = 2,
                width = "full",
                get = function() return Addon.db.profile[channel].customGreeting end,
                set = function(_, val) Addon.db.profile[channel].customGreeting = val end,
            },
        },
    }

    return args
end

-- Build reconnect toggles for a specific channel
local function BuildReconnectToggles(channel)
    local args = {}
    local order = 1
    local defaultCount = 3 -- First 3 are enabled by default

    -- Triggers panel
    args.triggersGroup = {
        type = "group",
        name = L["Triggers"],
        inline = true,
        order = order,
        args = {
            onReconnect = {
                type = "toggle",
                name = L["On reconnect"],
                desc = channel == "party" and L["Send greeting when you reconnect to party"] or L["Send greeting when you reconnect to raid"],
                order = 1,
                width = 1.5,
                get = function() return Addon.db.profile[channel].onReconnect end,
                set = function(_, val) Addon.db.profile[channel].onReconnect = val end,
            },
        },
    }
    order = order + 1

    -- Popular panel
    local popularArgs = {}
    for i = 1, math.min(defaultCount, #AutoSay.Reconnects) do
        local msg = AutoSay.Reconnects[i]
        popularArgs[msg.key] = {
            type = "toggle",
            name = msg.text,
            order = i,
            width = 1.0,
            get = function() return Addon.db.profile[channel].enabledReconnects[msg.key] end,
            set = function(_, val) Addon.db.profile[channel].enabledReconnects[msg.key] = val end,
        }
    end
    args.popularGroup = {
        type = "group",
        name = L["Popular"],
        inline = true,
        order = order,
        args = popularArgs,
    }
    order = order + 1

    -- More panel
    local moreArgs = {}
    for i = defaultCount + 1, #AutoSay.Reconnects do
        local msg = AutoSay.Reconnects[i]
        moreArgs[msg.key] = {
            type = "toggle",
            name = msg.text,
            order = i - defaultCount,
            width = 1.0,
            get = function() return Addon.db.profile[channel].enabledReconnects[msg.key] end,
            set = function(_, val) Addon.db.profile[channel].enabledReconnects[msg.key] = val end,
        }
    end
    args.moreGroup = {
        type = "group",
        name = L["More"],
        inline = true,
        order = order,
        args = moreArgs,
    }
    order = order + 1

    -- Custom reconnect panel
    args.customGroup = {
        type = "group",
        name = L["Custom reconnect"],
        inline = true,
        order = order,
        args = {
            useCustomReconnect = {
                type = "toggle",
                name = L["Use custom reconnect"],
                desc = L["Include your custom reconnect in the message pool"],
                order = 1,
                width = 1.2,
                get = function() return Addon.db.profile[channel].useCustomReconnect end,
                set = function(_, val) Addon.db.profile[channel].useCustomReconnect = val end,
            },
            customReconnect = {
                type = "input",
                name = L["Custom reconnect"],
                desc = L["Enter your custom reconnect message"],
                order = 2,
                width = "full",
                get = function() return Addon.db.profile[channel].customReconnect end,
                set = function(_, val) Addon.db.profile[channel].customReconnect = val end,
            },
        },
    }

    return args
end

-- Build goodbye toggles for a specific channel
local function BuildGoodbyeToggles(channel)
    local args = {}
    local order = 1
    local defaultCount = 5 -- First 5 are enabled by default

    -- Triggers panel
    local triggersArgs = {}
    if channel == "guild" then
        triggersArgs.sendGoodbye = {
            type = "toggle",
            name = L["On logout"],
            desc = L["Send goodbye when you log out"],
            order = 1,
            width = 1.2,
            get = function() return Addon.db.profile.guild.sendGoodbye end,
            set = function(_, val) Addon.db.profile.guild.sendGoodbye = val end,
        }
    else
        triggersArgs.sendGoodbye = {
            type = "toggle",
            name = L["Send goodbye on leave"],
            desc = channel == "party" and L["Send goodbye when leaving party"] or L["Send goodbye when leaving raid"],
            order = 1,
            width = 1.5,
            get = function() return Addon.db.profile[channel].sendGoodbye end,
            set = function(_, val) Addon.db.profile[channel].sendGoodbye = val end,
        }
    end
    args.triggersGroup = {
        type = "group",
        name = L["Triggers"],
        inline = true,
        order = order,
        args = triggersArgs,
    }
    order = order + 1

    -- Popular panel
    local popularArgs = {}
    for i = 1, math.min(defaultCount, #AutoSay.Goodbyes) do
        local msg = AutoSay.Goodbyes[i]
        popularArgs[msg.key] = {
            type = "toggle",
            name = msg.text,
            order = i,
            width = 1.0,
            get = function() return Addon.db.profile[channel].enabledGoodbyes[msg.key] end,
            set = function(_, val) Addon.db.profile[channel].enabledGoodbyes[msg.key] = val end,
        }
    end
    args.popularGroup = {
        type = "group",
        name = L["Popular"],
        inline = true,
        order = order,
        args = popularArgs,
    }
    order = order + 1

    -- More panel
    local moreArgs = {}
    for i = defaultCount + 1, #AutoSay.Goodbyes do
        local msg = AutoSay.Goodbyes[i]
        moreArgs[msg.key] = {
            type = "toggle",
            name = msg.text,
            order = i - defaultCount,
            width = 1.0,
            get = function() return Addon.db.profile[channel].enabledGoodbyes[msg.key] end,
            set = function(_, val) Addon.db.profile[channel].enabledGoodbyes[msg.key] = val end,
        }
    end
    args.moreGroup = {
        type = "group",
        name = L["More"],
        inline = true,
        order = order,
        args = moreArgs,
    }
    order = order + 1

    -- Custom goodbye panel
    args.customGroup = {
        type = "group",
        name = L["Custom goodbye"],
        inline = true,
        order = order,
        args = {
            useCustomGoodbye = {
                type = "toggle",
                name = L["Use custom goodbye"],
                desc = L["Include your custom goodbye in the message pool"],
                order = 1,
                width = 1.2,
                get = function() return Addon.db.profile[channel].useCustomGoodbye end,
                set = function(_, val) Addon.db.profile[channel].useCustomGoodbye = val end,
            },
            customGoodbye = {
                type = "input",
                name = L["Custom goodbye"],
                desc = L["Enter your custom goodbye message"],
                order = 2,
                width = "full",
                get = function() return Addon.db.profile[channel].customGoodbye end,
                set = function(_, val) Addon.db.profile[channel].customGoodbye = val end,
            },
        },
    }

    return args
end

-- Main options table
local options = {
    type = "group",
    name = "|cFF0099FFAuto|r|cFFFFD700Say|r",
    handler = Addon,
    args = {
        -- General settings
        general = {
            type = "group",
            name = L["General"],
            order = 1,
            args = {
                enabled = {
                    type = "toggle",
                    name = L["Enable addon"],
                    desc = L["Enable addon"],
                    order = 1,
                    width = "full",
                    get = function() return Addon.db.profile.enabled end,
                    set = function(_, val) Addon.db.profile.enabled = val end,
                },
                channelsGroup = {
                    type = "group",
                    name = L["Channels"],
                    inline = true,
                    order = 5,
                    args = {
                        enableParty = {
                            type = "toggle",
                            name = L["Enable Party"],
                            desc = L["Send greetings and goodbyes in party chat"],
                            order = 1,
                            width = "full",
                            get = function() return Addon.db.profile.party.enabled end,
                            set = function(_, val)
                                Addon.db.profile.party.enabled = val
                                LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                            end,
                        },
                        enableRaid = {
                            type = "toggle",
                            name = L["Enable Raid"],
                            desc = L["Send greetings and goodbyes in raid chat"],
                            order = 2,
                            width = "full",
                            get = function() return Addon.db.profile.raid.enabled end,
                            set = function(_, val)
                                Addon.db.profile.raid.enabled = val
                                LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                            end,
                        },
                        enableGuild = {
                            type = "toggle",
                            name = L["Enable Guild"],
                            desc = L["Send greetings and goodbyes to guild chat"],
                            order = 3,
                            width = "full",
                            get = function() return Addon.db.profile.guild.enabled end,
                            set = function(_, val)
                                Addon.db.profile.guild.enabled = val
                                LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                            end,
                        },
                    },
                },
                timingGroup = {
                    type = "group",
                    name = L["Timing"],
                    inline = true,
                    order = 10,
                    args = {
                        messageDelay = {
                            type = "range",
                            name = L["Message delay"],
                            desc = L["Delay before sending message (seconds)"],
                            order = 1,
                            min = 0,
                            max = 10,
                            step = 0.5,
                            width = "full",
                            get = function() return Addon.db.profile.messageDelay end,
                            set = function(_, val) Addon.db.profile.messageDelay = val end,
                        },
                        cooldown = {
                            type = "range",
                            name = L["Cooldown"],
                            desc = L["Minimum time between messages (seconds)"],
                            order = 2,
                            min = 0,
                            max = 300,
                            step = 5,
                            width = "full",
                            get = function() return Addon.db.profile.cooldown end,
                            set = function(_, val) Addon.db.profile.cooldown = val end,
                        },
                    },
                },
                testModeGroup = {
                    type = "group",
                    name = L["Test Mode"],
                    inline = true,
                    order = 17,
                    args = {
                        testModeEnabled = {
                            type = "toggle",
                            name = L["Enable Test Mode"],
                            desc = L["Enable test mode desc"],
                            order = 1,
                            width = "full",
                            get = function() return Addon.db.profile.testMode end,
                            set = function(_, val)
                                Addon.db.profile.testMode = val
                                if val then
                                    Addon:Print("|cFFFF9900Simulation:|r |cFF00FF00ON|r")
                                else
                                    Addon:Print("|cFFFF9900Simulation:|r |cFFFF0000OFF|r")
                                    Addon:TestReset()
                                    Addon.db.profile.debugMode = false
                                end
                                LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                            end,
                        },
                    },
                },
                resetWindowSize = {
                    type = "execute",
                    name = L["Reset window size"],
                    desc = L["Reset settings window to default size and position"],
                    order = 19,
                    width = 1.2,
                    func = function()
                        Addon.db.profile.configWindowStatus = nil
                        local AceConfigDialog = LibStub("AceConfigDialog-3.0")
                        local status = AceConfigDialog:GetStatusTable("AutoSay")
                        status.width = 1000
                        status.height = 700
                        status.top = nil
                        status.left = nil
                        local frame = AceConfigDialog.OpenFrames["AutoSay"]
                        if frame then
                            frame:SetWidth(1000)
                            frame:SetHeight(700)
                            frame.frame:ClearAllPoints()
                            frame.frame:SetPoint("CENTER")
                        end
                    end,
                },
                resetDefaults = {
                    type = "execute",
                    name = L["Reset to Defaults"],
                    desc = L["Reset all settings to default values"],
                    order = 20,
                    width = "full",
                    confirm = true,
                    confirmText = L["Are you sure you want to reset all settings to defaults?"],
                    func = function()
                        Addon.db:ResetProfile()
                        Addon:Print(L["Settings reset to defaults"])
                    end,
                },
            },
        },

        -- === PARTY ===
        party = {
            type = "group",
            name = "|cFF00FF00Party|r",
            order = 10,
            childGroups = "tab",
            hidden = function() return not Addon.db.profile.party.enabled end,
            args = {
                greetings = {
                    type = "group",
                    name = L["Greetings"],
                    order = 1,
                    args = BuildGreetingToggles("party"),
                },
                goodbyes = {
                    type = "group",
                    name = L["Goodbyes"],
                    order = 2,
                    args = BuildGoodbyeToggles("party"),
                },
                reconnects = {
                    type = "group",
                    name = L["Reconnects"],
                    order = 3,
                    args = BuildReconnectToggles("party"),
                },
            },
        },

        -- === RAID ===
        raid = {
            type = "group",
            name = "|cFFFF9900Raid|r",
            order = 20,
            childGroups = "tab",
            hidden = function() return not Addon.db.profile.raid.enabled end,
            args = {
                greetings = {
                    type = "group",
                    name = L["Greetings"],
                    order = 1,
                    args = BuildGreetingToggles("raid"),
                },
                goodbyes = {
                    type = "group",
                    name = L["Goodbyes"],
                    order = 2,
                    args = BuildGoodbyeToggles("raid"),
                },
                reconnects = {
                    type = "group",
                    name = L["Reconnects"],
                    order = 3,
                    args = BuildReconnectToggles("raid"),
                },
            },
        },

        -- === GUILD ===
        guild = {
            type = "group",
            name = "|cFF00CCFFGuild|r",
            order = 30,
            childGroups = "tab",
            hidden = function() return not Addon.db.profile.guild.enabled end,
            args = {
                greetings = {
                    type = "group",
                    name = L["Greetings"],
                    order = 1,
                    args = BuildGreetingToggles("guild"),
                },
                goodbyes = {
                    type = "group",
                    name = L["Goodbyes"],
                    order = 2,
                    args = BuildGoodbyeToggles("guild"),
                },
            },
        },

        -- Test mode settings
        testMode = {
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
                simulateGroup = {
                    type = "group",
                    name = L["Simulate Events"],
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
                        simulateGuild = {
                            type = "execute",
                            name = L["Guild Greeting"],
                            desc = L["Simulate guild login greeting"],
                            order = 5,
                            width = 0.8,
                            func = function() Addon:TestGuildGreeting() end,
                            disabled = function() return not Addon.db.profile.testMode end,
                        },
                        simulateGuildBye = {
                            type = "execute",
                            name = L["Guild Goodbye"],
                            desc = L["Simulate guild logout goodbye"],
                            order = 6,
                            width = 0.8,
                            func = function() Addon:TestGuildGoodbye() end,
                            disabled = function() return not Addon.db.profile.testMode end,
                        },
                    },
                },
                playerJoinGroup = {
                    type = "group",
                    name = L["Simulate Player Join"],
                    inline = true,
                    order = 20,
                    args = {
                        simulatePlayerJoin = {
                            type = "execute",
                            name = L["Random Player Joins"],
                            desc = L["Simulate a random player joining your group"],
                            order = 1,
                            width = 1.2,
                            func = function() Addon:TestPlayerJoins() end,
                            disabled = function() return not Addon.db.profile.testMode or not Addon.testState.simulatedGroupType end,
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
                    },
                },
            },
        },
    },
}

-- Register options
function Addon:SetupConfig()
    AceConfig:RegisterOptionsTable("AutoSay", options)
    AceConfigDialog:AddToBlizOptions("AutoSay", "AutoSay")
end

-- Hook into OnInitialize to setup config
local origOnInitialize = Addon.OnInitialize
function Addon:OnInitialize()
    origOnInitialize(self)
    self:SetupConfig()
end
