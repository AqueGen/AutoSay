local ADDON_NAME, AutoSay = ...

-- Guild achievement congratulations
AutoSay.GuildGrats = {
    "gz", "grats!", "gratz {name}", "grats {name}!", "nice one {name}!", "congrats {name}!",
}

-- New guild member welcomes
AutoSay.GuildWelcome = {
    "welcome!", "welcome {name}!", "welcome to the guild, {name}!", "o/ welcome {name}",
}

-- Greetings database (enabled by default first)
AutoSay.Greetings = {
    { key = "hi", text = "Hi!" },
    { key = "hello", text = "Hello!" },
    { key = "hey", text = "Hey!" },
    { key = "greetings", text = "Greetings!" },
    -- Disabled by default
    { key = "wassup", text = "Wassup!" },
    { key = "yo", text = "Yo!" },
    { key = "heya", text = "Heya!" },
    { key = "sup", text = "Sup?" },
    { key = "howdy", text = "Howdy!" },
    { key = "hiya", text = "Hiya!" },
    { key = "yoyo", text = "Yo yo!" },
    { key = "hellothere", text = "Hello there!" },
}

-- Goodbyes database (enabled by default first)
AutoSay.Goodbyes = {
    { key = "bye", text = "Bye!" },
    { key = "goodbye", text = "Goodbye!" },
    { key = "gtg", text = "GTG, bye!" },
    { key = "takecare", text = "Take care!" },
    { key = "peace", text = "Peace!" },
    -- Disabled by default
    { key = "seeya", text = "See ya!" },
    { key = "later", text = "Later!" },
    { key = "cya", text = "Cya!" },
    { key = "cheers", text = "Cheers!" },
    { key = "gn", text = "GN!" },
    { key = "bb", text = "BB!" },
    { key = "laterall", text = "Later all!" },
}

-- Reconnect messages database (enabled by default first)
AutoSay.Reconnects = {
    { key = "back", text = "Back!" },
    { key = "reconnected", text = "Reconnected!" },
    { key = "imback", text = "I'm back!" },
    -- Disabled by default
    { key = "rehi", text = "Re!" },
    { key = "backagain", text = "Back again!" },
    { key = "herewego", text = "Here we go again!" },
    { key = "missedme", text = "Miss me?" },
    { key = "backinthegame", text = "Back in the game!" },
    { key = "srydc", text = "Sorry for DC!" },
    { key = "sorrydisconnect", text = "Sorry, got disconnected!" },
    { key = "dcsorry", text = "DC, sorry about that!" },
    { key = "mybad", text = "My bad, DC!" },
    { key = "internetissues", text = "Internet issues, back now!" },
    { key = "laggedout", text = "Lagged out, I'm back!" },
}

-- Key announce messages (M+ group full)
AutoSay.KeyAnnounce = {
    { key = "letsgo",   text = "Let's go! {dungeon} {key}" },
    { key = "ready",    text = "Ready! {dungeon} {key}" },
    { key = "gogogo",   text = "{dungeon} {key}, let's do this!" },
}

-- M+ completion messages - timed (enabled by default first)
AutoSay.CompletionTimed = {
    { key = "gg", text = "gg" },
    { key = "ggwp", text = "gg wp" },
    { key = "gjteam", text = "gj team!" },
    { key = "nicerun", text = "nice run!" },
    -- Disabled by default
    { key = "letsgo", text = "let's gooo!" },
    { key = "cleanrun", text = "clean run!" },
    { key = "greatteam", text = "great team!" },
    { key = "wpall", text = "wp all" },
    { key = "timed", text = "{dungeon} {key} timed, gg!" },
    { key = "upgraded", text = "+{upgrade} upgrade, nice!" },
}

-- Guild member login greetings (enabled by default first)
AutoSay.GuildLoginGreetings = {
    { key = "wb", text = "Welcome back, {name}!" },
    { key = "hey", text = "Hey {name}!" },
    { key = "hi", text = "Hi {name}!" },
    -- Disabled by default
    { key = "ohey", text = "o/ {name}" },
    { key = "greetings", text = "Greetings, {name}!" },
    { key = "goodtosee", text = "Good to see you, {name}!" },
    { key = "wbplain", text = "Welcome back!" },
    { key = "heythere", text = "Hey there, {name}!" },
}

-- Dungeon name lookup: mapChallengeModeID -> English name (Midnight Season 2)
-- Used to always display dungeon names in English regardless of client locale.
-- Update this table each season when the M+ pool rotates.
AutoSay.DungeonNames = {
    [588] = "Altar of Fangs",
    [399] = "Ruby Life Pools",
    [249] = "Kings' Rest",
    [585] = "Voidscar Arena",
    [586] = "Den of Nalorakk",
    [587] = "Murder Row",
    [250] = "Temple of Sethraliss",
    [584] = "The Blinding Vale",
}

-- LFG activityID -> mapChallengeModeID mapping (Midnight Season 1)
-- Used to resolve dungeon names from Group Finder listings.
AutoSay.ActivityToDungeon = {
    [1760] = 558,
    [1764] = 560,
    [1768] = 559,
    [1542] = 557,
    [1160] = 402,
    [486]  = 583,
    [182]  = 161,
    [1770] = 556,
}

-- M+ completion messages - depleted (enabled by default first)
AutoSay.CompletionDepleted = {
    { key = "gg", text = "gg" },
    { key = "ggwp", text = "gg wp" },
    { key = "tyrun", text = "ty for the run" },
    { key = "tyall", text = "ty all" },
    -- Disabled by default
    { key = "goodrun", text = "good run!" },
    { key = "ggeveryone", text = "gg everyone" },
    { key = "gjteam", text = "gj team" },
    { key = "wpall", text = "wp all" },
    { key = "done", text = "{dungeon} {key} done, gg" },
    { key = "tyfun", text = "ty all, was fun" },
}

-- Time-of-day greeting extras, mixed into the universal pool by local hour
AutoSay.GreetingsTimeOfDay = {
    morning = {
        { key = "morning", text = "morning!" },
        { key = "goodmorningall", text = "good morning all" },
        { key = "morningwave", text = "morning o/" },
    },
    evening = {
        { key = "evening", text = "evening!" },
        { key = "goodevening", text = "good evening" },
        { key = "eveningall", text = "evening all o/" },
    },
    night = {
        { key = "lateone", text = "hi, late one o/" },
        { key = "laterun", text = "heya, late run" },
        { key = "uplate", text = "up late too? hi" },
        { key = "nightowls", text = "night owls unite o/" },
    },
}
