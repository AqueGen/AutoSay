# AutoSay 1.5.0 Social Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Testable anti-spam core (SocialGate) + humanizer (Humanizer) with a headless busted test suite and CI, wired into existing AutoSay message flows, plus two opt-in guild triggers (achievement grats, newcomer welcome).

**Architecture:** Hexagonal: `SocialGate.lua` and `Humanizer.lua` are pure Lua 5.1 modules with injected dependencies (`now()`, `random()`, `hour()`, state tables) that run under busted without WoW. Core.lua/Events.lua become thin adapters that translate real events into core calls. Spec: `docs/superpowers/specs/2026-08-09-social-foundation-design.md`.

**Tech Stack:** WoW retail Lua 5.1, Ace3 (AceDB char section for persistent state), busted for headless tests, GitHub Actions CI.

## Global Constraints

- All files English. No AI attribution anywhere (no Co-Authored-By).
- WoW Lua = 5.1. No `goto` over local declarations. Core modules must not reference any WoW global (no frames, no `SendChatMessage`, no `GetTime`); only injected deps. `time()`/`date()` allowed ONLY in adapters.
- Core modules end with `return <Module>` and also attach to the addon namespace via TOC vararg (`local _, ns = ...` guarded with `if ns then`), so both `require` (busted) and WoW loading work.
- Existing Core.lua queue/channel-cooldown logic is NOT modified; the gate runs before it.
- Defaults: budgetPerHour=12, personCooldownHours=4, listen=true, typingDelay=true, timeOfDay=true, guildGrats=false, guildWelcome=false. Welcome hard cap: 2/hour, each player once ever (30-day prune).
- Typing delay: `1.5 + 0.06 * #message` seconds, jitter +-30%, cap 6s.
- Anti-repeat: last K=min(3, poolSize-1) picks excluded per pool.
- Time bands (local clock): morning 5-11, day 11-17, evening 17-23, night 23-5.
- Commit after every green test cycle. Do not bump TOC Version or tag; release is manual.

---

### Task 1: Headless test infrastructure

**Files:**
- Create: `.busted`, `tests/wow_stub.lua`, `tests/infra_spec.lua`, `.github/workflows/test.yml`

**Interfaces:**
- Produces: `busted` runnable from repo root picking up `tests/*_spec.lua`; `tests/wow_stub.lua` required by every spec file first.

- [ ] **Step 1: Write `.busted` config**

```lua
return {
  _all = { pattern = "_spec" },
  default = { ROOT = { "tests" }, verbose = true },
}
```

- [ ] **Step 2: Write `tests/wow_stub.lua`**

```lua
-- Minimal WoW globals for headless runs. Core modules must not need these
-- (deps are injected); this exists so future adapter-level tests can load.
_G.strsplit = _G.strsplit or function(sep, s)
  local out = {}
  for part in string.gmatch(s, "([^" .. sep .. "]+)") do out[#out + 1] = part end
  return unpack(out)
end
return true
```

- [ ] **Step 3: Write `tests/infra_spec.lua`**

```lua
require("tests.wow_stub")
describe("test infrastructure", function()
  it("runs under lua 5.1 semantics", function()
    assert.equal("50", ("%d"):format(50))
    assert.is_function(setfenv) -- 5.1 only
  end)
end)
```

- [ ] **Step 4: Run and verify green**

Run from repo root: `busted`
Expected: `2 successes` (0 failures). If busted missing locally: `luarocks install busted` (Lua 5.1 tree; on Windows use hererocks or WSL).

- [ ] **Step 5: Write `.github/workflows/test.yml`**

```yaml
name: tests
on: [push, pull_request]
jobs:
  busted:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: leafo/gh-actions-lua@v10
        with:
          luaVersion: "5.1"
      - uses: leafo/gh-actions-luarocks@v4
      - run: luarocks install busted
      - run: busted
```

- [ ] **Step 6: Commit**

```bash
git add .busted tests .github
git commit -m "Add headless busted test infrastructure and CI"
```

---

### Task 2: Humanizer core module

**Files:**
- Create: `Humanizer.lua`, `tests/humanizer_spec.lua`

**Interfaces:**
- Produces:
  - `Humanizer.New(deps) -> humanizer` where `deps = { random = fn(m,n)/fn(n)/fn(), hour = fn() -> 0..23 }`
  - `humanizer:GetTypingDelay(message) -> seconds` (number)
  - `humanizer:Pick(poolId, entries) -> text` (`entries`: array of strings; anti-repeat per poolId)
  - `humanizer:PickTimed(poolId, universal, bands) -> text` (`bands = { morning = {...}, day = {...}, evening = {...}, night = {...} }`, any band optional)
  - `Humanizer.BandForHour(hour) -> "morning"|"day"|"evening"|"night"`

- [ ] **Step 1: Write failing tests `tests/humanizer_spec.lua`**

```lua
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
```

- [ ] **Step 2: Run to verify failure**

Run: `busted`
Expected: FAIL `module 'Humanizer' not found`

- [ ] **Step 3: Implement `Humanizer.lua`**

```lua
local _, ns = ...

local Humanizer = {}
Humanizer.__index = Humanizer

local BASE_DELAY, PER_CHAR, MAX_DELAY, JITTER = 1.5, 0.06, 6, 0.3
local HISTORY_MAX = 3

function Humanizer.New(deps)
  local self = setmetatable({}, Humanizer)
  self.random = deps.random
  self.hour = deps.hour
  self.history = {} -- poolId -> array of recently picked texts (newest last)
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

function Humanizer:Pick(poolId, entries)
  local history = self.history[poolId]
  if not history then history = {}; self.history[poolId] = history end
  local k = math.min(HISTORY_MAX, #entries - 1)

  local blocked = {}
  for i = math.max(1, #history - k + 1), #history do blocked[history[i]] = true end

  local candidates = {}
  for _, text in ipairs(entries) do
    if not blocked[text] then candidates[#candidates + 1] = text end
  end
  if #candidates == 0 then candidates = entries end

  local text = candidates[self.random(#candidates)]
  history[#history + 1] = text
  if #history > HISTORY_MAX then table.remove(history, 1) end
  return text
end

function Humanizer:PickTimed(poolId, universal, bands)
  local merged = {}
  for _, t in ipairs(universal) do merged[#merged + 1] = t end
  local band = bands and bands[Humanizer.BandForHour(self.hour())]
  if band then
    for _, t in ipairs(band) do merged[#merged + 1] = t end
  end
  return self:Pick(poolId, merged)
end

if ns then ns.Humanizer = Humanizer end
return Humanizer
```

- [ ] **Step 4: Run to verify green**

Run: `busted`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add Humanizer.lua tests/humanizer_spec.lua
git commit -m "Add Humanizer core: typing delay, anti-repeat, time-of-day pools"
```

---

### Task 3: SocialGate core - budget and per-person cooldown

**Files:**
- Create: `SocialGate.lua`, `tests/socialgate_spec.lua`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces:
  - `SocialGate.New(deps) -> gate` where `deps = { now = fn() -> epoch seconds, settings = fn() -> settingsTable, state = table, debug = fn(msg) or nil }`
  - `settingsTable` fields used: `budgetPerHour` (number), `personCooldownHours` (number), `listen` (bool)
  - `state` fields (created lazily by the gate): `sends = {ts,...}`, `perPerson = {name=ts}`, `welcomed = {name=ts}`, `welcomeSends = {ts,...}`
  - `gate:MaySend(trigger, targetName|nil) -> ok, reason` (reason: `"budget"|"person-cd"`)
  - `gate:Record(trigger, targetName|nil)`
  - `gate:Prune()` (call on login; drops stale entries)

- [ ] **Step 1: Write failing tests (first block of `tests/socialgate_spec.lua`)**

```lua
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
```

- [ ] **Step 2: Run to verify failure**

Run: `busted`
Expected: FAIL `module 'SocialGate' not found`

- [ ] **Step 3: Implement `SocialGate.lua`**

```lua
local _, ns = ...

local SocialGate = {}
SocialGate.__index = SocialGate

local HOUR = 3600
local PERSON_PRUNE_AGE = 24 * HOUR
local WELCOME_PRUNE_AGE = 30 * 24 * HOUR

function SocialGate.New(deps)
  local self = setmetatable({}, SocialGate)
  self.now = deps.now
  self.settings = deps.settings
  self.debug = deps.debug or function() end
  local state = deps.state
  state.sends = state.sends or {}
  state.perPerson = state.perPerson or {}
  state.welcomed = state.welcomed or {}
  state.welcomeSends = state.welcomeSends or {}
  self.state = state
  self.pending = {}
  self.nextPendingId = 1
  return self
end

local function pruneWindow(list, cutoff)
  while list[1] and list[1] <= cutoff do
    table.remove(list, 1)
  end
end

function SocialGate:MaySend(trigger, targetName)
  local now = self.now()
  local s = self.settings()

  pruneWindow(self.state.sends, now - HOUR)
  if #self.state.sends >= s.budgetPerHour then
    self.debug("blocked: budget (" .. trigger .. ")")
    return false, "budget"
  end

  if targetName then
    local last = self.state.perPerson[targetName]
    if last and (now - last) < s.personCooldownHours * HOUR then
      self.debug("blocked: person-cd (" .. targetName .. ")")
      return false, "person-cd"
    end
  end

  return true
end

function SocialGate:Record(trigger, targetName)
  local now = self.now()
  local sends = self.state.sends
  sends[#sends + 1] = now
  if targetName then
    self.state.perPerson[targetName] = now
  end
end

function SocialGate:Prune()
  local now = self.now()
  pruneWindow(self.state.sends, now - HOUR)
  pruneWindow(self.state.welcomeSends, now - HOUR)
  for name, ts in pairs(self.state.perPerson) do
    if now - ts > PERSON_PRUNE_AGE then self.state.perPerson[name] = nil end
  end
  for name, ts in pairs(self.state.welcomed) do
    if now - ts > WELCOME_PRUNE_AGE then self.state.welcomed[name] = nil end
  end
end

if ns then ns.SocialGate = SocialGate end
return SocialGate
```

- [ ] **Step 4: Run to verify green**

Run: `busted`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add SocialGate.lua tests/socialgate_spec.lua
git commit -m "Add SocialGate core: hourly budget and per-person cooldown"
```

---

### Task 4: SocialGate pending slots, social listening, welcome rules

**Files:**
- Modify: `SocialGate.lua` (append methods before the `if ns then` tail)
- Modify: `tests/socialgate_spec.lua` (append describe blocks)

**Interfaces:**
- Produces (in addition to Task 3):
  - `SocialGate.INTENTS` word lists: `grats`, `welcome`, `greeting`
  - `gate:AddPending(intent, channel) -> id`
  - `gate:OnChatMessage(channel, sender, text)` (cancels matching pendings)
  - `gate:TakePending(id) -> allowed` (true if not cancelled; removes slot)
  - `gate:MayWelcome(name) -> ok, reason` (reason: `"already-welcomed"|"welcome-cap"`; also runs MaySend rules internally? NO - caller combines)
  - `gate:RecordWelcome(name)`

- [ ] **Step 1: Append failing tests to `tests/socialgate_spec.lua`**

```lua
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
```

Note: `makeGate` must return `gate, clock, state, settings` (Task 3 already does); the re-init test above needs a second clock - extend `makeGate` so `opts.state` reuse works with a fresh clock per call (it already does since each call makes its own `clock`).

- [ ] **Step 2: Run to verify failure**

Run: `busted`
Expected: FAIL `attempt to call method 'AddPending' (a nil value)`

- [ ] **Step 3: Append implementation to `SocialGate.lua`**

```lua
SocialGate.INTENTS = {
  grats = { "gz", "gratz", "grats", "congrats", "congratulations", "grtz" },
  welcome = { "welcome", "wb" },
  greeting = { "hi", "hello", "hey", "yo", "o/", "morning", "evening", "sup", "hiya" },
}

function SocialGate:AddPending(intent, channel)
  local id = self.nextPendingId
  self.nextPendingId = id + 1
  self.pending[id] = { intent = intent, channel = channel, cancelled = false }
  return id
end

function SocialGate:OnChatMessage(channel, sender, text)
  if not next(self.pending) then return end
  local words = {}
  for word in text:lower():gmatch("[%a/]+") do words[word] = true end
  for _, slot in pairs(self.pending) do
    if slot.channel == channel and not slot.cancelled then
      for _, keyword in ipairs(SocialGate.INTENTS[slot.intent] or {}) do
        if words[keyword] then
          slot.cancelled = true
          self.debug("blocked: someone-answered (" .. slot.intent .. ")")
          break
        end
      end
    end
  end
end

function SocialGate:TakePending(id)
  local slot = self.pending[id]
  self.pending[id] = nil
  return slot ~= nil and not slot.cancelled
end

function SocialGate:MayWelcome(name)
  local now = self.now()
  if self.state.welcomed[name] then
    self.debug("blocked: already-welcomed (" .. name .. ")")
    return false, "already-welcomed"
  end
  pruneWindow(self.state.welcomeSends, now - HOUR)
  if #self.state.welcomeSends >= 2 then
    self.debug("blocked: welcome-cap")
    return false, "welcome-cap"
  end
  return true
end

function SocialGate:RecordWelcome(name)
  local now = self.now()
  self.state.welcomed[name] = now
  local ws = self.state.welcomeSends
  ws[#ws + 1] = now
end
```

- [ ] **Step 4: Run to verify green**

Run: `busted`
Expected: all pass (including the 100-join wave test).

- [ ] **Step 5: Commit**

```bash
git add SocialGate.lua tests/socialgate_spec.lua
git commit -m "Add SocialGate listening, pending slots, and welcome rules"
```

---

### Task 5: Wire core into the addon (adapters, defaults, existing flows)

**Files:**
- Modify: `AutoSay.toc` (add `SocialGate.lua`, `Humanizer.lua` after `Messages.lua`, before `Core.lua`)
- Modify: `Core.lua` (defaults, init, greeting send path)
- Modify: `Events.lua` (chat listening registration)
- Modify: `Messages.lua` (time-of-day greeting bands)

**Interfaces:**
- Consumes: everything from Tasks 2-4 via `local _, ns = ...` namespace (`ns.SocialGate`, `ns.Humanizer`). NOTE: check how existing files get the namespace - Messages.lua populates the global `AutoSay` table. If the addon does not already use the TOC vararg namespace, attach modules to the global instead: in each core module replace the tail guard with `if _G.AutoSay then _G.AutoSay.SocialGate = SocialGate end` (mirror whatever Messages.lua does), and update tests only if the `require` return stops working (it must not - keep `return Module` as last line).
- Produces: `Addon.socialGate`, `Addon.humanizer` live objects; existing greetings/goodbyes/reconnect go through gate+humanizer.

- [ ] **Step 1: TOC ordering**

In `AutoSay.toc` core files section:

```
# Core files
Messages.lua
SocialGate.lua
Humanizer.lua
Core.lua
Events.lua
Config.lua
```

- [ ] **Step 2: Add defaults in Core.lua**

In the AceDB defaults table (next to existing `profile` sections, ~line 100-230) add:

```lua
        social = {
            budgetPerHour = 12,
            personCooldownHours = 4,
            listen = true,
            typingDelay = true,
            timeOfDay = true,
            guildGrats = false,
            guildWelcome = false,
        },
```

and a `char` section to the same defaults table (AceDB supports `char = {}` alongside `profile`):

```lua
    char = {
        social = {},
    },
```

- [ ] **Step 3: Instantiate core objects in OnInitialize (after `self.db = LibStub("AceDB-3.0"):New(...)`)**

```lua
    local Modules = AutoSay -- or the ns table, per Step "Interfaces" note
    self.socialGate = Modules.SocialGate.New{
        now = time,
        settings = function() return self.db.profile.social end,
        state = self.db.char.social,
        debug = function(msg) self:DebugPrint("SocialGate:", msg) end,
    }
    self.humanizer = Modules.Humanizer.New{
        random = math.random,
        hour = function() return tonumber(date("%H")) end,
    }
    self.socialGate:Prune()
```

- [ ] **Step 4: Route existing auto-messages through the gate**

In `Addon:SendGreeting(playerNames, reason)` (Core.lua ~line 808), after the `settings.enabled` check add:

```lua
    local target = playerNames and playerNames[1] or nil
    local ok, why = self.socialGate:MaySend("greeting", target)
    if not ok then
        self:DebugPrint("SendGreeting gated:", why)
        if self:IsTestMode() then self:TestPrint("Greeting blocked: " .. why) end
        return
    end
```

In the success path of `Addon:DoSendMessage` (after the real `SendChatMessage` pcall succeeds AND in the test-mode simulated branch) add one line:

```lua
    if self.socialGate then self.socialGate:Record("auto") end
```

(`Record` without target here; per-person stamps are recorded by the specific triggers that know the target.) Apply the same `MaySend("goodbye")` / `MaySend("reconnect")` guard at the top of `SendGoodbye` and `HandleGroupReconnect` decision points - same 5-line pattern, trigger name differs.

- [ ] **Step 5: Humanized delay for auto messages**

In `Addon:SendMessageToChat` replace the fixed delay selection:

```lua
    local delay = self.db.profile.messageDelay
    if self.db.profile.social.typingDelay and self.humanizer then
        delay = math.max(delay or 0, self.humanizer:GetTypingDelay(message))
    end
```

- [ ] **Step 6: Time-of-day greeting pools**

In `Messages.lua` add:

```lua
-- Time-of-day greeting extras, mixed into the universal pool by local hour
AutoSay.GreetingsTimeOfDay = {
    morning = { "morning!", "good morning all", "morning o/" },
    evening = { "evening!", "good evening", "evening all o/" },
    night = { "up late too? hi", "night owls unite o/" },
}
```

In `Addon:GetRandomMessageForChannel` (Core.lua ~750), when `messageType == "greetings"` and `self.db.profile.social.timeOfDay`, build the final list through the humanizer:

```lua
    if messageType == "greetings" and self.db.profile.social.timeOfDay and self.humanizer then
        return self.humanizer:PickTimed("greet:" .. channel, enabledList, AutoSay.GreetingsTimeOfDay)
    end
    -- otherwise existing random selection, but replace the lastGreetingText
    -- de-dup with: return self.humanizer:Pick(messageType .. ":" .. channel, enabledList)
```

where `enabledList` is the already-computed array of enabled message texts. Delete the old `lastGreetingText` compare/assign code (search `lastGreetingText` in Core.lua) - the humanizer history replaces it.

- [ ] **Step 7: Chat listening registration in Events.lua**

Where events are registered, add:

```lua
    self:RegisterEvent("CHAT_MSG_PARTY", "OnSocialChat")
    self:RegisterEvent("CHAT_MSG_PARTY_LEADER", "OnSocialChat")
    self:RegisterEvent("CHAT_MSG_RAID", "OnSocialChat")
    self:RegisterEvent("CHAT_MSG_RAID_LEADER", "OnSocialChat")
    self:RegisterEvent("CHAT_MSG_INSTANCE_CHAT", "OnSocialChat")
    self:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER", "OnSocialChat")
    self:RegisterEvent("CHAT_MSG_GUILD", "OnSocialChat")
```

and the handler (skip own messages; normalize channel):

```lua
local CHAT_EVENT_CHANNEL = {
    CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY",
    CHAT_MSG_RAID = "RAID", CHAT_MSG_RAID_LEADER = "RAID",
    CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT", CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
    CHAT_MSG_GUILD = "GUILD",
}

function Addon:OnSocialChat(event, text, sender)
    if not self.db.profile.social.listen then return end
    local me = UnitName("player")
    local senderName = sender and sender:match("^([^%-]+)") or sender
    if senderName == me then return end
    self.socialGate:OnChatMessage(CHAT_EVENT_CHANNEL[event], senderName, text)
end
```

- [ ] **Step 8: TestReset integration**

In `Addon:TestReset()` (Core.lua ~1540) add session-state cleanup (persistent budget/person state intentionally NOT cleared - matches live behavior per spec):

```lua
    if self.socialGate then
        self.socialGate.pending = {}
    end
    if self.humanizer then
        self.humanizer.history = {}
    end
```

- [ ] **Step 9: Verify**

Run: `busted` (still green - core untouched).
In-game smoke: `/reload`, `/as testmode`, join test party -> greeting arrives with a 2-5s human delay; `/as test` blocked messages print gate reasons.

- [ ] **Step 9: Commit**

```bash
git add AutoSay.toc Core.lua Events.lua Messages.lua
git commit -m "Wire SocialGate and Humanizer into existing message flows"
```

---

### Task 6: Social config tab + locale strings

**Files:**
- Modify: `Config.lua` (new "Social" group), `Locales/enUS.lua`

**Interfaces:**
- Consumes: `Addon.db.profile.social` fields from Task 5.
- Produces: user-visible toggles; trigger toggles `guildGrats`/`guildWelcome` referenced by Tasks 7-8.

- [ ] **Step 1: Locale strings (append to `Locales/enUS.lua`)**

```lua
L["Social"] = "Social"
L["Hourly message budget"] = "Hourly message budget"
L["Maximum automatic messages per hour, all triggers combined"] = "Maximum automatic messages per hour, all triggers combined"
L["Per-person cooldown (hours)"] = "Per-person cooldown (hours)"
L["Do not target the same player more often than this"] = "Do not target the same player more often than this"
L["Social listening"] = "Social listening"
L["Skip a message if someone else already said it"] = "Skip a message if someone else already said it"
L["Human typing delay"] = "Human typing delay"
L["Delay messages as if typed by hand"] = "Delay messages as if typed by hand"
L["Time-of-day greetings"] = "Time-of-day greetings"
L["Mix in morning/evening phrases by local time"] = "Mix in morning/evening phrases by local time"
L["Congratulate guild achievements"] = "Congratulate guild achievements"
L["Send grats when a guild member earns an achievement"] = "Send grats when a guild member earns an achievement"
L["Welcome new guild members"] = "Welcome new guild members"
L["Greet players who join the guild (max 2 per hour, once per player)"] = "Greet players who join the guild (max 2 per hour, once per player)"
```

- [ ] **Step 2: Add "Social" group to the options tree in Config.lua**

Insert alongside the existing top-level groups (party/raid/guild), order after General:

```lua
        social = {
            type = "group",
            name = L["Social"],
            order = 5,
            args = {
                budgetPerHour = {
                    type = "range", order = 1, min = 4, max = 30, step = 1,
                    name = L["Hourly message budget"],
                    desc = L["Maximum automatic messages per hour, all triggers combined"],
                    get = function() return Addon.db.profile.social.budgetPerHour end,
                    set = function(_, v) Addon.db.profile.social.budgetPerHour = v end,
                },
                personCooldownHours = {
                    type = "range", order = 2, min = 1, max = 24, step = 1,
                    name = L["Per-person cooldown (hours)"],
                    desc = L["Do not target the same player more often than this"],
                    get = function() return Addon.db.profile.social.personCooldownHours end,
                    set = function(_, v) Addon.db.profile.social.personCooldownHours = v end,
                },
                listen = {
                    type = "toggle", order = 3, width = "full",
                    name = L["Social listening"],
                    desc = L["Skip a message if someone else already said it"],
                    get = function() return Addon.db.profile.social.listen end,
                    set = function(_, v) Addon.db.profile.social.listen = v end,
                },
                typingDelay = {
                    type = "toggle", order = 4, width = "full",
                    name = L["Human typing delay"],
                    desc = L["Delay messages as if typed by hand"],
                    get = function() return Addon.db.profile.social.typingDelay end,
                    set = function(_, v) Addon.db.profile.social.typingDelay = v end,
                },
                timeOfDay = {
                    type = "toggle", order = 5, width = "full",
                    name = L["Time-of-day greetings"],
                    desc = L["Mix in morning/evening phrases by local time"],
                    get = function() return Addon.db.profile.social.timeOfDay end,
                    set = function(_, v) Addon.db.profile.social.timeOfDay = v end,
                },
                guildGrats = {
                    type = "toggle", order = 6, width = "full",
                    name = L["Congratulate guild achievements"],
                    desc = L["Send grats when a guild member earns an achievement"],
                    get = function() return Addon.db.profile.social.guildGrats end,
                    set = function(_, v) Addon.db.profile.social.guildGrats = v end,
                },
                guildWelcome = {
                    type = "toggle", order = 7, width = "full",
                    name = L["Welcome new guild members"],
                    desc = L["Greet players who join the guild (max 2 per hour, once per player)"],
                    get = function() return Addon.db.profile.social.guildWelcome end,
                    set = function(_, v) Addon.db.profile.social.guildWelcome = v end,
                },
            },
        },
```

- [ ] **Step 3: In-game verify**

`/reload`, open settings -> Social tab present, sliders/toggles read and write (change value, `/reload`, value persists).

- [ ] **Step 4: Commit**

```bash
git add Config.lua Locales/enUS.lua
git commit -m "Add Social settings tab"
```

---

### Task 7: Guild achievement grats trigger

**Files:**
- Modify: `Messages.lua` (grats pool), `Events.lua` (event adapter), `Core.lua` (send helper), `tests/socialgate_spec.lua` (flow test)

**Interfaces:**
- Consumes: `gate:MaySend/AddPending/TakePending/Record`, `humanizer:Pick/GetTypingDelay`, `db.profile.social.guildGrats`.
- Produces: `Addon:SendGuildGrats(playerName)` adapter helper.

- [ ] **Step 1: Add pool to `Messages.lua`**

```lua
-- Guild achievement congratulations
AutoSay.GuildGrats = {
    "gz", "grats!", "gratz {name}", "grats {name}!", "nice one {name}!", "congrats {name}!",
}
```

- [ ] **Step 2: Headless flow test (append to `tests/socialgate_spec.lua`)**

```lua
describe("grats flow (gate composition)", function()
  it("second grats to same player is person-blocked, other player passes", function()
    local gate = makeGate{}
    assert.is_true(gate:MaySend("grats", "Bob"))
    local id = gate:AddPending("grats", "GUILD")
    assert.is_true(gate:TakePending(id))
    gate:Record("grats", "Bob")
    assert.is_false(gate:MaySend("grats", "Bob"))
    assert.is_true(gate:MaySend("grats", "Alice"))
  end)
end)
```

Run: `busted` -> passes already (composition of tested parts); keep as regression net.

- [ ] **Step 3: Adapter in Events.lua**

Register: `self:RegisterEvent("CHAT_MSG_GUILD_ACHIEVEMENT", "OnGuildAchievement")`

```lua
function Addon:OnGuildAchievement(event, message, _, _, _, sender)
    if not self.db.profile.enabled then return end
    if not self.db.profile.social.guildGrats then return end
    local name = (sender and sender:match("^([^%-]+)")) or message:match("^([^%s]+)")
    if not name or name == UnitName("player") then return end
    self:SendGuildGrats(name)
end
```

- [ ] **Step 4: Send helper in Core.lua**

```lua
function Addon:SendGuildGrats(name)
    local ok, why = self.socialGate:MaySend("grats", name)
    if not ok then
        if self:IsTestMode() then self:TestPrint("Grats blocked: " .. why) end
        return
    end
    local text = self.humanizer:Pick("guildgrats", AutoSay.GuildGrats):gsub("{name}", name)
    local pendingId = self.socialGate:AddPending("grats", "GUILD")
    local delay = 4 + math.random() * 6 -- 4-10s listening window per spec
    self:ScheduleTimer(function()
        if not self.socialGate:TakePending(pendingId) then
            if self:IsTestMode() then self:TestPrint("Grats blocked: someone-answered") end
            return
        end
        self.socialGate:Record("grats", name)
        self:SendMessageToChat(text, "GUILD")
    end, delay)
end
```

- [ ] **Step 5: Test-mode command**

In the test command dispatcher (Core.lua, near existing `/as test` handlers) add case `grats`:

```lua
    elseif arg == "grats" then
        self:TestPrint("=== Simulating GUILD ACHIEVEMENT (TestGuildie) ===")
        self:SendGuildGrats("TestGuildie")
```

- [ ] **Step 6: Verify + commit**

Run: `busted` green. In-game: `/as testmode`, `/as test grats` twice -> first schedules simulated send, second prints `Grats blocked: person-cd`.

```bash
git add Messages.lua Events.lua Core.lua tests/socialgate_spec.lua
git commit -m "Add guild achievement grats trigger"
```

---

### Task 8: Guild newcomer welcome trigger

**Files:**
- Modify: `Messages.lua` (welcome pool), `Events.lua` (system message adapter), `Core.lua` (send helper + test command)

**Interfaces:**
- Consumes: `gate:MayWelcome/RecordWelcome/MaySend/Record`, `humanizer:Pick`, `db.profile.social.guildWelcome`.
- Produces: `Addon:SendGuildWelcome(playerName)`.

- [ ] **Step 1: Pool in `Messages.lua`**

```lua
-- New guild member welcomes
AutoSay.GuildWelcome = {
    "welcome!", "welcome {name}!", "welcome to the guild, {name}!", "o/ welcome {name}",
}
```

- [ ] **Step 2: System-message adapter in Events.lua**

Register: `self:RegisterEvent("CHAT_MSG_SYSTEM", "OnSystemMessage")` (if not already registered; if registered, extend the existing handler).

```lua
-- ERR_GUILD_JOIN_S = "%s has joined the guild." - build a robust pattern from
-- the constant so non-English clients work too.
local GUILD_JOIN_PATTERN = "^" .. ERR_GUILD_JOIN_S:gsub("%%s", "(%%S+)"):gsub("%.", "%%.") .. "$"

function Addon:OnSystemMessage(event, message)
    if not self.db.profile.enabled then return end
    if not self.db.profile.social.guildWelcome then return end
    local name = message:match(GUILD_JOIN_PATTERN)
    if name then
        self:SendGuildWelcome(name)
    end
end
```

- [ ] **Step 3: Send helper in Core.lua**

```lua
function Addon:SendGuildWelcome(name)
    local okW, whyW = self.socialGate:MayWelcome(name)
    if not okW then
        if self:IsTestMode() then self:TestPrint("Welcome blocked: " .. whyW) end
        return
    end
    local ok, why = self.socialGate:MaySend("welcome", name)
    if not ok then
        if self:IsTestMode() then self:TestPrint("Welcome blocked: " .. why) end
        return
    end
    local text = self.humanizer:Pick("guildwelcome", AutoSay.GuildWelcome):gsub("{name}", name)
    local pendingId = self.socialGate:AddPending("welcome", "GUILD")
    local delay = 5 + math.random() * 10 -- 5-15s per spec
    self:ScheduleTimer(function()
        if not self.socialGate:TakePending(pendingId) then
            if self:IsTestMode() then self:TestPrint("Welcome blocked: someone-answered") end
            return
        end
        self.socialGate:RecordWelcome(name)
        self.socialGate:Record("welcome", name)
        self:SendMessageToChat(text, "GUILD")
    end, delay)
end
```

- [ ] **Step 4: Test-mode command `guildjoin`**

```lua
    elseif arg == "guildjoin" then
        self.testGuildJoinCounter = (self.testGuildJoinCounter or 0) + 1
        local name = "TestNewbie" .. self.testGuildJoinCounter
        self:TestPrint("=== Simulating GUILD JOIN (" .. name .. ") ===")
        self:SendGuildWelcome(name)
```

- [ ] **Step 5: Verify + commit**

Run: `busted` green (welcome rules covered in Task 4 incl. 100-join wave). In-game: `/as test guildjoin` three times fast -> third prints `Welcome blocked: welcome-cap`.

```bash
git add Messages.lua Events.lua Core.lua
git commit -m "Add guild newcomer welcome trigger with hard caps"
```

---

### Task 9: Release prep (no tag)

**Files:**
- Modify: `CHANGELOG.md` (overwrite per repo release rules), `CLAUDE.md` (testing section)

- [ ] **Step 1: Overwrite CHANGELOG.md**

```markdown
## [1.5.0] - unreleased

### Added

- Social foundation: a global anti-spam gate for every automatic message -
  hourly budget (default 12/hour), per-person cooldown (default 4h), and
  social listening (your message is skipped if someone already said it).
- Human typing delay: messages go out after a short, length-based delay
  instead of instantly.
- Smarter phrase rotation: recently used phrases are not repeated.
- Time-of-day greetings (morning/evening/night phrase mixes).
- Optional guild triggers (off by default): grats on guild achievements,
  welcome for new guild members (max 2 per hour, once per player ever).
- Headless test suite (busted) and GitHub Actions CI.

### Notes

- All new triggers are opt-in. Existing behavior only gains the anti-spam
  protections and more human timing.
```

- [ ] **Step 2: Document testing in CLAUDE.md**

Append section:

```markdown
## Testing

- Headless: `busted` from repo root (Lua 5.1). Core modules SocialGate.lua /
  Humanizer.lua are WoW-free; specs in `tests/*_spec.lua`. CI runs on push.
- In-game smoke: `/as testmode`, then `/as test`, `/as test grats`,
  `/as test guildjoin`. Gate rejections print their reason.
```

- [ ] **Step 3: Final full run + in-game smoke checklist**

Run: `busted` -> all green.
In-game: reload mid-budget survives (send 2 test messages, `/reload`, check `/as test` reports remaining budget); grats + welcome flows per Tasks 7-8; normal party greeting still works with delay.

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md CLAUDE.md
git commit -m "Prepare 1.5.0 changelog and testing docs"
```
