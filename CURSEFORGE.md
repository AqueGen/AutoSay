# CurseForge Listing

Keep this file in sync with addon features. Update after each release.
CurseForge editor: switch to **Markdown** mode, then paste the Description section below.

---

## Summary

Automatically sends greetings, farewells, and reconnect messages in party, raid, and guild chat. Supports custom messages, M+ key announcements, and per-channel configuration.

---

## Description (paste into CurseForge in Markdown mode)

AutoSay takes care of the social basics so you don't have to. It automatically sends greetings when you join a group, says goodbye when you leave, and lets everyone know when you reconnect after a disconnect — all in party, raid, and guild chat.

<!-- TODO: Add 1-2 screenshots of the settings window here -->

### Chat Messages

- Sends greetings when you or others join a group
- Sends farewells when you leave, log out, or quit the game
- Sends reconnect messages after a disconnect
- Comes with a variety of built-in messages — toggle each one on or off
- Add up to 10 custom messages per channel and message type
- Messages are picked randomly from your enabled pool
- Optionally include the joining player's name in greetings

### Mythic+

- Announces your key in party chat when the group fills to 5/5 (leader only)
- Sends a completion message at the end of a dungeon — different messages for timed and depleted runs

### Smart Delivery

- Independent settings for Party, Raid, and Guild — enable or disable each channel separately
- Cooldown system prevents message spam (adjustable per channel, 0–60 seconds)
- Messages blocked by cooldown are queued and sent automatically when ready
- Multiple player names are merged into a single greeting

### Configuration

- Open settings with `/autosay` or `/as`
- Simulation mode lets you preview all triggers without sending real messages
- Per-character profiles — different setups for different characters
- Settings window remembers its size and position

### Feedback & Bugs

Found a bug or have a feature request? Open an issue on [GitHub](https://github.com/AqueGen/AutoSay/issues).
