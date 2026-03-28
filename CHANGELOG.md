## [1.4.0] - 2026-03-28

### Added

- English dungeon names by default for M+ announcements and completion messages. Non-English clients no longer send localized dungeon names that other players can't read.
- "Use client language for dungeon names" toggle in M+ settings to switch back to client locale if preferred.
- Dungeon Names preview section in M+ settings showing all current season dungeons. Updates dynamically when toggling the language setting.
- Hardcoded Midnight Season 1 M+ dungeon pool (Magisters' Terrace, Maisara Caverns, Nexus-Point Xenas, Windrunner Spire, Algeth'ar Academy, Seat of the Triumvirate, Skyreach, Pit of Saron).

### Fixed

- Party greetings and goodbyes now work in LFG/instance groups (dungeon finder, LFR, battlegrounds). Previously, messages sent to PARTY chat were silently dropped in instance groups.
- Updated test simulation dungeons to Midnight Season 1 pool.
- Removed redundant nil guards for channel settings (guaranteed by AceDB defaults).
