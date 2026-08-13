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
    welcome = true,
    -- Disabled by default
    wassup = false,
    yo = false,
    heya = false,
    sup = false,
    howdy = false,
    hiya = false,
    yoyo = false,
    hellothere = false,
    welcomenames = false,
    hinames = false,
    welcomeaboard = false,
    -- Time-of-day phrases: on by default, gated by social.timeOfDay and the local hour
    morning = true,
    goodmorningall = true,
    morningwave = true,
    evening = true,
    goodevening = true,
    eveningall = true,
    lateone = true,
    laterun = true,
    uplate = true,
    nightowls = true,
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
    -- Time-of-day phrases: off by default - band goodbyes are new behavior, and AceDB
    -- merges these keys into existing profiles (a true here would surprise upgraders
    -- who had turned every stock goodbye off)
    eveningbye = false,
    gnall = false,
    goodnightall = false,
    sleepwell = false,
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

-- Default enabled guild login greetings
local defaultGuildLoginGreetings = {
    wb = true,
    hey = true,
    hi = true,
    -- Disabled by default
    ohey = false,
    greetings = false,
    goodtosee = false,
    wbplain = false,
    heythere = false,
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
        instanceMigrated = false, -- Instance channel seeded from the party settings (see MigrateInstanceChannel)

        -- Minimap icon
        minimap = {
            hide = false,
        },

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

        -- Instance group settings (LFG dungeons/LFR/battlegrounds, INSTANCE_CHAT)
        instance = {
            enabled = true,
            onSelfJoin = true,          -- Greet once after zoning into the instance
            onOthersJoin = false,
            onOthersJoinLeaderOnly = false,
            includeNames = false,
            includeGroupNames = false,
            sendGoodbye = true,
            enabledGreetings = DeepCopy(defaultGreetings),
            enabledGoodbyes = DeepCopy(defaultGoodbyes),
            customGreetings = {},
            customGoodbyes = {},
        },

        -- Mythic+ settings
        mythicplus = {
            enabled = true,
            announceOnFull = true,      -- Announce when group fills 5/5
            messageMode = "basic",      -- "basic" | "withlevel" | "smart"
            useClientLanguage = false,  -- false = English dungeon names, true = client locale
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
            onMemberLogin = false, -- Greet guild members who log in
            memberLoginCooldown = 30, -- Separate cooldown for member login greetings (seconds)
            enabledGreetings = DeepCopy(defaultGreetings),
            enabledGoodbyes = DeepCopy(defaultGoodbyes),
            enabledLoginGreetings = DeepCopy(defaultGuildLoginGreetings),
            customGreetings = {},
            customGoodbyes = {},
            customLoginGreetings = {},
        },

        -- Social gate / humanizer settings
        social = {
            budgetPerHour = 12,
            personCooldownHours = 4,
            listen = true,
            typingDelay = true,
            timeOfDay = true,
            rolePhrases = true, -- Master switch for role-tagged and {role} phrases
            lowercaseFirst = false,
            guildGrats = false,
            guildWelcome = false,
        },
    },

    global = {
        -- "major.minor" of the last release whose What's new popup was dismissed.
        -- Account-wide on purpose: the news is the same on every character.
        whatsNewSeen = "",
    },

    char = {
        social = {},
        -- Instance zone-in greeting flag, persisted so a /reload does not re-greet
        instanceGreeted = { done = false },
        lastLogoutTime = 0,
        lastSeenTime = 0, -- Heartbeat: PLAYER_LOGOUT never fires on a crash/hard DC, this does
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
    cachedLFGListing = nil, -- Cached LFG listing data (before auto-delist)
    keyAnnounced = false, -- Prevent duplicate M+ key announcements per group
    keyAnnounceRetried = false, -- Key announce was already re-scheduled once for the cooldown
    keyAnnounceTimer = nil, -- Pending key announce retry timer (one in flight at a time)
    groupGoodbyeTimer = nil, -- Self-reset timer for the once-per-leave goodbye guard
    instanceGreeted = false, -- Instance zone-in greeting sent (mirrors db.char.instanceGreeted, see SetInstanceGreeted)
    pendingGuildLogins = {}, -- Batch guild member login names
    guildLoginTimer = nil, -- Timer for batched guild login greeting
    lastGuildLoginGreetTime = 0, -- Separate cooldown for guild member login greetings
    guildMemberPresence = {}, -- Track guild member presence states (memberId → presence)
    guildPresenceReady = false, -- Flag: true after INITIAL_CLUBS_LOADED + snapshot (prevents mass greetings on login)
    pendingGuildGreeting = false, -- Flag: send guild greeting after clubs load (deferred from PLAYER_ENTERING_WORLD)
}

-- Test mode simulation state
Addon.testState = {
    simulatedGroupType = nil, -- "PARTY", "RAID", or nil
    simulatedInGuild = false,
    simulatedGroupMembers = {},
    simulatedIsLeader = true, -- Simulate being group leader (default true for test)
    simulatedRole = "DAMAGER", -- Role used for role-tagged phrases while testing
    mythicPlusRole = "leader", -- "leader" or "joined" for M+ flow simulation
}

function Addon:OnInitialize()
    -- Initialize database
    self.db = LibStub("AceDB-3.0"):New("AutoSayDB", defaults, true)

    -- Migrate old single custom message format to new array format
    self:MigrateCustomMessages()

    -- Seed the instance channel from the party settings on the first run after the upgrade
    self:MigrateInstanceChannel()

    -- Wire up social gate + humanizer core
    self.socialGate = AutoSay.SocialGate.New{
        now = time,
        settings = function() return self.db.profile.social end,
        state = self.db.char.social,
        debug = function(msg) self:DebugPrint("SocialGate:", msg) end,
    }
    self.humanizer = AutoSay.Humanizer.New{
        random = math.random,
        hour = function() return tonumber(date("%H")) end,
    }
    self.socialGate:Prune()

    -- Register slash commands
    self:RegisterChatCommand("autosay", "SlashCommand")
    self:RegisterChatCommand("as", "SlashCommand")

    -- Initialize minimap icon
    self:InitMinimapIcon()

    self:DebugPrint("Addon initialized")
end

-- Initialize minimap icon using LibDBIcon
function Addon:InitMinimapIcon()
    local LDB = LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LibStub("LibDBIcon-1.0", true)
    if not LDB or not LDBIcon then return end

    local dataObj = LDB:NewDataObject("AutoSay", {
        type = "launcher",
        icon = "Interface\\Icons\\UI_Chat",
        label = "AutoSay",
        OnClick = function()
            local AceConfigDialog = LibStub("AceConfigDialog-3.0")
            if AceConfigDialog.OpenFrames["AutoSay"] then
                AceConfigDialog:Close("AutoSay")
            else
                Addon:OpenConfig()
            end
        end,
        OnTooltipShow = function(tip)
            tip:AddLine("|cFF0099FFAuto|r|cFFFFD700Say|r")
            tip:AddLine("|cFFCCCCCCClick|r to open settings", 0.8, 0.8, 0.8)
        end,
    })

    LDBIcon:Register("AutoSay", dataObj, self.db.profile.minimap)
    self.minimapIcon = LDBIcon
end

-- Update minimap icon visibility
function Addon:UpdateMinimapIcon()
    if not self.minimapIcon then return end
    if self.db.profile.minimap.hide then
        self.minimapIcon:Hide("AutoSay")
    else
        self.minimapIcon:Show("AutoSay")
    end
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

-- The instance channel is new: before it existed LFG groups used the party settings, so seed
-- it from them once. On a fresh install the party values are the defaults, so this is a no-op.
-- Only the active profile is migrated - the addon registers no AceDB profile callbacks, so a
-- profile switched to later keeps its own (defaults-equal) instance settings.
function Addon:MigrateInstanceChannel()
    local profile = self.db.profile
    if profile.instanceMigrated then return end

    local party, instance = profile.party, profile.instance
    instance.enabled = party.enabled
    instance.onSelfJoin = party.onSelfJoin
    instance.onOthersJoin = party.onOthersJoin
    instance.onOthersJoinLeaderOnly = party.onOthersJoinLeaderOnly
    instance.includeNames = party.includeNames
    instance.includeGroupNames = party.includeGroupNames
    instance.sendGoodbye = party.sendGoodbye

    profile.instanceMigrated = true
    self:DebugPrint("Instance channel seeded from party settings")
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

    -- Presence heartbeat: PLAYER_LOGOUT never fires on a crash or hard disconnect, so the
    -- reconnect detection also compares against this once-a-minute timestamp
    self:ScheduleRepeatingTimer(function()
        self.db.char.lastSeenTime = time()
    end, 60)

    -- What's new popup, well after the loading screen has let go
    self:ScheduleTimer("CheckWhatsNew", 8)

    self:DebugPrint("Addon enabled")
end

-- "1.6" out of "1.6.2"; nil for an unpackaged build, where the TOC still holds the
-- packager placeholder and there is no release to announce
function Addon:VersionMinor()
    local version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON_NAME, "Version") or ""
    return version:match("^(%d+%.%d+)")
end

-- Show the What's new popup once per account per minor release
function Addon:CheckWhatsNew()
    local minor = self:VersionMinor()
    if not minor or self.db.global.whatsNewSeen == minor then return end

    -- A popup mid-fight is worse than a popup a minute later
    if InCombatLockdown() then
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            self:CheckWhatsNew()
        end)
        return
    end

    self:ShowWhatsNew(minor)
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
            self:SendGroupGoodbyeOnce(category)
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

-- Which chat the goodbye belongs in for the group we are leaving. LeaveParty tells us
-- which of the two group slots is being dropped; without it fall back to where we are now.
function Addon:GoodbyeChannelForCategory(category)
    if category == LE_PARTY_CATEGORY_HOME then
        return IsInRaid(LE_PARTY_CATEGORY_HOME) and "RAID" or "PARTY"
    elseif category == LE_PARTY_CATEGORY_INSTANCE then
        return "INSTANCE_CHAT"
    end
    -- Resolve live (we are still in the group at this point) so LFG groups pick up
    -- the instance settings; cached type is the fallback if the API already dropped us
    return self:GetChatChannel() or self.state.currentGroupType
end

-- Send group goodbye only once per leave action
function Addon:SendGroupGoodbyeOnce(category)
    if self.state.groupGoodbyeSent then
        self:DebugPrint("Group goodbye already sent, skipping")
        return
    end

    local channel = self:GoodbyeChannelForCategory(category)
    if not channel then
        self:DebugPrint("No current group type cached, skipping goodbye")
        return
    end

    self.state.groupGoodbyeSent = true
    self:DebugPrint("Sending goodbye to", channel, "before leaving")
    self:SendGoodbye(channel)

    -- GROUP_LEFT deliberately does not clear the flag (it fires milliseconds after this
    -- hook), and leaving an instance group while still in a home party fires no group event
    -- at all - so the guard resets itself. 5s covers a double LeaveParty, nothing longer.
    if self.state.groupGoodbyeTimer then
        self:CancelTimer(self.state.groupGoodbyeTimer)
    end
    self.state.groupGoodbyeTimer = self:ScheduleTimer(function()
        self.state.groupGoodbyeTimer = nil
        self.state.groupGoodbyeSent = false
    end, 5)
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
        elseif subcmd == "instance" or subcmd == "i" then
            self:TestJoinInstance()
        elseif subcmd == "leave" or subcmd == "l" then
            self:TestLeaveGroup()
        elseif subcmd == "guild" or subcmd == "g" then
            self:TestGuildGreeting()
        elseif subcmd == "guildbye" or subcmd == "gb" then
            self:TestGuildGoodbye()
        elseif subcmd == "guildlogin" or subcmd == "gl" then
            local _, _, playerName = self:GetArgs(input, 3)
            self:TestGuildMemberLogin(playerName)
        elseif subcmd == "grats" then
            self:TestPrint("=== Simulating GUILD ACHIEVEMENT (TestGuildie) ===")
            self:SendGuildGrats("TestGuildie")
        elseif subcmd == "guildjoin" or subcmd == "gj" then
            self.testGuildJoinCounter = (self.testGuildJoinCounter or 0) + 1
            local name = "TestNewbie" .. self.testGuildJoinCounter
            self:TestPrint("=== Simulating GUILD JOIN (" .. name .. ") ===")
            self:SendGuildWelcome(name)
        elseif subcmd == "reconnect" or subcmd == "re" then
            self:TestReconnect()
        elseif subcmd == "player" or subcmd == "join" then
            local _, _, playerName = self:GetArgs(input, 3)
            self:TestPlayerJoins(playerName)
        elseif subcmd == "key" or subcmd == "k" then
            self:TestMythicPlusFlow()
        elseif subcmd == "reset" then
            self:TestReset()
        elseif subcmd == "resetgate" or subcmd == "rg" then
            local social = self.db.char.social
            for _, key in ipairs({"sends", "perPerson", "welcomed", "welcomeSends"}) do
                for k in pairs(social[key]) do
                    social[key][k] = nil
                end
            end
            if self.socialGate then
                self.socialGate.pending = {}
            end
            self:Print("Social gate counters cleared (budget, cooldowns, welcomed list)")
        elseif subcmd == "status" or subcmd == "s" then
            self:TestStatus()
        else
            self:Print("|cFFFF9900Test commands:|r")
            self:Print("  /as test party - Simulate joining a party")
            self:Print("  /as test raid - Simulate joining a raid")
            self:Print("  /as test instance - Simulate zoning into an instance group")
            self:Print("  /as test leave - Simulate leaving group")
            self:Print("  /as test guild - Simulate guild login greeting")
            self:Print("  /as test guildbye - Simulate guild logout goodbye")
            self:Print("  /as test guildlogin [name] - Simulate guild member logging in")
            self:Print("  /as test grats - Simulate guild achievement congrats")
            self:Print("  /as test guildjoin - Simulate a new member joining the guild")
            self:Print("  /as test reconnect - Simulate reconnecting to group")
            self:Print("  /as test player [name] - Simulate player joining")
            self:Print("  /as test key - Simulate full M+ flow (listing → joins → announce)")
            self:Print("  /as test reset - Reset test state")
            self:Print("  /as test resetgate - Clear social gate counters (budget, cooldowns, welcomed list)")
            self:Print("  /as test status - Show test status")
        end
    elseif cmd == "selftest" or cmd == "st" then
        self:RunSelfTest()
    elseif cmd == "dumpdungeons" or cmd == "dd" then
        self:DumpDungeons()
    elseif cmd == "status" then
        self:TestStatus()
    elseif cmd == "help" or cmd == "?" then
        self:Print("|cFFFFCC00AutoSay Commands:|r")
        self:Print("  /as - Open settings")
        self:Print("  /as toggle - Enable/disable addon")
        self:Print("  /as debug - Toggle debug mode")
        self:Print("  /as testmode - Toggle test mode")
        self:Print("  /as test [cmd] - Run test simulation")
        self:Print("  /as selftest - Verify anti-spam and humanizer logic (no side effects)")
        self:Print("  /as dumpdungeons - Print the live M+ pool as paste-ready Lua for Messages.lua")
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
        frame:SetStatusText(L["Made in Ukraine"])
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
function Addon:SendMessageToChat(message, channel, target, keepCase)
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
    if self.db.profile.social.typingDelay and self.humanizer then
        delay = math.max(delay or 0, self.humanizer:GetTypingDelay(message))
    end

    if delay and delay > 0 then
        self:ScheduleTimer(function()
            self:DoSendMessage(message, channel, target, keepCase)
        end, delay)
        self:DebugPrint("Scheduled message in", delay, "seconds")
    else
        self:DoSendMessage(message, channel, target, keepCase)
    end
    return true
end

-- Final polish applied to every outgoing message: {role} placeholder, leftover M+ tokens,
-- and the optional lowercase first letter (skipped for keepCase phrases, e.g. "Lok'tar ogar!")
-- (%a is ASCII-only on purpose, so UTF-8 custom messages are left alone)
function Addon:PolishMessage(message, keepCase)
    if not message then return nil end
    message = message:gsub("{role}", self:GetRoleWord())
    -- M+ placeholders only the M+ path can resolve - a custom greeting/goodbye using them
    -- would otherwise ship the raw token to chat
    for _, token in ipairs(AutoSay.MPlusTokens) do
        message = message:gsub(token, "")
    end
    message = message:gsub("  +", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if self.db.profile.social.lowercaseFirst and not keepCase then
        message = message:gsub("^%a", string.lower)
    end
    return message
end

-- Chat colour per channel for the test-mode "would send" line
local ChannelColor = {}
for _, c in ipairs(AutoSay.Channels) do ChannelColor[c.chat] = c.color end

-- SendChatMessage rejects anything over 255 bytes: cut to 252 + "...", never inside a UTF-8 sequence
local function TruncateToChatLimit(message)
    if #message <= 255 then return message end
    local cut = 252
    while cut > 0 do
        local b = message:byte(cut)
        if b >= 0x80 and b < 0xC0 then
            cut = cut - 1 -- continuation byte, walk back to the lead byte
        else
            if b >= 0xC0 then cut = cut - 1 end -- lead byte of a sequence that no longer fits
            break
        end
    end
    return message:sub(1, cut) .. "..."
end

function Addon:DoSendMessage(message, channel, target, keepCase)
    if not message then
        self:DebugPrint("No message to send")
        return
    end

    message = TruncateToChatLimit(self:PolishMessage(message, keepCase))

    -- Token stripping can reduce a message to nothing (custom text of only "{dungeon} {key}")
    -- and SendChatMessage("") would error - drop instead
    if not message:match("%S") then
        self:DebugPrint("Message empty after polish, dropping")
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
        local channelColor = ChannelColor[channel] or "|cFF00CCFF" -- Default blue
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

-- Instance zone-in greeting flag. Mirrored into db.char so a /reload inside the instance
-- does not greet the same group twice; cleared whenever we leave or change group.
function Addon:SetInstanceGreeted(done)
    self.state.instanceGreeted = done and true or false
    self.db.char.instanceGreeted.done = self.state.instanceGreeted
end

-- Get appropriate chat channel
function Addon:GetChatChannel()
    -- In test mode, use simulated group type
    if self:IsTestMode() and self.testState.simulatedGroupType then
        return self.testState.simulatedGroupType
    end

    if IsInRaid(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    elseif IsInRaid() then
        return "RAID"
    elseif IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
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

-- Get assigned role (with test mode support); "NONE" when solo/unassigned
function Addon:GetPlayerRoleOrTest()
    if self:IsTestMode() then
        return self.testState.simulatedRole or "DAMAGER"
    end
    return UnitGroupRolesAssigned("player")
end

-- Word used for the {role} placeholder
function Addon:GetRoleWord()
    return AutoSay.RoleWords[self:GetPlayerRoleOrTest()] or AutoSay.RoleWords.DAMAGER
end

-- Get channel settings table
function Addon:GetChannelSettings(channel)
    for _, c in ipairs(AutoSay.Channels) do
        if c.chat == channel then return self.db.profile[c.key] end
    end
    return nil
end

-- Preset phrases can be tagged with a role/faction/time-of-day band/trigger - skip the ones that do not fit right now
local function FitsContext(msg, role, faction, band, reason, rolePhrases)
    -- Master switch: every tag has its filter, and this one gates the role tag and {role}
    if not rolePhrases and (msg.role or msg.text:find("{role}", 1, true)) then return false end
    if msg.role and msg.role ~= role then return false end
    -- No assigned role: a {role} phrase would confidently announce "dps" for an unassigned tank
    if role == "NONE" and msg.text:find("{role}", 1, true) then return false end
    if msg.faction and msg.faction ~= faction then return false end
    if msg.band and msg.band ~= band then return false end
    -- Reason-less paths (guild login/logout, group goodbye) have no join to talk about,
    -- so a phrase written for one ("tank here, pull respectfully") never fits them
    if reason == nil then return msg.trigger == nil end
    -- Anything that is not someone else joining (self join, reconnect, guild login) counts as "self"
    if msg.trigger == "others" and reason ~= "others_join" then return false end
    if msg.trigger == "self" and reason == "others_join" then return false end
    return true
end

-- Names-carrying phrase with no names to carry: drop the slot instead of the phrase,
-- so a pool of only {names} phrases still says something ("welcome {names}!" -> "welcome!")
local function StripNameSlot(text)
    text = text:gsub("{names}", "")
    text = text:gsub("  +", " "):gsub("%s+([!?.,])", "%1")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- How a phrase carries player names: "slot" = {names} inside the text, "append" = glued to the end
local function NameMode(msg)
    if msg.text:find("{names}", 1, true) then return "slot" end
    if msg.appendNames then return "append" end
    return nil
end

-- Get random message for a channel.
-- reason is the greeting reason ("self_join"/"others_join"/"reconnect", nil elsewhere) and gates
-- the per-phrase trigger; wantNames prefers phrases that can carry names.
-- Returns the text, its name mode (nil = the phrase must never carry names) and its keepCase flag.
function Addon:GetRandomMessageForChannel(messageType, channel, reason, wantNames)
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

    -- Presets first, and the same text never enters twice: a custom copy of a preset must not
    -- override the preset's keepCase/mode, nor double that text's odds of being picked
    local candidates, seen = {}, {}
    local function AddCandidate(c)
        if seen[c.text] then return end
        seen[c.text] = true
        table.insert(candidates, c)
    end

    -- Add enabled preset messages
    if settings[enabledKey] then
        local role = self:GetPlayerRoleOrTest()
        local faction = UnitFactionGroup("player")
        -- nil band = band-tagged phrases never match, i.e. the master switch is off
        local hour = (self.humanizer and self.humanizer.hour)
            and self.humanizer.hour() or tonumber(date("%H"))
        local band = self.db.profile.social.timeOfDay
            and AutoSay.Humanizer.BandForHour(hour) or nil
        local rolePhrases = self.db.profile.social.rolePhrases
        for _, msg in ipairs(messages) do
            if settings[enabledKey][msg.key] and FitsContext(msg, role, faction, band, reason, rolePhrases) then
                AddCandidate({ text = msg.text, mode = NameMode(msg), keepCase = msg.keepCase })
            end
        end
    end

    -- Add enabled custom messages: a {names} placeholder makes them slot phrases (and thus
    -- droppable when there are no names), everything else keeps the append-if-asked behaviour
    if settings[customsKey] then
        for _, entry in ipairs(settings[customsKey]) do
            if entry.enabled and entry.text and entry.text ~= "" then
                local mode = entry.text:find("{names}", 1, true) and "slot" or "append"
                AddCandidate({ text = entry.text, mode = mode })
            end
        end
    end

    -- With names in hand prefer the phrases built for them; without, drop the ones
    -- that would render a hole where {names} sits
    local pool = {}
    for _, c in ipairs(candidates) do
        if wantNames then
            if c.mode then table.insert(pool, c) end
        elseif c.mode ~= "slot" then
            table.insert(pool, c)
        end
    end
    if wantNames and #pool == 0 then
        pool = candidates -- nothing name-capable is enabled: send without names
    elseif not wantNames and #pool == 0 then
        -- Only {names} phrases are enabled and there are no names: say them without the slot
        -- rather than going silent
        for _, c in ipairs(candidates) do
            if c.mode == "slot" then
                table.insert(pool, { text = StripNameSlot(c.text), keepCase = c.keepCase })
            end
        end
    end
    if #pool == 0 then
        return nil
    end

    local texts = {}
    for _, c in ipairs(pool) do
        table.insert(texts, c.text)
    end

    local text
    if self.humanizer then
        text = self.humanizer:Pick(messageType .. ":" .. channel, texts)
    else
        text = texts[math.random(#texts)]
    end

    -- First match wins, same rule the dedupe above used
    for _, c in ipairs(pool) do
        if c.text == text then return text, c.mode, c.keepCase end
    end
    return text
end

-- Pools a style bundle can toggle (channels without a pool are skipped)
local stylePools = {
    { messages = "Greetings",  enabledKey = "enabledGreetings" },
    { messages = "Goodbyes",   enabledKey = "enabledGoodbyes" },
    { messages = "Reconnects", enabledKey = "enabledReconnects" },
}

-- Phrases of the other faction can never be picked on this character, so the bundle both
-- ignores them when deciding "fully enabled" and leaves them alone when applying.
local function StyleFits(msg, style, faction)
    return msg.style == style and (not msg.faction or msg.faction == faction)
end

-- True when every usable phrase of the style is enabled on every channel that has its pool
function Addon:IsStyleBundleEnabled(style)
    local faction = UnitFactionGroup("player")
    for _, c in ipairs(AutoSay.Channels) do
        local settings = self.db.profile[c.key]
        for _, pool in ipairs(stylePools) do
            local enabled = settings and settings[pool.enabledKey]
            if enabled then
                for _, msg in ipairs(AutoSay[pool.messages]) do
                    if StyleFits(msg, style, faction) and not enabled[msg.key] then
                        return false
                    end
                end
            end
        end
    end
    return true
end

-- Set every preset phrase of a style on all channels (state = true/false).
-- replace = true also turns off everything that is not part of the style (custom messages are untouched).
function Addon:ApplyStyleBundle(style, replace, state)
    if state == nil then state = true end
    local faction = UnitFactionGroup("player")

    -- A pool the style has nothing usable in must be left as it is - Replace has no
    -- replacement to offer there, so wiping it would just silence the channel
    local poolHasStyle = {}
    for _, pool in ipairs(stylePools) do
        for _, msg in ipairs(AutoSay[pool.messages]) do
            if StyleFits(msg, style, faction) then
                poolHasStyle[pool.enabledKey] = true
                break
            end
        end
    end

    for _, c in ipairs(AutoSay.Channels) do
        local settings = self.db.profile[c.key]
        for _, pool in ipairs(stylePools) do
            local enabled = settings and settings[pool.enabledKey]
            if enabled and poolHasStyle[pool.enabledKey] then
                for _, msg in ipairs(AutoSay[pool.messages]) do
                    if StyleFits(msg, style, faction) then
                        enabled[msg.key] = state
                    elseif msg.style == style then
                        -- other faction's phrase of this same style: untouched
                    elseif replace and state and not msg.band then
                        -- Band phrases are not shown in this UI - Replace must not silently kill them
                        enabled[msg.key] = false
                    end
                end
            end
        end
    end

    LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
    local doneKey = state and "Style bundle applied" or "Style bundle removed"
    self:Print(L[doneKey] .. ": |cFFFFFF00" .. L["Style " .. style] .. "|r")
end

-- Tag-category matchers for the bulk enable/disable buttons next to the master switches
local TagMatchers = {
    role = function(msg) return msg.role ~= nil or msg.text:find("{role}", 1, true) ~= nil end,
    band = function(msg) return msg.band ~= nil end,
}

-- Bulk-set every phrase of a tag category (role/band) on all channels, bundle-style.
-- The master switch stays the gate; this only rewrites the per-phrase checkboxes,
-- so "master on + old selections" remains the third, untouched-by-buttons state.
function Addon:SetTaggedPhrasesEnabled(kind, state)
    local matches = TagMatchers[kind]
    if not matches then return end

    for _, c in ipairs(AutoSay.Channels) do
        local settings = self.db.profile[c.key]
        for _, pool in ipairs(stylePools) do
            local enabled = settings and settings[pool.enabledKey]
            if enabled then
                for _, msg in ipairs(AutoSay[pool.messages]) do
                    if matches(msg) then
                        enabled[msg.key] = state
                    end
                end
            end
        end
    end

    LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
    self:Print(L[state and "Phrases enabled on all channels" or "Phrases disabled on all channels"])
end

-- Render player names into a message according to the phrase's name mode
-- ("slot" = fill the {names} placeholder, "append" = glue to the end, nil = no names at all)
function Addon:AddPlayersToMessage(message, playerNames, nameMode)
    if not nameMode or not playerNames or #playerNames == 0 then
        return message
    end

    -- Long name lists read like spam: keep four and count the rest
    local names
    if #playerNames > 4 then
        names = table.concat(playerNames, ", ", 1, 4) .. " +" .. (#playerNames - 4)
    else
        names = table.concat(playerNames, ", ")
    end

    if nameMode == "slot" then
        return (message:gsub("{names}", names))
    end

    return message .. " " .. names
end

-- Send greeting (checks cooldown and drops if blocked).
-- Returns true only when a message reached the send pipeline - callers that burn a
-- once-per-group flag (instance zone-in) must not burn it on a bail-out.
function Addon:SendGreeting(playerNames, reason)
    local db = self.db.profile

    if not db.enabled then return false end

    local channel = self:GetChatChannel()
    if not channel then
        self:DebugPrint("Not in group, skipping greeting")
        return false
    end

    local settings = self:GetChannelSettings(channel)
    if not settings then return false end

    -- Check if channel is enabled
    if not settings.enabled then
        self:DebugPrint(channel, "greetings disabled")
        return false
    end

    if self.socialGate then
        local target = playerNames and playerNames[1] or nil
        local ok, why = self.socialGate:MaySend("greeting", target)
        if not ok then
            self:DebugPrint("SendGreeting gated:", why)
            if self:IsTestMode() then self:TestPrint("Greeting blocked: " .. why) end
            return false
        end
    end

    self:DebugPrint("SendGreeting called - reason:", reason, "channel:", channel,
        "names:", playerNames and table.concat(playerNames, ", ") or "none")

    -- Check cooldown - if blocked, drop it. A greeting that lands seconds late is a
    -- second greeting, not a delayed one.
    if not self:CanSendMessage(channel) then
        self:DebugPrint("SendGreeting -> cooldown active, dropping", reason, "greeting for", channel)
        if self:IsTestMode() then self:TestPrint("Greeting dropped (cooldown active): " .. tostring(reason)) end
        return false
    end

    -- Send immediately
    self:DebugPrint("SendGreeting -> cooldown OK, sending immediately")
    return self:BuildAndSendGreeting(channel, reason, playerNames)
end

-- Build a greeting message and send it. Returns true when it reached the send pipeline.
function Addon:BuildAndSendGreeting(channel, reason, playerNames)
    local settings = self:GetChannelSettings(channel)
    if not settings or not settings.enabled then return false end

    -- Do we want names on this one?
    -- For self_join: names are pre-collected based on includeGroupNames, use them if provided
    -- For others_join: check includeNames setting
    local hasNames = playerNames ~= nil and #playerNames > 0
    local wantNames = hasNames and (reason == "self_join" or settings.includeNames or false)

    -- Pick a message based on reason (humanizer history avoids immediate repeats)
    local message, nameMode, keepCase
    if reason == "reconnect" then
        message, nameMode, keepCase = self:GetRandomMessageForChannel("reconnects", channel, reason, wantNames)
        if not message then
            self:DebugPrint("No reconnects enabled for", channel, "- falling back to greetings")
            message, nameMode, keepCase = self:GetRandomMessageForChannel("greetings", channel, reason, wantNames)
        end
    else
        message, nameMode, keepCase = self:GetRandomMessageForChannel("greetings", channel, reason, wantNames)
    end

    if not message then
        self:DebugPrint("No greetings enabled for", channel)
        return false
    end

    message = self:AddPlayersToMessage(message, playerNames, wantNames and nameMode or nil)

    self:DebugPrint("BuildAndSend -> final message:", message)

    if not self:SendMessageToChat(message, channel, nil, keepCase) then
        -- Cooldown won the race - drop it, a late greeting is just a second greeting
        self:DebugPrint("BuildAndSend -> SendMessageToChat refused (cooldown), dropping")
        return false
    end

    -- Spend the budget slot only for a message that actually went out
    if self.socialGate then
        self.socialGate:Record("greeting", playerNames and playerNames[1] or nil)
    end
    return true
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

    if self.socialGate then
        local ok, why = self.socialGate:MaySend("goodbye")
        if not ok then
            self:DebugPrint("SendGoodbye gated:", why)
            if self:IsTestMode() then self:TestPrint("Goodbye blocked: " .. why) end
            return
        end
    end

    -- Get random goodbye for this channel
    local message, _, keepCase = self:GetRandomMessageForChannel("goodbyes", channel)
    if not message then
        self:DebugPrint("No goodbyes enabled for", channel)
        return
    end

    -- Send immediately (no delay for goodbyes since we're leaving)
    self:DoSendMessage(message, channel, nil, keepCase)

    -- Spend the budget slot for the message we just dispatched
    if self.socialGate then
        self.socialGate:Record("goodbye")
    end
end

-- Send congrats when a guildmate earns an achievement
function Addon:SendGuildGrats(name)
    if not self.socialGate or not self.humanizer then return end
    local ok, why = self.socialGate:MaySend("grats", name)
    if not ok then
        if self:IsTestMode() then self:TestPrint("Grats blocked: " .. why) end
        return
    end
    -- Reserve the slot before the listening window, so an achievement wave cannot
    -- schedule N grats against the same stale counters
    self.socialGate:Record("grats", name)
    local text = self.humanizer:Pick("guildgrats", AutoSay.GuildGrats):gsub("{name}", name)
    local pendingId = self.socialGate:AddPending("grats", "GUILD")
    local delay = 4 + math.random() * 6 -- 4-10s listening window per spec
    self:ScheduleTimer(function()
        if not self.socialGate:TakePending(pendingId) then
            if self:IsTestMode() then self:TestPrint("Grats blocked: someone-answered") end
            return
        end
        self:SendMessageToChat(text, "GUILD")
    end, delay)
end

-- Send welcome when a new member joins the guild
function Addon:SendGuildWelcome(name)
    if not self.socialGate or not self.humanizer then return end
    local okW, whyW = self.socialGate:MayWelcome(name)
    if not okW then
        if self:IsTestMode() then self:TestPrint("Welcome blocked: " .. whyW) end
        return
    end
    local ok, why = self.socialGate:MaySend("welcome", name)
    if not ok then
        if self:IsTestMode() then self:TestPrint("Welcome blocked: " .. why) end
        return
    end
    -- Reserve both the welcome cap slot and the budget slot before scheduling:
    -- a burst of joins must see the updated counters, not the pre-timer ones
    self.socialGate:RecordWelcome(name)
    self.socialGate:Record("welcome", name)
    local text = self.humanizer:Pick("guildwelcome", AutoSay.GuildWelcome):gsub("{name}", name)
    local pendingId = self.socialGate:AddPending("welcome", "GUILD")
    local delay = 5 + math.random() * 10 -- 5-15s per spec
    self:ScheduleTimer(function()
        if not self.socialGate:TakePending(pendingId) then
            if self:IsTestMode() then self:TestPrint("Welcome blocked: someone-answered") end
            return
        end
        self:SendMessageToChat(text, "GUILD")
    end, delay)
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

    -- Check cooldown - if blocked, drop it (we just said something in guild chat)
    if not self:CanSendMessage("GUILD") then
        self:DebugPrint("Guild login greeting dropped - cooldown active")
        return
    end

    -- Get random greeting for guild
    local message, _, keepCase = self:GetRandomMessageForChannel("greetings", "GUILD")
    if not message then
        self:DebugPrint("No greetings enabled for GUILD")
        return
    end

    if self.socialGate then
        local ok, why = self.socialGate:MaySend("greeting")
        if not ok then
            self:DebugPrint("Guild login greeting gated:", why)
            if self:IsTestMode() then self:TestPrint("Guild greeting blocked: " .. why) end
            return
        end
    end

    -- Spend the budget slot only for a message that actually went out
    if self:SendMessageToChat(message, "GUILD", nil, keepCase) and self.socialGate then
        self.socialGate:Record("greeting")
    end
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
    local message, _, keepCase = self:GetRandomMessageForChannel("goodbyes", "GUILD")
    if not message then
        self:DebugPrint("No goodbyes enabled for GUILD")
        return
    end

    if self.socialGate then
        local ok, why = self.socialGate:MaySend("goodbye")
        if not ok then
            self:DebugPrint("Guild goodbye gated:", why)
            if self:IsTestMode() then self:TestPrint("Guild goodbye blocked: " .. why) end
            return
        end
    end

    self:DebugPrint("Sending guild goodbye:", message)
    -- Send immediately (no delay for goodbyes)
    self:DoSendMessage(message, "GUILD", nil, keepCase)

    -- Spend the budget slot for the message we just dispatched
    if self.socialGate then
        self.socialGate:Record("goodbye")
    end
end

-- Handle a guild member logging in (called from CLUB_MEMBER_PRESENCE_UPDATED)
function Addon:HandleGuildMemberLogin(name)
    -- Add to pending batch
    self.state.pendingGuildLogins[name] = true

    -- Reset batch timer on each new login (3 sec window to collect rapid logins)
    if self.state.guildLoginTimer then
        self:CancelTimer(self.state.guildLoginTimer)
    end

    self.state.guildLoginTimer = self:ScheduleTimer(function()
        local names = {}
        for n in pairs(self.state.pendingGuildLogins) do
            table.insert(names, n)
        end
        self.state.pendingGuildLogins = {}
        self.state.guildLoginTimer = nil

        if #names > 0 then
            self:DebugPrint("Sending batched guild login greeting for:", table.concat(names, ", "))
            self:SendGuildLoginGreeting(names)
        end
    end, 3)
end

-- Send greeting when guild members log in
function Addon:SendGuildLoginGreeting(names)
    local db = self.db.profile

    if not db.enabled then return end
    if not db.guild.enabled then return end
    if not db.guild.onMemberLogin then
        self:DebugPrint("Guild member login greeting disabled")
        return
    end
    if not self:IsInGuildOrTest() then return end

    -- Check separate cooldown for member login greetings
    local now = GetTime()
    local cooldown = db.guild.memberLoginCooldown or 30
    if (now - self.state.lastGuildLoginGreetTime) < cooldown then
        local remaining = cooldown - (now - self.state.lastGuildLoginGreetTime)
        self:DebugPrint("Guild login greeting on cooldown, skipping (" .. string.format("%.1f", remaining) .. "s remaining)")
        if self:IsTestMode() then
            self:TestPrint("Guild member greeting blocked by cooldown (" .. string.format("%.1f", remaining) .. "s remaining)")
        end
        return
    end

    if self.socialGate then
        local ok, why = self.socialGate:MaySend("greeting", names and names[1] or nil)
        if not ok then
            self:DebugPrint("Guild login greeting gated:", why)
            if self:IsTestMode() then self:TestPrint("Guild login greeting blocked: " .. why) end
            return
        end
    end

    -- Get random login greeting
    local message = self:GetRandomGuildLoginGreeting()
    if not message then
        self:DebugPrint("No login greetings enabled for GUILD")
        return
    end

    -- Replace {name} placeholder with member name(s)
    local nameStr = table.concat(names, ", ")
    message = message:gsub("{name}", nameStr)

    self.state.lastGuildLoginGreetTime = now
    -- Reserve the budget slot before the delay timer, now that a message is certain to go out
    if self.socialGate then
        self.socialGate:Record("greeting", names and names[1] or nil)
    end
    -- Send directly, bypassing global cooldown (member login has its own cooldown above)
    local delay = db.messageDelay
    if delay and delay > 0 then
        self:ScheduleTimer(function()
            self:DoSendMessage(message, "GUILD")
        end, delay)
    else
        self:DoSendMessage(message, "GUILD")
    end
end

-- Get random guild login greeting from enabled pool
function Addon:GetRandomGuildLoginGreeting()
    local settings = self.db.profile.guild
    local enabled = {}

    -- Add enabled preset messages
    if settings.enabledLoginGreetings then
        for _, msg in ipairs(AutoSay.GuildLoginGreetings) do
            if settings.enabledLoginGreetings[msg.key] then
                table.insert(enabled, msg.text)
            end
        end
    end

    -- Add enabled custom messages
    if settings.customLoginGreetings then
        for _, entry in ipairs(settings.customLoginGreetings) do
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

-- Resolve dungeon name: English by default, client locale if useClientLanguage is enabled.
-- @param mapID number|nil - mapChallengeModeID
-- @param fallbackName string|nil - localized name from API (used as fallback or when useClientLanguage is on)
function Addon:GetDungeonName(mapID, fallbackName)
    local useClient = self.db and self.db.profile.mythicplus.useClientLanguage
    if useClient then
        return fallbackName or AutoSay.DungeonNames[mapID] or "Unknown"
    end
    if mapID and AutoSay.DungeonNames[mapID] then
        return AutoSay.DungeonNames[mapID]
    end
    return fallbackName or "Unknown"
end

-- Resolve mapChallengeModeID from an LFG activityID
function Addon:GetMapIDFromActivity(activityID)
    return activityID and AutoSay.ActivityToDungeon[activityID] or nil
end

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
    -- M+ messages go straight to SendChatMessage, so apply the shared polish here.
    -- keepCase: dungeon names are proper nouns, "Ruby Life Pools" must not become "ruby ...".
    return self:PolishMessage(message, true)
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

    -- One announce in flight: a retry is already carrying this group's message
    if self.state.keyAnnounceTimer then
        self:DebugPrint("Key announce retry already pending, skipping")
        return
    end

    local listing = self.state.cachedLFGListing
    if not listing or not listing.dungeonName then
        self:DebugPrint("SendKeyAnnounce: no cached listing data")
        return
    end

    -- Resolve dungeon name (English by default, client locale if enabled)
    local localizedName = listing.dungeonName and listing.dungeonName:gsub(" %(Mythic Keystone%)", "")
    local mapID = self:GetMapIDFromActivity(listing.activityID)
    local dungeon = self:GetDungeonName(mapID, localizedName)

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

    -- Share the group cooldown with greetings: an announce landing in the same second as
    -- the greeting reads like a bot. One retry when the cooldown is still running, then drop.
    -- keepCase so the second polish inside DoSendMessage keeps the dungeon name capitalized.
    if self:SendMessageToChat(message, channel, nil, true) then
        self.state.keyAnnounceRetried = false
        return
    end

    if self.state.keyAnnounceRetried then
        self:DebugPrint("Key announce still cooldown-blocked after the retry, dropping")
        return
    end

    self.state.keyAnnounceRetried = true
    local remaining = self.db.profile.cooldown - (GetTime() - self.state.lastGroupMessageTime)
    local wait = math.max(remaining, 0) + (self.db.profile.messageDelay or 0) + 0.5
    self:DebugPrint("Key announce cooldown-blocked, retrying in", string.format("%.1f", wait) .. "s")
    -- Resend the very message we built, not a fresh roll, and only while the announce
    -- this retry belongs to is still valid (same full group, flag not reset meanwhile)
    self.state.keyAnnounceTimer = self:ScheduleTimer(function()
        self.state.keyAnnounceTimer = nil
        if not self.state.keyAnnounced or GetNumGroupMembers() ~= 5 then
            self:DebugPrint("Key announce retry no longer valid, dropping")
            return
        end
        self:SendMessageToChat(message, channel, nil, true)
    end, wait)
end

-- Get a random completion message from enabled pool
function Addon:GetRandomCompletionMessage(onTime, upgrade)
    local settings = self.db.profile.mythicplus
    local enabled = {}

    local presetDB = onTime and AutoSay.CompletionTimed or AutoSay.CompletionDepleted
    local enabledPresets = onTime and settings.enabledCompletionTimed or settings.enabledCompletionDepleted
    local customMessages = onTime and settings.customCompletionTimed or settings.customCompletionDepleted

    -- "+0 upgrade, nice!" is nonsense: drop upgrade phrases when the key did not go up
    local hasUpgrade = (tonumber(upgrade) or 0) >= 1
    local function usable(text)
        return hasUpgrade or not text:find("{upgrade}", 1, true)
    end

    -- Add enabled preset messages
    if enabledPresets then
        for _, msg in ipairs(presetDB) do
            if enabledPresets[msg.key] and usable(msg.text) then
                table.insert(enabled, msg.text)
            end
        end
    end

    -- Add enabled custom messages
    if customMessages then
        for _, entry in ipairs(customMessages) do
            if entry.enabled and entry.text and entry.text ~= "" and usable(entry.text) then
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

    local template = self:GetRandomCompletionMessage(onTime, upgrade)
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

    -- Always party in M+ dungeon. Routed through the normal pipeline for truncation,
    -- cooldown and test mode; keepCase keeps the dungeon name capitalized.
    local channel = "PARTY"
    if not self:SendMessageToChat(message, channel, nil, true) then
        -- A completion line that lands half a minute late is noise, so no retry
        self:DebugPrint("Completion message dropped (cooldown or addon disabled)")
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
    self.state.lastGuildLoginGreetTime = 0
    self.state.pendingNewMembers = {}
    self.state.pendingGuildLogins = {}
    if self.state.guildLoginTimer then
        self:CancelTimer(self.state.guildLoginTimer)
        self.state.guildLoginTimer = nil
    end
    if self.state.pendingGreetTimer then
        self:CancelTimer(self.state.pendingGreetTimer)
        self.state.pendingGreetTimer = nil
    end
    self.state.cachedLFGListing = nil
    self.state.keyAnnounced = false
    self.state.keyAnnounceRetried = false
    if self.state.keyAnnounceTimer then
        self:CancelTimer(self.state.keyAnnounceTimer)
        self.state.keyAnnounceTimer = nil
    end
    self:SetInstanceGreeted(false)
    self.state.mythicPlusFlowActive = false
    self.state.goodbyeSent = false
    self.state.groupGoodbyeSent = false
    self.state.guildMemberPresence = {}
    self.state.guildPresenceReady = true -- In test mode, always ready
    -- Clear session-only social state (persistent budget/person state intentionally kept, matches live behavior)
    if self.socialGate then
        self.socialGate.pending = {}
    end
    if self.humanizer then
        self.humanizer.history = {}
    end
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

-- Simulate zoning into an instance group (LFG dungeon/LFR/battleground)
function Addon:TestJoinInstance()
    if not self:IsTestMode() then
        self:Print("|cFFFF0000Test mode is not enabled!|r Use /as testmode or enable in settings.")
        return
    end

    self:TestPrint("=== Simulating ENTER INSTANCE GROUP ===")
    self.testState.simulatedGroupType = "INSTANCE_CHAT"
    self.state.previousGroup = { [UnitName("player")] = true }
    self.state.sentGreetings = {}
    self.state.currentGroupType = "INSTANCE_CHAT"
    self:SetInstanceGreeted(false)

    -- Trigger the greeting logic (mirrors the PLAYER_ENTERING_WORLD zone-in path)
    if self.db.profile.enabled and self:ShouldGreetOnSelfJoin("INSTANCE_CHAT") then
        if self:SendGreeting(nil, "self_join") then
            self:SetInstanceGreeted(true)
        end
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
    self:SetInstanceGreeted(false)
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

-- Simulate guild member login
function Addon:TestGuildMemberLogin(playerName)
    if not self:IsTestMode() then
        self:Print("|cFFFF0000Test mode is not enabled!|r Use /as testmode or enable in settings.")
        return
    end

    local testNames = { "Thrall", "Jaina", "Sylvanas", "Anduin", "Tyrande", "Velen", "Baine", "Lor'themar" }
    local name = playerName or testNames[math.random(#testNames)]

    self:TestPrint("=== Simulating GUILD MEMBER LOGIN: " .. name .. " ===")
    self.testState.simulatedInGuild = true
    self:HandleGuildMemberLogin(name)
    -- Note: simulatedInGuild stays true until the batched timer fires
    -- Schedule cleanup after the batch window
    self:ScheduleTimer(function()
        self.testState.simulatedInGuild = false
    end, 4)
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

    -- Randomize dungeon (Midnight Season 1 pool with activityIDs)
    local dungeons = {
        { name = "Magisters' Terrace",        activityID = 1760, mapID = 558 },
        { name = "Maisara Caverns",           activityID = 1764, mapID = 560 },
        { name = "Nexus-Point Xenas",         activityID = 1768, mapID = 559 },
        { name = "Windrunner Spire",          activityID = 1542, mapID = 557 },
        { name = "Algeth'ar Academy",         activityID = 1160, mapID = 402 },
        { name = "Seat of the Triumvirate",   activityID = 486,  mapID = 583 },
        { name = "Skyreach",                  activityID = 182,  mapID = 161 },
        { name = "Pit of Saron",              activityID = 1770, mapID = 556 },
    }
    local picked = dungeons[math.random(#dungeons)]
    local keyLevel = math.random(4, 15)
    local dungeon = self:GetDungeonName(picked.mapID, picked.name)

    if isLeader then
        -- Leader: has LFG listing cached
        self.state.cachedLFGListing = {
            activityID = picked.activityID,
            title = "+" .. keyLevel,
            dungeonName = picked.name .. " (Mythic Keystone)",
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
        { name = "Magisters' Terrace",        mapID = 558 },
        { name = "Maisara Caverns",           mapID = 560 },
        { name = "Nexus-Point Xenas",         mapID = 559 },
        { name = "Windrunner Spire",          mapID = 557 },
        { name = "Algeth'ar Academy",         mapID = 402 },
        { name = "Seat of the Triumvirate",   mapID = 583 },
        { name = "Skyreach",                  mapID = 161 },
        { name = "Pit of Saron",              mapID = 556 },
    }
    local picked = dungeons[math.random(#dungeons)]
    local dungeon = self:GetDungeonName(picked.mapID, picked.name)
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
        { name = "Magisters' Terrace",        mapID = 558 },
        { name = "Maisara Caverns",           mapID = 560 },
        { name = "Nexus-Point Xenas",         mapID = 559 },
        { name = "Windrunner Spire",          mapID = 557 },
        { name = "Algeth'ar Academy",         mapID = 402 },
        { name = "Seat of the Triumvirate",   mapID = 583 },
        { name = "Skyreach",                  mapID = 161 },
        { name = "Pit of Saron",              mapID = 556 },
    }
    local picked = dungeons[math.random(#dungeons)]
    local dungeon = self:GetDungeonName(picked.mapID, picked.name)
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

    -- Humanizer pick history status
    if self.humanizer and self.humanizer.history then
        local poolCount = 0
        for _ in pairs(self.humanizer.history) do poolCount = poolCount + 1 end
        self:Print("Humanizer history pools:", "|cFFFFFF00" .. poolCount .. "|r")
    end

    -- Show channel status
    local db = self.db.profile
    local function YesNo(v) return v and "|cFF00FF00Yes|r" or "|cFFFF0000No|r" end
    for _, c in ipairs(AutoSay.Channels) do
        local s = db[c.key]
        if c.key ~= "guild" then
            self:Print(L[c.chat] .. ":", s.enabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r",
                "| Self:", YesNo(s.onSelfJoin),
                "| Others:", YesNo(s.onOthersJoin),
                "| Names:", YesNo(s.includeNames),
                "| Bye:", YesNo(s.sendGoodbye))
        end
    end
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

    -- Social gate status (read-only; never mutates gate state)
    if self.socialGate then
        local now = time()
        local social = self.db.char.social or {}
        local settings = self.db.profile.social or {}
        local hourAgo = now - 3600

        local sends = social.sends or {}
        local budgetUsed = 0
        for _, ts in ipairs(sends) do
            if ts > hourAgo then budgetUsed = budgetUsed + 1 end
        end
        self:Print("Social gate:")
        self:Print("  Budget:", "|cFFFFFF00" .. budgetUsed .. "/" .. (settings.budgetPerHour or 0) .. "|r", "used this hour")

        local welcomeSends = social.welcomeSends or {}
        local welcomeUsed = 0
        for _, ts in ipairs(welcomeSends) do
            if ts > hourAgo then welcomeUsed = welcomeUsed + 1 end
        end
        self:Print("  Welcomes:", "|cFFFFFF00" .. welcomeUsed .. "/2|r", "used this hour")

        local personCooldown = (settings.personCooldownHours or 0) * 3600
        local perPerson = social.perPerson or {}
        local onCooldown = 0
        for _, ts in pairs(perPerson) do
            if now - ts < personCooldown then onCooldown = onCooldown + 1 end
        end
        self:Print("  Per-person cooldown:", "|cFFFFFF00" .. onCooldown .. "|r", "player(s)")

        local welcomed = social.welcomed or {}
        local welcomedCount = 0
        for _ in pairs(welcomed) do welcomedCount = welcomedCount + 1 end
        self:Print("  Welcomed (ever):", "|cFFFFFF00" .. welcomedCount .. "|r", "player(s)")

        local pendingCount = 0
        for _ in pairs(self.socialGate.pending or {}) do pendingCount = pendingCount + 1 end
        self:Print("  Pending replies:", "|cFFFFFF00" .. pendingCount .. "|r")
    end
end
