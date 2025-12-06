# AutoSay

[![CurseForge](https://img.shields.io/badge/CurseForge-AutoSay-orange)](https://www.curseforge.com/wow/addons/autosay)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![WoW Version](https://img.shields.io/badge/WoW-11.2.7-brightgreen)](https://worldofwarcraft.com)

A World of Warcraft addon that automatically sends greetings and farewells in party, raid, and guild chat. Never forget to say hello or goodbye again!

## Features

### Per-Channel Configuration
Configure each channel independently with its own settings:
- **Party Chat** - Greet your dungeon groups automatically
- **Raid Chat** - Welcome your raid members
- **Guild Chat** - Send greetings on login and farewells on logout

### Smart Triggers
Choose when messages are sent:
- **On Self Join** - When you join a group/raid or log in (guild)
- **On Others Join** - When other players join your group (party/raid only)
- **On Leave** - Send farewells when leaving groups
- **On Logout** - Send guild farewell when logging out

### Message Customization
- **24 Built-in Greetings** - From casual "Hi!" to international "Konnichiwa!"
- **20 Built-in Farewells** - From simple "Bye!" to multilingual "Sayonara!"
- **Custom Messages** - Add your own personalized greetings and farewells
- **Per-Channel Selection** - Enable different messages for different channels
- **Random Selection** - Messages are randomly picked from your enabled pool

### Additional Features
- **Player Names** - Optionally include joining player's name in greetings
- **Cooldown System** - Prevent spam with configurable cooldown timer
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
   - **Include Names** - Add player names to greetings
   - **Send Farewell** - Say goodbye when leaving
5. Select messages in **Greetings** and **Farewells** sub-tabs

### Guild Settings
1. Select **Guild** tab
2. Enable guild messages
3. Configure:
   - **On Login** - Send greeting when you log in
   - **On Logout** - Send farewell when you log out
4. Select your preferred messages

### General Settings
- **Cooldown** - Minimum seconds between messages (default: 5)
- **Message Delay** - Delay before sending (default: 2 seconds)
- **Debug Mode** - Enable detailed console logging

## Built-in Messages

### Greetings
| English | International |
|---------|---------------|
| Hi!, Hello!, Hey! | Hola!, Ciao!, Bonjour! |
| Yo!, Heya!, Sup? | Konnichiwa!, Ni hao! |
| Howdy!, Hiya! | Annyeonghaseyo!, Merhaba! |
| Greetings!, Wassup! | Aloha!, Shalom!, Namaste! |

### Farewells
| English | International |
|---------|---------------|
| Bye!, Goodbye!, See ya! | Adios!, Ciao!, Au revoir! |
| Later!, Cya!, Take care! | Sayonara!, Zai jian! |
| Peace!, Cheers!, GN! | Annyeong!, Tschuss! |
| BB!, GTG bye!, Later all! | Do svidaniya! |

## Requirements

- World of Warcraft: The War Within (11.2.7+)
- No additional addons required (libraries included)

## Dependencies (Bundled)

- Ace3 Framework (AceAddon, AceDB, AceConfig, AceConsole, AceEvent, AceTimer, AceLocale, AceGUI)
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
