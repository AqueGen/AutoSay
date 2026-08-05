## [1.4.1] - 2026-08-05

### Added

- Support for WoW 12.1.0.

### Fixed

- Greetings, goodbyes, and reconnect messages were still skipped in instance
  groups (dungeon finder, LFR, battlegrounds): the instance chat channel did
  not pick up your party/raid settings. Instance groups now use party or raid
  settings depending on the group type.
- Custom messages longer than the 255-character chat limit are now rejected
  when added instead of silently failing to send.
- The settings window now refreshes immediately after "Reset to Defaults".
