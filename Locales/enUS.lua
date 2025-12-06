local L = LibStub("AceLocale-3.0"):NewLocale("AutoSay", "enUS", true)
if not L then return end

-- General
L["AutoSay"] = "AutoSay"
L["Enable"] = "Enable"
L["Enable addon"] = "Enable addon"
L["Debug mode"] = "Debug mode"
L["Show debug messages in chat"] = "Show debug messages in chat"

-- Categories / Tabs
L["General"] = "General"
L["Greetings"] = "Greetings"
L["Farewells"] = "Farewells"
L["Messages"] = "Messages"

-- Channel names
L["Party"] = "Party"
L["Raid"] = "Raid"
L["Guild"] = "Guild"
L["PARTY"] = "Party"
L["RAID"] = "Raid"
L["GUILD"] = "Guild"

-- Per-channel tab names
L["Party Settings"] = "Party Settings"
L["Party Greetings"] = "Party Greetings"
L["Party Farewells"] = "Party Farewells"
L["Raid Settings"] = "Raid Settings"
L["Raid Greetings"] = "Raid Greetings"
L["Raid Farewells"] = "Raid Farewells"
L["Party Reconnects"] = "Party Reconnects"
L["Raid Reconnects"] = "Raid Reconnects"
L["Guild Settings"] = "Guild Settings"
L["Guild Greetings"] = "Guild Greetings"
L["Guild Farewells"] = "Guild Farewells"

-- Per-channel descriptions
L["Configure party chat settings"] = "Configure party chat settings"
L["Configure raid chat settings"] = "Configure raid chat settings"
L["Configure guild chat settings"] = "Configure guild chat settings"
L["Select greetings to use in party chat"] = "Select greetings to use in party chat"
L["Select farewells to use in party chat"] = "Select farewells to use in party chat"
L["Select greetings to use in raid chat"] = "Select greetings to use in raid chat"
L["Select farewells to use in raid chat"] = "Select farewells to use in raid chat"
L["Select greetings to use in guild chat"] = "Select greetings to use in guild chat"
L["Select farewells to use in guild chat"] = "Select farewells to use in guild chat"

-- Per-channel enable settings
L["Enable Party"] = "Enable Party"
L["Enable Party greetings"] = "Enable Party"
L["Send greetings and farewells in party chat"] = "Send greetings and farewells in party chat"
L["Send greetings to party chat"] = "Send greetings and farewells in party chat"
L["Enable Raid"] = "Enable Raid"
L["Enable Raid greetings"] = "Enable Raid"
L["Send greetings and farewells in raid chat"] = "Send greetings and farewells in raid chat"
L["Send greetings to raid chat"] = "Send greetings and farewells in raid chat"
L["Enable Guild"] = "Enable Guild"
L["Enable Guild greetings"] = "Enable Guild"
L["Send greetings and farewells to guild chat"] = "Send greetings and farewells to guild chat"
L["Send greeting to guild chat on login"] = "Send greeting to guild chat on login"
L["Send greetings to guild chat on login"] = "Send greeting to guild chat on login"

-- Triggers
L["Triggers"] = "Triggers"
L["On self join"] = "On self join"
L["Send greeting when you join"] = "Send greeting when you join"
L["Send greeting when you join a party"] = "Send greeting when you join a party"
L["Send greeting when you join a raid"] = "Send greeting when you join a raid"
L["On others join"] = "On others join"
L["Send greeting when others join"] = "Send greeting when others join"
L["Send greeting when others join your party"] = "Send greeting when others join your party"
L["Send greeting when others join your raid"] = "Send greeting when others join your raid"
L["On reconnect"] = "On reconnect"
L["Send greeting when you reconnect to party"] = "Send greeting when you reconnect to party"
L["Send greeting when you reconnect to raid"] = "Send greeting when you reconnect to raid"
L["On login"] = "On login"
L["Send greeting when you log in"] = "Send greeting when you log in"
L["On logout"] = "On logout"
L["Send farewell when you log out"] = "Send farewell when you log out"

-- Names
L["Player Names"] = "Player Names"
L["Include player names"] = "Include player names"
L["Add joined player names to the greeting"] = "Add joined player names to the greeting"

-- Farewells
L["Send Farewell"] = "Send Farewell"
L["Send farewell on leave"] = "Send farewell on leave"
L["Send farewell when leaving"] = "Send farewell when leaving"
L["Send farewell when leaving party"] = "Send farewell when leaving party"
L["Send farewell when leaving raid"] = "Send farewell when leaving raid"

-- Messages
L["Message Selection"] = "Message Selection"
L["Greeting Messages"] = "Greeting Messages"
L["Select which greetings to use"] = "Select which greetings to use"
L["Farewell Messages"] = "Farewell Messages"
L["Select which farewells to use"] = "Select which farewells to use"

-- Message categories
L["Popular"] = "Popular"
L["More"] = "More"
L["Custom Messages"] = "Custom Messages"
L["Custom greeting"] = "Custom greeting"
L["Enter your custom greeting message"] = "Enter your custom greeting message"
L["Custom farewell"] = "Custom farewell"
L["Enter your custom farewell message"] = "Enter your custom farewell message"
L["Custom reconnect"] = "Custom reconnect"
L["Enter your custom reconnect message"] = "Enter your custom reconnect message"

-- Timing
L["Timing"] = "Timing"
L["Message delay"] = "Message delay"
L["Delay before sending message (seconds)"] = "Delay before sending message (seconds)"
L["Cooldown"] = "Cooldown"
L["Minimum time between messages (seconds)"] = "Minimum time between messages (seconds)"

-- Slash commands
L["Opens AutoSay settings"] = "Opens AutoSay settings"
L["Addon enabled"] = "Addon enabled"
L["Addon disabled"] = "Addon disabled"

-- Status messages
L["Sent greeting to"] = "Sent greeting to"
L["Sent farewell to"] = "Sent farewell to"

-- Test Mode
L["Test Mode"] = "Test Mode"
L["Test mode description"] = "Test mode allows you to test all addon functionality without being in a group, raid, or guild. Messages will be printed to chat instead of actually sent."
L["Test Mode Toggle"] = "Test Mode Toggle"
L["Enable Test Mode"] = "Enable Test Mode"
L["Enable test mode desc"] = "Enable test mode to simulate events and preview messages without sending them"
L["Simulate Events"] = "Simulate Events"
L["Join Party"] = "Join Party"
L["Simulate joining a party"] = "Simulate joining a party"
L["Join Raid"] = "Join Raid"
L["Simulate joining a raid"] = "Simulate joining a raid"
L["Leave Group"] = "Leave Group"
L["Simulate leaving current group"] = "Simulate leaving current group"
L["Guild Greeting"] = "Guild Greeting"
L["Simulate guild login greeting"] = "Simulate guild login greeting"
L["Guild Farewell"] = "Guild Farewell"
L["Simulate guild logout farewell"] = "Simulate guild logout farewell"
L["Simulate Player Join"] = "Simulate Player Join"
L["Random Player Joins"] = "Random Player Joins"
L["Simulate a random player joining your group"] = "Simulate a random player joining your group"
L["Reconnect"] = "Reconnect"
L["Simulate reconnecting to group"] = "Simulate reconnecting to group"
L["Status"] = "Status"
L["Reset Test State"] = "Reset Test State"
L["Reset all test state and cooldowns"] = "Reset all test state and cooldowns"
L["Refresh Status"] = "Refresh Status"
L["Refresh the status display"] = "Refresh the status display"

-- Debug
L["Debug"] = "Debug"
