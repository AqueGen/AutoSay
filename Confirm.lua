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
