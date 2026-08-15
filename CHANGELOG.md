# Changelog

## [1.6.0](https://github.com/AqueGen/AutoSay/compare/v1.5.0...v1.6.0) (2026-08-15)


### Features

* add dedicated Instance channel for LFG/LFR/BG groups ([#4](https://github.com/AqueGen/AutoSay/issues/4)) ([fa81faf](https://github.com/AqueGen/AutoSay/commit/fa81faf114025921abcd86113827a4078b4ac1ab))
* keep the Instance channel out of LFR, add five style bundles with role phrases ([#6](https://github.com/AqueGen/AutoSay/issues/6)) ([ce63632](https://github.com/AqueGen/AutoSay/commit/ce63632152006562bc6c39b0dbaa8d9f27296011))


### Bug Fixes

* one rule for every Enable all and Disable all ([#7](https://github.com/AqueGen/AutoSay/issues/7)) ([e0dcb91](https://github.com/AqueGen/AutoSay/commit/e0dcb919005a3da56f5fb837814e917a474cda23))
* update M+ dungeon pool for Midnight Season 2 ([#2](https://github.com/AqueGen/AutoSay/issues/2)) ([de21578](https://github.com/AqueGen/AutoSay/commit/de215788e36bcea94a9abae8b9312b17fd3a0204))

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
