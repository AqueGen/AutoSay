local _, ns = ...

local SocialGate = {}
SocialGate.__index = SocialGate

local HOUR = 3600
local PERSON_PRUNE_AGE = 24 * HOUR
local WELCOME_PRUNE_AGE = 30 * 24 * HOUR

function SocialGate.New(deps)
  local self = setmetatable({}, SocialGate)
  self.now = deps.now
  self.settings = deps.settings
  self.debug = deps.debug or function() end
  local state = deps.state
  state.sends = state.sends or {}
  state.perPerson = state.perPerson or {}
  state.welcomed = state.welcomed or {}
  state.welcomeSends = state.welcomeSends or {}
  self.state = state
  self.pending = {}
  self.nextPendingId = 1
  return self
end

local function pruneWindow(list, cutoff)
  while list[1] and list[1] <= cutoff do
    table.remove(list, 1)
  end
end

function SocialGate:MaySend(trigger, targetName)
  local now = self.now()
  local s = self.settings()

  pruneWindow(self.state.sends, now - HOUR)
  -- Goodbyes are exempt: staying silent when leaving reads worse than one extra line.
  -- They still spend a slot via Record, so they count against later greetings.
  if trigger ~= "goodbye" and #self.state.sends >= s.budgetPerHour then
    self.debug("blocked: budget (" .. trigger .. ")")
    return false, "budget"
  end

  if targetName then
    local last = self.state.perPerson[targetName]
    if last and (now - last) < s.personCooldownHours * HOUR then
      self.debug("blocked: person-cd (" .. targetName .. ")")
      return false, "person-cd"
    end
  end

  return true
end

function SocialGate:Record(trigger, targetName)
  local now = self.now()
  local sends = self.state.sends
  sends[#sends + 1] = now
  if targetName then
    self.state.perPerson[targetName] = now
  end
end

function SocialGate:Prune()
  local now = self.now()
  pruneWindow(self.state.sends, now - HOUR)
  pruneWindow(self.state.welcomeSends, now - HOUR)
  for name, ts in pairs(self.state.perPerson) do
    if now - ts > PERSON_PRUNE_AGE then self.state.perPerson[name] = nil end
  end
  for name, ts in pairs(self.state.welcomed) do
    if now - ts > WELCOME_PRUNE_AGE then self.state.welcomed[name] = nil end
  end
end

SocialGate.INTENTS = {
  grats = { "gz", "gratz", "grats", "congrats", "congratulations", "grtz" },
  welcome = { "welcome", "wb" },
}

function SocialGate:AddPending(intent, channel)
  local id = self.nextPendingId
  self.nextPendingId = id + 1
  self.pending[id] = { intent = intent, channel = channel, cancelled = false }
  return id
end

function SocialGate:OnChatMessage(channel, sender, text)
  if not next(self.pending) then return end
  local words = {}
  for word in text:lower():gmatch("[%a/]+") do words[word] = true end
  for _, slot in pairs(self.pending) do
    if slot.channel == channel and not slot.cancelled then
      for _, keyword in ipairs(SocialGate.INTENTS[slot.intent] or {}) do
        if words[keyword] then
          slot.cancelled = true
          self.debug("blocked: someone-answered (" .. slot.intent .. ")")
          break
        end
      end
    end
  end
end

function SocialGate:TakePending(id)
  local slot = self.pending[id]
  self.pending[id] = nil
  return slot ~= nil and not slot.cancelled
end

function SocialGate:MayWelcome(name)
  local now = self.now()
  if self.state.welcomed[name] then
    self.debug("blocked: already-welcomed (" .. name .. ")")
    return false, "already-welcomed"
  end
  pruneWindow(self.state.welcomeSends, now - HOUR)
  if #self.state.welcomeSends >= 2 then
    self.debug("blocked: welcome-cap")
    return false, "welcome-cap"
  end
  return true
end

function SocialGate:RecordWelcome(name)
  local now = self.now()
  self.state.welcomed[name] = now
  local ws = self.state.welcomeSends
  ws[#ws + 1] = now
end

if ns then ns.SocialGate = SocialGate end
return SocialGate
