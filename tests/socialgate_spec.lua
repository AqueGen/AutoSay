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
