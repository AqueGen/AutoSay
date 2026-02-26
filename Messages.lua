local ADDON_NAME, AutoSay = ...

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
