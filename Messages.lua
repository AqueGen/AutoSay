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
    { key = "slavaukraini", text = "Slava Ukraini!" },
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
    { key = "heroiamslava", text = "Heroiam Slava!" },
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
