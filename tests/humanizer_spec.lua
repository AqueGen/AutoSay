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

  describe("Pick rotation", function()
    local function newPicker()
      return Humanizer.New{ random = function(n) return 1 end, hour = function() return 12 end }
    end

    it("says everything once before anything comes back", function()
      local h = newPicker()
      local pool = { "a", "b", "c", "d", "e" }
      local seen = {}
      for _ = 1, #pool do
        local text = h:Pick("greet", pool)
        assert.is_nil(seen[text], "repeated " .. text .. " inside one round")
        seen[text] = true
      end
      local count = 0
      for _ in pairs(seen) do count = count + 1 end
      assert.equals(#pool, count)
    end)

    it("starts the next round without repeating the line it just said", function()
      local h = newPicker()
      local pool = { "a", "b", "c" }
      local last
      for _ = 1, #pool do last = h:Pick("p", pool) end
      assert.not_equals(last, h:Pick("p", pool))
    end)

    it("keeps alternating a pool of two", function()
      local h = newPicker()
      local pool = { "one", "two" }
      local first = h:Pick("p", pool)
      local second = h:Pick("p", pool)
      assert.not_equals(first, second)
      assert.not_equals(second, h:Pick("p", pool))
    end)

    it("survives a pool of one", function()
      local h = newPicker()
      assert.equals("only", h:Pick("p", { "only" }))
      assert.equals("only", h:Pick("p", { "only" }))
    end)

    it("keeps each pool's round to itself", function()
      local h = newPicker()
      local pool = { "a", "b" }
      h:Pick("greet", pool)
      assert.equals(h:Pick("bye", pool), h:Pick("bye", { "a", "b" }) == "a" and "b" or "a")
    end)

    it("picks up a phrase switched on mid-round", function()
      local h = newPicker()
      h:Pick("p", { "a", "b" })
      h:Pick("p", { "a", "b" })
      -- "c" arrived after both of the originals were spent, so it is the only candidate left
      assert.equals("c", h:Pick("p", { "a", "b", "c" }))
    end)
  end)
end)
