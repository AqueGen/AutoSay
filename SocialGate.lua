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
  if #self.state.sends >= s.budgetPerHour then
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

if ns then ns.SocialGate = SocialGate end
return SocialGate
