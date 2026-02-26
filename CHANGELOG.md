## [1.3.0] - 2026-02-26

### Added

- **Mythic+ Key Announcement**: Automatically announces your keystone in party chat when the group fills to 5/5 players (leader only)
  - Three detection modes: Basic (dungeon name only), With Key Level, and Smart (auto-detect)
  - Customizable messages with `{dungeon}` and `{key}` placeholders
  - Works when you create a Group Finder listing for a Mythic Keystone dungeon
- **M+ Completion Messages**: Sends a message to party chat when a Mythic+ dungeon is completed
  - Separate message pools for timed and depleted runs
  - Placeholders: `{dungeon}`, `{key}`, `{time}`, `{upgrade}`
- **Minimap Icon**: Quick-access button to open AutoSay settings
  - Toggle visibility in General settings
- **M+ Simulation**: Simulate full M+ flow, timed and depleted completions in Simulation mode

### Changed

- Mythic+ feature is now enabled by default for new installations
- CURSEFORGE.md updated with M+ feature description
