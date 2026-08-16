local ADDON_NAME, AutoSay = ...

-- Create addon using Ace3
local Addon = LibStub("AceAddon-3.0"):NewAddon(AutoSay, ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

-- Version (replaced by packager with git tag)
Addon.version = "@project-version@"

-- Pure string/table logic lives in MessageLogic.lua (headless-testable); alias what this file uses
local Logic = AutoSay.MessageLogic
local TruncateToChatLimit = Logic.TruncateToChatLimit
local FitsContext = Logic.FitsContext
local StripNameSlot = Logic.StripNameSlot
local NameMode = Logic.NameMode
local SameKey = Logic.SameKey
local StyleFits = Logic.StyleFits

-- Debug print helper
function Addon:DebugPrint(...)
    if self.db and self.db.profile.debugMode and self.db.profile.testMode then
        print("|cFF00FF00[AutoSay Debug]|r", ...)
    end
    -- The session log records the same narration, whether or not anyone is watching chat:
    -- one call site to keep in sync instead of a second set sprinkled through the addon
    if self.LogLine then self:LogLine(...) end
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

-- Gate for every test command: off means say so once, here, and let the caller bail
function Addon:RequireTestMode()
    if self:IsTestMode() then return true end
    self:Print(L["Test mode required"])
    return false
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
    yo = false,
    sup = false,
    howdy = false,
    welcomenames = false,
    hinames = false,
    welcomeaboard = false,
    -- Role phrases: enabled, silent until the Style tab master switch is on (same deal as
    -- the time-of-day set). Styled role phrases stay off, like every other styled phrase
    classic_tank1 = true,
    classic_tank2 = true,
    classic_heal1 = true,
    classic_heal2 = true,
    classic_dps1 = true,
    classic_dps2 = true,
    -- Time-of-day phrases: enabled, but silent until the Style tab master switch is on.
    -- The switch is the feature; the phrases under it are ready so one click is enough
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

-- Band goodbyes shipped disabled before this release, so an upgrade never had them
local BAND_GOODBYE_KEYS = { "eveningbye", "gnall", "goodnightall", "sleepwell" }

-- Arriving and welcoming are separate lists in the profile, built from the same authored
-- defaults: an untagged phrase is offered on both occasions, a tagged one only on its own.
local function GreetingDefaultsFor(side)
    local t = {}
    for _, msg in ipairs(AutoSay.Greetings) do
        if defaultGreetings[msg.key] ~= nil and Logic.PhraseInPool(msg, { side = side }) then
            t[msg.key] = defaultGreetings[msg.key]
        end
    end
    return t
end
local defaultGreetingsSelf = GreetingDefaultsFor("self")
local defaultGreetingsOthers = GreetingDefaultsFor("others")

-- Default enabled goodbyes
local defaultGoodbyes = {
    bye = true,
    goodbye = true,
    gtg = true,
    takecare = true,
    peace = true,
    -- Disabled by default
    later = false,
    cya = false,
    cheers = false,
    gn = false,
    -- Time-of-day phrases: enabled like the band greetings, and silent until the Style tab
    -- master switch is on. An upgrader who muted every goodbye and never touched that
    -- switch stays muted; flipping it on is what opts them back in
    eveningbye = true,
    gnall = true,
    goodnightall = true,
    sleepwell = true,
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
    backinthegame = false,
    sorrydisconnect = false,
    mybad = false,
    internetissues = false,
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
        masterSwitchesMigrated = false, -- Time-of-day switch carried over from 1.5.x (see MigrateMasterSwitches)
        retiredPhrasesMigrated = 0, -- Version of the last retired-phrase pass (see RETIRED_PHRASES_VERSION)

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
            sendGoodbyeOnRunEnd = false, -- Also say goodbye the moment the dungeon or key ends
            enabledGreetingsSelf = DeepCopy(defaultGreetingsSelf),
            enabledGreetingsOthers = DeepCopy(defaultGreetingsOthers),
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
            sendGoodbyeOnRunEnd = false,
            enabledGreetingsSelf = DeepCopy(defaultGreetingsSelf),
            enabledGreetingsOthers = DeepCopy(defaultGreetingsOthers),
            enabledGoodbyes = DeepCopy(defaultGoodbyes),
            enabledReconnects = DeepCopy(defaultReconnects),
            customGreetings = {},
            customGoodbyes = {},
            customReconnects = {},
        },

        -- Instance group settings (LFG dungeons/LFR/battlegrounds, INSTANCE_CHAT)
        instance = {
            enabled = true,
            skipRaidGroups = true,      -- Stay silent in LFR and battlegrounds (see SkipsRaidInstanceGroup)
            onSelfJoin = true,          -- Greet once after zoning into the instance
            onOthersJoin = false,
            onOthersJoinLeaderOnly = false,
            includeNames = false,
            includeGroupNames = false,
            sendGoodbye = true,
            sendGoodbyeOnRunEnd = false,
            enabledGreetingsSelf = DeepCopy(defaultGreetingsSelf),
            enabledGreetingsOthers = DeepCopy(defaultGreetingsOthers),
            enabledGoodbyes = DeepCopy(defaultGoodbyes),
            customGreetings = {},
            customGoodbyes = {},
        },

        -- Mythic+ settings
        mythicplus = {
            enabled = true,
            announceOnFull = true,      -- Announce when group fills 5/5
            announceOnStart = true,     -- Announce the inserted keystone when the run starts
            includeKeyLevel = false,    -- Put the key level in the announce when it is known for sure
            keyLevelMigrated = false,   -- messageMode folded into includeKeyLevel (see MigrateKeyLevelMode)
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
            enabledGreetingsSelf = DeepCopy(defaultGreetingsSelf),
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
            -- Both off by default: they change what the addon says about YOU (your role,
            -- your local hour), so they are opt-in. The phrases under them ship enabled,
            -- so ticking the switch is all it takes
            timeOfDay = false,
            rolePhrases = false, -- Master switch for role-tagged and {role} phrases
            lowercaseFirst = false,
            guildGrats = false,
            guildWelcome = false,
        },
    },

    global = {
        -- "major.minor" of the last release whose What's new popup was dismissed.
        -- Account-wide on purpose: the news is the same on every character.
        whatsNewSeen = "",
        -- Session log (see Log.lua). Account-wide as well: a session spans characters,
        -- and the recording must survive a /reload to be worth anything.
        log = { recording = false, entries = {} },
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
    groupGoodbyeSent = {}, -- Per-channel once-per-leave goodbye guard (channel -> bool)
    pendingNewMembers = {}, -- Batch new members for others_join greeting
    pendingGreetTimer = nil, -- Timer for batched greeting
    cachedLFGListing = nil, -- Cached LFG listing data (before auto-delist)
    keyAnnounced = false, -- Prevent duplicate M+ key announcements per group
    keyAnnounceRetried = false, -- Key announce was already re-scheduled once for the cooldown
    keyAnnounceTimer = nil, -- Pending key announce retry timer (one in flight at a time)
    announcedKey = nil, -- What the last key announce actually said: { mapID = number|nil, dungeon = string, level = number|nil }
    startAnnounced = false, -- Key start announce already sent for the current run
    startAnnounceTimer = nil, -- Pending key start announce (initial delay or its one retry)
    groupGoodbyeTimer = {}, -- Per-channel self-reset timers for the goodbye guard
    instanceGreeted = false, -- Instance zone-in greeting sent (mirrors db.char.instanceGreeted, see SetInstanceGreeted)
    runEndGoodbyeSent = false, -- Run-end goodbye already said for the current dungeon or key
    pendingGroupSends = {}, -- Delayed group sends in flight (handle -> channel), cancelled on GROUP_JOINED
    sendGeneration = 0, -- Bumped on every test-mode toggle: delayed sends from the other mode drop
    testFlowGeneration = 0, -- Bumped when a simulation is replaced: the previous flow's own timers drop
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
    simulatedRaidInstance = false, -- Simulated instance group is raid-sized (LFR/battleground)
    simulatedInGuild = false,
    simulatedGroupMembers = {},
    simulatedIsLeader = true, -- Simulate being group leader (default true for test)
    simulatedRole = "DAMAGER", -- Role used for role-tagged phrases while testing
    simulatedHour = nil, -- Hour (0-23) used for time-of-day band while testing; nil = use real time
    mythicPlusRole = "leader", -- "leader" or "joined" for M+ flow simulation
}

function Addon:OnInitialize()
    -- Snapshot taken before AceDB fills the store with defaults: afterwards an explicit
    -- "off" from 1.5.x is indistinguishable from the new default of the same value, and
    -- the profile this character uses is only known once the database exists
    local priorProfiles, priorTimeOfDay, priorBandGoodbyes = {}, {}, {}
    if AutoSayDB and AutoSayDB.profiles then
        for name, stored in pairs(AutoSayDB.profiles) do
            if type(stored) ~= "table" then stored = {} end
            priorProfiles[name] = true
            priorTimeOfDay[name] = type(stored.social) == "table" and stored.social.timeOfDay or nil
            local ticked = {}
            for _, channel in ipairs(AutoSay.Channels) do
                local settings = stored[channel.key]
                local goodbyes = type(settings) == "table" and type(settings.enabledGoodbyes) == "table"
                    and settings.enabledGoodbyes or nil
                if goodbyes then
                    for _, key in ipairs(BAND_GOODBYE_KEYS) do
                        if goodbyes[key] then ticked[channel.key .. ":" .. key] = true end
                    end
                end
            end
            priorBandGoodbyes[name] = ticked
        end
    end
    self.priorProfiles = priorProfiles
    self.priorTimeOfDay = priorTimeOfDay
    self.priorBandGoodbyes = priorBandGoodbyes

    -- Initialize database
    self.db = LibStub("AceDB-3.0"):New("AutoSayDB", defaults, true)

    -- Every migration is one-shot per profile, so re-running them when the active profile
    -- changes is what makes a profile switched to later behave like one loaded at login.
    -- Without this a legacy profile picked mid-session keeps a selection this build no
    -- longer ships, and an Instance channel that never inherited its Party settings.
    for _, event in ipairs({ "OnProfileChanged", "OnProfileCopied", "OnProfileReset" }) do
        self.db.RegisterCallback(self, event, "OnProfileSwitched")
    end
    -- A name freed by a deletion belongs to nobody: whoever takes it next is a new profile,
    -- not the one that predated this build
    self.db.RegisterCallback(self, "OnProfileDeleted", "OnProfileDeleted")

    self:RunProfileMigrations()

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
-- skipRaidGroups is what keeps an upgrade out of LFR and battlegrounds; 1.5.x had no such
-- guard, so the channel inheriting the party toggles is only safe alongside it.
-- Every profile is migrated as it becomes active: the AceDB profile callbacks re-run this
-- for a profile switched to later, so it is treated exactly like one loaded at login.
function Addon:MigrateInstanceChannel()
    if Logic.MigrateInstanceChannel(self.db.profile) then
        self:DebugPrint("Instance channel seeded from party settings")
    end
end

-- Phrases do get retired between versions. Someone whose whole selection was retired would
-- otherwise go quiet on that channel with no hint why, so a pool left with nothing to say
-- gets the stock set back. Only pools that are actually empty are touched.
-- Bumped whenever a release retires phrases, so that release gets its own pass instead of
-- finding the flag an earlier one left behind
local RETIRED_PHRASES_VERSION = 2

local RETIRED_POOLS = {
    { messages = "Greetings", enabledKey = "enabledGreetingsSelf", customsKey = "customGreetings",
      side = "self" },
    { messages = "Greetings", enabledKey = "enabledGreetingsOthers", customsKey = "customGreetings",
      side = "others" },
    { messages = "Goodbyes", enabledKey = "enabledGoodbyes", customsKey = "customGoodbyes" },
    { messages = "Reconnects", enabledKey = "enabledReconnects", customsKey = "customReconnects" },
}

-- The M+ pools live once under db.profile.mythicplus rather than per channel
local RETIRED_MPLUS_POOLS = {
    { messages = "KeyAnnounce", enabledKey = "enabledKeyAnnounce", customsKey = "customKeyAnnounce" },
    { messages = "CompletionTimed", enabledKey = "enabledCompletionTimed", customsKey = "customCompletionTimed" },
    { messages = "CompletionDepleted", enabledKey = "enabledCompletionDepleted", customsKey = "customCompletionDepleted" },
}

function Addon:MigrateRetiredPhrases()
    local profile = self.db.profile
    if profile.retiredPhrasesMigrated == RETIRED_PHRASES_VERSION then return end
    profile.retiredPhrasesMigrated = RETIRED_PHRASES_VERSION
    if not self.priorProfiles[self.db:GetCurrentProfile()] then return end

    local defaults = {
        enabledGreetingsSelf = defaultGreetingsSelf,
        enabledGreetingsOthers = defaultGreetingsOthers,
        enabledGoodbyes = defaultGoodbyes,
        enabledReconnects = defaultReconnects,
        enabledKeyAnnounce = defaultKeyAnnounce,
        enabledCompletionTimed = defaultCompletionTimed,
        enabledCompletionDepleted = defaultCompletionDepleted,
    }
    local targets = {}
    for _, channel in ipairs(AutoSay.Channels) do
        targets[#targets + 1] = { settings = profile[channel.key], pools = RETIRED_POOLS, label = channel.key }
    end
    targets[#targets + 1] = { settings = profile.mythicplus, pools = RETIRED_MPLUS_POOLS, label = "mythicplus" }

    for _, target in ipairs(targets) do
        local settings = target.settings
        for _, pool in ipairs(target.pools) do
            local enabled = settings and settings[pool.enabledKey]
            if enabled then
                local live = {}
                for _, msg in ipairs(AutoSay[pool.messages]) do
                  if Logic.PhraseInPool(msg, pool) then
                    -- false rather than true for anything a master switch holds back: it is
                    -- still shipped, so it is no evidence of a retirement, but it cannot
                    -- carry the pool either. Both switches ship off and both sets of phrases
                    -- ship enabled, so counting them as content hid every empty pool.
                    live[msg.key] = msg.band == nil and msg.role == nil
                        and not msg.text:find("{role}", 1, true)
                  end
                end
                if Logic.PoolLostItsPhrases(enabled, live, settings[pool.customsKey]) then
                    for key in pairs(enabled) do
                        if not live[key] then enabled[key] = nil end
                    end
                    for key, on in pairs(defaults[pool.enabledKey]) do enabled[key] = on end
                    self:DebugPrint("Restored stock", pool.messages, "for", target.label)
                end
            end
        end
    end
end

function Addon:OnProfileDeleted(_, _, name)
    if name then
        self.priorProfiles[name] = nil
        self.priorTimeOfDay[name] = nil
        self.priorBandGoodbyes[name] = nil
    end
end

function Addon:OnProfileSwitched(event)
    -- Rotation is per pool, not per profile: without this, phrases spent under the profile
    -- you left stay spent under the one you arrived at
    if self.humanizer then self.humanizer.rounds = {} end
    if event == "OnProfileCopied" then
        -- The copy carries the source's stored tables, so the structural conversions still
        -- have real work to do. Only the snapshot-dependent ones are stamped: their evidence
        -- is keyed by profile name, and the name here belongs to the destination.
        self:MigrateCustomMessages()
        self:MigrateGreetingSides()
        self:MigrateInstanceChannel()
        self:MigrateKeyLevelMode()
        local profile = self.db.profile
        profile.masterSwitchesMigrated = true
        profile.retiredPhrasesMigrated = RETIRED_PHRASES_VERSION
        LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
        return
    end
    if event == "OnProfileReset" then
        -- A reset asks for the defaults, and the defaults are already what every migration
        -- would produce. Running them would only move the profile off them again.
        self:StampMigrationsDone()
    else
        self:RunProfileMigrations()
    end
    LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay") -- the open panel shows the old profile
end

function Addon:RunProfileMigrations()
    -- Migrate old single custom message format to new array format
    self:MigrateCustomMessages()

    -- One greeting list becomes two, before anything else reads either of them
    self:MigrateGreetingSides()

    -- Seed the instance channel from the party settings on the first run after the upgrade
    self:MigrateInstanceChannel()

    -- Fold the old three-way M+ messageMode into the includeKeyLevel toggle
    self:MigrateKeyLevelMode()

    -- Restore first, suppress second: the stock set includes the band goodbyes, so running
    -- it after the master-switch migration would undo that migration's suppression
    self:MigrateRetiredPhrases()

    -- Keep the time-of-day phrases an upgrade already had
    self:MigrateMasterSwitches()
end

-- Arriving and welcoming used to share one list of ticks and tell themselves apart by a tag
-- on the phrase. Each occasion owns its own list now, so the stored one is dealt into both:
-- every phrase keeps the state it had, on the occasions it can actually serve.
-- The stored choices land on top of whatever the defaults already put in the list
local function ApplySelection(settings, key, values)
    local target = settings[key]
    if type(target) ~= "table" then
        settings[key] = values
        return
    end
    for phrase, state in pairs(values) do target[phrase] = state end
end

function Addon:MigrateGreetingSides()
    local profile = self.db.profile
    -- Not "have we run before" but "is there anything left to convert": a profile copied
    -- from one that never became active under this build arrives stamped and unconverted,
    -- and its owner's whole selection would otherwise be ignored.
    local pending = false
    for _, channel in ipairs(AutoSay.Channels) do
        local settings = profile[channel.key]
        if settings and type(settings.enabledGreetings) == "table" then pending = true end
    end
    if not pending then
        profile.greetingSidesMigrated = true
        return
    end

    for _, channel in ipairs(AutoSay.Channels) do
        local settings = profile[channel.key]
        local stored = settings and settings.enabledGreetings
        if stored then
            local selfSide, others = Logic.SplitGreetingSelection(stored, AutoSay.Greetings)
            -- Written over the defaults, never in place of them. AceDB stores only what
            -- differs from a default and copies the rest back in at load, so the stored list
            -- holds the player's changes alone. Replacing the table with it would drop every
            -- phrase they never touched, which is most of them.
            ApplySelection(settings, "enabledGreetingsSelf", selfSide)
            -- The guild never welcomes anyone through this list: its arrivals have their own
            if channel.key ~= "guild" then
                ApplySelection(settings, "enabledGreetingsOthers", others)
            end
            settings.enabledGreetings = nil
            self:DebugPrint("Split the greeting selection for", channel.key)
        end
    end

    -- Last, so a raise anywhere above leaves the work to be retried rather than skipped
    profile.greetingSidesMigrated = true
end

-- Everything the migrations would have done is already true of a freshly reset profile,
-- so they only need marking as done - running them would move it off the defaults.
function Addon:StampMigrationsDone()
    local profile = self.db.profile
    profile.greetingSidesMigrated = true
    profile.instanceMigrated = true
    profile.masterSwitchesMigrated = true
    profile.retiredPhrasesMigrated = RETIRED_PHRASES_VERSION
    if profile.mythicplus then profile.mythicplus.keyLevelMigrated = true end
end

-- The master switches are new, and they ship off. 1.5.x had no switch and spoke its
-- time-of-day phrases for everyone, so defaulting an upgrade to off would read as "the
-- morning greetings broke", not as a setting. Roles are genuinely new, so they stay off.
function Addon:MigrateMasterSwitches()
    local profile = self.db.profile
    if profile.masterSwitchesMigrated then return end
    profile.masterSwitchesMigrated = true
    -- Only a profile that existed before this build can have lost anything. One created or
    -- copied afterwards already holds whatever it was given, and treating it as an upgrade
    -- would switch a feature on that its owner never had.
    local name = self.db:GetCurrentProfile()
    if not self.priorProfiles[name] then return end
    -- A stored false is someone who turned the phrases off back when the switch defaulted
    -- to on; turning them back on would undo a decision made by hand.
    if self.priorTimeOfDay[name] == nil then
        profile.social.timeOfDay = true
        -- Only the greetings existed before. Band goodbyes are new, and switching the
        -- master on for an upgrade must not start saying "gn all" on their behalf
        local ticked = self.priorBandGoodbyes[name] or {}
        for _, key in ipairs(BAND_GOODBYE_KEYS) do
            for _, channel in ipairs(AutoSay.Channels) do
                local settings = profile[channel.key]
                -- Leave alone anything the profile itself had ticked: only the values this
                -- build handed out are being taken back
                if settings and settings.enabledGoodbyes
                    and not ticked[channel.key .. ":" .. key] then
                    settings.enabledGoodbyes[key] = false
                end
            end
        end
        self:DebugPrint("Kept time-of-day phrases on for an upgraded profile")
    end
end

function Addon:MigrateKeyLevelMode()
    if Logic.MigrateKeyLevelMode(self.db.profile.mythicplus) then
        self:DebugPrint("Key level mode migrated - includeKeyLevel = true")
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

    -- Presence heartbeat: PLAYER_LOGOUT never fires on a hard disconnect, so the reconnect
    -- detection also compares against this once-a-minute timestamp. (SavedVariables only
    -- flush on logout/reload, so this covers a DC followed by a normal client exit - a hard
    -- client crash loses the writes and is out of reach.)
    -- OnEnable runs at PLAYER_LOGIN, BEFORE the login classification in
    -- PLAYER_ENTERING_WORLD reads this value - so the previous session's timestamp is
    -- snapshotted first, or every login would look like a reconnect and the guild
    -- greeting would never fire again. The immediate stamp then covers a DC inside the
    -- first minute of this session.
    self.state.lastSeenBeforeLogin = self.db.char.lastSeenTime or 0
    self.db.char.lastSeenTime = time()
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
    -- No notes written for this release: nothing to show, and nothing worth a combat retry
    if not self:HasWhatsNew(minor) then return end

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
    self.state.groupGoodbyeSent = {}

    -- Hook C_PartyInfo.LeaveParty (retail WoW API) - use RawHook to run BEFORE the function.
    -- Known limitation: rare confirmation flows (Party Sync's LEAVE_PARTY_CONFIRMATION) can
    -- cancel the leave AFTER the goodbye already went out - a stray "bye" while staying
    -- grouped. Deferring to ConfirmLeaveParty would miss every normal leave, so the common
    -- case wins.
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
    -- Nil category means the HOME group in Blizzard's own UI: the raid manager offers
    -- "Leave Group" (bare C_PartyInfo.LeaveParty()) right next to a separate "Leave
    -- Instance Group" button (Blizzard_CompactRaidFrameManager.lua:1311, .xml:386), and
    -- instance departures always pass LE_PARTY_CATEGORY_INSTANCE explicitly. The generated
    -- API docs give LeaveParty's nilable category NO documented default, so the call sites
    -- are the ground truth here.
    if IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return IsInRaid(LE_PARTY_CATEGORY_HOME) and "RAID" or "PARTY"
    end
    -- No home group: resolve live (we are still in the group at this point) so LFG groups
    -- pick up the instance settings; cached type is the fallback if the API dropped us
    return self:GetChatChannel() or self.state.currentGroupType
end

-- Send group goodbye only once per leave action. The guard is keyed by the resolved
-- channel: leaving the instance group and the home party back to back are two different
-- goodbyes, and one shared boolean would swallow the second.
function Addon:SendGroupGoodbyeOnce(category)
    local channel = self:GoodbyeChannelForCategory(category)
    if not channel then
        self:DebugPrint("No current group type cached, skipping goodbye")
        return
    end

    if self.state.groupGoodbyeSent[channel] then
        self:DebugPrint("Group goodbye already sent to", channel, ", skipping")
        return
    end

    -- The guard is set only when a goodbye actually went out (SendGoodbye is synchronous):
    -- a bail-out - empty pool, gate, message that polishes to nothing - must not consume
    -- the once-per-leave slot. A double LeaveParty still cannot double-send: the first
    -- successful send sets the flag before the second hook can run.
    self:DebugPrint("Sending goodbye to", channel, "before leaving")
    if self:SendGoodbye(channel) then
        self.state.groupGoodbyeSent[channel] = true
    end

    -- GROUP_LEFT deliberately does not clear the flag (it fires milliseconds after this
    -- hook) - so the guard resets itself. 5s covers a double LeaveParty, nothing longer.
    if self.state.groupGoodbyeTimer[channel] then
        self:CancelTimer(self.state.groupGoodbyeTimer[channel])
    end
    self.state.groupGoodbyeTimer[channel] = self:ScheduleTimer(function()
        self.state.groupGoodbyeTimer[channel] = nil
        self.state.groupGoodbyeSent[channel] = false
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
    elseif cmd == "testmode" then
        self.db.profile.testMode = not self.db.profile.testMode
        -- Invalidate every delayed send built under the previous mode: a simulated message
        -- still sitting in a typing delay must never reach real chat (and vice versa)
        self.state.sendGeneration = self.state.sendGeneration + 1
        if self.db.profile.testMode then
            self:Print("|cFFFF9900Test mode:|r |cFF00FF00ON|r - Messages will be printed, not sent")
            self:Print("Use |cFFFFFF00/as help|r to see test commands")
        else
            self:Print("|cFFFF9900Test mode:|r |cFFFF0000OFF|r")
            self:TestReset()
        end
    -- Test simulation commands. Gated as a whole: the inline subcommands below (grats,
    -- guildjoin, resetgate) reach real guild chat / wipe real gate state when test mode is
    -- off - the per-helper RequireTestMode calls do not cover them.
    elseif cmd == "test" then
        local subcmd = arg1 and arg1:lower() or ""
        -- Bare "/as test" may always show the command list; everything else needs test mode
        if subcmd ~= "" and not self:RequireTestMode() then return end
        if subcmd == "party" or subcmd == "p" then
            self:TestJoinParty()
        elseif subcmd == "raid" or subcmd == "r" then
            self:TestJoinRaid()
        elseif subcmd == "instance" or subcmd == "i" then
            self:TestJoinInstance()
        elseif subcmd == "lfr" or subcmd == "bg" then
            self:TestJoinInstance(true)
        elseif subcmd == "leave" or subcmd == "l" then
            self:TestLeaveGroup()
        elseif subcmd == "runend" then
            self:TestPrint("=== Simulating RUN END (dungeon or key finished) ===")
            -- The flag is what a real ending clears, so a second /as test runend in the
            -- same simulated group is meant to stay silent, exactly like the real one
            if not self:SendRunEndGoodbye(false) then
                self:TestPrint("Nothing sent: either this run already said goodbye, or "
                    .. "\"Send goodbye when the run ends\" is off for this channel")
            end
        elseif subcmd == "guild" or subcmd == "g" then
            self:TestGuildGreeting()
        elseif subcmd == "guildbye" or subcmd == "gb" then
            self:TestGuildGoodbye()
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
        elseif subcmd == "keystart" or subcmd == "ks" then
            self:TestKeyStart()
        elseif subcmd == "role" then
            local _, _, roleArg = self:GetArgs(input, 3)
            self:TestSetRole(roleArg)
        elseif subcmd == "hour" then
            local _, _, hourArg = self:GetArgs(input, 3)
            self:TestSetHour(hourArg)
        elseif subcmd == "whatsnew" then
            self:TestPreviewWhatsNew()
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
            self:Print("  /as testmode - Toggle simulation mode (required for the commands below)")
            self:Print("  /as test party - Simulate joining a party")
            self:Print("  /as test raid - Simulate joining a raid")
            self:Print("  /as test instance - Simulate zoning into a 5-player instance group")
            self:Print("  /as test lfr (or bg) - Simulate zoning into an LFR or battleground")
            self:Print("  /as test leave - Simulate leaving group")
            self:Print("  /as test runend - Simulate a dungeon or key finishing")
            self:Print("  /as test guild - Simulate guild login greeting")
            self:Print("  /as test guildbye - Simulate guild logout goodbye")
            self:Print("  /as test grats - Simulate guild achievement congrats")
            self:Print("  /as test guildjoin - Simulate a new member joining the guild")
            self:Print("  /as test reconnect - Simulate reconnecting to group")
            self:Print("  /as test player [name] - Simulate player joining")
            self:Print("  /as test key - Simulate full M+ flow (listing → joins → announce)")
            self:Print("  /as test keystart - Simulate the key start announce (duplicate and new key)")
            self:Print("  /as test role tank|healer|dps - Simulate assigned role")
            self:Print("  /as test hour <0-23>|off - Simulate time-of-day band")
            self:Print("  /as test whatsnew - Preview the What's new popup")
            self:Print("  /as test reset - Reset test state")
            self:Print("  /as test resetgate - Clear social gate counters (budget, cooldowns, welcomed list)")
            self:Print("  /as test status - Show test status")
        end
    elseif cmd == "log" then
        local sub = arg1 and arg1:lower() or ""
        if sub == "on" then
            self:StartLogging()
        elseif sub == "off" then
            self:StopLogging()
        elseif sub == "clear" then
            self:ClearLog()
        elseif sub == "" or sub == "show" then
            self:ShowLogWindow()
        else
            self:Print("Usage: /as log on | off | show | clear")
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
        self:Print("  /as log on|off|show|clear - Record what the addon does, then copy it out")
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

-- True when nothing may go out on this channel right now: the toggle means "say nothing in
-- an LFR or a battleground", so goodbyes and reconnects obey it as much as greetings.
-- Asked at preflight so a refused line burns no cooldown or budget, and again at dispatch -
-- goodbyes dispatch with no preflight at all, and a delayed send can outlive the group
-- state it was scheduled in.
function Addon:IsChannelSilenced(channel)
    if not Logic.SkipsRaidInstanceGroup(channel, self.db.profile.instance, self:IsRaidInstanceGroupOrTest()) then
        return false
    end
    self:DebugPrint("Raid-sized instance group, skipping message")
    if self:IsTestMode() then
        self:TestPrint("Message blocked: LFR and battlegrounds are skipped (General tab)")
    end
    return true
end

-- Check if cooldown has passed for a specific channel type
function Addon:CanSendMessage(channelType)
    if self:IsChannelSilenced(channelType) then return false end

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

-- Send a message to chat. Optional validate() runs again inside the typing delay - a send
-- whose precondition can expire (the key announce's 5/5) re-checks right before dispatch.
-- Optional onSent() fires only when the line actually went out: state that must record
-- "this was SAID" (announcedKey) belongs there, not on the scheduling result.
function Addon:SendMessageToChat(message, channel, target, keepCase, validate, onSent)
    if not self.db.profile.enabled then
        self:DebugPrint("Addon disabled, not sending")
        return false
    end

    -- A message that polishes down to nothing (custom text of only "{dungeon} {key}") must be
    -- refused here, before the caller burns its once-per-group flag, cooldown or budget slot on it
    local polished = self:PolishMessage(message, keepCase)
    if not polished or not polished:match("%S") then
        self:DebugPrint("Message empty after polish, refusing")
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
        -- Group sends are tracked so that joining a NEW group can cancel anything still in
        -- flight for the old one - a greeting built for group A must not land in group B.
        -- Guild sends are not: the guild never changes under a pending timer. GROUP_LEFT does
        -- not cancel either (the goodbye is scheduled moments before it fires).
        local handles = channel ~= "GUILD" and self.state.pendingGroupSends or nil
        -- A message built under one test-mode state must not fire under another: toggling
        -- test mode inside the typing delay would otherwise send a SIMULATION into real chat
        local generation = self.state.sendGeneration
        local handle
        handle = self:ScheduleTimer(function()
            if handles then handles[handle] = nil end
            if generation ~= self.state.sendGeneration then
                self:DebugPrint("Dropping delayed send - test mode toggled since scheduling")
                return
            end
            if validate and not validate() then
                self:DebugPrint("Dropping delayed send - no longer valid")
                return
            end
            if self:DoSendMessage(message, channel, target, keepCase) and onSent then
                onSent()
            end
        end, delay)
        -- Tagged with the channel so GROUP_JOINED can cancel selectively (an instance
        -- group forming next to a live home party only kills the INSTANCE_CHAT sends)
        if handles then handles[handle] = channel end
        self:DebugPrint("Scheduled message in", delay, "seconds")
        return true
    end
    -- Immediate path: the caller's budget/flag spend must reflect what actually happened
    local ok = self:DoSendMessage(message, channel, target, keepCase)
    if ok and onSent then onSent() end
    return ok
end

-- Final polish applied to every outgoing message: {role} placeholder, leftover M+ tokens,
-- and the optional lowercase first letter (skipped for keepCase phrases, e.g. "Lok'tar ogar!")
-- (%a is ASCII-only on purpose, so UTF-8 custom messages are left alone)
function Addon:PolishMessage(message, keepCase)
    if not message then return nil end
    message = message:gsub("{role}", self:GetRoleWord())
    -- M+ placeholders only the M+ path can resolve - a custom greeting/goodbye using them
    -- would otherwise ship the raw token to chat
    message = Logic.StripTokens(message, AutoSay.MPlusTokens)
    if self.db.profile.social.lowercaseFirst and not keepCase then
        message = message:gsub("^%a", string.lower)
    end
    return message
end

-- Chat colour per channel for the test-mode "would send" line
local ChannelColor = {}
for _, c in ipairs(AutoSay.Channels) do ChannelColor[c.chat] = c.color end

-- Returns true when a message actually went out (or was simulated in test mode) - callers
-- The line actually leaving the addon. C_ChatInfo.SendChatMessage is the modern entry point
-- and the one that survives the restrictions WoW 12.0 put on chat from inside instances, with
-- the old global kept as the fallback for anything that lacks it. Both are wrapped: a refusal
-- is a normal outcome here, not an error worth breaking the caller for.
local function RawSend(message, channel, target)
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        if pcall(C_ChatInfo.SendChatMessage, message, channel, nil, target) then return true end
    end
    return (pcall(SendChatMessage, message, channel, nil, target))
end

-- that spend a budget slot on the dispatch must not spend it on a drop
function Addon:DoSendMessage(message, channel, target, keepCase)
    if not message then
        self:DebugPrint("No message to send")
        return false
    end

    -- Last gate before the line leaves: goodbyes come straight here without a preflight,
    -- and a scheduled send is only checked against the group it was scheduled in
    if self:IsChannelSilenced(channel) then return false end

    message = TruncateToChatLimit(self:PolishMessage(message, keepCase))

    -- Token stripping can reduce a message to nothing (custom text of only "{dungeon} {key}")
    -- and SendChatMessage("") would error - drop instead
    if not message:match("%S") then
        self:DebugPrint("Message empty after polish, dropping")
        return false
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
        return true
    end

    if RawSend(message, channel, target) then
        updateCooldown()
        self:DebugPrint("Sent to", channel, ":", message)
        return true
    end

    -- Refused where we stand. The usual reason is the call stack rather than the message:
    -- we are inside a hook on a Blizzard function or in the tail of an encounter, and chat
    -- is closed to anything running there. One clean frame is enough to get out of it.
    if C_Timer and C_Timer.After then
        self:DebugPrint("Send refused, retrying next frame for", channel, ":", message)
        local generation = self.state.sendGeneration
        C_Timer.After(0, function()
            -- One frame is enough for the group to change under us, and a line meant for
            -- the party we just left must not land in the one we just joined
            if generation ~= self.state.sendGeneration then return end
            if self:GetChatChannel() ~= channel and channel ~= "GUILD" then
                self:DebugPrint("Retry dropped - the group changed", channel)
                return
            end
            if RawSend(message, channel, target) then
                updateCooldown()
                self:DebugPrint("Sent on retry to", channel, ":", message)
            else
                self:DebugPrint("Retry failed for", channel, ":", message)
            end
        end)
        -- Counted as handed off: the caller must not queue the same line a second time,
        -- but the cooldown is stamped by the retry itself, only if it actually speaks
        return true
    end

    self:DebugPrint("Failed to send to", channel, ":", message)
    return false
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

-- LFR and battlegrounds are raid-sized instance groups; a 5-player LFG run never is.
-- Asked about the group, not the head count: a raid group is raid-sized from the moment
-- it forms, before it fills up.
function Addon:IsRaidInstanceGroupOrTest()
    if self:IsTestMode() and self.testState.simulatedGroupType then
        return self.testState.simulatedRaidInstance and true or false
    end
    return IsInRaid(LE_PARTY_CATEGORY_INSTANCE) and true or false
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

-- Check if player is group leader (with test mode support). The optional channel scopes
-- the check to that channel's own group: while dual-grouped, leading the home party says
-- nothing about leading the LFR whose INSTANCE_CHAT is being greeted.
function Addon:IsGroupLeaderOrTest(channel)
    if self:IsTestMode() and self.testState.simulatedGroupType then
        return self.testState.simulatedIsLeader
    end
    if channel == "INSTANCE_CHAT" then
        return UnitIsGroupLeader("player", LE_PARTY_CATEGORY_INSTANCE)
    elseif channel then
        return UnitIsGroupLeader("player", LE_PARTY_CATEGORY_HOME)
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

-- A custom text containing {role} obeys the same two gates as the preset role phrases
-- (master switch on, an actual role assigned) - PolishMessage would otherwise confidently
-- substitute "dps" for an unassigned or role-phrases-off player. Applies to EVERY custom
-- pool: channel messages, guild login, key announce, completion.
function Addon:CustomTextUsable(text, channel)
    if not text:find("{role}", 1, true) then return true end
    -- Same rule the presets follow: a role means nothing to a guild reading it
    if channel == "GUILD" then return false end
    return self.db.profile.social.rolePhrases and self:GetPlayerRoleOrTest() ~= "NONE"
end

-- Get channel settings table
function Addon:GetChannelSettings(channel)
    for _, c in ipairs(AutoSay.Channels) do
        if c.chat == channel then return self.db.profile[c.key] end
    end
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
        -- Arriving draws from one list, welcoming from the other. A reconnect is about me,
        -- so it borrows the arrival list when its own has nothing to say.
        enabledKey = Logic.GreetingPoolKey(reason)
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
    -- override the preset's keepCase/mode, nor double that text's odds of being picked.
    -- Every enabled phrase is a candidate. Names no longer decide who is eligible - they are
    -- applied to whichever phrase wins, into its {names} slot or onto its end. Filtering by
    -- name-capability used to shrink a whole style down to the one or two lines written with a
    -- slot, and a set with one of them said that line to every newcomer in a row.
    local texts, modes, keeps = {}, {}, {}
    local seen = {}
    local function AddCandidate(text, mode, keepCase)
        -- Without names to carry, a slot phrase says its line with the hole closed up
        if not wantNames and mode == "slot" then
            text, mode = StripNameSlot(text), nil
            if seen[text] then return end
        end
        if seen[text] then return end
        seen[text] = true
        local n = #texts + 1
        texts[n], modes[n], keeps[n] = text, mode, keepCase
    end

    -- Add enabled preset messages
    if settings[enabledKey] then
        local role = self:GetPlayerRoleOrTest()
        local faction = UnitFactionGroup("player")
        -- nil band = band-tagged phrases never match, i.e. the master switch is off
        local hour
        if self:IsTestMode() and self.testState.simulatedHour ~= nil then
            hour = self.testState.simulatedHour
        else
            hour = (self.humanizer and self.humanizer.hour)
                and self.humanizer.hour() or tonumber(date("%H"))
        end
        local band = self.db.profile.social.timeOfDay
            and AutoSay.Humanizer.BandForHour(hour) or nil
        -- Never in guild chat: "tank here o/" is addressed to the four people you are about
        -- to pull for, not to a guild reading it over breakfast
        local rolePhrases = self.db.profile.social.rolePhrases and channel ~= "GUILD"

        for _, msg in ipairs(messages) do
            if settings[enabledKey][msg.key] and FitsContext(msg, role, faction, band, reason, rolePhrases) then
                AddCandidate(msg.text, NameMode(msg), msg.keepCase)
            end
        end
    end

    -- Add enabled custom messages: a {names} placeholder makes them slot phrases (and thus
    -- droppable when there are no names), everything else keeps the append-if-asked behaviour.
    -- A custom {role} obeys the same two gates as the preset ones (master switch, no assigned
    -- role) - otherwise "your {role} is here" announces "dps" for an unassigned tank.
    if settings[customsKey] then
        for _, entry in ipairs(settings[customsKey]) do
            if entry.enabled and entry.text and entry.text ~= "" and self:CustomTextUsable(entry.text, channel) then
                local mode = entry.text:find("{names}", 1, true) and "slot" or "append"
                AddCandidate(entry.text, mode)
            end
        end
    end

    if #texts == 0 then return nil end

    local text
    if self.humanizer then
        text = self.humanizer:Pick(messageType .. ":" .. channel, texts)
    else
        text = texts[math.random(#texts)]
    end

    -- First match wins, same rule the dedupe above used
    for i = 1, #texts do
        if texts[i] == text then return text, modes[i], keeps[i] end
    end
    return text
end

-- Every settings table a bundle or bulk button writes to, paired with the pool it owns there.
-- Channel pools repeat once per channel (channels without that pool are skipped by the nil
-- settings check downstream); M+ pools exist once, under db.profile.mythicplus.
local function StylePoolTargets(profile)
    local targets = {}
    for _, c in ipairs(AutoSay.Channels) do
        for _, pool in ipairs(AutoSay.StylePools) do
            if not pool.mplus then
                targets[#targets + 1] = { settings = profile[c.key], pool = pool }
            end
        end
    end
    for _, pool in ipairs(AutoSay.StylePools) do
        if pool.mplus then
            targets[#targets + 1] = { settings = profile.mythicplus, pool = pool }
        end
    end
    return targets
end

-- StyleFits (from MessageLogic): used to decide whether a pool holds anything of this style
-- for this character; the apply loop itself enables both factions on purpose.

-- Set every preset phrase of a style in every pool (state = true/false).
-- replace = true also turns off everything that is not part of the style (custom messages are untouched).
function Addon:ApplyStyleBundle(style, replace, state)
    if state == nil then state = true end
    local faction = UnitFactionGroup("player")

    local targets = StylePoolTargets(self.db.profile)

    -- A pool the style has nothing usable in must be left as it is - Replace has no
    -- replacement to offer there, so wiping it would just silence the channel
    local poolHasStyle = {}
    for _, target in ipairs(targets) do
        for _, msg in ipairs(AutoSay[target.pool.messages]) do
            if StyleFits(msg, style, faction) and Logic.PhraseInPool(msg, target.pool) then
                poolHasStyle[target.pool.enabledKey] = true
                break
            end
        end
    end

    for _, target in ipairs(targets) do
        local enabled = target.settings and target.settings[target.pool.enabledKey]
        if enabled and poolHasStyle[target.pool.enabledKey] then
            for _, msg in ipairs(AutoSay[target.pool.messages]) do
                if not Logic.PhraseInPool(msg, target.pool) then -- not this list's occasion
                elseif Logic.StyleMatches(msg, style) then
                    -- Both factions on purpose: the profile is shared by every character on
                    -- the account, and FitsContext already filters by faction at send time.
                    -- Skipping the other faction here + Replace would leave a Horde alt with
                    -- an all-false pool and no goodbye at all.
                    enabled[msg.key] = state
                elseif replace and state and not msg.band then
                    -- Band phrases are not shown in this UI - Replace must not silently kill them
                    enabled[msg.key] = false
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

    for _, target in ipairs(StylePoolTargets(self.db.profile)) do
        local enabled = target.settings and target.settings[target.pool.enabledKey]
        if enabled then
            for _, msg in ipairs(AutoSay[target.pool.messages]) do
                if matches(msg) and Logic.PhraseInPool(msg, target.pool) then
                    enabled[msg.key] = state
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
    return Logic.AddPlayersToMessage(message, playerNames, nameMode)
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

    -- First of the refusals: this channel is off-limits whatever the budget or the cooldown
    -- says, so it is the honest reason to report. Nothing below has run yet, so no cooldown
    -- stamp, phrase history or budget slot is spent on a line that was never going out.
    if self:IsChannelSilenced(channel) then return false end

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

    -- Pick a message based on reason (the humanizer rotates through the whole pool)
    local message, nameMode, keepCase
    if reason == "reconnect" then
        message, nameMode, keepCase = self:GetRandomMessageForChannel("reconnects", channel, reason, wantNames)
        if not message then
            -- Deliberate: this fallback may pick a [self]-tagged greeting even when
            -- "On self join" is off - a reconnect IS a self event, and going silent when the
            -- user explicitly enabled reconnect greetings would be the worse behaviour
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

-- Send goodbye. Returns true only when a line actually went out, so the caller's
-- once-per-leave guard is not burned on a bail-out.
function Addon:SendGoodbye(channel)
    local settings = self:GetChannelSettings(channel)
    if settings and not settings.sendGoodbye then
        self:DebugPrint(channel, "goodbyes disabled")
        return false
    end
    return self:DispatchGoodbye(channel)
end

-- The goodbye itself, without the switch that decides the occasion. Leaving the group asks
-- through SendGoodbye, the end of a run asks through SendRunEndGoodbye, and both land here
-- so a goodbye is picked, gated and recorded exactly the same way whichever brought it out.
function Addon:DispatchGoodbye(channel)
    local db = self.db.profile

    if not db.enabled then return false end

    local settings = self:GetChannelSettings(channel)
    if not settings then return false end

    -- The channel master comes first: "Enable Party" off means silence on that channel,
    -- goodbyes included, whatever the per-channel goodbye toggle inherited
    if not settings.enabled then
        self:DebugPrint(channel, "channel disabled, no goodbye")
        return false
    end

    if self.socialGate then
        local ok, why = self.socialGate:MaySend("goodbye")
        if not ok then
            self:DebugPrint("SendGoodbye gated:", why)
            if self:IsTestMode() then self:TestPrint("Goodbye blocked: " .. why) end
            return false
        end
    end

    -- Get random goodbye for this channel
    local message, _, keepCase = self:GetRandomMessageForChannel("goodbyes", channel)
    if not message then
        self:DebugPrint("No goodbyes enabled for", channel)
        return false
    end

    -- Send immediately (no delay for goodbyes since we're leaving);
    -- spend the budget slot only for a message that actually went out
    local sent = self:DoSendMessage(message, channel, nil, keepCase)
    if sent and self.socialGate then
        self.socialGate:Record("goodbye")
    end
    return sent
end

-- The end of a run is its own occasion, independent of leaving: a dungeon can end with
-- everyone standing around for another minute, and "Send goodbye" would still be waiting for
-- someone to press leave. Both switches can be on - then the group hears one line when the
-- run ends and another when you actually go.
-- completionSpoke says an M+ completion line is already going out for this very ending, and
-- that one has the floor: two of our lines in the same second read as a bot, not a person.
function Addon:SendRunEndGoodbye(completionSpoke)
    local channel = self:GetChatChannel()
    if not channel then return false end

    local settings = self:GetChannelSettings(channel)
    if not Logic.SaysGoodbyeOnRunEnd(settings, self.state.runEndGoodbyeSent, completionSpoke) then
        if completionSpoke and settings and settings.sendGoodbyeOnRunEnd then
            self:DebugPrint("Run-end goodbye skipped - the M+ completion line speaks for this run")
        end
        return false
    end

    -- The cooldown is asked before the flag is burned: a goodbye refused for talking too
    -- recently has not been said, and the leave that follows should still get its chance
    if not self:CanSendMessage(channel) then
        self:DebugPrint("Run-end goodbye dropped - cooldown active")
        return false
    end

    -- Burn the once-per-run flag on the attempt, not on the result: a goodbye the budget
    -- refused must not come back a second later from the leave path's event
    self.state.runEndGoodbyeSent = true
    self:DebugPrint("Run ended, saying goodbye on", channel)
    return self:DispatchGoodbye(channel)
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
    local generation = self.state.sendGeneration
    local delay = 4 + math.random() * 6 -- 4-10s listening window per spec
    self:ScheduleTimer(function()
        -- The pending slot is consumed either way - dropping on a stale generation must
        -- not leave a dangling intent in the social gate's listening state
        local taken = self.socialGate:TakePending(pendingId)
        if generation ~= self.state.sendGeneration then return end
        if not taken then
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
    local generation = self.state.sendGeneration
    local delay = 5 + math.random() * 10 -- 5-15s per spec
    self:ScheduleTimer(function()
        -- Consume the pending slot before the generation check, same as the grats path
        local taken = self.socialGate:TakePending(pendingId)
        if generation ~= self.state.sendGeneration then return end
        if not taken then
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
    if not db.guild.enabled then
        if self:IsTestMode() then self:TestPrint("Guild greeting skipped (guild channel disabled)") end
        return
    end
    if not db.guild.onSelfJoin then
        self:DebugPrint("Guild greeting on login disabled")
        if self:IsTestMode() then self:TestPrint("Guild greeting skipped (On login disabled)") end
        return
    end
    if not self:IsInGuildOrTest() then return end

    -- Check cooldown - if blocked, drop it (we just said something in guild chat)
    if not self:CanSendMessage("GUILD") then
        self:DebugPrint("Guild login greeting dropped - cooldown active")
        return
    end

    -- Get random greeting for guild. Logging in IS a self join: without the reason,
    -- FitsContext rejects every [self]-tagged phrase the guild tab shows as active.
    local message, _, keepCase = self:GetRandomMessageForChannel("greetings", "GUILD", "self_join")
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
        if self:IsTestMode() then self:TestPrint("Guild goodbye skipped (guild channel disabled)") end
        return
    end
    if not db.guild.sendGoodbye then
        self:DebugPrint("Guild goodbye on logout disabled")
        if self:IsTestMode() then self:TestPrint("Guild goodbye skipped (Send goodbye disabled)") end
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
    -- Send immediately (no delay for goodbyes);
    -- spend the budget slot only for a message that actually went out
    if self:DoSendMessage(message, "GUILD", nil, keepCase) and self.socialGate then
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

    local generation = self.state.sendGeneration
    self.state.guildLoginTimer = self:ScheduleTimer(function()
        if generation ~= self.state.sendGeneration then
            self.state.guildLoginTimer = nil
            -- The batch is unsendable - its names must not ride along in the next one
            self.state.pendingGuildLogins = {}
            return
        end
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

    -- Replace {name} placeholder with member name(s), capped like every other names path -
    -- a raid-night login burst must not produce a 255-byte name wall chopped mid-name
    message = message:gsub("{name}", Logic.FormatNameList(names))

    -- A message that polishes to nothing must not consume the cooldown or a budget slot
    local polished = self:PolishMessage(message)
    if not polished or not polished:match("%S") then
        self:DebugPrint("Guild login greeting empty after polish, dropping")
        return
    end

    self.state.lastGuildLoginGreetTime = now
    -- Reserve the budget slot before the delay timer, now that a message is certain to go out
    if self.socialGate then
        self.socialGate:Record("greeting", names and names[1] or nil)
    end
    -- Send directly, bypassing global cooldown (member login has its own cooldown above)
    local delay = db.messageDelay
    if delay and delay > 0 then
        local generation = self.state.sendGeneration
        self:ScheduleTimer(function()
            if generation ~= self.state.sendGeneration then return end
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
            if entry.enabled and entry.text and entry.text ~= "" and self:CustomTextUsable(entry.text, "GUILD") then
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
    if settings.onOthersJoinLeaderOnly and not self:IsGroupLeaderOrTest(channel) then
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

-- Resolve mapChallengeModeID by exact localized-name match against the live season pool -
-- the fallback for listings whose activityID is not in ActivityToDungeon (the table can lag
-- a season behind). Same matching trick DumpDungeons uses.
function Addon:GetMapIDFromDungeonName(name)
    if not name or not C_ChallengeMode or not C_ChallengeMode.GetMapTable
        or not C_ChallengeMode.GetMapUIInfo then
        return nil
    end
    for _, mapID in ipairs(C_ChallengeMode.GetMapTable() or {}) do
        if C_ChallengeMode.GetMapUIInfo(mapID) == name then
            return mapID
        end
    end
    return nil
end

-- Replace {dungeon} and {key} placeholders in a message
function Addon:ReplacePlaceholders(message, dungeon, keyLevel, extraReplacements)
    if not message then return nil end
    message = message:gsub("{dungeon}", dungeon or "")
    if keyLevel then
        message = message:gsub("{key}", "+" .. keyLevel)
    else
        -- Remove {key} together with the punctuation that introduced it, so
        -- "the {dungeon} express departs, {key}" does not end on a dangling comma;
        -- CleanupAfterTokenStrip (inside PolishMessage below) sweeps every other
        -- comma position ("{key}, here we go", "gg, {key}, wp")
        message = message:gsub(",?%s*{key}", "")
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

-- Key level for the announce, from the API only - a listing title is free text ("+10 or 12",
-- "10+ exp", a guild name with digits) and guessing from it announces the wrong key.
-- nil means "not known for sure": the announce then names the dungeon and nothing else.
function Addon:GetKeyLevel()
    if not self.db.profile.mythicplus.includeKeyLevel then return nil end

    local listing = self.state.cachedLFGListing

    -- Test flow: the simulated listing carries the level the simulation announced
    if self:IsTestMode() and listing and listing.keyLevel then
        return listing.keyLevel
    end

    -- 1. Our own keystone, but only while it is the dungeon this group is listed for
    if C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel and C_MythicPlus.GetOwnedKeystoneChallengeMapID then
        local ownedMapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
        local listedMapID = listing and (self:GetMapIDFromActivity(listing.activityID)
            or self:GetMapIDFromDungeonName(listing.dungeonName
                and listing.dungeonName:gsub("%s*%b()%s*$", "")))
        if ownedMapID and listedMapID and ownedMapID == listedMapID then
            local level = C_MythicPlus.GetOwnedKeystoneLevel()
            if level and level > 0 then
                self:DebugPrint("Key level from owned keystone:", level)
                return level
            end
        end
    end

    -- 2. The level the listing itself was created with
    if listing and listing.activityID and C_LFGList and C_LFGList.GetKeystoneForActivity then
        local level = C_LFGList.GetKeystoneForActivity(listing.activityID)
        if level and level > 0 then
            self:DebugPrint("Key level from GetKeystoneForActivity:", level)
            return level
        end
    end

    self:DebugPrint("Key level unknown, announcing dungeon name only")
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
            if entry.enabled and entry.text and entry.text ~= "" and self:CustomTextUsable(entry.text) then
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
    if not self:MythicPlusChannelOpen() then return end

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

    -- Resolve dungeon name (English by default, client locale if enabled). The suffix strip
    -- takes any trailing parenthesis, because "(Mythic Keystone)" is localized on non-enUS clients.
    local localizedName = listing.dungeonName and listing.dungeonName:gsub("%s*%b()%s*$", "")
    -- The displayed name only ever comes from the LISTED activity (or the listing's own
    -- text, matched by name against the live season pool when the activity table lags a
    -- season behind): feeding any other map id into GetDungeonName could announce a
    -- different dungeon. The resolved map id doubles as the SameKey identity - the same id
    -- space C_ChallengeMode.GetActiveChallengeMapID uses, which keeps the start announce
    -- silent for an already-announced key on every client language.
    local listedMapID = self:GetMapIDFromActivity(listing.activityID)
        or self:GetMapIDFromDungeonName(localizedName)
    local dungeon = self:GetDungeonName(listedMapID, localizedName)
    local mapID = listedMapID

    -- Get key level based on mode
    local keyLevel = self:GetKeyLevel()

    -- Already said exactly this (the group dipped below 5 and refilled inside the announce
    -- delay, scheduling a second timer): once is enough
    if SameKey(self.state.announcedKey, { mapID = mapID, dungeon = dungeon, level = keyLevel }) then
        self:DebugPrint("Key announce skipped: this key was already announced")
        return
    end

    -- Get random message template
    local template = self:GetRandomKeyAnnounce()
    if not template then
        self:DebugPrint("SendKeyAnnounce: no key announce messages enabled")
        return
    end

    -- Replace placeholders
    local message = self:ReplacePlaceholders(template, dungeon, keyLevel)

    self:DebugPrint("SendKeyAnnounce:", message, "(dungeon:", dungeon,
        "level:", tostring(keyLevel) .. ")")

    -- The announce belongs to the HOME group carrying the listing - GetChatChannel is
    -- instance-first and would post the key line into a BG/LFR the party queued together
    local channel = IsInRaid(LE_PARTY_CATEGORY_HOME) and "RAID" or "PARTY"

    -- Share the group cooldown with greetings: an announce landing in the same second as
    -- the greeting reads like a bot. One retry when the cooldown is still running, then drop.
    -- keepCase so the second polish inside DoSendMessage keeps the dungeon name capitalized.
    -- The validator re-checks 5/5 inside the typing delay: a member leaving after the
    -- announce was accepted must kill the stale key line.
    local stillValid = function()
        return self.state.keyAnnounced
            and (self:IsTestMode() or GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) == 5)
    end
    -- announcedKey records what was actually SAID: stamping it on the scheduling result
    -- would let a validator-dropped send silence this key for good (the dip path does not
    -- clear announcedKey, and both announce entry points dedupe against it)
    local recordSaid = function()
        self.state.announcedKey = { mapID = mapID, dungeon = dungeon, level = keyLevel }
    end
    if self:SendMessageToChat(message, channel, nil, true, stillValid, recordSaid) then
        self.state.keyAnnounceRetried = false
        return
    end

    if self.state.keyAnnounceRetried then
        self:DebugPrint("Key announce still blocked after the retry (cooldown or chat restriction), dropping")
        return
    end

    self.state.keyAnnounceRetried = true
    local remaining = self.db.profile.cooldown - (GetTime() - self.state.lastGroupMessageTime)
    local wait = math.max(remaining, 0) + (self.db.profile.messageDelay or 0) + 0.5
    self:DebugPrint("Key announce blocked (cooldown or chat restriction), retrying in", string.format("%.1f", wait) .. "s")
    -- Resend the very message we built, not a fresh roll, and only while the announce
    -- this retry belongs to is still valid (same full group, flag not reset meanwhile)
    self.state.keyAnnounceTimer = self:ScheduleTimer(function()
        self.state.keyAnnounceTimer = nil
        -- Whatever happens next, this retry is spent: the latch must not outlive it and
        -- swallow a FUTURE announce's retry (dip-refill, next listing)
        self.state.keyAnnounceRetried = false
        if not stillValid() then
            self:DebugPrint("Key announce retry no longer valid, dropping")
            return
        end
        self:SendMessageToChat(message, channel, nil, true, stillValid, recordSaid)
    end, wait)
end

-- Announce the keystone that was actually inserted, at the start of the run.
-- Silent when the group-full announce already named this exact dungeon and level.
-- @return boolean - true when a message was scheduled
function Addon:SendKeyStartAnnounce(dungeon, keyLevel, mapID)
    -- A pending attempt from a previous insert (reset-then-restart within the retry window)
    -- must not survive into this one - it would post its stale message alongside ours
    if self.state.startAnnounceTimer then
        self:CancelTimer(self.state.startAnnounceTimer)
        self.state.startAnnounceTimer = nil
    end
    mapID = mapID or (C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID
        and C_ChallengeMode.GetActiveChallengeMapID()) or nil
    local key = { mapID = mapID, dungeon = dungeon, level = keyLevel }

    if SameKey(self.state.announcedKey, key) then
        self:DebugPrint("Key start announce skipped:", dungeon, tostring(keyLevel),
            "was already announced when the group filled")
        return false
    end

    local template = self:GetRandomKeyAnnounce()
    if not template then
        self:DebugPrint("SendKeyStartAnnounce: no key announce messages enabled")
        return false
    end

    local message = self:ReplacePlaceholders(template, dungeon, keyLevel)
    -- Home-scoped like SendKeyAnnounce: a keystone run is always the home group
    local channel = IsInRaid(LE_PARTY_CATEGORY_HOME) and "RAID" or "PARTY"

    self:DebugPrint("SendKeyStartAnnounce:", message, "(dungeon:", dungeon,
        "level:", tostring(keyLevel) .. ")")

    -- announcedKey is written only once the line actually went out: recording it up front
    -- would let a cooldown refusal silence this key for good. One retry, then drop.
    local retried = false
    local recordSaid = function()
        self.state.announcedKey = key
    end
    local function Attempt()
        self.state.startAnnounceTimer = nil
        if self:SendMessageToChat(message, channel, nil, true, nil, recordSaid) then
            return
        end
        if retried then
            self:DebugPrint("Key start announce still blocked after the retry (cooldown or chat restriction), dropping")
            return
        end
        retried = true
        local remaining = self.db.profile.cooldown - (GetTime() - self.state.lastGroupMessageTime)
        local wait = math.max(remaining, 0) + (self.db.profile.messageDelay or 0) + 0.5
        self:DebugPrint("Key start announce blocked (cooldown or chat restriction), retrying in", string.format("%.1f", wait) .. "s")
        self.state.startAnnounceTimer = self:ScheduleTimer(Attempt, wait)
    end

    -- Small delay so it lands after the start countdown noise, not in the middle of it
    self.state.startAnnounceTimer = self:ScheduleTimer(Attempt, 2)
    return true
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
            if entry.enabled and entry.text and entry.text ~= ""
                and usable(entry.text) and self:CustomTextUsable(entry.text) then
                table.insert(enabled, entry.text)
            end
        end
    end

    if #enabled == 0 then return nil end

    return enabled[math.random(#enabled)]
end

-- Everything Mythic+ says is said in party chat, so "Enable Party" governs it like any other
-- line sent there. The M+ switch decides whether the feature runs, the channel switch decides
-- whether that channel speaks at all, and the channel has the last word.
function Addon:MythicPlusChannelOpen()
    local settings = self.db.profile.party
    if settings and settings.enabled == false then
        self:DebugPrint("Party channel disabled, no Mythic+ announcement")
        if self:IsTestMode() then
            self:TestPrint("Message blocked: the Party channel is off (General tab)")
        end
        return false
    end
    return true
end

-- Send completion message to party chat
function Addon:SendCompletionMessage(dungeon, keyLevel, onTime, upgrade, timeFormatted)
    local db = self.db.profile
    if not db.enabled or not db.mythicplus.enabled or not db.mythicplus.completionEnabled then return false end
    if not self:MythicPlusChannelOpen() then return false end

    local template = self:GetRandomCompletionMessage(onTime, upgrade)
    if not template then
        self:DebugPrint("SendCompletionMessage: no completion messages enabled for", onTime and "timed" or "depleted")
        return false
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
        return false
    end
    return true
end

--------------------------------------------------------------------------------
-- TEST MODE SIMULATION FUNCTIONS
--------------------------------------------------------------------------------

-- Reset test state
function Addon:TestReset()
    self.testState.simulatedGroupType = nil
    self.testState.simulatedRaidInstance = false
    self.testState.simulatedInGuild = false
    self.testState.simulatedGroupMembers = {}
    self.testState.simulatedIsLeader = true
    self.testState.simulatedRole = "DAMAGER"
    self.testState.simulatedHour = nil
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
    self.state.announcedKey = nil
    self.state.startAnnounced = false
    if self.state.keyAnnounceTimer then
        self:CancelTimer(self.state.keyAnnounceTimer)
        self.state.keyAnnounceTimer = nil
    end
    if self.state.startAnnounceTimer then
        self:CancelTimer(self.state.startAnnounceTimer)
        self.state.startAnnounceTimer = nil
    end
    self:SetInstanceGreeted(false)
    self.state.mythicPlusFlowActive = false
    self.state.goodbyeSent = false
    self.state.groupGoodbyeSent = {}
    self.state.guildMemberPresence = {}
    self.state.guildPresenceReady = true -- In test mode, always ready
    -- Clear session-only social state (persistent budget/person state intentionally kept, matches live behavior)
    if self.socialGate then
        self.socialGate.pending = {}
    end
    if self.humanizer then
        self.humanizer.rounds = {}
    end
    -- Delayed sends from an earlier simulation must not fire into the next one (the
    -- sendGeneration bump on the test-mode toggle covers mode changes; this covers resets).
    -- The bump also invalidates untracked simulation timers (the M+ flow's join closures).
    self:TestCancelPendingSends()
    self.state.sendGeneration = self.state.sendGeneration + 1
    self:TestPrint("Test state reset")
end

-- Role names accepted by /as test role, mapped to the UnitGroupRolesAssigned values
local testRoleAliases = {
    tank = "TANK", t = "TANK",
    healer = "HEALER", h = "HEALER",
    dps = "DAMAGER", d = "DAMAGER",
}

-- Simulate the assigned role, for role-tagged phrases and the {role} placeholder
function Addon:TestSetRole(roleArg)
    if not self:RequireTestMode() then return end

    local role = testRoleAliases[roleArg and roleArg:lower() or ""]
    if not role then
        self:Print(L["Test role usage"])
        return
    end

    self.testState.simulatedRole = role
    self:TestPrint(L["Simulated role set"] .. ": " .. AutoSay.RoleWords[role])
end

-- Simulate the local hour, for the time-of-day band ("off" reverts to the real clock)
function Addon:TestSetHour(hourArg)
    if not self:RequireTestMode() then return end

    if hourArg and hourArg:lower() == "off" then
        self.testState.simulatedHour = nil
        self:TestPrint(L["Simulated hour cleared"])
        return
    end

    local hour = tonumber(hourArg)
    if not hour or hour < 0 or hour > 23 or hour ~= math.floor(hour) then
        self:Print(L["Test hour usage"])
        return
    end

    self.testState.simulatedHour = hour
    local band = AutoSay.Humanizer.BandForHour(hour)
    self:TestPrint(L["Simulated hour set"] .. ": " .. hour .. " (" .. band .. ")")
end

-- Preview the What's new popup without burning the real one-time-per-version flag
function Addon:TestPreviewWhatsNew()
    if not self:RequireTestMode() then return end

    self:TestPrint("=== Previewing What's new ===")
    self:ShowWhatsNew(self:VersionMinor() or "dev", true)
end

-- Entering a new simulated group drops whatever the previous one still had in flight, the
-- way GROUP_JOINED does for real groups. Without it a greeting built for one simulation
-- lands in the next: schedule a 5-player instance greeting, switch to /as test lfr inside
-- the typing delay, and the old timer would speak in a group that must stay silent.
-- Deliberately only the tracked group sends, with no sendGeneration bump: the bump reaches
-- further than a group change should (it would drop a pending guild greeting and strand the
-- M+ simulation's own closures, which a live GROUP_JOINED leaves alone). Full teardown of a
-- simulation is TestReset's job.
function Addon:TestCancelPendingSends()
    for handle in pairs(self.state.pendingGroupSends) do
        self:CancelTimer(handle)
    end
    self.state.pendingGroupSends = {}
    -- The M+ simulation schedules its own untracked join timers. They are fenced by the
    -- flow generation rather than sendGeneration, so replacing a simulation strands them
    -- without touching a guild send that has nothing to do with the group.
    self.state.testFlowGeneration = self.state.testFlowGeneration + 1
    self.state.mythicPlusFlowActive = false
    -- The announce timers are held by name rather than in pendingGroupSends, and their own
    -- revalidation would accept the replacement group, so they have to be dropped here
    if self.state.keyAnnounceTimer then
        self:CancelTimer(self.state.keyAnnounceTimer)
        self.state.keyAnnounceTimer = nil
    end
    if self.state.startAnnounceTimer then
        self:CancelTimer(self.state.startAnnounceTimer)
        self.state.startAnnounceTimer = nil
    end
end

-- Simulate joining a party
function Addon:TestJoinParty()
    if not self:RequireTestMode() then return end

    self:TestPrint("=== Simulating JOIN PARTY ===")
    self:TestCancelPendingSends()
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
    if not self:RequireTestMode() then return end

    self:TestPrint("=== Simulating JOIN RAID ===")
    self:TestCancelPendingSends()
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

-- Simulate zoning into an instance group. raidSized simulates an LFR or a battleground,
-- which the skipRaidGroups toggle silences; without it this is a 5-player LFG run.
function Addon:TestJoinInstance(raidSized)
    if not self:RequireTestMode() then return end

    self:TestPrint(raidSized and "=== Simulating ENTER LFR/BATTLEGROUND ===" or "=== Simulating ENTER INSTANCE GROUP ===")
    self:TestCancelPendingSends()
    self.testState.simulatedGroupType = "INSTANCE_CHAT"
    self.testState.simulatedRaidInstance = raidSized and true or false
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
    if not self:RequireTestMode() then return end

    if not self.testState.simulatedGroupType then
        self:TestPrint("Not in a simulated group!")
        return
    end

    local groupType = self.testState.simulatedGroupType
    self:TestPrint("=== Simulating LEAVE " .. groupType .. " ===")

    -- Send goodbye before "leaving"
    self:SendGoodbye(groupType)

    -- Reset simulated group state. The flow ends with the group: a simulation left behind
    -- would keep adding fake members to a group that no longer exists
    self:TestCancelPendingSends()
    self.testState.simulatedGroupType = nil
    self.testState.simulatedRaidInstance = false
    self.state.previousGroup = nil
    self.state.sentGreetings = {}
    self.state.currentGroupType = nil
    self:SetInstanceGreeted(false)
end

-- Simulate player joining the group
function Addon:TestPlayerJoins(playerName)
    if not self:RequireTestMode() then return end

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
    if not self:RequireTestMode() then return end

    self:TestPrint("=== Simulating GUILD LOGIN greeting ===")
    self.testState.simulatedInGuild = true
    self:SendGuildGreeting()
    self.testState.simulatedInGuild = false
end

-- Simulate guild logout goodbye
function Addon:TestGuildGoodbye()
    if not self:RequireTestMode() then return end

    self:TestPrint("=== Simulating GUILD LOGOUT goodbye ===")
    self.testState.simulatedInGuild = true
    self:SendGuildGoodbye()
    self.testState.simulatedInGuild = false
end

-- Simulate guild member login
function Addon:TestGuildMemberLogin(playerName)
    if not self:RequireTestMode() then return end

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
    if not self:RequireTestMode() then return end

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

-- Dungeon pool for the M+ simulations (Midnight Season 2, matching AutoSay.DungeonNames so
-- the simulations exercise the shipped table; activityIDs are placeholders until the season
-- ids exist - the test path resolves names via mapID/name, not the activity map)
local testDungeons = {
    { name = "Altar of Fangs",            activityID = 0, mapID = 588 },
    { name = "Ruby Life Pools",           activityID = 0, mapID = 399 },
    { name = "Kings' Rest",               activityID = 0, mapID = 249 },
    { name = "Voidscar Arena",            activityID = 0, mapID = 585 },
    { name = "Den of Nalorakk",           activityID = 0, mapID = 586 },
    { name = "Murder Row",                activityID = 0, mapID = 587 },
    { name = "Temple of Sethraliss",      activityID = 0, mapID = 250 },
    { name = "The Blinding Vale",         activityID = 0, mapID = 584 },
}

-- Simulate full M+ flow: create listing → players join → 5/5 → announce
function Addon:TestMythicPlusFlow()
    if not self:RequireTestMode() then return end

    -- Prevent overlapping simulations
    if self.state.mythicPlusFlowActive then
        self:TestPrint("M+ flow simulation already in progress!")
        return
    end

    local isLeader = self.testState.mythicPlusRole == "leader"

    self:TestPrint("=== Simulating M+ Full Flow (" .. (isLeader and "Leader" or "Joined") .. ") ===")

    -- Step 1: Reset and set up party. The overlap flag goes AFTER the reset -
    -- TestReset clears it, so setting it first made the guard permanently dead.
    self:TestReset()
    self.state.mythicPlusFlowActive = true
    self.testState.simulatedGroupType = "PARTY"
    self.testState.simulatedIsLeader = isLeader
    self.state.currentGroupType = "PARTY"
    self.state.previousGroup = { [UnitName("player")] = true }
    self.testState.simulatedGroupMembers = { UnitName("player") }

    local picked = testDungeons[math.random(#testDungeons)]
    local keyLevel = math.random(4, 15)
    local dungeon = self:GetDungeonName(picked.mapID, picked.name)

    if isLeader then
        -- Leader: has LFG listing cached
        self.state.cachedLFGListing = {
            activityID = picked.activityID,
            title = "+" .. keyLevel,
            -- The real GetKeyLevel reads the game APIs; the simulation has none, so it
            -- hands the level over on the fake listing instead
            keyLevel = keyLevel,
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

    -- Step 2: Players join with delays. Generation-stamped like every other delayed send:
    -- turning test mode off mid-flow must kill the remaining joins, or their fabricated
    -- names would be greeted into the player's REAL party chat.
    local fakeNames = { "Tankmaster", "HolyPala", "Shadowmage", "Hunterbro" }
    local generation = self.state.sendGeneration
    local flowGeneration = self.state.testFlowGeneration
    for i, name in ipairs(fakeNames) do
        self:ScheduleTimer(function()
            if generation ~= self.state.sendGeneration then return end
            -- Another simulation replaced this one: its remaining joins are not ours to greet
            if flowGeneration ~= self.state.testFlowGeneration then return end
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
                            -- Both fences before the shared flag: a stale callback clearing
                            -- it would hand the next simulation's flow to a third one
                            if generation ~= self.state.sendGeneration then return end
                            if flowGeneration ~= self.state.testFlowGeneration then return end
                            self.state.mythicPlusFlowActive = false
                            self:SendKeyAnnounce()
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

-- Simulate CHALLENGE_MODE_START: the inserted keystone gets announced, unless the
-- group-full announce already said exactly this. Runs both paths back to back.
function Addon:TestKeyStart()
    if not self:RequireTestMode() then return end

    local index = math.random(#testDungeons)
    local picked = testDungeons[index]
    local other = testDungeons[(index % #testDungeons) + 1]
    local keyLevel = math.random(4, 15)
    local includeLevel = self.db.profile.mythicplus.includeKeyLevel
    local dungeon = self:GetDungeonName(picked.mapID, picked.name)
    local otherDungeon = self:GetDungeonName(other.mapID, other.name)

    self:TestPrint("=== Simulating M+ Key Start ===")

    -- Path 1: the same key the group-full announce already named
    self.state.announcedKey = { dungeon = dungeon, level = includeLevel and keyLevel or nil }
    self:TestPrint("Group was announced as " .. dungeon .. " +" .. keyLevel .. ", same key inserted...")
    if not self:SendKeyStartAnnounce(dungeon, includeLevel and keyLevel or nil) then
        self:TestPrint("Stayed silent - the group-full announce already said this")
    end

    -- Path 2: a different key went in (lead swap, someone else's key)
    local otherLevel = keyLevel + 2
    self:TestPrint("Now a different key is inserted: " .. otherDungeon .. " +" .. otherLevel)
    self:SendKeyStartAnnounce(otherDungeon, includeLevel and otherLevel or nil)
end

-- Simulate timed M+ completion
function Addon:TestCompletionTimed()
    if not self:RequireTestMode() then return end

    local picked = testDungeons[math.random(#testDungeons)]
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
    if not self:RequireTestMode() then return end

    local picked = testDungeons[math.random(#testDungeons)]
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

    -- Where each pool stands in its rotation: how many of its phrases are already spent
    if self.humanizer and self.humanizer.rounds then
        for poolId, round in pairs(self.humanizer.rounds) do
            local spent = 0
            for _ in pairs(round.used or {}) do spent = spent + 1 end
            self:Print("Rotation:", poolId, "|cFFFFFF00" .. spent .. "|r said this round")
        end
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
        "| Key level:", db.mythicplus.includeKeyLevel and "|cFF00FF00Yes|r" or "|cFF888888No|r",
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
