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

    -- Player logout for guild goodbye
    self:RegisterEvent("PLAYER_LOGOUT")

    -- LFG listing updates (for M+ key announce)
    self:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
    self:RegisterEvent("LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS")

    self:DebugPrint("Events registered")
end

-- Handle GROUP_JOINED - we joined a group
function Addon:GROUP_JOINED()
    self:DebugPrint("EVENT: GROUP_JOINED - We joined a group")

    local db = self.db.profile

    -- Auto-disable simulation mode on real group events
    if db.testMode and db.autoDisableTestMode then
        db.testMode = false
        db.debugMode = false
        self:Print("|cFFFF9900Simulation auto-disabled|r (real group detected)")
        LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
    end

    if not db.enabled then return end

    -- Delay to allow raid/party state to fully initialize
    self:ScheduleTimer(function()
        -- Initialize group tracking
        self.state.previousGroup = self:GetCurrentGroupMembers()
        self.state.sentGreetings = {}

        -- Update current group type
        if IsInRaid() then
            self.state.currentGroupType = "RAID"
        elseif IsInGroup() then
            self.state.currentGroupType = "PARTY"
        end

        -- Determine channel type
        local channel = self:GetChatChannel()
        if not channel then
            self:DebugPrint("Not in group after delay, skipping greeting")
            return
        end

        self:DebugPrint("Detected group type:", channel)

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

        -- Collect group member names if enabled
        local memberNames = nil
        local settings = self:GetChannelSettings(channel)
        if settings and settings.includeGroupNames then
            memberNames = {}
            local currentGroup = self:GetCurrentGroupMembers()
            local myName = UnitName("player")
            for name in pairs(currentGroup) do
                if name ~= myName then
                    table.insert(memberNames, name)
                end
            end
            self:DebugPrint("Including group member names:", table.concat(memberNames, ", "))
        end

        -- Send greeting
        self:SendGreeting(memberNames, "self_join")
    end, 1) -- 1 second delay for group state to initialize
end

-- Handle GROUP_LEFT - we left a group
function Addon:GROUP_LEFT()
    self:DebugPrint("EVENT: GROUP_LEFT - We left the group")

    -- Note: Goodbye is now sent via HookLeaveGroupFunctions() BEFORE leaving
    -- This event fires AFTER we've already left, so we just reset state here

    -- Reset state
    self.state.previousGroup = nil
    self.state.sentGreetings = {}
    self.state.currentGroupType = nil
    self.state.groupGoodbyeSent = false
    self.state.pendingNewMembers = {}
    if self.state.pendingGreetTimer then
        self:CancelTimer(self.state.pendingGreetTimer)
        self.state.pendingGreetTimer = nil
    end
    if #self.state.messageQueue > 0 then
        self:DebugPrint("GROUP_LEFT -> clearing", #self.state.messageQueue, "queued message(s)")
    end
    self.state.messageQueue = {}
    if self.state.queueTimer then
        self:DebugPrint("GROUP_LEFT -> cancelling queue timer")
        self:CancelTimer(self.state.queueTimer)
        self.state.queueTimer = nil
    end
    self.state.lastGreetingText = {}
    self.state.keyAnnounced = false
    self.state.cachedLFGListing = nil
end

-- Handle GROUP_ROSTER_UPDATE - group composition changed
function Addon:GROUP_ROSTER_UPDATE()
    self:DebugPrint("EVENT: GROUP_ROSTER_UPDATE triggered")

    local db = self.db.profile

    if not db.enabled then return end

    -- Update current group type
    if IsInRaid() then
        self.state.currentGroupType = "RAID"
    elseif IsInGroup() then
        self.state.currentGroupType = "PARTY"
    else
        self.state.currentGroupType = nil
    end

    self:DebugPrint("Group type:", self.state.currentGroupType, "Size:", GetNumGroupMembers())

    -- Debug: show all units and their connection status
    local isRaid = IsInRaid()
    local groupSize = GetNumGroupMembers()
    for i = 1, groupSize do
        local unitID = isRaid and ("raid" .. i) or ("party" .. i)
        local name = UnitName(unitID)
        local connected = UnitIsConnected(unitID)
        local exists = UnitExists(unitID)
        self:DebugPrint("  Unit:", unitID, "Name:", tostring(name), "Exists:", tostring(exists), "Connected:", tostring(connected))
    end

    -- Get current group members
    local currentGroup = self:GetCurrentGroupMembers()
    local playerName = UnitName("player")

    self:DebugPrint("Current connected members:", self:TableKeysToString(currentGroup))
    self:DebugPrint("Previous members:", self:TableKeysToString(self.state.previousGroup))

    -- First run - initialize state
    if not self.state.previousGroup then
        self:DebugPrint("First roster update - initializing state")
        self.state.previousGroup = currentGroup
        return
    end

    -- Find members who left (to clear their greeting status for re-join)
    for name in pairs(self.state.previousGroup) do
        if not currentGroup[name] and name ~= playerName then
            self:DebugPrint("Member left group:", name)
            -- Clear greeting status so they get greeted if they rejoin
            self.state.sentGreetings[name] = nil
        end
    end

    -- Find newly joined members
    local newMembers = {}
    for name in pairs(currentGroup) do
        if not self.state.previousGroup[name] and name ~= playerName then
            self:DebugPrint("Detected new member:", name, "Already greeted:", tostring(self.state.sentGreetings[name]))
            -- Check if we already greeted this player
            if not self.state.sentGreetings[name] then
                table.insert(newMembers, name)
                self.state.sentGreetings[name] = true
                self:DebugPrint("Added to newMembers:", name)
            end
        end
    end

    -- Update state
    self.state.previousGroup = currentGroup

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
       and GetNumGroupMembers() == 5 then

        -- Check if we have cached LFG listing data for a M+ key
        if self.state.cachedLFGListing and self.state.cachedLFGListing.isMythicPlus then
            self.state.keyAnnounced = true
            self:DebugPrint("Group full 5/5 with M+ listing, scheduling key announce")
            -- Small delay to send after any greeting messages
            self:ScheduleTimer(function()
                self:SendKeyAnnounce()
            end, 2)
        else
            self:DebugPrint("Group full 5/5 but no M+ listing cached")
        end
    end
end

-- Handle LFG_LIST_ACTIVE_ENTRY_UPDATE - cache listing data for M+ key announce
function Addon:LFG_LIST_ACTIVE_ENTRY_UPDATE()
    if not C_LFGList or not C_LFGList.GetActiveEntryInfo then return end

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

    -- Check if we have cached M+ listing data
    if self.state.cachedLFGListing and self.state.cachedLFGListing.isMythicPlus then
        self.state.keyAnnounced = true
        self:DebugPrint("M+ listing delisted (group full), scheduling key announce")
        -- Small delay to send after any greeting messages
        self:ScheduleTimer(function()
            self:SendKeyAnnounce()
        end, 2)
    else
        self:DebugPrint("Listing delisted but no M+ cache available")
    end
end

-- Handle PLAYER_ENTERING_WORLD - for guild greeting on login and group reconnect
function Addon:PLAYER_ENTERING_WORLD(event, isInitialLogin, isReloadingUi)
    self:DebugPrint("EVENT: PLAYER_ENTERING_WORLD", "isInitialLogin:", tostring(isInitialLogin), "isReloadingUi:", tostring(isReloadingUi))

    -- Update cached guild status
    self:UpdateGuildStatus()

    -- Only send guild greeting on initial login, not on reload or zone change
    if isInitialLogin then
        self:DebugPrint("Initial login detected, scheduling guild greeting")
        -- Delay guild greeting to allow guild roster to load
        self:ScheduleTimer(function()
            -- Update guild status after delay
            self:UpdateGuildStatus()
            self:DebugPrint("Attempting to send guild greeting, IsInGuild:", tostring(IsInGuild()))
            if IsInGuild() then
                self:SendGuildGreeting()
            else
                -- Retry once more after additional delay if guild not loaded yet
                self:DebugPrint("Guild not loaded yet, retrying in 5 seconds")
                self:ScheduleTimer(function()
                    self:UpdateGuildStatus()
                    self:DebugPrint("Retry: IsInGuild:", tostring(IsInGuild()))
                    self:SendGuildGreeting()
                end, 5)
            end
        end, 5) -- 5 second delay for guild to load
    end

    -- Initialize group state if already in a group
    if IsInGroup() then
        self.state.previousGroup = self:GetCurrentGroupMembers()
        if IsInRaid() then
            self.state.currentGroupType = "RAID"
        else
            self.state.currentGroupType = "PARTY"
        end

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
                if IsInRaid() then
                    self.state.currentGroupType = "RAID"
                else
                    self.state.currentGroupType = "PARTY"
                end
                self:HandleGroupReconnect()
            else
                self:DebugPrint("Reconnect retry: still not in group, no reconnect needed")
            end
        end, 5) -- Longer delay for group state to load after disconnect
    end
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

    -- Check if reconnect greeting is enabled for this channel
    if not self:ShouldGreetOnReconnect(channel) then
        self:DebugPrint("Reconnect greeting disabled for", channel)
        return
    end

    -- Send greeting
    self:SendGreeting(nil, "reconnect")
end

-- Get current group members as a table (only connected members)
function Addon:GetCurrentGroupMembers()
    local members = {}
    local isRaid = IsInRaid()
    local groupSize = GetNumGroupMembers()

    for i = 1, groupSize do
        local unitID = isRaid and ("raid" .. i) or ("party" .. i)
        local name = UnitName(unitID)

        -- Only include members who are actually connected (not pending invites)
        if name and name ~= "" and name ~= "Unknown" and UnitIsConnected(unitID) then
            members[name] = true
        end
    end

    -- Always include player
    local playerName = UnitName("player")
    if playerName and playerName ~= "Unknown" then
        members[playerName] = true
    end

    return members
end

-- Handle PLAYER_LOGOUT - for guild goodbye on logout (fallback if hooks didn't fire)
function Addon:PLAYER_LOGOUT()
    self:DebugPrint("EVENT: PLAYER_LOGOUT - Player is logging out")
    self:DebugPrint("IsInGuild:", tostring(IsInGuild()))
    self:DebugPrint("Guild settings - enabled:", tostring(self.db.profile.guild.enabled), "sendGoodbye:", tostring(self.db.profile.guild.sendGoodbye))

    -- Send guild goodbye if enabled (uses SendGuildGoodbyeOnce to avoid duplicates with hooks)
    self:SendGuildGoodbyeOnce()
end
