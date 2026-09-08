# AutoSay

WoW addon: automatic greetings, goodbyes, and reconnect messages for party, raid, and guild chat.

## Architecture
- **Framework**: Ace3 (AceAddon, AceEvent, AceTimer, AceHook, AceDB, AceConfig, AceGUI)
- **Slash command**: `/autosay`
- **SavedVariables**: `AutoSayDB`
- **Settings UI**: AceConfig dialog (ESC → AddOns → AutoSay)

## Key Files
- `Core.lua` — Main logic: event handling, message sending, cooldowns, queue, hooks
- `Config.lua` — AceConfig UI definition (tabs: General, Style, Social, Group, Guild, M+, Test). The Group tab covers party/raid/instance with one shared phrase list and a checkbox column per channel; the db layout stays per channel (`db.profile.party/raid/instance`)
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

## UI Conventions

- The Blizzard AddOns tab holds a **button that opens the standalone window**, not the option tree. Two AceConfig tables exist for this: `AutoSay` is the real tree, `AutoSay-Blizzard` is the stub that `AddToBlizOptions` gets. Registering the real tree in both places squeezes every phrase matrix into a panel too narrow for it.

## WoW Addon Rules

### Lua Compatibility

- WoW's Lua supports `goto`/`::label::` syntax, but `goto` **cannot jump over local variable declarations** into their scope. Use `if/else` blocks instead.

## Release Process

Releases are driven by [release-please](https://github.com/googleapis/release-please) from **Conventional Commits**. Nothing is versioned by hand.

- Write commits as `feat: ...` (minor), `fix: ...` (patch), `feat!: ...` or a `BREAKING CHANGE:` footer (major). Anything else (`chore:`, `docs:`, `ci:`, `refactor:`) does not trigger a release on its own.
- On every push to `main`, `release-please.yml` opens or updates a **release PR** that bumps `## Version:` / `## X-Curse-Version:` in `AutoSay.toc`, updates `CHANGELOG.md`, and updates `.release-please-manifest.json`.
- **Merging that PR** publishes everything: the `v<semver>` tag, the GitHub release, and the CurseForge/Wago upload.
- Packaging does not run inside the release-please job. A tag pushed with the default `GITHUB_TOKEN` does **not** start a tag workflow, and packaging on the branch push fails too: the packager reads the real `GITHUB_REF` (`refs/heads/main`) and skips with `Found future tag` (a step-level `env:` cannot override a reserved `GITHUB_*` variable). Instead the `package` job dispatches `release.yml` on the new tag - `workflow_dispatch` is the one event `GITHUB_TOKEN` may still start - so the packager runs with a real tag ref. `release.yml` stays `workflow_dispatch` only and doubles as the entry point for manual alpha/beta builds.
- `CHANGELOG.md` is **generated and accumulating** — release-please owns it. Do NOT hand-edit it and do NOT overwrite it with a single release's notes. The packager gets only the newest section, via `RELEASE_NOTES.md`, which CI extracts from `CHANGELOG.md` before packaging (it is gitignored and excluded from the zip).
- The TOC version is written by release-please as **bare semver** (`1.5.0`); tags keep the `v` prefix (`v1.5.0`). Do not add a `v` back into the TOC.
- Never edit the version lines in `AutoSay.toc` by hand — they sit inside `# x-release-please-start-version` / `# x-release-please-end` markers.
- **NEVER** delete, force-push, or recreate tags/releases. CurseForge picks up every tag push and creates duplicate entries that cannot be removed. Always let a new release PR produce the next version instead.
- `version-check.yml` is now only a safety net (it tolerates a leading `v` on either side); release-please keeps the TOC and the tag in sync by construction.

## Testing

- Headless: `busted` from repo root (Lua 5.1). Core modules SocialGate.lua /
  Humanizer.lua are WoW-free; specs in `tests/*_spec.lua`. CI runs on push.
- On the Windows dev box busted lives in a WSL Lua 5.1 env (hererocks), so run:
  `MSYS_NO_PATHCONV=1 wsl bash -lc 'cd "/mnt/g/Games/World of Warcraft/_retail_/Interface/AddOns/AutoSay" && ~/luaenv/bin/busted'`
- In-game smoke: `/as testmode`, then `/as test`, `/as test grats`,
  `/as test guildjoin`. Gate rejections print their reason.
- In-game regression pass: `/as selftest`. Besides the gate and humanizer wiring it
  checks the phrase data (styles, role coverage, class hints, locale names), the LFR
  gate through `IsChannelSilenced`, and the profile migrations - those run on a scratch
  profile it creates and deletes again, so the player's own profile is not touched.
  What it cannot check is layout: colours, greyed rows and widths still need eyes.
