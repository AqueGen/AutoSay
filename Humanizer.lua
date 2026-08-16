local _, ns = ...

local Humanizer = {}
Humanizer.__index = Humanizer

local BASE_DELAY, PER_CHAR, MAX_DELAY, JITTER = 1.5, 0.06, 6, 0.3

function Humanizer.New(deps)
  local self = setmetatable({}, Humanizer)
  self.random = deps.random
  self.hour = deps.hour
  -- poolId -> { used = set of texts already spent this round, last = the previous pick }.
  -- A round is one pass over everything enabled, so a set of ten phrases says ten different
  -- things before any of them comes back.
  self.rounds = {}
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

-- Everything enabled gets its turn before anything repeats. Picking at random with a short
-- memory still lands the same line twice in an evening, and the group hears the machine.
-- The round survives pool changes: a phrase switched on mid-round joins the remaining
-- candidates, one switched off simply never comes up again.
function Humanizer:Pick(poolId, entries)
  local round = self.rounds[poolId]
  if not round then round = { used = {} }; self.rounds[poolId] = round end

  local candidates = {}
  for _, text in ipairs(entries) do
    if not round.used[text] then candidates[#candidates + 1] = text end
  end

  if #candidates == 0 then
    -- Round over. The one just said is held back from the next one, so the seam between
    -- two rounds cannot be the only place a phrase repeats back to back.
    round.used = {}
    for _, text in ipairs(entries) do
      if text ~= round.last or #entries == 1 then candidates[#candidates + 1] = text end
    end
  end

  local text = candidates[self.random(#candidates)]
  round.used[text] = true
  round.last = text
  return text
end

if ns then ns.Humanizer = Humanizer end
return Humanizer
