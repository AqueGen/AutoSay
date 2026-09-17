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
    { key = "fun_healeronline", text = "healer online, bandages not included", style = "fun", role = "HEALER", trigger = "self" },
    { key = "fun_pocketheals", text = "pocket heals reporting in", style = "fun", role = "HEALER", trigger = "self" },
    { key = "fun_dpsarrived", text = "dps here, numbers incoming", style = "fun", role = "DAMAGER", trigger = "self" },
    { key = "fun_pewpew", text = "pew pew department reporting in", style = "fun", role = "DAMAGER", trigger = "self" },
    { key = "fun_reinforcements", text = "reinforcements have arrived, welcome {names}", style = "fun", trigger = "others" },
    { key = "fun_freshrecruits", text = "fresh recruits, welcome o/", style = "fun", trigger = "others" },
    { key = "fun_tank3", text = "walls up, send them my way", style = "fun", role = "TANK", trigger = "self" },
    { key = "fun_heal3", text = "health bars are my hobby", style = "fun", role = "HEALER", trigger = "self" },
    { key = "fun_dps3", text = "bringing the boom, responsibly", style = "fun", role = "DAMAGER", trigger = "self" },
    { key = "fun_hinames", text = "hey {names}, bonus chaos reporting in", style = "fun", trigger = "self" },
    { key = "fun_joinnames", text = "{names} joined the fun", style = "fun", trigger = "others" },
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
    { key = "light_vibes", text = "hey team, happy to join you", style = "light", trigger = "self" },
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
    -- Casual is the register most pug chat is actually written in: lower case, the standard
    -- abbreviations, nothing performed. Classic greets with a capital and an exclamation
    -- mark, minimal answers in one word, and between them there was nothing. Two rules hold
    -- the bundle together - no idiom a non-native speaker has to decode, and no joke
    { key = "casual_heyall", text = "hey all o/", style = "casual" },
    { key = "casual_glhf", text = "hi all, gl hf", style = "casual" },
    { key = "casual_hey", text = "hey o/", style = "casual" },
    { key = "casual_ready", text = "hi, ready when you are", style = "casual", trigger = "self" },
    { key = "casual_tank1", text = "tank here, gl hf", style = "casual", role = "TANK", trigger = "self" },
    { key = "casual_tank2", text = "tank here, ready when you are", style = "casual", role = "TANK", trigger = "self" },
    { key = "casual_tank3", text = "tank o/ shout if I pull too fast", style = "casual", role = "TANK", trigger = "self" },
    { key = "casual_heal1", text = "heals here o/", style = "casual", role = "HEALER", trigger = "self" },
    { key = "casual_heal2", text = "healer here, gl hf", style = "casual", role = "HEALER", trigger = "self" },
    { key = "casual_heal3", text = "heals up, shout if you need", style = "casual", role = "HEALER", trigger = "self" },
    { key = "casual_dps1", text = "dps here, gl", style = "casual", role = "DAMAGER", trigger = "self" },
    { key = "casual_dps2", text = "dps here, gl hf", style = "casual", role = "DAMAGER", trigger = "self" },
    { key = "casual_dps3", text = "dps ready when you are", style = "casual", role = "DAMAGER", trigger = "self" },
    { key = "casual_names1", text = "hey {names} o/", style = "casual", trigger = "self" },
    { key = "casual_names2", text = "welcome {names}, gl hf", style = "casual", trigger = "others" },
    { key = "casual_names3", text = "hi {names}, gl hf", style = "casual", trigger = "others" },
    { key = "casual_welcome", text = "welcome o/ gl hf", style = "casual", trigger = "others" },
    { key = "classic_tank1", text = "tank here o/", role = "TANK", trigger = "self" },
    { key = "classic_tank2", text = "tanking today", role = "TANK", trigger = "self" },
    { key = "classic_heal1", text = "healer here o/", role = "HEALER", trigger = "self" },
    { key = "classic_heal2", text = "heals incoming", role = "HEALER", trigger = "self" },
    { key = "classic_dps1", text = "dps here o/", role = "DAMAGER", trigger = "self" },
    { key = "classic_dps2", text = "damage on the way", role = "DAMAGER", trigger = "self" },
    { key = "classic_tank3", text = "holding the front today", role = "TANK", trigger = "self" },
    { key = "classic_heal3", text = "healer ready", role = "HEALER", trigger = "self" },
    { key = "classic_dps3", text = "ready to deal damage", role = "DAMAGER", trigger = "self" },
    { key = "classic_hellonames", text = "hello {names}", trigger = "self" },
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
    { key = "dark_tank3", text = "the darkness breaks against me", style = "dark", role = "TANK", trigger = "self" },
    { key = "dark_heal3", text = "I call the fading back", style = "dark", role = "HEALER", trigger = "self", keepCase = true },
    { key = "dark_dps3", text = "the last bell tolls", style = "dark", role = "DAMAGER", trigger = "self" },
    { key = "dark_names1", text = "the shadows know you, {names}", style = "dark", trigger = "self" },
    { key = "dark_names2", text = "welcome to the dark, {names}", style = "dark", trigger = "others" },
    { key = "dark_names3", text = "the gloom makes room for {names}", style = "dark", trigger = "others" },
    { key = "light_tank1", text = "tank here, I've got you all", style = "light", role = "TANK", trigger = "self" },
    { key = "light_tank2", text = "I'll keep everyone safe o/", style = "light", role = "TANK", trigger = "self", keepCase = true },
    { key = "light_heal1", text = "healer here, I'll patch you up", style = "light", role = "HEALER", trigger = "self" },
    { key = "light_heal2", text = "heals ready, happy to help <3", style = "light", role = "HEALER", trigger = "self" },
    { key = "light_dps1", text = "dps here, happy to help o/", style = "light", role = "DAMAGER", trigger = "self" },
    { key = "light_dps2", text = "I'll do my best out there", style = "light", role = "DAMAGER", trigger = "self", keepCase = true },
    { key = "light_tank3", text = "I will clear a safe path for us", style = "light", role = "TANK", trigger = "self", keepCase = true },
    { key = "light_heal3", text = "plenty of care to go around <3", style = "light", role = "HEALER", trigger = "self" },
    { key = "light_dps3", text = "damage duty, with a smile", style = "light", role = "DAMAGER", trigger = "self" },
    { key = "light_names1", text = "lovely to see you {names}", style = "light", trigger = "self" },
    { key = "light_names2", text = "so glad you are here, {names}", style = "light", trigger = "others" },
    { key = "pirate_tank1", text = "I be the hull, hide behind me", style = "pirate", role = "TANK", trigger = "self", keepCase = true },
    { key = "pirate_tank2", text = "anchor's down, I'm not moving", style = "pirate", role = "TANK", trigger = "self", keepCase = true },
    { key = "pirate_heal1", text = "the ship's surgeon reports in", style = "pirate", role = "HEALER", trigger = "self" },
    { key = "pirate_heal2", text = "I patch the crew, mind the fire", style = "pirate", role = "HEALER", trigger = "self", keepCase = true },
    { key = "pirate_dps1", text = "cannons ready o/", style = "pirate", role = "DAMAGER", trigger = "self" },
    { key = "pirate_dps2", text = "the cannons are loaded", style = "pirate", role = "DAMAGER", trigger = "self", keepCase = true },
    { key = "pirate_tank3", text = "this hull takes the broadside", style = "pirate", role = "TANK", trigger = "self" },
    { key = "pirate_heal3", text = "surgeon's kit open on deck", style = "pirate", role = "HEALER", trigger = "self" },
    { key = "pirate_dps3", text = "bringing the broadside", style = "pirate", role = "DAMAGER", trigger = "self" },
    { key = "pirate_names1", text = "ahoy {names}", style = "pirate", trigger = "self" },
    { key = "pirate_names2", text = "welcome to the crew, {names}", style = "pirate", trigger = "others" },
    { key = "faction_tank1", text = "front line, on me", style = "faction", role = "TANK", trigger = "self" },
    { key = "faction_tank2", text = "I hold the vanguard", style = "faction", role = "TANK", trigger = "self", keepCase = true },
    { key = "faction_heal1", text = "field medic reporting", style = "faction", role = "HEALER", trigger = "self" },
    { key = "faction_heal2", text = "the wounded live today", style = "faction", role = "HEALER", trigger = "self" },
    { key = "faction_dps1", text = "weapons hot", style = "faction", role = "DAMAGER", trigger = "self" },
    { key = "faction_dps2", text = "for the charge o/", style = "faction", role = "DAMAGER", trigger = "self" },
    { key = "faction_tank3", text = "our banner will not yield", style = "faction", role = "TANK", trigger = "self" },
    { key = "faction_heal3", text = "our ranks return to fighting strength", style = "faction", role = "HEALER", trigger = "self" },
    { key = "faction_dps3", text = "for our banner, I strike", style = "faction", role = "DAMAGER", trigger = "self" },
    { key = "faction_names1", text = "rally with me, {names}", style = "faction", trigger = "self" },
    { key = "faction_names2", text = "the Horde welcomes you, {names}", style = "faction", faction = "Horde", trigger = "others" },
    { key = "faction_names3", text = "the Alliance welcomes you, {names}", style = "faction", faction = "Alliance", trigger = "others" },
    { key = "zoomer_tank1", text = "tank here, im him", style = "zoomer", role = "TANK", trigger = "self" },
    { key = "zoomer_tank2", text = "tank here, pulling big fr", style = "zoomer", role = "TANK", trigger = "self" },
    { key = "zoomer_heal1", text = "healer here, ill keep u alive fr", style = "zoomer", role = "HEALER", trigger = "self" },
    { key = "zoomer_heal2", text = "heals on deck", style = "zoomer", role = "HEALER", trigger = "self" },
    { key = "zoomer_dps1", text = "dps here, watch this", style = "zoomer", role = "DAMAGER", trigger = "self" },
    { key = "zoomer_dps2", text = "locked in today", style = "zoomer", role = "DAMAGER", trigger = "self" },
    { key = "zoomer_tank3", text = "aggro locked, we move", style = "zoomer", role = "TANK", trigger = "self" },
    { key = "zoomer_heal3", text = "heals ready, i got you", style = "zoomer", role = "HEALER", trigger = "self" },
    { key = "zoomer_dps3", text = "dps here, numbers loading", style = "zoomer", role = "DAMAGER", trigger = "self" },
    { key = "zoomer_names1", text = "yo {names}", style = "zoomer", trigger = "self" },
    { key = "zoomer_names2", text = "{names} pulled up", style = "zoomer", trigger = "others" },
    { key = "zoomer_names3", text = "welcome {names}, squad just got buffed", style = "zoomer", trigger = "others" },
    { key = "butler_tank1", text = "I shall stand between you and harm", style = "butler", role = "TANK", trigger = "self", keepCase = true },
    { key = "butler_tank2", text = "your protection is my duty", style = "butler", role = "TANK", trigger = "self" },
    { key = "butler_heal1", text = "I shall attend to your wounds", style = "butler", role = "HEALER", trigger = "self", keepCase = true },
    { key = "butler_heal2", text = "your health is in my care", style = "butler", role = "HEALER", trigger = "self" },
    { key = "butler_dps1", text = "I shall dispatch them, discreetly", style = "butler", role = "DAMAGER", trigger = "self", keepCase = true },
    { key = "butler_dps2", text = "the unpleasantness is mine to handle", style = "butler", role = "DAMAGER", trigger = "self" },
    { key = "butler_tank3", text = "allow me to take the forward position", style = "butler", role = "TANK", trigger = "self" },
    { key = "butler_heal3", text = "should you falter, I shall restore you", style = "butler", role = "HEALER", trigger = "self" },
    { key = "butler_dps3", text = "our uninvited guests will be shown the door", style = "butler", role = "DAMAGER", trigger = "self" },
    { key = "butler_names1", text = "may I offer my respects, {names}", style = "butler", trigger = "self" },
    { key = "butler_names2", text = "delighted to have you with us, {names}", style = "butler", trigger = "others" },
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
    { key = "minimal_tank3", text = "front line", style = "minimal", role = "TANK", trigger = "self" },
    { key = "minimal_heal3", text = "on heals", style = "minimal", role = "HEALER", trigger = "self" },
    { key = "minimal_dps3", text = "dps ready", style = "minimal", role = "DAMAGER", trigger = "self" },
    { key = "minimal_hinames", text = "{names} o/", style = "minimal", trigger = "self" },
    { key = "minimal_names2", text = "welcome {names}", style = "minimal", trigger = "others" },
    { key = "robot_greetings", text = "greetings, unit", style = "robot" },
    { key = "robot_protocol", text = "party protocol initiated", style = "robot", trigger = "self" },
    { key = "robot_parameters", text = "functioning within parameters", style = "robot", trigger = "self" },
    { key = "robot_detected", text = "new unit detected, welcome", style = "robot", trigger = "others" },
    { key = "robot_tank3", text = "hostile focus routing enabled", style = "robot", role = "TANK", trigger = "self" },
    { key = "robot_heal3", text = "ally repair matrix calibrated", style = "robot", role = "HEALER", trigger = "self" },
    { key = "robot_dps3", text = "combat output calibrated", style = "robot", role = "DAMAGER", trigger = "self" },
    { key = "robot_names1", text = "acknowledgment complete: {names}", style = "robot", trigger = "self" },
    { key = "robot_names2", text = "registration complete: {names}", style = "robot", trigger = "others" },
    { key = "robot_names3", text = "welcome, {names}. protocol resumed.", style = "robot", trigger = "others" },
    { key = "deadpan_hi", text = "hi.", style = "deadpan", appendNames = true },
    { key = "deadpan_another", text = "another run. hello.", style = "deadpan", trigger = "self" },
    { key = "deadpan_herewego", text = "here we go then", style = "deadpan", trigger = "self" },
    { key = "deadpan_someone", text = "new arrival. hello.", style = "deadpan", trigger = "others" },
    { key = "deadpan_tank3", text = "tank. front position, apparently mine", style = "deadpan", role = "TANK", trigger = "self" },
    { key = "deadpan_heal3", text = "healing. routine enough", style = "deadpan", role = "HEALER", trigger = "self" },
    { key = "deadpan_dps3", text = "damage. routine work", style = "deadpan", role = "DAMAGER", trigger = "self" },
    { key = "deadpan_names1", text = "hello {names}.", style = "deadpan", trigger = "self" },
    { key = "deadpan_names2", text = "there you are, {names}.", style = "deadpan", trigger = "others" },
    { key = "deadpan_names3", text = "so, {names}. hello.", style = "deadpan", trigger = "others" },
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
    { key = "nature_tank3", text = "the old oak stands at the front", style = "naturewarden", role = "TANK", trigger = "self" },
    { key = "nature_heal3", text = "the grove mends what breaks", style = "naturewarden", role = "HEALER", trigger = "self" },
    { key = "nature_dps3", text = "the wilds lend strength to every strike", style = "naturewarden", role = "DAMAGER", trigger = "self" },
    { key = "nature_names1", text = "the grove is brighter with you, {names}", style = "naturewarden", trigger = "self" },
    { key = "nature_names2", text = "new paths join ours: {names}", style = "naturewarden", trigger = "others" },
    { key = "fantasy_skies", text = "may the skies favor our path", style = "fantasy" },
    { key = "fantasy_ancient", text = "the old paths brought us together", style = "fantasy", trigger = "self" },
    { key = "fantasy_scale", text = "I hold the line, steady as dragon scales", style = "fantasy", role = "TANK", trigger = "self", keepCase = true },
    { key = "fantasy_heal3", text = "my arts stand ready to mend", style = "fantasy", role = "HEALER", trigger = "self" },
    { key = "fantasy_dps3", text = "my might joins the fray", style = "fantasy", role = "DAMAGER", trigger = "self" },
    { key = "fantasy_greetnames", text = "our fellowship is strengthened by {names}", style = "fantasy", trigger = "self" },
    { key = "fantasy_joinnames", text = "the road brings us {names}", style = "fantasy", trigger = "others" },
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
    { key = "dark_calls", text = "my work here is done", style = "dark" },
    { key = "dark_mist", text = "rest while you can", style = "dark" },
    { key = "light_takecare", text = "bye all, take care <3", style = "light" },
    { key = "light_bewell", text = "thanks for the run, be well", style = "light" },
    { key = "light_seeyou", text = "see you around, friends", style = "light" },
    { key = "pirate_fairwinds", text = "sailing off, fair winds", style = "pirate" },
    { key = "pirate_calmerseas", text = "off to calmer seas o/", style = "pirate" },
    { key = "faction_strength", text = "strength and honor, bye", style = "faction", faction = "Horde" },
    { key = "faction_axes", text = "may your axes stay sharp", style = "faction", faction = "Horde" },
    { key = "faction_lightbe", text = "Light be with you", style = "faction", faction = "Alliance", keepCase = true },
    { key = "faction_honorguide", text = "honor guide you, bye", style = "faction", faction = "Alliance" },
    -- Not "gg go next": the depleted pool says that, and a run that goes down would have
    -- said it once already a few seconds earlier
    { key = "zoomer_ggnext", text = "peace out o/", style = "zoomer" },
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
    { key = "deadpan_itwasfine", text = "leaving. gg.", style = "deadpan" },
    { key = "deadpan_iguess", text = "bye then.", style = "deadpan" },
    { key = "nature_road", text = "may the road be gentle", style = "naturewarden" },
    { key = "nature_seasons", text = "good hunting, until the seasons turn", style = "naturewarden" },
    { key = "nature_still", text = "safe travels, keep to the still paths", style = "naturewarden" },
    { key = "fantasy_flytrue", text = "fly true, friends", style = "fantasy" },
    { key = "casual_ggcya", text = "gg all, cya", style = "casual" },
    { key = "casual_thxbye", text = "thx for the run, bye o/", style = "casual" },
    { key = "casual_gtg", text = "gtg, thx all", style = "casual" },
    { key = "casual_cyanext", text = "cya, gl on the next one", style = "casual" },
    { key = "casual_bb", text = "bb all o/", style = "casual" },
    { key = "pirate_opensea", text = "back to the open sea o/", style = "pirate" },
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
    { key = "casual_backsorry", text = "back, sorry about that", style = "casual" },
    { key = "casual_backdc", text = "back, dc'd", style = "casual" },
    { key = "casual_backnow", text = "back o/", style = "casual" },
    -- One reconnect line is one too few for a bad evening on a bad line
    { key = "pirate_ashore", text = "washed ashore, back o/", style = "pirate" },
    { key = "faction_formation", text = "back in formation", style = "faction" },
    { key = "zoomer_wegood", text = "back, we good", style = "zoomer" },
    { key = "butler_interruption", text = "forgive the interruption", style = "butler" },
}

-- Style bundle ids, in UI order
-- "classic" is not a style tag on any phrase: it stands for the untagged pool, so the
-- stock phrases can be switched on and off as fast as a style bundle (see StyleMatches)
AutoSay.MessageStyles = {
    "classic", "casual", "minimal", "fun", "fantasy", "dark", "deadpan", "light", "pirate",
    "faction", "zoomer", "butler", "robot", "naturewarden",
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
--   side        greeting pools only: "self" is what you say on arriving, "others" what you
--               say to whoever arrives after you. Untagged phrases belong to both.
AutoSay.StylePools = {
    { messages = "Greetings", enabledKey = "enabledGreetingsSelf",
      header = "Greetings", side = "self" },
    { messages = "Greetings", enabledKey = "enabledGreetingsOthers",
      header = "Greetings", side = "others" },
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
    { key = "deadpan_sure", text = "{dungeon} {key}. right then.", style = "deadpan" },
    { key = "nature_trail", text = "the trail leads to {dungeon} {key}", style = "naturewarden" },
    -- Faction had no M+ line at all, so picking that bundle left a player speaking classic
    -- in every dungeon. Its soldier's voice carries without naming a side, which is what
    -- keeps the pool the same depth for a Horde and an Alliance character
    { key = "faction_orders", text = "{dungeon} {key}, orders are clear", style = "faction" },
    { key = "faction_muster", text = "{dungeon} {key}, muster up", style = "faction" },
    { key = "casual_key", text = "{dungeon} {key}, gl hf all", style = "casual" },
    { key = "casual_keyready", text = "{dungeon} {key}, ready when you are", style = "casual" },
    -- A second line per bundle. One was enough to prove the bundle existed and not enough
    -- for a second key on the same evening
    { key = "minimal_keygo", text = "{dungeon} {key} go", style = "minimal" },
    { key = "fun_keysnacks", text = "{dungeon} {key}, snacks packed", style = "fun" },
    { key = "fantasy_keyquest", text = "{dungeon} {key}, the quest begins", style = "fantasy" },
    { key = "dark_keybegin", text = "{dungeon} {key}, let it begin", style = "dark" },
    { key = "deadpan_keyhere", text = "{dungeon} {key}. here we go.", style = "deadpan" },
    { key = "light_keygotthis", text = "{dungeon} {key}, we've got this", style = "light" },
    { key = "pirate_keyanchor", text = "{dungeon} {key}, weigh anchor", style = "pirate" },
    { key = "zoomer_keyball", text = "{dungeon} {key} we ball", style = "zoomer" },
    { key = "butler_keyconvenience", text = "{dungeon} {key}, at your convenience", style = "butler" },
    { key = "robot_keycommencing", text = "{dungeon} {key}, commencing", style = "robot" },
    { key = "nature_keypath", text = "{dungeon} {key}, the path opens", style = "naturewarden" },
}

-- M+ completion messages - timed (enabled by default first)
-- A timed key is a win, so nothing here may undercut it: no surprise that the group
-- managed it, no grudging approval, no line that grades the run or the people in it.
-- Dry styles stay dry by aiming at the speaker or the clock, never at the group
AutoSay.CompletionTimed = {
    { key = "gg", text = "gg" },
    { key = "ggwp", text = "gg wp" },
    { key = "gjteam", text = "gj team!" },
    { key = "nicerun", text = "nice run!" },
    -- Disabled by default
    { key = "letsgo", text = "let's gooo!" },
    { key = "cleanrun", text = "beat the timer!" },
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
    { key = "minimal_wellrun", text = "timed", style = "minimal" },
    { key = "robot_nominal", text = "objective complete, efficiency nominal", style = "robot" },
    { key = "deadpan_incredible", text = "timer beaten. good work.", style = "deadpan" },
    { key = "nature_wellwalked", text = "well walked, everyone", style = "naturewarden" },
    -- No faction tag on any of these: the M+ pools are picked without FitsContext, so a
    -- side named here would go out to the other one as well
    { key = "faction_objective", text = "objective secured, well fought", style = "faction" },
    { key = "faction_bannerflies", text = "the banner still flies, gg", style = "faction" },
    { key = "faction_heldfield", text = "we hold the field, gg all", style = "faction" },
    { key = "casual_ggty", text = "gg ty all", style = "casual" },
    { key = "casual_nicegg", text = "nice, gg ty", style = "casual" },
    { key = "casual_timedit", text = "timed it, gg all", style = "casual" },
    -- Two more per bundle. A timed key is the most-repeated line the addon has for an M+
    -- player, and it was running on one phrase per bundle
    { key = "minimal_ontime", text = "on time", style = "minimal" },
    { key = "minimal_madeit", text = "made it", style = "minimal" },
    { key = "fun_outran", text = "gg, we out-ran the clock", style = "fun" },
    { key = "fun_tellguild", text = "timed it, someone tell the guild", style = "fun" },
    { key = "fantasy_timeryields", text = "the timer yields", style = "fantasy" },
    { key = "fantasy_swiftvictory", text = "a swift victory, well fought", style = "fantasy" },
    { key = "dark_merciless", text = "swift and merciless, gg", style = "dark" },
    { key = "dark_clockbowed", text = "the clock bowed to us", style = "dark" },
    { key = "deadpan_unexpected", text = "on time. as planned.", style = "deadpan" },
    { key = "deadpan_noted", text = "we made it. well done.", style = "deadpan" },
    { key = "light_lovelyrun", text = "lovely run everyone, gg", style = "light" },
    { key = "light_madeit", text = "made it, thanks all <3", style = "light" },
    { key = "pirate_beattide", text = "beat the tide, gg crew", style = "pirate" },
    { key = "pirate_swiftcrossing", text = "a swift crossing, well sailed", style = "pirate" },
    { key = "zoomer_ezgg", text = "timed it ez, gg", style = "zoomer" },
    { key = "zoomer_sentit", text = "gg we sent it", style = "zoomer" },
    { key = "butler_efficiently", text = "most efficiently done", style = "butler" },
    { key = "butler_observed", text = "the timer has been observed", style = "butler" },
    { key = "robot_parameters", text = "objective complete, within parameters", style = "robot" },
    { key = "robot_constraint", text = "time constraint satisfied", style = "robot" },
    { key = "nature_swifthunt", text = "swift as the hunt, well done", style = "naturewarden" },
    { key = "nature_pacesun", text = "we kept pace with the sun", style = "naturewarden" },
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

-- LFG activityID -> mapChallengeModeID (Midnight Season 2, harvested with /as dumpdungeons).
-- A fallback, not the main answer: GetMapIDFromActivity bridges the two ids live through the
-- ui map id they share, which keeps working when the season rotates. This table answers when
-- the activity data is not loaded yet, and is the place to correct a dungeon by hand.
AutoSay.ActivityToDungeon = {
    [1933] = 588, -- Altar of Fangs
    [1176] = 399, -- Ruby Life Pools
    [514] = 249,  -- Kings' Rest
    [1951] = 585, -- Voidscar Arena
    [1952] = 586, -- Den of Nalorakk
    [1950] = 587, -- Murder Row
    [504] = 250,  -- Temple of Sethraliss
    [1949] = 584, -- The Blinding Vale
}

-- M+ completion messages - depleted (enabled by default first)
AutoSay.CompletionDepleted = {
    { key = "gg", text = "gg" },
    { key = "ggwp", text = "gg wp" },
    { key = "tyrun", text = "ty for the run" },
    { key = "tyall", text = "ty all" },
    -- Disabled by default
    { key = "goodrun", text = "thanks for the effort, everyone" },
    { key = "ggeveryone", text = "gg everyone" },
    { key = "gjteam", text = "gj team" },
    { key = "wpall", text = "wp all" },
    { key = "done", text = "{dungeon} {key} done, gg" },
    { key = "tyfun", text = "thanks for the run, everyone" },
    -- Style bundles (never enabled by default, activated by bundle or by hand)
    { key = "fun_blamelag", text = "timer got away, loot didn't", style = "fun" },
    { key = "fantasy_noble", text = "a noble effort, friends", style = "fantasy" },
    { key = "dark_claims", text = "the dungeon claims this one, gg", style = "dark" },
    { key = "light_nextone", text = "thanks for finishing together <3", style = "light" },
    { key = "pirate_roughseas", text = "rough seas, gg crew", style = "pirate" },
    { key = "zoomer_gonext", text = "gg go next", style = "zoomer" },
    { key = "butler_valiant", text = "my thanks for your company and effort", style = "butler" },
    { key = "minimal_rough", text = "over the timer", style = "minimal" },
    { key = "robot_recalibrating", text = "dungeon complete. timer exceeded.", style = "robot" },
    { key = "deadpan_asexpected", text = "done. the clock disagreed.", style = "deadpan" },
    { key = "nature_longpath", text = "a long path, but we walked it", style = "naturewarden" },
    -- Untagged for the same reason as the timed ones, and a depleted key is not the moment
    -- for a war cry anyway
    { key = "faction_heldline", text = "the line held, the clock did not", style = "faction" },
    { key = "faction_honorintact", text = "honor intact, ty all", style = "faction" },
    { key = "faction_regroup", text = "we regroup, ty all", style = "faction" },
    { key = "casual_tyrunall", text = "ty for the run all", style = "casual" },
    { key = "casual_gganyway", text = "gg anyway, ty all", style = "casual" },
    { key = "casual_notime", text = "no time but ty all", style = "casual" },
    -- Two more per bundle, written to the same rule as the defaults above: the addon knows
    -- the timer ran out and nothing else. Nothing here grades the run, blames anything,
    -- promises the next one, or calls a finished dungeon a failure
    { key = "minimal_tyd", text = "ty", style = "minimal" },
    { key = "minimal_ggall", text = "gg all", style = "minimal" },
    { key = "fun_clockundefeated", text = "gg, the clock is undefeated", style = "fun" },
    { key = "fun_finishedcounts", text = "we finished it, that counts", style = "fun" },
    { key = "fantasy_hourran", text = "the hour ran out, the deed stands", style = "fantasy" },
    { key = "fantasy_sawthrough", text = "we saw it through, friends", style = "fantasy" },
    { key = "dark_hourwon", text = "the hour won this one", style = "dark" },
    { key = "dark_endsanyway", text = "it ends, if not in time", style = "dark" },
    { key = "deadpan_eventually", text = "finished. ty all.", style = "deadpan" },
    { key = "deadpan_itsover", text = "well, that's done. ty.", style = "deadpan" },
    { key = "light_toughone", text = "ty all, that was a tough one", style = "light" },
    { key = "light_stickingwith", text = "appreciate you all sticking with it", style = "light" },
    { key = "pirate_tidebeat", text = "the tide beat us, ty crew", style = "pirate" },
    { key = "pirate_portlate", text = "we made port late, gg", style = "pirate" },
    { key = "zoomer_stillgg", text = "no timer, still gg", style = "zoomer" },
    { key = "zoomer_wemove", text = "gg, we move", style = "zoomer" },
    { key = "butler_allthesame", text = "my thanks to you all", style = "butler" },
    { key = "butler_pleasureregardless", text = "a pleasure as always, thank you", style = "butler" },
    { key = "robot_suboptimal", text = "objective complete, time constraint not met", style = "robot" },
    { key = "robot_runlogged", text = "run logged, ty units", style = "robot" },
    { key = "nature_pathlong", text = "the path was long, ty all", style = "naturewarden" },
    { key = "nature_walkedthrough", text = "we walked it through, well done", style = "naturewarden" },
}
