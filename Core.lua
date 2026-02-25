local ADDON_NAME, AutoSay = ...

-- Create addon using Ace3
local Addon = LibStub("AceAddon-3.0"):NewAddon(AutoSay, ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

-- Version (replaced by packager with git tag)
Addon.version = "@project-version@"

-- Debug print helper
function Addon:DebugPrint(...)
    if self.db and self.db.profile.debugMode and self.db.profile.testMode then
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

-- Default enabled key announce messages
local defaultKeyAnnounce = {
    letsgo = true,
    ready = true,
    gogogo = true,
}

-- Default enabled completion timed messages
local defaultCompletionTimed = {
    gg = true,
    ggwp = true,
    gjteam = true,
    nicerun = true,
    -- Disabled by default
    letsgo = false,
    cleanrun = false,
    greatteam = false,
    wpall = false,
    timed = false,
    upgraded = false,
}

-- Default enabled completion depleted messages
local defaultCompletionDepleted = {
    gg = true,
    ggwp = true,
    tyrun = true,
    tyall = true,
    -- Disabled by default
    goodrun = false,
    ggeveryone = false,
    gjteam = false,
    wpall = false,
    done = false,
    tyfun = false,
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
        autoDisableTestMode = true, -- Auto-disable simulation when real group events fire

        -- Timing (global)
        messageDelay = 1.0,
        cooldown = 5,

        -- Party settings
        party = {
            enabled = true,
            onSelfJoin = true,
            onOthersJoin = false,
            onOthersJoinLeaderOnly = false, -- Only greet newcomers when you are the group leader
            onReconnect = true, -- Send greeting when reconnecting to group
            includeNames = false, -- Include names of players who joined (others join)
            includeGroupNames = false, -- Include names of existing group members (self join)
            sendGoodbye = true,
            enabledGreetings = DeepCopy(defaultGreetings),
            enabledGoodbyes = DeepCopy(defaultGoodbyes),
            enabledReconnects = DeepCopy(defaultReconnects),
            customGreetings = {},
            customGoodbyes = {},
            customReconnects = {},
        },

        -- Raid settings (disabled by default - raids are more formal content)
        raid = {
            enabled = false,
            onSelfJoin = false,
            onOthersJoin = false,
            onOthersJoinLeaderOnly = false, -- Only greet newcomers when you are the raid leader
            onReconnect = false,
            includeNames = false, -- Include names of players who joined (others join)
            includeGroupNames = false, -- Include names of existing group members (self join)
            sendGoodbye = false,
            enabledGreetings = DeepCopy(defaultGreetings),
            enabledGoodbyes = DeepCopy(defaultGoodbyes),
            enabledReconnects = DeepCopy(defaultReconnects),
            customGreetings = {},
            customGoodbyes = {},
            customReconnects = {},
        },

        -- Mythic+ settings (disabled by default)
        mythicplus = {
            enabled = false,
            announceOnFull = true,      -- Announce when group fills 5/5
            messageMode = "basic",      -- "basic" | "withlevel" | "smart"
            enabledKeyAnnounce = DeepCopy(defaultKeyAnnounce),
            customKeyAnnounce = {},
            -- Completion messages
            completionEnabled = true,   -- Send message on M+ completion
            enabledCompletionTimed = DeepCopy(defaultCompletionTimed),
            enabledCompletionDepleted = DeepCopy(defaultCompletionDepleted),
            customCompletionTimed = {},
            customCompletionDepleted = {},
        },

        -- Config window status (persisted size/position)
        configWindowStatus = nil,

        -- Guild settings (disabled by default - less commonly needed)
        guild = {
            enabled = false,
            onSelfJoin = false,  -- Send greeting on login (disabled by default)
            sendGoodbye = false, -- Send goodbye on logout (disabled by default)
            enabledGreetings = DeepCopy(defaultGreetings),
            enabledGoodbyes = DeepCopy(defaultGoodbyes),
            customGreetings = {},
            customGoodbyes = {},
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
    pendingNewMembers = {}, -- Batch new members for others_join greeting
    pendingGreetTimer = nil, -- Timer for batched greeting
    messageQueue = {}, -- Queue for cooldown-blocked messages
    queueTimer = nil, -- Timer for processing queued messages
    lastGreetingText = {}, -- Cache greeting text per channel:reason for consistency
    cachedLFGListing = nil, -- Cached LFG listing data (before auto-delist)
    keyAnnounced = false, -- Prevent duplicate M+ key announcements per group
}

-- Test mode simulation state
Addon.testState = {
    simulatedGroupType = nil, -- "PARTY", "RAID", or nil
    simulatedInGuild = false,
    simulatedGroupMembers = {},
    simulatedIsLeader = true, -- Simulate being group leader (default true for test)
    mythicPlusRole = "leader", -- "leader" or "joined" for M+ flow simulation
}

function Addon:OnInitialize()
    -- Initialize database
    self.db = LibStub("AceDB-3.0"):New("AutoSayDB", defaults, true)

    -- Migrate old single custom message format to new array format
    self:MigrateCustomMessages()

    -- Register slash commands
    self:RegisterChatCommand("autosay", "SlashCommand")
    self:RegisterChatCommand("as", "SlashCommand")

    self:DebugPrint("Addon initialized")
end

-- Migrate old single custom message fields to the new array format
function Addon:MigrateCustomMessages()
    local migrations = {
        { old = "customGreeting",  useOld = "useCustomGreeting",  new = "customGreetings" },
        { old = "customGoodbye",   useOld = "useCustomGoodbye",   new = "customGoodbyes" },
        { old = "customReconnect", useOld = "useCustomReconnect", new = "customReconnects" },
    }

    for _, channel in ipairs({"party", "raid", "guild"}) do
        local settings = self.db.profile[channel]
        if settings then
            for _, m in ipairs(migrations) do
                if type(settings[m.old]) == "string" then
                    if settings[m.old] ~= "" then
                        settings[m.new] = settings[m.new] or {}
                        table.insert(settings[m.new], {
                            text = settings[m.old],
                            enabled = settings[m.useOld] or false,
                        })
                    end
                    settings[m.old] = nil
                    settings[m.useOld] = nil
                end
            end
        end
    end
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
        elseif subcmd == "key" or subcmd == "k" then
            self:TestMythicPlusFlow()
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
            self:Print("  /as test key - Simulate full M+ flow (listing → joins → announce)")
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
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")

    -- Restore saved window status or set default size
    local status = AceConfigDialog:GetStatusTable("AutoSay")
    local saved = self.db.profile.configWindowStatus
    if saved and saved.width then
        status.width = saved.width
        status.height = saved.height
        status.top = saved.top
        status.left = saved.left
    elseif not status.width then
        status.width = 1000
        status.height = 900
    end

    AceConfigDialog:Open("AutoSay")

    -- Hook frame close to save window status
    local frame = AceConfigDialog.OpenFrames["AutoSay"]
    if frame then
        frame:SetCallback("OnClose", function(widget, event)
            local s = AceConfigDialog:GetStatusTable("AutoSay")
            self.db.profile.configWindowStatus = {
                width = s.width,
                height = s.height,
                top = s.top,
                left = s.left,
            }
            AceConfigDialog.OpenFrames["AutoSay"] = nil
            LibStub("AceGUI-3.0"):Release(widget)
        end)
    end
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
        return false
    end

    if not self:CanSendMessage(channel) then
        return false
    end

    -- Update cooldown immediately to prevent race conditions with rapid calls
    -- (without this, multiple SendGreeting calls within messageDelay all pass cooldown check)
    if channel == "GUILD" then
        self.state.lastGuildMessageTime = GetTime()
    else
        self.state.lastGroupMessageTime = GetTime()
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
    return true
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

-- Check if player is group leader (with test mode support)
function Addon:IsGroupLeaderOrTest()
    if self:IsTestMode() and self.testState.simulatedGroupType then
        return self.testState.simulatedIsLeader
    end
    return UnitIsGroupLeader("player")
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

    local messages, enabledKey, customsKey
    if messageType == "greetings" then
        messages = AutoSay.Greetings
        enabledKey = "enabledGreetings"
        customsKey = "customGreetings"
    elseif messageType == "goodbyes" then
        messages = AutoSay.Goodbyes
        enabledKey = "enabledGoodbyes"
        customsKey = "customGoodbyes"
    elseif messageType == "reconnects" then
        messages = AutoSay.Reconnects
        enabledKey = "enabledReconnects"
        customsKey = "customReconnects"
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

    -- Add enabled custom messages
    if settings[customsKey] then
        for _, entry in ipairs(settings[customsKey]) do
            if entry.enabled and entry.text and entry.text ~= "" then
                table.insert(enabled, entry.text)
            end
        end
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

-- Send greeting (checks cooldown and queues if blocked)
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

    self:DebugPrint("SendGreeting called - reason:", reason, "channel:", channel,
        "names:", playerNames and table.concat(playerNames, ", ") or "none")

    -- Check cooldown - if blocked, queue for later delivery
    if not self:CanSendMessage(channel) then
        self:DebugPrint("SendGreeting -> cooldown active, queuing message")
        self:QueueGreeting(channel, reason, playerNames)
        return
    end

    -- Send immediately
    self:DebugPrint("SendGreeting -> cooldown OK, sending immediately")
    self:BuildAndSendGreeting(channel, reason, playerNames)
end

-- Build a greeting message and send it (used by both direct send and queue processing)
function Addon:BuildAndSendGreeting(channel, reason, playerNames)
    local settings = self:GetChannelSettings(channel)
    if not settings or not settings.enabled then return end

    local textKey = channel .. ":" .. reason
    local cooldown = self.db.profile.cooldown
    local now = GetTime()

    -- Reuse same greeting text within cooldown window for consistency
    -- (so queued messages use the same "Hey!" as the original send)
    local message
    local cached = self.state.lastGreetingText[textKey]
    if cached and (now - cached.time) < cooldown * 2 then
        message = cached.text
        self:DebugPrint("BuildAndSend -> reusing cached greeting for consistency:", message,
            "(age:", string.format("%.1f", now - cached.time) .. "s, window:", cooldown * 2 .. "s)")
    else
        -- Pick new random message based on reason
        if reason == "reconnect" then
            message = self:GetRandomMessageForChannel("reconnects", channel)
            if not message then
                self:DebugPrint("No reconnects enabled for", channel, "- falling back to greetings")
                message = self:GetRandomMessageForChannel("greetings", channel)
            end
        else
            message = self:GetRandomMessageForChannel("greetings", channel)
        end

        if not message then
            self:DebugPrint("No greetings enabled for", channel)
            return
        end

        -- Cache for consistency within cooldown window
        self.state.lastGreetingText[textKey] = { text = message, time = now }
        self:DebugPrint("BuildAndSend -> new random greeting picked and cached:", message, "key:", textKey)
    end

    -- Add player names if enabled for this channel
    -- For self_join: names are pre-collected based on includeGroupNames, always append if provided
    -- For others_join: check includeNames setting
    local includeNames
    if reason == "self_join" then
        includeNames = (playerNames ~= nil and #playerNames > 0)
    else
        includeNames = settings.includeNames or false
    end
    message = self:AddPlayersToMessage(message, playerNames, includeNames)

    self:DebugPrint("BuildAndSend -> final message:", message)

    local sent = self:SendMessageToChat(message, channel)
    if sent then
        self:DebugPrint("BuildAndSend -> message accepted for sending")
    else
        -- Cooldown blocked (race condition) - re-queue for retry
        self:DebugPrint("BuildAndSend -> SendMessageToChat returned false, re-queuing")
        self:QueueGreeting(channel, reason, playerNames)
    end
end

-- Queue a greeting intent for later delivery (when cooldown blocked)
function Addon:QueueGreeting(channel, reason, playerNames)
    -- Copy playerNames to avoid reference issues
    local namesCopy = nil
    if playerNames and #playerNames > 0 then
        namesCopy = {}
        for _, name in ipairs(playerNames) do
            table.insert(namesCopy, name)
        end
    end

    table.insert(self.state.messageQueue, {
        channel = channel,
        reason = reason,
        playerNames = namesCopy,
    })

    self:DebugPrint("QUEUE -> added entry:", reason, "channel:", channel,
        "names:", namesCopy and table.concat(namesCopy, ", ") or "none",
        "| queue size now:", #self.state.messageQueue)

    if self:IsTestMode() then
        local namesStr = namesCopy and (" for " .. table.concat(namesCopy, ", ")) or ""
        self:TestPrint("Message queued (cooldown active): " .. reason .. namesStr .. " | queue size: " .. #self.state.messageQueue)
    end

    -- Schedule queue processing when cooldown expires
    self:ScheduleQueueProcessing(channel)
end

-- Schedule processing of the message queue when cooldown expires
function Addon:ScheduleQueueProcessing(channel)
    if self.state.queueTimer then
        self:DebugPrint("QUEUE -> timer already scheduled, skipping")
        return
    end

    local cooldown = self.db.profile.cooldown
    local lastTime
    if channel == "GUILD" then
        lastTime = self.state.lastGuildMessageTime
    else
        lastTime = self.state.lastGroupMessageTime
    end

    local elapsed = GetTime() - lastTime
    local remaining = cooldown - elapsed

    -- Account for messageDelay: DoSendMessage updates cooldown AFTER delay,
    -- so queue must wait for cooldown + messageDelay to avoid being blocked again
    local messageDelay = self.db.profile.messageDelay or 0
    if messageDelay > 0 then
        remaining = remaining + messageDelay
    end

    if remaining < 0.1 then remaining = 0.1 end

    self:DebugPrint("QUEUE -> scheduling processing in", string.format("%.1f", remaining) .. "s",
        "(cooldown:", cooldown .. "s, elapsed:", string.format("%.1f", elapsed) .. "s, messageDelay:", messageDelay .. "s)")

    if self:IsTestMode() then
        self:TestPrint("Queue will process in " .. string.format("%.1f", remaining) .. "s (cooldown: " .. cooldown .. "s)")
    end

    self.state.queueTimer = self:ScheduleTimer(function()
        self.state.queueTimer = nil
        self:DebugPrint("QUEUE -> timer fired, processing queue")
        self:ProcessMessageQueue()
    end, remaining)
end

-- Process queued messages: merge same-type entries, deduplicate, concatenate names
function Addon:ProcessMessageQueue()
    if #self.state.messageQueue == 0 then
        self:DebugPrint("QUEUE PROCESS -> queue is empty, nothing to do")
        return
    end

    self:DebugPrint("QUEUE PROCESS -> starting, entries:", #self.state.messageQueue)

    -- Log each entry before grouping
    for i, entry in ipairs(self.state.messageQueue) do
        self:DebugPrint("  entry", i, ":", entry.channel, entry.reason,
            "names:", entry.playerNames and table.concat(entry.playerNames, ", ") or "none")
    end

    -- Group entries by (channel, reason) - merge names, deduplicate
    local groups = {}
    local groupOrder = {}
    for _, entry in ipairs(self.state.messageQueue) do
        local key = entry.channel .. ":" .. entry.reason
        if not groups[key] then
            groups[key] = {
                channel = entry.channel,
                reason = entry.reason,
                playerNames = {},
                nameSet = {},
            }
            table.insert(groupOrder, key)
        end
        -- Merge player names with deduplication
        if entry.playerNames then
            for _, name in ipairs(entry.playerNames) do
                if not groups[key].nameSet[name] then
                    groups[key].nameSet[name] = true
                    table.insert(groups[key].playerNames, name)
                else
                    self:DebugPrint("  dedup: skipping duplicate name", name, "in group", key)
                end
            end
        end
    end

    self:DebugPrint("QUEUE PROCESS -> grouped into", #groupOrder, "group(s):")
    for i, key in ipairs(groupOrder) do
        local g = groups[key]
        self:DebugPrint("  group", i, ":", key,
            "names:", #g.playerNames > 0 and table.concat(g.playerNames, ", ") or "none")
    end

    -- Clear queue
    self.state.messageQueue = {}

    -- Send the first merged group
    local firstKey = groupOrder[1]
    if firstKey then
        local group = groups[firstKey]
        local names = #group.playerNames > 0 and group.playerNames or nil

        self:DebugPrint("QUEUE PROCESS -> sending first group:", group.reason, "channel:", group.channel,
            "merged names:", names and table.concat(names, ", ") or "none")

        if self:IsTestMode() then
            local namesStr = names and (" " .. table.concat(names, ", ")) or ""
            self:TestPrint("Processing queue: sending " .. group.reason .. " to " .. group.channel .. namesStr)
        end

        self:BuildAndSendGreeting(group.channel, group.reason, names)

        -- Re-queue remaining groups (different channel/reason combos need separate sends)
        if #groupOrder > 1 then
            self:DebugPrint("QUEUE PROCESS -> re-queuing", #groupOrder - 1, "remaining group(s)")
            for i = 2, #groupOrder do
                local key = groupOrder[i]
                local g = groups[key]
                local n = #g.playerNames > 0 and g.playerNames or nil
                table.insert(self.state.messageQueue, {
                    channel = g.channel,
                    reason = g.reason,
                    playerNames = n,
                })
                self:DebugPrint("  re-queued:", key,
                    "names:", n and table.concat(n, ", ") or "none")
            end

            -- Schedule next processing if queue still has entries
            local nextEntry = self.state.messageQueue[1]
            self:DebugPrint("QUEUE PROCESS -> scheduling next processing for:", nextEntry.channel, nextEntry.reason)
            self:ScheduleQueueProcessing(nextEntry.channel)
        else
            self:DebugPrint("QUEUE PROCESS -> queue fully processed")
        end
    end
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

    -- Check cooldown - if blocked, queue for later delivery
    if not self:CanSendMessage("GUILD") then
        self:QueueGreeting("GUILD", "guild_login", nil)
        return
    end

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
    if not settings or not settings.enabled or not settings.onOthersJoin then
        return false
    end
    -- If leader-only is enabled, check if player is the group leader
    if settings.onOthersJoinLeaderOnly and not self:IsGroupLeaderOrTest() then
        self:DebugPrint("Leader-only greeting enabled but not leader, skipping")
        return false
    end
    return true
end

-- Check if should greet on reconnect for channel
function Addon:ShouldGreetOnReconnect(channel)
    local settings = self:GetChannelSettings(channel)
    return settings and settings.enabled and settings.onReconnect
end

--------------------------------------------------------------------------------
-- MYTHIC+ KEY ANNOUNCE FUNCTIONS
--------------------------------------------------------------------------------

-- Replace {dungeon} and {key} placeholders in a message
function Addon:ReplacePlaceholders(message, dungeon, keyLevel, extraReplacements)
    if not message then return nil end
    message = message:gsub("{dungeon}", dungeon or "")
    if keyLevel then
        message = message:gsub("{key}", "+" .. keyLevel)
    else
        -- Remove {key} and any preceding space
        message = message:gsub(" ?{key}", "")
    end
    -- Extra replacements for completion messages ({upgrade}, {time}, etc.)
    if extraReplacements then
        for placeholder, value in pairs(extraReplacements) do
            message = message:gsub("{" .. placeholder .. "}", value)
        end
    end
    return message
end

-- Get key level based on message mode
function Addon:GetKeyLevel()
    local mode = self.db.profile.mythicplus.messageMode
    local listing = self.state.cachedLFGListing

    if mode == "basic" then
        return nil
    end

    if mode == "withlevel" then
        -- 1. Try GetKeystoneForActivity (most reliable)
        if listing and listing.activityID and C_LFGList.GetKeystoneForActivity then
            local keystoneLevel = C_LFGList.GetKeystoneForActivity(listing.activityID)
            if keystoneLevel and keystoneLevel > 0 then
                self:DebugPrint("withlevel: GetKeystoneForActivity returned level:", keystoneLevel)
                return keystoneLevel
            end
        end
        -- 2. Fallback: parse from listing title
        if listing and listing.title then
            local level = tonumber(listing.title:match("%+?(%d+)"))
            if level and level >= 2 and level <= 99 then
                self:DebugPrint("withlevel: parsed level from title:", level)
                return level
            end
        end
        return nil
    end

    -- Smart mode: API first (most reliable), then title parsing
    if mode == "smart" then
        -- 1. Try GetKeystoneForActivity (returns key level only if our key matches the listed dungeon)
        if listing and listing.activityID and C_LFGList.GetKeystoneForActivity then
            local keystoneLevel = C_LFGList.GetKeystoneForActivity(listing.activityID)
            if keystoneLevel and keystoneLevel > 0 then
                self:DebugPrint("GetKeystoneForActivity returned level:", keystoneLevel)
                return keystoneLevel
            end
        end

        -- 2. Parse from listing title
        if listing and listing.title then
            local level = tonumber(listing.title:match("%+?(%d+)"))
            if level and level >= 2 and level <= 99 then
                self:DebugPrint("Parsed key level from title:", level)
                return level
            end
        end
    end

    return nil
end

-- Get a random key announce message from enabled pool
function Addon:GetRandomKeyAnnounce()
    local settings = self.db.profile.mythicplus
    local enabled = {}

    -- Add enabled preset messages
    if settings.enabledKeyAnnounce then
        for _, msg in ipairs(AutoSay.KeyAnnounce) do
            if settings.enabledKeyAnnounce[msg.key] then
                table.insert(enabled, msg.text)
            end
        end
    end

    -- Add enabled custom messages
    if settings.customKeyAnnounce then
        for _, entry in ipairs(settings.customKeyAnnounce) do
            if entry.enabled and entry.text and entry.text ~= "" then
                table.insert(enabled, entry.text)
            end
        end
    end

    if #enabled == 0 then return nil end

    return enabled[math.random(#enabled)]
end

-- Send key announce message to party chat
function Addon:SendKeyAnnounce()
    local db = self.db.profile
    if not db.enabled or not db.mythicplus.enabled then return end

    local listing = self.state.cachedLFGListing
    if not listing or not listing.dungeonName then
        self:DebugPrint("SendKeyAnnounce: no cached listing data")
        return
    end

    -- Clean dungeon name (remove " (Mythic Keystone)" suffix)
    local dungeon = listing.dungeonName:gsub(" %(Mythic Keystone%)", "")

    -- Get key level based on mode
    local keyLevel = self:GetKeyLevel()

    -- Get random message template
    local template = self:GetRandomKeyAnnounce()
    if not template then
        self:DebugPrint("SendKeyAnnounce: no key announce messages enabled")
        return
    end

    -- Replace placeholders
    local message = self:ReplacePlaceholders(template, dungeon, keyLevel)

    self:DebugPrint("SendKeyAnnounce:", message, "(mode:", db.mythicplus.messageMode,
        "dungeon:", dungeon, "level:", tostring(keyLevel) .. ")")

    -- Determine channel
    local channel = self:GetChatChannel()
    if not channel then
        channel = "PARTY" -- Default to party for M+
    end

    -- Send the message (bypasses greeting cooldown, uses DoSendMessage directly)
    if self:IsTestMode() then
        local channelColor = "|cFFAAAAFF"
        print("|cFFFF9900[AutoSay TEST]|r Would send to " .. channelColor .. "[" .. channel .. "]|r: " .. message)
        self:DebugPrint("Test mode - simulated key announce to", channel)
    else
        local ok, err = pcall(SendChatMessage, message, channel, nil, nil)
        if ok then
            self:DebugPrint("Key announce sent to", channel, ":", message)
        else
            self:DebugPrint("Failed to send key announce:", tostring(err))
        end
    end
end

-- Get a random completion message from enabled pool
function Addon:GetRandomCompletionMessage(onTime)
    local settings = self.db.profile.mythicplus
    local enabled = {}

    local presetDB = onTime and AutoSay.CompletionTimed or AutoSay.CompletionDepleted
    local enabledPresets = onTime and settings.enabledCompletionTimed or settings.enabledCompletionDepleted
    local customMessages = onTime and settings.customCompletionTimed or settings.customCompletionDepleted

    -- Add enabled preset messages
    if enabledPresets then
        for _, msg in ipairs(presetDB) do
            if enabledPresets[msg.key] then
                table.insert(enabled, msg.text)
            end
        end
    end

    -- Add enabled custom messages
    if customMessages then
        for _, entry in ipairs(customMessages) do
            if entry.enabled and entry.text and entry.text ~= "" then
                table.insert(enabled, entry.text)
            end
        end
    end

    if #enabled == 0 then return nil end

    return enabled[math.random(#enabled)]
end

-- Send completion message to party chat
function Addon:SendCompletionMessage(dungeon, keyLevel, onTime, upgrade, timeFormatted)
    local db = self.db.profile
    if not db.enabled or not db.mythicplus.enabled or not db.mythicplus.completionEnabled then return end

    local template = self:GetRandomCompletionMessage(onTime)
    if not template then
        self:DebugPrint("SendCompletionMessage: no completion messages enabled for", onTime and "timed" or "depleted")
        return
    end

    local extra = {
        upgrade = tostring(upgrade or 0),
        time = timeFormatted or "0:00",
    }

    local message = self:ReplacePlaceholders(template, dungeon, keyLevel, extra)

    self:DebugPrint("SendCompletionMessage:", message, "(onTime:", tostring(onTime),
        "dungeon:", dungeon, "level:", tostring(keyLevel), "upgrade:", tostring(upgrade) .. ")")

    -- Always party in M+ dungeon
    local channel = "PARTY"

    if self:IsTestMode() then
        local channelColor = "|cFFAAAAFF"
        print("|cFFFF9900[AutoSay TEST]|r Would send to " .. channelColor .. "[" .. channel .. "]|r: " .. message)
        self:DebugPrint("Test mode - simulated completion message to", channel)
    else
        local ok, err = pcall(SendChatMessage, message, channel, nil, nil)
        if ok then
            self:DebugPrint("Completion message sent to", channel, ":", message)
        else
            self:DebugPrint("Failed to send completion message:", tostring(err))
        end
    end
end

--------------------------------------------------------------------------------
-- TEST MODE SIMULATION FUNCTIONS
--------------------------------------------------------------------------------

-- Reset test state
function Addon:TestReset()
    self.testState.simulatedGroupType = nil
    self.testState.simulatedInGuild = false
    self.testState.simulatedGroupMembers = {}
    self.testState.simulatedIsLeader = true
    self.state.previousGroup = nil
    self.state.sentGreetings = {}
    self.state.currentGroupType = nil
    self.state.lastGroupMessageTime = 0
    self.state.lastGuildMessageTime = 0
    self.state.pendingNewMembers = {}
    if self.state.pendingGreetTimer then
        self:CancelTimer(self.state.pendingGreetTimer)
        self.state.pendingGreetTimer = nil
    end
    self.state.messageQueue = {}
    if self.state.queueTimer then
        self:CancelTimer(self.state.queueTimer)
        self.state.queueTimer = nil
    end
    self.state.lastGreetingText = {}
    self.state.cachedLFGListing = nil
    self.state.keyAnnounced = false
    self.state.mythicPlusFlowActive = false
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

-- Simulate full M+ flow: create listing → players join → 5/5 → announce
function Addon:TestMythicPlusFlow()
    if not self:IsTestMode() then
        self:Print("|cFFFF0000Test mode is not enabled!|r Use /as testmode or enable in settings.")
        return
    end

    -- Prevent overlapping simulations
    if self.state.mythicPlusFlowActive then
        self:TestPrint("M+ flow simulation already in progress!")
        return
    end

    local isLeader = self.testState.mythicPlusRole == "leader"

    self:TestPrint("=== Simulating M+ Full Flow (" .. (isLeader and "Leader" or "Joined") .. ") ===")
    self.state.mythicPlusFlowActive = true

    -- Step 1: Reset and set up party
    self:TestReset()
    self.testState.simulatedGroupType = "PARTY"
    self.testState.simulatedIsLeader = isLeader
    self.state.currentGroupType = "PARTY"
    self.state.previousGroup = { [UnitName("player")] = true }
    self.testState.simulatedGroupMembers = { UnitName("player") }

    -- Randomize dungeon
    local dungeons = {
        "The Dawnbreaker", "Cinderbrew Meadery", "Darkflame Cleft",
        "The Rookery", "Priory of the Sacred Flame", "The Stonevault",
        "City of Threads", "Ara-Kara, City of Echoes",
    }
    local dungeon = dungeons[math.random(#dungeons)]
    local keyLevel = math.random(4, 15)

    if isLeader then
        -- Leader: has LFG listing cached
        self.state.cachedLFGListing = {
            activityID = 0,
            title = "+" .. keyLevel,
            dungeonName = dungeon .. " (Mythic Keystone)",
            isMythicPlus = true,
        }
        self:TestPrint("Listed in Group Finder: " .. dungeon .. " +" .. keyLevel)
    else
        -- Joined: no listing data (cleared on GROUP_JOINED)
        self.state.cachedLFGListing = nil
        self:TestPrint("Joined a group for: " .. dungeon .. " +" .. keyLevel)
    end
    self.state.keyAnnounced = false

    self:TestPrint("Waiting for group to fill...")

    -- Step 2: Players join with delays
    local fakeNames = { "Tankmaster", "HolyPala", "Shadowmage", "Hunterbro" }
    for i, name in ipairs(fakeNames) do
        self:ScheduleTimer(function()
            table.insert(self.testState.simulatedGroupMembers, name)
            local count = #self.testState.simulatedGroupMembers
            self:TestPrint(name .. " joined (" .. count .. "/5)")

            -- Greet if enabled (only others_join when leader, self_join handled separately)
            if self.db.profile.enabled and self:ShouldGreetOnOthersJoin("PARTY") then
                if not self.state.sentGreetings[name] then
                    self.state.sentGreetings[name] = true
                    self:SendGreeting({ name }, "others_join")
                end
            end

            -- Check if group is full 5/5
            if count == 5 then
                local db = self.db.profile
                if db.mythicplus and db.mythicplus.enabled
                   and db.mythicplus.announceOnFull
                   and not self.state.keyAnnounced then
                    if self.state.cachedLFGListing and self.state.cachedLFGListing.isMythicPlus then
                        self.state.keyAnnounced = true
                        self:TestPrint("Group full 5/5! Sending key announce...")
                        self:ScheduleTimer(function()
                            self:SendKeyAnnounce()
                            self.state.mythicPlusFlowActive = false
                        end, 2)
                    else
                        self:TestPrint("Group full 5/5 but no listing data (not the leader) — key announce skipped")
                        self.state.mythicPlusFlowActive = false
                    end
                else
                    if not db.mythicplus.enabled then
                        self:TestPrint("M+ announcements disabled in settings")
                    end
                    self.state.mythicPlusFlowActive = false
                end
            end
        end, i * 2) -- 2 seconds between each join
    end
end

-- Simulate timed M+ completion
function Addon:TestCompletionTimed()
    if not self:IsTestMode() then
        self:Print("|cFFFF0000Test mode is not enabled!|r Use /as testmode or enable in settings.")
        return
    end

    local dungeons = {
        "The Dawnbreaker", "Cinderbrew Meadery", "Darkflame Cleft",
        "The Rookery", "Priory of the Sacred Flame", "The Stonevault",
        "City of Threads", "Ara-Kara, City of Echoes",
    }
    local dungeon = dungeons[math.random(#dungeons)]
    local keyLevel = math.random(4, 15)
    local upgrade = math.random(1, 3)
    local minutes = math.random(15, 35)
    local seconds = math.random(0, 59)
    local timeFormatted = string.format("%d:%02d", minutes, seconds)

    self:TestPrint("=== Simulating M+ Timed Completion ===")
    self:TestPrint(dungeon .. " +" .. keyLevel .. " timed in " .. timeFormatted .. " (+" .. upgrade .. " upgrade)")

    self:SendCompletionMessage(dungeon, keyLevel, true, upgrade, timeFormatted)
end

-- Simulate depleted M+ completion
function Addon:TestCompletionDepleted()
    if not self:IsTestMode() then
        self:Print("|cFFFF0000Test mode is not enabled!|r Use /as testmode or enable in settings.")
        return
    end

    local dungeons = {
        "The Dawnbreaker", "Cinderbrew Meadery", "Darkflame Cleft",
        "The Rookery", "Priory of the Sacred Flame", "The Stonevault",
        "City of Threads", "Ara-Kara, City of Echoes",
    }
    local dungeon = dungeons[math.random(#dungeons)]
    local keyLevel = math.random(4, 15)
    local minutes = math.random(35, 50)
    local seconds = math.random(0, 59)
    local timeFormatted = string.format("%d:%02d", minutes, seconds)

    self:TestPrint("=== Simulating M+ Depleted Completion ===")
    self:TestPrint(dungeon .. " +" .. keyLevel .. " depleted at " .. timeFormatted)

    self:SendCompletionMessage(dungeon, keyLevel, false, 0, timeFormatted)
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

    -- Queue status
    local queueSize = #self.state.messageQueue
    if queueSize > 0 then
        self:Print("Queued messages:", "|cFFFFFF00" .. queueSize .. "|r",
            "| Timer:", self.state.queueTimer and "|cFF00FF00scheduled|r" or "|cFFFF0000none|r")
        for i, entry in ipairs(self.state.messageQueue) do
            local namesStr = entry.playerNames and table.concat(entry.playerNames, ", ") or "none"
            self:Print("  [" .. i .. "]", entry.channel, entry.reason, "names:", namesStr)
        end
    else
        self:Print("Queued messages:", "|cFF00FF000|r")
    end

    -- Greeting text cache status
    local cacheCount = 0
    local now = GetTime()
    local cooldown = self.db.profile.cooldown
    for key, cached in pairs(self.state.lastGreetingText) do
        local age = now - cached.time
        if age < cooldown * 2 then
            cacheCount = cacheCount + 1
            self:Print("Cached greeting:", "|cFFFFFF00" .. key .. "|r", "=", "|cFF00FF00" .. cached.text .. "|r",
                "(age:", string.format("%.1fs", age) .. ")")
        end
    end
    if cacheCount == 0 then
        self:Print("Cached greetings:", "|cFF888888none|r")
    end

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
    self:Print("M+:", db.mythicplus.enabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r",
        "| Mode:", db.mythicplus.messageMode,
        "| Announced:", self.state.keyAnnounced and "|cFFFFFF00Yes|r" or "|cFF888888No|r")
    if self.state.cachedLFGListing then
        self:Print("  LFG cache:", self.state.cachedLFGListing.dungeonName or "unknown",
            "| Title:", self.state.cachedLFGListing.title or "none",
            "| M+:", self.state.cachedLFGListing.isMythicPlus and "|cFF00FF00Yes|r" or "|cFFFF0000No|r")
    end
end
