# AutoSay

WoW addon: automatic greetings, goodbyes, and reconnect messages for party, raid, and guild chat.

## Architecture
- **Framework**: Ace3 (AceAddon, AceEvent, AceTimer, AceHook, AceDB, AceConfig, AceGUI)
- **Slash command**: `/autosay`
- **SavedVariables**: `AutoSayDB`
- **Settings UI**: AceConfig dialog (ESC → AddOns → AutoSay)

## Key Files
- `Core.lua` — Main logic: event handling, message sending, cooldowns, queue, hooks
- `Config.lua` — AceConfig UI definition (tabs: General, Party, Raid, Guild, M+, Test)
- `Events.lua` — WoW event registration and dispatch
- `Messages.lua` — Built-in message databases (greetings, goodbyes, reconnects)
- `Locales/enUS.lua` — Localization strings

## Features
- Auto-greet on join party/raid/guild
- Auto-greet new members joining your group
- Reconnect detection and messaging
- Goodbye on leave party or logout (via hooks on C_PartyInfo.LeaveParty, Logout, Quit)
- M+ key announcements when group fills to 5/5
- Custom messages (up to 10 per channel/category)
- Per-channel settings (party, raid, guild)
- Message cooldown and batching system
- Test mode for development

## References
- **WoW UI Source / API**: `G:\Games\wow-ui-source-live`

## WoW Addon Rules

### Lua Compatibility

- WoW's Lua supports `goto`/`::label::` syntax, but `goto` **cannot jump over local variable declarations** into their scope. Use `if/else` blocks instead.

## Release Process

- `CHANGELOG.md` is a **manual changelog** used by BigWigsMods/packager for both GitHub releases and CurseForge.
- Before each release, **overwrite** `CHANGELOG.md` with the notes for the current version only (packager uses the entire file as the release body).
- Do NOT accumulate old versions in the file — only the latest release notes.
- **NEVER** delete, force-push, or recreate tags/releases. CurseForge picks up every tag push and creates duplicate entries that cannot be removed. Always bump the version and create a new tag instead.

## Testing

- Headless: `busted` from repo root (Lua 5.1). Core modules SocialGate.lua /
  Humanizer.lua are WoW-free; specs in `tests/*_spec.lua`. CI runs on push.
- On the Windows dev box busted lives in a WSL Lua 5.1 env (hererocks), so run:
  `MSYS_NO_PATHCONV=1 wsl bash -lc 'cd "/mnt/g/Games/World of Warcraft/_retail_/Interface/AddOns/AutoSay" && ~/luaenv/bin/busted'`
- In-game smoke: `/as testmode`, then `/as test`, `/as test grats`,
  `/as test guildjoin`. Gate rejections print their reason.
