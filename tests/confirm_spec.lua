require("tests.wow_stub")
local Confirm = require("Confirm")

local function item(text, extra)
  local t = { text = text, channel = "PARTY", generation = 0 }
  for k, v in pairs(extra or {}) do t[k] = v end
  return t
end

describe("Confirm", function()
  it("starts empty", function()
    local c = Confirm.New()
    assert.is_nil(c:Current())
  end)

  it("a new offer replaces the current one", function()
    local c = Confirm.New()
    c:Offer(item("hi"), 10)
    c:Offer(item("hello"), 12)
    assert.equal("hello", c:Current().text)
  end)

  describe("Remaining", function()
    it("counts down from the offer time", function()
      local c = Confirm.New()
      c:Offer(item("hi"), 100)
      assert.equal(30, c:Remaining(100, 30))
      assert.equal(12, c:Remaining(118, 30))
    end)

    it("never goes below zero", function()
      local c = Confirm.New()
      c:Offer(item("hi"), 100)
      assert.equal(0, c:Remaining(200, 30))
    end)

    it("is zero with nothing offered", function()
      assert.equal(0, Confirm.New():Remaining(5, 30))
    end)

    it("restarts for a replacing offer", function()
      local c = Confirm.New()
      c:Offer(item("hi"), 100)
      c:Offer(item("yo"), 125)
      assert.equal(25, c:Remaining(130, 30))
    end)
  end)

  describe("Reroll", function()
    it("takes a different text from repick", function()
      local c = Confirm.New()
      c:Offer(item("hi", { repick = function() return "hello" end }), 0)
      assert.is_true(c:Reroll())
      assert.equal("hello", c:Current().text)
    end)

    it("tries three times for a different text, then keeps the current one", function()
      local calls = 0
      local c = Confirm.New()
      c:Offer(item("hi", { repick = function() calls = calls + 1 return "hi" end }), 0)
      assert.is_false(c:Reroll())
      assert.equal(3, calls)
      assert.equal("hi", c:Current().text)
    end)

    it("skips a nil pick and uses the next one", function()
      local answers = { nil, "yo" }
      local n = 0
      local c = Confirm.New()
      c:Offer(item("hi", { repick = function() n = n + 1 return answers[n] end }), 0)
      assert.is_true(c:Reroll())
      assert.equal("yo", c:Current().text)
    end)

    it("does nothing without repick", function()
      local c = Confirm.New()
      c:Offer(item("hi"), 0)
      assert.is_false(c:CanReroll())
      assert.is_false(c:Reroll())
      assert.equal("hi", c:Current().text)
    end)

    it("does nothing with no offer", function()
      local c = Confirm.New()
      assert.is_false(c:CanReroll())
      assert.is_false(c:Reroll())
    end)
  end)

  it("Take returns the offer and clears it", function()
    local c = Confirm.New()
    c:Offer(item("hi"), 0)
    assert.equal("hi", c:Take().text)
    assert.is_nil(c:Current())
    assert.is_nil(c:Take())
  end)

  it("Dismiss clears the offer", function()
    local c = Confirm.New()
    c:Offer(item("hi"), 0)
    c:Dismiss()
    assert.is_nil(c:Current())
  end)

  describe("DismissIf", function()
    it("drops the offer when the predicate matches", function()
      local c = Confirm.New()
      c:Offer(item("hi"), 0)
      assert.is_true(c:DismissIf(function(i) return i.channel == "PARTY" end))
      assert.is_nil(c:Current())
    end)

    it("keeps the offer when it does not match", function()
      local c = Confirm.New()
      c:Offer(item("hi"), 0)
      assert.is_false(c:DismissIf(function(i) return i.channel == "GUILD" end))
      assert.equal("hi", c:Current().text)
    end)

    it("returns false with nothing offered", function()
      assert.is_false(Confirm.New():DismissIf(function() return true end))
    end)
  end)
end)
