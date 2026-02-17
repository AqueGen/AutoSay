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

    -- Triggers section
    args.headerTriggers = {
        type = "header",
        name = L["Triggers"],
        order = order,
    }
    order = order + 1

    -- On self join (On login for guild)
    if channel == "guild" then
        args.onSelfJoin = {
            type = "toggle",
            name = L["On login"],
            desc = L["Send greeting when you log in"],
            order = order,
            width = 1.2,
            get = function() return Addon.db.profile.guild.onSelfJoin end,
            set = function(_, val) Addon.db.profile.guild.onSelfJoin = val end,
        }
        order = order + 1
    else
        args.onSelfJoin = {
            type = "toggle",
            name = L["On self join"],
            desc = channel == "party" and L["Send greeting when you join a party"] or L["Send greeting when you join a raid"],
            order = order,
            get = function() return Addon.db.profile[channel].onSelfJoin end,
            set = function(_, val) Addon.db.profile[channel].onSelfJoin = val end,
        }
        order = order + 1

        args.onOthersJoin = {
            type = "toggle",
            name = L["On others join"],
            desc = channel == "party" and L["Send greeting when others join your party"] or L["Send greeting when others join your raid"],
            order = order,
            get = function() return Addon.db.profile[channel].onOthersJoin end,
            set = function(_, val) Addon.db.profile[channel].onOthersJoin = val end,
        }
        order = order + 1

        args.includeNames = {
            type = "toggle",
            name = L["Include player names"],
            desc = L["Add joined player names to the greeting"],
            order = order,
            get = function() return Addon.db.profile[channel].includeNames end,
            set = function(_, val) Addon.db.profile[channel].includeNames = val end,
        }
        order = order + 1
    end

    -- Popular header
    args.headerPopular = {
        type = "header",
        name = L["Popular"],
        order = order,
    }
    order = order + 1

    -- All greetings with category headers
    for i, msg in ipairs(AutoSay.Greetings) do
        -- Add "More" header after default messages
        if i == defaultCount + 1 then
            args.headerMore = {
                type = "header",
                name = L["More"],
                order = order,
            }
            order = order + 1
        end

        args[msg.key] = {
            type = "toggle",
            name = msg.text,
            order = order,
            width = 1.0,
            get = function() return Addon.db.profile[channel].enabledGreetings[msg.key] end,
            set = function(_, val) Addon.db.profile[channel].enabledGreetings[msg.key] = val end,
        }
        order = order + 1
    end

    -- Custom greeting
    args.headerCustom = {
        type = "header",
        name = L["Custom greeting"],
        order = order,
    }
    order = order + 1

    args.useCustomGreeting = {
        type = "toggle",
        name = L["Use custom greeting"],
        desc = L["Include your custom greeting in the message pool"],
        order = order,
        width = 1.2,
        get = function() return Addon.db.profile[channel].useCustomGreeting end,
        set = function(_, val) Addon.db.profile[channel].useCustomGreeting = val end,
    }
    order = order + 1

    args.customGreeting = {
        type = "input",
        name = L["Custom greeting"],
        desc = L["Enter your custom greeting message"],
        order = order,
        width = "full",
        get = function() return Addon.db.profile[channel].customGreeting end,
        set = function(_, val) Addon.db.profile[channel].customGreeting = val end,
    }

    return args
end

-- Build reconnect toggles for a specific channel
local function BuildReconnectToggles(channel)
    local args = {}
    local order = 1
    local defaultCount = 3 -- First 3 are enabled by default

    -- Triggers section
    args.headerTriggers = {
        type = "header",
        name = L["Triggers"],
        order = order,
    }
    order = order + 1

    args.onReconnect = {
        type = "toggle",
        name = L["On reconnect"],
        desc = channel == "party" and L["Send greeting when you reconnect to party"] or L["Send greeting when you reconnect to raid"],
        order = order,
        width = 1.5,
        get = function() return Addon.db.profile[channel].onReconnect end,
        set = function(_, val) Addon.db.profile[channel].onReconnect = val end,
    }
    order = order + 1

    -- Popular header
    args.headerPopular = {
        type = "header",
        name = L["Popular"],
        order = order,
    }
    order = order + 1

    -- All reconnects with category headers
    for i, msg in ipairs(AutoSay.Reconnects) do
        -- Add "More" header after default messages
        if i == defaultCount + 1 then
            args.headerMore = {
                type = "header",
                name = L["More"],
                order = order,
            }
            order = order + 1
        end

        args[msg.key] = {
            type = "toggle",
            name = msg.text,
            order = order,
            width = 1.0,
            get = function() return Addon.db.profile[channel].enabledReconnects[msg.key] end,
            set = function(_, val) Addon.db.profile[channel].enabledReconnects[msg.key] = val end,
        }
        order = order + 1
    end

    -- Custom reconnect
    args.headerCustom = {
        type = "header",
        name = L["Custom reconnect"],
        order = order,
    }
    order = order + 1

    args.useCustomReconnect = {
        type = "toggle",
        name = L["Use custom reconnect"],
        desc = L["Include your custom reconnect in the message pool"],
        order = order,
        width = 1.2,
        get = function() return Addon.db.profile[channel].useCustomReconnect end,
        set = function(_, val) Addon.db.profile[channel].useCustomReconnect = val end,
    }
    order = order + 1

    args.customReconnect = {
        type = "input",
        name = L["Custom reconnect"],
        desc = L["Enter your custom reconnect message"],
        order = order,
        width = "full",
        get = function() return Addon.db.profile[channel].customReconnect end,
        set = function(_, val) Addon.db.profile[channel].customReconnect = val end,
    }

    return args
end

-- Build goodbye toggles for a specific channel
local function BuildGoodbyeToggles(channel)
    local args = {}
    local order = 1
    local defaultCount = 5 -- First 5 are enabled by default

    -- Triggers section
    args.headerTriggers = {
        type = "header",
        name = L["Triggers"],
        order = order,
    }
    order = order + 1

    if channel == "guild" then
        args.sendGoodbye = {
            type = "toggle",
            name = L["On logout"],
            desc = L["Send goodbye when you log out"],
            order = order,
            width = 1.2,
            get = function() return Addon.db.profile.guild.sendGoodbye end,
            set = function(_, val) Addon.db.profile.guild.sendGoodbye = val end,
        }
    else
        args.sendGoodbye = {
            type = "toggle",
            name = L["Send goodbye on leave"],
            desc = channel == "party" and L["Send goodbye when leaving party"] or L["Send goodbye when leaving raid"],
            order = order,
            width = 1.5,
            get = function() return Addon.db.profile[channel].sendGoodbye end,
            set = function(_, val) Addon.db.profile[channel].sendGoodbye = val end,
        }
    end
    order = order + 1

    -- Popular header
    args.headerPopular = {
        type = "header",
        name = L["Popular"],
        order = order,
    }
    order = order + 1

    -- All goodbyes with category headers
    for i, msg in ipairs(AutoSay.Goodbyes) do
        -- Add "More" header after default messages
        if i == defaultCount + 1 then
            args.headerMore = {
                type = "header",
                name = L["More"],
                order = order,
            }
            order = order + 1
        end

        args[msg.key] = {
            type = "toggle",
            name = msg.text,
            order = order,
            width = 1.0,
            get = function() return Addon.db.profile[channel].enabledGoodbyes[msg.key] end,
            set = function(_, val) Addon.db.profile[channel].enabledGoodbyes[msg.key] = val end,
        }
        order = order + 1
    end

    -- Custom goodbye
    args.headerCustom = {
        type = "header",
        name = L["Custom goodbye"],
        order = order,
    }
    order = order + 1

    args.useCustomGoodbye = {
        type = "toggle",
        name = L["Use custom goodbye"],
        desc = L["Include your custom goodbye in the message pool"],
        order = order,
        width = 1.2,
        get = function() return Addon.db.profile[channel].useCustomGoodbye end,
        set = function(_, val) Addon.db.profile[channel].useCustomGoodbye = val end,
    }
    order = order + 1

    args.customGoodbye = {
        type = "input",
        name = L["Custom goodbye"],
        desc = L["Enter your custom goodbye message"],
        order = order,
        width = "full",
        get = function() return Addon.db.profile[channel].customGoodbye end,
        set = function(_, val) Addon.db.profile[channel].customGoodbye = val end,
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
                headerChannels = {
                    type = "header",
                    name = L["Channels"],
                    order = 5,
                },
                enableParty = {
                    type = "toggle",
                    name = L["Enable Party"],
                    desc = L["Send greetings and goodbyes in party chat"],
                    order = 6,
                    width = "full",
                    get = function() return Addon.db.profile.party.enabled end,
                    set = function(_, val) Addon.db.profile.party.enabled = val end,
                },
                enableRaid = {
                    type = "toggle",
                    name = L["Enable Raid"],
                    desc = L["Send greetings and goodbyes in raid chat"],
                    order = 7,
                    width = "full",
                    get = function() return Addon.db.profile.raid.enabled end,
                    set = function(_, val) Addon.db.profile.raid.enabled = val end,
                },
                enableGuild = {
                    type = "toggle",
                    name = L["Enable Guild"],
                    desc = L["Send greetings and goodbyes to guild chat"],
                    order = 8,
                    width = "full",
                    get = function() return Addon.db.profile.guild.enabled end,
                    set = function(_, val) Addon.db.profile.guild.enabled = val end,
                },
                headerTiming = {
                    type = "header",
                    name = L["Timing"],
                    order = 10,
                },
                messageDelay = {
                    type = "range",
                    name = L["Message delay"],
                    desc = L["Delay before sending message (seconds)"],
                    order = 11,
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
                    order = 12,
                    min = 0,
                    max = 300,
                    step = 5,
                    width = "full",
                    get = function() return Addon.db.profile.cooldown end,
                    set = function(_, val) Addon.db.profile.cooldown = val end,
                },
                headerReset = {
                    type = "header",
                    name = "",
                    order = 20,
                },
                resetDefaults = {
                    type = "execute",
                    name = L["Reset to Defaults"],
                    desc = L["Reset all settings to default values"],
                    order = 21,
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
        partyGreetings = {
            type = "group",
            name = "|cFF00FF00Party|r Greetings",
            order = 10,
            args = BuildGreetingToggles("party"),
        },

        partyGoodbyes = {
            type = "group",
            name = "|cFF00FF00Party|r Goodbyes",
            order = 11,
            args = BuildGoodbyeToggles("party"),
        },

        partyReconnects = {
            type = "group",
            name = "|cFF00FF00Party|r Reconnects",
            order = 12,
            args = BuildReconnectToggles("party"),
        },

        -- === RAID ===
        raidGreetings = {
            type = "group",
            name = "|cFFFF9900Raid|r Greetings",
            order = 20,
            args = BuildGreetingToggles("raid"),
        },

        raidGoodbyes = {
            type = "group",
            name = "|cFFFF9900Raid|r Goodbyes",
            order = 21,
            args = BuildGoodbyeToggles("raid"),
        },

        raidReconnects = {
            type = "group",
            name = "|cFFFF9900Raid|r Reconnects",
            order = 22,
            args = BuildReconnectToggles("raid"),
        },

        -- === GUILD ===
        guildGreetings = {
            type = "group",
            name = "|cFF00CCFFGuild|r Greetings",
            order = 30,
            args = BuildGreetingToggles("guild"),
        },

        guildGoodbyes = {
            type = "group",
            name = "|cFF00CCFFGuild|r Goodbyes",
            order = 31,
            args = BuildGoodbyeToggles("guild"),
        },

        -- Test mode settings
        testMode = {
            type = "group",
            name = L["Test Mode"],
            order = 50,
            args = {
                description = {
                    type = "description",
                    name = L["Test mode description"],
                    order = 0,
                    fontSize = "medium",
                },
                headerToggle = {
                    type = "header",
                    name = L["Test Mode Toggle"],
                    order = 1,
                },
                testModeEnabled = {
                    type = "toggle",
                    name = L["Enable Test Mode"],
                    desc = L["Enable test mode desc"],
                    order = 2,
                    width = "full",
                    get = function() return Addon.db.profile.testMode end,
                    set = function(_, val)
                        Addon.db.profile.testMode = val
                        if val then
                            Addon:Print("|cFFFF9900Test mode:|r |cFF00FF00ON|r")
                        else
                            Addon:Print("|cFFFF9900Test mode:|r |cFFFF0000OFF|r")
                            Addon:TestReset()
                        end
                    end,
                },
                headerSimulate = {
                    type = "header",
                    name = L["Simulate Events"],
                    order = 10,
                },
                simulateParty = {
                    type = "execute",
                    name = L["Join Party"],
                    desc = L["Simulate joining a party"],
                    order = 11,
                    width = 0.8,
                    func = function() Addon:TestJoinParty() end,
                    disabled = function() return not Addon.db.profile.testMode end,
                },
                simulateRaid = {
                    type = "execute",
                    name = L["Join Raid"],
                    desc = L["Simulate joining a raid"],
                    order = 12,
                    width = 0.8,
                    func = function() Addon:TestJoinRaid() end,
                    disabled = function() return not Addon.db.profile.testMode end,
                },
                simulateLeave = {
                    type = "execute",
                    name = L["Leave Group"],
                    desc = L["Simulate leaving current group"],
                    order = 13,
                    width = 0.8,
                    func = function() Addon:TestLeaveGroup() end,
                    disabled = function() return not Addon.db.profile.testMode or not Addon.testState.simulatedGroupType end,
                },
                simulateReconnect = {
                    type = "execute",
                    name = L["Reconnect"],
                    desc = L["Simulate reconnecting to group"],
                    order = 14,
                    width = 0.8,
                    func = function() Addon:TestReconnect() end,
                    disabled = function() return not Addon.db.profile.testMode or not Addon.testState.simulatedGroupType end,
                },
                simulateGuild = {
                    type = "execute",
                    name = L["Guild Greeting"],
                    desc = L["Simulate guild login greeting"],
                    order = 15,
                    width = 0.8,
                    func = function() Addon:TestGuildGreeting() end,
                    disabled = function() return not Addon.db.profile.testMode end,
                },
                simulateGuildBye = {
                    type = "execute",
                    name = L["Guild Goodbye"],
                    desc = L["Simulate guild logout goodbye"],
                    order = 16,
                    width = 0.8,
                    func = function() Addon:TestGuildGoodbye() end,
                    disabled = function() return not Addon.db.profile.testMode end,
                },
                headerPlayerJoin = {
                    type = "header",
                    name = L["Simulate Player Join"],
                    order = 20,
                },
                simulatePlayerJoin = {
                    type = "execute",
                    name = L["Random Player Joins"],
                    desc = L["Simulate a random player joining your group"],
                    order = 21,
                    width = 1.2,
                    func = function() Addon:TestPlayerJoins() end,
                    disabled = function() return not Addon.db.profile.testMode or not Addon.testState.simulatedGroupType end,
                },
                headerStatus = {
                    type = "header",
                    name = L["Status"],
                    order = 30,
                },
                currentStatus = {
                    type = "description",
                    name = function()
                        local status = "|cFFFFCC00Current Status:|r\n"
                        if Addon.db.profile.testMode then
                            status = status .. "Test mode: |cFF00FF00ON|r\n"
                        else
                            status = status .. "Test mode: |cFFFF0000OFF|r\n"
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
                    order = 31,
                    fontSize = "medium",
                },
                resetButton = {
                    type = "execute",
                    name = L["Reset Test State"],
                    desc = L["Reset all test state and cooldowns"],
                    order = 32,
                    width = 1.0,
                    func = function() Addon:TestReset() end,
                    disabled = function() return not Addon.db.profile.testMode end,
                },
                refreshButton = {
                    type = "execute",
                    name = L["Refresh Status"],
                    desc = L["Refresh the status display"],
                    order = 33,
                    width = 0.8,
                    func = function()
                        -- Trigger options refresh
                        LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                    end,
                },
                headerDebug = {
                    type = "header",
                    name = L["Debug"],
                    order = 40,
                },
                debugMode = {
                    type = "toggle",
                    name = L["Debug mode"],
                    desc = L["Show debug messages in chat"],
                    order = 41,
                    width = "full",
                    get = function() return Addon.db.profile.debugMode end,
                    set = function(_, val) Addon.db.profile.debugMode = val end,
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
