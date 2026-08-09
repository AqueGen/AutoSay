require("tests.wow_stub")
local Humanizer = require("Humanizer")

local function fixedRandom(value)
  return function(a, b)
    if a == nil then return value end          -- random() -> 0..1
    if b == nil then return math.max(1, math.floor(value * a)) end
    return a + math.floor(value * (b - a))
  end
end

describe("Humanizer", function()
  describe("BandForHour", function()
    it("maps hours to bands", function()
      assert.equal("morning", Humanizer.BandForHour(5))
      assert.equal("morning", Humanizer.BandForHour(10))
      assert.equal("day", Humanizer.BandForHour(11))
      assert.equal("evening", Humanizer.BandForHour(17))
      assert.equal("night", Humanizer.BandForHour(23))
      assert.equal("night", Humanizer.BandForHour(4))
    end)
  end)

  describe("GetTypingDelay", function()
    it("scales with length and caps at 6", function()
      local h = Humanizer.New{ random = fixedRandom(0.5), hour = function() return 12 end }
      -- jitter factor at random()=0.5 is exactly 1.0
      assert.near(1.5 + 0.06 * 2, h:GetTypingDelay("hi"), 0.001)
      assert.equal(6, h:GetTypingDelay(string.rep("x", 200)))
    end)
    it("applies +-30% jitter bounds", function()
      local lo = Humanizer.New{ random = fixedRandom(0), hour = function() return 12 end }
      local hi = Humanizer.New{ random = fixedRandom(0.999), hour = function() return 12 end }
      local base = 1.5 + 0.06 * 2
      assert.near(base * 0.7, lo:GetTypingDelay("hi"), 0.01)
      assert.near(base * 1.3, hi:GetTypingDelay("hi"), 0.05)
    end)
  end)

  describe("Pick anti-repeat", function()
    it("never repeats any of the last 3 picks when pool is big enough", function()
      local h = Humanizer.New{ random = function(n) return 1 end, hour = function() return 12 end }
      local pool = { "a", "b", "c", "d", "e" }
      local seen = {}
      for i = 1, 4 do
        local text = h:Pick("greet", pool)
        assert.is_nil(seen[text], "repeated " .. text .. " within history window")
        seen[text] = true
        if i >= 4 then break end
      end
    end)
    it("still works when pool smaller than history", function()
      local h = Humanizer.New{ random = function(n) return 1 end, hour = function() return 12 end }
      local pool = { "only", "two" }
      assert.is_string(h:Pick("p", pool))
      assert.is_string(h:Pick("p", pool))
      assert.is_string(h:Pick("p", pool))
    end)
  end)

  describe("PickTimed", function()
    it("mixes band pool with universal when band matches", function()
      local h = Humanizer.New{ random = function(n) return n end, hour = function() return 7 end }
      local universal = { "hi" }
      local bands = { morning = { "morning!" } }
      -- random(n)=n picks last entry: with merge order universal..band, that is the band phrase
      assert.equal("morning!", h:PickTimed("g", universal, bands))
    end)
    it("uses only universal when band has no pool", function()
      local h = Humanizer.New{ random = function(n) return n end, hour = function() return 12 end }
      assert.equal("hi", h:PickTimed("g", { "hi" }, { morning = { "morning!" } }))
    end)
  end)
end)
