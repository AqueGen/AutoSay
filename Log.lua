local ADDON_NAME, AutoSay = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)

-- Session log: what the addon did, in the order it did it, kept where a player can copy it
-- out and paste it into a bug report. Debug printing answers "what is it doing right now" and
-- scrolls away; this answers "what happened over that hour of keys" after the fact.
--
-- Recording is off by default and costs nothing while it is off. Switched on, every line the
-- addon already narrates through DebugPrint is stamped and stored, so the log covers the same
-- decisions the debug output does without a second set of call sites to keep in sync.

local MAX_ENTRIES = 500

-- Chat colours, item links and the like paste as noise, and the log is read as plain text
local function Strip(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub("|T.-|t", ""):gsub("|A.-|a", "")
    return text
end

local function Join(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring((select(i, ...)))
    end
    return Strip(table.concat(parts, " "))
end

function Addon:LoggingEnabled()
    return self.db and self.db.global.log and self.db.global.log.recording
end

-- Where the entries live. Global rather than per profile: a log is about a play session, not
-- about a set of settings, and switching character mid-session must not split it in two.
function Addon:LogStore()
    local log = self.db.global.log
    if not log.entries then log.entries = {} end
    return log
end

--- One line in the log. Called by DebugPrint for everything the addon narrates, and directly
--- for the few facts that are worth recording even when nothing was said.
function Addon:LogLine(...)
    if not self:LoggingEnabled() then return end
    local log = self:LogStore()
    local entry = date("%H:%M:%S") .. "  " .. Join(...)
    log.entries[#log.entries + 1] = entry
    -- A ring rather than a cap: the interesting part of a long session is usually its end
    if #log.entries > MAX_ENTRIES then
        table.remove(log.entries, 1)
        log.dropped = (log.dropped or 0) + 1
    end
end

-- The state a log is only readable against: which channels could speak at all, what the
-- group looked like, which build this was. Written when recording starts and on demand.
function Addon:LogSnapshot(header)
    if not self:LoggingEnabled() then return end
    local db = self.db.profile
    local version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON_NAME, "Version") or "?"
    self:LogLine("===", header, "| AutoSay", version, "| profile", self.db:GetCurrentProfile(), "===")

    local channels = {}
    for _, c in ipairs(AutoSay.Channels) do
        local s = db[c.key]
        if s then
            local flags = {}
            if s.enabled then flags[#flags + 1] = "on" else flags[#flags + 1] = "off" end
            if s.onSelfJoin then flags[#flags + 1] = "self" end
            if s.onOthersJoin then flags[#flags + 1] = "others" end
            if s.onReconnect then flags[#flags + 1] = "reconnect" end
            if s.sendGoodbye then flags[#flags + 1] = "bye" end
            if s.sendGoodbyeOnRunEnd then flags[#flags + 1] = "bye-on-end" end
            if s.includeNames or s.includeGroupNames then flags[#flags + 1] = "names" end
            channels[#channels + 1] = c.key .. "(" .. table.concat(flags, ",") .. ")"
        end
    end
    self:LogLine("channels:", table.concat(channels, " "))
    self:LogLine("styles: role", tostring(db.social.rolePhrases),
        "| time-of-day", tostring(db.social.timeOfDay),
        "| budget/h", tostring(db.social.budgetPerHour),
        "| per-person h", tostring(db.social.personCooldownHours),
        "| listening", tostring(db.social.listen),
        "| typing delay", tostring(db.social.typingDelay))
    self:LogLine("context: group", tostring(self:GetChatChannel()),
        "| role", tostring(self:GetPlayerRoleOrTest()),
        "| test mode", tostring(db.testMode))
end

function Addon:StartLogging()
    local log = self:LogStore()
    log.recording = true
    self:LogSnapshot("recording started")
    self:Print("Session log ON. Play as usual, then /as log show to copy it out.")
end

function Addon:StopLogging()
    local log = self:LogStore()
    if log.recording then
        self:LogLine("=== recording stopped ===")
        log.recording = false
    end
    self:Print(string.format("Session log OFF. %d line(s) kept - /as log show to copy them.",
        #(log.entries or {})))
end

function Addon:ClearLog()
    local log = self:LogStore()
    log.entries = {}
    log.dropped = nil
    self:Print("Session log cleared.")
    if log.recording then self:LogSnapshot("recording continues") end
end

--- The whole log as one block of text, ready to paste into an issue.
function Addon:LogText()
    local log = self:LogStore()
    local entries = log.entries or {}
    if #entries == 0 then
        return "AutoSay session log is empty. Start it with /as log on."
    end
    local lines = {}
    if log.dropped then
        lines[1] = string.format("... %d earlier line(s) dropped, the log keeps the last %d",
            log.dropped, MAX_ENTRIES)
    end
    for _, entry in ipairs(entries) do lines[#lines + 1] = entry end
    return table.concat(lines, "\n")
end

--- A copy window: one big edit box with the text already selected, since a chat window
--- cannot be copied out of and a 500-line log is not something anyone retypes.
function Addon:ShowLogWindow()
    local AceGUI = LibStub("AceGUI-3.0")
    if self.logFrame then
        self.logFrame:Release()
        self.logFrame = nil
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("AutoSay session log")
    frame:SetStatusText("Ctrl+A, Ctrl+C to copy. The log keeps recording while this is open.")
    frame:SetLayout("Fill")
    frame:SetWidth(700)
    frame:SetHeight(500)
    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        self.logFrame = nil
    end)

    local box = AceGUI:Create("MultiLineEditBox")
    box:SetLabel("")
    box:DisableButton(true)
    box:SetFullWidth(true)
    box:SetFullHeight(true)
    box:SetText(self:LogText())
    box.editBox:HighlightText()
    box.editBox:SetFocus()
    frame:AddChild(box)

    self.logFrame = frame
end
