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

    self:Print(format("Self-test: %d/%d passed", passed, total))
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
    local nameToMap = {}
    for _, mapID in ipairs(maps) do
        local name = MapName(mapID)
        -- false marks a duplicate name, which we refuse to match an activity against
        if nameToMap[name] ~= nil then nameToMap[name] = false else nameToMap[name] = mapID end
        print(format('    [%d] = "%s", -- %s', mapID, name, AutoSay.DungeonNames[mapID] and "known" or "NEW"))
    end

    -- LFG gives no direct activityID -> mapChallengeModeID link, so match on the dungeon name both
    -- APIs return in the client's language, and emit only unambiguous matches.
    local lines, unmatched = {}, 0
    local filters = 0
    if Enum and Enum.LFGListFilter and bit then
        filters = bit.bor(Enum.LFGListFilter.CurrentSeason, Enum.LFGListFilter.PvE)
    end
    local activities = C_LFGList and C_LFGList.GetAvailableActivities
        and C_LFGList.GetAvailableActivities(GROUP_FINDER_CATEGORY_ID_DUNGEONS or 2, 0, filters)
    if type(activities) == "table" then
        for _, activityID in ipairs(activities) do
            local info = C_LFGList.GetActivityInfoTable and C_LFGList.GetActivityInfoTable(activityID)
            if info and info.isMythicPlusActivity then
                local mapID = nameToMap[info.shortName] or nameToMap[info.fullName]
                if mapID then
                    lines[#lines + 1] = format("    [%d] = %d, -- %s", activityID, mapID, info.shortName)
                else
                    unmatched = unmatched + 1
                end
            end
        end
    end

    if #lines > 0 then
        print("|cFFFFCC00-- AutoSay.ActivityToDungeon (Messages.lua) - matched by dungeon name, check the comments|r")
        for _, line in ipairs(lines) do print(line) end
        if unmatched > 0 then
            print(format("|cFFFF0000-- %d Mythic+ activity(s) had no unambiguous map match - add those by hand|r", unmatched))
        end
    else
        print("|cFFFF0000-- Could not resolve LFG activity IDs automatically. Leave AutoSay.ActivityToDungeon|r")
        print("|cFFFF0000-- as it is and update it by hand rather than guessing.|r")
    end
end
