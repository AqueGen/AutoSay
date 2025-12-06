local ADDON_NAME, AutoSay = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- Build greeting toggles for a specific channel
local function BuildGreetingToggles(channel)
    local args = {}
    local order = 1

    -- Header for English greetings
    args.headerEnglish = {
        type = "header",
        name = "English / Common",
        order = order,
    }
    order = order + 1

    -- English greetings (1-12)
    for i = 1, 12 do
        local msg = AutoSay.Greetings[i]
        if msg then
            args[msg.key] = {
                type = "toggle",
                name = msg.text,
                order = order,
                width = 0.6,
                get = function() return Addon.db.profile[channel].enabledGreetings[msg.key] end,
                set = function(_, val) Addon.db.profile[channel].enabledGreetings[msg.key] = val end,
            }
            order = order + 1
        end
    end

    -- Header for International greetings
    args.headerInternational = {
        type = "header",
        name = "International",
        order = order,
    }
    order = order + 1

    -- International greetings (13-24)
    for i = 13, #AutoSay.Greetings do
        local msg = AutoSay.Greetings[i]
        if msg then
            args[msg.key] = {
                type = "toggle",
                name = msg.text,
                order = order,
                width = 0.7,
                get = function() return Addon.db.profile[channel].enabledGreetings[msg.key] end,
                set = function(_, val) Addon.db.profile[channel].enabledGreetings[msg.key] = val end,
            }
            order = order + 1
        end
    end

    -- Custom greeting
    args.headerCustom = {
        type = "header",
        name = L["Custom greeting"],
        order = order,
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

-- Build farewell toggles for a specific channel
local function BuildFarewellToggles(channel)
    local args = {}
    local order = 1

    -- Header for English farewells
    args.headerEnglish = {
        type = "header",
        name = "English / Common",
        order = order,
    }
    order = order + 1

    -- English farewells (1-12)
    for i = 1, 12 do
        local msg = AutoSay.Farewells[i]
        if msg then
            args[msg.key] = {
                type = "toggle",
                name = msg.text,
                order = order,
                width = 0.6,
                get = function() return Addon.db.profile[channel].enabledFarewells[msg.key] end,
                set = function(_, val) Addon.db.profile[channel].enabledFarewells[msg.key] = val end,
            }
            order = order + 1
        end
    end

    -- Header for International farewells
    args.headerInternational = {
        type = "header",
        name = "International",
        order = order,
    }
    order = order + 1

    -- International farewells (13+)
    for i = 13, #AutoSay.Farewells do
        local msg = AutoSay.Farewells[i]
        if msg then
            args[msg.key] = {
                type = "toggle",
                name = msg.text,
                order = order,
                width = 0.7,
                get = function() return Addon.db.profile[channel].enabledFarewells[msg.key] end,
                set = function(_, val) Addon.db.profile[channel].enabledFarewells[msg.key] = val end,
            }
            order = order + 1
        end
    end

    -- Custom farewell
    args.headerCustom = {
        type = "header",
        name = L["Custom farewell"],
        order = order,
    }
    order = order + 1

    args.customFarewell = {
        type = "input",
        name = L["Custom farewell"],
        desc = L["Enter your custom farewell message"],
        order = order,
        width = "full",
        get = function() return Addon.db.profile[channel].customFarewell end,
        set = function(_, val) Addon.db.profile[channel].customFarewell = val end,
    }

    return args
end

-- Main options table
local options = {
    type = "group",
    name = "AutoSay",
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
            },
        },

        -- Party settings
        partySettings = {
            type = "group",
            name = L["Party"],
            order = 2,
            args = {
                enabled = {
                    type = "toggle",
                    name = L["Enable Party greetings"],
                    desc = L["Send greetings to party chat"],
                    order = 1,
                    width = "full",
                    get = function() return Addon.db.profile.party.enabled end,
                    set = function(_, val) Addon.db.profile.party.enabled = val end,
                },
                headerTriggers = {
                    type = "header",
                    name = L["Triggers"],
                    order = 10,
                },
                onSelfJoin = {
                    type = "toggle",
                    name = L["On self join"],
                    desc = L["Send greeting when you join a party"],
                    order = 11,
                    get = function() return Addon.db.profile.party.onSelfJoin end,
                    set = function(_, val) Addon.db.profile.party.onSelfJoin = val end,
                },
                onOthersJoin = {
                    type = "toggle",
                    name = L["On others join"],
                    desc = L["Send greeting when others join your party"],
                    order = 12,
                    get = function() return Addon.db.profile.party.onOthersJoin end,
                    set = function(_, val) Addon.db.profile.party.onOthersJoin = val end,
                },
                includeNames = {
                    type = "toggle",
                    name = L["Include player names"],
                    desc = L["Add joined player names to the greeting"],
                    order = 13,
                    get = function() return Addon.db.profile.party.includeNames end,
                    set = function(_, val) Addon.db.profile.party.includeNames = val end,
                },
                headerFarewell = {
                    type = "header",
                    name = L["Farewells"],
                    order = 20,
                },
                sendFarewell = {
                    type = "toggle",
                    name = L["Send farewell on leave"],
                    desc = L["Send farewell when leaving party"],
                    order = 21,
                    get = function() return Addon.db.profile.party.sendFarewell end,
                    set = function(_, val) Addon.db.profile.party.sendFarewell = val end,
                },
            },
        },

        -- Party greeting messages
        partyGreetings = {
            type = "group",
            name = L["Party Greetings"],
            order = 3,
            args = BuildGreetingToggles("party"),
        },

        -- Party farewell messages
        partyFarewells = {
            type = "group",
            name = L["Party Farewells"],
            order = 4,
            args = BuildFarewellToggles("party"),
        },

        -- Raid settings
        raidSettings = {
            type = "group",
            name = L["Raid"],
            order = 5,
            args = {
                enabled = {
                    type = "toggle",
                    name = L["Enable Raid greetings"],
                    desc = L["Send greetings to raid chat"],
                    order = 1,
                    width = "full",
                    get = function() return Addon.db.profile.raid.enabled end,
                    set = function(_, val) Addon.db.profile.raid.enabled = val end,
                },
                headerTriggers = {
                    type = "header",
                    name = L["Triggers"],
                    order = 10,
                },
                onSelfJoin = {
                    type = "toggle",
                    name = L["On self join"],
                    desc = L["Send greeting when you join a raid"],
                    order = 11,
                    get = function() return Addon.db.profile.raid.onSelfJoin end,
                    set = function(_, val) Addon.db.profile.raid.onSelfJoin = val end,
                },
                onOthersJoin = {
                    type = "toggle",
                    name = L["On others join"],
                    desc = L["Send greeting when others join your raid"],
                    order = 12,
                    get = function() return Addon.db.profile.raid.onOthersJoin end,
                    set = function(_, val) Addon.db.profile.raid.onOthersJoin = val end,
                },
                includeNames = {
                    type = "toggle",
                    name = L["Include player names"],
                    desc = L["Add joined player names to the greeting"],
                    order = 13,
                    get = function() return Addon.db.profile.raid.includeNames end,
                    set = function(_, val) Addon.db.profile.raid.includeNames = val end,
                },
                headerFarewell = {
                    type = "header",
                    name = L["Farewells"],
                    order = 20,
                },
                sendFarewell = {
                    type = "toggle",
                    name = L["Send farewell on leave"],
                    desc = L["Send farewell when leaving raid"],
                    order = 21,
                    get = function() return Addon.db.profile.raid.sendFarewell end,
                    set = function(_, val) Addon.db.profile.raid.sendFarewell = val end,
                },
            },
        },

        -- Raid greeting messages
        raidGreetings = {
            type = "group",
            name = L["Raid Greetings"],
            order = 6,
            args = BuildGreetingToggles("raid"),
        },

        -- Raid farewell messages
        raidFarewells = {
            type = "group",
            name = L["Raid Farewells"],
            order = 7,
            args = BuildFarewellToggles("raid"),
        },

        -- Guild settings
        guildSettings = {
            type = "group",
            name = L["Guild"],
            order = 8,
            args = {
                enabled = {
                    type = "toggle",
                    name = L["Enable Guild"],
                    desc = L["Send greetings and farewells to guild chat"],
                    order = 1,
                    width = "full",
                    get = function() return Addon.db.profile.guild.enabled end,
                    set = function(_, val) Addon.db.profile.guild.enabled = val end,
                },
                headerTriggers = {
                    type = "header",
                    name = L["Triggers"],
                    order = 10,
                },
                onSelfJoin = {
                    type = "toggle",
                    name = L["On login"],
                    desc = L["Send greeting when you log in"],
                    order = 11,
                    get = function() return Addon.db.profile.guild.onSelfJoin end,
                    set = function(_, val) Addon.db.profile.guild.onSelfJoin = val end,
                },
                headerFarewell = {
                    type = "header",
                    name = L["Farewells"],
                    order = 20,
                },
                sendFarewell = {
                    type = "toggle",
                    name = L["On logout"],
                    desc = L["Send farewell when you log out"],
                    order = 21,
                    get = function() return Addon.db.profile.guild.sendFarewell end,
                    set = function(_, val) Addon.db.profile.guild.sendFarewell = val end,
                },
            },
        },

        -- Guild greeting messages
        guildGreetings = {
            type = "group",
            name = L["Guild Greetings"],
            order = 9,
            args = BuildGreetingToggles("guild"),
        },

        -- Guild farewell messages
        guildFarewells = {
            type = "group",
            name = L["Guild Farewells"],
            order = 10,
            args = BuildFarewellToggles("guild"),
        },

        -- Test mode settings
        testMode = {
            type = "group",
            name = L["Test Mode"],
            order = 11,
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
                simulateGuild = {
                    type = "execute",
                    name = L["Guild Greeting"],
                    desc = L["Simulate guild login greeting"],
                    order = 14,
                    width = 0.8,
                    func = function() Addon:TestGuildGreeting() end,
                    disabled = function() return not Addon.db.profile.testMode end,
                },
                simulateGuildBye = {
                    type = "execute",
                    name = L["Guild Farewell"],
                    desc = L["Simulate guild logout farewell"],
                    order = 15,
                    width = 0.8,
                    func = function() Addon:TestGuildFarewell() end,
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

                        local cooldownRemaining = math.max(0, Addon.db.profile.cooldown - (GetTime() - Addon.state.lastMessageTime))
                        if cooldownRemaining > 0 then
                            status = status .. "Cooldown: |cFFFF8800" .. string.format("%.1f", cooldownRemaining) .. "s|r"
                        else
                            status = status .. "Cooldown: |cFF00FF00Ready|r"
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
