-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
describe("What's new", function()
  local Addon, scheduled

  before_each(function()
    Addon = { db = { global = { newsSeen = 0 } } }
    scheduled = 0
    _G.LibStub = function()
      return {
        GetAddon = function() return Addon end,
        GetLocale = function() return setmetatable({}, { __index = function(_, key) return key end }) end,
      }
    end
    _G.C_Timer = { After = function() scheduled = scheduled + 1 end }
    assert(loadfile("WhatsNew.lua"))("AutoSay")
  end)

  it("shows once after an update and never on later logins", function()
    Addon:ScheduleNews()
    assert.equal(1, scheduled)
    Addon:ScheduleNews()
    Addon:ScheduleNews()
    assert.equal(1, scheduled)
  end)

  it("never shows on a new install and stays quiet after it", function()
    Addon.newInstall = true
    Addon:ScheduleNews()
    Addon.newInstall = nil
    Addon:ScheduleNews()
    assert.equal(0, scheduled)
  end)
end)
