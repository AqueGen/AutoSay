local ADDON_NAME, AutoSay = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)

-- Register all events
function Addon:RegisterEvents()
    -- Group events
    self:RegisterEvent("GROUP_JOINED")
    self:RegisterEvent("GROUP_LEFT")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")

    -- Player login for guild greeting
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    -- Guild member online detection (Club/Communities API)
    -- Disabled until member login greeting feature is fully working
    -- self:RegisterEvent("CLUB_MEMBER_PRESENCE_UPDATED")

    -- Club system initialization (needed before Club API is reliable)
    self:RegisterEvent("INITIAL_CLUBS_LOADED")

    -- Player logout for guild goodbye
    self:RegisterEvent("PLAYER_LOGOUT")

    -- LFG listing updates (for M+ key announce)
    self:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
    self:RegisterEvent("LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS")

    -- M+ keystone activated / dungeon completion
    self:RegisterEvent("CHALLENGE_MODE_START")
    self:RegisterEvent("CHALLENGE_MODE_RESET")
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED")

    -- Chat listening for social gate (pending-intent confirmation, welcome tracking).
    -- Only guild triggers create pending slots, so guild chat is the only channel worth watching.
    self:RegisterEvent("CHAT_MSG_GUILD", "OnSocialChat")
    self:RegisterEvent("CHAT_MSG_GUILD_ACHIEVEMENT", "OnGuildAchievement")
    self:RegisterEvent("CHAT_MSG_SYSTEM", "OnSystemMessage")

    self:DebugPrint("Events registered")
end

local CHAT_EVENT_CHANNEL = {
    CHAT_MSG_GUILD = "GUILD",
}

-- Listen to guild chat for the social gate (welcome tracking, pending-intent confirmation)
function Addon:OnSocialChat(event, text, sender)
    if not self.socialGate then return end
    if not self.db.profile.social.listen then return end
    local me = UnitName("player")
    local senderName = sender and sender:match("^([^%-]+)") or sender
    if senderName == me then return end
    self.socialGate:OnChatMessage(CHAT_EVENT_CHANNEL[event], senderName, text)
end

-- Handle CHAT_MSG_GUILD_ACHIEVEMENT - guildmate earned an achievement, offer congrats
function Addon:OnGuildAchievement(event, message, sender)
    if not self.db.profile.enabled then return end
    if not self.db.profile.social.guildGrats then return end
    local name = (sender and sender:match("^([^%-]+)")) or message:match("^([^%s]+)")
    if not name or name == UnitName("player") then return end
    self:SendGuildGrats(name)
end

-- ERR_GUILD_JOIN_S = "%s has joined the guild." - built lazily (not always available
-- at file scope depending on client/load order) from the global so non-English clients work too.
local guildJoinPattern
local function GetGuildJoinPattern()
    if guildJoinPattern == nil and ERR_GUILD_JOIN_S then
        -- Escape every Lua pattern magic char first (this turns the "%s" placeholder into
        -- an escaped literal "%%s"), then swap that placeholder for the name capture.
        local escaped = ERR_GUILD_JOIN_S:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1")
        guildJoinPattern = "^" .. escaped:gsub("%%%%s", "(%%S+)") .. "$"
    end
    return guildJoinPattern
end
Addon.GetGuildJoinPattern = GetGuildJoinPattern -- exposed for /as selftest

-- Handle CHAT_MSG_SYSTEM - detect new guild member joins to offer a welcome
function Addon:OnSystemMessage(event, message)
    if not self.db.profile.enabled then return end
    if not self.db.profile.social.guildWelcome then return end
    local pattern = GetGuildJoinPattern()
    if not pattern then return end
    local name = message:match(pattern)
    name = name and name:match("^([^%-]+)") or name
    if not name or name == UnitName("player") then return end
    self:SendGuildWelcome(name)
end

-- Handle GROUP_JOINED - we joined a group. Fires once per category (home/instance);
-- the payload says which one this event is about.
function Addon:GROUP_JOINED(event, category)
    self:DebugPrint("EVENT: GROUP_JOINED - We joined a group, category:", tostring(category))

    local db = self.db.profile

    -- An instance group forming NEXT TO a live home group must not wipe that home group's
    -- state: the M+ listing, announce guards and in-flight sends all belong to the home
    -- party (queueing a BG while your key group is listed is exactly this)
    local homeSurvives = category == LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_HOME)

    if not homeSurvives then
        -- Clear stale M+ listing cache when joining a new group
        -- (prevents announce from firing with old data when joining someone else's group)
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
        -- A delayed send still in flight belongs to the previous group - typing delays reach
        -- ~7s, long enough to leave one party and join another before the line goes out
        for handle in pairs(self.state.pendingGroupSends) do
            self:CancelTimer(handle)
        end
        self.state.pendingGroupSends = {}
    end
    -- Join time is where the once-per-group guards reset: GROUP_LEFT fires milliseconds
    -- after the leave hook, which would make the goodbye guard useless
    self.state.groupGoodbyeSent = false
    if self.state.groupGoodbyeTimer then
        self:CancelTimer(self.state.groupGoodbyeTimer)
        self.state.groupGoodbyeTimer = nil
    end
    -- A new instance group forming must drop the previous instance group's greet flag
    -- (IsInGroup(INSTANCE) is already true at this point, so the category payload is the
    -- only way to tell "this instance group is new" from "a home party joined alongside
    -- an already-greeted instance group" - the latter must keep the flag)
    if category == LE_PARTY_CATEGORY_INSTANCE or not IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        self:SetInstanceGreeted(false)
    end

    if not db.enabled then return end

    -- Delay to allow raid/party state to fully initialize
    self:ScheduleTimer(function()
        -- Initialize group tracking
        self.state.previousGroup = self:GetCurrentGroupMembers()
        self.state.sentGreetings = {}

        -- Determine channel type
        local channel = self:GetChatChannel()
        self.state.currentGroupType = channel
        if not channel then
            self:DebugPrint("Not in group after delay, skipping greeting")
            return
        end

        self:DebugPrint("Detected group type:", channel)

        -- Instance groups are greeted on zone-in (PLAYER_ENTERING_WORLD), not on group form
        if channel == "INSTANCE_CHAT" then
            self:DebugPrint("Instance group - greeting handled by the zone-in path")
            return
        end

        -- If we're the group leader, we created the group - don't send self_join greeting
        -- The others_join greeting will handle welcoming people who joined our group
        if UnitIsGroupLeader("player") then
            self:DebugPrint("We're the leader (created group), skipping self_join greeting")
            return
        end

        -- Check per-channel settings
        if not self:ShouldGreetOnSelfJoin(channel) then
            self:DebugPrint("Self join greetings disabled for", channel)
            return
        end

        -- Send greeting
        self:SendGreeting(self:CollectGroupMemberNames(self:GetChannelSettings(channel)), "self_join")
    end, 1) -- 1 second delay for group state to initialize
end

-- Handle GROUP_LEFT - we left a group. Fires once per category (home/instance).
function Addon:GROUP_LEFT(event, category)
    self:DebugPrint("EVENT: GROUP_LEFT - We left the group, category:", tostring(category))

    -- Note: Goodbye is now sent via HookLeaveGroupFunctions() BEFORE leaving
    -- This event fires AFTER we've already left, so we just reset state here

    -- Leaving one category while the other survives (left the LFR while keeping the home
    -- party, or vice versa): the surviving group keeps its roster and M+ state - a full
    -- reset here would wipe greeting tracking for people still grouped with us
    local otherCategory = category == LE_PARTY_CATEGORY_INSTANCE
        and LE_PARTY_CATEGORY_HOME or LE_PARTY_CATEGORY_INSTANCE
    if category and IsInGroup(otherCategory) then
        if category == LE_PARTY_CATEGORY_INSTANCE then
            self:SetInstanceGreeted(false)
        end
        self.state.previousGroup = self:GetCurrentGroupMembers()
        self.state.currentGroupType = self:GetChatChannel()
        -- Members of the departed category are gone from previousGroup, so the roster
        -- diff can never clear their greeted flags - prune them here or an ex-groupmate
        -- who later joins the surviving group would never be greeted
        for key in pairs(self.state.sentGreetings) do
            if not self.state.previousGroup[key] then
                self.state.sentGreetings[key] = nil
            end
        end
        -- A newcomer batch collected in the departed category must not fire into the
        -- surviving group's chat - the batch callback re-resolves the channel live
        if self.state.pendingGreetTimer then
            self:CancelTimer(self.state.pendingGreetTimer)
            self.state.pendingGreetTimer = nil
        end
        self.state.pendingNewMembers = {}
        return
    end

    -- Reset state
    self.state.previousGroup = nil
    self.state.sentGreetings = {}
    self.state.currentGroupType = nil
    -- groupGoodbyeSent is deliberately NOT cleared here: this event fires right after the
    -- leave hook sent the goodbye, so clearing it would re-arm the guard for a double leave.
    -- GROUP_JOINED (and the login group init) owns the reset.
    self.state.pendingNewMembers = {}
    if self.state.pendingGreetTimer then
        self:CancelTimer(self.state.pendingGreetTimer)
        self.state.pendingGreetTimer = nil
    end
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
    self.state.cachedLFGListing = nil
    self:SetInstanceGreeted(false)
end

-- Handle GROUP_ROSTER_UPDATE - group composition changed
function Addon:GROUP_ROSTER_UPDATE()
    self:DebugPrint("EVENT: GROUP_ROSTER_UPDATE triggered")

    local db = self.db.profile

    if not db.enabled then return end

    -- Update current group type
    self.state.currentGroupType = self:GetChatChannel()

    self:DebugPrint("Group type:", self.state.currentGroupType, "Size:", GetNumGroupMembers())

    -- Debug: show all units and their connection status. Gated on the flag, not left to
    -- DebugPrint - a 40-man raid would pay 40 rounds of tostring/concat for nothing.
    if db.debugMode then
        local isRaid = IsInRaid()
        for i = 1, GetNumGroupMembers() do
            local unitID = isRaid and ("raid" .. i) or ("party" .. i)
            local name = UnitName(unitID)
            local connected = UnitIsConnected(unitID)
            local exists = UnitExists(unitID)
            self:DebugPrint("  Unit:", unitID, "Name:", tostring(name), "Exists:", tostring(exists), "Connected:", tostring(connected))
        end
    end

    -- Get current group members (presence-based; disconnected members still count as present)
    local currentGroup, connected = self:GetCurrentGroupMembers()
    local playerName = UnitName("player")

    self:DebugPrint("Current connected members:", self:TableKeysToString(currentGroup))
    self:DebugPrint("Previous members:", self:TableKeysToString(self.state.previousGroup))

    -- First run - initialize state
    if not self.state.previousGroup then
        self:DebugPrint("First roster update - initializing state")
        self.state.previousGroup = currentGroup
        return
    end

    -- Find members who left (to clear their greeting status for re-join).
    -- Keys are full Name-Realm; the stored value is the short display name.
    for key in pairs(self.state.previousGroup) do
        if not currentGroup[key] and key ~= playerName then
            self:DebugPrint("Member left group:", key)
            -- Clear greeting status so they get greeted if they rejoin
            self.state.sentGreetings[key] = nil
        end
    end

    -- Find newly joined members (only once they are connected - someone still on a load
    -- screen is not a joiner yet, and stays out of previousGroup so a later roster update
    -- with them connected can still greet them once)
    local newMembers = {}
    local newPrevious = {}
    for key, displayName in pairs(currentGroup) do
        local known = self.state.previousGroup[key] or key == playerName
        if known then
            newPrevious[key] = displayName
        elseif not connected[key] then
            self:DebugPrint("New member seen but not connected yet, deferring:", key)
        else
            newPrevious[key] = displayName
            self:DebugPrint("Detected new member:", key, "Already greeted:", tostring(self.state.sentGreetings[key]))
            -- Check if we already greeted this player
            if not self.state.sentGreetings[key] then
                table.insert(newMembers, displayName)
                self.state.sentGreetings[key] = true
                self:DebugPrint("Added to newMembers:", key)
            end
        end
    end

    -- Update state
    self.state.previousGroup = newPrevious

    -- If others joined, batch them before sending greeting
    -- (GROUP_ROSTER_UPDATE fires multiple times when a group of players joins)
    if #newMembers > 0 then
        self:DebugPrint("New members detected:", table.concat(newMembers, ", "))

        local channel = self.state.currentGroupType
        if channel and self:ShouldGreetOnOthersJoin(channel) then
            -- Add to pending batch
            for _, name in ipairs(newMembers) do
                self.state.pendingNewMembers[name] = true
            end

            -- Start batch timer only if not already running
            -- (subsequent joiners just accumulate in pendingNewMembers)
            if not self.state.pendingGreetTimer then
                local batchWindow = 2 -- seconds to collect rapid GROUP_ROSTER_UPDATE events
                self.state.pendingGreetTimer = self:ScheduleTimer(function()
                    local names = {}
                    for name in pairs(self.state.pendingNewMembers) do
                        table.insert(names, name)
                    end
                    self.state.pendingNewMembers = {}
                    self.state.pendingGreetTimer = nil

                    if #names > 0 then
                        self:DebugPrint("Sending batched greeting for:", table.concat(names, ", "))
                        self:SendGreeting(names, "others_join")
                    end
                end, batchWindow)
            end
        else
            self:DebugPrint("Others join greeting disabled for", channel or "unknown")
        end
    end

    -- M+ key announce: reset flag when group drops below 5
    if self.state.keyAnnounced and GetNumGroupMembers() < 5 then
        self.state.keyAnnounced = false
        self:DebugPrint("Group dropped below 5, key announce reset")
    end

    -- M+ key announce: check if group is full 5/5
    if db.mythicplus and db.mythicplus.enabled
       and db.mythicplus.announceOnFull
       and not self.state.keyAnnounced
       and GetNumGroupMembers() == 5
       and UnitIsGroupLeader("player") then

        -- Check if we have cached LFG listing data for a M+ key
        if self.state.cachedLFGListing and self.state.cachedLFGListing.isMythicPlus then
            self.state.keyAnnounced = true
            self:DebugPrint("Group full 5/5 with M+ listing, scheduling key announce")
            -- Small delay to send after any greeting messages. Tracked so a new group
            -- cancels it, and revalidated - someone can leave inside the two seconds.
            local handles = self.state.pendingGroupSends
            local handle
            handle = self:ScheduleTimer(function()
                handles[handle] = nil
                if not self.state.keyAnnounced or GetNumGroupMembers() ~= 5 then
                    self:DebugPrint("Key announce no longer valid, dropping")
                    return
                end
                self:SendKeyAnnounce()
            end, 2)
            handles[handle] = true
        else
            self:DebugPrint("Group full 5/5 but no M+ listing cached")
        end
    end
end

-- Handle LFG_LIST_ACTIVE_ENTRY_UPDATE - cache listing data for M+ key announce
function Addon:LFG_LIST_ACTIVE_ENTRY_UPDATE()
    if not C_LFGList or not C_LFGList.GetActiveEntryInfo then return end

    -- Only cache listing data if we are the group leader (listing creator)
    -- This event can fire for non-leaders too, but the data may be unreliable
    if not UnitIsGroupLeader("player") then
        self:DebugPrint("LFG_LIST_ACTIVE_ENTRY_UPDATE: not the leader, ignoring")
        return
    end

    local entryData = C_LFGList.GetActiveEntryInfo()
    if entryData then
        -- API returns activityIDs (array), not activityID
        local activityID = entryData.activityIDs and entryData.activityIDs[1]
        if not activityID then
            self:DebugPrint("LFG listing has no activityIDs, skipping")
            return
        end

        local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
        local fullName = activityInfo and activityInfo.fullName or nil
        local isMythicPlus = activityInfo and activityInfo.isMythicPlusActivity or false

        self.state.cachedLFGListing = {
            activityID = activityID,
            title = entryData.name or "",
            dungeonName = fullName,
            isMythicPlus = isMythicPlus,
        }

        self:DebugPrint("LFG listing cached:", fullName or "unknown",
            "title:", entryData.name or "none", "isM+:", tostring(isMythicPlus))
    else
        -- Listing removed (delisted) - keep cache for pending announce
        self:DebugPrint("LFG listing removed (keeping cache)")
    end
end

-- Handle LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS - group filled via Group Finder
function Addon:LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS()
    self:DebugPrint("EVENT: LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS - listing auto-delisted (group full)")

    local db = self.db.profile
    if not db.enabled then return end
    if not db.mythicplus or not db.mythicplus.enabled or not db.mythicplus.announceOnFull then return end
    if self.state.keyAnnounced then return end
    if not UnitIsGroupLeader("player") then
        self:DebugPrint("Not the leader, skipping key announce")
        return
    end

    -- Check if we have cached M+ listing data
    if self.state.cachedLFGListing and self.state.cachedLFGListing.isMythicPlus then
        self.state.keyAnnounced = true
        self:DebugPrint("M+ listing delisted (group full), scheduling key announce")
        -- Small delay to send after any greeting messages. Tracked so a new group
        -- cancels it, and revalidated - someone can leave inside the two seconds.
        local handles = self.state.pendingGroupSends
        local handle
        handle = self:ScheduleTimer(function()
            handles[handle] = nil
            if not self.state.keyAnnounced or GetNumGroupMembers() ~= 5 then
                self:DebugPrint("Key announce no longer valid, dropping")
                return
            end
            self:SendKeyAnnounce()
        end, 2)
        handles[handle] = true
    else
        self:DebugPrint("Listing delisted but no M+ cache available")
    end
end

-- Handle CHALLENGE_MODE_START - a keystone was activated. This reads the key that actually
-- went into the font, so it is right even after a lead swap or when someone else's key is used.
function Addon:CHALLENGE_MODE_START(event, mapID)
    self:DebugPrint("EVENT: CHALLENGE_MODE_START")

    local db = self.db.profile
    if not db.enabled then return end
    if not db.mythicplus or not db.mythicplus.enabled or not db.mythicplus.announceOnStart then return end

    -- The event fires on all five clients. Without this gate every party member running
    -- AutoSay would post the same line - the SameKey dedupe is client-local and cannot
    -- see what another client announced. Same gate as the two group-full announce paths.
    if not UnitIsGroupLeader("player") and not self:IsTestMode() then
        self:DebugPrint("Not the leader, skipping key start announce")
        return
    end

    if self.state.startAnnounced then
        self:DebugPrint("Key start already announced for this run")
        return
    end

    if not C_ChallengeMode or not C_ChallengeMode.GetActiveKeystoneInfo then return end

    local level = C_ChallengeMode.GetActiveKeystoneInfo()
    if not level or level < 2 then
        self:DebugPrint("No valid active keystone level (", tostring(level), "), skipping start announce")
        return
    end

    -- GetActiveChallengeMapID is documented to return a mapChallengeModeID - the id space
    -- GetMapUIInfo and our DungeonNames table expect. The event payload is only declared as
    -- an untyped "mapID", so it is the fallback, not the primary.
    mapID = (C_ChallengeMode.GetActiveChallengeMapID and C_ChallengeMode.GetActiveChallengeMapID()) or mapID
    local localizedName = mapID and C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(mapID) or nil
    local dungeon = self:GetDungeonName(mapID, localizedName)

    self.state.startAnnounced = true
    self:SendKeyStartAnnounce(dungeon, db.mythicplus.includeKeyLevel and level or nil, mapID)
end

-- Handle CHALLENGE_MODE_RESET - the run was reset and can start again, so it earns
-- another start announce. A key already announced stays deduped via announcedKey: the
-- same key re-inserted after a reset is not news.
function Addon:CHALLENGE_MODE_RESET()
    self:DebugPrint("EVENT: CHALLENGE_MODE_RESET")
    self.state.startAnnounced = false
    if self.state.startAnnounceTimer then
        self:CancelTimer(self.state.startAnnounceTimer)
        self.state.startAnnounceTimer = nil
    end
end

-- Handle CHALLENGE_MODE_COMPLETED - M+ dungeon finished (timed or depleted)
function Addon:CHALLENGE_MODE_COMPLETED()
    self:DebugPrint("EVENT: CHALLENGE_MODE_COMPLETED")

    -- The next run may be the very same key, and that one deserves its own announce
    self.state.startAnnounced = false
    self.state.announcedKey = nil
    if self.state.startAnnounceTimer then
        self:CancelTimer(self.state.startAnnounceTimer)
        self.state.startAnnounceTimer = nil
    end

    local db = self.db.profile
    if not db.enabled then return end
    if not db.mythicplus or not db.mythicplus.enabled or not db.mythicplus.completionEnabled then return end

    if not C_ChallengeMode or not C_ChallengeMode.GetChallengeCompletionInfo then return end

    local info = C_ChallengeMode.GetChallengeCompletionInfo()
    if not info then
        self:DebugPrint("No completion info available")
        return
    end

    -- Skip practice runs
    if info.practiceRun then
        self:DebugPrint("Practice run, skipping completion message")
        return
    end

    -- Get dungeon name (English by default, client locale if enabled)
    local localizedName = nil
    if C_ChallengeMode.GetMapUIInfo then
        localizedName = C_ChallengeMode.GetMapUIInfo(info.mapChallengeModeID)
    end
    local dungeonName = self:GetDungeonName(info.mapChallengeModeID, localizedName)

    local keyLevel = info.level
    local onTime = info.onTime
    local upgrade = info.keystoneUpgradeLevels or 0

    -- Format completion time as mm:ss
    local timeSec = (info.time or 0) / 1000
    local minutes = math.floor(timeSec / 60)
    local seconds = math.floor(timeSec % 60)
    local timeFormatted = string.format("%d:%02d", minutes, seconds)

    self:DebugPrint("M+ completed:", dungeonName, "+", keyLevel,
        "onTime:", tostring(onTime), "upgrade:", upgrade, "time:", timeFormatted)

    -- Small delay so it doesn't overlap with Blizzard's completion UI. Tracked so joining
    -- a different group inside the delay cancels it instead of congratulating strangers.
    local handles = self.state.pendingGroupSends
    local handle
    handle = self:ScheduleTimer(function()
        handles[handle] = nil
        self:SendCompletionMessage(dungeonName, keyLevel, onTime, upgrade, timeFormatted)
    end, 3)
    handles[handle] = true
end

-- Handle PLAYER_ENTERING_WORLD - for guild greeting on login and group reconnect
function Addon:PLAYER_ENTERING_WORLD(event, isInitialLogin, isReloadingUi)
    self:DebugPrint("EVENT: PLAYER_ENTERING_WORLD", "isInitialLogin:", tostring(isInitialLogin), "isReloadingUi:", tostring(isReloadingUi))

    -- Update cached guild status
    self:UpdateGuildStatus()

    -- Reset guild presence tracking only on login/reload (not zone changes)
    if isInitialLogin or isReloadingUi then
        self.state.guildPresenceReady = false
        self.state.guildMemberPresence = {}
        -- A login within 5 minutes of the last logout is a reconnect, not an arrival:
        -- guildmates saw us a moment ago, so skip the hello. lastSeenBeforeLogin is the
        -- PREVIOUS session's heartbeat (snapshotted in OnEnable before this session starts
        -- stamping) and covers hard DCs, where PLAYER_LOGOUT never gets to run.
        local lastSeen = math.max(self.db.char.lastLogoutTime or 0, self.state.lastSeenBeforeLogin or 0)
        local sinceLogout = time() - lastSeen
        local isReconnect = isInitialLogin and sinceLogout < 300
        if isReconnect then
            self:DebugPrint("Login", sinceLogout, "s after logout - treating as reconnect, no guild greeting")
        end
        self.state.pendingGuildGreeting = isInitialLogin and not isReconnect -- Flag: send guild greeting after clubs load
        self:DebugPrint("Guild presence reset, waiting for INITIAL_CLUBS_LOADED")

        -- Fallback: if INITIAL_CLUBS_LOADED already fired or never fires, force init after 20s
        self:ScheduleTimer(function()
            -- Disabled until member login greeting feature is fully working
            -- if not self.state.guildPresenceReady then
            --     self:DebugPrint("INITIAL_CLUBS_LOADED fallback: forcing guild presence init")
            --     self:SnapshotGuildPresence()
            -- end
            if self.state.pendingGuildGreeting then
                self.state.pendingGuildGreeting = false
                self:DebugPrint("Fallback: sending deferred guild greeting")
                self:UpdateGuildStatus()
                if IsInGuild() then
                    self:SendGuildGreeting()
                end
            end
        end, 20)
    end

    -- Restore / clear the persisted instance-greet flag before the zone-in check below:
    -- a /reload (or a relog into the same group) must not greet the same group a second time,
    -- and leaving the group behind must not carry the flag into the next one
    if isInitialLogin or isReloadingUi then
        -- Restore unconditionally: on initial login IsInGroup() can still be false while the
        -- group data loads, and clearing here would re-greet a group we already greeted before
        -- the disconnect. A genuinely left-behind group clears the flag via GROUP_JOINED/LEFT.
        self.state.instanceGreeted = self.db.char.instanceGreeted.done or false
        self:DebugPrint("Restored instance greeted flag:", tostring(self.state.instanceGreeted))
    end

    -- Greet the instance group once after zoning in (covers reconnects too, since a login
    -- inside an instance fires this event as well)
    if self.db.profile.enabled and IsInInstance() and not self.state.instanceGreeted then
        self:ScheduleTimer(function()
            self:HandleInstanceEnter()
        end, 3) -- Delay for chat/group state to settle after the load screen
    end

    -- Initialize group state if already in a group. Only on login/reload: this event also
    -- fires on every zone change, and re-arming the goodbye guard mid-group would let a
    -- second LeaveParty post a second goodbye.
    if isInitialLogin or isReloadingUi then
        if IsInGroup() then
            self.state.previousGroup = self:GetCurrentGroupMembers()
            self.state.currentGroupType = self:GetChatChannel()
            self.state.groupGoodbyeSent = false -- fresh session in this group: re-arm the goodbye guard

            -- Handle reconnect to existing group (login while already in a group)
            -- This is different from GROUP_JOINED which fires when joining a NEW group
            if isInitialLogin and not isReloadingUi then
                self:DebugPrint("Reconnect detected - already in group on login")
                self:ScheduleTimer(function()
                    self:HandleGroupReconnect()
                end, 3) -- Delay for group state to fully initialize (increased for 12.0 compatibility)
            end
        elseif isInitialLogin and not isReloadingUi then
            -- Group state might not be available yet on 12.0+
            -- Schedule a retry to check if we're actually in a group
            self:DebugPrint("Initial login but not in group yet - scheduling reconnect check retry")
            self:ScheduleTimer(function()
                if IsInGroup() then
                    self:DebugPrint("Reconnect retry: now in group, handling reconnect")
                    self.state.previousGroup = self:GetCurrentGroupMembers()
                    self.state.currentGroupType = self:GetChatChannel()
                    self:HandleGroupReconnect()
                else
                    self:DebugPrint("Reconnect retry: still not in group, no reconnect needed")
                end
            end, 5) -- Longer delay for group state to load after disconnect
        end
    end
end

-- Greet the instance group after zoning in - fires once per group, not per load screen
function Addon:HandleInstanceEnter()
    if self.state.instanceGreeted then return end

    if self:GetChatChannel() ~= "INSTANCE_CHAT" or not IsInInstance() then
        self:DebugPrint("Not in an instance group after delay, skipping instance greeting")
        return
    end

    if not self:ShouldGreetOnSelfJoin("INSTANCE_CHAT") then
        self:DebugPrint("Instance zone-in greeting disabled")
        return
    end

    -- Only burn the once-per-group flag when a greeting actually went out
    local names = self:CollectGroupMemberNames(self.db.profile.instance)
    if self:SendGreeting(names, "self_join") then
        self:SetInstanceGreeted(true)
    end
end

-- Names of the other group members for a self-join greeting, or nil when the channel
-- does not want them. Only connected members: someone still on a load screen has no name yet.
function Addon:CollectGroupMemberNames(settings)
    if not settings or not settings.includeGroupNames then return nil end

    local names = {}
    local members, connected = self:GetCurrentGroupMembers()
    local myName = UnitName("player")
    -- Keys are full Name-Realm (identity); the stored value is the short display name -
    -- chat gets the display name, never the realm-suffixed key
    for key, displayName in pairs(members) do
        if connected[key] and key ~= myName then
            table.insert(names, displayName)
        end
    end
    self:DebugPrint("Including group member names:", table.concat(names, ", "))
    return names
end

-- Handle reconnecting to an existing group
function Addon:HandleGroupReconnect()
    local db = self.db.profile

    if not db.enabled then return end

    local channel = self:GetChatChannel()
    if not channel then
        self:DebugPrint("Not in group after delay, skipping reconnect greeting")
        return
    end

    self:DebugPrint("HandleGroupReconnect - channel:", channel)

    -- Instance groups have no reconnect trigger - the zone-in path owns their greeting
    if channel == "INSTANCE_CHAT" then
        self:DebugPrint("Instance group - reconnect greeting handled by the zone-in path")
        return
    end

    -- Check if reconnect greeting is enabled for this channel
    if not self:ShouldGreetOnReconnect(channel) then
        self:DebugPrint("Reconnect greeting disabled for", channel)
        return
    end

    -- Send greeting (SendGreeting is the single gate for this path - gating here too
    -- would reserve two budget slots for one message)
    self:SendGreeting(nil, "reconnect")
end

-- Get current group members. Membership is presence (the unit exists and has a name), not
-- connectivity: a load screen or a DC must not shrink the roster and turn everyone still
-- in the group into a "newcomer" when they come back.
-- Returns the member set plus a set of the members who are currently connected.
function Addon:GetCurrentGroupMembers()
    local members, connected = {}, {}
    local isRaid = IsInRaid()
    local groupSize = GetNumGroupMembers()

    for i = 1, groupSize do
        local unitID = isRaid and ("raid" .. i) or ("party" .. i)
        local name, realm = UnitName(unitID)

        if UnitExists(unitID) and name and name ~= "" and name ~= "Unknown" then
            -- Keyed by full name: two cross-realm members can share a short name, and a
            -- short-name key would collapse them into one (second one never greeted, first
            -- one re-greeted when the other leaves). The value is the short display name.
            local key = (realm and realm ~= "") and (name .. "-" .. realm) or name
            members[key] = name
            if UnitIsConnected(unitID) then
                connected[key] = true
            end
        end
    end

    -- Always include player (same-realm, so the short name is the key)
    local playerName = UnitName("player")
    if playerName and playerName ~= "Unknown" then
        members[playerName] = playerName
        connected[playerName] = true
    end

    return members, connected
end

-- Handle INITIAL_CLUBS_LOADED - Club API is now ready
function Addon:INITIAL_CLUBS_LOADED()
    self:DebugPrint("EVENT: INITIAL_CLUBS_LOADED - Club system initialized")

    -- Update guild status now that Club API is reliable
    self:UpdateGuildStatus()

    -- Disabled until member login greeting feature is fully working
    -- self:SnapshotGuildPresence()

    -- Send guild greeting on login (deferred from PLAYER_ENTERING_WORLD)
    if self.state.pendingGuildGreeting then
        self.state.pendingGuildGreeting = false
        self:DebugPrint("Clubs loaded, sending deferred guild greeting")
        -- Small delay for chat system to be fully ready
        self:ScheduleTimer(function()
            self:UpdateGuildStatus()
            self:DebugPrint("Attempting to send guild greeting, IsInGuild:", tostring(IsInGuild()))
            if IsInGuild() then
                self:SendGuildGreeting()
            else
                self:DebugPrint("Not in guild after INITIAL_CLUBS_LOADED, skipping greeting")
            end
        end, 2)
    end
end

-- Snapshot all current guild members' presence so login detection has a baseline
function Addon:SnapshotGuildPresence()
    if not C_Club or not C_Club.GetGuildClubId or not C_Club.GetClubMembers then
        self:DebugPrint("Club API not available for presence snapshot")
        self.state.guildPresenceReady = true
        return
    end

    local guildClubId = C_Club.GetGuildClubId()
    if not guildClubId then
        self:DebugPrint("No guild club ID, skipping presence snapshot")
        self.state.guildPresenceReady = true
        return
    end

    -- Focus members and subscribe to presence updates for the guild club
    -- Without SetClubPresenceSubscription, CLUB_MEMBER_PRESENCE_UPDATED won't fire
    if C_Club.FocusMembers then
        C_Club.FocusMembers(guildClubId)
    end
    if C_Club.SetClubPresenceSubscription then
        C_Club.SetClubPresenceSubscription(guildClubId)
        self:DebugPrint("Subscribed to guild presence updates, clubId:", tostring(guildClubId))
    end

    local memberIds = C_Club.GetClubMembers(guildClubId)
    if not memberIds then
        self:DebugPrint("No guild members returned, skipping snapshot")
        self.state.guildPresenceReady = true
        return
    end

    local onlineCount = 0
    for _, memberId in ipairs(memberIds) do
        local info = C_Club.GetMemberInfo(guildClubId, memberId)
        if info and info.presence then
            self.state.guildMemberPresence[memberId] = info.presence
            if info.presence == Enum.ClubMemberPresence.Online
               or info.presence == Enum.ClubMemberPresence.OnlineMobile
               or info.presence == Enum.ClubMemberPresence.Away
               or info.presence == Enum.ClubMemberPresence.Busy then
                onlineCount = onlineCount + 1
            end
        end
    end

    self.state.guildPresenceReady = true
    self:DebugPrint("Guild presence snapshot complete:", #memberIds, "members,", onlineCount, "online")
end

-- Handle CLUB_MEMBER_PRESENCE_UPDATED - detect guild member login via Club API
function Addon:CLUB_MEMBER_PRESENCE_UPDATED(event, clubId, memberId, presence)
    -- Debug: log every presence update to verify the event fires
    local info = C_Club and C_Club.GetMemberInfo and C_Club.GetMemberInfo(clubId, memberId)
    local memberName = info and info.name or tostring(memberId)
    self:DebugPrint("EVENT: CLUB_MEMBER_PRESENCE_UPDATED", memberName,
        "presence:", tostring(presence), "ready:", tostring(self.state.guildPresenceReady))

    if not self.db.profile.enabled then return end
    if not self.db.profile.guild.enabled then return end
    if not self.db.profile.guild.onMemberLogin then return end

    -- Only handle guild club events
    if not C_Club or not C_Club.GetGuildClubId then return end
    local guildClubId = C_Club.GetGuildClubId()
    if not guildClubId or clubId ~= guildClubId then
        self:DebugPrint("  Not guild club, ignoring (got:", tostring(clubId), "guild:", tostring(guildClubId), ")")
        return
    end

    -- Track previous presence and update
    local prevPresence = self.state.guildMemberPresence[memberId]
    self.state.guildMemberPresence[memberId] = presence

    -- Don't process greetings during initialization (roster still loading)
    if not self.state.guildPresenceReady then
        self:DebugPrint("  Presence not ready yet, skipping")
        return
    end

    -- Only greet on transition to Online (not OnlineMobile — that's the companion app, not in-game)
    if presence ~= Enum.ClubMemberPresence.Online then
        self:DebugPrint("  Not Online transition, skipping (presence:", tostring(presence), ")")
        return
    end

    -- Only greet if previously Offline, Unknown, or never seen (not Away→Online or Busy→Online)
    if prevPresence and prevPresence ~= Enum.ClubMemberPresence.Offline
       and prevPresence ~= Enum.ClubMemberPresence.Unknown then
        self:DebugPrint("  Was already online/away/busy, skipping (prev:", tostring(prevPresence), ")")
        return
    end

    if not info or not info.name then
        self:DebugPrint("  No member info/name available")
        return
    end

    -- Don't greet yourself
    if info.isSelf then return end

    local name = info.name
    self:DebugPrint("Guild member logged in (presence update):", name, "prev:", tostring(prevPresence))
    self:HandleGuildMemberLogin(name)
end

-- Handle PLAYER_LOGOUT - for guild goodbye on logout (fallback if hooks didn't fire)
function Addon:PLAYER_LOGOUT()
    self:DebugPrint("EVENT: PLAYER_LOGOUT - Player is logging out")
    self.db.char.lastLogoutTime = time()
    self:DebugPrint("IsInGuild:", tostring(IsInGuild()))
    self:DebugPrint("Guild settings - enabled:", tostring(self.db.profile.guild.enabled), "sendGoodbye:", tostring(self.db.profile.guild.sendGoodbye))

    -- Send guild goodbye if enabled (uses SendGuildGoodbyeOnce to avoid duplicates with hooks)
    self:SendGuildGoodbyeOnce()
end
