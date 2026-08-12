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
    -- Time-of-day phrases: only picked while the local hour is in their band
    { key = "morning", text = "morning!", band = "morning" },
    { key = "goodmorningall", text = "good morning all", band = "morning" },
    { key = "morningwave", text = "morning o/", band = "morning" },
    { key = "evening", text = "evening!", band = "evening" },
    { key = "goodevening", text = "good evening", band = "evening" },
    { key = "eveningall", text = "evening all o/", band = "evening" },
    { key = "lateone", text = "hi, late one o/", band = "night" },
    { key = "laterun", text = "heya, late run", band = "night" },
    { key = "uplate", text = "up late too? hi", band = "night" },
    { key = "nightowls", text = "night owls unite o/", band = "night" },
    -- Style bundles (never enabled by default, activated by bundle or by hand)
    { key = "fun_o7", text = "o7", style = "fun" },
    { key = "fun_wildgroup", text = "a wild group appears", style = "fun" },
    { key = "fun_snacks", text = "hi, I brought snacks", style = "fun" },
    { key = "fun_plusone", text = "your +1 {role} has arrived", style = "fun" },
    { key = "fun_loot", text = "hello friends, let's loot", style = "fun" },
    { key = "fun_tankhere", text = "tank here, pull respectfully", style = "fun", role = "TANK" },
    { key = "fun_shield", text = "your shield has arrived", style = "fun", role = "TANK" },
    { key = "fun_healeronline", text = "healer online, don't stand in fire", style = "fun", role = "HEALER" },
    { key = "fun_pocketheals", text = "pocket heals reporting in", style = "fun", role = "HEALER" },
    { key = "fantasy_wellmet", text = "well met, travelers", style = "fantasy" },
    { key = "fantasy_adventurers", text = "greetings, adventurers o/", style = "fantasy" },
    { key = "fantasy_blades", text = "may your blades stay sharp", style = "fantasy" },
    { key = "fantasy_quest", text = "a fine day for a quest", style = "fantasy" },
    { key = "dark_mortals", text = "greetings, mortals", style = "dark" },
    { key = "dark_soul", text = "another soul joins the run", style = "dark" },
    { key = "dark_reinforcements", text = "the shadows sent reinforcements", style = "dark" },
    { key = "light_friends", text = "hi friends <3", style = "light" },
    { key = "light_glhf", text = "hello all, glhf", style = "light" },
    { key = "light_happy", text = "happy to be here o/", style = "light" },
    { key = "light_vibes", text = "hey team, good vibes only", style = "light" },
    { key = "pirate_ahoy", text = "ahoy crew o/", style = "pirate" },
    { key = "pirate_aboard", text = "all aboard!", style = "pirate" },
    { key = "pirate_finecrew", text = "a fine crew we have here", style = "pirate" },
    { key = "faction_loktar", text = "Lok'tar ogar!", style = "faction", faction = "Horde" },
    { key = "faction_forthehorde", text = "for the Horde o/", style = "faction", faction = "Horde" },
    { key = "faction_bloodthunder", text = "blood and thunder!", style = "faction", faction = "Horde" },
    { key = "faction_forthealliance", text = "for the Alliance o/", style = "faction", faction = "Alliance" },
    { key = "faction_wellmetheroes", text = "well met, heroes", style = "faction", faction = "Alliance" },
    { key = "faction_bythelight", text = "by the Light, hello", style = "faction", faction = "Alliance" },
    { key = "zoomer_weball", text = "yo we ball", style = "zoomer" },
    { key = "zoomer_cook", text = "lets cook team", style = "zoomer" },
    { key = "zoomer_squad", text = "squad up o/", style = "zoomer" },
    { key = "butler_goodday", text = "good day to you all", style = "butler" },
    { key = "butler_pleasure", text = "a pleasure to join you", style = "butler" },
    { key = "butler_service", text = "at your service o/", style = "butler" },
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
    -- Time-of-day phrases: only picked while the local hour is in their band
    { key = "eveningbye", text = "have a good evening", band = "evening" },
    { key = "gnall", text = "gn all", band = "night" },
    { key = "goodnightall", text = "good night everyone", band = "night" },
    { key = "sleepwell", text = "gn, sleep well", band = "night" },
    -- Style bundles (never enabled by default, activated by bundle or by hand)
    { key = "fun_hearthstone", text = "gtg, my hearthstone is calling", style = "fun" },
    { key = "fun_afkirl", text = "afk irl, bye o/", style = "fun" },
    { key = "fun_bags", text = "bye, may your bags be full", style = "fun" },
    { key = "fun_glhf", text = "gl hf without me", style = "fun" },
    { key = "fantasy_safetravels", text = "safe travels", style = "fantasy" },
    { key = "fantasy_meetagain", text = "until we meet again", style = "fantasy" },
    { key = "fantasy_wind", text = "may the wind guide you", style = "fantasy" },
    { key = "dark_shadows", text = "I return to the shadows", style = "dark" },
    { key = "dark_calls", text = "the darkness calls me home", style = "dark" },
    { key = "dark_mist", text = "fading into the mist o/", style = "dark" },
    { key = "light_takecare", text = "bye all, take care <3", style = "light" },
    { key = "light_bewell", text = "thanks for the run, be well", style = "light" },
    { key = "light_seeyou", text = "see you around, friends", style = "light" },
    { key = "pirate_fairwinds", text = "sailing off, fair winds", style = "pirate" },
    { key = "pirate_calmerseas", text = "off to calmer seas o/", style = "pirate" },
    { key = "faction_strength", text = "strength and honor, bye", style = "faction", faction = "Horde" },
    { key = "faction_axes", text = "may your axes stay sharp", style = "faction", faction = "Horde" },
    { key = "faction_lightbe", text = "Light be with you", style = "faction", faction = "Alliance" },
    { key = "faction_honorguide", text = "honor guide you, bye", style = "faction", faction = "Alliance" },
    { key = "zoomer_ggnext", text = "gg go next", style = "zoomer" },
    { key = "zoomer_dipping", text = "aight, dipping o/", style = "zoomer" },
    { key = "zoomer_beenreal", text = "it's been real", style = "zoomer" },
    { key = "butler_honour", text = "it has been an honour", style = "butler" },
    { key = "butler_takecare", text = "do take care, everyone", style = "butler" },
    { key = "butler_farewell", text = "I bid you farewell", style = "butler" },
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
    -- Style bundles (never enabled by default, activated by bundle or by hand)
    { key = "fun_router", text = "back, blame the router", style = "fun" },
    { key = "fun_lagwon", text = "the lag won round one", style = "fun" },
    { key = "fantasy_portal", text = "the portal spat me back out", style = "fantasy" },
    { key = "dark_death", text = "death could not hold me", style = "dark" },
    { key = "dark_void", text = "back from the void", style = "dark" },
    { key = "light_sorry", text = "back, sorry all!", style = "light" },
    { key = "light_waiting", text = "here again, thanks for waiting", style = "light" },
    { key = "pirate_backondeck", text = "back on deck!", style = "pirate" },
    { key = "faction_backfight", text = "back to the fight!", style = "faction" },
    { key = "zoomer_wifi", text = "back, wifi said no for a sec", style = "zoomer" },
    { key = "butler_returned", text = "my apologies, I have returned", style = "butler" },
}

-- Style bundle ids, in UI order
AutoSay.MessageStyles = {
    "fun", "fantasy", "dark", "light", "pirate", "faction", "zoomer", "butler",
}

-- Role token used by the {role} placeholder and by the config labels
AutoSay.RoleWords = {
    TANK = "tank",
    HEALER = "healer",
    DAMAGER = "dps",
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
