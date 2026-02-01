local ADDON_NAME, AutoSay = ...

-- Create addon using Ace3
local Addon = LibStub("AceAddon-3.0"):NewAddon(AutoSay, ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0")
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

-- Helper to convert table keys to string for debug output
function Addon:TableKeysToString(tbl)
    if not tbl then return "nil" end
    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, tostring(k))
    end
    if #keys == 0 then return "(empty)" end
    return table.concat(keys, ", ")
end

-- Default enabled greetings
local defaultGreetings = {
    hi = true,
    hello = true,
    hey = true,
    greetings = true,
    -- Disabled by default
    wassup = false,
    yo = false,
    heya = false,
    sup = false,
    howdy = false,
    hiya = false,
    yoyo = false,
    hellothere = false,
}

-- Default enabled goodbyes
local defaultGoodbyes = {
    bye = true,
    goodbye = true,
    gtg = true,
    takecare = true,
    peace = true,
    -- Disabled by default
    seeya = false,
    later = false,
    cya = false,
    cheers = false,
    gn = false,
    bb = false,
    laterall = false,
}

-- Default enabled reconnect messages
local defaultReconnects = {
    back = true,
    reconnected = true,
    imback = true,
    -- Disabled by default
    rehi = false,
    backagain = false,
    herewego = false,
    missedme = false,
    backinthegame = false,
    srydc = false,
    sorrydisconnect = false,
    dcsorry = false,
    mybad = false,
    internetissues = false,
    laggedout = false,
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
        cooldown = 5,

        -- Party settings
        party = {
            enabled = true,
            onSelfJoin = true,
            onOthersJoin = false,
            onReconnect = true, -- Send greeting when reconnecting to group
            includeNames = false,
            sendGoodbye = true,
            enabledGreetings = DeepCopy(defaultGreetings),
            enabledGoodbyes = DeepCopy(defaultGoodbyes),
            enabledReconnects = DeepCopy(defaultReconnects),
            customGreeting = "",
            customGoodbye = "",
            customReconnect = "",
            useCustomGreeting = false,
            useCustomGoodbye = false,
            useCustomReconnect = false,
        },

        -- Raid settings (disabled by default - raids are more formal content)
        raid = {
            enabled = false,
            onSelfJoin = false,
            onOthersJoin = false,
            onReconnect = false,
            includeNames = false,
            sendGoodbye = false,
            enabledGreetings = DeepCopy(defaultGreetings),
            enabledGoodbyes = DeepCopy(defaultGoodbyes),
            enabledReconnects = DeepCopy(defaultReconnects),
            customGreeting = "",
            customGoodbye = "",
            customReconnect = "",
            useCustomGreeting = false,
            useCustomGoodbye = false,
            useCustomReconnect = false,
        },

        -- Guild settings (disabled by default - less commonly needed)
        guild = {
            enabled = false,
            onSelfJoin = false,  -- Send greeting on login (disabled by default)
            sendGoodbye = false, -- Send goodbye on logout (disabled by default)
            enabledGreetings = DeepCopy(defaultGreetings),
            enabledGoodbyes = DeepCopy(defaultGoodbyes),
            customGreeting = "",
            customGoodbye = "",
            useCustomGreeting = false,
            useCustomGoodbye = false,
        },
    },
}

-- State tracking
Addon.state = {
    previousGroup = nil,
    lastGroupMessageTime = 0, -- Cooldown for party/raid messages
    lastGuildMessageTime = 0, -- Cooldown for guild messages (separate from group)
    pendingGoodbye = false,
    currentGroupType = nil,
    sentGreetings = {},
    isInGuild = false, -- Cached guild status (IsInGuild() returns false during logout)
    groupGoodbyeSent = false, -- Track if group goodbye was sent (to avoid duplicates)
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

    -- Cache guild membership status (IsInGuild() returns false during logout)
    self:UpdateGuildStatus()

    -- Hook logout/quit functions to send farewell before instant logout
    self:HookLogoutFunctions()

    -- Hook leave group functions to send farewell before leaving
    self:HookLeaveGroupFunctions()

    self:DebugPrint("Addon enabled")
end

-- Update cached guild status
function Addon:UpdateGuildStatus()
    self.state.isInGuild = IsInGuild()
    self:DebugPrint("Guild status cached:", tostring(self.state.isInGuild))
end

-- Hook Logout and Quit to send guild goodbye before instant logout
function Addon:HookLogoutFunctions()
    -- Track if we already sent goodbye to avoid duplicates
    self.state.goodbyeSent = false

    -- Hook Logout function
    if not self:IsHooked("Logout") then
        self:SecureHook("Logout", function()
            self:DebugPrint("Logout() called - sending goodbye (cached guild:", tostring(self.state.isInGuild), ")")
            self:SendGuildGoodbyeOnce()
        end)
    end

    -- Hook Quit function
    if not self:IsHooked("Quit") then
        self:SecureHook("Quit", function()
            self:DebugPrint("Quit() called - sending goodbye (cached guild:", tostring(self.state.isInGuild), ")")
            self:SendGuildGoodbyeOnce()
        end)
    end

    -- Hook ForceQuit function (Alt+F4 or crash protection)
    if ForceQuit and not self:IsHooked("ForceQuit") then
        self:SecureHook("ForceQuit", function()
            self:DebugPrint("ForceQuit() called - sending goodbye")
            self:SendGuildGoodbyeOnce()
        end)
    end

    self:DebugPrint("Logout functions hooked")
end

-- Send guild goodbye only once per logout session
function Addon:SendGuildGoodbyeOnce()
    if self.state.goodbyeSent then
        self:DebugPrint("Goodbye already sent, skipping")
        return
    end
    self.state.goodbyeSent = true
    self:SendGuildGoodbye()
end

-- Hook LeaveParty to send group goodbye before leaving
function Addon:HookLeaveGroupFunctions()
    -- Track if we already sent group goodbye to avoid duplicates
    self.state.groupGoodbyeSent = false

    -- Hook C_PartyInfo.LeaveParty (retail WoW API) - use RawHook to run BEFORE the function
    if C_PartyInfo and C_PartyInfo.LeaveParty and not self:IsHooked(C_PartyInfo, "LeaveParty") then
        self:RawHook(C_PartyInfo, "LeaveParty", function(category)
            self:DebugPrint("C_PartyInfo.LeaveParty() intercepted - sending goodbye BEFORE leaving")
            self:SendGroupGoodbyeOnce()
            -- Call the original function
            return self.hooks[C_PartyInfo].LeaveParty(category)
        end, true)
    end

    -- Hook LeaveParty (classic/fallback) - use RawHook to run BEFORE the function
    if LeaveParty and not self:IsHooked("LeaveParty") then
        self:RawHook("LeaveParty", function()
            self:DebugPrint("LeaveParty() intercepted - sending goodbye BEFORE leaving")
            self:SendGroupGoodbyeOnce()
            -- Call the original function
            return self.hooks.LeaveParty()
        end, true)
    end

    self:DebugPrint("Leave group functions hooked")
end

-- Send group goodbye only once per leave action
function Addon:SendGroupGoodbyeOnce()
    if self.state.groupGoodbyeSent then
        self:DebugPrint("Group goodbye already sent, skipping")
        return
    end

    local channel = self.state.currentGroupType
    if not channel then
        self:DebugPrint("No current group type cached, skipping goodbye")
        return
    end

    self.state.groupGoodbyeSent = true
    self:DebugPrint("Sending goodbye to", channel, "before leaving")
    self:SendGoodbye(channel)

    -- Reset flag after a short delay (in case GROUP_LEFT also tries to send)
    self:ScheduleTimer(function()
        self.state.groupGoodbyeSent = false
    end, 2)
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
            self:TestGuildGoodbye()
        elseif subcmd == "reconnect" or subcmd == "re" then
            self:TestReconnect()
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
            self:Print("  /as test guildbye - Simulate guild logout goodbye")
            self:Print("  /as test reconnect - Simulate reconnecting to group")
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

-- Check if cooldown has passed for a specific channel type
function Addon:CanSendMessage(channelType)
    local now = GetTime()
    local cooldown = self.db.profile.cooldown

    -- Use separate cooldowns for guild vs group
    local lastMessageTime
    if channelType == "GUILD" then
        lastMessageTime = self.state.lastGuildMessageTime
    else
        lastMessageTime = self.state.lastGroupMessageTime
    end

    if (now - lastMessageTime) < cooldown then
        local remaining = cooldown - (now - lastMessageTime)
        self:DebugPrint("Cooldown active for", channelType or "unknown", ", skipping message (" .. string.format("%.1f", remaining) .. "s remaining)")
        if self:IsTestMode() then
            self:TestPrint("Message blocked by cooldown (" .. string.format("%.1f", remaining) .. "s remaining). Wait " .. cooldown .. "s between messages.")
        end
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

    if not self:CanSendMessage(channel) then
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

    -- Update appropriate cooldown based on channel type
    local function updateCooldown()
        if channel == "GUILD" then
            self.state.lastGuildMessageTime = GetTime()
        else
            self.state.lastGroupMessageTime = GetTime()
        end
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
        updateCooldown()
        self:DebugPrint("Test mode - simulated send to", channel, ":", message)
        return
    end

    -- WoW 12.0+ restricts SendChatMessage in certain instance contexts
    -- (active M+ key, PvP match, boss encounter). Use pcall to handle gracefully.
    local ok, err = pcall(SendChatMessage, message, channel, nil, target)
    if ok then
        updateCooldown()
        self:DebugPrint("Sent to", channel, ":", message)
    else
        self:DebugPrint("Failed to send to", channel, ":", tostring(err))
        if self:IsTestMode() then
            self:TestPrint("Failed to send message (possible instance restriction): " .. tostring(err))
        end
    end
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

-- Check if in guild (with test mode support and cached fallback for logout)
function Addon:IsInGuildOrTest()
    -- For test mode, only use simulation if explicitly set (during test commands)
    -- Otherwise use real guild status (for actual logout)
    if self:IsTestMode() and self.testState.simulatedInGuild then
        return true
    end
    -- Use cached value as fallback (IsInGuild() returns false during logout)
    return IsInGuild() or self.state.isInGuild
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

    local messages, enabledKey, customKey
    if messageType == "greetings" then
        messages = AutoSay.Greetings
        enabledKey = "enabledGreetings"
        customKey = "customGreeting"
    elseif messageType == "goodbyes" then
        messages = AutoSay.Goodbyes
        enabledKey = "enabledGoodbyes"
        customKey = "customGoodbye"
    elseif messageType == "reconnects" then
        messages = AutoSay.Reconnects
        enabledKey = "enabledReconnects"
        customKey = "customReconnect"
    else
        return nil
    end

    local enabled = {}

    -- Add enabled preset messages
    if settings[enabledKey] then
        for _, msg in ipairs(messages) do
            if settings[enabledKey][msg.key] then
                table.insert(enabled, msg.text)
            end
        end
    end

    -- Add custom message if enabled and set
    local useCustomKey = "useCustom" .. customKey:sub(7, 7):upper() .. customKey:sub(8) -- customGreeting -> useCustomGreeting
    if settings[useCustomKey] and settings[customKey] and settings[customKey] ~= "" then
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

    -- Get random message based on reason
    local message
    if reason == "reconnect" then
        -- Use reconnect messages for reconnect reason
        message = self:GetRandomMessageForChannel("reconnects", channel)
        if not message then
            self:DebugPrint("No reconnects enabled for", channel, "- falling back to greetings")
            message = self:GetRandomMessageForChannel("greetings", channel)
        end
    else
        -- Use regular greetings for other reasons
        message = self:GetRandomMessageForChannel("greetings", channel)
    end

    if not message then
        self:DebugPrint("No greetings enabled for", channel)
        return
    end

    -- Add player names if enabled for this channel
    local includeNames = settings.includeNames or false
    message = self:AddPlayersToMessage(message, playerNames, includeNames)

    self:SendMessageToChat(message, channel)
end

-- Send goodbye
function Addon:SendGoodbye(channel)
    local db = self.db.profile

    if not db.enabled then return end

    local settings = self:GetChannelSettings(channel)
    if not settings then return end

    -- Check if goodbye is enabled for this channel
    if not settings.sendGoodbye then
        self:DebugPrint(channel, "goodbyes disabled")
        return
    end

    -- Get random goodbye for this channel
    local message = self:GetRandomMessageForChannel("goodbyes", channel)
    if not message then
        self:DebugPrint("No goodbyes enabled for", channel)
        return
    end

    -- Send immediately (no delay for goodbyes since we're leaving)
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

-- Send guild goodbye on logout
function Addon:SendGuildGoodbye()
    self:DebugPrint("SendGuildGoodbye called")
    local db = self.db.profile

    if not db.enabled then
        self:DebugPrint("Addon disabled, skipping guild goodbye")
        return
    end
    if not db.guild.enabled then
        self:DebugPrint("Guild channel disabled, skipping goodbye")
        return
    end
    if not db.guild.sendGoodbye then
        self:DebugPrint("Guild goodbye on logout disabled")
        return
    end

    local inGuild = self:IsInGuildOrTest()
    self:DebugPrint("IsInGuildOrTest:", tostring(inGuild))
    if not inGuild then
        self:DebugPrint("Not in guild, skipping goodbye")
        return
    end

    -- Get random goodbye for guild
    local message = self:GetRandomMessageForChannel("goodbyes", "GUILD")
    if not message then
        self:DebugPrint("No goodbyes enabled for GUILD")
        return
    end

    self:DebugPrint("Sending guild goodbye:", message)
    -- Send immediately (no delay for goodbyes)
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

-- Check if should greet on reconnect for channel
function Addon:ShouldGreetOnReconnect(channel)
    local settings = self:GetChannelSettings(channel)
    return settings and settings.enabled and settings.onReconnect
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
    self.state.lastGroupMessageTime = 0
    self.state.lastGuildMessageTime = 0
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

    -- Send goodbye before "leaving"
    self:SendGoodbye(groupType)

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

-- Simulate guild logout goodbye
function Addon:TestGuildGoodbye()
    if not self:IsTestMode() then
        self:Print("|cFFFF0000Test mode is not enabled!|r Use /as testmode or enable in settings.")
        return
    end

    self:TestPrint("=== Simulating GUILD LOGOUT goodbye ===")
    self.testState.simulatedInGuild = true
    self:SendGuildGoodbye()
    self.testState.simulatedInGuild = false
end

-- Simulate reconnecting to group
function Addon:TestReconnect()
    if not self:IsTestMode() then
        self:Print("|cFFFF0000Test mode is not enabled!|r Use /as testmode or enable in settings.")
        return
    end

    if not self.testState.simulatedGroupType then
        self:TestPrint("Not in a simulated group! Join a party or raid first.")
        return
    end

    local channel = self.testState.simulatedGroupType
    self:TestPrint("=== Simulating RECONNECT to " .. channel .. " ===")

    if self.db.profile.enabled and self:ShouldGreetOnReconnect(channel) then
        self:SendGreeting(nil, "reconnect")
    else
        self:TestPrint("Reconnect greeting disabled for " .. channel)
    end
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

    local groupCooldown = math.max(0, self.db.profile.cooldown - (GetTime() - self.state.lastGroupMessageTime))
    local guildCooldown = math.max(0, self.db.profile.cooldown - (GetTime() - self.state.lastGuildMessageTime))
    self:Print("Cooldown remaining: Group:", string.format("%.1fs", groupCooldown), "| Guild:", string.format("%.1fs", guildCooldown))

    -- Show channel status
    local db = self.db.profile
    self:Print("Party:", db.party.enabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r",
        "| Self:", db.party.onSelfJoin and "|cFF00FF00Yes|r" or "|cFFFF0000No|r",
        "| Others:", db.party.onOthersJoin and "|cFF00FF00Yes|r" or "|cFFFF0000No|r",
        "| Names:", db.party.includeNames and "|cFF00FF00Yes|r" or "|cFFFF0000No|r",
        "| Bye:", db.party.sendGoodbye and "|cFF00FF00Yes|r" or "|cFFFF0000No|r")
    self:Print("Raid:", db.raid.enabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r",
        "| Self:", db.raid.onSelfJoin and "|cFF00FF00Yes|r" or "|cFFFF0000No|r",
        "| Others:", db.raid.onOthersJoin and "|cFF00FF00Yes|r" or "|cFFFF0000No|r",
        "| Names:", db.raid.includeNames and "|cFF00FF00Yes|r" or "|cFFFF0000No|r",
        "| Bye:", db.raid.sendGoodbye and "|cFF00FF00Yes|r" or "|cFFFF0000No|r")
    self:Print("Guild:", db.guild.enabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r",
        "| Login:", db.guild.onSelfJoin and "|cFF00FF00Yes|r" or "|cFFFF0000No|r",
        "| Logout:", db.guild.sendGoodbye and "|cFF00FF00Yes|r" or "|cFFFF0000No|r")
end
