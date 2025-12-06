# AutoSay

[![CurseForge](https://img.shields.io/badge/CurseForge-AutoSay-orange)](https://www.curseforge.com/wow/addons/autosay)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![WoW Version](https://img.shields.io/badge/WoW-11.2.7+-brightgreen)](https://worldofwarcraft.com)

A World of Warcraft addon that automatically sends greetings and farewells in party, raid, and guild chat. Never forget to say hello or goodbye again!

## Features

### Per-Channel Configuration

Configure each channel independently with its own settings:

- **Party Chat** - Greet your dungeon groups automatically (enabled by default)
- **Raid Chat** - Welcome your raid members (disabled by default)
- **Guild Chat** - Send greetings on login and farewells on logout (disabled by default)

### Smart Triggers
Choose when messages are sent:
- **On Self Join** - When you join a group/raid or log in (guild)
- **On Others Join** - When other players join your group (party/raid only)
- **On Reconnect** - Send reconnect message after disconnecting (party/raid only)
- **On Leave** - Send farewells when leaving groups
- **On Logout** - Send guild farewell when logging out

### Message Customization
- **12 Built-in Greetings** - From casual "Hi!" to friendly "Hello there!"
- **12 Built-in Farewells** - From simple "Bye!" to "Later all!"
- **14 Reconnect Messages** - From "Back!" to "Sorry, got disconnected!"
- **Custom Messages** - Add your own personalized messages per channel
- **Per-Channel Selection** - Enable different messages for different channels
- **Random Selection** - Messages are randomly picked from your enabled pool

### Additional Features
- **Player Names** - Optionally include joining player's name in greetings
- **Cooldown System** - Separate cooldowns for guild and group messages (default: 5s)
- **Message Delay** - Configurable delay before sending (default: 1s)
- **Test Mode** - Test all functionality without sending actual messages
- **Debug Mode** - Detailed logging for troubleshooting
- **Profile Support** - Save different configurations per character

## Installation

### CurseForge (Recommended)
Install via [CurseForge](https://www.curseforge.com/wow/addons/autosay) app for automatic updates.

### Manual Installation
1. Download the latest release from [GitHub Releases](https://github.com/AqueGen/AutoSay/releases)
2. Extract to `World of Warcraft/_retail_/Interface/AddOns/`
3. Restart WoW or `/reload`

## Usage

### Opening Settings
- `/autosay` or `/as` - Open the settings panel
- Or find **AutoSay** in Interface > AddOns

### Slash Commands

| Command | Description |
|---------|-------------|
| `/as` | Open settings |
| `/as toggle` | Enable/disable addon |
| `/as testmode` | Toggle test mode |
| `/as debug` | Toggle debug mode |
| `/as status` | Show current status |
| `/as help` | Show all commands |

### Test Commands (requires Test Mode)

| Command | Description |
|---------|-------------|
| `/as test party` | Simulate joining a party |
| `/as test raid` | Simulate joining a raid |
| `/as test leave` | Simulate leaving group |
| `/as test guild` | Simulate guild login greeting |
| `/as test guildbye` | Simulate guild logout farewell |
| `/as test reconnect` | Simulate reconnecting to group |
| `/as test player [name]` | Simulate player joining your group |
| `/as test reset` | Reset test state |
| `/as test status` | Show test status |

## Configuration Guide

### Party/Raid Settings
1. Open settings with `/as`
2. Select **Party** or **Raid** tab
3. Enable the channel
4. Choose triggers:
   - **On Self Join** - Greet when you join
   - **On Others Join** - Greet when others join
   - **On Reconnect** - Send reconnect message after DC
   - **Include Names** - Add player names to greetings
   - **Send Farewell** - Say goodbye when leaving
5. Select messages in **Greetings**, **Farewells**, and **Reconnects** sub-tabs

### Guild Settings
1. Select **Guild** tab
2. Enable guild messages
3. Configure:
   - **On Login** - Send greeting when you log in
   - **On Logout** - Send farewell when you log out
4. Select your preferred messages

### General Settings

- **Cooldown** - Minimum seconds between messages (default: 5s, separate for guild/group)
- **Message Delay** - Delay before sending (default: 1s)
- **Debug Mode** - Enable detailed console logging

## Built-in Messages

### Greetings (12)

| Default Enabled | Disabled by Default |
|-----------------|---------------------|
| Hi! | Wassup! |
| Hello! | Yo! |
| Hey! | Heya! |
| Greetings! | Sup? |
| | Howdy! |
| | Hiya! |
| | Yo yo! |
| | Hello there! |

### Farewells (12)

| Default Enabled | Disabled by Default |
|-----------------|---------------------|
| Bye! | See ya! |
| Goodbye! | Later! |
| GTG, bye! | Cya! |
| Take care! | Cheers! |
| Peace! | GN! |
| | BB! |
| | Later all! |

### Reconnect Messages (14)

| Default Enabled | Disabled by Default |
|-----------------|---------------------|
| Back! | Re! |
| Reconnected! | Back again! |
| I'm back! | Here we go again! |
| | Miss me? |
| | Back in the game! |
| | Sorry for DC! |
| | Sorry, got disconnected! |
| | DC, sorry about that! |
| | My bad, DC! |
| | Internet issues, back now! |
| | Lagged out, I'm back! |

## Requirements

- World of Warcraft: The War Within (11.0.2+)
- No additional addons required (libraries included)

## Dependencies (Bundled)

- Ace3 Framework (AceAddon, AceDB, AceConfig, AceConsole, AceEvent, AceTimer, AceHook, AceLocale, AceGUI)
- LibStub
- CallbackHandler

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests on [GitHub](https://github.com/AqueGen/AutoSay).

## Support

- **Issues**: [GitHub Issues](https://github.com/AqueGen/AutoSay/issues)
- **CurseForge**: [Project Page](https://www.curseforge.com/wow/addons/autosay)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

**AqueGen**

---

*Made with love for the WoW community*
