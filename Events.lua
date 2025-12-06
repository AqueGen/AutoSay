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

    -- Player logout for guild farewell
    self:RegisterEvent("PLAYER_LOGOUT")

    self:DebugPrint("Events registered")
end

-- Handle GROUP_JOINED - we joined a group
function Addon:GROUP_JOINED()
    self:DebugPrint("EVENT: GROUP_JOINED - We joined a group")

    local db = self.db.profile

    if not db.enabled then return end

    -- Initialize group tracking
    self.state.previousGroup = self:GetCurrentGroupMembers()
    self.state.sentGreetings = {}

    -- Determine channel type
    local channel = self:GetChatChannel()
    if not channel then return end

    -- Check per-channel settings
    if not self:ShouldGreetOnSelfJoin(channel) then
        self:DebugPrint("Self join greetings disabled for", channel)
        return
    end

    -- Send greeting
    self:SendGreeting(nil, "self_join")
end

-- Handle GROUP_LEFT - we left a group
function Addon:GROUP_LEFT()
    self:DebugPrint("EVENT: GROUP_LEFT - We left the group")

    local db = self.db.profile

    if not db.enabled then return end

    -- Determine what type of group we were in
    local channel = self.state.currentGroupType

    if channel then
        -- Send farewell before leaving
        -- Note: We need to send this immediately as we're leaving
        self:SendFarewell(channel)
    end

    -- Reset state
    self.state.previousGroup = nil
    self.state.sentGreetings = {}
    self.state.currentGroupType = nil
end

-- Handle GROUP_ROSTER_UPDATE - group composition changed
function Addon:GROUP_ROSTER_UPDATE()
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

    -- Get current group members
    local currentGroup = self:GetCurrentGroupMembers()
    local playerName = UnitName("player")

    -- First run - initialize state
    if not self.state.previousGroup then
        self:DebugPrint("First roster update - initializing state")
        self.state.previousGroup = currentGroup
        return
    end

    -- Find newly joined members
    local newMembers = {}
    for name in pairs(currentGroup) do
        if not self.state.previousGroup[name] and name ~= playerName then
            -- Check if we already greeted this player
            if not self.state.sentGreetings[name] then
                table.insert(newMembers, name)
                self.state.sentGreetings[name] = true
            end
        end
    end

    -- Update state
    self.state.previousGroup = currentGroup

    -- If others joined and we have that setting enabled for current channel
    if #newMembers > 0 then
        self:DebugPrint("New members joined:", table.concat(newMembers, ", "))

        local channel = self.state.currentGroupType
        if channel and self:ShouldGreetOnOthersJoin(channel) then
            self:SendGreeting(newMembers, "others_join")
        else
            self:DebugPrint("Others join greeting disabled for", channel or "unknown")
        end
    end
end

-- Handle PLAYER_ENTERING_WORLD - for guild greeting on login
function Addon:PLAYER_ENTERING_WORLD(event, isInitialLogin, isReloadingUi)
    self:DebugPrint("EVENT: PLAYER_ENTERING_WORLD", "isInitialLogin:", isInitialLogin, "isReloadingUi:", isReloadingUi)

    -- Only send guild greeting on initial login, not on reload or zone change
    if isInitialLogin then
        -- Delay guild greeting to allow guild roster to load
        self:ScheduleTimer(function()
            self:SendGuildGreeting()
        end, 3) -- 3 second delay for guild to load
    end

    -- Initialize group state if already in a group
    if IsInGroup() then
        self.state.previousGroup = self:GetCurrentGroupMembers()
        if IsInRaid() then
            self.state.currentGroupType = "RAID"
        else
            self.state.currentGroupType = "PARTY"
        end
    end
end

-- Get current group members as a table
function Addon:GetCurrentGroupMembers()
    local members = {}
    local isRaid = IsInRaid()
    local groupSize = GetNumGroupMembers()

    for i = 1, groupSize do
        local unitID = isRaid and ("raid" .. i) or ("party" .. i)
        local name = UnitName(unitID)

        if name and name ~= "" and name ~= "Unknown" then
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

-- Handle PLAYER_LOGOUT - for guild farewell on logout
function Addon:PLAYER_LOGOUT()
    self:DebugPrint("EVENT: PLAYER_LOGOUT - Player is logging out")

    -- Send guild farewell if enabled
    self:SendGuildFarewell()
end
