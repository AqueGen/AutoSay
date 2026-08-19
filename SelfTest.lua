local ADDON_NAME, AutoSay = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)

local format = string.format
local HOUR = 3600

-- Live M+ season pool, or nil when the client has no data (outside a season, or not loaded yet).
local function SeasonMaps()
    if not (C_ChallengeMode and C_ChallengeMode.GetMapTable) then return nil end
    local maps = C_ChallengeMode.GetMapTable()
    if type(maps) ~= "table" or #maps == 0 then return nil end
    return maps
end

-- Dungeon name for a challenge map ID, in the client's language.
local function MapName(mapID)
    local name
    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        name = C_ChallengeMode.GetMapUIInfo(mapID)
    end
    return name or "?"
end

-- In-game counterpart to the headless busted suite: busted proves the core logic,
-- this proves the core is correctly wired into the addon and behaves in the real client.
-- Everything behavioural runs against throwaway SocialGate/Humanizer instances built on
-- scratch state with a fake clock, so the player's real counters (db.char.social) are
-- never touched. The live-wiring checks below are strictly read-only.
function Addon:RunSelfTest()
    local passed, total = 0, 0
    local function check(label, ok, detail)
        total = total + 1
        if ok then
            passed = passed + 1
            self:Print("|cFF00FF00PASS|r " .. label)
        else
            self:Print("|cFFFF0000FAIL|r " .. label .. (detail and (" - " .. detail) or ""))
        end
    end

    local fakeNow = 1000000
    local settings = { budgetPerHour = 12, personCooldownHours = 4, listen = true }
    local function newGate()
        return AutoSay.SocialGate.New{
            now = function() return fakeNow end,
            settings = function() return settings end,
            state = {}, -- throwaway, never db.char.social
        }
    end

    -- Group A: Humanizer
    local hz = AutoSay.Humanizer.New{ random = math.random, hour = function() return 12 end }

    local base = 1.5 + 0.06 * 2
    local delay = hz:GetTypingDelay("hi")
    check("typing delay scales with length", delay >= base * 0.7 and delay <= base * 1.3,
        format("expected %.2f..%.2f, got %.2f", base * 0.7, base * 1.3, delay))

    local capped = hz:GetTypingDelay(string.rep("x", 200))
    check("typing delay capped at 6s", capped == 6, format("expected 6, got %.2f", capped))

    local pool = { "p1", "p2", "p3", "p4", "p5" }
    local a, b, c = hz:Pick("selftest", pool), hz:Pick("selftest", pool), hz:Pick("selftest", pool)
    check("anti-repeat: 3 consecutive picks are distinct", a ~= b and b ~= c and a ~= c,
        format("got %s, %s, %s", a, b, c))

    local band = AutoSay.Humanizer.BandForHour
    check("time-of-day band mapping",
        band(7) == "morning" and band(12) == "day" and band(20) == "evening" and band(2) == "night",
        format("7=%s 12=%s 20=%s 2=%s", band(7), band(12), band(20), band(2)))

    -- Group B: SocialGate
    local gate = newGate()
    local sent = 0
    for _ = 1, settings.budgetPerHour do
        if gate:MaySend("selftest") then
            gate:Record("selftest")
            sent = sent + 1
        end
    end
    local okBudget, whyBudget = gate:MaySend("selftest")
    check("hourly budget: 12 sends pass, 13th blocked",
        sent == settings.budgetPerHour and okBudget == false and whyBudget == "budget",
        format("sent=%d, next=%s/%s", sent, tostring(okBudget), tostring(whyBudget)))

    fakeNow = fakeNow + HOUR + 1
    check("budget window slides after an hour", gate:MaySend("selftest") == true, "still blocked at +1h")

    gate = newGate()
    gate:Record("grats", "Bob")
    local okBob, whyBob = gate:MaySend("grats", "Bob")
    local okAlice = gate:MaySend("grats", "Alice")
    check("per-person cooldown blocks Bob but not Alice",
        okBob == false and whyBob == "person-cd" and okAlice == true,
        format("Bob=%s/%s Alice=%s", tostring(okBob), tostring(whyBob), tostring(okAlice)))

    gate = newGate()
    local welcomes = 0
    for i = 1, 100 do
        local name = "Joiner" .. i
        if gate:MayWelcome(name) then
            gate:RecordWelcome(name)
            welcomes = welcomes + 1
        end
    end
    check("100-join wave capped at 2 welcomes", welcomes == 2, format("expected 2, got %d", welcomes))

    gate = newGate()
    gate:RecordWelcome("Newbie")
    fakeNow = fakeNow + HOUR + 1
    local okNewbie, whyNewbie = gate:MayWelcome("Newbie")
    check("welcome is once-ever, even after an hour",
        okNewbie == false and whyNewbie == "already-welcomed",
        format("got %s/%s", tostring(okNewbie), tostring(whyNewbie)))

    gate = newGate()
    local pendingId = gate:AddPending("grats", "GUILD")
    gate:OnChatMessage("GUILD", "Someone", "gz nice")
    check("someone else's 'gz' cancels our pending grats",
        gate:TakePending(pendingId) == false, "pending survived, we would have double-posted")

    pendingId = gate:AddPending("grats", "GUILD")
    gate:OnChatMessage("GUILD", "Someone", "gzip that log")
    check("listening matches whole words only ('gzip' is not 'gz')",
        gate:TakePending(pendingId) == true, "pending was cancelled by a substring match")

    pendingId = gate:AddPending("grats", "GUILD")
    gate:OnChatMessage("PARTY", "Someone", "gz")
    check("listening is per-channel (party 'gz' leaves guild pending alone)",
        gate:TakePending(pendingId) == true, "pending was cancelled from the wrong channel")

    -- Group C: live wiring (read-only)
    check("live socialGate and humanizer exist",
        type(self.socialGate) == "table" and type(self.humanizer) == "table",
        format("socialGate=%s humanizer=%s", type(self.socialGate), type(self.humanizer)))

    local social = self.db and self.db.char and self.db.char.social
    local missingState = {}
    for _, key in ipairs({ "sends", "perPerson", "welcomed", "welcomeSends" }) do
        if type(social) ~= "table" or type(social[key]) ~= "table" then
            missingState[#missingState + 1] = key
        end
    end
    check("db.char.social holds the four gate tables", #missingState == 0,
        "missing: " .. table.concat(missingState, ", "))

    local missingHandlers = {}
    for _, name in ipairs({ "OnSocialChat", "OnGuildAchievement", "OnSystemMessage",
                            "SendGuildGrats", "SendGuildWelcome" }) do
        if type(self[name]) ~= "function" then missingHandlers[#missingHandlers + 1] = name end
    end
    check("social adapter handlers are registered", #missingHandlers == 0,
        "missing: " .. table.concat(missingHandlers, ", "))

    local pattern = self.GetGuildJoinPattern and self.GetGuildJoinPattern()
    local sample = ERR_GUILD_JOIN_S and format(ERR_GUILD_JOIN_S, "Testname")
    local captured = pattern and sample and sample:match(pattern)
    check("guild join pattern parses this client's ERR_GUILD_JOIN_S", captured == "Testname",
        format("pattern=%s sample=%s captured=%s",
            tostring(pattern), tostring(sample), tostring(captured)))

    -- Group D: live season pool coverage (read-only)
    local seasonMaps = SeasonMaps()
    if seasonMaps then
        local missing = {}
        for _, mapID in ipairs(seasonMaps) do
            if not AutoSay.DungeonNames[mapID] then
                missing[#missing + 1] = format("%d (%s)", mapID, MapName(mapID))
            end
        end
        check("AutoSay.DungeonNames covers the live M+ season pool", #missing == 0,
            "missing " .. table.concat(missing, ", ") .. " - run /as dumpdungeons")
    else
        self:Print("|cFFFFCC00SKIP|r season pool coverage - no M+ map data on this client right now")
    end

    -- A cross-season mismatch here silently kills English names and the key dedupe
    local orphanActivities = {}
    for activityID, mapID in pairs(AutoSay.ActivityToDungeon) do
        if not AutoSay.DungeonNames[mapID] then
            orphanActivities[#orphanActivities + 1] = format("%d->%d", activityID, mapID)
        end
    end
    check("every ActivityToDungeon map id resolves in DungeonNames", #orphanActivities == 0,
        "orphans: " .. table.concat(orphanActivities, ", ") .. " - regenerate both via /as dumpdungeons")

    if seasonMaps then
        local withoutUiMap = {}
        for _, mapID in ipairs(seasonMaps) do
            if not select(6, C_ChallengeMode.GetMapUIInfo(mapID)) then
                withoutUiMap[#withoutUiMap + 1] = format("%d (%s)", mapID, MapName(mapID))
            end
        end
        -- The ui map id is the only link left between an LFG activity and a dungeon: an
        -- activity's shortName is just "Mythic+", so losing this would silently leave the
        -- shipped fallback table as the only answer.
        check("every season dungeon exposes a ui map id", #withoutUiMap == 0,
            "no ui map for " .. table.concat(withoutUiMap, ", "))
    end

    -- The live bridge is what the announce actually uses; the table is only its stand-in.
    -- They must agree, or a listing would name a different dungeon depending on which one
    -- answered first.
    local disagreeing, unresolved = {}, 0
    for activityID, mapID in pairs(AutoSay.ActivityToDungeon) do
        local info = C_LFGList and C_LFGList.GetActivityInfoTable
            and C_LFGList.GetActivityInfoTable(activityID)
        local live = info and self.ChallengeMapForUiMap(info.mapID)
        if not live then
            unresolved = unresolved + 1
        elseif live ~= mapID then
            disagreeing[#disagreeing + 1] = format("%d: table %d, live %d", activityID, mapID, live)
        end
    end
    check("the live activity bridge agrees with ActivityToDungeon", #disagreeing == 0,
        table.concat(disagreeing, "; "))
    if unresolved > 0 then
        self:Print(format("|cFFFFCC00NOTE|r %d activity(s) could not be resolved live "
            .. "- last season's ids, or activity data not loaded yet", unresolved))
    end

    -- Group E: 1.6 content (read-only)
    local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
    local Logic = AutoSay.MessageLogic

    local styleSet = {}
    for _, style in ipairs(AutoSay.MessageStyles) do styleSet[style] = true end

    -- rawget rather than L[key]: a missing key must be reported, not raised
    local unnamed = {}
    for _, style in ipairs(AutoSay.MessageStyles) do
        if type(rawget(L, "Style " .. style)) ~= "string" then unnamed[#unnamed + 1] = style end
    end
    check("every style bundle has a name in the locale", #unnamed == 0,
        'no L["Style <id>"] for: ' .. table.concat(unnamed, ", "))

    -- A phrase tagged with a style the tab does not list can never be switched on
    local stray, dupes = {}, {}
    for _, pool in ipairs(AutoSay.StylePools) do
        local seen = {}
        for _, msg in ipairs(AutoSay[pool.messages]) do
            if msg.style and not styleSet[msg.style] then
                stray[#stray + 1] = format("%s (%s)", msg.key, msg.style)
            end
            if seen[msg.key] then dupes[#dupes + 1] = pool.messages .. ":" .. msg.key end
            seen[msg.key] = true
        end
    end
    check("no phrase carries a style the Style tab does not list", #stray == 0,
        table.concat(stray, ", "))
    check("phrase keys are unique inside their pool", #dupes == 0, table.concat(dupes, ", "))

    local roleGaps = {}
    for _, style in ipairs(AutoSay.MessageStyles) do
        for _, role in ipairs({ "TANK", "HEALER", "DAMAGER" }) do
            local found = false
            for _, msg in ipairs(AutoSay.Greetings) do
                if msg.role == role and Logic.StyleMatches(msg, style) then found = true break end
            end
            if not found then roleGaps[#roleGaps + 1] = style .. "/" .. role end
        end
    end
    check("every style bundle has a phrase for every role", #roleGaps == 0,
        "missing: " .. table.concat(roleGaps, ", "))

    -- The guild login list and the three M+ lists are picked without MessageLogic.FitsContext,
    -- so a tag on one of them would be greyed by the panel and ignored by the sender. The
    -- panel is right about the ones that go through FitsContext, so keep these tag-free.
    local taggedPlain = {}
    for _, name in ipairs({ "GuildLoginGreetings", "KeyAnnounce",
                            "CompletionTimed", "CompletionDepleted" }) do
        for _, msg in ipairs(AutoSay[name] or {}) do
            if msg.role or msg.band or msg.faction or msg.trigger
                or msg.text:find("{role}", 1, true) then
                taggedPlain[#taggedPlain + 1] = name .. ":" .. msg.key
            end
        end
    end
    check("the lists sent without a context filter carry no tags", #taggedPlain == 0,
        "tagged: " .. table.concat(taggedPlain, ", ") .. " - the sender ignores those tags")

    local classTokens = {}
    for i = 1, GetNumClasses() do
        local _, token = GetClassInfo(i)
        if token then classTokens[token] = true end
    end
    local badHints, hinted = {}, {}
    for style, list in pairs(AutoSay.StyleClasses) do
        if not styleSet[style] then badHints[#badHints + 1] = "style " .. style end
        for _, token in ipairs(list) do
            if not classTokens[token] then badHints[#badHints + 1] = "class " .. token end
            hinted[token] = true
        end
    end
    check("class hints name a real bundle and a real class", #badHints == 0,
        table.concat(badHints, ", "))
    local unhinted = {}
    for token in pairs(classTokens) do
        if not hinted[token] then unhinted[#unhinted + 1] = token end
    end
    check("every class this client knows is named by some bundle", #unhinted == 0,
        "no hint mentions: " .. table.concat(unhinted, ", "))

    -- The LFR gate, asked the way the sender asks it. The four answers are collected inside a
    -- pcall so that a raise cannot walk out on the restore below.
    do
        local instance = self.db.profile.instance
        local savedSkip, savedMode = instance.skipRaidGroups, self.db.profile.testMode
        local savedType, savedRaid =
            self.testState.simulatedGroupType, self.testState.simulatedRaidInstance
        local silencedInLFR, silencedInDungeon, silencedWithToggleOff, partyUntouched

        local asked, askErr = pcall(function()
            self.db.profile.testMode = true
            self.testState.simulatedGroupType = "INSTANCE_CHAT"

            instance.skipRaidGroups = true
            self.testState.simulatedRaidInstance = true
            silencedInLFR = self:IsChannelSilenced("INSTANCE_CHAT")
            -- Asked while the toggle is still on: with it off, a gate that wrongly silenced
            -- every channel would answer "not silenced" here and look correct
            partyUntouched = self:IsChannelSilenced("PARTY")
            self.testState.simulatedRaidInstance = false
            silencedInDungeon = self:IsChannelSilenced("INSTANCE_CHAT")
            instance.skipRaidGroups = false
            self.testState.simulatedRaidInstance = true
            silencedWithToggleOff = self:IsChannelSilenced("INSTANCE_CHAT")
        end)

        instance.skipRaidGroups = savedSkip
        self.db.profile.testMode = savedMode
        self.testState.simulatedGroupType = savedType
        self.testState.simulatedRaidInstance = savedRaid

        if not asked then check("the LFR gate answered at all", false, tostring(askErr)) end
        check("the instance channel is silent in a raid-sized group", silencedInLFR == true,
            "a raid finder run would have been greeted")
        check("a 5-player instance group still speaks", silencedInDungeon == false,
            "the gate caught the groups it is meant to allow")
        check("the toggle switched off lets LFR through", silencedWithToggleOff == false,
            "the gate ignored its own setting")
        check("the gate is limited to INSTANCE_CHAT", partyUntouched == false,
            "party chat was silenced by an instance rule")
    end

    -- Group F: profile migrations, on a scratch profile that is deleted again. The name is
    -- claimed rather than assumed: deleting a profile a player happens to have called the
    -- same thing would be a far worse bug than the one this group is looking for.
    local taken = {}
    for _, name in ipairs(self.db:GetProfiles()) do taken[name] = true end
    local SCRATCH
    for i = 1, 100 do
        local candidate = "AutoSay self-test" .. (i > 1 and (" " .. i) or "")
        if not taken[candidate] then SCRATCH = candidate break end
    end
    local home = self.db:GetCurrentProfile()
    if not SCRATCH then
        self:Print("|cFFFFCC00SKIP|r migrations - no free name for a scratch profile")
    else
        local function Dump(value)
            if type(value) ~= "table" then return tostring(value) end
            local keys = {}
            for k in pairs(value) do keys[#keys + 1] = k end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
            local parts = {}
            for _, k in ipairs(keys) do
                parts[#parts + 1] = tostring(k) .. "=" .. Dump(value[k])
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end

        local ok, err = pcall(function()
            self.db:SetProfile(SCRATCH)
            local profile = self.db.profile
            -- Pretend this profile came from 1.5.x: it existed before the upgrade, its whole
            -- greeting selection has since been retired, and it never met a master switch
            self.priorProfiles[SCRATCH] = { party = {} }
            self.priorTimeOfDay[SCRATCH] = nil
            self.priorBandGoodbyes[SCRATCH] = nil
            wipe(profile.party.enabledGreetingsSelf)
            profile.party.enabledGreetingsSelf["retired_in_1_6"] = true
            -- A 1.6 profile as AceDB would have stored it: one changed phrase, nothing else
            profile.greetingSidesMigrated = nil
            profile.party.enabledGreetings = { hi = false }
            profile.greetingSidesMigrated = true -- the split already happened for this profile
            profile.instanceMigrated = nil
            profile.masterSwitchesMigrated = nil
            profile.retiredPhrasesMigrated = nil
            if profile.mythicplus then profile.mythicplus.keyLevelMigrated = nil end
            profile.social.timeOfDay = false

            self:RunProfileMigrations()

            -- Raid keeps its selection through all of this, so its greetings are still the
            -- stock set: the rescued party pool has to match it key for key, not merely
            -- hold more than one key
            check("a pool whose phrases were all retired gets the stock set back",
                Dump(profile.party.enabledGreetingsSelf) == Dump(profile.raid.enabledGreetingsSelf),
                "the restored set is not the stock one")

            check("an upgrade keeps the time-of-day phrases it already had",
                profile.social.timeOfDay == true, "the master switch was left off")

            -- On its own, away from the rescue: a stored list holds only what its owner
            -- changed, so a split that replaced the list instead of writing over it would
            -- take every untouched phrase with it - and the rescue would hide that by
            -- handing the stock set back.
            self.priorProfiles[SCRATCH] = nil -- no history, so nothing is rescued here
            profile.greetingSidesMigrated = nil
            profile.raid.enabledGreetings = { hi = false }
            self:MigrateGreetingSides()
            local kept, stored = 0, profile.raid.enabledGreetingsSelf
            for _ in pairs(stored) do kept = kept + 1 end
            check("a sparse stored list keeps the phrases it never mentioned",
                kept > 5 and stored.hi == false,
                format("%d phrase(s) left, hi=%s", kept, tostring(stored.hi)))
            self.priorProfiles[SCRATCH] = { party = {} }

            local afterFirst = Dump(profile)
            self:RunProfileMigrations()
            check("a second login changes nothing", Dump(profile) == afterFirst,
                "the migrations are not idempotent")

            self.db:ResetProfile()
            profile = self.db.profile
            local afterReset = Dump(profile)
            self:RunProfileMigrations()
            check("a reset profile stays on the defaults",
                Dump(profile) == afterReset and profile.social.timeOfDay == false,
                "the migrations undid Reset Profile")
        end)

        -- Each step of the way back is on its own: a raise in the first must not strand the
        -- player on the scratch profile with the rest of the cleanup unrun
        local backHome = pcall(function() self.db:SetProfile(home) end)
        if backHome then pcall(function() self.db:DeleteProfile(SCRATCH, true) end) end
        self.priorProfiles[SCRATCH] = nil
        self.priorTimeOfDay[SCRATCH] = nil
        self.priorBandGoodbyes[SCRATCH] = nil
        check("the player is back on their own profile", backHome
            and self.db:GetCurrentProfile() == home,
            "still on " .. tostring(self.db:GetCurrentProfile()) .. " - switch back by hand")
        if not ok then
            check("the migration checks ran to the end", false, tostring(err))
        end
    end

    self:Print(format("Self-test: %d/%d passed", passed, total))
    self:Print("|cFFFFCC00Still needs eyes:|r the Style tab layout and its colours, "
        .. "the greyed-out rows and columns, and the Social sliders sharing a row.")
end

-- The Group Finder's activity list is server data. Nothing asks for it until the Premade
-- Groups panel opens (LFGListFrame_OnShow calls RequestAvailableActivities), so on a client
-- that never opened it this session every activity query comes back empty.
local function MythicPlusFilters()
    if Enum and Enum.LFGListFilter and Enum.LFGListFilter.CurrentSeason and bit then
        return bit.bor(Enum.LFGListFilter.CurrentSeason, Enum.LFGListFilter.PvE or 0)
    end
    return 0
end

-- A group id of 0 means "activities that belong to no group", which is where the heroic,
-- normal and timewalking entries live. Every Mythic+ dungeon is a group of its own, so its
-- activity is only reachable through that group - the same walk the Group Finder's own
-- dropdown does (LFGList.lua: GetAvailableActivityGroups, then GetAvailableActivities).
local function CollectActivities(category, filters)
    local found = {}
    local groups = C_LFGList.GetAvailableActivityGroups
        and C_LFGList.GetAvailableActivityGroups(category, filters) or {}
    for _, groupID in ipairs(groups) do
        for _, id in ipairs(C_LFGList.GetAvailableActivities(category, groupID, filters) or {}) do
            found[#found + 1] = id
        end
    end
    for _, id in ipairs(C_LFGList.GetAvailableActivities(category, 0, filters) or {}) do
        found[#found + 1] = id
    end
    return found
end

local function DungeonActivities()
    if not (C_LFGList and C_LFGList.GetAvailableActivities) then return nil, "no API" end
    local category = GROUP_FINDER_CATEGORY_ID_DUNGEONS or 2
    local list = CollectActivities(category, MythicPlusFilters())
    if #list > 0 then return list, "current season" end
    -- An unfiltered walk still answers if the season filter is the part that came up empty
    list = CollectActivities(category, 0)
    if #list > 0 then return list, "unfiltered" end
    return nil, "empty"
end

-- Maintenance: harvest the current season's M+ pool as paste-ready Lua for Messages.lua.
-- Uses print() rather than self:Print() so the lines carry no addon prefix and paste cleanly.
function Addon:DumpDungeons()
    local maps = SeasonMaps()
    if not maps then
        self:Print("|cFFFF0000No M+ map data|r - C_ChallengeMode.GetMapTable() is empty. " ..
            "Try again once fully logged in, and only while a Mythic+ season is active.")
        return
    end

    print("|cFFFFCC00-- AutoSay.DungeonNames (Messages.lua) - names come from C_ChallengeMode.GetMapUIInfo|r")
    print("|cFFFFCC00-- and are in THIS CLIENT's language: run this on an enUS client for the English table.|r")
    -- Two ways to reach a challenge map id from an activity: the ui map id both APIs speak
    -- (language-proof, the sixth return of GetMapUIInfo) and the dungeon name (a last resort).
    local nameToMap, uiMapToMap = {}, {}
    for _, mapID in ipairs(maps) do
        local name = MapName(mapID)
        -- false marks a duplicate name, which we refuse to match an activity against
        if nameToMap[name] ~= nil then nameToMap[name] = false else nameToMap[name] = mapID end
        local uiMapID = C_ChallengeMode.GetMapUIInfo and select(6, C_ChallengeMode.GetMapUIInfo(mapID))
        if uiMapID then uiMapToMap[uiMapID] = mapID end
        print(format('    [%d] = "%s", -- %s, ui map %s', mapID, name,
            AutoSay.DungeonNames[mapID] and "known" or "NEW", tostring(uiMapID)))
    end

    local _, source = DungeonActivities()
    if source == "empty" and C_LFGList and C_LFGList.RequestAvailableActivities then
        C_LFGList.RequestAvailableActivities()
        self:Print("The Group Finder activity list was empty - asked the server for it, "
            .. "printing the activity table in a moment.")
        if C_Timer and C_Timer.After then
            C_Timer.After(2, function() self:DumpActivities(uiMapToMap, nameToMap) end)
            return
        end
    end
    self:DumpActivities(uiMapToMap, nameToMap)
end

-- Second half of /as dumpdungeons: the activityID -> mapChallengeModeID table, plus enough
-- numbers to tell a broken query apart from a query that simply matched nothing.
function Addon:DumpActivities(uiMapToMap, nameToMap)
    local activities, source = DungeonActivities()
    if not activities then
        print("|cFFFF0000-- No Group Finder activities to read (" .. source .. "). Open Premade|r")
        print("|cFFFF0000-- Groups once, close it, and run /as dumpdungeons again.|r")
        return
    end

    local lines, byMapCount, byNameCount, unmatched, seen = {}, 0, 0, {}, 0
    for _, activityID in ipairs(activities) do
        local info = C_LFGList.GetActivityInfoTable and C_LFGList.GetActivityInfoTable(activityID)
        if info and info.isMythicPlusActivity then
            seen = seen + 1
            local mapID = info.mapID and uiMapToMap[info.mapID]
            local how = "ui map"
            if mapID then
                byMapCount = byMapCount + 1
            else
                mapID = nameToMap[info.shortName] or nameToMap[info.fullName]
                how = "name"
                if mapID then byNameCount = byNameCount + 1 end
            end
            if mapID then
                lines[#lines + 1] = format("    [%d] = %d, -- %s (%s)", activityID, mapID,
                    info.shortName, how)
            else
                unmatched[#unmatched + 1] = format("%d %s (ui map %s)", activityID,
                    info.shortName or "?", tostring(info.mapID))
            end
        end
    end

    print(format("|cFFFFCC00-- %d activity(s) read (%s), %d of them Mythic+: %d matched by ui map, %d by name|r",
        #activities, source, seen, byMapCount, byNameCount))

    if #lines > 0 then
        print("|cFFFFCC00-- AutoSay.ActivityToDungeon (Messages.lua)|r")
        for _, line in ipairs(lines) do print(line) end
    end
    if #unmatched > 0 then
        print("|cFFFF0000-- unmatched: " .. table.concat(unmatched, ", ") .. "|r")
    end
    if #lines == 0 then
        print("|cFFFF0000-- Nothing resolved. Leave AutoSay.ActivityToDungeon as it is and|r")
        print("|cFFFF0000-- update it by hand rather than guessing.|r")
    end
end
