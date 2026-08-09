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

### Notes

- All new triggers are opt-in. Existing behavior only gains the anti-spam
  protections and more human timing.
