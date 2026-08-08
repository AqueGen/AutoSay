require("tests.wow_stub")
local SocialGate = require("SocialGate")

local function makeGate(opts)
  opts = opts or {}
  local clock = { t = opts.t or 1000000 }
  local settings = {
    budgetPerHour = opts.budgetPerHour or 12,
    personCooldownHours = opts.personCooldownHours or 4,
    listen = true,
  }
  local state = opts.state or {}
  local gate = SocialGate.New{
    now = function() return clock.t end,
    settings = function() return settings end,
    state = state,
  }
  return gate, clock, state, settings
end

describe("SocialGate budget", function()
  it("allows up to budgetPerHour sends then blocks", function()
    local gate = makeGate{ budgetPerHour = 3 }
    for _ = 1, 3 do
      assert.is_true(gate:MaySend("greeting"))
      gate:Record("greeting")
    end
    local ok, reason = gate:MaySend("greeting")
    assert.is_false(ok)
    assert.equal("budget", reason)
  end)

  it("slides the window: old sends free the budget", function()
    local gate, clock = makeGate{ budgetPerHour = 2 }
    gate:Record("greeting"); gate:Record("greeting")
    assert.is_false(gate:MaySend("greeting"))
    clock.t = clock.t + 3601
    assert.is_true(gate:MaySend("greeting"))
  end)

  it("budget survives re-init from same state table (reload sim)", function()
    local state = {}
    local gate1 = makeGate{ budgetPerHour = 2, state = state }
    gate1:Record("greeting"); gate1:Record("greeting")
    local gate2 = makeGate{ budgetPerHour = 2, state = state }
    assert.is_false(gate2:MaySend("greeting"))
  end)
end)

describe("SocialGate per-person cooldown", function()
  it("blocks a second message to the same player inside the window", function()
    local gate = makeGate{}
    assert.is_true(gate:MaySend("grats", "Bob"))
    gate:Record("grats", "Bob")
    local ok, reason = gate:MaySend("grats", "Bob")
    assert.is_false(ok)
    assert.equal("person-cd", reason)
    assert.is_true(gate:MaySend("grats", "Alice"))
  end)

  it("frees the player after personCooldownHours", function()
    local gate, clock = makeGate{ personCooldownHours = 4 }
    gate:Record("grats", "Bob")
    clock.t = clock.t + 4 * 3600 + 1
    assert.is_true(gate:MaySend("grats", "Bob"))
  end)

  it("Prune drops per-person entries older than 24h", function()
    local gate, clock, state = makeGate{}
    gate:Record("grats", "Bob")
    clock.t = clock.t + 25 * 3600
    gate:Prune()
    assert.is_nil(state.perPerson.Bob)
  end)
end)

describe("SocialGate social listening", function()
  it("cancels pending when another player says a matching intent word", function()
    local gate = makeGate{}
    local id = gate:AddPending("grats", "GUILD")
    gate:OnChatMessage("GUILD", "Bob", "GZ Alice!!")
    assert.is_false(gate:TakePending(id))
  end)

  it("does not cancel on unrelated text or other channel", function()
    local gate = makeGate{}
    local id = gate:AddPending("grats", "GUILD")
    gate:OnChatMessage("GUILD", "Bob", "anyone up for m+?")
    gate:OnChatMessage("PARTY", "Bob", "gz")
    assert.is_true(gate:TakePending(id))
  end)

  it("matches whole words only - 'this' must not match greeting 'hi'", function()
    local gate = makeGate{}
    local id = gate:AddPending("greeting", "PARTY")
    gate:OnChatMessage("PARTY", "Bob", "this pull was rough")
    assert.is_true(gate:TakePending(id))
  end)

  it("TakePending removes the slot", function()
    local gate = makeGate{}
    local id = gate:AddPending("grats", "GUILD")
    assert.is_true(gate:TakePending(id))
    assert.is_false(gate:TakePending(id)) -- unknown id -> not allowed
  end)
end)

describe("SocialGate welcome rules", function()
  it("welcomes a player at most once ever", function()
    local gate = makeGate{}
    assert.is_true(gate:MayWelcome("Newbie"))
    gate:RecordWelcome("Newbie")
    local ok, reason = gate:MayWelcome("Newbie")
    assert.is_false(ok)
    assert.equal("already-welcomed", reason)
  end)

  it("caps welcomes at 2 per hour regardless of budget", function()
    local gate, clock = makeGate{ budgetPerHour = 30 }
    gate:RecordWelcome("A"); gate:RecordWelcome("B")
    local ok, reason = gate:MayWelcome("C")
    assert.is_false(ok)
    assert.equal("welcome-cap", reason)
    clock.t = clock.t + 3601
    assert.is_true(gate:MayWelcome("C"))
  end)

  it("mass join wave: 100 joins produce exactly 2 allowed welcomes", function()
    local gate = makeGate{ budgetPerHour = 30 }
    local allowed = 0
    for i = 1, 100 do
      if gate:MayWelcome("Player" .. i) then
        gate:RecordWelcome("Player" .. i)
        allowed = allowed + 1
      end
    end
    assert.equal(2, allowed)
  end)

  it("welcomed set survives re-init and prunes after 30 days", function()
    local state = {}
    local gate1 = makeGate{ state = state }
    gate1:RecordWelcome("Newbie")
    local gate2, clock2 = makeGate{ state = state }
    assert.is_false(gate2:MayWelcome("Newbie"))
    clock2.t = clock2.t + 31 * 24 * 3600
    gate2:Prune()
    assert.is_true(gate2:MayWelcome("Newbie"))
  end)
end)
