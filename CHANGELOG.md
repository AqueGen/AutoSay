# Changelog

All notable changes to AutoSay will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1] - 2026-02-23

### Fixed

- Debug logs no longer appear when Simulation is disabled
- Disabling Simulation now also turns off the Logging toggle

## [1.1.0] - 2026-02-22

### Added

- **Cooldown Message Queue**: Messages blocked by cooldown are saved and sent later as a batch with automatic name merging
- **Greeting Text Caching**: Prevents different random greetings within the same cooldown window
- **Window Persistence**: Settings window size and position are saved across sessions via SavedVariables
- **Reset Window Size**: Button in General settings to restore default window dimensions (1000×700)
- **Ukrainian Phrases**: New greetings and goodbyes in Ukrainian language

### Changed

- **Settings UI Redesign**: Consolidated 9 channel tabs into 3 (Party/Raid/Guild) with Greetings/Goodbyes/Reconnects sub-tabs
- Disabled channels now hide their tabs entirely with instant tree refresh
- Moved Simulation toggle to General settings; Simulation tab hidden when disabled
- Renamed "Test Mode" to "Simulation", "Debug" to "Logging"/"Show debug log"
- Added `width="full"` to sub-option toggles to prevent text truncation
- Updated addon title formatting
- Updated Interface version to 120001 (WoW 12.0.1 Midnight)
- Increased reconnect detection delay from 2s to 3s for better reliability on 12.0+

### Fixed

- Fixed race condition in SendMessageToChat where rapid calls all passed cooldown check
- Fixed settings panel opening via AceConfigDialog:Open
- Fixed reconnect detection failing when group state loads after PLAYER_ENTERING_WORLD on 12.0+
  - Added retry mechanism with 5s delay as fallback for late group loading
- Fixed test mode showing no feedback when messages are blocked by cooldown
  - Now displays remaining cooldown time in test mode
- Added graceful error handling for SendChatMessage in 12.0 instance restrictions (M+ keys, PvP, encounters)

## [1.0.3] - 2024-12-07

### Added

- CHANGELOG.md with full release history

## [1.0.2] - 2024-12-07

### Changed
- Updated Interface version to 110207 (WoW 11.2.7)
- Updated TOC notes to mention reconnect messages feature
- Improved README documentation with accurate feature descriptions

## [1.0.1] - 2024-12-06

### Added
- **Reconnect Messages**: Send automatic messages when reconnecting to party/raid after a disconnect
  - 14 built-in reconnect messages (3 enabled by default)
  - Custom reconnect message support
- **Farewell System**: Automatic goodbye messages when leaving groups
  - Party/Raid farewell on leave
  - Guild farewell on logout
- **About Tab**: Added support messages for Ukraine
- **Reset to Defaults**: Button to restore all settings to default values
- **Per-Trigger Settings**: Enable/disable specific triggers independently
  - On Self Join
  - On Others Join
  - On Reconnect
  - On Leave/Logout

### Changed
- Separated group and guild cooldowns for better control
- Refactored internal "farewell" naming to "goodbye" for consistency
- Improved timing for raid and guild login greetings

### Fixed
- Fixed raid and guild login greeting timing issues
- Improved event handling reliability

## [1.0.0] - 2024-12-05

### Added
- Initial release
- **Per-Channel Configuration**: Independent settings for Party, Raid, and Guild chat
- **Smart Triggers**: Configurable triggers for join, leave, and reconnect events
- **12 Built-in Greetings**: From casual "Hi!" to friendly "Hello there!"
- **12 Built-in Farewells**: From simple "Bye!" to "Later all!"
- **Custom Messages**: Add your own personalized messages per channel
- **Player Name Support**: Optionally include joining player's name in greetings
- **Cooldown System**: Prevent message spam with configurable cooldowns
- **Message Delay**: Configurable delay before sending messages
- **Test Mode**: Test functionality without sending actual messages
- **Debug Mode**: Detailed logging for troubleshooting
- **Profile Support**: Save different configurations per character
- Slash commands: `/autosay`, `/as`
- Integration with Blizzard Settings panel (ESC > Options > AddOns)

---

[1.1.1]: https://github.com/AqueGen/AutoSay/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/AqueGen/AutoSay/compare/v1.0.7...v1.1.0
[1.0.3]: https://github.com/AqueGen/AutoSay/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/AqueGen/AutoSay/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/AqueGen/AutoSay/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/AqueGen/AutoSay/releases/tag/v1.0.0
