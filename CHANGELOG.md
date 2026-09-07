# Changelog

## [1.9.1](https://github.com/AqueGen/AutoSay/compare/v1.9.0...v1.9.1) (2026-09-07)


### Bug Fixes

* ask the client before speaking instead of collecting blocked-action errors ([#26](https://github.com/AqueGen/AutoSay/issues/26)) ([7b484a4](https://github.com/AqueGen/AutoSay/commit/7b484a415f1049563081d60e70b43142168e1a67))

## [1.9.0](https://github.com/AqueGen/AutoSay/compare/v1.8.2...v1.9.0) (2026-09-06)


### Features

* show the profiles tab so styles can differ per character ([#25](https://github.com/AqueGen/AutoSay/issues/25)) ([3123617](https://github.com/AqueGen/AutoSay/commit/312361732226eff282bf2c806183492cb3866388))
* split the completion switch, deepen the phrase pools, retire the What's new popup ([#23](https://github.com/AqueGen/AutoSay/issues/23)) ([6b4b0d8](https://github.com/AqueGen/AutoSay/commit/6b4b0d81b99d4a1fabd0bcbcad0f45124e7877af))

## [1.8.2](https://github.com/AqueGen/AutoSay/compare/v1.8.1...v1.8.2) (2026-08-19)


### Bug Fixes

* resolve the listed dungeon through the ui map id ([#21](https://github.com/AqueGen/AutoSay/issues/21)) ([44e7084](https://github.com/AqueGen/AutoSay/commit/44e708426bc97adc7221d5a79844258238feca0e))
* stay quiet when chat is in messaging lockdown ([#20](https://github.com/AqueGen/AutoSay/issues/20)) ([0af8634](https://github.com/AqueGen/AutoSay/commit/0af8634eec5426c45e1bb54584e16936813d953d))

## [1.8.1](https://github.com/AqueGen/AutoSay/compare/v1.8.0...v1.8.1) (2026-08-16)


### Bug Fixes

* a phrase with a name slot waits for names ([#17](https://github.com/AqueGen/AutoSay/issues/17)) ([838b801](https://github.com/AqueGen/AutoSay/commit/838b8010c5f1531a4d096c93ab90931f02bda5dc))
* put the [names] tag on the switch that fills the slot ([#19](https://github.com/AqueGen/AutoSay/issues/19)) ([1892287](https://github.com/AqueGen/AutoSay/commit/1892287f73416a7d615a6da72847646714accb01))

## [1.8.0](https://github.com/AqueGen/AutoSay/compare/v1.7.0...v1.8.0) (2026-08-16)


### Features

* three of everything in every style ([#13](https://github.com/AqueGen/AutoSay/issues/13)) ([e774cd5](https://github.com/AqueGen/AutoSay/commit/e774cd5b3f8eb3deb2ef993473e2c3586ce74d00))


### Bug Fixes

* repair what the 1.7.0 greeting migration did to saved profiles ([#14](https://github.com/AqueGen/AutoSay/issues/14)) ([687ce6d](https://github.com/AqueGen/AutoSay/commit/687ce6d7ed90bbc69451a1ca985a488183d489ea))
* what two independent reviews found in the migration repair ([#16](https://github.com/AqueGen/AutoSay/issues/16)) ([8c8cae5](https://github.com/AqueGen/AutoSay/commit/8c8cae5d092ed82354d22d94c8f513c690893e57))

## [1.7.0](https://github.com/AqueGen/AutoSay/compare/v1.6.0...v1.7.0) (2026-08-16)


### Features

* record a session log you can copy out ([#9](https://github.com/AqueGen/AutoSay/issues/9)) ([c8a194e](https://github.com/AqueGen/AutoSay/commit/c8a194ee6d68715693da75fc813df073dc1e209e))
* say goodbye when the run ends, not only when you leave ([#8](https://github.com/AqueGen/AutoSay/issues/8)) ([660b04e](https://github.com/AqueGen/AutoSay/commit/660b04e41959a3dc748ae3b55cced301f92cd930))
* split greetings by occasion, rotate phrases properly, log a session ([#11](https://github.com/AqueGen/AutoSay/issues/11)) ([2fd10ee](https://github.com/AqueGen/AutoSay/commit/2fd10ee2b804b78db4f9704575624b8aa329d29e))

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
