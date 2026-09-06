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
  -- poolId -> the last text said, surviving the session. The round itself is not worth
  -- saving (it is stale the moment the player edits a pool), but the line the session ended
  -- on is: without it a /reload can open with the phrase the group just heard.
  self.lastPicks = deps.lastPicks or {}
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
  -- A round restored after a reload starts empty but remembers what the last session said,
  -- so the very first pick of the session is held back the same way a seam pick is
  if not round then round = { used = {}, last = self.lastPicks[poolId] }; self.rounds[poolId] = round end

  local candidates = {}
  for _, text in ipairs(entries) do
    if not round.used[text] and text ~= round.last then candidates[#candidates + 1] = text end
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
  self.lastPicks[poolId] = text
  return text
end

if ns then ns.Humanizer = Humanizer end
return Humanizer
