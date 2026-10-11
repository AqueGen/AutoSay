# AutoSay

[![CurseForge](https://img.shields.io/badge/CurseForge-AutoSay-orange)](https://www.curseforge.com/wow/addons/autosay)
[![Wago Addons](https://img.shields.io/badge/Wago-AutoSay-teal)](https://addons.wago.io/addons/rN4kvMGD)
[![License](https://img.shields.io/badge/License-All%20rights%20reserved-lightgrey.svg)](LICENSE)
[![WoW Version](https://img.shields.io/badge/WoW-12.0.1+-brightgreen)](https://worldofwarcraft.com)

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
- **Ask Before Sending** - Optional: every message waits in a small panel with Send and Another; leave and logout goodbyes stay silent in this mode
- **Test Mode** - Test all functionality without sending actual messages
- **Debug Mode** - Detailed logging for troubleshooting
- **Profile Support** - Save different configurations per character

## Installation

Install via your preferred addon manager:

- [CurseForge](https://www.curseforge.com/wow/addons/autosay)
- [Wago Addons](https://addons.wago.io/addons/rN4kvMGD)
- [GitHub Releases](https://github.com/AqueGen/AutoSay/releases)

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

Open settings with `/as`. The pages are listed on the left of the window. Each phrase list shows only the selected phrases at first; press **All phrases** to see and tick the rest, **Selected only** to go back.

### Quick setup
- **Channels** - Turn Party, Raid, Instance, Guild and Mythic+ on or off, and skip LFR and battlegrounds
- **Style** - Pick a main style and mix in other styles
- **Ask before sending** - Every message waits in a small panel first, with its own timeout
- Minimap icon, Simulation switch, window size reset and Reset to Defaults

### Group
Party, raid and instance share one phrase list with a checkbox column per channel.
- **When I join** - **On self join**, and **Name the group when I join** to add the group's names
- **When someone joins** - **On others join**, **Only if leader**, and **Name whoever joined**
- **Goodbyes** - **Send goodbye on leave** and **Send goodbye when the run ends**
- **Reconnects** - **On reconnect**, sent after a disconnect

### Guild
Shown while the Guild channel is on.
- **Greetings** - **On login**, sent when you log in
- **Goodbyes** - **On logout**, sent when you log out

### Mythic+
Shown while the Mythic+ channel is on. Messages go to party chat.
- **Group ready** - Announce your key when the group is full or when the key starts, optionally with the key level
- **Timed run** - Send a message when the key is timed
- **Depleted run** - Send a message when the timer is missed

### Style
Style bundles turn a whole set of phrases on or off across every channel. Role-based and time-of-day phrases have their own switches here, and **Lowercase first letter** sets the tone.

### Behaviour
- **Timing** - Message delay, cooldown and human typing delay
- **Limits** - Hourly message budget, per-person cooldown and social listening
- Congratulate guild achievements and welcome new guild members

### Simulation
Shown while Simulation is on (Quick setup or `/as testmode`). Buttons fake joins, leaves, reconnects, guild logins and Mythic+ runs without sending anything, and the Debug section holds the debug log and the session log.

### Profiles
Save different configurations and pick one per character.

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

- World of Warcraft: Midnight (12.0.1+)
- No additional addons required (libraries included)

## Dependencies (Bundled)

- Ace3 Framework (AceAddon, AceDB, AceConfig, AceConsole, AceEvent, AceTimer, AceHook, AceLocale, AceGUI)
- LibStub
- CallbackHandler

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests on [GitHub](https://github.com/AqueGen/AutoSay).

## Support

- **Issues**: [GitHub Issues](https://github.com/AqueGen/AutoSay/issues)

## License

All rights reserved - see [LICENSE](LICENSE). You may use the addon; you may not reuse its code or data.

## Author

**AqueGen**

---

*Made with love for the WoW community*
