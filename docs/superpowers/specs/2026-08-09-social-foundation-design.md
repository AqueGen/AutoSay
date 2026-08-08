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

Two new files, wired into AutoSay.toc after Core.lua. Core.lua is not grown
further (it is already ~2000 lines); existing queue/cooldown logic is not
modified, the new layer sits in front of it.

```
Event (Events.lua)
  -> SocialGate:MaySend(trigger, targetName)   -- budget? per-person CD? already answered?
  -> Humanizer:Pick(pool, opts)                -- anti-repeat + time-of-day
  -> Humanizer:GetTypingDelay(message)         -- human typing latency
  -> existing Core.lua queue / channel cooldowns (unchanged)
  -> SocialGate:Record(trigger, targetName, phrase)
```

- `SocialGate.lua` - the single yes/no authority for every automatic message.
  All triggers, existing and future, must pass through it.
- `Humanizer.lua` - how a message is produced: phrase selection and delay.

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

- Test mode simulation for each trigger and each gate rejection path.
- Manual QA: reload mid-budget (state survives), two grats events in a row
  (second blocked by budget/person rules), guild chat "gz" from another
  player cancels pending grats, welcome cap with 3+ simulated joins in an
  hour (only 2 fire).

## Phasing

- 1.5.0 (this spec): SocialGate + Humanizer applied to existing greetings/
  goodbyes/reconnect + guild grats + guild welcome.
- 1.6: combat-log thanks, dungeon flow, holiday pools - each new trigger is
  only a `SocialGate:MaySend` client, the core does not change.
