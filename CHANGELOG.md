## [1.5.0] - 2026-08-10

### Added

- Social foundation: an anti-spam gate for every automatic greeting, goodbye
  and guild message - hourly budget (default 12/hour), per-person cooldown
  (default 4h), and social listening in guild chat (your message is skipped
  if a guildmate already said it).
- Human typing delay: messages go out after a short, length-based delay
  instead of instantly.
- Smarter phrase rotation: recently used phrases are not repeated.
- Time-of-day greetings (morning/evening/night phrase mixes).
- Optional guild triggers (off by default): grats on guild achievements,
  welcome for new guild members (max 2 per hour, once per player ever).
- Headless test suite (busted) and GitHub Actions CI.
- `/as selftest` verifies the anti-spam and message logic inside the game and
  prints a pass/fail report. It has no side effects, so it is safe to run at
  any time.
- `/as test status` now shows the gate state: budget used this hour, welcomes
  used, players on cooldown, and how many have ever been welcomed.
- `/as test resetgate` clears those counters when you are done testing.
- `/as dumpdungeons` prints paste-ready Mythic+ dungeon tables harvested from
  your client, and the self-test warns when the current season's dungeon pool
  is not fully covered - both to keep announcements in English after a season
  rotation such as patch 12.1.

### Notes

- All new triggers are opt-in. Existing behavior only gains the anti-spam
  protections and more human timing.
