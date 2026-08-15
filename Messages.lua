local ADDON_NAME, AutoSay = ...

-- Preset phrase model (Greetings / Goodbyes / Reconnects)
--   key         unique id inside the pool, also the SavedVariables key of the on/off checkbox
--   text        the phrase itself; {role} is replaced on send, {names} by the joined/current players
--   style       style bundle id; see AutoSay.MessageStyles for the list. "classic" is not
--               a value here - it stands for a phrase with no style and no band.
--               Styled phrases are off by default and toggled by the bundle buttons.
--   role        only picked while the player has that assigned role (TANK/HEALER/DAMAGER)
--   faction     only picked for that faction (Horde/Alliance)
--   band        time-of-day band (morning/evening/night); only picked inside that band
--   keepCase    the phrase starts with a proper noun or an acronym ("Lok'tar", "GTG"),
--               so the "lowercase first letter" option must leave it alone
--   trigger     "self"   - only for our own join (and reconnect fallback)
--               "others" - only when someone else joins
--               absent   - fits both
--   {names}     natural name slot inside the text; such a phrase is only picked when
--               names are actually available, and never rendered with an empty hole
--   appendNames the phrase reads fine with " Name1, Name2" glued to the end.
--               Mutually exclusive with {names}. No marker at all = never carries names.

-- The channels the addon speaks on, in UI order.
--   key    profile sub-table (db.profile[key]) and style-bundle iteration key
--   chat    SendChatMessage channel type, also the key of GetChannelSettings
--   color  chat colour used by the test-mode "would send" line (matches the config tab)
AutoSay.Channels = {
    { key = "party",    chat = "PARTY",         color = "|cFFAAAAFF" },
    { key = "raid",     chat = "RAID",          color = "|cFFFF7F00" },
    { key = "instance", chat = "INSTANCE_CHAT", color = "|cFF9999FF" },
    { key = "guild",    chat = "GUILD",         color = "|cFF40FF40" },
}

-- M+ placeholders that only the M+ path can resolve - anywhere else they are stripped on send
AutoSay.MPlusTokens = { "{dungeon}", "{key}", "{upgrade}", "{time}" }

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
    { key = "hi", text = "Hi!", appendNames = true },
    { key = "hello", text = "Hello!", appendNames = true },
    { key = "hey", text = "Hey!", appendNames = true },
    { key = "greetings", text = "Greetings!", appendNames = true },
    { key = "welcome", text = "welcome!", trigger = "others", appendNames = true },
    -- Disabled by default
    { key = "yo", text = "Yo!", appendNames = true },
    { key = "sup", text = "Sup?", appendNames = true },
    { key = "howdy", text = "Howdy!", appendNames = true },
    { key = "welcomenames", text = "welcome {names}!", trigger = "others" },
    { key = "hinames", text = "hi {names} o/", trigger = "others" },
    { key = "welcomeaboard", text = "welcome aboard", trigger = "others" },
    -- Time-of-day phrases: only picked while the local hour is in their band
    { key = "morning", text = "morning!", band = "morning", appendNames = true },
    { key = "goodmorningall", text = "good morning all", band = "morning" },
    { key = "morningwave", text = "morning o/", band = "morning" },
    { key = "evening", text = "evening!", band = "evening", appendNames = true },
    { key = "goodevening", text = "good evening", band = "evening" },
    { key = "eveningall", text = "evening all o/", band = "evening" },
    { key = "lateone", text = "hi, late one o/", band = "night" },
    { key = "laterun", text = "heya, late run", band = "night" },
    { key = "uplate", text = "up late too? hi", band = "night" },
    { key = "nightowls", text = "night owls unite o/", band = "night" },
    -- Style bundles (never enabled by default, activated by bundle or by hand)
    { key = "fun_o7", text = "o7", style = "fun", appendNames = true },
    { key = "fun_wildgroup", text = "a wild group appears", style = "fun", trigger = "self" },
    { key = "fun_snacks", text = "hi, I brought snacks", style = "fun", trigger = "self" },
    { key = "fun_plusone", text = "your +1 {role} has arrived", style = "fun", trigger = "self" },
    { key = "fun_loot", text = "hello friends, let's loot", style = "fun", trigger = "self" },
    { key = "fun_tankhere", text = "tank here, pull respectfully", style = "fun", role = "TANK", trigger = "self" },
    { key = "fun_shield", text = "your shield has arrived", style = "fun", role = "TANK", trigger = "self" },
    { key = "fun_healeronline", text = "healer online, don't stand in fire", style = "fun", role = "HEALER", trigger = "self" },
    { key = "fun_pocketheals", text = "pocket heals reporting in", style = "fun", role = "HEALER", trigger = "self" },
    { key = "fun_dpsarrived", text = "dps here, numbers incoming", style = "fun", role = "DAMAGER", trigger = "self" },
    { key = "fun_pewpew", text = "pew pew department reporting in", style = "fun", role = "DAMAGER", trigger = "self" },
    { key = "fun_reinforcements", text = "reinforcements have arrived, welcome {names}", style = "fun", trigger = "others" },
    { key = "fun_freshrecruits", text = "fresh recruits, welcome o/", style = "fun", trigger = "others" },
    { key = "fantasy_wellmet", text = "well met, travelers", style = "fantasy", trigger = "self" },
    { key = "fantasy_adventurers", text = "greetings, adventurers o/", style = "fantasy" },
    { key = "fantasy_blades", text = "may your blades stay sharp", style = "fantasy" },
    { key = "fantasy_quest", text = "a fine day for a quest", style = "fantasy" },
    { key = "fantasy_wellmetnames", text = "well met, {names}", style = "fantasy", trigger = "others" },
    { key = "dark_mortals", text = "greetings, mortals", style = "dark" },
    { key = "dark_soul", text = "another soul joins the run", style = "dark", trigger = "others" },
    { key = "dark_reinforcements", text = "the shadows sent reinforcements", style = "dark", trigger = "others" },
    { key = "light_friends", text = "hi friends <3", style = "light", appendNames = true },
    { key = "light_glhf", text = "hello all, glhf", style = "light", trigger = "self" },
    { key = "light_happy", text = "happy to be here o/", style = "light", trigger = "self" },
    { key = "light_vibes", text = "hey team, good vibes only", style = "light", trigger = "self" },
    { key = "light_welcomenames", text = "welcome, {names} <3", style = "light", trigger = "others" },
    { key = "pirate_ahoy", text = "ahoy crew o/", style = "pirate" },
    { key = "pirate_aboard", text = "all aboard!", style = "pirate", trigger = "others" },
    { key = "pirate_finecrew", text = "a fine crew we have here", style = "pirate", trigger = "self" },
    { key = "pirate_aboardnames", text = "welcome aboard, {names}", style = "pirate", trigger = "others" },
    { key = "faction_loktar", text = "Lok'tar ogar!", style = "faction", faction = "Horde", keepCase = true },
    { key = "faction_forthehorde", text = "for the Horde o/", style = "faction", faction = "Horde" },
    { key = "faction_bloodthunder", text = "blood and thunder!", style = "faction", faction = "Horde" },
    { key = "faction_forthealliance", text = "for the Alliance o/", style = "faction", faction = "Alliance" },
    { key = "faction_wellmetheroes", text = "well met, heroes", style = "faction", faction = "Alliance" },
    { key = "faction_bythelight", text = "by the Light, hello", style = "faction", faction = "Alliance" },
    { key = "zoomer_weball", text = "yo we ball", style = "zoomer" },
    { key = "zoomer_cook", text = "lets lock in team", style = "zoomer", trigger = "self" },
    { key = "zoomer_squad", text = "squad up o/", style = "zoomer" },
    { key = "butler_goodday", text = "good day to you all", style = "butler" },
    { key = "butler_pleasure", text = "a pleasure to join you", style = "butler", trigger = "self" },
    { key = "butler_service", text = "at your service o/", style = "butler", trigger = "self" },
    { key = "butler_welcomenames", text = "a warm welcome, {names}", style = "butler", trigger = "others" },
    { key = "classic_tank1", text = "tank here o/", role = "TANK", trigger = "self" },
    { key = "classic_tank2", text = "tanking today", role = "TANK", trigger = "self" },
    { key = "classic_heal1", text = "healer here o/", role = "HEALER", trigger = "self" },
    { key = "classic_heal2", text = "heals incoming", role = "HEALER", trigger = "self" },
    { key = "classic_dps1", text = "dps here o/", role = "DAMAGER", trigger = "self" },
    { key = "classic_dps2", text = "damage on the way", role = "DAMAGER", trigger = "self" },
    { key = "fantasy_tank1", text = "I shall hold the line", style = "fantasy", role = "TANK", trigger = "self", keepCase = true },
    { key = "fantasy_tank2", text = "the shield of this company stands ready", style = "fantasy", role = "TANK", trigger = "self" },
    { key = "fantasy_heal1", text = "the Light mends, call for me", style = "fantasy", role = "HEALER", trigger = "self" },
    { key = "fantasy_heal2", text = "your wounds are my charge", style = "fantasy", role = "HEALER", trigger = "self" },
    { key = "fantasy_dps1", text = "my blade answers the call", style = "fantasy", role = "DAMAGER", trigger = "self" },
    { key = "fantasy_dps2", text = "steel and fury, at your service", style = "fantasy", role = "DAMAGER", trigger = "self" },
    { key = "dark_tank1", text = "let them break upon me", style = "dark", role = "TANK", trigger = "self" },
    { key = "dark_tank2", text = "I am the wall before the end", style = "dark", role = "TANK", trigger = "self", keepCase = true },
    { key = "dark_heal1", text = "death can wait, I am here", style = "dark", role = "HEALER", trigger = "self", keepCase = true },
    { key = "dark_heal2", text = "your fate rests in my hands", style = "dark", role = "HEALER", trigger = "self" },
    { key = "dark_dps1", text = "I bring the ending", style = "dark", role = "DAMAGER", trigger = "self", keepCase = true },
    { key = "dark_dps2", text = "the reaping starts now", style = "dark", role = "DAMAGER", trigger = "self" },
    { key = "light_tank1", text = "tank here, I've got you all", style = "light", role = "TANK", trigger = "self" },
    { key = "light_tank2", text = "I'll keep everyone safe o/", style = "light", role = "TANK", trigger = "self", keepCase = true },
    { key = "light_heal1", text = "healer here, I'll patch you up", style = "light", role = "HEALER", trigger = "self" },
    { key = "light_heal2", text = "nobody dies on my watch <3", style = "light", role = "HEALER", trigger = "self" },
    { key = "light_dps1", text = "dps here, happy to help o/", style = "light", role = "DAMAGER", trigger = "self" },
    { key = "light_dps2", text = "I'll do my best out there", style = "light", role = "DAMAGER", trigger = "self", keepCase = true },
    { key = "pirate_tank1", text = "I be the hull, hide behind me", style = "pirate", role = "TANK", trigger = "self", keepCase = true },
    { key = "pirate_tank2", text = "the figurehead has arrived", style = "pirate", role = "TANK", trigger = "self" },
    { key = "pirate_heal1", text = "the ship's surgeon reports in", style = "pirate", role = "HEALER", trigger = "self" },
    { key = "pirate_heal2", text = "I patch the crew, mind the fire", style = "pirate", role = "HEALER", trigger = "self", keepCase = true },
    { key = "pirate_dps1", text = "cannons ready o/", style = "pirate", role = "DAMAGER", trigger = "self" },
    { key = "pirate_dps2", text = "the cannons are loaded", style = "pirate", role = "DAMAGER", trigger = "self", keepCase = true },
    { key = "faction_tank1", text = "front line, on me", style = "faction", role = "TANK", trigger = "self" },
    { key = "faction_tank2", text = "I hold the vanguard", style = "faction", role = "TANK", trigger = "self", keepCase = true },
    { key = "faction_heal1", text = "field medic reporting", style = "faction", role = "HEALER", trigger = "self" },
    { key = "faction_heal2", text = "the wounded live today", style = "faction", role = "HEALER", trigger = "self" },
    { key = "faction_dps1", text = "weapons hot", style = "faction", role = "DAMAGER", trigger = "self" },
    { key = "faction_dps2", text = "for the charge o/", style = "faction", role = "DAMAGER", trigger = "self" },
    { key = "zoomer_tank1", text = "tank here, im him", style = "zoomer", role = "TANK", trigger = "self" },
    { key = "zoomer_tank2", text = "no cap i hold everything", style = "zoomer", role = "TANK", trigger = "self" },
    { key = "zoomer_heal1", text = "healer here, ill keep u alive fr", style = "zoomer", role = "HEALER", trigger = "self" },
    { key = "zoomer_heal2", text = "heals on deck", style = "zoomer", role = "HEALER", trigger = "self" },
    { key = "zoomer_dps1", text = "dps here, watch this", style = "zoomer", role = "DAMAGER", trigger = "self" },
    { key = "zoomer_dps2", text = "locked in today", style = "zoomer", role = "DAMAGER", trigger = "self" },
    { key = "butler_tank1", text = "I shall stand between you and harm", style = "butler", role = "TANK", trigger = "self", keepCase = true },
    { key = "butler_tank2", text = "your protection is my duty", style = "butler", role = "TANK", trigger = "self" },
    { key = "butler_heal1", text = "I shall attend to your wounds", style = "butler", role = "HEALER", trigger = "self", keepCase = true },
    { key = "butler_heal2", text = "your health is in my care", style = "butler", role = "HEALER", trigger = "self" },
    { key = "butler_dps1", text = "I shall dispatch them, discreetly", style = "butler", role = "DAMAGER", trigger = "self", keepCase = true },
    { key = "butler_dps2", text = "the unpleasantness is mine to handle", style = "butler", role = "DAMAGER", trigger = "self" },
    { key = "minimal_tank1", text = "tank", style = "minimal", role = "TANK", trigger = "self" },
    { key = "minimal_tank2", text = "tank o/", style = "minimal", role = "TANK", trigger = "self" },
    { key = "minimal_heal1", text = "heals", style = "minimal", role = "HEALER", trigger = "self" },
    { key = "minimal_heal2", text = "heals o/", style = "minimal", role = "HEALER", trigger = "self" },
    { key = "minimal_dps1", text = "dps", style = "minimal", role = "DAMAGER", trigger = "self" },
    { key = "minimal_dps2", text = "dps o/", style = "minimal", role = "DAMAGER", trigger = "self" },
    { key = "robot_tank1", text = "damage absorption unit online", style = "robot", role = "TANK", trigger = "self" },
    { key = "robot_tank2", text = "armor plating at full integrity", style = "robot", role = "TANK", trigger = "self" },
    { key = "robot_heal1", text = "repair systems online", style = "robot", role = "HEALER", trigger = "self" },
    { key = "robot_heal2", text = "restoration protocol standing by", style = "robot", role = "HEALER", trigger = "self" },
    { key = "robot_dps1", text = "weapon systems online", style = "robot", role = "DAMAGER", trigger = "self" },
    { key = "robot_dps2", text = "target acquisition ready", style = "robot", role = "DAMAGER", trigger = "self" },
    { key = "deadpan_tank1", text = "tank. I'll stand in front, as usual.", style = "deadpan", role = "TANK", trigger = "self" },
    { key = "deadpan_tank2", text = "yes, I'll pull", style = "deadpan", role = "TANK", trigger = "self" },
    { key = "deadpan_heal1", text = "healer. I will be over here, healing.", style = "deadpan", role = "HEALER", trigger = "self" },
    { key = "deadpan_heal2", text = "healer. the bars go up, eventually.", style = "deadpan", role = "HEALER", trigger = "self", keepCase = true },
    { key = "deadpan_dps1", text = "dps. I press buttons.", style = "deadpan", role = "DAMAGER", trigger = "self" },
    { key = "deadpan_dps2", text = "I'll do damage. allegedly.", style = "deadpan", role = "DAMAGER", trigger = "self", keepCase = true },
    { key = "minimal_hi", text = "hi", style = "minimal", appendNames = true },
    { key = "minimal_wave", text = "o/", style = "minimal", appendNames = true },
    { key = "minimal_sup", text = "sup", style = "minimal" },
    { key = "minimal_names", text = "o/ {names}", style = "minimal", trigger = "others" },
    { key = "robot_greetings", text = "greetings, unit", style = "robot" },
    { key = "robot_protocol", text = "party protocol initiated", style = "robot", trigger = "self" },
    { key = "robot_parameters", text = "functioning within parameters", style = "robot", trigger = "self" },
    { key = "robot_detected", text = "new unit detected, welcome", style = "robot", trigger = "others" },
    { key = "deadpan_hi", text = "hi.", style = "deadpan", appendNames = true },
    { key = "deadpan_another", text = "another one", style = "deadpan", trigger = "self" },
    { key = "deadpan_herewego", text = "here we go then", style = "deadpan", trigger = "self" },
    { key = "deadpan_someone", text = "someone new. hello.", style = "deadpan", trigger = "others" },
    { key = "nature_paths", text = "our paths cross well today", style = "naturewarden" },
    { key = "nature_wind", text = "the wind is with us o/", style = "naturewarden" },
    { key = "nature_grove", text = "greetings from the grove", style = "naturewarden", trigger = "self" },
    { key = "nature_welcomenames", text = "the wilds welcome you, {names}", style = "naturewarden", trigger = "others" },
    { key = "nature_tank1", text = "I stand where the storm hits first", style = "naturewarden", role = "TANK", trigger = "self", keepCase = true },
    { key = "nature_tank2", text = "roots hold, and so do I", style = "naturewarden", role = "TANK", trigger = "self" },
    { key = "nature_heal1", text = "the healing winds are with us", style = "naturewarden", role = "HEALER", trigger = "self" },
    { key = "nature_heal2", text = "I tend the wounded, call out early", style = "naturewarden", role = "HEALER", trigger = "self", keepCase = true },
    { key = "nature_dps1", text = "the hunt begins o/", style = "naturewarden", role = "DAMAGER", trigger = "self" },
    { key = "nature_dps2", text = "swift and steady, that is the way", style = "naturewarden", role = "DAMAGER", trigger = "self" },
    { key = "fantasy_skies", text = "well met, may the skies favor our path", style = "fantasy" },
    { key = "fantasy_ancient", text = "the old paths brought us together", style = "fantasy", trigger = "self" },
    { key = "fantasy_scale", text = "I hold the line, steady as dragon scales", style = "fantasy", role = "TANK", trigger = "self", keepCase = true },
}

-- Goodbyes database (enabled by default first)
AutoSay.Goodbyes = {
    { key = "bye", text = "Bye!" },
    { key = "goodbye", text = "Goodbye!" },
    { key = "gtg", text = "GTG, bye!", keepCase = true },
    { key = "gn", text = "GN!", keepCase = true },
    { key = "takecare", text = "Take care!" },
    { key = "peace", text = "Peace!" },
    -- Disabled by default
    { key = "later", text = "Later!" },
    { key = "cya", text = "Cya!" },
    { key = "cheers", text = "Cheers!" },
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
    { key = "dark_shadows", text = "I return to the shadows", style = "dark", keepCase = true },
    { key = "dark_calls", text = "the darkness calls me home", style = "dark" },
    { key = "dark_mist", text = "fading into the mist o/", style = "dark" },
    { key = "light_takecare", text = "bye all, take care <3", style = "light" },
    { key = "light_bewell", text = "thanks for the run, be well", style = "light" },
    { key = "light_seeyou", text = "see you around, friends", style = "light" },
    { key = "pirate_fairwinds", text = "sailing off, fair winds", style = "pirate" },
    { key = "pirate_calmerseas", text = "off to calmer seas o/", style = "pirate" },
    { key = "faction_strength", text = "strength and honor, bye", style = "faction", faction = "Horde" },
    { key = "faction_axes", text = "may your axes stay sharp", style = "faction", faction = "Horde" },
    { key = "faction_lightbe", text = "Light be with you", style = "faction", faction = "Alliance", keepCase = true },
    { key = "faction_honorguide", text = "honor guide you, bye", style = "faction", faction = "Alliance" },
    { key = "zoomer_ggnext", text = "gg go next", style = "zoomer" },
    { key = "zoomer_dipping", text = "aight, dipping o/", style = "zoomer" },
    { key = "zoomer_beenreal", text = "it's been real", style = "zoomer" },
    { key = "butler_honour", text = "it has been an honour", style = "butler" },
    { key = "butler_takecare", text = "do take care, everyone", style = "butler" },
    { key = "butler_farewell", text = "I bid you farewell", style = "butler", keepCase = true },
    { key = "minimal_bye", text = "bye", style = "minimal" },
    { key = "minimal_wave", text = "o/", style = "minimal" },
    { key = "minimal_gg", text = "gg", style = "minimal" },
    { key = "robot_disconnecting", text = "disconnecting from party", style = "robot" },
    { key = "robot_shutdown", text = "shutdown sequence initiated", style = "robot" },
    { key = "robot_farewell", text = "farewell, units", style = "robot" },
    { key = "deadpan_thatsthat", text = "and that's that", style = "deadpan" },
    { key = "deadpan_itwasfine", text = "leaving. that worked.", style = "deadpan" },
    { key = "deadpan_iguess", text = "bye I guess", style = "deadpan", keepCase = true },
    { key = "nature_road", text = "may the road be gentle", style = "naturewarden" },
    { key = "nature_seasons", text = "good hunting, until the seasons turn", style = "naturewarden" },
    { key = "nature_still", text = "safe travels, keep to the still paths", style = "naturewarden" },
    { key = "fantasy_flytrue", text = "fly true, friends, until our paths cross again", style = "fantasy" },
}

-- Reconnect messages database (enabled by default first)
AutoSay.Reconnects = {
    { key = "back", text = "Back!" },
    { key = "reconnected", text = "Reconnected!" },
    { key = "imback", text = "I'm back!", keepCase = true },
    -- Disabled by default
    { key = "rehi", text = "Re!" },
    { key = "backagain", text = "Back again!" },
    { key = "herewego", text = "Here we go again!" },
    { key = "backinthegame", text = "Back in the game!" },
    { key = "sorrydisconnect", text = "Sorry, got disconnected!" },
    { key = "mybad", text = "My bad, DC!" },
    { key = "internetissues", text = "Internet issues, back now!" },
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
    { key = "minimal_back", text = "back", style = "minimal" },
    { key = "minimal_re", text = "re", style = "minimal" },
    { key = "robot_restored", text = "connection restored", style = "robot" },
    { key = "robot_online", text = "systems back online", style = "robot" },
    { key = "deadpan_apparently", text = "internet exists, apparently", style = "deadpan" },
    { key = "deadpan_thrilling", text = "back. thrilling.", style = "deadpan" },
    { key = "nature_roots", text = "the roots led me back", style = "naturewarden" },
    { key = "nature_storm", text = "the storm passed, I am back", style = "naturewarden", keepCase = true },
    { key = "fantasy_horizon", text = "back from beyond the horizon", style = "fantasy" },
}

-- Style bundle ids, in UI order
-- "classic" is not a style tag on any phrase: it stands for the untagged pool, so the
-- stock phrases can be switched on and off as fast as a style bundle (see StyleMatches)
AutoSay.MessageStyles = {
    "classic", "minimal", "fun", "fantasy", "dark", "deadpan", "light", "pirate", "faction",
    "zoomer", "butler", "robot", "naturewarden",
}

-- Style bundles that lean towards particular classes. Advisory only - every bundle works
-- for every class, and a bundle missing here shows no class hint rather than an empty one.
-- Kept sparse on purpose: a hint for every plausible pairing would stop meaning anything,
-- and "light" is wholesome rather than Holy Light, so it earns no class of its own.
AutoSay.StyleClasses = {
    fantasy = { "WARRIOR", "PALADIN", "PRIEST", "MAGE", "MONK", "EVOKER" },
    dark = { "DEATHKNIGHT", "WARLOCK", "DEMONHUNTER" },
    pirate = { "ROGUE", "HUNTER" },
    naturewarden = { "DRUID", "SHAMAN", "HUNTER" },
}

-- Every phrase pool a style bundle can toggle, in UI order. One inventory, three consumers:
-- the bundle apply/state logic, the tag bulk buttons, and the bundle tooltip in Config.
--   messages    name of the AutoSay.<name> phrase table
--   enabledKey  settings key of that pool's per-phrase checkbox table
--   mplus       the pool lives once under db.profile.mythicplus instead of per channel
--   header      tooltip section title; pools sharing one are listed under a single header
AutoSay.StylePools = {
    { messages = "Greetings",          enabledKey = "enabledGreetings",          header = "Greetings" },
    { messages = "Goodbyes",           enabledKey = "enabledGoodbyes",           header = "Goodbyes" },
    { messages = "Reconnects",         enabledKey = "enabledReconnects",         header = "Reconnects" },
    { messages = "KeyAnnounce",        enabledKey = "enabledKeyAnnounce",        header = "Key announce", mplus = true },
    { messages = "CompletionTimed",    enabledKey = "enabledCompletionTimed",    header = "Completion",   mplus = true },
    { messages = "CompletionDepleted", enabledKey = "enabledCompletionDepleted", header = "Completion",   mplus = true },
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
    -- Style bundles (never enabled by default, activated by bundle or by hand)
    { key = "fun_express", text = "the {dungeon} express departs, {key}", style = "fun" },
    { key = "fantasy_gates", text = "the gates of {dungeon} await, {key}", style = "fantasy" },
    { key = "dark_ready", text = "{dungeon} {key}, the shadows are ready", style = "dark" },
    { key = "light_goodluck", text = "{dungeon} {key}, good luck everyone <3", style = "light" },
    { key = "pirate_sail", text = "setting sail for {dungeon} {key}", style = "pirate" },
    { key = "zoomer_cook", text = "{dungeon} {key} lets lock in", style = "zoomer" },
    { key = "butler_carriage", text = "your carriage to {dungeon} {key} is ready", style = "butler" },
    { key = "minimal_key", text = "{dungeon} {key}", style = "minimal" },
    { key = "robot_objective", text = "objective loaded: {dungeon} {key}", style = "robot" },
    { key = "deadpan_sure", text = "{dungeon} {key}. sure.", style = "deadpan" },
    { key = "nature_trail", text = "the trail leads to {dungeon} {key}", style = "naturewarden" },
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
    -- Style bundles (never enabled by default, activated by bundle or by hand)
    { key = "fun_router", text = "gg, the router held up", style = "fun" },
    { key = "fantasy_victory", text = "victory, well fought", style = "fantasy" },
    { key = "dark_pleased", text = "the void is pleased, gg", style = "dark" },
    { key = "light_lovely", text = "gg all, lovely run <3", style = "light" },
    { key = "pirate_plunder", text = "fine plunder, crew", style = "pirate" },
    { key = "zoomer_ez", text = "gg, we were locked in", style = "zoomer" },
    { key = "butler_splendid", text = "splendidly done, everyone", style = "butler" },
    { key = "minimal_wellrun", text = "clean", style = "minimal" },
    { key = "robot_nominal", text = "objective complete, efficiency nominal", style = "robot" },
    { key = "deadpan_incredible", text = "we did it. incredible.", style = "deadpan" },
    { key = "nature_wellwalked", text = "well walked, everyone", style = "naturewarden" },
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

-- LFG activityID -> mapChallengeModeID mapping. Used to resolve dungeon names from Group
-- Finder listings. Empty until the Season 2 activity ids exist: regenerate with
-- /as dumpdungeons (enUS client) once the season is live. The announce degrades gracefully
-- without it (listing's own name + the owned-keystone identity check), whereas last season's
-- ids would resolve to map ids the Season 2 DungeonNames table cannot name.
AutoSay.ActivityToDungeon = {
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
    -- Style bundles (never enabled by default, activated by bundle or by hand)
    { key = "fun_blamelag", text = "gg, we blame the lag", style = "fun" },
    { key = "fantasy_noble", text = "a noble effort, friends", style = "fantasy" },
    { key = "dark_claims", text = "the dungeon claims this one, gg", style = "dark" },
    { key = "light_nextone", text = "good try all, next one is ours", style = "light" },
    { key = "pirate_roughseas", text = "rough seas, gg crew", style = "pirate" },
    { key = "zoomer_gonext", text = "gg go next", style = "zoomer" },
    { key = "butler_valiant", text = "a valiant attempt, thank you all", style = "butler" },
    { key = "minimal_rough", text = "rough one", style = "minimal" },
    { key = "robot_recalibrating", text = "objective failed, recalibrating", style = "robot" },
    { key = "deadpan_asexpected", text = "not clean, but done", style = "deadpan" },
    { key = "nature_longpath", text = "a long path, but we walked it", style = "naturewarden" },
}
