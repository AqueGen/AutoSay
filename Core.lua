local ADDON_NAME, AutoSay = ...

-- Create addon using Ace3
local Addon = LibStub("AceAddon-3.0"):NewAddon(AutoSay, ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

-- Version (replaced by packager with git tag)
Addon.version = "@project-version@"

-- Debug print helper
function Addon:DebugPrint(...)
    if self.db and self.db.profile.debugMode then
        print("|cFF00FF00[AutoSay Debug]|r", ...)
    end
end

-- Test mode print helper
function Addon:TestPrint(...)
    if self.db and self.db.profile.testMode then
        print("|cFFFF9900[AutoSay TEST]|r", ...)
    end
end

-- Check if we're in test mode
function Addon:IsTestMode()
    return self.db and self.db.profile.testMode
end

-- Default enabled greetings
local defaultGreetings = {
    hi = true,
    hello = true,
    hey = true,
    yo = true,
    heya = true,
    sup = true,
    howdy = true,
    hiya = true,
    greetings = true,
    wassup = true,
    yoyo = true,
    hellothere = true,
    -- International disabled by default
    hola = false,
    ciao = false,
    bonjour = false,
    konnichiwa = false,
    annyeong = false,
    nihao = false,
    merhaba = false,
    salve = false,
    aloha = false,
    shalom = false,
    sawubona = false,
    namaste = false,
}

-- Default enabled farewells
local defaultFarewells = {
    bye = true,
    goodbye = true,
    seeya = true,
    later = true,
    cya = true,
    takecare = true,
    peace = true,
    cheers = true,
    gn = false,
    bb = false,
    gtg = true,
    laterall = true,
    -- International disabled by default
    adios = false,
    ciaofarewell = false,
    aurevoir = false,
    sayonara = false,
    annyeongbye = false,
    zaijian = false,
    tschuss = false,
    dosvidaniya = false,
}

-- Deep copy helper for defaults
local function DeepCopy(orig)
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = v
    end
    return copy
end

-- Default database settings
local defaults = {
    profile = {
        enabled = true,
        debugMode = false,
        testMode = false,

        -- Timing (global)
        messageDelay = 1.0,
        cooldown = 30,

        -- Party settings
        party = {
            enabled = true,
            onSelfJoin = true,
            onOthersJoin = true,
            includeNames = true,
            sendFarewell = true,
            enabledGreetings = DeepCopy(defaultGreetings),
            enabledFarewells = DeepCopy(defaultFarewells),
            customGreeting = "",
            customFarewell = "",
        },

        -- Raid settings
        raid = {
            enabled = true,
            onSelfJoin = true,
            onOthersJoin = false, -- Disabled by default for raids (too many people)
            includeNames = false, -- Disabled by default for raids
            sendFarewell = true,
            enabledGreetings = DeepCopy(defaultGreetings),
            enabledFarewells = DeepCopy(defaultFarewells),
            customGreeting = "",
            customFarewell = "",
        },

        -- Guild settings (same structure as party/raid)
        guild = {
            enabled = true,
            onSelfJoin = true,  -- Send greeting on login
            sendFarewell = true, -- Send farewell on logout
            enabledGreetings = DeepCopy(defaultGreetings),
            enabledFarewells = DeepCopy(defaultFarewells),
            customGreeting = "",
            customFarewell = "",
        },
    },
}

-- State tracking
Addon.state = {
    previousGroup = nil,
    lastMessageTime = 0,
    pendingFarewell = false,
    currentGroupType = nil,
    sentGreetings = {},
}

-- Test mode simulation state
Addon.testState = {
    simulatedGroupType = nil, -- "PARTY", "RAID", or nil
    simulatedInGuild = false,
    simulatedGroupMembers = {},
}

function Addon:OnInitialize()
    -- Initialize database
    self.db = LibStub("AceDB-3.0"):New("AutoSayDB", defaults, true)

    -- Register slash commands
    self:RegisterChatCommand("autosay", "SlashCommand")
    self:RegisterChatCommand("as", "SlashCommand")

    self:DebugPrint("Addon initialized")
end

function Addon:OnEnable()
    -- Register events
    self:RegisterEvents()

    self:DebugPrint("Addon enabled")
end

function Addon:OnDisable()
    -- Unregister events
    self:UnregisterAllEvents()

    self:DebugPrint("Addon disabled")
end

function Addon:SlashCommand(input)
    local cmd, arg1 = self:GetArgs(input, 2)
    cmd = cmd and cmd:lower() or ""

    if cmd == "toggle" then
        self.db.profile.enabled = not self.db.profile.enabled
        if self.db.profile.enabled then
            self:Print(L["Addon enabled"])
        else
            self:Print(L["Addon disabled"])
        end
    elseif cmd == "debug" then
        self.db.profile.debugMode = not self.db.profile.debugMode
        self:Print("Debug mode:", self.db.profile.debugMode and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r")
    elseif cmd == "testmode" or cmd == "test" and not arg1 then
        self.db.profile.testMode = not self.db.profile.testMode
        if self.db.profile.testMode then
            self:Print("|cFFFF9900Test mode:|r |cFF00FF00ON|r - Messages will be printed, not sent")
            self:Print("Use |cFFFFFF00/as help|r to see test commands")
        else
            self:Print("|cFFFF9900Test mode:|r |cFFFF0000OFF|r")
            self:TestReset()
        end
    -- Test simulation commands
    elseif cmd == "test" then
        local subcmd = arg1 and arg1:lower() or ""
        if subcmd == "party" or subcmd == "p" then
            self:TestJoinParty()
        elseif subcmd == "raid" or subcmd == "r" then
            self:TestJoinRaid()
        elseif subcmd == "leave" or subcmd == "l" then
            self:TestLeaveGroup()
        elseif subcmd == "guild" or subcmd == "g" then
            self:TestGuildGreeting()
        elseif subcmd == "guildbye" or subcmd == "gb" then
            self:TestGuildFarewell()
        elseif subcmd == "player" or subcmd == "join" then
            local _, _, playerName = self:GetArgs(input, 3)
            self:TestPlayerJoins(playerName)
        elseif subcmd == "reset" then
            self:TestReset()
        elseif subcmd == "status" or subcmd == "s" then
            self:TestStatus()
        else
            self:Print("|cFFFF9900Test commands:|r")
            self:Print("  /as test party - Simulate joining a party")
            self:Print("  /as test raid - Simulate joining a raid")
            self:Print("  /as test leave - Simulate leaving group")
            self:Print("  /as test guild - Simulate guild login greeting")
            self:Print("  /as test guildbye - Simulate guild logout farewell")
            self:Print("  /as test player [name] - Simulate player joining")
            self:Print("  /as test reset - Reset test state")
            self:Print("  /as test status - Show test status")
        end
    elseif cmd == "status" then
        self:TestStatus()
    elseif cmd == "help" or cmd == "?" then
        self:Print("|cFFFFCC00AutoSay Commands:|r")
        self:Print("  /as - Open settings")
        self:Print("  /as toggle - Enable/disable addon")
        self:Print("  /as debug - Toggle debug mode")
        self:Print("  /as testmode - Toggle test mode")
        self:Print("  /as test [cmd] - Run test simulation")
        self:Print("  /as status - Show current status")
        self:Print("  /as help - Show this help")
    else
        -- Open settings
        self:OpenConfig()
    end
end

function Addon:OpenConfig()
    Settings.OpenToCategory("AutoSay")
end

-- Check if cooldown has passed
function Addon:CanSendMessage()
    local now = GetTime()
    local cooldown = self.db.profile.cooldown

    if (now - self.state.lastMessageTime) < cooldown then
        self:DebugPrint("Cooldown active, skipping message")
        return false
    end

    return true
end

-- Send a message to chat
function Addon:SendMessageToChat(message, channel, target)
    if not self.db.profile.enabled then
        self:DebugPrint("Addon disabled, not sending")
        return
    end

    if not self:CanSendMessage() then
        return
    end

    local delay = self.db.profile.messageDelay

    if delay and delay > 0 then
        self:ScheduleTimer(function()
            self:DoSendMessage(message, channel, target)
        end, delay)
        self:DebugPrint("Scheduled message in", delay, "seconds")
    else
        self:DoSendMessage(message, channel, target)
    end
end

function Addon:DoSendMessage(message, channel, target)
    if not message then
        self:DebugPrint("No message to send")
        return
    end

    -- In test mode, print to chat instead of actually sending
    if self:IsTestMode() then
        local channelColor = "|cFF00CCFF" -- Default blue
        if channel == "RAID" then
            channelColor = "|cFFFF7F00" -- Orange
        elseif channel == "GUILD" then
            channelColor = "|cFF40FF40" -- Green
        elseif channel == "PARTY" then
            channelColor = "|cFFAAAAFF" -- Light blue
        end

        print("|cFFFF9900[AutoSay TEST]|r Would send to " .. channelColor .. "[" .. channel .. "]|r: " .. message)
        self.state.lastMessageTime = GetTime()
        self:DebugPrint("Test mode - simulated send to", channel, ":", message)
        return
    end

    SendChatMessage(message, channel, nil, target)
    self.state.lastMessageTime = GetTime()

    self:DebugPrint("Sent to", channel, ":", message)
end

-- Get appropriate chat channel
function Addon:GetChatChannel()
    -- In test mode, use simulated group type
    if self:IsTestMode() and self.testState.simulatedGroupType then
        return self.testState.simulatedGroupType
    end

    if IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    end
    return nil
end

-- Check if in guild (with test mode support)
function Addon:IsInGuildOrTest()
    if self:IsTestMode() then
        return self.testState.simulatedInGuild
    end
    return IsInGuild()
end

-- Get channel settings table
function Addon:GetChannelSettings(channel)
    local db = self.db.profile
    if channel == "PARTY" then
        return db.party
    elseif channel == "RAID" then
        return db.raid
    elseif channel == "GUILD" then
        return db.guild
    end
    return nil
end

-- Get random message for a channel
function Addon:GetRandomMessageForChannel(messageType, channel)
    local settings = self:GetChannelSettings(channel)
    if not settings then return nil end

    local messages = messageType == "greetings" and AutoSay.Greetings or AutoSay.Farewells
    local enabledKey = messageType == "greetings" and "enabledGreetings" or "enabledFarewells"
    local customKey = messageType == "greetings" and "customGreeting" or "customFarewell"

    local enabled = {}

    -- Add enabled preset messages
    if settings[enabledKey] then
        for _, msg in ipairs(messages) do
            if settings[enabledKey][msg.key] then
                table.insert(enabled, msg.text)
            end
        end
    end

    -- Add custom message if set
    if settings[customKey] and settings[customKey] ~= "" then
        table.insert(enabled, settings[customKey])
    end

    if #enabled == 0 then
        return nil
    end

    return enabled[math.random(#enabled)]
end

-- Add player names to message
function Addon:AddPlayersToMessage(message, playerNames, includeNames)
    if not includeNames or not playerNames or #playerNames == 0 then
        return message
    end

    return message .. " " .. table.concat(playerNames, ", ")
end

-- Send greeting
function Addon:SendGreeting(playerNames, reason)
    local db = self.db.profile

    if not db.enabled then return end

    local channel = self:GetChatChannel()
    if not channel then
        self:DebugPrint("Not in group, skipping greeting")
        return
    end

    local settings = self:GetChannelSettings(channel)
    if not settings then return end

    -- Check if channel is enabled
    if not settings.enabled then
        self:DebugPrint(channel, "greetings disabled")
        return
    end

    -- Get random greeting for this channel
    local message = self:GetRandomMessageForChannel("greetings", channel)
    if not message then
        self:DebugPrint("No greetings enabled for", channel)
        return
    end

    -- Add player names if enabled for this channel
    local includeNames = settings.includeNames or false
    message = self:AddPlayersToMessage(message, playerNames, includeNames)

    self:SendMessageToChat(message, channel)
end

-- Send farewell
function Addon:SendFarewell(channel)
    local db = self.db.profile

    if not db.enabled then return end

    local settings = self:GetChannelSettings(channel)
    if not settings then return end

    -- Check if farewell is enabled for this channel
    if not settings.sendFarewell then
        self:DebugPrint(channel, "farewells disabled")
        return
    end

    -- Get random farewell for this channel
    local message = self:GetRandomMessageForChannel("farewells", channel)
    if not message then
        self:DebugPrint("No farewells enabled for", channel)
        return
    end

    -- Send immediately (no delay for farewells since we're leaving)
    self:DoSendMessage(message, channel)
end

-- Send guild greeting on login
function Addon:SendGuildGreeting()
    local db = self.db.profile

    if not db.enabled then return end
    if not db.guild.enabled then return end
    if not db.guild.onSelfJoin then
        self:DebugPrint("Guild greeting on login disabled")
        return
    end
    if not self:IsInGuildOrTest() then return end

    -- Get random greeting for guild
    local message = self:GetRandomMessageForChannel("greetings", "GUILD")
    if not message then
        self:DebugPrint("No greetings enabled for GUILD")
        return
    end

    self:SendMessageToChat(message, "GUILD")
end

-- Send guild farewell on logout
function Addon:SendGuildFarewell()
    local db = self.db.profile

    if not db.enabled then return end
    if not db.guild.enabled then return end
    if not db.guild.sendFarewell then
        self:DebugPrint("Guild farewell on logout disabled")
        return
    end
    if not self:IsInGuildOrTest() then return end

    -- Get random farewell for guild
    local message = self:GetRandomMessageForChannel("farewells", "GUILD")
    if not message then
        self:DebugPrint("No farewells enabled for GUILD")
        return
    end

    -- Send immediately (no delay for farewells)
    self:DoSendMessage(message, "GUILD")
end

-- Check if should greet on self join for channel
function Addon:ShouldGreetOnSelfJoin(channel)
    local settings = self:GetChannelSettings(channel)
    return settings and settings.enabled and settings.onSelfJoin
end

-- Check if should greet on others join for channel
function Addon:ShouldGreetOnOthersJoin(channel)
    local settings = self:GetChannelSettings(channel)
    return settings and settings.enabled and settings.onOthersJoin
end

--------------------------------------------------------------------------------
-- TEST MODE SIMULATION FUNCTIONS
--------------------------------------------------------------------------------

-- Reset test state
function Addon:TestReset()
    self.testState.simulatedGroupType = nil
    self.testState.simulatedInGuild = false
    self.testState.simulatedGroupMembers = {}
    self.state.previousGroup = nil
    self.state.sentGreetings = {}
    self.state.currentGroupType = nil
    self.state.lastMessageTime = 0
    self:TestPrint("Test state reset")
end

-- Simulate joining a party
function Addon:TestJoinParty()
    if not self:IsTestMode() then
        self:Print("|cFFFF0000Test mode is not enabled!|r Use /as testmode or enable in settings.")
        return
    end

    self:TestPrint("=== Simulating JOIN PARTY ===")
    self.testState.simulatedGroupType = "PARTY"
    self.state.previousGroup = { [UnitName("player")] = true }
    self.state.sentGreetings = {}
    self.state.currentGroupType = "PARTY"

    -- Trigger the greeting logic
    if self.db.profile.enabled and self:ShouldGreetOnSelfJoin("PARTY") then
        self:SendGreeting(nil, "self_join")
    else
        self:TestPrint("Greeting skipped (disabled in settings)")
    end
end

-- Simulate joining a raid
function Addon:TestJoinRaid()
    if not self:IsTestMode() then
        self:Print("|cFFFF0000Test mode is not enabled!|r Use /as testmode or enable in settings.")
        return
    end

    self:TestPrint("=== Simulating JOIN RAID ===")
    self.testState.simulatedGroupType = "RAID"
    self.state.previousGroup = { [UnitName("player")] = true }
    self.state.sentGreetings = {}
    self.state.currentGroupType = "RAID"

    -- Trigger the greeting logic
    if self.db.profile.enabled and self:ShouldGreetOnSelfJoin("RAID") then
        self:SendGreeting(nil, "self_join")
    else
        self:TestPrint("Greeting skipped (disabled in settings)")
    end
end

-- Simulate leaving current group
function Addon:TestLeaveGroup()
    if not self:IsTestMode() then
        self:Print("|cFFFF0000Test mode is not enabled!|r Use /as testmode or enable in settings.")
        return
    end

    if not self.testState.simulatedGroupType then
        self:TestPrint("Not in a simulated group!")
        return
    end

    local groupType = self.testState.simulatedGroupType
    self:TestPrint("=== Simulating LEAVE " .. groupType .. " ===")

    -- Send farewell before "leaving"
    self:SendFarewell(groupType)

    -- Reset simulated group state
    self.testState.simulatedGroupType = nil
    self.state.previousGroup = nil
    self.state.sentGreetings = {}
    self.state.currentGroupType = nil
end

-- Simulate player joining the group
function Addon:TestPlayerJoins(playerName)
    if not self:IsTestMode() then
        self:Print("|cFFFF0000Test mode is not enabled!|r Use /as testmode or enable in settings.")
        return
    end

    if not self.testState.simulatedGroupType then
        self:TestPrint("Not in a simulated group! Join a party or raid first.")
        return
    end

    local channel = self.testState.simulatedGroupType
    playerName = playerName or "TestPlayer" .. math.random(1000, 9999)
    self:TestPrint("=== Simulating " .. playerName .. " joining " .. channel .. " ===")

    if self.db.profile.enabled and self:ShouldGreetOnOthersJoin(channel) then
        if not self.state.sentGreetings[playerName] then
            self.state.sentGreetings[playerName] = true
            self:SendGreeting({ playerName }, "others_join")
        else
            self:TestPrint("Already greeted this player")
        end
    else
        self:TestPrint("Others join greeting disabled for " .. channel)
    end
end

-- Simulate guild login greeting
function Addon:TestGuildGreeting()
    if not self:IsTestMode() then
        self:Print("|cFFFF0000Test mode is not enabled!|r Use /as testmode or enable in settings.")
        return
    end

    self:TestPrint("=== Simulating GUILD LOGIN greeting ===")
    self.testState.simulatedInGuild = true
    self:SendGuildGreeting()
    self.testState.simulatedInGuild = false
end

-- Simulate guild logout farewell
function Addon:TestGuildFarewell()
    if not self:IsTestMode() then
        self:Print("|cFFFF0000Test mode is not enabled!|r Use /as testmode or enable in settings.")
        return
    end

    self:TestPrint("=== Simulating GUILD LOGOUT farewell ===")
    self.testState.simulatedInGuild = true
    self:SendGuildFarewell()
    self.testState.simulatedInGuild = false
end

-- Show current test state
function Addon:TestStatus()
    self:Print("=== AutoSay Test Status ===")
    self:Print("Test mode:", self.db.profile.testMode and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r")
    self:Print("Addon enabled:", self.db.profile.enabled and "|cFF00FF00Yes|r" or "|cFFFF0000No|r")

    if self.testState.simulatedGroupType then
        self:Print("Simulated group:", "|cFFFFFF00" .. self.testState.simulatedGroupType .. "|r")
    else
        self:Print("Simulated group:", "|cFF888888None|r")
    end

    self:Print("Cooldown remaining:", math.max(0, self.db.profile.cooldown - (GetTime() - self.state.lastMessageTime)) .. "s")

    -- Show channel status
    local db = self.db.profile
    self:Print("Party:", db.party.enabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r",
        "| Self:", db.party.onSelfJoin and "|cFF00FF00Yes|r" or "|cFFFF0000No|r",
        "| Others:", db.party.onOthersJoin and "|cFF00FF00Yes|r" or "|cFFFF0000No|r",
        "| Names:", db.party.includeNames and "|cFF00FF00Yes|r" or "|cFFFF0000No|r",
        "| Bye:", db.party.sendFarewell and "|cFF00FF00Yes|r" or "|cFFFF0000No|r")
    self:Print("Raid:", db.raid.enabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r",
        "| Self:", db.raid.onSelfJoin and "|cFF00FF00Yes|r" or "|cFFFF0000No|r",
        "| Others:", db.raid.onOthersJoin and "|cFF00FF00Yes|r" or "|cFFFF0000No|r",
        "| Names:", db.raid.includeNames and "|cFF00FF00Yes|r" or "|cFFFF0000No|r",
        "| Bye:", db.raid.sendFarewell and "|cFF00FF00Yes|r" or "|cFFFF0000No|r")
    self:Print("Guild:", db.guild.enabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r",
        "| Login:", db.guild.onSelfJoin and "|cFF00FF00Yes|r" or "|cFFFF0000No|r",
        "| Logout:", db.guild.sendFarewell and "|cFF00FF00Yes|r" or "|cFFFF0000No|r")
end
