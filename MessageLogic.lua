-- Pure message/phrase logic with no WoW API or Ace dependency, so busted can load it
-- headless (same export pattern as Humanizer/SocialGate). Core/Config/WhatsNew alias
-- these instead of defining their own copies.
local _, ns = ...

local MessageLogic = {}

-- A stripped token can leave punctuation debris in any position: "departs, " (comma before),
-- ", here we go" (comma after a leading token), "gg, , wp" (comma on both sides). Sweep it all.
function MessageLogic.CleanupAfterTokenStrip(message)
    -- Adjacent stripped tokens leave a run of commas, and one pass only halves it
    -- ("a, , , b"), so collapse until there is nothing left to collapse
    local n = 1
    while n > 0 do
        message, n = message:gsub("%s*,%s*,", ",")
    end
    message = message:gsub("^[%s,]+", "")       -- leading comma from a stripped leading token
    message = message:gsub("[%s,]+$", "")       -- trailing comma from a stripped trailing token
    message = message:gsub("  +", " "):gsub("%s+([!?.,])", "%1")
    return message
end

-- Strip a list of literal "{token}" placeholders. A leading token takes its trailing
-- punctuation with it ("{key}! here we go" -> "here we go", not "! here we go"),
-- elsewhere the introducing comma goes with the token.
function MessageLogic.StripTokens(message, tokens)
    for _, token in ipairs(tokens) do
        message = message:gsub("^%s*" .. token .. "[%s!?.,]*", "")
        message = message:gsub(",?%s*" .. token, "")
    end
    return MessageLogic.CleanupAfterTokenStrip(message)
end

-- Names-carrying phrase with no names to carry: drop the slot instead of the phrase,
-- so a pool of only {names} phrases still says something ("welcome {names}!" -> "welcome!").
-- The comma introducing the slot goes with it: "welcome, {names} <3" -> "welcome <3".
function MessageLogic.StripNameSlot(text)
    return MessageLogic.CleanupAfterTokenStrip(text:gsub(",?%s*{names}", ""))
end

-- SendChatMessage rejects anything over 255 bytes: cut to 252 + "...", never inside a UTF-8 sequence
function MessageLogic.TruncateToChatLimit(message)
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

-- Preset phrases can be tagged with a role/faction/time-of-day band/trigger - skip the ones that do not fit right now
function MessageLogic.FitsContext(msg, role, faction, band, reason, rolePhrases)
    -- Master switch: every tag has its filter, and this one gates the role tag and {role}
    if not rolePhrases and (msg.role or msg.text:find("{role}", 1, true)) then return false end
    if msg.role and msg.role ~= role then return false end
    -- No assigned role: a {role} phrase would confidently announce "dps" for an unassigned tank
    if role == "NONE" and msg.text:find("{role}", 1, true) then return false end
    if msg.faction and msg.faction ~= faction then return false end
    if msg.band and msg.band ~= band then return false end
    -- Reason-less paths (guild logout, group goodbye) have no join to talk about,
    -- so a phrase written for one ("tank here, pull respectfully") never fits them
    if reason == nil then return msg.trigger == nil end
    -- Anything that is not someone else joining (self join, reconnect, guild login) counts as "self"
    if msg.trigger == "others" and reason ~= "others_join" then return false end
    if msg.trigger == "self" and reason == "others_join" then return false end
    return true
end

-- How a phrase carries player names: "slot" = {names} inside the text, "append" = glued to the end
function MessageLogic.NameMode(msg)
    if msg.text:find("{names}", 1, true) then return "slot" end
    if msg.appendNames then return "append" end
    return nil
end

-- Long name lists read like spam: keep four and count the rest
function MessageLogic.FormatNameList(names)
    if #names > 4 then
        return table.concat(names, ", ", 1, 4) .. " +" .. (#names - 4)
    end
    return table.concat(names, ", ")
end

-- Insert player names into a message per its name mode (nil = the phrase never carries names)
function MessageLogic.AddPlayersToMessage(message, playerNames, nameMode)
    if not nameMode or not playerNames or #playerNames == 0 then
        return message
    end
    local names = MessageLogic.FormatNameList(playerNames)
    if nameMode == "slot" then
        return (message:gsub("{names}", names))
    end
    return message .. " " .. names
end

-- Same key twice? Map ids are locale-proof, so they decide whenever both sides have one;
-- a name comparison is the fallback and can only ever compare like with like.
function MessageLogic.SameKey(a, b)
    if not a or not b then return false end
    if a.level ~= b.level then return false end
    if a.mapID and b.mapID then return a.mapID == b.mapID end
    return a.dungeon == b.dungeon
end

-- Whether a styled phrase belongs to this style. Faction is deliberately NOT part of the
-- bundle-apply decision (the profile is account-shared and FitsContext filters at send
-- time), but the "fully enabled" check uses it to ignore phrases this character can never say.
-- "classic" is the untagged pool the phrase lists show first: no style of its own, and no
-- time-of-day band either (those are their own section, and the Style tab has a master
-- switch for them, so a bundle must not reach in and flip them).
function MessageLogic.StyleMatches(msg, style)
    if style == "classic" then
        return msg.style == nil and msg.band == nil
    end
    return msg.style == style
end

function MessageLogic.StyleFits(msg, style, faction)
    return MessageLogic.StyleMatches(msg, style)
        and (not msg.faction or msg.faction == faction)
end

-- A goodbye at the end of a run answers to its own switch, not to the one that covers
-- leaving: someone can want both, either, or neither. It fires once per run, and never when
-- an M+ completion line is already speaking for that same ending.
function MessageLogic.SaysGoodbyeOnRunEnd(settings, alreadySent, completionSpoke)
    if not settings then return false end
    if alreadySent or completionSpoke then return false end
    if settings.enabled == false then return false end
    return settings.sendGoodbyeOnRunEnd and true or false
end

-- LFR and battlegrounds share INSTANCE_CHAT with a 5-player dungeon run, but talking to 25
-- or 40 strangers is a different thing than talking to your 4 group mates. The channel is
-- on by default, this keeps it to the small groups people actually queue together for.
function MessageLogic.SkipsRaidInstanceGroup(channel, settings, isRaidInstanceGroup)
    if channel ~= "INSTANCE_CHAT" then return false end
    if not settings or not settings.skipRaidGroups then return false end
    return isRaidInstanceGroup and true or false
end

-- "1.6" matches "1.6" and "1.6.2" but not "1.60.x", "11.6.x" or "2.0.x"
function MessageLogic.VersionMatchesMinor(addonVersion, minor)
    if not addonVersion or not minor then return false end
    return addonVersion == minor or addonVersion:sub(1, #minor + 1) == minor .. "."
end

-- Newest "major.minor" key of a version-keyed table, compared numerically
-- ("1.10" beats "1.9", which a string compare would get wrong)
function MessageLogic.NewestVersion(versions)
    local newest, newestValue
    for version in pairs(versions) do
        local major, minor = version:match("^(%d+)%.(%d+)$")
        local value = (tonumber(major) or 0) * 1000 + (tonumber(minor) or 0)
        if not newestValue or value > newestValue then
            newest, newestValue = version, value
        end
    end
    return newest
end

-- The instance channel is new: before it existed LFG groups used the party settings, so
-- seed it from them once (toggles, phrase selections and custom lists - a user who narrowed
-- the party phrases down must not get the stock set back in LFG). Entry tables are cloned,
-- not shared. Returns true when the migration ran.
-- A pool that can no longer say anything: every preset the user had ticked is gone from the
-- inventory (phrases do get retired between versions) and no custom line fills the gap.
-- Restoring the defaults there is the difference between "my list changed" and "the addon
-- went quiet". validKeys is the set of keys the current build still ships for that pool.
-- validKeys maps a key to true when the phrase counts as something the pool can say, to
-- false when the build still ships it but it cannot speak for itself (a time-of-day phrase
-- waits on a master switch, and AceDB hands those out enabled), and to nil when the phrase
-- is gone. Counting a default-injected band phrase as content is what let a pool look alive
-- right up to the moment the band phrases were switched off again.
function MessageLogic.PoolIsSilent(enabled, validKeys, customs)
    if customs then
        for _, entry in ipairs(customs) do
            if entry.enabled and entry.text and entry.text:match("%S") then return false end
        end
    end
    if enabled then
        for key, on in pairs(enabled) do
            if on and validKeys[key] == true then return false end
        end
    end
    return true
end

-- Silence alone is not a reason to hand the stock phrases back: a pool can be empty because
-- the user unticked every line on purpose, and overriding that would be worse than the
-- problem. Only a pool that is silent AND still holds a tick for a phrase this build no
-- longer ships lost its selection to the release rather than to its owner.
function MessageLogic.PoolLostItsPhrases(enabled, validKeys, customs)
    if not enabled then return false end
    if not MessageLogic.PoolIsSilent(enabled, validKeys, customs) then return false end
    for key, on in pairs(enabled) do
        if on and validKeys[key] == nil then return true end
    end
    return false
end

function MessageLogic.MigrateInstanceChannel(profile)
    if profile.instanceMigrated then return false end

    local party, instance = profile.party, profile.instance
    instance.enabled = party.enabled
    instance.onSelfJoin = party.onSelfJoin
    instance.onOthersJoin = party.onOthersJoin
    instance.onOthersJoinLeaderOnly = party.onOthersJoinLeaderOnly
    instance.includeNames = party.includeNames
    instance.includeGroupNames = party.includeGroupNames
    instance.sendGoodbye = party.sendGoodbye

    local function CloneFlags(t)
        if not t then return nil end
        local copy = {}
        for k, v in pairs(t) do copy[k] = v end
        return copy
    end
    local function CloneCustoms(list)
        if not list then return nil end
        local copy = {}
        for i, entry in ipairs(list) do
            copy[i] = { text = entry.text, enabled = entry.enabled }
        end
        return copy
    end
    if party.enabledGreetings then instance.enabledGreetings = CloneFlags(party.enabledGreetings) end
    if party.enabledGoodbyes then instance.enabledGoodbyes = CloneFlags(party.enabledGoodbyes) end
    instance.customGreetings = CloneCustoms(party.customGreetings)
    instance.customGoodbyes = CloneCustoms(party.customGoodbyes)

    profile.instanceMigrated = true
    return true
end

-- "basic"/"withlevel"/"smart" collapsed into one toggle. Only "withlevel"/"smart" asked for
-- a level, so only those lift the (now false) default. A missing messageMode means "basic":
-- AceDB strips values equal to the default, and "basic" was that default.
-- Returns true when a stored mode was lifted.
function MessageLogic.MigrateKeyLevelMode(mplus)
    if mplus.keyLevelMigrated then return false end

    local lifted = false
    if mplus.messageMode == "withlevel" or mplus.messageMode == "smart" then
        mplus.includeKeyLevel = true
        lifted = true
    end
    mplus.messageMode = nil

    mplus.keyLevelMigrated = true
    return lifted
end

if ns then ns.MessageLogic = MessageLogic end
return MessageLogic
