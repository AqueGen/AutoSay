# CurseForge Listing

Keep this file in sync with addon features. Update after each release.
CurseForge editor: switch to **Markdown** mode, then paste the Description section below.
Wago takes the same Markdown in its description field.

Screenshots to keep on the listing, in this order (the first one is the header image):

1. The Style tab with a set expanded, so the counts and the Enable all / Disable all pair are visible.
2. The Group tab: the phrase list with the Party, Raid and Instance columns and a greyed column.
3. A party chat window with two or three greetings actually sent, in different styles.
4. The Mythic+ tab, or a chat line announcing a key.

---

## Summary

Automatic greetings, farewells and reconnect messages for party, raid, instance and guild chat. 460 phrases in 14 styles, phrases for your role, custom messages, Mythic+ key announcements and per-channel settings.

---

## Description (paste into CurseForge in Markdown mode)

AutoSay handles the social basics so you don't have to. It greets the group when you join, says goodbye when you leave, and tells people you are back after a disconnect. It works in party, raid, instance (LFG, LFR, battlegrounds) and guild chat, and every phrase it can say is a checkbox you own.

### New in 1.7

- **Greetings split by occasion.** What you say on arriving and what you say to whoever arrives after you are two lists now, each with its own tab, its own trigger and its own ticks.
- **Everything gets its turn.** The addon works through the whole set of phrases you enabled before any of them comes back, so a run of newcomers does not hear the same line twice.
- **Names on any phrase.** Turn names on and they go into whichever phrase comes up, into its {names} slot or onto its end, punctuated the way a person would write it.
- **A goodbye when the run ends.** Optional, off by default: say goodbye the moment a dungeon or key finishes instead of waiting for someone to press leave.
- **A session log.** `/as log on`, play, `/as log show` gives you the whole session as text you can copy into a bug report.

### New in 1.6

- **14 style bundles.** Classic, Casual, Minimal, Fun, Fantasy, Dark, Deadpan, Wholesome, Pirate, Faction, Zoomer, Butler, Robot and Naturewarden. Switch a whole set on or off in one click and read at a glance how many of its phrases are selected and how many can be sent right now.
- **Phrases for your role.** Every set has its own tank, healer and damage lines, so "I hold the line" only ever goes out when you are the one holding it. Off by default.
- **Time of day.** Morning, evening and night variants for the sets that have them. Also off by default.
- **Instance channel.** Its own settings for the groups you queue into, and it stays out of raid finder and battlegrounds unless you say otherwise.
- **Nothing sends silently.** A row that cannot go out is greyed and says which switch would bring it back.

### Chat messages

- Greets you joining, and other people joining after you
- Says goodbye when you leave the group, log out or quit
- Sends a reconnect line after a disconnect, with the greetings as a fallback
- Around 300 built-in phrases, each with its own checkbox per channel
- Up to 10 custom messages per channel and message type
- Picks at random from what you enabled, and avoids repeating itself
- Can name the people who joined, and merges several names into one line

### Mythic+

- Announces your key in party chat when the group fills to 5 out of 5, if you are the leader
- Sums up the run at the end, with separate phrases for a timed and a depleted key
- Dungeon names in English or in your client's language, your choice

### It behaves in chat

- An hourly budget, so a bad night of disconnects cannot turn into spam
- A per-person cooldown, so the same player is not greeted twice in an evening
- It listens first: if somebody already said "gz", it stays quiet
- An optional typing delay, so a line lands like something a person typed

### Settings

- `/autosay` or `/as` opens the panel
- Party, raid, instance and guild each keep their own settings
- Test mode replays every trigger without a word reaching real chat
- Profiles per character or shared across the account
- `/as selftest` checks the addon against your own settings and reports what it found

### Feedback and bugs

Found a bug or want a phrase added? Open an issue on [GitHub](https://github.com/AqueGen/AutoSay/issues).
