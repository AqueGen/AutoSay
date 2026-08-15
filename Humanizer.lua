local _, ns = ...

local Humanizer = {}
Humanizer.__index = Humanizer

local BASE_DELAY, PER_CHAR, MAX_DELAY, JITTER = 1.5, 0.06, 6, 0.3
local HISTORY_MAX = 3

function Humanizer.New(deps)
  local self = setmetatable({}, Humanizer)
  self.random = deps.random
  self.hour = deps.hour
  self.history = {} -- poolId -> array of recently picked texts (newest last)
  return self
end

function Humanizer.BandForHour(hour)
  if hour >= 5 and hour < 11 then return "morning" end
  if hour >= 11 and hour < 17 then return "day" end
  if hour >= 17 and hour < 23 then return "evening" end
  return "night"
end

function Humanizer:GetTypingDelay(message)
  local base = BASE_DELAY + PER_CHAR * #message
  local jitter = 1 + (self.random() * 2 - 1) * JITTER
  return math.min(MAX_DELAY, base * jitter)
end

function Humanizer:Pick(poolId, entries)
  local history = self.history[poolId]
  if not history then history = {}; self.history[poolId] = history end
  local k = math.min(HISTORY_MAX, #entries - 1)

  local blocked = {}
  for i = math.max(1, #history - k + 1), #history do blocked[history[i]] = true end

  local candidates = {}
  for _, text in ipairs(entries) do
    if not blocked[text] then candidates[#candidates + 1] = text end
  end
  if #candidates == 0 then candidates = entries end

  local text = candidates[self.random(#candidates)]
  history[#history + 1] = text
  if #history > HISTORY_MAX then table.remove(history, 1) end
  return text
end

if ns then ns.Humanizer = Humanizer end
return Humanizer
