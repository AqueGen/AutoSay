# AutoSay 1.5.0 "Social Foundation" - Design

Date: 2026-08-09
Status: approved (chat), pending spec review

## Goal

Make AutoSay's automatic messages feel like a friendly human and make it
impossible for the addon to spam, then add the two safest new social triggers.
This release builds the foundation (anti-spam gate + humanizer) and applies it
to existing messages; noisier triggers (combat-log thanks, dungeon flow,
holidays) come in 1.6 on top of the proven core.

## Non-Goals (deferred to 1.6+)

- Thanks for portals/feasts/summons/battle-res (combat log parsing)
- Boss kill / non-M+ dungeon completion messages
- Holiday message pools (Christmas / New Year)
- Any LLM/network-generated text (impossible in WoW sandbox anyway)

## Architecture

Testable-core (hexagonal) layout: all decision logic lives in WoW-agnostic
modules that run under plain Lua 5.1; game code is thin adapters that only
translate real events into core calls.

```
Adapters (thin, in-game only)          Core (pure Lua, headless-testable)
---------------------------------      -----------------------------------
Events.lua  (event subscriptions)  ->  SocialGate:MaySend(trigger, target)
Core.lua    (Ace glue, timers,     ->  Humanizer:Pick(pool, opts)
             SendChatMessage)      ->  Humanizer:GetTypingDelay(message)
                                   ->  SocialGate:Record(trigger, target, phrase)
```

- `SocialGate.lua` - the single yes/no authority for every automatic message.
  All triggers, existing and future, must pass through it.
- `Humanizer.lua` - how a message is produced: phrase selection and delay.
- Core modules never touch frames, events, or WoW globals directly. External
  dependencies are injected at init: `now()`, `random()`, a send sink, and a
  state table (the adapter passes `db.char.social` / `db.profile.social`).
  This is what makes them runnable outside the game.

**Existing logic migration.** Core.lua (~2000 lines) mixes decisions with
Ace glue. It is not rewritten in one go; decision logic is extracted into
the testable core **on touch**: whatever 1.5.0 has to modify anyway
(greeting/goodbye/reconnect decision paths, phrase selection replacing
`lastGreetingText`) moves into SocialGate/Humanizer with tests. Untouched
subsystems (M+ announcements, guild login greetings) migrate in later
releases the same way. End state: adapters contain trigger wiring only.

## SocialGate

Three independent filters; all must pass. Every rejection goes to DebugPrint
with a reason string: "budget", "person-cd", "someone-answered".

1. **Hourly budget.** Sliding window of send timestamps (epoch `time()`),
   default 12 auto-messages per hour, slider 4-30. Window full = silence until
   it frees up. Applies to every automatic message of any trigger.
2. **Per-person cooldown.** At most 1 auto-message aimed at the same player
   per 4 hours (configurable). Table `name -> timestamp`, entries older than
   24h pruned on login.
3. **Social listening.** Triggers do not fire instantly: the message sits in
   a pending slot for its humanized delay. During that window the addon
   listens to the target channel (CHAT_MSG_PARTY / RAID / INSTANCE_CHAT /
   GUILD); if another player already sent a message matching the same intent
   (keyword pattern lists per intent: grats/gz, wb/welcome, hi/hello/o/, ...),
   the pending message is silently cancelled. Default on.

Storage: settings in `db.profile.social`, live state in `db.char.social`
(AceDB char section). SavedVariables are plain in-memory Lua tables that WoW
serializes to disk once on logout/reload - zero runtime I/O. Epoch timestamps
keep budget and cooldowns valid across /reload and relog. A hard client crash
loses at most the since-last-save state; acceptable degradation, no extra
protection built.

## Humanizer

- **Typing delay.** `1.5s + 0.06s * #message`, +-30% jitter, capped at 6s.
  Replaces the fixed `messageDelay` for automatic messages (the existing
  slider acts as a minimum). Combat deferral behavior unchanged.
- **Anti-repeat.** Per message pool, the last 3 picked phrases are excluded
  from random selection (K = min(3, poolSize - 1)). Session memory only;
  replaces the current 1-step `lastGreetingText`.
- **Time-of-day pools.** Four bands by local clock: morning 5-11, day 11-17,
  evening 17-23, night 23-5. Small tagged phrase sets (e.g. "morning!") are
  mixed with the universal pool when the band matches. Default on.

## New Triggers (both default OFF, opt-in)

1. **Guild achievement grats.** Event `CHAT_MSG_GUILD_ACHIEVEMENT`. Random
   pending delay 4-10s, listening on GUILD; if anyone already congratulated,
   skip. Phrase pool: "gz", "grats {name}!", etc. Goes through all SocialGate
   filters.
2. **Guild newcomer welcome.** Detected via system message
   (`ERR_GUILD_JOIN_S` pattern on CHAT_MSG_SYSTEM). Hard extra cap:
   **max 2 welcomes per hour** regardless of remaining budget, and each
   player is welcomed **once ever** (persistent `db.char` set, entries pruned
   after 30 days). A mass guild invite wave therefore produces at most 2
   messages.

## Config UI

New "Social" tab in Config.lua:
- budget slider (4-30/hour), per-person cooldown (1-24h)
- toggles: social listening, typing delay, time-of-day pools
- trigger toggles: guild grats, guild welcome
Anti-repeat has no toggle (always on, invisible improvement).

## Test Mode

- `/as test grats`, `/as test guildjoin` simulate the new triggers.
- Gate rejections print their reason in test mode ("blocked: budget",
  "blocked: person-cd", "blocked: someone-answered").
- TestReset clears pending slots and per-session humanizer history, but not
  persistent budget/person state (matches live behavior).

## Testing Plan

Three layers; the headless layer is the primary safety net.

1. **Headless tests (primary).** `tests/` folder in the repo, run with
   busted under Lua 5.1, plus `tests/wow_stub.lua` with the minimal globals
   the core touches. GitHub Actions workflow runs the suite on every push
   and PR; same single command locally. Fake clock and captured send sink
   make the spam scenarios deterministic:
   - 100 guild joins in a minute -> exactly 2 welcomes sent
   - "gz" from another player inside the pending window -> grats cancelled
   - 12 sends in an hour -> 13th blocked; window slides correctly
   - serialize state table + re-init core -> budget continues (/reload sim)
   - per-person cooldown, anti-repeat rotation, time-of-day band selection
2. **Adapters stay untested headless.** Events.lua wiring is argument
   pass-through only; kept too thin to break.
3. **In-game smoke (secondary).** `/as test ...` commands verify adapters
   are actually wired to live events. One minute before release, not the
   main loop. No automated in-game test tab: everything it could assert is
   covered better by layer 1, and real events cannot be honestly simulated
   from inside the game anyway.

## Phasing

- 1.5.0 (this spec): testable core (SocialGate + Humanizer) with headless
  test suite + CI, applied to existing greetings/goodbyes/reconnect (their
  decision logic extracted on touch) + guild grats + guild welcome.
- 1.6: combat-log thanks, dungeon flow, holiday pools - each new trigger is
  only a `SocialGate:MaySend` client plus tests, the core does not change.
- Later: remaining Core.lua subsystems (M+, guild login) migrate into the
  testable core the same extract-on-touch way.
