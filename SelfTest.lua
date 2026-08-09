local ADDON_NAME, AutoSay = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)

local format = string.format
local HOUR = 3600

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

    self:Print(format("Self-test: %d/%d passed", passed, total))
end
