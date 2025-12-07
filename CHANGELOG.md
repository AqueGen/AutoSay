# Changelog

All notable changes to AutoSay will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.0.3]: https://github.com/AqueGen/AutoSay/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/AqueGen/AutoSay/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/AqueGen/AutoSay/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/AqueGen/AutoSay/releases/tag/v1.0.0
