-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local _, ns = ...

local Confirm = {}
Confirm.__index = Confirm

local REROLL_TRIES = 3

function Confirm.New()
  return setmetatable({ item = nil }, Confirm)
end

function Confirm:Offer(item, now)
  item.shownAt = now
  self.item = item
  return item
end

function Confirm:Current()
  return self.item
end

function Confirm:CanReroll()
  return self.item ~= nil and self.item.repick ~= nil
end

function Confirm:Reroll()
  local item = self.item
  if not item or not item.repick then return false end
  for _ = 1, REROLL_TRIES do
    local text = item.repick()
    if text and text ~= item.text then
      item.text = text
      return true
    end
  end
  return false
end

function Confirm:CanList()
  local item = self.item
  return item ~= nil and item.candidates ~= nil and #item.candidates() >= 2
end

function Confirm:Pinned(pins)
  local pinned = {}
  local item = self.item
  if not item or not item.candidates then return pinned end
  for _, entry in ipairs(item.candidates()) do
    if pins[entry.template] then pinned[#pinned + 1] = entry end
  end
  return pinned
end

function Confirm:Choose(text)
  local item = self.item
  if not item or type(text) ~= "string" or text == "" or text == item.text then return false end
  item.text = text
  return true
end

function Confirm:Remaining(now, timeout)
  if not self.item then return 0 end
  return math.max(0, timeout - (now - self.item.shownAt))
end

function Confirm:Take()
  local item = self.item
  self.item = nil
  return item
end

function Confirm:Dismiss()
  self.item = nil
end

function Confirm:DismissIf(predicate)
  if self.item and predicate(self.item) then
    self.item = nil
    return true
  end
  return false
end

if ns then ns.Confirm = Confirm end
return Confirm
